import 'dart:math';
import '../../../core/utils/text_normalizer.dart';

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
enum DiffType { match, missing, extra, replace }

class DiffSegment {
  final DiffType type;
  final String text;
  final String? replacement; // replace 時の置換テキスト

  DiffSegment({
    required this.type,
    required this.text,
    this.replacement,
  });
}

/// テキストマッチングアルゴリズム
class TextMatcher {
  /// 原文と認識テキストを比較
  MatchResult match(
    String original,
    String recognized, {
    ParenthesesMode parentheses = ParenthesesMode.keep,
  }) {
    // Step 1: 正規化
    final normOriginal =
        TextNormalizer.normalize(original, parentheses: parentheses);
    final normRecognized =
        TextNormalizer.normalize(recognized, parentheses: parentheses);

    // Step 2: 類似度スコア計算（レーベンシュタイン距離）
    final distance = _levenshteinDistance(normOriginal, normRecognized);
    final maxLen = max(normOriginal.length, normRecognized.length);
    final similarity = maxLen == 0 ? 100.0 : (1 - distance / maxLen) * 100;

    // Step 3: 差分検出（LCS ベース）
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
        // 一致
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
        // 不一致部分を収集
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
          // 置換
          segments.add(DiffSegment(
            type: DiffType.replace,
            text: origPart,
            replacement: recPart,
          ));
        } else if (origPart.isNotEmpty) {
          // 欠落
          segments.add(DiffSegment(
            type: DiffType.missing,
            text: origPart,
          ));
        } else if (recPart.isNotEmpty) {
          // 余分
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

    // LCS を復元
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
