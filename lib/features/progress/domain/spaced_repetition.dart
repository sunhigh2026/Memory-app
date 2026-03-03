import 'dart:math';

/// SM-2 間隔反復学習アルゴリズム
class SpacedRepetition {
  /// 練習スコア（0-100）→ SM-2 品質（0-5）に変換
  static int scoreToQuality(double score) {
    if (score >= 95) return 5; // 完璧
    if (score >= 85) return 4; // ほぼ正解
    if (score >= 70) return 3; // 正解だが困難
    if (score >= 50) return 2; // 不正解だが近い
    if (score >= 25) return 1; // 不正解、少し覚えている
    return 0; // 完全に忘れた
  }

  /// SM-2 アルゴリズムで次回復習パラメータを算出
  static SpacedRepetitionResult calculate({
    required double score,
    required double currentInterval,
    required double currentEaseFactor,
  }) {
    final quality = scoreToQuality(score);

    // EF 更新: EF' = EF + (0.1 - (5-q) * (0.08 + (5-q) * 0.02))
    double newEaseFactor = currentEaseFactor +
        (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
    newEaseFactor = max(1.3, newEaseFactor);

    double newInterval;
    if (quality < 3) {
      // 不合格: 間隔を1日にリセット
      newInterval = 1.0;
    } else {
      if (currentInterval <= 0) {
        newInterval = 1.0;
      } else if (currentInterval < 6) {
        newInterval = 6.0;
      } else {
        newInterval = currentInterval * newEaseFactor;
      }
    }

    final nextReviewAt = DateTime.now().add(
      Duration(hours: (newInterval * 24).round()),
    );

    return SpacedRepetitionResult(
      intervalDays: newInterval,
      easeFactor: newEaseFactor,
      nextReviewAt: nextReviewAt,
      quality: quality,
    );
  }
}

class SpacedRepetitionResult {
  final double intervalDays;
  final double easeFactor;
  final DateTime nextReviewAt;
  final int quality;

  SpacedRepetitionResult({
    required this.intervalDays,
    required this.easeFactor,
    required this.nextReviewAt,
    required this.quality,
  });
}
