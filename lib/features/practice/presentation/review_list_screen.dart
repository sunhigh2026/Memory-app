import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../scripts/data/scripts_repository.dart';
import '../../../models/script.dart';
import 'review_session_provider.dart';

class ReviewListScreen extends ConsumerStatefulWidget {
  const ReviewListScreen({super.key});

  @override
  ConsumerState<ReviewListScreen> createState() => _ReviewListScreenState();
}

class _ReviewListScreenState extends ConsumerState<ReviewListScreen> {
  final Set<String> _selectedTags = {};

  @override
  Widget build(BuildContext context) {
    final scripts = ref.watch(scriptsListProvider);

    // 全ての復習予定を過ぎているものと未学習のもの
    final rawReviewDueList = scripts.where((s) => s.isReviewDue).toList();
    final rawInitialCheckList = scripts.where((s) => s.practiceCount == 0).toList();

    // 今日取り組むべきテキストに関連するすべてのタグを抽出
    final availableTags = <String>{};
    for (final s in rawReviewDueList) {
      availableTags.addAll(s.tags);
    }
    for (final s in rawInitialCheckList) {
      availableTags.addAll(s.tags);
    }
    final sortedAvailableTags = availableTags.toList()..sort();

    // タグによる絞り込みを適用
    final filteredReviewDueList = rawReviewDueList.where((s) {
      if (_selectedTags.isEmpty) return true;
      return s.tags.any((t) => _selectedTags.contains(t));
    }).toList()
      ..sort((a, b) =>
          b.reviewOverdueDuration.compareTo(a.reviewOverdueDuration));

    final filteredInitialCheckList = rawInitialCheckList.where((s) {
      if (_selectedTags.isEmpty) return true;
      return s.tags.any((t) => _selectedTags.contains(t));
    }).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final totalCount = filteredReviewDueList.length + filteredInitialCheckList.length;

    // まとめてセッションを開始する処理
    void startContinuousSession() {
      if (totalCount == 0) return;

      final allIds = [
        ...filteredReviewDueList.map((s) => s.id),
        ...filteredInitialCheckList.map((s) => s.id),
      ];

      // セッション状態を初期化
      ref.read(reviewSessionProvider.notifier).startSession(allIds);

      // 最初のスクリプトのレベル2練習画面へ遷移
      context.pushReplacement('/practice/${allIds.first}/2');
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('今日の学習'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: Column(
        children: [
          // 上部のアクションエリア
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '今日取り組むテキスト',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.grey600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '合計 $totalCount 件',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        _TaskCountBadge(
                          label: '復習',
                          count: filteredReviewDueList.length,
                          color: const Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 8),
                        _TaskCountBadge(
                          label: '初回',
                          count: filteredInitialCheckList.length,
                          color: AppTheme.primary,
                        ),
                      ],
                    ),
                  ],
                ),
                if (sortedAvailableTags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: sortedAvailableTags.length,
                      separatorBuilder: (_, index) => const SizedBox(width: 6),
                      itemBuilder: (context, index) {
                        final tag = sortedAvailableTags[index];
                        final isSelected = _selectedTags.contains(tag);
                        final colors = AppTheme.tagColor(tag);
                        return FilterChip(
                          label: Text(
                            tag,
                            style: TextStyle(
                              fontSize: 11,
                              color: isSelected ? colors.text : AppTheme.grey600,
                            ),
                          ),
                          selected: isSelected,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          selectedColor: colors.background,
                          backgroundColor: colors.background.withValues(alpha: 0.4),
                          checkmarkColor: colors.text,
                          side: BorderSide(
                            color: isSelected ? colors.text : AppTheme.grey300,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedTags.add(tag);
                              } else {
                                _selectedTags.remove(tag);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: totalCount > 0 ? startContinuousSession : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppTheme.grey200,
                      disabledForegroundColor: AppTheme.grey400,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded, size: 24),
                    label: const Text(
                      'まとめて復習を開始 (Lv.2 固定)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // リストエリア
          Expanded(
            child: totalCount == 0
                ? _buildEmptyState()
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (filteredReviewDueList.isNotEmpty) ...[
                        _buildSectionHeader('復習待ち', filteredReviewDueList.length, const Color(0xFFF59E0B)),
                        ...filteredReviewDueList.map((script) => _ReviewTaskCard(
                              script: script,
                              onTap: () {
                                final allIds = [
                                  ...filteredReviewDueList.map((s) => s.id),
                                  ...filteredInitialCheckList.map((s) => s.id),
                                ];
                                final index = allIds.indexOf(script.id);
                                ref.read(reviewSessionProvider.notifier).startSession(
                                  allIds,
                                  startIndex: index >= 0 ? index : 0,
                                );
                                context.push('/practice/${script.id}/2');
                              },
                            )),
                        const SizedBox(height: 24),
                      ],
                      if (filteredInitialCheckList.isNotEmpty) ...[
                        _buildSectionHeader('初回チェック待ち', filteredInitialCheckList.length, AppTheme.primary),
                        ...filteredInitialCheckList.map((script) => _ReviewTaskCard(
                              script: script,
                              onTap: () {
                                final allIds = [
                                  ...filteredReviewDueList.map((s) => s.id),
                                  ...filteredInitialCheckList.map((s) => s.id),
                                ];
                                final index = allIds.indexOf(script.id);
                                ref.read(reviewSessionProvider.notifier).startSession(
                                  allIds,
                                  startIndex: index >= 0 ? index : 0,
                                );
                                context.push('/practice/${script.id}/2');
                              },
                            )),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '($count)',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.grey500,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.secondary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline_rounded,
              size: 64,
              color: AppTheme.secondary,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '今日の課題はすべて完了！',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedTags.isNotEmpty
                ? '選択したタグの課題はすべて完了しています。'
                : '素晴らしい！今日の復習と初回チェックは\nすべて完了しています。',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.grey500,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskCountBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _TaskCountBadge({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewTaskCard extends StatelessWidget {
  final Script script;
  final VoidCallback onTap;

  const _ReviewTaskCard({
    required this.script,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final lastPracticed = script.lastPracticedAt != null
        ? _timeAgo(script.lastPracticedAt!)
        : '未学習';
    final progress = script.progressPercent;

    // 期限切れ情報の計算
    final overdueDays = script.reviewOverdueDuration.inDays;
    final overdueText = overdueDays > 0 ? '$overdueDays日経過' : '今日';
    final badgeColor = overdueDays >= 3 ? AppTheme.error : const Color(0xFFF59E0B);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: AppTheme.cardDecoration,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        onTap: onTap,
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
                  const SizedBox(width: 8),
                  if (script.rank.isNotEmpty) ...[
                    _buildRankBadge(script.rank),
                    const SizedBox(width: 6),
                  ],
                  _buildLevelBadge(script.currentLevel),
                  // 初回チェック待ちか復習待ちかのステータスバッジ
                  if (script.practiceCount == 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: const Text(
                        '初回',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ] else if (script.isReviewDue) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: Text(
                        overdueText,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
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

  // ランクバッジ（色分け）- HomeScreenと完全統一
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

  // レベルバッジ（色分け）- HomeScreenと完全統一
  Widget _buildLevelBadge(int level) {
    final color = _levelColor(level);
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
            'Lv.$level',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Color _levelColor(int level) {
    switch (level) {
      case 0:
        return AppTheme.grey500;
      case 1:
        return AppTheme.accent;
      case 2:
        return const Color(0xFF9C27B0);
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

  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'たった今';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分前';
    if (diff.inHours < 24) return '${diff.inHours}時間前';
    if (diff.inDays < 7) return '${diff.inDays}日前';
    return '${(diff.inDays / 7).floor()}週間前';
  }
}
