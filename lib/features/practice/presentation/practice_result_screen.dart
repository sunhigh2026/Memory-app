import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../scripts/data/scripts_repository.dart';
import '../../progress/data/progress_repository.dart';
import '../../../models/script.dart';

class PracticeResultScreen extends ConsumerStatefulWidget {
  final String scriptId;
  final double score;
  final int level;
  final int totalQuestions;
  final int correctAnswers;
  final int durationSeconds;
  final List<String> mistakes;

  const PracticeResultScreen({
    super.key,
    required this.scriptId,
    required this.score,
    required this.level,
    required this.totalQuestions,
    required this.correctAnswers,
    this.durationSeconds = 0,
    this.mistakes = const [],
  });

  @override
  ConsumerState<PracticeResultScreen> createState() =>
      _PracticeResultScreenState();
}

class _PracticeResultScreenState extends ConsumerState<PracticeResultScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scoreAnimation;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _scoreAnimation = Tween<double>(begin: 0, end: widget.score).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _animController.forward();
    
    // 最初のフレーム描画完了後に安全に保存処理を実行
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _saveProgress();
    });
  }

  // Section 6: 保存中/成功/失敗 SnackBar フィードバック
  Future<void> _saveProgress() async {
    if (_saved) return;
    if (!mounted) return;
    _saved = true;

    final messenger = ScaffoldMessenger.of(context);
    ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? controller;

    try {
      controller = messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 12),
              Text('保存中...'),
            ],
          ),
          duration: const Duration(seconds: 30),
        ),
      );

      final progressRepo = ref.read(progressRepositoryProvider);
      await progressRepo.addSession(
        scriptId: widget.scriptId,
        mode: 'cloze',
        level: widget.level,
        score: widget.score,
        durationSeconds: widget.durationSeconds,
      );

      final scripts = ref.read(scriptsListProvider);
      final script = scripts.firstWhere((s) => s.id == widget.scriptId);
      
      await progressRepo.updateScriptProgress(
          script, widget.score, 'cloze', widget.level, mistakes: widget.mistakes);
      
      ref.read(scriptsListProvider.notifier).refresh();


      controller.close();
      if (mounted) {
        messenger.showSnackBar(const SnackBar(
          content: Text('保存しました ✓'),
          duration: Duration(seconds: 2),
        ));
      }
    } catch (e) {
      _saved = false; // 再試行可能に
      controller?.close();
      if (mounted) {
        messenger.showSnackBar(SnackBar(
          content: Text('保存に失敗しました: $e'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(label: '再試行', onPressed: _saveProgress),
        ));
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final passed = widget.score >= 80;
    final scripts = ref.watch(scriptsListProvider);
    final script = scripts.cast<Script?>().firstWhere(
          (s) => s?.id == widget.scriptId,
          orElse: () => null,
        );
    final leveledUp =
        passed && script != null && script.currentLevel > widget.level;

    final sortedScripts = List<Script>.from(scripts)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final currentIndex = sortedScripts.indexWhere((s) => s.id == widget.scriptId);
    final nextScript = (currentIndex != -1 && currentIndex < sortedScripts.length - 1)
        ? sortedScripts[currentIndex + 1]
        : null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.go('/detail/${widget.scriptId}');
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/detail/${widget.scriptId}'),
          ),
          title: const Text('練習結果'),
          automaticallyImplyLeading: false,
        ),
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // スコアアニメーション
                AnimatedBuilder(
                  animation: _scoreAnimation,
                  builder: (context, child) {
                    return Column(
                      children: [
                        Text(
                          '${_scoreAnimation.value.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 64,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.scoreColor(widget.score),
                          ),
                        ),
                        Text(
                          AppTheme.scoreLabel(widget.score),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.scoreColor(widget.score),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 32),
                // 正答数
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    // Section 1-D: circular(16) → radiusLg
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      if (script != null) ...[
                        Text(
                          '${script.sortOrder}. ${script.title}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _ResultStat(
                            label: '正解',
                            value: '${widget.correctAnswers}',
                            color: AppTheme.secondary,
                          ),
                          _ResultStat(
                            label: '問題数',
                            value: '${widget.totalQuestions}',
                            color: AppTheme.primary,
                          ),
                          _ResultStat(
                            label: 'Level',
                            value: '${widget.level}',
                            color: AppTheme.accent,
                          ),
                        ],
                      ),
                      if (leveledUp) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.secondary.withValues(alpha: 0.1),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSm),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.arrow_upward,
                                  color: AppTheme.secondary, size: 20),
                              const SizedBox(width: 4),
                              Text(
                                'Level ${widget.level + 1} に昇格！',
                                style: const TextStyle(
                                  color: AppTheme.secondary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (!passed) ...[
                        const SizedBox(height: 16),
                        Text(
                          '80%以上で次のレベルに昇格できます',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.grey500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                // ボタン
                 Column(
                   children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: OutlinedButton(
                            onPressed: () =>
                                context.go('/detail/${widget.scriptId}'),
                            child: const Text('詳細に戻る'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: ElevatedButton(
                            onPressed: () {
                              final nextLevel = passed ? widget.level + 1 : widget.level;
                              if (nextLevel >= 5) {
                                context.pushReplacement(
                                    '/voice-check/${widget.scriptId}/5');
                              } else {
                                context.pushReplacement(
                                    '/practice/${widget.scriptId}/$nextLevel');
                              }
                            },
                             child: Text(passed ? '次のレベル（Lv.${widget.level + 1}）へ' : 'もう一度'),
                          ),
                        ),
                      ],
                    ),
                     const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _showLevelSelectionSheet(context),
                        icon: const Icon(Icons.swap_vert, size: 18),
                        label: const Text('レベルを変更して再チャレンジ'),
                      ),
                    ),
                    if (nextScript != null && passed) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            context.pushReplacement(
                                '/practice/${nextScript.id}/${widget.level}');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.secondary,
                            foregroundColor: Colors.white,
                          ),
                           child: Text('次の問題（No.${nextScript.sortOrder}）へ'),
                        ),
                      ),
                    ],
                    if (!passed && widget.level > 1) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            context.pushReplacement(
                                '/practice/${widget.scriptId}/${widget.level - 1}');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.grey600,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('レベルを下げて再チャレンジ'),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  void _showLevelSelectionSheet(BuildContext context) {
    final scriptId = widget.scriptId;
    final currentLevel = widget.level;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
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
              'レベルを選択して再チャレンジ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            for (int lvl = 1; lvl <= 4; lvl++) ...[
              _buildLevelOption(ctx, lvl, scriptId, currentLevel),
              if (lvl < 4) const SizedBox(height: 8),
            ],
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('キャンセル'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelOption(BuildContext sheetContext, int level, String scriptId, int currentLevel) {
    final labels = {
      1: 'Level 1: 4択',
      2: 'Level 2: 高速フリック',
      3: 'Level 3: キーボード入力',
      4: 'Level 4: 高難度入力',
    };
    final isCurrent = level == currentLevel;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrent ? AppTheme.primary : AppTheme.grey200,
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: ListTile(
        onTap: () {
          Navigator.of(sheetContext).pop();
          context.pushReplacement('/practice/$scriptId/$level');
        },
        title: Row(
          children: [
            Text(labels[level]!,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            if (isCurrent) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.grey200,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '今回',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
        trailing: const Icon(Icons.chevron_right, size: 20),
      ),
    );
  }
}

class _ResultStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ResultStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          // Section 3-B: AppTheme.statNumber を使用
          style: AppTheme.statNumber.copyWith(color: color),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: AppTheme.grey500),
        ),
      ],
    );
  }
}
