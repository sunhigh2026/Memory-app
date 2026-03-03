/// 本番日から逆算した復習スケジュールを生成
class ScheduleGenerator {
  /// startDate から targetDate までの復習スケジュールを生成
  ///
  /// 3フェーズ構成:
  /// - Phase 1（覚える期間、前1/3）: 1〜2日おき
  /// - Phase 2（定着期間、中1/3）: 2〜4日おき
  /// - Phase 3（仕上げ期間、後1/3）: 1〜2日おき
  /// 前日は必ず含む
  static List<DateTime> generate({
    required DateTime startDate,
    required DateTime targetDate,
  }) {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final target = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final totalDays = target.difference(start).inDays;

    if (totalDays <= 0) return [start];
    if (totalDays <= 3) {
      return List.generate(
        totalDays,
        (i) => start.add(Duration(days: i + 1)),
      );
    }

    final schedule = <DateTime>[];

    final phase1End = (totalDays * 0.33).floor();
    final phase2End = (totalDays * 0.67).floor();

    // Phase 1: 覚える期間 → 1〜2日おき
    int day = 1;
    while (day <= phase1End) {
      schedule.add(start.add(Duration(days: day)));
      day += (totalDays > 14) ? 2 : 1;
    }

    // Phase 2: 定着期間 → 2〜4日おき
    day = phase1End + 1;
    while (day <= phase2End) {
      schedule.add(start.add(Duration(days: day)));
      day += (totalDays > 21) ? 4 : 2;
    }

    // Phase 3: 仕上げ期間 → 1〜2日おき
    day = phase2End + 1;
    while (day < totalDays) {
      schedule.add(start.add(Duration(days: day)));
      day += (totalDays > 14) ? 2 : 1;
    }

    // 前日は必ず入れる
    final dayBefore = target.subtract(const Duration(days: 1));
    if (!schedule.any((d) =>
        d.year == dayBefore.year &&
        d.month == dayBefore.month &&
        d.day == dayBefore.day)) {
      schedule.add(dayBefore);
    }

    // 重複除去してソート
    final seen = <String>{};
    final unique = <DateTime>[];
    for (final d in schedule) {
      final key = '${d.year}-${d.month}-${d.day}';
      if (seen.add(key)) unique.add(d);
    }
    unique.sort();
    return unique;
  }
}
