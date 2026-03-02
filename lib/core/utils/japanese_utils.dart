/// 日本語テキスト処理ユーティリティ
class JapaneseUtils {
  /// 漢字かどうか判定
  static bool isKanji(int rune) {
    return (rune >= 0x4E00 && rune <= 0x9FFF) || // CJK統合漢字
        (rune >= 0x3400 && rune <= 0x4DBF) || // CJK統合漢字拡張A
        (rune >= 0xF900 && rune <= 0xFAFF); // CJK互換漢字
  }

  /// ひらがなかどうか判定
  static bool isHiragana(int rune) {
    return rune >= 0x3040 && rune <= 0x309F;
  }

  /// カタカナかどうか判定
  static bool isKatakana(int rune) {
    return rune >= 0x30A0 && rune <= 0x30FF;
  }

  /// 助詞かどうか（簡易判定）
  static bool isParticle(String word) {
    const particles = [
      'は', 'が', 'を', 'に', 'へ', 'で', 'と', 'も', 'の', 'や',
      'か', 'な', 'よ', 'ね', 'わ', 'ぞ', 'ぜ', 'さ',
      'から', 'まで', 'より', 'して', 'ので', 'のに', 'けど',
      'けれど', 'けれども', 'ながら', 'たり', 'だり',
      'ば', 'ても', 'でも', 'のみ', 'だけ', 'ほど', 'くらい',
      'など', 'こそ', 'すら', 'さえ', 'しか', 'ばかり',
    ];
    return particles.contains(word);
  }

  /// 助動詞・接続詞かどうか（簡易判定）
  static bool isAuxiliaryOrConjunction(String word) {
    const words = [
      'する', 'される', 'した', 'して', 'しない', 'しなければ',
      'ある', 'ない', 'なる', 'なった', 'なければ', 'ならない',
      'いる', 'いた', 'いない', 'れる', 'られる',
      'できる', 'できない', 'です', 'ます', 'ました', 'ません',
      'だった', 'であり', 'である', 'でない', 'ではない',
      'また', 'そして', 'しかし', 'だが', 'ただし', 'なお',
      'つまり', 'すなわち', 'ところが', 'ところで',
      'それで', 'そこで', 'したがって', 'ゆえに',
      'および', 'ならびに', 'または', 'もしくは',
    ];
    return words.contains(word);
  }

  /// テキストから漢字連続を抽出（簡易形態素解析の代替）
  static List<WordPosition> extractKanjiWords(String text) {
    final words = <WordPosition>[];
    int? start;

    for (int i = 0; i < text.length; i++) {
      final rune = text.codeUnitAt(i);
      if (isKanji(rune)) {
        start ??= i;
      } else {
        if (start != null) {
          final word = text.substring(start, i);
          if (word.length >= 2) {
            words.add(WordPosition(
              word: word,
              startIndex: start,
              endIndex: i,
            ));
          }
          start = null;
        }
      }
    }
    // 末尾処理
    if (start != null) {
      final word = text.substring(start);
      if (word.length >= 2) {
        words.add(WordPosition(
          word: word,
          startIndex: start,
          endIndex: text.length,
        ));
      }
    }
    return words;
  }

  /// テキストからカタカナ連続を抽出
  static List<WordPosition> extractKatakanaWords(String text) {
    final words = <WordPosition>[];
    int? start;

    for (int i = 0; i < text.length; i++) {
      final rune = text.codeUnitAt(i);
      if (isKatakana(rune)) {
        start ??= i;
      } else {
        if (start != null) {
          final word = text.substring(start, i);
          if (word.length >= 3) {
            words.add(WordPosition(
              word: word,
              startIndex: start,
              endIndex: i,
            ));
          }
          start = null;
        }
      }
    }
    if (start != null) {
      final word = text.substring(start);
      if (word.length >= 3) {
        words.add(WordPosition(
          word: word,
          startIndex: start,
          endIndex: text.length,
        ));
      }
    }
    return words;
  }
}

class WordPosition {
  final String word;
  final int startIndex;
  final int endIndex;

  WordPosition({
    required this.word,
    required this.startIndex,
    required this.endIndex,
  });
}
