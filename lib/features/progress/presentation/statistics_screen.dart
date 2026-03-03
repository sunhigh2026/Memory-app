import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_theme.dart';
import '../../scripts/data/scripts_repository.dart';
import '../data/progress_repository.dart';

class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scripts = ref.watch(scriptsListProvider);
    final progressRepo = ref.watch(progressRepositoryProvider);

    final totalStudySeconds = progressRepo.getTotalDurationSeconds();
    final masteredCount = scripts.where((s) => s.isMastered).length;
    final streak = progressRepo.getStudyStreak();
    final dailyScores = progressRepo.getDailyAverageScores(days: 30);
    final dailyStudy = progressRepo.getDailyStudySeconds(days: 7);

    return Scaffold(
      appBar: AppBar(title: const Text('学習統計')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // サマリーカード
          _SummarySection(
            scriptCount: scripts.length,
            masteredCount: masteredCount,
            totalStudySeconds: totalStudySeconds,
            streak: streak,
          ),
          const SizedBox(height: 24),
          // スコア推移
          _ScoreTrendSection(dailyScores: dailyScores),
          const SizedBox(height: 24),
          // 学習時間
          _StudyTimeSection(dailyStudy: dailyStudy),
          const SizedBox(height: 24),
          // スクリプト別進捗
          _ScriptProgressSection(
            scripts: scripts,
            progressRepo: progressRepo,
          ),
        ],
      ),
    );
  }
}

/// サマリーカード4枚
class _SummarySection extends StatelessWidget {
  final int scriptCount;
  final int masteredCount;
  final int totalStudySeconds;
  final int streak;

  const _SummarySection({
    required this.scriptCount,
    required this.masteredCount,
    required this.totalStudySeconds,
    required this.streak,
  });

  @override
  Widget build(BuildContext context) {
    final hours = (totalStudySeconds / 3600).toStringAsFixed(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '概要',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _SummaryCard(
              icon: Icons.library_books,
              label: '登録数',
              value: '$scriptCount',
              color: AppTheme.primary,
            ),
            const SizedBox(width: 10),
            _SummaryCard(
              icon: Icons.emoji_events,
              label: 'マスター',
              value: '$masteredCount',
              color: const Color(0xFFD4AF37),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _SummaryCard(
              icon: Icons.timer,
              label: '総学習時間',
              value: '${hours}h',
              color: AppTheme.secondary,
            ),
            const SizedBox(width: 10),
            _SummaryCard(
              icon: Icons.local_fire_department,
              label: '連続日数',
              value: '$streak日',
              color: AppTheme.accent,
            ),
          ],
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 過去30日のスコア推移（折れ線グラフ）
class _ScoreTrendSection extends StatelessWidget {
  final Map<DateTime, double> dailyScores;

  const _ScoreTrendSection({required this.dailyScores});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'スコア推移（30日）',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 200,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: dailyScores.isEmpty
              ? const Center(
                  child: Text(
                    'データがありません',
                    style: TextStyle(color: AppTheme.textLight),
                  ),
                )
              : _buildLineChart(),
        ),
      ],
    );
  }

  Widget _buildLineChart() {
    final sortedEntries = dailyScores.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final now = DateTime.now();
    final baseDay = DateTime(now.year, now.month, now.day - 30);

    final spots = sortedEntries.map((e) {
      final dayIndex = e.key.difference(baseDay).inDays.toDouble();
      return FlSpot(dayIndex, e.value);
    }).toList();

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 100,
        minX: 0,
        maxX: 30,
        gridData: FlGridData(
          show: true,
          horizontalInterval: 25,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.grey[200]!,
            strokeWidth: 1,
          ),
          drawVerticalLine: false,
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: 25,
              getTitlesWidget: (value, meta) => Text(
                '${value.toInt()}',
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: 7,
              getTitlesWidget: (value, meta) {
                final day = baseDay.add(Duration(days: value.toInt()));
                return Text(
                  '${day.month}/${day.day}',
                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                );
              },
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppTheme.primary,
            barWidth: 2.5,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, _, _, _) => FlDotCirclePainter(
                radius: 3,
                color: AppTheme.primary,
                strokeWidth: 0,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: AppTheme.primary.withValues(alpha: 0.1),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
              final day = baseDay.add(Duration(days: spot.x.toInt()));
              return LineTooltipItem(
                '${day.month}/${day.day}: ${spot.y.toStringAsFixed(0)}%',
                const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

/// 過去7日の学習時間（棒グラフ）
class _StudyTimeSection extends StatelessWidget {
  final Map<DateTime, int> dailyStudy;

  const _StudyTimeSection({required this.dailyStudy});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '学習時間（7日）',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 180,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: _buildBarChart(),
        ),
      ],
    );
  }

  Widget _buildBarChart() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = <String>[];
    final minutes = <double>[];

    for (int i = 6; i >= 0; i--) {
      final day = today.subtract(Duration(days: i));
      days.add('${day.month}/${day.day}');
      final seconds = dailyStudy[day] ?? 0;
      minutes.add(seconds / 60.0);
    }

    final maxMinutes = minutes.isEmpty
        ? 10.0
        : minutes.reduce((a, b) => a > b ? a : b).clamp(10.0, double.infinity);

    return BarChart(
      BarChartData(
        maxY: maxMinutes * 1.2,
        alignment: BarChartAlignment.spaceAround,
        gridData: FlGridData(
          show: true,
          horizontalInterval: maxMinutes / 4,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.grey[200]!,
            strokeWidth: 1,
          ),
          drawVerticalLine: false,
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: maxMinutes / 4,
              getTitlesWidget: (value, meta) => Text(
                '${value.toInt()}m',
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= days.length) return const SizedBox();
                return Text(
                  days[idx],
                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                );
              },
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(7, (i) {
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: minutes[i],
                color: AppTheme.secondary,
                width: 20,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${rod.toY.toStringAsFixed(1)}分',
                const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// スクリプト別進捗リスト
class _ScriptProgressSection extends StatelessWidget {
  final List scripts;
  final ProgressRepository progressRepo;

  const _ScriptProgressSection({
    required this.scripts,
    required this.progressRepo,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'スクリプト別進捗',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 12),
        if (scripts.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                'スクリプトがありません',
                style: TextStyle(color: AppTheme.textLight),
              ),
            ),
          )
        else
          ...scripts.map((script) {
            final recentAvg =
                progressRepo.getRecentAverageScore(script.id, count: 5);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _levelColor(script.currentLevel),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        'L${script.currentLevel}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          script.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '練習${script.practiceCount}回 · 直近平均${recentAvg.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${script.progressPercent.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _levelColor(script.currentLevel),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Color _levelColor(int level) {
    switch (level) {
      case 1:
        return AppTheme.accent;
      case 2:
        return AppTheme.primary;
      case 3:
        return AppTheme.secondary;
      case 4:
        return const Color(0xFFD4AF37);
      default:
        return AppTheme.primary;
    }
  }
}
