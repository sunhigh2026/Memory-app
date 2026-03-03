import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../data/scripts_repository.dart';
import '../../progress/data/progress_repository.dart';
import '../../../models/script.dart';

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

    final totalStudySeconds = progressRepo.getTotalDurationSeconds();
    final totalHours = (totalStudySeconds / 3600).toStringAsFixed(1);
    final masteredCount = scripts.where((s) => s.isMastered).length;
    final avgCorrectRate = scripts.isEmpty
        ? 0.0
        : scripts.fold<double>(0, (sum, s) => sum + s.correctRate) /
            scripts.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('暗記サポート'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          // 統計サマリー
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _StatCard(
                  label: '総学習',
                  value: '${totalHours}h',
                  icon: Icons.timer,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  label: '正答率',
                  value: '${avgCorrectRate.toStringAsFixed(0)}%',
                  icon: Icons.check_circle_outline,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  label: 'マスター',
                  value: '$masteredCount/${scripts.length}',
                  icon: Icons.emoji_events,
                ),
              ],
            ),
          ),
          // タグフィルタ
          if (allTags.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: allTags.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final tag = allTags[index];
                  final isSelected = selectedTags.contains(tag);
                  return FilterChip(
                    label: Text(tag, style: const TextStyle(fontSize: 12)),
                    selected: isSelected,
                    selectedColor: AppTheme.primary.withValues(alpha: 0.2),
                    checkmarkColor: AppTheme.primary,
                    side: BorderSide(
                      color: isSelected
                          ? AppTheme.primary
                          : Colors.grey[300]!,
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
          if (allTags.isNotEmpty) const SizedBox(height: 8),
          // 文章リスト
          Expanded(
            child: filteredScripts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.library_books,
                            size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          selectedTags.isNotEmpty
                              ? '該当するテキストがありません'
                              : 'テキストを追加して\n暗記を始めましょう',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredScripts.length,
                    itemBuilder: (context, index) {
                      return _ScriptCard(script: filteredScripts[index]);
                    },
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

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
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
        child: Column(
          children: [
            Icon(icon, color: AppTheme.primary, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScriptCard extends ConsumerWidget {
  final Script script;

  const _ScriptCard({required this.script});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastPracticed = _timeAgo(script.lastPracticedAt);
    final progress = script.progressPercent;

    return Card(
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _levelColor(script.currentLevel),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'L${script.currentLevel}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                // タグ表示
                if (script.tags.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 2,
                    children: script.tags.take(3).map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
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
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _levelColor(script.currentLevel),
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
                          : '最終学習: $lastPracticed',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                    Text(
                      '${progress.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _levelColor(script.currentLevel),
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

  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'たった今';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分前';
    if (diff.inHours < 24) return '${diff.inHours}時間前';
    if (diff.inDays < 7) return '${diff.inDays}日前';
    return '${(diff.inDays / 7).floor()}週間前';
  }
}
