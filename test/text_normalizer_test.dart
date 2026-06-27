import 'package:flutter_test/flutter_test.dart';
import 'package:memorization_app/core/utils/text_normalizer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TextNormalizer.levenshtein', () {
    test('同じ文字列の距離は0', () {
      expect(TextNormalizer.levenshtein('あいうえお', 'あいうえお'), 0);
    });

    test('1文字置換の距離は1', () {
      expect(TextNormalizer.levenshtein('ひようせいしさん', 'ひようせつしさん'), 1);
    });

    test('1文字挿入の距離は1', () {
      expect(TextNormalizer.levenshtein('あいうえ', 'あいうえお'), 1);
    });

    test('1文字削除の距離は1', () {
      expect(TextNormalizer.levenshtein('あいうえお', 'あいうえ'), 1);
    });

    test('全く異なる文字列の距離はそれぞれの長さ', () {
      expect(TextNormalizer.levenshtein('あか', 'あお'), 1); // 1文字置換
      expect(TextNormalizer.levenshtein('', 'あいうえお'), 5);
    });
  });

  group('TextNormalizer.maxAllowedDistance', () {
    test('3文字以下は0（完全一致のみ）', () {
      expect(TextNormalizer.maxAllowedDistance(1), 0);
      expect(TextNormalizer.maxAllowedDistance(2), 0);
      expect(TextNormalizer.maxAllowedDistance(3), 0);
    });

    test('4〜6文字は1', () {
      expect(TextNormalizer.maxAllowedDistance(4), 1);
      expect(TextNormalizer.maxAllowedDistance(5), 1);
      expect(TextNormalizer.maxAllowedDistance(6), 1);
    });

    test('7文字以上は20%（ただし最低1）', () {
      expect(TextNormalizer.maxAllowedDistance(7), 1); // 7 * 0.20 = 1.4 -> 1
      expect(TextNormalizer.maxAllowedDistance(8), 1); // 8 * 0.20 = 1.6 -> 1
      expect(TextNormalizer.maxAllowedDistance(9), 1); // 9 * 0.20 = 1.8 -> 1
      expect(TextNormalizer.maxAllowedDistance(10), 2); // 10 * 0.20 = 2 -> 2
      expect(TextNormalizer.maxAllowedDistance(15), 3); // 15 * 0.20 = 3 -> 3
    });
  });

  group('TextNormalizer.isFuzzyMatch', () {
    test('ひようせいしさん vs ひようせつしさん (8文字, 1字違い) はマッチする', () {
      expect(TextNormalizer.isFuzzyMatch('ひようせつしさん', 'ひようせいしさん'), true);
    });

    test('あか vs あお (2文字, 1字違い) はマッチしない', () {
      expect(TextNormalizer.isFuzzyMatch('あか', 'あお'), false);
    });

    test('にほんご vs にほん (4文字, 1字削除) はマッチする', () {
      expect(TextNormalizer.isFuzzyMatch('にほん', 'にほんご'), true);
    });

    test('にほんご vs しほんご (4文字, 1字置換) はマッチする', () {
      expect(TextNormalizer.isFuzzyMatch('しほんご', 'にほんご'), true);
    });

    test('にほんご vs しほん (4文字, 2字違い) はマッチしない', () {
      expect(TextNormalizer.isFuzzyMatch('しほん', 'にほんご'), false);
    });
  });

  group('TextNormalizer.normalize (丸数字・記号除去のテスト)', () {
    test('丸数字や中黒、ダッシュが除去されること', () {
      expect(TextNormalizer.normalize('①費用・便益'), '費用便益');
      expect(TextNormalizer.normalize('①あ・い-う―え'), 'あいうえ');
    });

    test('NFCとNFDの濁音文字列が正規化後に一致すること', () {
      final nfcText = 'がぎぐげご';
      final nfdText = 'か\u3099き\u3099く\u3099け\u3099こ\u3099';
      expect(TextNormalizer.normalize(nfcText) == TextNormalizer.normalize(nfdText), isTrue);
    });

    test('toHiraganaが漢字を正しくひらがなに変換できること', () async {
      final hira = await TextNormalizer.toHiragana('負債');
      expect(hira, 'ふさい');
    });

    test('ゼロ幅スペースやBOMなどの不可視文字が除去されること', () {
      expect(TextNormalizer.normalize('負\u200B債\u200Cが\u200Dぎ\uFEFFぐげご'), '負債がぎぐげご');
    });

    test('fullNormalizeがカタカナ混じり漢字テキストを正しくひらがな化できること', () async {
      final norm = await TextNormalizer.fullNormalize('パソコン監査');
      expect(norm, 'ぱそこんかんさ');
    });
  });

  group('TextNormalizer.hotwordsCorrection', () {
    test('generateHotwordsMapが正味の名詞を抽出してマップを生成すること', () async {
      final text = '委託者は受託者に対して、権利を主張できる。これやそれは除外される。';
      final map = await TextNormalizer.generateHotwordsMap(text);
      
      // 名詞かつ2文字以上のものが含まれる
      expect(map['いたくしゃ'], '委託者');
      expect(map['じゅたくしゃ'], '受託者');
      expect(map['けんり'], '権利');
      
      // 代名詞の「これ」「それ」や助詞などは含まれない
      expect(map.containsKey('これ'), isFalse);
      expect(map.containsKey('それ'), isFalse);
      expect(map.containsKey('は'), isFalse);
    });

    test('距離1の誤変換が正しく補正される (痛く者 -> 委託者)', () async {
      final hotwords = {'いたくしゃ': '委託者'};
      final corrected = await TextNormalizer.correctRecognizedText('痛く者です', hotwords);
      expect(corrected, '委託者です');
    });

    test('距離2以上の場合は補正されず素のまま戻る', () async {
      final hotwords = {'いたくしゃ': '委託者'};
      // 「全く別な」 -> 「いたくしゃ」への距離は大幅に離れている
      final corrected = await TextNormalizer.correctRecognizedText('全く別なです', hotwords);
      expect(corrected, '全く別なです');
    });

    test('多義箇所で距離が一意に最小なら採用される', () async {
      final hotwords = {
        'いたくしゃ': '委託者',
        'じゅたくしゃ': '受託者',
      };
      // 「いたくし」 -> 「いたくしゃ」(距離1), 「じゅたくしゃ」(距離2)
      // 最小距離は1（一意）なので補正される
      final corrected = await TextNormalizer.correctRecognizedText('いたくしです', hotwords);
      expect(corrected, '委託者です');
    });

    test('多義箇所で最小距離が同距離タイなら補正されない', () async {
      final hotwords = {
        'いたくしゃ': '委託者',
        'おたくしゃ': '御託者',
      };
      // 「うたくしゃ」 -> 「いたくしゃ」(距離1), 「おたくしゃ」(距離1)
      // 最小距離1だがタイなので補正されない
      final corrected = await TextNormalizer.correctRecognizedText('うたくしゃです', hotwords);
      expect(corrected, 'うたくしゃです');
    });

    test('補正対象が無い場合は入力がそのまま返る', () async {
      final hotwords = <String, String>{};
      final corrected = await TextNormalizer.correctRecognizedText('テストです', hotwords);
      expect(corrected, 'テストです');
    });

    test('距離0でかつ表記も同じ場合は置換は発生しない（補正不要）', () async {
      final hotwords = {'いたくしゃ': '委託者'};
      final corrected = await TextNormalizer.correctRecognizedText('委託者です', hotwords);
      expect(corrected, '委託者です');
    });
  });

  group('TextNormalizer.normalize (追加された記号類のテスト)', () {
    test('「」『』などのカッコ記号が除去されること', () {
      expect(TextNormalizer.normalize('「費用」『便益』'), '費用便益');
      expect(TextNormalizer.normalize('【費用】[便益]'), '費用便益');
    });
  });

  group('TextNormalizer.fuzzyNormalize (超曖昧化処理のテスト)', () {
    test('長音、濁点・半濁点、小書きのかなが通常化されること', () {
      expect(TextNormalizer.fuzzyNormalize('さーばー'), 'さは'); // 長音除去 + 清音化
      expect(TextNormalizer.fuzzyNormalize('いっちゃく'), 'いつちやく'); // 促音・拗音の通常化
      expect(TextNormalizer.fuzzyNormalize('ぱそこん'), 'はそこん'); // 半濁点清音化
    });
  });

  group('TextNormalizer.isFuzzyMatch (照合の厳しさレベル別のテスト)', () {
    test('やさしい（easy）モードはより大きな揺れを許容する', () {
      // 「さーばー」 vs 「さーば」は長音除去により完全一致する
      expect(TextNormalizer.isFuzzyMatch('さーばー', 'さーば', strictness: 'strict'), true);

      // 「プロトコル」 (5文字) に対して 「プロトコ」 (4文字) は1文字違い
      // きびしい（strict）: 5文字以下は 0 文字許容（完全一致のみ）なので false
      expect(TextNormalizer.isFuzzyMatch('ぷろとこ', 'ぷろとこる', strictness: 'strict'), false);
      
      // ふつう（normal）: 4〜6文字は1文字許容なので true
      expect(TextNormalizer.isFuzzyMatch('ぷろとこ', 'ぷろとこる', strictness: 'normal'), true);

      // 「データベース」(6文字) に対して 「デタベス」 (4文字) は2文字違い（長音除外後）
      // 「でたべす」と「データベース」の長音除外ひらがなはそれぞれ「でたべす」と「でたべす」になるため長音抜きだと一致する。
      // なので、長音以外で2文字ずれたものでテストする：
      // 「ぷろとこる」に対して「ぷろとこあん」は2文字違い。
      // ふつう（normal）: 4〜6文字は1文字許容なので false
      expect(TextNormalizer.isFuzzyMatch('ぷろとこあん', 'ぷろとこる', strictness: 'normal'), false);
      
      // やさしい（easy）: 4〜6文字は2文字許容なので true
      expect(TextNormalizer.isFuzzyMatch('ぷろとこあん', 'ぷろとこる', strictness: 'easy'), true);
    });
  });
}
