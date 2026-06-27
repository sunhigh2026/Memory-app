import 'package:unorm_dart/unorm_dart.dart' as unorm;
import 'package:kuromoji/kuromoji.dart' as kuro;
import 'package:kuromoji/src/tokenizer.dart' as kuro_tok;

/// 括弧の扱い
enum ParenthesesMode { keep, stripContent, stripSymbols }

/// 照合の厳しさ設定用のコンフィグ
class MatchStrictnessConfig {
  final double ratio; // 一定文字数以上の許容割合
  final int shortLengthLimit; // 完全一致を求める文字数のしきい値
  final int mediumLengthLimit; // 1文字だけ許容する文字数のしきい値
  final int shortMaxDistance;
  final int mediumMaxDistance;

  const MatchStrictnessConfig({
    required this.ratio,
    required this.shortLengthLimit,
    required this.mediumLengthLimit,
    this.shortMaxDistance = 0,
    this.mediumMaxDistance = 1,
  });
}

/// テキスト正規化ユーティリティ
/// 音声認識結果と原文の比較前に正規化処理を行う
class TextNormalizer {
  // 各厳しさの定義
  static const Map<String, MatchStrictnessConfig> strictnessConfigs = {
    'easy': MatchStrictnessConfig(
      ratio: 0.30,
      shortLengthLimit: 1, // 1文字以下は完全一致
      mediumLengthLimit: 5, // 2〜5文字は2文字許容
      shortMaxDistance: 0,
      mediumMaxDistance: 2,
    ),
    'normal': MatchStrictnessConfig(
      ratio: 0.20,
      shortLengthLimit: 3, // 3文字以下は完全一致
      mediumLengthLimit: 6, // 4〜6文字は1文字許容
      shortMaxDistance: 0,
      mediumMaxDistance: 1,
    ),
    'strict': MatchStrictnessConfig(
      ratio: 0.10,
      shortLengthLimit: 5, // 5文字以下は完全一致
      mediumLengthLimit: 10, // 6〜10文字は1文字許容
      shortMaxDistance: 0,
      mediumMaxDistance: 1,
    ),
  };

  /// 比較用に正規化（句読点除去、全角→半角、カタカナ→ひらがな）
  static String normalize(
    String text, {
    ParenthesesMode parentheses = ParenthesesMode.keep,
  }) {
    var result = unorm.nfc(text.trim());
    // 括弧処理
    result = handleParentheses(result, parentheses);
    // 句読点・空白・改行、および丸数字や中黒、ダッシュ、数字等の記号、カッコ類、引用符、不可視制御文字を除去
    result = result.replaceAll(RegExp(r"""[。、！？!?,.\s\n\r　・①-⑳㉑-㊿\d０-９\-‐―—\u200B-\u200D\uFEFF「」『』【】〔〕〈〉《》［］｛｝＜＞\[\]{}<>""''`’]"""), '');
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
    var result = unorm.nfc(text.trim());
    result = handleParentheses(result, parentheses);
    result = result.replaceAll(RegExp(r"""[。、！？!?,.\s\n\r　・①-⑳㉑-㊿\d０-９\-‐―—\u200B-\u200D\uFEFF「」『』【】〔〕〈〉《》［］｛｝＜＞\[\]{}<>""''`’]"""), '');
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

  /// 文字数に応じた許容最大レーベンシュタイン距離を算出する（後方互換用）
  static int maxAllowedDistance(int length) {
    return maxAllowedDistanceForLevel(length, 'normal');
  }

  /// 厳しさ設定に応じた許容最大レーベンシュタイン距離を算出する
  static int maxAllowedDistanceForLevel(int length, String levelKey) {
    final config = strictnessConfigs[levelKey] ?? strictnessConfigs['normal']!;
    
    if (length <= config.shortLengthLimit) {
      return config.shortMaxDistance;
    } else if (length <= config.mediumLengthLimit) {
      return config.mediumMaxDistance;
    } else {
      final calculated = (length * config.ratio).floor();
      // 中間の許容上限は維持するように最低値を確保する
      final minAllowed = config.mediumMaxDistance;
      return calculated > minAllowed ? calculated : minAllowed;
    }
  }

  /// 表記の揺れや誤認識（長音、促音・拗音の大小、濁点・半濁点の有無など）を吸収する超曖昧化処理
  static String fuzzyNormalize(String hira) {
    var result = hira;
    
    // 1. 長音記号「ー」の除去（サーバー vs サーバ などの長音の有無を統一）
    result = result.replaceAll('ー', '');

    // 2. 濁点・半濁点を除去して清音化（が -> か、ぱ -> は など）
    final decomposed = unorm.nfd(result);
    final noDiacritics = decomposed.replaceAll(RegExp(r'[\u3099\u309A]'), '');
    result = unorm.nfc(noDiacritics);

    // 3. 促音・拗音（小書き文字）を通常の文字（大書き）に統一（っ->つ, ゃ->や など）
    result = result
        .replaceAll('っ', 'つ')
        .replaceAll('ゃ', 'や')
        .replaceAll('ゅ', 'ゆ')
        .replaceAll('ょ', 'よ')
        .replaceAll('ぁ', 'あ')
        .replaceAll('ぃ', 'い')
        .replaceAll('ぅ', 'う')
        .replaceAll('ぇ', 'え')
        .replaceAll('ぉ', 'お');

    return result;
  }

  /// ひらがなの読み同士を曖昧比較する
  /// レーベンシュタイン距離が許容範囲内であれば true を返す
  static bool isFuzzyMatch(String hira1, String hira2, {String strictness = 'normal'}) {
    if (hira1.isEmpty || hira2.isEmpty) return false;
    if (hira1 == hira2) return true;

    // 照合前の曖昧正規化（長音、促音・拗音、濁点・半濁点のゆれを吸収）
    final norm1 = fuzzyNormalize(hira1);
    final norm2 = fuzzyNormalize(hira2);

    if (norm1 == norm2) return true;

    final dist = levenshtein(norm1, norm2);
    // 正解の文字の長さ（hira2を正解と想定）を基準に閾値を決定
    final maxDist = maxAllowedDistanceForLevel(hira2.length, strictness);

    return dist <= maxDist;
  }

  /// ホットワード近傍補正の最大許容編集距離（0で無効化）
  static const int kHotwordCorrectionMaxDistance = 1;

  /// 文全体を安全にトークン化する（助詞・助動詞で分割して個別にtokenizeすることでOOMを防ぐ）
  static Future<List<Map<String, dynamic>>> _safeTokenize(String text) async {
    if (text.isEmpty) return [];
    
    try {
      final tokenizer = await _getTokenizer();
      
      // 助詞、助動詞、接続詞、句読点などでテキストを分割する
      // これにより、OOMを引き起こす複雑な接続探索を避ける
      final splitReg = RegExp(
        r'[。、！？!?,.\s\n\r　・①-⑳㉑-㊿\d０-９\-‐―—\u200B-\u200D\uFEFF'
        r'はがをにへとでもやで]+'
        r'|です|ます|だ|である|した|する|して'
      );
      
      final List<Map<String, dynamic>> allTokens = [];
      int lastIdx = 0;
      
      for (final match in splitReg.allMatches(text)) {
        final start = match.start;
        final end = match.end;
        
        if (start > lastIdx) {
          final word = text.substring(lastIdx, start).trim();
          if (word.isNotEmpty) {
            try {
              final tokens = tokenizer.tokenize(word);
              allTokens.addAll(tokens.cast<Map<String, dynamic>>());
            } catch (_) {
              allTokens.add({
                'surface_form': word,
                'reading': katakanaToHiragana(word),
              });
            }
          }
        }
        
        final delimiter = text.substring(start, end);
        allTokens.add({
          'surface_form': delimiter,
          'reading': katakanaToHiragana(delimiter),
          'pos': '記号',
        });
        
        lastIdx = end;
      }
      
      if (lastIdx < text.length) {
        final word = text.substring(lastIdx).trim();
        if (word.isNotEmpty) {
          try {
            final tokens = tokenizer.tokenize(word);
            allTokens.addAll(tokens.cast<Map<String, dynamic>>());
          } catch (_) {
            allTokens.add({
              'surface_form': word,
              'reading': katakanaToHiragana(word),
            });
          }
        }
      }
      
      return allTokens;
    } catch (e) {
      // ignore: avoid_print
      print('【デバッグ】_safeTokenizeエラー: $e');
      return [
        {
          'surface_form': text,
          'reading': katakanaToHiragana(text),
        }
      ];
    }
  }

  /// 正解文から「ひらがな読み -> 漢字表層形」の専門用語マップを生成する
  static Future<Map<String, String>> generateHotwordsMap(String correctText) async {
    if (correctText.isEmpty) return {};
    
    try {
      final tokens = await _safeTokenize(correctText);
      final Map<String, String> hotwords = {};
      
      final currentSurface = StringBuffer();
      final currentReading = StringBuffer();
      
      void flushBuffer() {
        if (currentSurface.isNotEmpty) {
          final surface = currentSurface.toString();
          final reading = katakanaToHiragana(currentReading.toString()).replaceAll(RegExp(r'[^ぁ-ん]'), '');
          // 読みが2文字以上かつ表層形も2文字以上の場合のみ登録（過補正防止）
          if (reading.length >= 2 && surface.length >= 2) {
            hotwords[reading] = surface;
          }
          currentSurface.clear();
          currentReading.clear();
        }
      }
      
      for (final token in tokens) {
        final pos = token['pos'] as String? ?? '';
        final posDetail1 = token['pos_detail_1'] as String? ?? '';
        final surface = token['surface_form'] as String? ?? '';
        final reading = token['reading'] as String? ?? '';
        
        final isNoun = pos == '名詞';
        // 代名詞、数、非自立は除外（接尾辞は直前の名詞と結合させるため除外しない）
        final isExcludedNoun = posDetail1 == '代名詞' || posDetail1 == '数' || posDetail1 == '非自立';
        
        if (isNoun && !isExcludedNoun && reading.isNotEmpty && reading != '*') {
          currentSurface.write(surface);
          currentReading.write(reading);
        } else {
          flushBuffer();
        }
      }
      flushBuffer();
      
      return hotwords;
    } catch (e) {
      // ignore: avoid_print
      print('【デバッグ】generateHotwordsMapエラー: $e');
      return {};
    }
  }

  /// 認識結果のトークンを読みベースで近傍補正し、正しい漢字表層形に置換する
  static Future<String> correctRecognizedText(
    String recognizedText,
    Map<String, String> hotwordsMap, {
    int maxDistance = kHotwordCorrectionMaxDistance,
  }) async {
    if (hotwordsMap.isEmpty || recognizedText.isEmpty || maxDistance <= 0) {
      return recognizedText;
    }

    try {
      final tokens = await _safeTokenize(recognizedText);
      
      final List<Map<String, String>> tokenList = tokens.map((t) {
        final surface = t['surface_form'] as String? ?? '';
        final rawReading = t['reading'] as String? ?? '';
        final reading = (rawReading == '*' || rawReading.isEmpty) 
            ? katakanaToHiragana(surface) 
            : katakanaToHiragana(rawReading);
        
        // 記号等を除去してひらがなのみにする
        final cleanReading = reading.replaceAll(RegExp(r'[^ぁ-ん]'), '');
        return {
          'surface': surface,
          'reading': cleanReading,
        };
      }).toList();


      final int len = tokenList.length;
      final List<bool> replaced = List.filled(len, false);
      final resultSurfaces = <String>[];

      int i = 0;
      while (i < len) {
        if (replaced[i]) {
          i++;
          continue;
        }

        String? bestMatchSurface;
        int bestMatchTokensCount = 0;
        int minDistance = maxDistance + 1;
        bool isTie = false;
        bool exactMatchFound = false;

        // 1〜3個の連続するトークンを結合してホットワードと比較
        for (int w = 1; w <= 3; w++) {
          if (i + w > len) break;

          final subTokens = tokenList.sublist(i, i + w);
          final combinedReading = subTokens.map((t) => t['reading']!).join('');
          final combinedSurface = subTokens.map((t) => t['surface']!).join('');

          // まず、読みも表記も完全に一致しているホットワードがあるかチェック
          for (final entry in hotwordsMap.entries) {
            if (combinedReading == entry.key && combinedSurface == entry.value) {
              exactMatchFound = true;
              bestMatchTokensCount = w;
              break;
            }
          }
          if (exactMatchFound) {
            break;
          }

          // 完全一致がない場合のみ、編集距離による曖昧マッチングを行う
          for (final entry in hotwordsMap.entries) {
            final hotwordReading = entry.key;
            final hotwordSurface = entry.value;

            // 読みも表記も一致しているものは上記で除外されているため、ここでは距離計算からスキップ
            if (combinedReading == hotwordReading && combinedSurface == hotwordSurface) {
              continue;
            }

            final dist = levenshtein(combinedReading, hotwordReading);
            if (dist <= maxDistance) {
              if (dist < minDistance) {
                minDistance = dist;
                bestMatchSurface = hotwordSurface;
                bestMatchTokensCount = w;
                isTie = false;
              } else if (dist == minDistance && bestMatchSurface != hotwordSurface) {
                isTie = true; // 同距離タイの競合検出
              }
            }
          }
        }

        if (exactMatchFound) {
          // 完全一致していた場合は、補正せず（そのままの表記を使用）トークン数分進める
          for (int k = 0; k < bestMatchTokensCount; k++) {
            resultSurfaces.add(tokenList[i + k]['surface']!);
          }
          i += bestMatchTokensCount;
        } else if (bestMatchSurface != null && !isTie && minDistance <= maxDistance) {
          resultSurfaces.add(bestMatchSurface);
          for (int k = 0; k < bestMatchTokensCount; k++) {
            replaced[i + k] = true;
          }
          i += bestMatchTokensCount;
        } else {
          resultSurfaces.add(tokenList[i]['surface']!);
          i++;
        }
      }

      return resultSurfaces.join('');
    } catch (e) {
      // ignore: avoid_print
      print('【デバッグ】correctRecognizedTextエラー: $e');
      return recognizedText;
    }
  }
}
