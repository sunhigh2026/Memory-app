import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../data/scripts_repository.dart';
import '../../progress/data/progress_repository.dart';
import '../../../core/data/app_settings_repository.dart';
import '../../../models/script.dart';

import 'import_csv_dialog.dart';

Color levelColor(int level) {
  switch (level) {
    case 0:
      return AppTheme.grey500;
    case 1:
      return AppTheme.accent;
    case 2:
      return const Color(0xFF9C27B0); // パープル
    case 3:
      return AppTheme.primary;
    case 4:
      return AppTheme.secondary;
    case 5:
    case 6:
    case 7:
    case 8:
      return AppTheme.levelGold;
    default:
      return AppTheme.primary;
  }
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isSelectMode = false;
  final Set<String> _selectedScriptIds = {};

  void _toggleSelect(String id) {
    setState(() {
      if (_selectedScriptIds.contains(id)) {
        _selectedScriptIds.remove(id);
      } else {
        _selectedScriptIds.add(id);
      }
    });
  }

  void _selectAll(List<Script> scripts) {
    setState(() {
      _selectedScriptIds.clear();
      _selectedScriptIds.addAll(scripts.map((s) => s.id));
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedScriptIds.clear();
    });
  }

  void _exitSelectMode() {
    setState(() {
      _isSelectMode = false;
      _selectedScriptIds.clear();
    });
  }

  // 一括削除
  Future<void> _deleteSelected() async {
    if (_selectedScriptIds.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('一括削除の確認'),
        content: Text('選択した ${_selectedScriptIds.length} 件のテキストを削除しますか？\nこの操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('削除する'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final ids = _selectedScriptIds.toList();
      await ref.read(scriptsListProvider.notifier).deleteMultipleScripts(ids);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${ids.length} 件のテキストを削除しました')),
      );
      _exitSelectMode();
    }
  }

  // 一括本番日登録
  Future<void> _updateTargetDateSelected() async {
    if (_selectedScriptIds.isEmpty) return;
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );

    if (selectedDate != null && mounted) {
      final ids = _selectedScriptIds.toList();
      await ref.read(scriptsListProvider.notifier).updateTargetDateMultiple(ids, selectedDate);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${ids.length} 件のテキストに本番日を設定しました')),
      );
      _exitSelectMode();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scripts = ref.watch(scriptsListProvider);
    final progressRepo = ref.watch(progressRepositoryProvider);
    final selectedTags = ref.watch(selectedTagsProvider);
    final repo = ref.watch(scriptsRepositoryProvider);
    final allTags = repo.getAllTags();

    final goalMode = ref.watch(goalSettingModeProvider);
    final manualGoal = ref.watch(dailyGoalProvider);
    final selectedLevels = ref.watch(levelFilterProvider);
    final selectedRanks = ref.watch(rankFilterProvider);
    final sortMode = ref.watch(sortModeProvider);

    // タグフィルタ適用
    var filtered = selectedTags.isEmpty
        ? scripts
        : scripts
            .where((s) => s.tags.any((t) => selectedTags.contains(t)))
            .toList();

    // レベルフィルタ適用
    if (selectedLevels.isNotEmpty) {
      filtered = filtered.where((s) => selectedLevels.contains(s.currentLevel)).toList();
    }

    // ランクフィルタ適用
    if (selectedRanks.isNotEmpty) {
      filtered = filtered.where((s) => selectedRanks.contains(s.rank)).toList();
    }

    // 並び替えモードに応じてソート
    final filteredScripts = List<Script>.from(filtered)
      ..sort((a, b) {
        switch (sortMode) {
          case 'sortOrder':
            return a.sortOrder.compareTo(b.sortOrder);
          case 'level':
            return b.currentLevel.compareTo(a.currentLevel);
          case 'lastPracticed':
          default:
            final aTime = a.lastPracticedAt;
            final bTime = b.lastPracticedAt;
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime);
        }
      });

    // ダッシュボード用データ
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

    // AppBar の構築
    final PreferredSizeWidget appBar = _isSelectMode
        ? AppBar(
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: _exitSelectMode,
            ),
            title: Text('${_selectedScriptIds.length} 件選択中'),
            actions: [
              IconButton(
                icon: const Icon(Icons.select_all),
                tooltip: 'すべて選択',
                onPressed: () => _selectAll(filteredScripts),
              ),
              IconButton(
                icon: const Icon(Icons.deselect),
                tooltip: '選択解除',
                onPressed: _clearSelection,
              ),
            ],
          )
        : AppBar(
            title: Image.asset('assets/logo_text.png', height: 40, fit: BoxFit.fitHeight),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_note),
                tooltip: '一括操作',
                onPressed: () => setState(() => _isSelectMode = true),
              ),
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
          );

    return Scaffold(
      appBar: appBar,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // ダッシュボード
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _DashboardTile(
                              icon: Icons.local_fire_department,
                              iconColor: const Color(0xFFF97316),
                              label: '連続学習',
                              value: '$streakDays日',
                              sub: 'ストリーク',
                            ),
                          ),
                          const SizedBox(width: 8),
                          () {
                            final dailyGoal = goalMode == 'auto'
                                ? (reviewDueList.isEmpty ? 1 : reviewDueList.length)
                                : manualGoal;
                            final remainingGoal = (dailyGoal - todayCompletedCount).clamp(0, dailyGoal);
                            final isGoalAchieved = remainingGoal == 0;
                            return Expanded(
                              child: _DashboardTile(
                                icon: isGoalAchieved
                                    ? Icons.workspace_premium_rounded
                                    : Icons.assignment_turned_in_outlined,
                                iconColor: isGoalAchieved ? AppTheme.levelGold : AppTheme.primary,
                                label: '今日の目標',
                                value: isGoalAchieved ? '達成！ 🎉' : '残り $remainingGoal回',
                                sub: '今日の実績: $todayCompletedCount / $dailyGoal 回',
                                backgroundColor: isGoalAchieved
                                    ? AppTheme.levelGold.withValues(alpha: 0.05)
                                    : null,
                                borderColor: isGoalAchieved ? AppTheme.levelGold : null,
                              ),
                            );
                          }(),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _DashboardTile(
                              icon: Icons.refresh_rounded,
                              iconColor: const Color(0xFFF59E0B),
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
              // ソートとレベル・ランクフィルタ (タグの下にインライン配置)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Row(
                    children: [
                      // 左側：並び替えドロップダウン
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<String>(
                          value: sortMode,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: '並び替え',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                              borderSide: const BorderSide(color: AppTheme.grey300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                              borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                              borderSide: const BorderSide(color: AppTheme.grey300),
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'lastPracticed', child: Text('学習順', overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'sortOrder', child: Text('番号順', overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'level', child: Text('レベル順', overflow: TextOverflow.ellipsis)),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              ref.read(sortModeProvider.notifier).state = val;
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      // レベル複数選択ドロップダウン
                      Expanded(
                        flex: 4,
                        child: _MultiSelectDropdown<int>(
                          label: 'レベル',
                          values: selectedLevels,
                          items: const [0, 1, 2, 3, 4, 5, 6, 7, 8],
                          itemLabelBuilder: (val) => 'Lv$val',
                          onChanged: (newValues) {
                            ref.read(levelFilterProvider.notifier).state = newValues;
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      // ランク複数選択ドロップダウン
                      Expanded(
                        flex: 3,
                        child: _MultiSelectDropdown<String>(
                          label: 'ランク',
                          values: selectedRanks,
                          items: const ['S', 'A', 'B', 'C'],
                          itemLabelBuilder: (val) => val,
                          onChanged: (newValues) {
                            ref.read(rankFilterProvider.notifier).state = newValues;
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // 復習が必要セクション
              if (reviewDueList.isNotEmpty && !_isSelectMode)
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                        Icon(Icons.library_books, size: 64, color: AppTheme.grey300),
                        const SizedBox(height: 16),
                        Text(
                          selectedTags.isNotEmpty ||
                                  selectedLevels.isNotEmpty ||
                                  selectedRanks.isNotEmpty
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
                  padding: EdgeInsets.only(
                      left: 16, right: 16, bottom: _isSelectMode ? 100 : 80),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final script = filteredScripts[index];
                        final isSelected = _selectedScriptIds.contains(script.id);
                        
                        return Row(
                          children: [
                            if (_isSelectMode)
                              Checkbox(
                                value: isSelected,
                                onChanged: (value) => _toggleSelect(script.id),
                              ),
                            Expanded(
                              child: _ScriptCard(
                                script: script,
                                isSelectMode: _isSelectMode,
                                isSelected: isSelected,
                                onLongPress: () {
                                  if (!_isSelectMode) {
                                    setState(() {
                                      _isSelectMode = true;
                                      _selectedScriptIds.add(script.id);
                                    });
                                  }
                                },
                                onTap: () {
                                  if (_isSelectMode) {
                                    _toggleSelect(script.id);
                                  } else {
                                    context.push('/detail/${script.id}');
                                  }
                                },
                              ),
                            ),
                          ],
                        );
                      },
                      childCount: filteredScripts.length,
                    ),
                  ),
                ),
            ],
          ),
          // 一括アクションバー（選択モード中のみ表示）
          if (_isSelectMode)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(30),
                color: AppTheme.primary,
                child: Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_selectedScriptIds.length} 件選択中',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.calendar_month, color: Colors.white),
                            tooltip: '本番日一括登録',
                            onPressed: _selectedScriptIds.isEmpty
                                ? null
                                : _updateTargetDateSelected,
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.white),
                            tooltip: '一括削除',
                            onPressed: _selectedScriptIds.isEmpty
                                ? null
                                : _deleteSelected,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _isSelectMode
          ? null
          : FloatingActionButton(
              onPressed: () => context.push('/add'),
              child: const Icon(Icons.add),
            ),
    );
  }
}

class _DashboardTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String sub;
  final Color? backgroundColor;
  final Color? borderColor;

  const _DashboardTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.sub,
    this.backgroundColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecoration.copyWith(
        color: backgroundColor ?? Colors.white,
        border: borderColor != null ? Border.all(color: borderColor!, width: 1.5) : null,
      ),
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${script.sortOrder}. ${script.title}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  if (script.rank.isNotEmpty) ...[
                    _buildMiniRankBadge(script.rank),
                    const SizedBox(width: 4),
                  ],
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
                        const Icon(Icons.local_fire_department,
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

  Widget _buildMiniRankBadge(String rank) {
    Color color;
    switch (rank) {
      case 'S':
        color = const Color(0xFFD4AF37); // ゴールド
        break;
      case 'A':
        color = AppTheme.primary; // インディゴ
        break;
      case 'B':
        color = AppTheme.secondary; // ティール
        break;
      case 'C':
      default:
        color = AppTheme.grey500; // グレー
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm / 2),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
      ),
      child: Text(
        rank,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _ScriptCard extends ConsumerWidget {
  final Script script;
  final bool isSelectMode;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _ScriptCard({
    required this.script,
    this.isSelectMode = false,
    this.isSelected = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastPracticed = script.lastPracticedAt != null
        ? _timeAgo(script.lastPracticedAt!)
        : '未学習';
    final progress = script.progressPercent;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: AppTheme.cardDecoration.copyWith(
        border: isSelected
            ? Border.all(color: AppTheme.primary, width: 1.5)
            : null,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${script.sortOrder}. ${script.title}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (script.rank.isNotEmpty) ...[
                    _buildRankBadge(script.rank),
                    const SizedBox(width: 6),
                  ],
                  _buildLevelBadge(script.currentLevel),
                ],
              ),
              if (script.tags.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
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
                    script.currentLevel >= 4
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

  // ランクバッジ（色分け）
  Widget _buildRankBadge(String rank) {
    Color color;
    switch (rank) {
      case 'S':
        color = const Color(0xFFD4AF37); // ゴールド
        break;
      case 'A':
        color = AppTheme.primary; // インディゴ
        break;
      case 'B':
        color = AppTheme.secondary; // ティール
        break;
      case 'C':
      default:
        color = AppTheme.grey500; // グレー
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Text(
        rank,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // レベルバッジ（色分け）
  Widget _buildLevelBadge(int level) {
    final color = levelColor(level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_fire_department, size: 12, color: Colors.white),
          const SizedBox(width: 2),
          Text(
            '$level',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}


class _MultiSelectDropdown<T> extends StatefulWidget {
  final String label;
  final Set<T> values;
  final List<T> items;
  final String Function(T) itemLabelBuilder;
  final ValueChanged<Set<T>> onChanged;

  const _MultiSelectDropdown({
    required this.label,
    required this.values,
    required this.items,
    required this.itemLabelBuilder,
    required this.onChanged,
  });

  @override
  State<_MultiSelectDropdown<T>> createState() => _MultiSelectDropdownState<T>();
}

class _MultiSelectDropdownState<T> extends State<_MultiSelectDropdown<T>> {
  final GlobalKey _buttonKey = GlobalKey();

  void _showMenu(BuildContext context) async {
    final RenderBox renderBox = _buttonKey.currentContext!.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    final rect = RelativeRect.fromLTRB(
      offset.dx,
      offset.dy + renderBox.size.height,
      offset.dx + renderBox.size.width,
      offset.dy + renderBox.size.height + 200,
    );

    // 一時的に選択状態をコピー
    final tempSelected = Set<T>.from(widget.values);

    await showMenu<T>(
      context: context,
      position: rect,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.grey200),
      ),
      items: [
        PopupMenuItem<T>(
          enabled: false, // タップでメニューが閉じるのを防ぐ
          child: StatefulBuilder(
            builder: (context, menuSetState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 「すべて」クリアボタン
                  TextButton(
                    onPressed: tempSelected.isEmpty
                        ? null
                        : () {
                            menuSetState(() {
                              tempSelected.clear();
                            });
                            widget.onChanged(tempSelected);
                          },
                    child: const Text('クリア', style: TextStyle(fontSize: 12)),
                  ),
                  const Divider(height: 1),
                  ...widget.items.map((item) {
                    final isChecked = tempSelected.contains(item);
                    Color textColor = AppTheme.textDark;
                    FontWeight fontWeight = FontWeight.normal;
                    if (item is String && ['S', 'A', 'B', 'C'].contains(item)) {
                      fontWeight = FontWeight.bold;
                      switch (item) {
                        case 'S':
                          textColor = const Color(0xFFD4AF37);
                          break;
                        case 'A':
                          textColor = AppTheme.primary;
                          break;
                        case 'B':
                          textColor = AppTheme.secondary;
                          break;
                        case 'C':
                          textColor = AppTheme.grey500;
                          break;
                      }
                    }
                    return CheckboxListTile(
                      title: Text(
                        widget.itemLabelBuilder(item),
                        style: TextStyle(
                          fontSize: 14,
                          color: textColor,
                          fontWeight: fontWeight,
                        ),
                      ),
                      value: isChecked,
                      onChanged: (checked) {
                        menuSetState(() {
                          if (checked == true) {
                            tempSelected.add(item);
                          } else {
                            tempSelected.remove(item);
                          }
                        });
                        widget.onChanged(tempSelected);
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    );
                  }),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayText = widget.values.isEmpty
        ? 'すべて'
        : widget.values.map(widget.itemLabelBuilder).join(', ');

    return InkWell(
      key: _buttonKey,
      onTap: () => _showMenu(context),
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: widget.label,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppTheme.grey300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppTheme.primary, width: 2),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                displayText,
                style: const TextStyle(fontSize: 13, color: AppTheme.textDark),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const Icon(Icons.arrow_drop_down, size: 18, color: AppTheme.grey600),
          ],
        ),
      ),
    );
  }
}
