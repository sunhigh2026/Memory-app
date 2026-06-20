import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../data/cloze_generator.dart';
import '../../scripts/data/scripts_repository.dart';
import '../../progress/data/progress_repository.dart';
import '../../../models/script.dart';
import '../../../models/cloze_word.dart';

enum EvaluationType {
  correct,   // 覚えてる
  ambiguous, // 自信ない
  wrong,     // わからない
}

class FlipModeScreen extends ConsumerStatefulWidget {
  final String scriptId;

  const FlipModeScreen({
    super.key,
    required this.scriptId,
  });

  @override
  ConsumerState<FlipModeScreen> createState() => _FlipModeScreenState();
}

class _FlipModeScreenState extends ConsumerState<FlipModeScreen> {
  late Script _script;
  late List<ClozeWord> _clozeWords;
  int _currentIndex = 0;
  int _correctCount = 0;

  // 各空欄の状態管理
  final Map<int, bool> _revealedStates = {};
  final Map<int, EvaluationType?> _evaluatedStates = {};

  final _generator = ClozeGenerator();
  final _stopwatch = Stopwatch();

  // フリック検出用
  Offset _dragStart = Offset.zero;
  bool _hasDragged = false;

  @override
  void initState() {
    super.initState();
    _loadScript();
    _stopwatch.start();
  }

  void _loadScript() {
    final scripts = ref.read(scriptsListProvider);
    _script = scripts.firstWhere((s) => s.id == widget.scriptId);

    // Level 2 の密度は20%
    final density = ClozeGenerator.densityForLevel(2);
    final pinned = _script.pinnedClozeWords;
    _clozeWords = _generator.generate(
      _script.content,
      densityPercent: density,
      pinnedClozeWords: pinned,
    );

    if (_clozeWords.isEmpty) {
      _clozeWords = _generator.generate(
        _script.content,
        densityPercent: 20,
        pinnedClozeWords: pinned,
      );
    }

    // 各空欄の状態を初期化
    for (int i = 0; i < _clozeWords.length; i++) {
      _revealedStates[i] = false;
      _evaluatedStates[i] = null;
    }
  }

  Future<bool> _showExitConfirmationDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('練習の中止'),
        content: const Text('現在の練習を中止して詳細画面に戻りますか？\n（進捗は保存されません）'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('中止する'),
          ),
        ],
      ),
    );
    return result ?? false;
  }



  void _handleTap() {
    // タップによる開示フロー廃止のため、何もしない
  }

  void _evaluateCurrent(EvaluationType type) async {
    if (_currentIndex >= _clozeWords.length) return;

    HapticFeedback.mediumImpact();
    setState(() {
      _revealedStates[_currentIndex] = true; // フリック時に答えを開示する
      _evaluatedStates[_currentIndex] = type;
      if (type == EvaluationType.correct) {
        _correctCount++;
      }
      _currentIndex++;
    });
  }

  Future<void> _finishSession() async {
    _stopwatch.stop();
    final duration = _stopwatch.elapsed.inSeconds;

    final mistakes = <String>[];
    double scoreSum = 0.0;
    for (int i = 0; i < _clozeWords.length; i++) {
      final eval = _evaluatedStates[i];
      if (eval == EvaluationType.correct) {
        scoreSum += 1.0;
      } else if (eval == EvaluationType.ambiguous) {
        scoreSum += 0.5;
        mistakes.add(_clozeWords[i].word);
      } else {
        mistakes.add(_clozeWords[i].word);
      }
    }

    final score = _clozeWords.isEmpty
        ? 0.0
        : (scoreSum / _clozeWords.length) * 100;

    final progressRepo = ref.read(progressRepositoryProvider);
    await progressRepo.addSession(
      scriptId: _script.id,
      mode: 'cloze',
      level: 2,
      score: score,
      durationSeconds: duration,
    );
    await progressRepo.updateScriptProgress(
      _script,
      score,
      'cloze',
      2,
      mistakes: mistakes,
    );
    ref.read(scriptsListProvider.notifier).refresh();

    if (mounted) {
      context.pushReplacement('/practice-result', extra: {
        'scriptId': _script.id,
        'score': score,
        'level': 2,
        'totalQuestions': _clozeWords.length,
        'correctAnswers': _correctCount,
        'durationSeconds': duration,
        'mistakes': mistakes,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_clozeWords.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('高速フリック練習')),
        body: const Center(child: Text('穴埋め対象の単語が見つかりません')),
      );
    }

    final progress = _clozeWords.isEmpty ? 0.0 : _currentIndex / _clozeWords.length;
    final isFinished = _currentIndex >= _clozeWords.length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _showExitConfirmationDialog();
        if (shouldPop && context.mounted) {
          context.go('/detail/${widget.scriptId}');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final shouldPop = await _showExitConfirmationDialog();
              if (shouldPop && context.mounted) {
                context.go('/detail/${widget.scriptId}');
              }
            },
          ),
          title: Text('No. ${_script.sortOrder} ${_script.title} (Lv0)'),
          actions: [
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text(
                  '${_currentIndex.clamp(0, _clozeWords.length)} / ${_clozeWords.length}',
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _handleTap,
          onPanDown: (details) {
            _dragStart = details.localPosition;
            _hasDragged = false;
          },
          onPanUpdate: (details) {
            if (_hasDragged || _currentIndex >= _clozeWords.length) return;
            final dx = details.localPosition.dx - _dragStart.dx;
            final dy = details.localPosition.dy - _dragStart.dy;
            
            // 感度調整（短めでも感知）
            const threshold = 30.0;
            
            if (dy.abs() > dx.abs()) {
              // 縦方向
              if (dy < -threshold) {
                _hasDragged = true;
                _evaluateCurrent(EvaluationType.correct);
              } else if (dy > threshold) {
                _hasDragged = true;
                _evaluateCurrent(EvaluationType.wrong);
              }
            } else {
              // 横方向
              if (dx < -threshold) {
                _hasDragged = true;
                _evaluateCurrent(EvaluationType.ambiguous);
              }
            }
          },
          child: Column(
            children: [
              LinearProgressIndicator(
                value: progress,
                backgroundColor: AppTheme.grey200,
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
              ),
              if (_script.tags.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: _script.tags.map((tag) {
                        final colors = AppTheme.tagColor(tag);
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: colors.background,
                            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.label_outline, size: 12, color: colors.text),
                              const SizedBox(width: 4),
                              Text(
                                tag,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colors.text,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],

              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: _buildClozeText(),
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Center(
                    child: !isFinished
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.arrow_upward, color: AppTheme.secondary, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    '覚えてる (上) 👆',
                                    style: TextStyle(
                                      color: AppTheme.secondary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.arrow_back, color: Colors.orange, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    '自信ない (左) 👈',
                                    style: TextStyle(
                                      color: Colors.orange,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.arrow_downward, color: AppTheme.error, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    'わからない (下) 👇',
                                    style: TextStyle(
                                      color: AppTheme.error,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          )
                        : Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _finishSession,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                child: const Text(
                                  '結果を表示',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClozeText() {
    final content = _script.content;
    final spans = <TextSpan>[];

    int lastEnd = 0;
    for (int i = 0; i < _clozeWords.length; i++) {
      final cw = _clozeWords[i];
      if (cw.startIndex > lastEnd) {
        spans.add(TextSpan(
          text: content.substring(lastEnd, cw.startIndex),
          style: const TextStyle(
              fontSize: 18, height: 1.8, color: AppTheme.textDark),
        ));
      }

      final isRevealed = _revealedStates[i] ?? false;
      final evaluation = _evaluatedStates[i];

      Color holeColor;
      String displayText;
      FontWeight fontWeight = FontWeight.bold;
      TextDecoration decoration = TextDecoration.underline;

      if (i < _currentIndex) {
        // すでに評価済みの空欄
        if (evaluation == EvaluationType.correct) {
          holeColor = AppTheme.secondary.withValues(alpha: 0.7); // 覚えてる＝薄い緑
          displayText = cw.word;
          fontWeight = FontWeight.w600;
          decoration = TextDecoration.none;
        } else if (evaluation == EvaluationType.ambiguous) {
          holeColor = Colors.orange.withValues(alpha: 0.7); // 自信ない＝薄いオレンジ
          displayText = cw.word;
          fontWeight = FontWeight.w600;
          decoration = TextDecoration.none;
        } else {
          holeColor = AppTheme.error.withValues(alpha: 0.7); // わからない＝薄い赤
          displayText = cw.word;
          fontWeight = FontWeight.w600;
          decoration = TextDecoration.none;
        }
      } else if (i == _currentIndex) {
        // 現在処理中の空欄
        if (isRevealed) {
          holeColor = AppTheme.primary; // 開示中＝主色
          displayText = cw.word;
        } else {
          holeColor = AppTheme.primary; // 未開示＝主色の伏せ字
          displayText = '＿' * cw.word.length;
        }
      } else {
        // これから到達する空欄
        holeColor = AppTheme.grey400; // グレーの伏せ字
        displayText = '＿' * cw.word.length;
        decoration = TextDecoration.none;
      }

      spans.add(TextSpan(
        text: displayText,
        style: TextStyle(
          fontSize: 18,
          height: 1.8,
          color: holeColor,
          fontWeight: fontWeight,
          decoration: decoration,
          decorationColor: holeColor,
        ),
      ));

      lastEnd = cw.endIndex;
    }

    if (lastEnd < content.length) {
      spans.add(TextSpan(
        text: content.substring(lastEnd),
        style: const TextStyle(
            fontSize: 18, height: 1.8, color: AppTheme.textDark),
      ));
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.grey200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text.rich(TextSpan(children: spans)),
    );
  }
}
