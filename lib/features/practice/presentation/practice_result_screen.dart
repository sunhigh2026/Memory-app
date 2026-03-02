import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../scripts/data/scripts_repository.dart';
import '../../progress/data/progress_repository.dart';

class PracticeResultScreen extends ConsumerStatefulWidget {
  final String scriptId;
  final double score;
  final int level;
  final int totalQuestions;
  final int correctAnswers;

  const PracticeResultScreen({
    super.key,
    required this.scriptId,
    required this.score,
    required this.level,
    required this.totalQuestions,
    required this.correctAnswers,
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
    _saveProgress();
  }

  Future<void> _saveProgress() async {
    if (_saved) return;
    _saved = true;

    final progressRepo = ref.read(progressRepositoryProvider);
    await progressRepo.addSession(
      scriptId: widget.scriptId,
      mode: 'cloze',
      level: widget.level,
      score: widget.score,
    );

    // Script の進捗を更新
    final scripts = ref.read(scriptsListProvider);
    final script = scripts.firstWhere((s) => s.id == widget.scriptId);
    await progressRepo.updateScriptProgress(
        script, widget.score, 'cloze', widget.level);
    ref.read(scriptsListProvider.notifier).refresh();
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
    final script = scripts.cast<dynamic>().firstWhere(
          (s) => s.id == widget.scriptId,
          orElse: () => null,
        );
    final leveledUp =
        passed && script != null && script.currentLevel > widget.level;

    return Scaffold(
      appBar: AppBar(
        title: const Text('練習結果'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
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
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  children: [
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
                          borderRadius: BorderRadius.circular(8),
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
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // ボタン
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => context.go('/detail/${widget.scriptId}'),
                      child: const Text('詳細に戻る'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final level = passed && widget.level < 3
                            ? widget.level + 1
                            : widget.level;
                        context.pushReplacement(
                            '/practice/${widget.scriptId}/$level');
                      },
                      child: const Text('もう一度'),
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
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        ),
      ],
    );
  }
}
