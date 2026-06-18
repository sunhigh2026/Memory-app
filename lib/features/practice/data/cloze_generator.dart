import 'dart:math';
import '../../../core/utils/japanese_utils.dart';
import '../../../models/cloze_word.dart';

/// 高度なルールベースによる自動穴埋め生成
class ClozeGenerator {
  final Random _random = Random();

  // 穴埋め問題として暗記する価値の低い漢字2文字語（ブラックリスト）
  static const Set<String> _blacklistedWords = {
    // 指示詞・形式名詞・代名詞
    'これ', 'それ', 'あれ', 'どれ', 'この', 'その', 'あの', 'どの',
    'ここ', 'そこ', 'あそこ', 'どこ', 'こちら', 'そちら', 'あちら', 'どちら',
    'こと', 'もの', 'とき', 'ため', 'よう', 'そう', 'わけ', 'うち', 'なか',
    '自分', '自身', '自ら', '彼ら', '彼女', '相手', 'これら', 'それら',
    // 汎用名詞（時間・場所・数量）
    '今回', '前回', '次回', '今度', '最初', '最後', '最終', '途中', '前後',
    '左右', '上下', '内外', '内側', '外側', '内部', '外部', '中心', '周辺',
    '一部', '全部', '全体', '個別', '共通', '一般', '特殊', '基本', '詳細',
    '日付', '日時', '年度', '期間', '時間', '日数', '月数', '年数', '回数',
    '件数', '人数', '数量', '金額', '割合', '程度', '範囲', '限度', '基準',
    // 汎用名詞（ドキュメント・システム動作・処理）
    '記述', '記載', '記入', '説明', '表示', '画面', '動作', '実行', '処理',
    '設定', '変更', '追加', '削除', '登録', '選択', '指定', '確認', '終了',
    '開始', '完了', '経過', '結果', '影響', '理由', '原因', '対策', '状況',
    '状態', '項目', '内容', '対象', '規定', '条件', '目的', '方法',
    '手続', '場合', '監査', '検査', '調査', '分析', '把握', '検討', '決定',
    '合意', '承認', '許可', '認可', '届出', '申請', '報告', '提出', '期限',
    '定義', '意義', '意味', '分類', '区分', '関係', '関連', '効果',
    '役割', '機能', '特徴', '性質', '構造', '組織', '体制', '制度', '法律',
    '規則', '規程', '細則', '方針', '手順', '計画', '実施', '評価', '管理',
    '運用', '活用', '導入', '構築', '整備', '向上', '改善', '解決', '支援',
    // 会計・実務などで除外したい汎用2文字語
    '企業', '活動', '取引', '発生', '認識', '測定', '開示', '提供',
    '有用', '意思', '判断', '算定', '計算', '作成', 'その他',
    '公表', '閲覧', '縦覧', '送信', '受信', '入力', '出力', '部分',
    'データ', 'ソフト', 'ハード', 'ネット', 'ウェブ', 'サイト', 'ページ',
  };

  /// ダミーの初期化メソッド（practice_screen.dart 側との互換性維持のため）
  static Future<void> initialize() async {
    // 形態素解析ライブラリの廃止に伴い、処理は行いません
  }

  /// テキストから穴埋め対象語を自動生成
  /// [densityPercent]: 穴埋め密度 (5-30, デフォルト15)
  /// [pinnedClozeWords]: 必ず穴埋めにする語のリスト（ブラックリストに載っていても強制的に含める）
  List<ClozeWord> generate(String text, {
    int densityPercent = 15,
    List<String> pinnedClozeWords = const [],
  }) {
    // 1. テキスト全体から出現頻度マップを作成（重要用語判定の精度維持のため）
    final globalKanji = JapaneseUtils.extractKanjiWords(text);
    final globalKatakana = JapaneseUtils.extractKatakanaWords(text);
    final frequencyMap = <String, int>{};
    for (final wp in [...globalKanji, ...globalKatakana]) {
      frequencyMap[wp.word] = (frequencyMap[wp.word] ?? 0) + 1;
    }

    // 2. テキストを文（句点、感嘆符、疑問符、改行など）ごとに分割
    final segments = _splitIntoSentences(text);
    final selected = <ClozeWord>[];

    for (final segment in segments) {
      final segmentText = segment.text;
      final offset = segment.startIndex;

      if (segmentText.isEmpty) continue;

      // 漢字語とカタカナ語を抽出
      final kanjiWords = JapaneseUtils.extractKanjiWords(segmentText);
      final katakanaWords = JapaneseUtils.extractKatakanaWords(segmentText);

      // 候補を統合
      final allCandidates = <WordPosition>[];
      allCandidates.addAll(kanjiWords);
      allCandidates.addAll(katakanaWords);

      // 助詞・助動詞・接続詞を除外
      allCandidates.removeWhere((wp) =>
          JapaneseUtils.isParticle(wp.word) ||
          JapaneseUtils.isAuxiliaryOrConjunction(wp.word));

      // ブラックリストの除外（pinnedWordsは除外しない）
      allCandidates.removeWhere((wp) =>
          _blacklistedWords.contains(wp.word) &&
          !pinnedClozeWords.contains(wp.word));

      // 2文字の漢字語で接尾辞的な特徴を持つ語の簡易除外（pinnedWordsは除外しない）
      allCandidates.removeWhere((wp) {
        final w = wp.word;
        if (pinnedClozeWords.contains(w)) return false;
        if (w.length == 2) {
          if (w.endsWith('的') || w.endsWith('化') || w.endsWith('性')) {
            return true;
          }
        }
        return false;
      });

      // 重複除去（同じ開始位置の語は1つだけ）
      final seen = <int>{};
      final uniqueCandidates = <WordPosition>[];
      for (final wp in allCandidates) {
        if (!seen.contains(wp.startIndex)) {
          seen.add(wp.startIndex);
          uniqueCandidates.add(wp);
        }
      }

      // 優先度ソート
      uniqueCandidates.sort((a, b) {
        final aIsPinned = pinnedClozeWords.contains(a.word);
        final bIsPinned = pinnedClozeWords.contains(b.word);
        if (aIsPinned != bIsPinned) return aIsPinned ? -1 : 1;

        final aIsLong = (JapaneseUtils.extractKanjiWords(a.word).isNotEmpty && a.word.length >= 3) ||
                        (JapaneseUtils.extractKatakanaWords(a.word).isNotEmpty && a.word.length >= 4);
        final bIsLong = (JapaneseUtils.extractKanjiWords(b.word).isNotEmpty && b.word.length >= 3) ||
                        (JapaneseUtils.extractKatakanaWords(b.word).isNotEmpty && b.word.length >= 4);

        if (aIsLong != bIsLong) {
          return aIsLong ? -1 : 1;
        }

        final freqA = frequencyMap[a.word] ?? 0;
        final freqB = frequencyMap[b.word] ?? 0;
        final priorityA = (freqA >= 1 && freqA <= 3) ? 0 : 1;
        final priorityB = (freqB >= 1 && freqB <= 3) ? 0 : 1;
        if (priorityA != priorityB) return priorityA.compareTo(priorityB);

        return a.startIndex.compareTo(b.startIndex);
      });

      // セグメントごとの目標文字数
      final targetClozeChars = (segmentText.length * densityPercent / 100).round();
      int currentClozeChars = 0;

      final segmentSelected = <ClozeWord>[];
      for (final wp in uniqueCandidates) {
        final isPinned = pinnedClozeWords.contains(wp.word);
        // ピン留め語は密度を超えても必ず含める
        if (!isPinned && currentClozeChars >= targetClozeChars) break;
        // 重複チェック
        final overlaps = segmentSelected.any((cw) =>
            (wp.startIndex >= cw.startIndex && wp.startIndex < cw.endIndex) ||
            (wp.endIndex > cw.startIndex && wp.endIndex <= cw.endIndex));
        if (overlaps) continue;

        segmentSelected.add(ClozeWord(
          startIndex: wp.startIndex + offset, // 絶対位置へマッピング
          endIndex: wp.endIndex + offset,     // 絶対位置へマッピング
          word: wp.word,
          isAutoGenerated: !isPinned,
        ));
        currentClozeChars += wp.word.length;
      }
      selected.addAll(segmentSelected);
    }

    // 全セグメントの穴埋め語を位置順にソートして返却
    selected.sort((a, b) => a.startIndex.compareTo(b.startIndex));
    return selected;
  }

  /// テキストを文（句点、感嘆符、疑問符、改行など）ごとに分割する補助メソッド
  List<_SentenceSegment> _splitIntoSentences(String text) {
    final segments = <_SentenceSegment>[];
    int start = 0;
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      if (char == '。' || char == '！' || char == '？' || char == '\n') {
        final segmentText = text.substring(start, i + 1);
        segments.add(_SentenceSegment(segmentText, start));
        start = i + 1;
      }
    }
    if (start < text.length) {
      segments.add(_SentenceSegment(text.substring(start), start));
    }
    return segments;
  }

  /// Level に応じた穴埋め密度を返す
  static int densityForLevel(int level) {
    switch (level) {
      case 1:
        return 20;
      case 2:
        return 40;
      case 3:
        return 60;
      default:
        return 15;
    }
  }

  /// 選択肢（4択）を生成
  List<String> generateChoices(String correctAnswer, List<ClozeWord> allClozeWords) {
    final choices = <String>{correctAnswer};

    // 他の穴埋め語から選択肢を追加
    final otherWords = allClozeWords
        .where((cw) => cw.word != correctAnswer)
        .map((cw) => cw.word)
        .toList()
      ..shuffle(_random);

    for (final word in otherWords) {
      if (choices.length >= 4) break;
      choices.add(word);
    }

    // まだ足りない場合はダミー追加
    final dummyWords = ['対象', '規定', '条件', '手続', '権限', '義務', '責任', '制度'];
    for (final dummy in dummyWords..shuffle(_random)) {
      if (choices.length >= 4) break;
      if (!choices.contains(dummy)) {
        choices.add(dummy);
      }
    }

    final result = choices.toList()..shuffle(_random);
    return result;
  }
}

class _SentenceSegment {
  final String text;
  final int startIndex;
  _SentenceSegment(this.text, this.startIndex);
}