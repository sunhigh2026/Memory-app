import 'package:flutter_test/flutter_test.dart';
import 'package:memorization_app/features/practice/data/cloze_generator.dart';

void main() {
  group('ClozeGenerator Tests', () {
    late ClozeGenerator generator;

    setUp(() {
      generator = ClozeGenerator();
    });

    test('短いテキストで基本的な穴埋めが生成されること', () {
      final text = '基本設計と詳細設計を実施します。';
      final result = generator.generate(text, densityPercent: 20);

      expect(result, isNotEmpty);
      // 「基本設計」と「詳細設計」は漢字3文字以上なので優先的に選ばれるはず
      final words = result.map((cw) => cw.word).toList();
      expect(words.contains('基本設計') || words.contains('詳細設計'), isTrue);
    });

    test('長文においてテキストの後半（最後の文）からもバランスよく穴埋めが生成されること', () {
      final text =
          '新規開発プロジェクトにおいて、基本設計と詳細設計を実施し、進捗状況を細かく確認する。\n'
          '開発チーム全体で連携して、機能実装と画面レイアウトを決定する。\n'
          '最終的な動作確認とユーザーテストを完了させる。';

      // レベル1 (密度 20%) で生成
      final result = generator.generate(text, densityPercent: 20);

      // 各文に対応する文字インデックスの範囲
      // 文1: 新規開発プロジェクトにおいて、基本設計と詳細設計を実施し、進捗状況を細かく確認する。(改行含む) => 0 ~ 44
      // 文2: 開発チーム全体で連携して、機能実装と画面レイアウトを決定する。(改行含む) => 45 ~ 76
      // 文3: 最終的な動作確認とユーザーテストを完了させる。 => 77 ~ 99 (計100文字程度)

      // それぞれの文の範囲に穴埋めが存在するかチェック
      bool hasHoleInSentence1 = false;
      bool hasHoleInSentence2 = false;
      bool hasHoleInSentence3 = false;

      for (final cw in result) {
        if (cw.startIndex < 45) {
          hasHoleInSentence1 = true;
        } else if (cw.startIndex >= 45 && cw.startIndex < 77) {
          hasHoleInSentence2 = true;
        } else if (cw.startIndex >= 77) {
          hasHoleInSentence3 = true;
        }
      }

      // すべての文からバランスよく穴埋めが抽出されていることを検証
      expect(hasHoleInSentence1, isTrue, reason: '文1から穴埋めが生成されていません');
      expect(hasHoleInSentence2, isTrue, reason: '文2から穴埋めが生成されていません');
      expect(hasHoleInSentence3, isTrue, reason: '文3から穴埋めが生成されていません');
    });

    test('ピン留めされた単語は目標密度やブラックリストに関わらず必ず穴埋めに選ばれること', () {
      final text = '計画を作成します。';
      final pinned = ['計画']; // '計画' はブラックリストに含まれるため通常は選ばれない
      final result = generator.generate(text, densityPercent: 0, pinnedClozeWords: pinned);

      final words = result.map((cw) => cw.word).toList();
      expect(words, contains('計画'));
    });
  });
}
