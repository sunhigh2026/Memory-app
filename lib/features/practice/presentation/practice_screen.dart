import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/text_normalizer.dart';
import '../../../core/widgets/animations/shake_widget.dart';
import '../data/cloze_generator.dart';
import '../../scripts/data/scripts_repository.dart';
import '../../voice_check/data/speech_recognition_service.dart';
import '../../voice_check/domain/recognition_mode.dart';
import '../../../models/script.dart';
import '../../../models/cloze_word.dart';

class PracticeScreen extends ConsumerStatefulWidget {
  final String scriptId;
  final int level;

  const PracticeScreen({
    super.key,
    required this.scriptId,
    required this.level,
  });

  @override
  ConsumerState<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends ConsumerState<PracticeScreen>
    with SingleTickerProviderStateMixin {
  late Script _script;
  late List<ClozeWord> _clozeWords;
  int _currentIndex = 0;
  int _correctCount = 0;
  int _hintUsed = 0;
  bool _showingResult = false;
  bool? _lastAnswerCorrect;
  String _correctAnswer = '';

  // 各穴の回答結果を記録（true=正解、false=不正解、null=未回答）
  final Map<int, bool> _answeredResults = {};
  bool _isListeningVoiceInput = false;
  final _inputController = TextEditingController();
  final _generator = ClozeGenerator();

  List<String> _currentChoices = [];
  String _selectedChoice = '';
  bool _isAutoTransitioning = false;

  // キーボードを維持するためのFocusNode
  final _inputFocusNode = FocusNode();

  // 学習時間を測定するストップウォッチ
  final _stopwatch = Stopwatch();

  // Section 5-B: ShakeWidget と ScaleAnimation
  final _shakeKey = GlobalKey<ShakeWidgetState>();
  late final AnimationController _scaleCtrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _loadScript();
    _stopwatch.start();
    // Section 5-B: 正解時スケールアニメーション
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.04), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.04, end: 1.0), weight: 50),
    ]).animate(
        CurvedAnimation(parent: _scaleCtrl, curve: Curves.elasticOut));
  }


  void _loadScript() {
    final scripts = ref.read(scriptsListProvider);
    _script = scripts.firstWhere((s) => s.id == widget.scriptId);

    final density = ClozeGenerator.densityForLevel(widget.level);
    final pinned = _script.pinnedClozeWords;
    _clozeWords = _generator.generate(
      _script.content,
      densityPercent: density,
      pinnedClozeWords: pinned,
    );

    if (_clozeWords.isEmpty) {
      _clozeWords = _generator.generate(
        _script.content,
        densityPercent: 30,
        pinnedClozeWords: pinned,
      );
    }

    if (_clozeWords.isNotEmpty && widget.level == 1) {
      _generateCurrentChoices();
    }
  }

  void _generateCurrentChoices() {
    if (_clozeWords.isEmpty || _currentIndex >= _clozeWords.length) return;
    final currentWord = _clozeWords[_currentIndex];
    _currentChoices = _generator.generateChoices(currentWord.word, _clozeWords);
  }

  @override
  void dispose() {
    _inputController.dispose();
    _inputFocusNode.dispose();
    _scaleCtrl.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    if (_clozeWords.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('穴埋め練習')),
        body: const Center(child: Text('穴埋め対象の単語が見つかりません')),
      );
    }

    final currentWord = _clozeWords[_currentIndex];
    final progress = (_currentIndex + 1) / _clozeWords.length;

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
          title: Text('No. ${_script.sortOrder} ${_script.title}'),
          actions: [
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text(
                  '${_currentIndex + 1} / ${_clozeWords.length}',
                  // Section 3-B: textTheme.labelLarge を使用
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // プログレスバー
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
            // テキスト表示（穴あき）— Section 5-B: AnimatedSwitcher
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween(begin: 0.97, end: 1.0).animate(animation),
                      child: child,
                    ),
                  ),
                  child: KeyedSubtree(
                    key: ValueKey(_currentIndex),
                    child: _buildClozeText(currentWord),
                  ),
                ),
              ),
            ),
            // 回答エリア（画面下部に固定）— Section 5-B: ShakeWidget でラップ
            ShakeWidget(
              key: _shakeKey,
              child: Container(
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
                  child: Padding(
                    // Section 2: fromLTRB(16,12,16,16) → fromLTRB(16,16,16,16)
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 回答UI（常時表示、判定後は状態に応じてスタイル変更）
                        widget.level == 1
                            ? _buildChoices(currentWord)
                            : _buildInputField(currentWord),
                        if (_showingResult) ...[
                          const SizedBox(height: 12),
                          ScaleTransition(
                            scale: _scaleAnim,
                            child: _buildResultDisplay(),
                          ),
                          // 不正解時のみ「次へ」ボタンを表示
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _next,
                              child: Text(
                                _currentIndex < _clozeWords.length - 1
                                    ? '次へ'
                                    : '結果を見る',
                              ),
                            ),
                          ),
                        ] else if (widget.level > 1 && _hintUsed < 3) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: OutlinedButton.icon(
                              onPressed: () => _showHint(currentWord),
                              icon: const Icon(Icons.lightbulb_outline,
                                  size: 18),
                              label: Text('ヒント (${3 - _hintUsed})'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClozeText(ClozeWord target) {
    final content = _script.content;
    final spans = <TextSpan>[];

    int lastEnd = 0;
    for (final cw in _clozeWords) {
      if (cw.startIndex > lastEnd) {
        spans.add(TextSpan(
          text: content.substring(lastEnd, cw.startIndex),
          style: const TextStyle(
              fontSize: 16, height: 1.8, color: AppTheme.textDark),
        ));
      }

      final cwIndex = _clozeWords.indexOf(cw);
      final previousResult = _answeredResults[cwIndex];

      if (cw == target) {
        // 現在の対象穴
        Color holeColor = AppTheme.primary;
        String displayText = '＿' * cw.word.length;
        if (_lastAnswerCorrect == true) {
          holeColor = AppTheme.secondary;
          displayText = cw.word; // 正解なら単語を表示
        } else if (_showingResult && _lastAnswerCorrect == false) {
          holeColor = AppTheme.error;
          displayText = cw.word; // 不正解なら正解の単語を赤字で表示
        }

        spans.add(TextSpan(
          text: displayText,
          style: TextStyle(
            fontSize: 16,
            height: 1.8,
            color: holeColor,
            fontWeight: FontWeight.bold,
            decoration: TextDecoration.underline,
            decorationColor: holeColor,
          ),
        ));
      } else if (previousResult != null) {
        // 既に回答済みの穴
        final resultColor = previousResult ? AppTheme.secondary : AppTheme.error;
        spans.add(TextSpan(
          text: cw.word, // 正解・不正解問わず正解テキストを表示。不正解箇所は薄い赤字になる。
          style: TextStyle(
            fontSize: 16,
            height: 1.8,
            color: resultColor.withValues(alpha: 0.6),
            fontWeight: FontWeight.w600,
          ),
        ));
      } else {
        // 未回答の穴
        spans.add(TextSpan(
          text: '＿' * cw.word.length,
          style: TextStyle(
            fontSize: 16,
            height: 1.8,
            color: AppTheme.grey400,
          ),
        ));
      }
      lastEnd = cw.endIndex;
    }

    if (lastEnd < content.length) {
      spans.add(TextSpan(
        text: content.substring(lastEnd),
        style: const TextStyle(
            fontSize: 16, height: 1.8, color: AppTheme.textDark),
      ));
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.grey200),
      ),
      child: Text.rich(TextSpan(children: spans)),
    );
  }

  Widget _buildChoices(ClozeWord target) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _currentChoices.map((choice) {
        Color? backgroundColor;
        Color? foregroundColor;
        BorderSide? borderSide;

        if (_showingResult) {
          if (choice == target.word) {
            backgroundColor = AppTheme.secondary.withValues(alpha: 0.12);
            foregroundColor = AppTheme.secondary;
            borderSide = const BorderSide(color: AppTheme.secondary, width: 2);
          } else if (choice == _selectedChoice && _lastAnswerCorrect == false) {
            backgroundColor = AppTheme.error.withValues(alpha: 0.12);
            foregroundColor = AppTheme.error;
            borderSide = const BorderSide(color: AppTheme.error, width: 2);
          }
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: OutlinedButton(
            onPressed: _showingResult ? null : () => _checkAnswer(choice, target.word),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              backgroundColor: backgroundColor,
              foregroundColor: foregroundColor,
              side: borderSide,
            ),
            child: Text(choice),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInputField(ClozeWord target) {
    Color? borderColor;
    Color? textColor;
    Color? fillColor;

    if (_showingResult) {
      if (_lastAnswerCorrect == true) {
        borderColor = AppTheme.secondary;
        textColor = AppTheme.secondary;
        fillColor = AppTheme.secondary.withValues(alpha: 0.05);
      } else {
        borderColor = AppTheme.error;
        textColor = AppTheme.error;
        fillColor = AppTheme.error.withValues(alpha: 0.05);
      }
    }

    return Column(
      children: [
        Row(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _showingResult
                  ? null
                  : () {
                      if (_isListeningVoiceInput) {
                        _stopVoiceInput();
                      } else {
                        _startVoiceInput(target.word);
                      }
                    },
              child: Container(
                width: 48,
                height: 48,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: _isListeningVoiceInput
                      ? AppTheme.error.withValues(alpha: 0.1)
                      : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _isListeningVoiceInput
                        ? AppTheme.error
                        : AppTheme.grey300,
                    width: _isListeningVoiceInput ? 2 : 1,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  _isListeningVoiceInput ? Icons.mic : Icons.mic_none,
                  color: _isListeningVoiceInput ? AppTheme.error : AppTheme.primary,
                ),
              ),
            ),
            Expanded(
              child: TextField(
                controller: _inputController,
                focusNode: _inputFocusNode,
                enabled: !_showingResult,
                autofocus: true,
                style: TextStyle(
                  color: textColor,
                  fontWeight: _showingResult ? FontWeight.bold : FontWeight.normal,
                ),
                decoration: InputDecoration(
                  fillColor: fillColor ?? Colors.white,
                  hintText: _isListeningVoiceInput ? '音声を聞き取り中...' : '答えを入力してください',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _showingResult
                        ? null
                        : () => _checkAnswer(_inputController.text.trim(), target.word),
                  ),
                  enabledBorder: borderColor != null
                      ? OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor, width: 2),
                        )
                      : null,
                  disabledBorder: borderColor != null
                      ? OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor, width: 2),
                        )
                      : null,
                  focusedBorder: borderColor != null
                      ? OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor, width: 2),
                        )
                      : null,
                ),
                onSubmitted: _showingResult
                    ? null
                    : (value) => _checkAnswer(value.trim(), target.word),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _startVoiceInput(String correctWord) async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('マイクの権限が必要です')),
        );
      }
      return;
    }

    final speechService = ref.read(speechRecognitionServiceProvider);
    final available = await speechService.initialize();
    if (!available) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('音声認識を初期化できませんでした')),
        );
      }
      return;
    }

    setState(() {
      _isListeningVoiceInput = true;
      _inputController.text = '';
    });

    await speechService.startListening(
      mode: RecognitionMode.immediate,
      listenFor: const Duration(seconds: 10), // 短い時間で十分
      onResult: (text) {
        if (!mounted) return;
        setState(() {
          _isListeningVoiceInput = false;
          _inputController.text = text;
        });
        _checkAnswer(text, correctWord);
      },
      onPartialResult: (text) async {
        if (!mounted) return;
        setState(() {
          _inputController.text = text;
        });

        final normalizedText = TextNormalizer.normalize(text);
        final normalizedCorrect = TextNormalizer.normalize(correctWord);

        // 1. 完全一致・包含チェック (高速)
        if (normalizedText.contains(normalizedCorrect)) {
          _stopVoiceInput();
          _checkAnswer(correctWord, correctWord); // 正解として送信
          return;
        }

        // 2. ひらがな（読み）の包含および曖昧一致チェック
        try {
          final hiraText = await TextNormalizer.toHiragana(normalizedText);
          final hiraCorrect = await TextNormalizer.toHiragana(normalizedCorrect);
          if (hiraText.isNotEmpty && hiraCorrect.isNotEmpty) {
            if (hiraText.contains(hiraCorrect) || TextNormalizer.isFuzzyMatch(hiraText, hiraCorrect)) {
              _stopVoiceInput();
              _checkAnswer(correctWord, correctWord); // 正解として送信
            }
          }
        } catch (e) {
          debugPrint('リアルタイムひらがな判定エラー: $e');
        }
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _isListeningVoiceInput = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('音声認識エラー: $error')),
        );
      },
    );
  }

  Future<void> _stopVoiceInput() async {
    final speechService = ref.read(speechRecognitionServiceProvider);
    await speechService.stopListening();
    if (mounted) {
      setState(() {
        _isListeningVoiceInput = false;
      });
    }
  }

  Widget _buildResultDisplay() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _lastAnswerCorrect == true
            ? AppTheme.secondary.withValues(alpha: 0.1)
            : AppTheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: _lastAnswerCorrect == true
              ? AppTheme.secondary.withValues(alpha: 0.3)
              : AppTheme.error.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(
            _lastAnswerCorrect == true ? Icons.check_circle : Icons.cancel,
            color: _lastAnswerCorrect == true
                ? AppTheme.secondary
                : AppTheme.error,
            size: 48,
          ),
          const SizedBox(height: 8),
          Text(
            _lastAnswerCorrect == true ? '正解！' : '不正解',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _lastAnswerCorrect == true
                  ? AppTheme.secondary
                  : AppTheme.error,
            ),
          ),
          if (_lastAnswerCorrect != true) ...[
            const SizedBox(height: 8),
            Text(
              '正解: $_correctAnswer',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _checkAnswer(String answer, String correct) async {
    if (answer.isEmpty) return;
    if (_showingResult) return;

    final normalizedAnswer = TextNormalizer.normalize(answer);
    final normalizedCorrect = TextNormalizer.normalize(correct);

    bool isCorrect =
        normalizedAnswer == normalizedCorrect || answer == correct;

    if (!isCorrect) {
      // ひらがな読み曖昧比較
      try {
        final hiraAnswer = await TextNormalizer.toHiragana(normalizedAnswer);
        final hiraCorrect = await TextNormalizer.toHiragana(normalizedCorrect);
        if (hiraAnswer.isNotEmpty && hiraCorrect.isNotEmpty) {
          isCorrect = hiraAnswer == hiraCorrect ||
              TextNormalizer.isFuzzyMatch(hiraAnswer, hiraCorrect);
        }
      } catch (_) {}
    }

    if (widget.level == 1) {
      _selectedChoice = answer;
      if (isCorrect) {
        setState(() {
          _correctCount++;
          _answeredResults[_currentIndex] = true;
          _lastAnswerCorrect = true;
        });
        // 軽量オーバーレイで正解を表示し、即座に次へ
        _showCorrectOverlay();
        _isAutoTransitioning = true;
        Future.delayed(const Duration(milliseconds: 250), () {
          _isAutoTransitioning = false;
          if (mounted) _next();
        });
      } else {
        setState(() {
          _showingResult = true;
          _lastAnswerCorrect = false;
          _correctAnswer = correct;
          _answeredResults[_currentIndex] = false;
        });
        _shakeKey.currentState?.shake();
      }
    } else {
      if (isCorrect) {
        setState(() {
          _correctCount++;
          _answeredResults[_currentIndex] = true;
          _lastAnswerCorrect = true;
        });
        // 軽量オーバーレイで正解を表示し、即座に次へ（キーボード維持）
        _showCorrectOverlay();
        _isAutoTransitioning = true;
        final isLast = _currentIndex >= _clozeWords.length - 1;
        Future.delayed(const Duration(milliseconds: 250), () {
          _isAutoTransitioning = false;
          if (mounted) {
            _next();
            // 次の問題がある場合のみキーボードを維持
            if (!isLast && widget.level > 1) {
              Future.microtask(() {
                if (mounted) _inputFocusNode.requestFocus();
               });
            }
          }
        });
      } else {
        if (!mounted) return;
        FocusScope.of(context).unfocus(); // 不正解時はキーボードを閉じる
        setState(() {
          _showingResult = true;
          _lastAnswerCorrect = false;
          _correctAnswer = correct;
          _answeredResults[_currentIndex] = false;
        });
        _shakeKey.currentState?.shake();
      }
    }
  }

  /// 正解時に軽量なオーバーレイで「✓ 正解」を一瞬表示
  void _showCorrectOverlay() {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).size.height * 0.35,
        left: 0,
        right: 0,
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 200),
            builder: (context, value, child) => Opacity(
              opacity: value,
              child: Transform.scale(
                scale: 0.8 + 0.2 * value,
                child: child,
              ),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.secondary.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.secondary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                  SizedBox(width: 6),
                  Text(
                    '正解！',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(milliseconds: 400), () {
      entry.remove();
    });
  }

  void _showHint(ClozeWord target) {
    setState(() => _hintUsed++);
    final firstChar = target.word.substring(0, 1);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('ヒント: 最初の文字は「$firstChar」です'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _next() {
    if (_isAutoTransitioning) return;

    if (_currentIndex < _clozeWords.length - 1) {
      setState(() {
        _currentIndex++;
        _showingResult = false;
        _lastAnswerCorrect = null;
        _selectedChoice = '';
        _inputController.clear();
      });

      if (_clozeWords.isNotEmpty && widget.level == 1) {
        _generateCurrentChoices();
      }
    } else {
      _stopwatch.stop();
      final duration = _stopwatch.elapsed.inSeconds;

      // 結果画面遷移前にキーボードを非表示にする
      FocusScope.of(context).unfocus();

      final mistakes = <String>[];
      for (int i = 0; i < _clozeWords.length; i++) {
        if (_answeredResults[i] == false) {
          mistakes.add(_clozeWords[i].word);
        }
      }

      final score = _clozeWords.isEmpty
          ? 0.0
          : (_correctCount / _clozeWords.length) * 100;

      // キーボードの閉じるアニメーションがある程度進行するのを待ち、
      // 画面レイアウトのオーバーフローを防ぐために少し遅延を入れてから遷移する
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        context.pushReplacement('/practice-result', extra: {
          'scriptId': widget.scriptId,
          'score': score,
          'level': widget.level,
          'totalQuestions': _clozeWords.length,
          'correctAnswers': _correctCount,
          'durationSeconds': duration,
          'mistakes': mistakes,
        });
      });
    }
  }
}
