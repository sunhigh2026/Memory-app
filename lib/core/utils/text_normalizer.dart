import 'package:jp_transliterate/jp_transliterate.dart';

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
    var result = text;
    // 括弧処理
    result = handleParentheses(result, parentheses);
    // 句読点・空白・改行を除去
    result = result.replaceAll(RegExp(r'[。、！？!?,.\s\n\r　]'), '');
    // 全角英数字を半角に変換
    result = _fullWidthToHalfWidth(result);
    // カタカナをひらがなに変換
    result = katakanaToHiragana(result);
    return result;
  }

  /// 漢字混じりテキスト → ひらがな変換
  /// jp_transliterate を使用。失敗時はカタカナ→ひらがなフォールバック。
  static Future<String> toHiragana(String text) async {
    try {
      final data = await JpTransliterate.transliterate(kanji: text);
      return data.hiragana;
    } catch (_) {
      // オフライン時やAPI失敗時のフォールバック
      return katakanaToHiragana(text);
    }
  }

  /// フル正規化: ひらがな化 → 記号除去
  static Future<String> fullNormalize(
    String text, {
    ParenthesesMode parentheses = ParenthesesMode.keep,
  }) async {
    var result = text;
    result = handleParentheses(result, parentheses);
    result = result.replaceAll(RegExp(r'[。、！？!?,.\s\n\r　]'), '');
    result = _fullWidthToHalfWidth(result);
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
}
