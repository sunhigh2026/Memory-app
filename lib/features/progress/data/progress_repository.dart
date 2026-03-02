import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../../../models/practice_session.dart';
import '../../../models/script.dart';

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

    await script.save();
  }
}

final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  return ProgressRepository();
});
