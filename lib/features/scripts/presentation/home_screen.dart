import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../data/scripts_repository.dart';
import '../../progress/data/progress_repository.dart';
import '../../../models/script.dart';

import 'import_csv_dialog.dart';

// Section 1-B: トップレベル関数として _levelColor() を統合
Color levelColor(int level) {
  switch (level) {
    case 0:
      return AppTheme.grey500;
    case 1:
      return AppTheme.accent;
    case 2:
      return AppTheme.primary;
    case 3:
      return AppTheme.secondary;
    case 4:
      return AppTheme.levelGold;
    default:
      return AppTheme.primary;
  }
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scripts = ref.watch(scriptsListProvider);
    final progressRepo = ref.watch(progressRepositoryProvider);
    final selectedTags = ref.watch(selectedTagsProvider);
    final repo = ref.watch(scriptsRepositoryProvider);
    final allTags = repo.getAllTags();

    // タグフィルタ適用
    final filteredScripts = selectedTags.isEmpty
        ? scripts
        : scripts
            .where((s) => s.tags.any((t) => selectedTags.contains(t)))
            .toList();

    // Section 10: ダッシュボード用データ
    final streakDays = progressRepo.getStudyStreak();
    final reviewDueList = scripts
        .where((s) => s.isReviewDue)
        .toList()
      ..sort((a, b) =>
          b.reviewOverdueDuration.compareTo(a.reviewOverdueDuration));

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todaySessions = progressRepo.getSessionsInRange(todayStart, now);
    final todayCompletedCount = todaySessions.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('暗リピ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload),
            tooltip: 'CSVインポート',
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const ImportCsvDialog(),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Section 10: 新ダッシュボード
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // 上段: ストリーク + 今日の目標
                  Row(
                    children: [
                      Expanded(
                        child: _DashboardTile(
                          icon: Icons.local_fire_department,
                          iconColor: Color(0xFFF97316),
                          label: '連続学習',
                          value: '$streakDays日',
                          sub: 'ストリーク',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _DashboardTile(
                          icon: Icons.assignment_turned_in_outlined,
                          iconColor: AppTheme.primary,
                          label: '今日の目標',
                          value: reviewDueList.isEmpty ? '完了 ✓' : '残り ${reviewDueList.length}件',
                          sub: '今日の実績: $todayCompletedCount回',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Section 10-C: 中段: 要復習 + 学習統計リンクタイル
                  Row(
                    children: [
                      Expanded(
                        child: _DashboardTile(
                          icon: Icons.refresh_rounded,
                          iconColor: Color(0xFFF59E0B),
                          label: '要復習',
                          value: '${reviewDueList.length}件',
                          sub: '期限切れ',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => context.push('/statistics'),
                          child: _DashboardTile(
                            icon: Icons.bar_chart_rounded,
                            iconColor: AppTheme.secondary,
                            label: '学習統計',
                            value: '詳細を見る',
                            sub: '→ タップ',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 下段: よく間違える語
                  () {
                    final mistakesMap = <String, int>{};
                    for (final s in scripts) {
                      final mMap = s.mistakeWords ?? {};
                      mMap.forEach((word, count) {
                        mistakesMap[word] = (mistakesMap[word] ?? 0) + count;
                      });
                    }
                    final sortedMistakes = mistakesMap.entries.toList()
                      ..sort((a, b) => b.value.compareTo(a.value));
                    final topMistakes = sortedMistakes.take(5).map((e) => e.key).toList();
                    return _MistakesSummaryCard(mistakes: topMistakes);
                  }(),
                ],
              ),
            ),
          ),
          // タグフィルタ
          if (allTags.isNotEmpty)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 48,
                child: ListView.separated(
                  shrinkWrap: true,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: allTags.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (context, index) {
                    final tag = allTags[index];
                    final isSelected = selectedTags.contains(tag);
                    final colors = AppTheme.tagColor(tag);
                    return FilterChip(
                      label: Text(
                        tag,
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected ? colors.text : AppTheme.grey600,
                        ),
                      ),
                      selected: isSelected,
                      materialTapTargetSize: MaterialTapTargetSize.padded,
                      selectedColor: colors.background,
                      backgroundColor: colors.background.withValues(alpha: 0.4),
                      checkmarkColor: colors.text,
                      side: BorderSide(
                        color: isSelected ? colors.text : AppTheme.grey300,
                      ),
                      onSelected: (selected) {
                        final current =
                            Set<String>.from(ref.read(selectedTagsProvider));
                        if (selected) {
                          current.add(tag);
                        } else {
                          current.remove(tag);
                        }
                        ref.read(selectedTagsProvider.notifier).state = current;
                      },
                    );
                  },
                ),
              ),
            ),
          if (allTags.isNotEmpty)
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
          // 復習が必要セクション
          if (reviewDueList.isNotEmpty)
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    // Section 10-H: 件数部分のみカラー強調
                    child: Text.rich(
                      TextSpan(
                        text: '復習が必要（',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                        ),
                        children: [
                          TextSpan(
                            text: '${reviewDueList.length}件',
                            style: const TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const TextSpan(text: '）'),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 100,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: reviewDueList.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        return _ReviewDueCard(script: reviewDueList[index]);
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          // 文章リスト
          if (filteredScripts.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.library_books,
                        size: 64, color: AppTheme.grey300),
                    const SizedBox(height: 16),
                    Text(
                      selectedTags.isNotEmpty
                          ? '該当するテキストがありません'
                          : 'テキストを追加して\n暗記を始めましょう',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: AppTheme.grey500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              // Section 10-G: FAB 被り防止
              padding: const EdgeInsets.only(
                  left: 16, right: 16, bottom: 80),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return _ScriptCard(script: filteredScripts[index]);
                  },
                  childCount: filteredScripts.length,
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/add'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// Section 10-A: ダッシュボードタイル（丸アイコン背景 + statNumber）
class _DashboardTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String sub;

  const _DashboardTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecoration,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label, style: AppTheme.sectionHeader),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: AppTheme.statNumber),
          const SizedBox(height: 4),
          Text(sub,
              style: const TextStyle(fontSize: 12, color: AppTheme.grey500)),
        ],
      ),
    );
  }
}

// Section 10-B: よく間違える語サマリーカード（Icon使用）
class _MistakesSummaryCard extends StatelessWidget {
  final List<String> mistakes;

  const _MistakesSummaryCard({required this.mistakes});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: AppTheme.cardDecoration,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: AppTheme.grey500, size: 16),
              const SizedBox(width: 6),
              const Text('よく間違える語', style: AppTheme.sectionHeader),
            ],
          ),
          const SizedBox(height: 12),
          if (mistakes.isEmpty)
            const Text(
              'まだデータがありません',
              style: TextStyle(fontSize: 13, color: AppTheme.grey400),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: mistakes
                  .map((word) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.grey200,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSm),
                        ),
                        child: Text(word,
                            style: const TextStyle(
                                fontSize: 13, color: AppTheme.grey600)),
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }
}

// Section 1-E: _ReviewDueCard — cardDecoration + InkWell (4-D)
class _ReviewDueCard extends StatelessWidget {
  final Script script;

  const _ReviewDueCard({required this.script});

  @override
  Widget build(BuildContext context) {
    final overdueDays = script.reviewOverdueDuration.inDays;
    final hasTarget = script.hasTargetDate;
    final targetUrgent = hasTarget && script.daysUntilTarget <= 3;
    final isUrgent = targetUrgent || overdueDays >= 3;
    final badgeColor = isUrgent ? AppTheme.error : AppTheme.accent;

    // Section 4-D: GestureDetector → InkWell でリップルを追加
    return Container(
      width: 150,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: badgeColor.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        onTap: () => context.push('/detail/${script.id}'),
        child: Padding(
          // Section 2: horizontal:6,vertical:2 → horizontal:8,vertical:4
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      script.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  // Section 9: レベルバッジ リデザイン
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: levelColor(script.currentLevel),
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.local_fire_department,
                            size: 12,
                            color: Colors.white),
                        const SizedBox(width: 2),
                        Text(
                          '${script.currentLevel}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 14, color: badgeColor),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          overdueDays == 0 ? '今日が復習日' : '$overdueDays日超過',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: badgeColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (hasTarget)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        targetUrgent
                            ? 'まもなく本番'
                            : '本番まで${script.daysUntilTarget}日',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: targetUrgent
                              ? AppTheme.error
                              : AppTheme.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Section 1-E: _ScriptCard — Card → Container(cardDecoration)
class _ScriptCard extends ConsumerWidget {
  final Script script;

  const _ScriptCard({required this.script});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastPracticed = script.lastPracticedAt != null
        ? _timeAgo(script.lastPracticedAt!)
        : '未学習';
    final progress = script.progressPercent;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: AppTheme.cardDecoration,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        onTap: () => context.push('/detail/${script.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      script.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Section 9: レベルバッジ リデザイン
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: levelColor(script.currentLevel),
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.local_fire_department,
                            size: 12, color: Colors.white),
                        const SizedBox(width: 2),
                        Text(
                          '${script.currentLevel}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // タグ表示
              if (script.tags.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  runSpacing: 4, // Section 2: 2 → 4
                  children: script.tags.take(3).map((tag) {
                    final tc = AppTheme.tagColor(tag);
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: tc.background,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSm / 2),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          fontSize: 10,
                          color: tc.text,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 10),
              // プログレスバー
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress / 100,
                  backgroundColor: AppTheme.grey200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    levelColor(script.currentLevel),
                  ),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    script.currentLevel == 4
                        ? 'ベストスコア: ${script.bestVoiceScore.toStringAsFixed(0)}%'
                        : script.lastPracticedAt == null
                            ? '未学習'
                            : '最終学習: $lastPracticed',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.grey500,
                    ),
                  ),
                  Text(
                    '${progress.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: levelColor(script.currentLevel),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'たった今';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分前';
    if (diff.inHours < 24) return '${diff.inHours}時間前';
    if (diff.inDays < 7) return '${diff.inDays}日前';
    return '${(diff.inDays / 7).floor()}週間前';
  }
}
