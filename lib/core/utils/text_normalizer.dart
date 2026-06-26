import 'package:jp_transliterate/jp_transliterate.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;
import 'package:kuromoji/kuromoji.dart' as kuro;
import 'package:kuromoji/src/tokenizer.dart' as kuro_tok;

/// 括弧の扱い
enum ParenthesesMode { keep, stripContent, stripSymbols }

/// テキスト正規化ユーティリティ
/// 音声認識結果と原文の比較前に正規化処理を行う
class TextNormalizer {
  /// 比較用に正規化（句読点除去、全角→半角、カタカナ→ひらがな）
  static String normalize(
    String text, {
    ParenthesesMode parentheses = ParenthesesMode.keep,
  }) {
    var result = unorm.nfc(text);
    // 括弧処理
    result = handleParentheses(result, parentheses);
    // 句読点・空白・改行、および丸数字や中黒、ダッシュ、数字等の記号を除去
    result = result.replaceAll(RegExp(r'[。、！？!?,.\s\n\r　・①-⑳㉑-㊿\d０-９\-‐―—]'), '');
    // 全角英数字を半角に変換
    result = _fullWidthToHalfWidth(result);
    // 小文字に統一
    result = result.toLowerCase();
    // カタカナをひらがなに変換
    result = katakanaToHiragana(result);
    return result;
  }

  static kuro_tok.Tokenizer? _kuromojiTokenizer;

  static Future<kuro_tok.Tokenizer> _getTokenizer() async {
    if (_kuromojiTokenizer != null) return _kuromojiTokenizer!;
    _kuromojiTokenizer = await kuro.TokenizerBuilder().build();
    return _kuromojiTokenizer!;
  }

  /// 漢字混じりテキスト → ひらがな変換
  /// ピュアDartのkuromojiを使用し、オフライン・クロスプラットフォームで安定して動作します。
  static Future<String> toHiragana(String text) async {
    if (text.isEmpty) return '';
    try {
      final tokenizer = await _getTokenizer();
      final tokens = tokenizer.tokenize(text);
      final buffer = StringBuffer();
      for (final token in tokens) {
        final reading = token['reading'] as String?;
        if (reading == null || reading == '*' || reading.isEmpty) {
          buffer.write(token['surface_form'] as String? ?? '');
        } else {
          buffer.write(katakanaToHiragana(reading));
        }
      }
      return buffer.toString();
    } catch (e) {
      // ignore: avoid_print
      print('【デバッグ】toHiraganaエラー: $e');
      // オフライン時やAPI失敗時のフォールバック
      return katakanaToHiragana(text);
    }
  }

  /// フル正規化: ひらがな化 → 記号除去
  static Future<String> fullNormalize(
    String text, {
    ParenthesesMode parentheses = ParenthesesMode.keep,
  }) async {
    var result = unorm.nfc(text);
    result = handleParentheses(result, parentheses);
    result = result.replaceAll(RegExp(r'[。、！？!?,.\s\n\r　・①-⑳㉑-㊿\d０-９\-‐―—]'), '');
    result = _fullWidthToHalfWidth(result);
    result = result.toLowerCase();
    result = await toHiragana(result);
    // toHiragana後にカタカナが残る場合もあるので二重変換
    result = katakanaToHiragana(result);
    return result;
  }

  /// 括弧の処理
  static String handleParentheses(String text, ParenthesesMode mode) {
    switch (mode) {
      case ParenthesesMode.keep:
        return text;
      case ParenthesesMode.stripContent:
        // 括弧と中身を丸ごと除去
        return text.replaceAll(RegExp(r'[（(][^)）]*[)）]'), '');
      case ParenthesesMode.stripSymbols:
        // 括弧記号のみ除去（中身は保持）
        return text.replaceAll(RegExp(r'[（()）]'), '');
    }
  }

  /// 文字列から ParenthesesMode に変換
  static ParenthesesMode parseParenthesesMode(String mode) {
    switch (mode) {
      case 'stripContent':
        return ParenthesesMode.stripContent;
      case 'stripSymbols':
        return ParenthesesMode.stripSymbols;
      default:
        return ParenthesesMode.keep;
    }
  }

  /// カタカナをひらがなに変換
  static String katakanaToHiragana(String text) {
    final buffer = StringBuffer();
    for (final rune in text.runes) {
      // カタカナ範囲: 0x30A0-0x30FF → ひらがな: 0x3040-0x309F
      if (rune >= 0x30A1 && rune <= 0x30F6) {
        buffer.writeCharCode(rune - 0x60);
      } else {
        buffer.writeCharCode(rune);
      }
    }
    return buffer.toString();
  }

  /// ひらがなをカタカナに変換
  static String hiraganaToKatakana(String text) {
    final buffer = StringBuffer();
    for (final rune in text.runes) {
      if (rune >= 0x3041 && rune <= 0x3096) {
        buffer.writeCharCode(rune + 0x60);
      } else {
        buffer.writeCharCode(rune);
      }
    }
    return buffer.toString();
  }

  /// 全角英数字を半角に変換
  static String _fullWidthToHalfWidth(String text) {
    final buffer = StringBuffer();
    for (final rune in text.runes) {
      if (rune >= 0xFF10 && rune <= 0xFF19) {
        buffer.writeCharCode(rune - 0xFEE0);
      } else if (rune >= 0xFF21 && rune <= 0xFF3A) {
        buffer.writeCharCode(rune - 0xFEE0);
      } else if (rune >= 0xFF41 && rune <= 0xFF5A) {
        buffer.writeCharCode(rune - 0xFEE0);
      } else {
        buffer.writeCharCode(rune);
      }
    }
    return buffer.toString();
  }

  /// 文章を句点で分割
  static List<String> splitSentences(String text) {
    final sentences = text.split(RegExp(r'(?<=。)'));
    return sentences
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// レーベンシュタイン距離を計算する
  static int levenshtein(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    final v0 = List<int>.generate(t.length + 1, (i) => i);
    final v1 = List<int>.filled(t.length + 1, 0);

    for (int i = 0; i < s.length; i++) {
      v1[0] = i + 1;

      for (int j = 0; j < t.length; j++) {
        final cost = (s.codeUnitAt(i) == t.codeUnitAt(j)) ? 0 : 1;
        v1[j + 1] = _min3(v1[j] + 1, v0[j + 1] + 1, v0[j] + cost);
      }

      for (int j = 0; j < v0.length; j++) {
        v0[j] = v1[j];
      }
    }

    return v0[t.length];
  }

  static int _min3(int a, int b, int c) {
    int m = a < b ? a : b;
    return m < c ? m : c;
  }

  /// 文字数に応じた許容最大レーベンシュタイン距離を算出する
  /// 短い語（3文字以下）で誤判定が起きないよう制限し、長い語では最大20%の誤認識を許容します。
  static int maxAllowedDistance(int length) {
    if (length <= 3) {
      return 0; // 3文字以下は完全一致のみ（誤認識による誤判定を防ぐ）
    } else if (length <= 6) {
      return 1; // 4〜6文字は1文字までの誤認識を許容 (16.7% 〜 25%)
    } else {
      // 7文字以上は全体の20%までの誤認識を許容
      // ただし、最低でも1文字は許容する
      final calculated = (length * 0.20).floor();
      return calculated > 1 ? calculated : 1;
    }
  }

  /// ひらがなの読み同士を曖昧比較する
  /// レーベンシュタイン距離が許容範囲内であれば true を返す
  static bool isFuzzyMatch(String hira1, String hira2) {
    if (hira1.isEmpty || hira2.isEmpty) return false;
    if (hira1 == hira2) return true;

    final dist = levenshtein(hira1, hira2);
    // 正解の文字の長さ（hira2を正解と想定）を基準に閾値を決定
    final maxDist = maxAllowedDistance(hira2.length);

    return dist <= maxDist;
  }
}
