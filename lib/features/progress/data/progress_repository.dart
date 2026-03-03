import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../../../models/practice_session.dart';
import '../../../models/script.dart';
import '../domain/spaced_repetition.dart';

class ProgressRepository {
  static const String _boxName = 'practice_sessions';
  final Uuid _uuid = const Uuid();

  Box<PracticeSession> get _box => Hive.box<PracticeSession>(_boxName);

  Future<PracticeSession> addSession({
    required String scriptId,
    required String mode,
    required int level,
    required double score,
    int durationSeconds = 0,
    String? recognizedText,
  }) async {
    final session = PracticeSession(
      id: _uuid.v4(),
      scriptId: scriptId,
      mode: mode,
      level: level,
      score: score,
      durationSeconds: durationSeconds,
      recognizedText: recognizedText,
    );
    await _box.add(session);
    return session;
  }

  List<PracticeSession> getSessionsForScript(String scriptId) {
    return _box.values
        .where((s) => s.scriptId == scriptId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<PracticeSession> getRecentSessions(String scriptId, int count) {
    final sessions = getSessionsForScript(scriptId);
    return sessions.take(count).toList();
  }

  double getRecentAverageScore(String scriptId, {int count = 5}) {
    final sessions = getRecentSessions(scriptId, count);
    if (sessions.isEmpty) return 0;
    final total = sessions.fold<double>(0, (sum, s) => sum + s.score);
    return total / sessions.length;
  }

  /// 前回のセッションスコアを取得
  double? getPreviousScore(String scriptId, String mode) {
    final sessions = _box.values
        .where((s) => s.scriptId == scriptId && s.mode == mode)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (sessions.length < 2) return null;
    return sessions[1].score;
  }

  int getTotalDurationSeconds() {
    return _box.values.fold<int>(0, (sum, s) => sum + s.durationSeconds);
  }

  /// Script の進捗を更新
  Future<void> updateScriptProgress(Script script, double score, String mode, int level) async {
    script.practiceCount++;
    script.lastPracticedAt = DateTime.now();

    // 正答率更新（累計平均）
    script.correctRate = ((script.correctRate * (script.practiceCount - 1)) + score) / script.practiceCount;

    // 音声モード時のベストスコア
    if (mode == 'voice' && score > script.bestVoiceScore) {
      script.bestVoiceScore = score;
    }

    // レベル昇格判定
    if (mode == 'cloze' && score >= 80 && level == script.currentLevel && script.currentLevel < 4) {
      script.currentLevel++;
    }

    // スケジュール更新
    if (script.isTargetDateMode) {
      // 本番日モード: generatedSchedule に従う
      if (score >= 85) {
        script.scheduleIndex = (script.scheduleIndex + 1)
            .clamp(0, script.generatedSchedule.length - 1);
      } else {
        // 不合格: 翌日を臨時復習日として挿入
        final tomorrow = DateTime.now().add(const Duration(days: 1));
        final tomorrowDate =
            DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
        if (script.scheduleIndex + 1 < script.generatedSchedule.length) {
          script.generatedSchedule
              .insert(script.scheduleIndex + 1, tomorrowDate);
        } else {
          script.generatedSchedule.add(tomorrowDate);
        }
      }
      if (script.scheduleIndex < script.generatedSchedule.length) {
        script.nextReviewAt =
            script.generatedSchedule[script.scheduleIndex];
      }
    } else {
      // SM-2 モード（ペース係数適用）
      final srResult = SpacedRepetition.calculate(
        score: score,
        currentInterval: script.intervalDays,
        currentEaseFactor: script.easeFactor,
        pace: script.reviewPace,
      );
      script.intervalDays = srResult.intervalDays;
      script.easeFactor = srResult.easeFactor;
      script.nextReviewAt = srResult.nextReviewAt;
    }

    await script.save();
  }

  // --- 統計集計メソッド ---

  /// 指定期間のセッション一覧
  List<PracticeSession> getSessionsInRange(DateTime start, DateTime end) {
    return _box.values
        .where((s) => s.createdAt.isAfter(start) && s.createdAt.isBefore(end))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  /// 日別平均スコア（過去N日）
  Map<DateTime, double> getDailyAverageScores({int days = 30}) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day - days);
    final sessions = getSessionsInRange(start, now);

    final grouped = <DateTime, List<double>>{};
    for (final s in sessions) {
      final dayKey = DateTime(s.createdAt.year, s.createdAt.month, s.createdAt.day);
      grouped.putIfAbsent(dayKey, () => []).add(s.score);
    }

    return grouped.map((date, scores) =>
        MapEntry(date, scores.reduce((a, b) => a + b) / scores.length));
  }

  /// 日別学習時間（過去N日、秒単位）
  Map<DateTime, int> getDailyStudySeconds({int days = 7}) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day - days);
    final sessions = getSessionsInRange(start, now);

    final grouped = <DateTime, int>{};
    for (final s in sessions) {
      final dayKey = DateTime(s.createdAt.year, s.createdAt.month, s.createdAt.day);
      grouped[dayKey] = (grouped[dayKey] ?? 0) + s.durationSeconds;
    }
    return grouped;
  }

  /// 連続学習日数（ストリーク）
  int getStudyStreak() {
    final now = DateTime.now();
    var currentDay = DateTime(now.year, now.month, now.day);
    int streak = 0;

    // 今日学習したかチェック
    final todayHasSessions = _box.values.any((s) {
      final d = DateTime(s.createdAt.year, s.createdAt.month, s.createdAt.day);
      return d == currentDay;
    });

    if (!todayHasSessions) {
      // まだ今日学習していない場合、昨日から起算
      currentDay = currentDay.subtract(const Duration(days: 1));
    }

    while (true) {
      final dayHasSessions = _box.values.any((s) {
        final d = DateTime(s.createdAt.year, s.createdAt.month, s.createdAt.day);
        return d == currentDay;
      });
      if (!dayHasSessions) break;
      streak++;
      currentDay = currentDay.subtract(const Duration(days: 1));
    }

    return streak;
  }
}

final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  return ProgressRepository();
});
