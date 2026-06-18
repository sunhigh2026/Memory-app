import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/section_header.dart';
import '../data/scripts_repository.dart';
import '../../tts/presentation/tts_player_widget.dart';
import '../../voice_check/data/allowed_pairs_repository.dart';
import '../../progress/domain/schedule_generator.dart';
import '../../../models/script.dart';

class ScriptDetailScreen extends ConsumerWidget {
  final String scriptId;

  const ScriptDetailScreen({super.key, required this.scriptId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scripts = ref.watch(scriptsListProvider);
    final script = scripts.cast<Script?>().firstWhere(
          (s) => s?.id == scriptId,
          orElse: () => null,
        );

    if (script == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('エラー')),
        body: const Center(child: Text('テキストが見つかりません')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('No. ${script.sortOrder} ${script.title}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => context.push('/edit/${script.id}'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // メタ情報
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _InfoChip(
                  icon: Icons.bar_chart,
                  label: 'Level ${script.currentLevel}',
                ),
                _InfoChip(
                  icon: Icons.repeat,
                  label: '${script.practiceCount}回練習',
                ),
                ...script.tags.map((tag) => _InfoChip(
                      icon: Icons.label_outline,
                      label: tag,
                    )),
              ],
            ),
            const SizedBox(height: 16),
            // 原文表示 — Section 1-E: outlineDecoration
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.outlineDecoration,
              child: SelectableText(
                script.content,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.8,
                  color: AppTheme.textDark,
                ),
                contextMenuBuilder: (context, editableTextState) {
                  final buttonItems = editableTextState.contextMenuButtonItems;
                  buttonItems.add(ContextMenuButtonItem(
                    label: '重要に追加',
                    onPressed: () async {
                      final selection = editableTextState.currentTextEditingValue.selection;
                      final text = editableTextState.currentTextEditingValue.text;
                      if (selection.isValid && !selection.isCollapsed) {
                        final selectedText = selection.textInside(text);
                        if (selectedText.isNotEmpty) {
                          final currentPinned = List<String>.from(script.pinnedClozeWords);
                          if (!currentPinned.contains(selectedText)) {
                            currentPinned.add(selectedText);
                            script.pinnedClozeWords = currentPinned;
                            await script.save();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('「$selectedText」を重要に追加しました')),
                              );
                              ref.read(scriptsListProvider.notifier).refresh();
                            }
                          }
                        }
                      }
                      editableTextState.hideToolbar();
                    },
                  ));
                  return AdaptiveTextSelectionToolbar.buttonItems(
                    anchors: editableTextState.contextMenuAnchors,
                    buttonItems: buttonItems,
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            // TTS プレイヤー
            TtsPlayerWidget(text: script.content),
            const SizedBox(height: 24),
            // アクションボタン
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showLevelSelectionBottomSheet(context, script),
                    icon: const Icon(Icons.edit_note),
                    label: const Text('穴埋め練習'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showVoiceLevelSelectionBottomSheet(context, script),
                    icon: const Icon(Icons.mic),
                    label: const Text('音声で確認'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.secondary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // ベストスコア表示
            if (script.bestVoiceScore > 0)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.scoreColor(script.bestVoiceScore)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(
                    color: AppTheme.scoreColor(script.bestVoiceScore)
                        .withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.emoji_events,
                      color: AppTheme.scoreColor(script.bestVoiceScore),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'ベストスコア: ${script.bestVoiceScore.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.scoreColor(script.bestVoiceScore),
                      ),
                    ),
                  ],
                ),
              ),
            // 本番日・復習ペース
            const SizedBox(height: 24),
            _TargetDateSection(script: script),
            // 重要（穴埋め固定）
            const SizedBox(height: 24),
            _PinnedClozeWordsSection(script: script),
            // 許容語リスト
            const SizedBox(height: 24),
            _AllowedPairsSection(scriptId: scriptId),
          ],
        ),
      ),
    );
  }

  void _showLevelSelectionBottomSheet(BuildContext context, Script script) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '練習レベルを選択',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            _buildLevelTile(
              context: context,
              level: 1,
              title: 'Level 1: 4択練習',
              description: '穴あき部分（約20%）に当てはまる語を4択から選んで回答します。初心者向け。',
              recommended: script.currentLevel == 1 || script.currentLevel == 0,
              scriptId: script.id,
            ),
            const SizedBox(height: 12),
            _buildLevelTile(
              context: context,
              level: 2,
              title: 'Level 2: キーボード入力',
              description: '穴あき部分（約40%）に当てはまる語をキーボードで直接入力します。中級者向け。',
              recommended: script.currentLevel == 2,
              scriptId: script.id,
            ),
            const SizedBox(height: 12),
            _buildLevelTile(
              context: context,
              level: 3,
              title: 'Level 3: 高難度入力',
              description: '穴あき部分（約60%）に当てはまる語を入力します。ほぼ全体の暗唱が必要です。上級者向け。',
              recommended: script.currentLevel >= 3,
              scriptId: script.id,
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('キャンセル'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelTile({
    required BuildContext context,
    required int level,
    required String title,
    required String description,
    required bool recommended,
    required String scriptId,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: recommended ? AppTheme.primary.withValues(alpha: 0.04) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: recommended ? AppTheme.primary : AppTheme.grey200,
          width: recommended ? 2 : 1,
        ),
      ),
      child: ListTile(
        onTap: () {
          Navigator.of(context).pop(); // ボトムシートを閉じる
          context.push('/practice/$scriptId/$level');
        },
        title: Row(
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            if (recommended) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'おすすめ',
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(description, style: TextStyle(fontSize: 12, color: AppTheme.grey500)),
        ),
        trailing: const Icon(Icons.chevron_right, size: 20),
      ),
    );
  }

  void _showVoiceLevelSelectionBottomSheet(BuildContext context, Script script) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '暗記確認レベルを選択',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            _buildVoiceLevelTile(
              context: context,
              level: 4,
              title: 'Level 4: 全文表示',
              description: '原文を表示した状態で、音声で暗唱を確認します。',
              recommended: script.currentLevel == 4 || script.currentLevel < 4,
              scriptId: script.id,
            ),
            const SizedBox(height: 12),
            _buildVoiceLevelTile(
              context: context,
              level: 5,
              title: 'Level 5: 文頭・文末ヒント',
              description: '文頭と文末の文字のみ表示した状態で暗唱します。',
              recommended: script.currentLevel == 5,
              scriptId: script.id,
            ),
            const SizedBox(height: 12),
            _buildVoiceLevelTile(
              context: context,
              level: 6,
              title: 'Level 6: 助詞ヒント',
              description: '助詞（は、が、を等）のみ表示した状態で暗唱します。',
              recommended: script.currentLevel == 6,
              scriptId: script.id,
            ),
            const SizedBox(height: 12),
            _buildVoiceLevelTile(
              context: context,
              level: 7,
              title: 'Level 7: 完全暗唱',
              description: 'ヒントなし（全非表示）の状態で暗唱します。',
              recommended: script.currentLevel >= 7,
              scriptId: script.id,
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('キャンセル'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceLevelTile({
    required BuildContext context,
    required int level,
    required String title,
    required String description,
    required bool recommended,
    required String scriptId,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: recommended ? AppTheme.secondary.withValues(alpha: 0.04) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: recommended ? AppTheme.secondary : AppTheme.grey200,
          width: recommended ? 2 : 1,
        ),
      ),
      child: ListTile(
        onTap: () {
          Navigator.of(context).pop(); // ボトムシートを閉じる
          context.push('/voice-check/$scriptId/$level');
        },
        title: Row(
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            if (recommended) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.secondary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'おすすめ',
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(description, style: TextStyle(fontSize: 12, color: AppTheme.grey500)),
        ),
        trailing: const Icon(Icons.chevron_right, size: 20),
      ),
    );
  }
}

class _TargetDateSection extends ConsumerStatefulWidget {
  final Script script;

  const _TargetDateSection({required this.script});

  @override
  ConsumerState<_TargetDateSection> createState() =>
      _TargetDateSectionState();
}

class _TargetDateSectionState extends ConsumerState<_TargetDateSection> {
  bool _scheduleExpanded = false;

  @override
  Widget build(BuildContext context) {
    final script = widget.script;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section 3-A: SectionHeader widget を使用
        const SectionHeader(title: '復習スケジュール'),
        // 復習ペース（本番日未設定時のみ有効）
        Container(
          width: double.infinity,
          // Section 2: padding 14 → 16
          padding: const EdgeInsets.all(16),
          // Section 1-E: outlineDecoration
          decoration: AppTheme.outlineDecoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '復習ペース',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                      value: 'relaxed', label: Text('ゆっくり')),
                  ButtonSegment(
                      value: 'normal', label: Text('ふつう')),
                  ButtonSegment(
                      value: 'intensive', label: Text('しっかり')),
                  ButtonSegment(
                      value: 'daily', label: Text('毎日')),
                ],
                selected: {script.reviewPace},
                onSelectionChanged: script.isTargetDateMode
                    ? null
                    : (newSelection) async {
                        script.reviewPace = newSelection.first;
                        await script.save();
                        ref.read(scriptsListProvider.notifier).refresh();
                      },
                style: ButtonStyle(
                  textStyle: WidgetStatePropertyAll(
                    const TextStyle(fontSize: 11),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              if (script.isTargetDateMode)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '本番日スケジュールが優先されます',
                    style: TextStyle(fontSize: 11, color: AppTheme.grey500),
                  ),
                ),
            ],
          ),
        ),
        // Section 2: height 10 → 8
        const SizedBox(height: 8),
        // 本番日設定
        if (script.hasTargetDate) ...[
          Container(
            width: double.infinity,
            // Section 2: padding 14 → 16
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(
                color: script.daysUntilTarget <= 3
                    ? AppTheme.error.withValues(alpha: 0.4)
                    : AppTheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.event,
                      size: 18,
                      color: script.daysUntilTarget <= 3
                          ? AppTheme.error
                          : AppTheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '本番日: ${_formatDate(script.targetDate!)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      script.daysUntilTarget > 0
                          ? 'あと${script.daysUntilTarget}日'
                          : script.daysUntilTarget == 0
                              ? '今日が本番'
                              : '本番日を過ぎています',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: script.daysUntilTarget <= 3
                            ? AppTheme.error
                            : AppTheme.secondary,
                      ),
                    ),
                  ],
                ),
                if (script.generatedSchedule.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    '復習予定: 全${script.generatedSchedule.length}回のうち${script.scheduleIndex}回目',
                    style: TextStyle(fontSize: 12, color: AppTheme.grey500),
                  ),
                  const SizedBox(height: 8),
                  // Section 4-C: GestureDetector → InkWell (48dp タップ面積)
                  InkWell(
                    onTap: () =>
                        setState(() => _scheduleExpanded = !_scheduleExpanded),
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusSm),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 4),
                      child: Row(
                        children: [
                          Icon(
                            _scheduleExpanded
                                ? Icons.expand_less
                                : Icons.expand_more,
                            size: 18,
                            color: AppTheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _scheduleExpanded ? 'スケジュールを閉じる' : 'スケジュールを表示',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Section 5-D: AnimatedSize でスケジュール展開
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    child: _scheduleExpanded
                        ? Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Column(
                              children: List.generate(
                                script.generatedSchedule.length,
                                (i) {
                                  final date = script.generatedSchedule[i];
                                  final isCompleted =
                                      i < script.scheduleIndex;
                                  final isToday =
                                      _isSameDay(date, DateTime.now());
                                  return Padding(
                                    // Section 2: vertical 2 → 4
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 4),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isCompleted
                                              ? Icons.check_circle
                                              : isToday
                                                  ? Icons
                                                      .radio_button_checked
                                                  : Icons
                                                      .radio_button_unchecked,
                                          size: 16,
                                          color: isCompleted
                                              ? AppTheme.secondary
                                              : isToday
                                                  ? AppTheme.primary
                                                  : AppTheme.grey400,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _formatDate(date),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isToday
                                                ? AppTheme.primary
                                                : AppTheme.grey600,
                                            fontWeight: isToday
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                            decoration: isCompleted
                                                ? TextDecoration.lineThrough
                                                : null,
                                          ),
                                        ),
                                        if (isToday)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                left: 6),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 1),
                                              decoration: BoxDecoration(
                                                color: AppTheme.primary
                                                    .withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        AppTheme.radiusSm /
                                                            2),
                                              ),
                                              child: const Text(
                                                '今日',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: AppTheme.primary,
                                                  fontWeight:
                                                      FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () async {
                      script.targetDate = null;
                      script.generatedSchedule = [];
                      script.scheduleIndex = 0;
                      await script.save();
                      ref.read(scriptsListProvider.notifier).refresh();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.error,
                      side: BorderSide(
                          color: AppTheme.error.withValues(alpha: 0.4)),
                    ),
                    child: const Text('本番日を解除'),
                  ),
                ),
              ],
            ),
          ),
        ] else
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _pickTargetDate(context, script),
              icon: const Icon(Icons.event, size: 18),
              label: const Text('本番日を設定'),
            ),
          ),
      ],
    );
  }

  Future<void> _pickTargetDate(BuildContext context, Script script) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 7)),
      firstDate: now.add(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
      helpText: '本番日を選択',
    );
    if (picked == null) return;

    final schedule = ScheduleGenerator.generate(
      startDate: now,
      targetDate: picked,
    );

    script.targetDate = picked;
    script.generatedSchedule = schedule;
    script.scheduleIndex = 0;
    if (schedule.isNotEmpty) {
      script.nextReviewAt = schedule[0];
    }
    await script.save();
    ref.read(scriptsListProvider.notifier).refresh();
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _AllowedPairsSection extends ConsumerWidget {
  final String scriptId;

  const _AllowedPairsSection({required this.scriptId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(allowedPairsRepositoryProvider);
    final pairs = repo.getByScriptId(scriptId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section 3-A: SectionHeader widget を使用
        const SectionHeader(title: '許容語リスト'),
        if (pairs.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              // Section 1-C: Colors.grey[50] → AppTheme.background
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.grey200),
            ),
            child: Text(
              '音声チェック結果画面から登録できます',
              style: TextStyle(fontSize: 13, color: AppTheme.grey500),
              textAlign: TextAlign.center,
            ),
          )
        else
          ...pairs.map((pair) => Container(
                // Section 2: margin bottom 6 → 8
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(color: AppTheme.grey200),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: pair.recognizedWord,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppTheme.diffExtra,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const TextSpan(
                              text: ' → ',
                              style: TextStyle(
                                  fontSize: 14, color: AppTheme.textLight),
                            ),
                            TextSpan(
                              text: pair.originalWord,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const TextSpan(
                              text: ' として許容',
                              style: TextStyle(
                                  fontSize: 12, color: AppTheme.textLight),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Section 4-A: タッチターゲット 48dp 確保
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      color: AppTheme.grey400,
                      onPressed: () async {
                        await repo.delete(pair);
                        ref.read(scriptsListProvider.notifier).refresh();
                      },
                      splashRadius: 24,
                      constraints: const BoxConstraints(
                          minWidth: 48, minHeight: 48),
                    ),
                  ],
                ),
              )),
      ],
    );
  }
}

// Section 3-C: Semantics でラップ
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: Container(
        // Section 2: horizontal:10,vertical:6 → horizontal:8,vertical:6
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppTheme.primary),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PinnedClozeWordsSection extends ConsumerStatefulWidget {
  final Script script;

  const _PinnedClozeWordsSection({required this.script});

  @override
  ConsumerState<_PinnedClozeWordsSection> createState() =>
      _PinnedClozeWordsSectionState();
}

class _PinnedClozeWordsSectionState
    extends ConsumerState<_PinnedClozeWordsSection> {
  final _wordController = TextEditingController();

  @override
  void dispose() {
    _wordController.dispose();
    super.dispose();
  }

  void _addWord() {
    final word = _wordController.text.trim();
    if (word.isEmpty) return;
    
    // 本文に含まれているか確認
    if (!widget.script.content.contains(word)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('「$word」は本文中に見つかりません')),
      );
      return;
    }
    
    // 重複チェック
    if (widget.script.pinnedClozeWords.contains(word)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('「$word」は既に登録されています')),
      );
      return;
    }
    
    setState(() {
      widget.script.pinnedClozeWords.add(word);
      _wordController.clear();
    });
    widget.script.save();
    ref.read(scriptsListProvider.notifier).refresh();
  }

  void _removeWord(String word) {
    setState(() {
      widget.script.pinnedClozeWords.remove(word);
    });
    widget.script.save();
    ref.read(scriptsListProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final pinnedWords = widget.script.pinnedClozeWords;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: '重要（穴埋め固定）'),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.outlineDecoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (pinnedWords.isEmpty)
                Text(
                  '登録されている重要語はありません（本文中のテキストを長押し選択して追加できます）',
                  style: TextStyle(fontSize: 13, color: AppTheme.grey500),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: pinnedWords.map((word) {
                    return InputChip(
                      label: Text(
                        word,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      deleteIconColor: AppTheme.grey400,
                      onDeleted: () => _removeWord(word),
                      backgroundColor: AppTheme.primary.withValues(alpha: 0.08),
                      side: BorderSide.none,
                    );
                  }).toList(),
                ),
              const SizedBox(height: 12),
              // 手動追加用フィールド
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _wordController,
                      decoration: const InputDecoration(
                        hintText: '本文中の単語を入力',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      onSubmitted: (_) => _addWord(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _addWord,
                    icon: const Icon(Icons.add_circle_outline),
                    color: AppTheme.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
