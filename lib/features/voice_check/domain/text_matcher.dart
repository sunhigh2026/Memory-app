import 'dart:math';
import '../../../core/utils/text_normalizer.dart';
import '../../../models/allowed_pair.dart';

/// テキストマッチング結果
class MatchResult {
  final double similarityScore;
  final List<DiffSegment> diffSegments;
  final String normalizedOriginal;
  final String normalizedRecognized;

  MatchResult({
    required this.similarityScore,
    required this.diffSegments,
    required this.normalizedOriginal,
    required this.normalizedRecognized,
  });

  String get scoreLabel {
    if (similarityScore >= 95) return '完璧！';
    if (similarityScore >= 85) return 'ほぼ完璧！';
    if (similarityScore >= 70) return 'もう少し！';
    return '練習が必要';
  }
}

/// Diff の各セグメント
enum DiffType { match, missing, extra, replace, allowed }

class DiffSegment {
  final DiffType type;
  final String text;
  final String? replacement; // replace 時の置換テキスト
  final String? hiraganaReading; // allowed 時のひらがな読み

  DiffSegment({
    required this.type,
    required this.text,
    this.replacement,
    this.hiraganaReading,
  });
}

/// テキストマッチングアルゴリズム
class TextMatcher {
  /// ひらがな正規化＋許容ペア適用による比較（スコアはひらがなベース）
  Future<MatchResult> matchAsync(
    String original,
    String recognized, {
    ParenthesesMode parentheses = ParenthesesMode.keep,
    String cachedOriginalHiragana = '',
    List<AllowedPair> allowedPairs = const [],
  }) async {
    // Step 1: ひらがな正規化（スコア計算用）
    String hiraOriginal = cachedOriginalHiragana;
    if (hiraOriginal.isEmpty) {
      hiraOriginal = await TextNormalizer.fullNormalize(
        original,
        parentheses: parentheses,
      );
    }
    String hiraRecognized = await TextNormalizer.fullNormalize(
      recognized,
      parentheses: parentheses,
    );

    // Step 2: 許容ペアを適用（認識テキスト内の許容語を原文側の語に置換）
    for (final pair in allowedPairs) {
      if (pair.recognizedHira.isNotEmpty) {
        hiraRecognized = hiraRecognized.replaceAll(
          pair.recognizedHira,
          pair.originalHira,
        );
      }
    }

    // Step 3: ひらがなベースのスコア計算
    final distance = _levenshteinDistance(hiraOriginal, hiraRecognized);
    final maxLen = max(hiraOriginal.length, hiraRecognized.length);
    final similarity = maxLen == 0 ? 100.0 : (1 - distance / maxLen) * 100;

    // Step 4: 漢字ベースの差分（表示用）
    final normOriginal =
        TextNormalizer.normalize(original, parentheses: parentheses);
    final normRecognized =
        TextNormalizer.normalize(recognized, parentheses: parentheses);
    final diffSegments = _computeDiff(normOriginal, normRecognized);

    // Step 5: replace セグメントのうち許容ペアに該当するものを allowed に変換
    final processedSegments = <DiffSegment>[];
    for (final seg in diffSegments) {
      if (seg.type == DiffType.replace &&
          seg.replacement != null &&
          allowedPairs.isNotEmpty) {
        final matchingPair = allowedPairs.cast<AllowedPair?>().firstWhere(
              (p) =>
                  p!.originalWord == seg.text &&
                  p.recognizedWord == seg.replacement,
              orElse: () => null,
            );
        if (matchingPair != null) {
          processedSegments.add(DiffSegment(
            type: DiffType.allowed,
            text: seg.text,
            replacement: seg.replacement,
            hiraganaReading: matchingPair.originalHira.isNotEmpty
                ? matchingPair.originalHira
                : null,
          ));
          continue;
        }
      }
      processedSegments.add(seg);
    }

    return MatchResult(
      similarityScore: similarity.clamp(0, 100),
      diffSegments: processedSegments,
      normalizedOriginal: normOriginal,
      normalizedRecognized: normRecognized,
    );
  }

  /// 原文と認識テキストを比較（同期版、後方互換）
  MatchResult match(
    String original,
    String recognized, {
    ParenthesesMode parentheses = ParenthesesMode.keep,
  }) {
    final normOriginal =
        TextNormalizer.normalize(original, parentheses: parentheses);
    final normRecognized =
        TextNormalizer.normalize(recognized, parentheses: parentheses);

    final distance = _levenshteinDistance(normOriginal, normRecognized);
    final maxLen = max(normOriginal.length, normRecognized.length);
    final similarity = maxLen == 0 ? 100.0 : (1 - distance / maxLen) * 100;

    final diffSegments = _computeDiff(normOriginal, normRecognized);

    return MatchResult(
      similarityScore: similarity.clamp(0, 100),
      diffSegments: diffSegments,
      normalizedOriginal: normOriginal,
      normalizedRecognized: normRecognized,
    );
  }

  /// レーベンシュタイン距離
  int _levenshteinDistance(String s, String t) {
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    final m = s.length;
    final n = t.length;
    final dp = List.generate(m + 1, (_) => List.filled(n + 1, 0));

    for (int i = 0; i <= m; i++) {
      dp[i][0] = i;
    }
    for (int j = 0; j <= n; j++) {
      dp[0][j] = j;
    }

    for (int i = 1; i <= m; i++) {
      for (int j = 1; j <= n; j++) {
        final cost = s[i - 1] == t[j - 1] ? 0 : 1;
        dp[i][j] = [
          dp[i - 1][j] + 1,
          dp[i][j - 1] + 1,
          dp[i - 1][j - 1] + cost,
        ].reduce(min);
      }
    }
    return dp[m][n];
  }

  /// LCS ベースの差分検出
  List<DiffSegment> _computeDiff(String original, String recognized) {
    final lcs = _lcs(original, recognized);
    final segments = <DiffSegment>[];

    int oi = 0, ri = 0, li = 0;

    while (oi < original.length || ri < recognized.length) {
      if (li < lcs.length && oi < original.length && ri < recognized.length && original[oi] == lcs[li] && recognized[ri] == lcs[li]) {
        final matchStart = oi;
        while (li < lcs.length && oi < original.length && ri < recognized.length && original[oi] == lcs[li] && recognized[ri] == lcs[li]) {
          oi++;
          ri++;
          li++;
        }
        segments.add(DiffSegment(
          type: DiffType.match,
          text: original.substring(matchStart, oi),
        ));
      } else {
        final origStart = oi;
        final recStart = ri;

        while (oi < original.length && (li >= lcs.length || original[oi] != lcs[li])) {
          oi++;
        }
        while (ri < recognized.length && (li >= lcs.length || recognized[ri] != lcs[li])) {
          ri++;
        }

        final origPart = original.substring(origStart, oi);
        final recPart = recognized.substring(recStart, ri);

        if (origPart.isNotEmpty && recPart.isNotEmpty) {
          segments.add(DiffSegment(
            type: DiffType.replace,
            text: origPart,
            replacement: recPart,
          ));
        } else if (origPart.isNotEmpty) {
          segments.add(DiffSegment(
            type: DiffType.missing,
            text: origPart,
          ));
        } else if (recPart.isNotEmpty) {
          segments.add(DiffSegment(
            type: DiffType.extra,
            text: recPart,
          ));
        }
      }
    }

    return segments;
  }

  /// 最長共通部分列 (LCS)
  String _lcs(String a, String b) {
    final m = a.length;
    final n = b.length;
    final dp = List.generate(m + 1, (_) => List.filled(n + 1, 0));

    for (int i = 1; i <= m; i++) {
      for (int j = 1; j <= n; j++) {
        if (a[i - 1] == b[j - 1]) {
          dp[i][j] = dp[i - 1][j - 1] + 1;
        } else {
          dp[i][j] = max(dp[i - 1][j], dp[i][j - 1]);
        }
      }
    }

    final buffer = StringBuffer();
    int i = m, j = n;
    while (i > 0 && j > 0) {
      if (a[i - 1] == b[j - 1]) {
        buffer.write(a[i - 1]);
        i--;
        j--;
      } else if (dp[i - 1][j] > dp[i][j - 1]) {
        i--;
      } else {
        j--;
      }
    }

    return buffer.toString().split('').reversed.join();
  }
}
