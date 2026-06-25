import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:budoux/budoux.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/text_normalizer.dart';
import '../../../core/widgets/rank_chip.dart';
import '../../scripts/data/scripts_repository.dart';
import '../../progress/data/progress_repository.dart';
import '../data/speech_recognition_service.dart';
import '../domain/realtime_matcher.dart';
import '../domain/recognition_mode.dart';
import '../domain/text_matcher.dart';
import 'diff_result_widget.dart';
import '../../../models/script.dart';
import '../data/allowed_pairs_repository.dart';

enum HintLevel {
  showAll,            // Level 5
  firstAndLastChars,  // Level 6 (文頭・文末)
  particles,          // Level 7 (助詞)
  hidden,             // Level 8 (完全暗唱)
}

class VoiceCheckScreen extends ConsumerStatefulWidget {
  final String scriptId;
  final int level;

  const VoiceCheckScreen({super.key, required this.scriptId, required this.level});

  @override
  ConsumerState<VoiceCheckScreen> createState() => _VoiceCheckScreenState();
}

// Section 5-F: スコアアニメーション用に TickerProviderStateMixin を追加
class _VoiceCheckScreenState extends ConsumerState<VoiceCheckScreen>
    with TickerProviderStateMixin {
  late Script _script;
  Script? _nextScript;
  RecognitionMode _mode = RecognitionMode.fullRecitation;
  bool _isRecording = false;
  late HintLevel _hintLevel;
  bool _isListeningStarted = false;
  late final _budouxParser = const Budoux();
  String _partialText = '';
  String _recognizedText = '';
  int _elapsedSeconds = 0;
  Timer? _timer;
  MatchResult? _matchResult;
  bool _showResult = false;
  bool _initialized = false;
  double? _previousScore;
  final Set<String> _allowedKeys = {};
  RealtimeMatcher? _realtimeMatcher;
  RealtimeMatchState? _realtimeState;
  bool _isProcessing = false;
  bool _showOriginal = true;

  // Section 5-F: スコアカウントアップアニメーション
  late final AnimationController _scoreAnimCtrl;
  late Animation<double> _scoreAnim;

  int get _maxSeconds =>
      _mode == RecognitionMode.fullRecitation ? 300 : 60;

  @override
  void initState() {
    super.initState();
    switch (widget.level) {
      case 6:
        _hintLevel = HintLevel.firstAndLastChars;
        break;
      case 7:
        _hintLevel = HintLevel.particles;
        break;
      case 8:
        _hintLevel = HintLevel.hidden;
        break;
      case 5:
      default:
        _hintLevel = HintLevel.showAll;
        break;
    }
    _loadData();
    
    // 音声認識サービスの初期化をあらかじめバックグラウンドで開始しておく
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(speechRecognitionServiceProvider).initialize();
    });

    _scoreAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scoreAnim = const AlwaysStoppedAnimation(0.0);
  }

  void _loadData() {
    final scripts = ref.read(scriptsListProvider);
    final sortedScripts = List<Script>.from(scripts)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final currentIndex = sortedScripts.indexWhere((s) => s.id == widget.scriptId);
    _nextScript = (currentIndex != -1 && currentIndex < sortedScripts.length - 1)
        ? sortedScripts[currentIndex + 1]
        : null;

    _script = scripts.firstWhere((s) => s.id == widget.scriptId);

    final progressRepo = ref.read(progressRepositoryProvider);
    _previousScore = progressRepo.getPreviousScore(widget.scriptId, 'voice');

    // レベル4〜7が対象なので、初期状態ではヒントあり、レベル7（完全暗唱）のみ非表示に初期化
    _showOriginal = _hintLevel != HintLevel.hidden;

    setState(() => _initialized = true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scoreAnimCtrl.dispose();
    super.dispose();
  }

  Future<bool> _showExitConfirmationDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認の中止'),
        content: const Text('音声暗記確認を中止して詳細画面に戻りますか？'),
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
    if (!_initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_showResult && _matchResult != null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          context.go('/detail/${widget.scriptId}');
        },
        child: _buildResultScreen(),
      );
    }

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
          title: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text('${_script.sortOrder}. ${_script.title}'),
          ),
        ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '「${_script.title}」',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  RankChip(rank: _script.rank),
                  ..._script.tags.map((tag) {
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
                  }),
                ],
              ),
              const SizedBox(height: 16),
              // 原文表示エリア — Section 1-E: outlineDecoration
              GestureDetector(
                onTap: () => setState(() => _showOriginal = !_showOriginal),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: AppTheme.outlineDecoration,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _showOriginal
                                ? Icons.visibility
                                : Icons.visibility_off,
                            size: 16,
                            color: AppTheme.grey500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '原文（タップで表示/非表示）',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.grey500,
                            ),
                          ),
                        ],
                      ),
                      // Section 5-C: AnimatedSize で原文の展開/折りたたみ
                      AnimatedSize(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        child: _showOriginal
                            ? Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  _getHintText(_script.content, _hintLevel),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    height: 1.8,
                                    color: AppTheme.textDark,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // 認識中テキスト
              const Text(
                '認識中のテキスト:',
                style: TextStyle(fontSize: 14, color: AppTheme.textLight),
              ),
              const SizedBox(height: 8),
              Container(
                height: 160,
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(
                    // 録音中は primary border に上書き
                    color: _isRecording ? AppTheme.primary : AppTheme.grey200,
                    width: _isRecording ? 2 : 1,
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildRecognitionText(),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            // モード切替
            Center(
              child: SegmentedButton<RecognitionMode>(
                segments: const [
                  ButtonSegment(
                    value: RecognitionMode.immediate,
                    label: Text('即時中断'),
                    icon: Icon(Icons.flash_on, size: 16),
                  ),
                  ButtonSegment(
                    value: RecognitionMode.fullRecitation,
                    label: Text('全文暗唱'),
                    icon: Icon(Icons.article, size: 16),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: _isRecording
                    ? null
                    : (newSelection) {
                        setState(() => _mode = newSelection.first);
                      },
                style: ButtonStyle(
                  textStyle: WidgetStatePropertyAll(
                    const TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // 録音ボタン
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _isRecording ? _stopRecording : _startRecording,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: _isRecording
                            ? AppTheme.error
                            : AppTheme.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color:
                                (_isRecording ? AppTheme.error : AppTheme.primary)
                                    .withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        _isRecording ? Icons.stop : Icons.mic,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isRecording
                        ? '$_formattedTime / ${_maxSeconds ~/ 60}:${(_maxSeconds % 60).toString().padLeft(2, '0')}'
                        : '録音開始',
                    style: TextStyle(
                      fontSize: 14,
                      color: _isRecording ? AppTheme.error : AppTheme.grey500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (_isRecording) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _isListeningStarted
                                ? AppTheme.secondary
                                : AppTheme.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isListeningStarted ? 'お話しください 🎤' : '準備中...',
                          style: TextStyle(
                            fontSize: 12,
                            color: _isListeningStarted
                                ? AppTheme.secondary
                                : AppTheme.grey500,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ),
  ),
);
}

  String get _formattedTime {
    final minutes = _elapsedSeconds ~/ 60;
    final seconds = _elapsedSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('マイクの権限が必要です')),
        );
      }
      return;
    }

    if (_isProcessing) return;

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

    final parentheses =
        TextNormalizer.parseParenthesesMode(_script.parenthesesMode);
    _realtimeMatcher = RealtimeMatcher(
      _script.content,
      parentheses: parentheses,
    );
    _realtimeState = null;

    setState(() {
      _isRecording = true;
      _isListeningStarted = false;
      _partialText = '';
      _recognizedText = '';
      _elapsedSeconds = 0;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _elapsedSeconds++);
      if (_elapsedSeconds >= _maxSeconds) {
        _stopRecording();
      }
    });

    await speechService.startListening(
      mode: _mode,
      listenFor: Duration(seconds: _maxSeconds),
      onListeningStarted: () {
        if (mounted) {
          setState(() => _isListeningStarted = true);
        }
      },
      onResult: (text) {
        setState(() {
          _recognizedText = text;
          _partialText = text;
        });
        if (_mode == RecognitionMode.immediate) {
          _stopRecording();
        }
      },
      onPartialResult: (text) {
        final state = _realtimeMatcher?.processPartial(text);
        if (state != null && state.newMismatchDetected) {
          HapticFeedback.heavyImpact();
        }
        setState(() {
          _partialText = text;
          _realtimeState = state;
        });
      },
      onError: (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('音声認識エラー: $error')),
          );
        }
      },
    );
  }

  Future<void> _stopRecording() async {
    if (_isProcessing) return;
    _isProcessing = true;
    _timer?.cancel();
    _realtimeMatcher?.reset();
    setState(() {
      _isRecording = false;
      _isListeningStarted = false;
      _realtimeState = null;
    });

    await Future.delayed(const Duration(milliseconds: 1200));

    final speechService = ref.read(speechRecognitionServiceProvider);
    await speechService.stopListening();

    if (_mode == RecognitionMode.fullRecitation) {
      final accumulated = speechService.accumulatedText;
      if (_partialText.length > accumulated.length) {
        _recognizedText = _partialText;
      } else if (accumulated.isNotEmpty) {
        _recognizedText = accumulated;
        _partialText = accumulated;
      }
    } else if (_partialText.isNotEmpty) {
      _recognizedText = _partialText;
    }

    if (_recognizedText.isEmpty) {
      _isProcessing = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('音声が認識できませんでした。もう一度お試しください。')),
        );
      }
      return;
    }

    final matcher = TextMatcher();
    final parentheses =
        TextNormalizer.parseParenthesesMode(_script.parenthesesMode);
    final allowedPairsRepo = ref.read(allowedPairsRepositoryProvider);
    final allowedPairs = allowedPairsRepo.getByScriptId(widget.scriptId);
    final result = await matcher.matchAsync(
      _script.content,
      _recognizedText,
      parentheses: parentheses,
      cachedOriginalHiragana: _script.fullTextHiragana,
      allowedPairs: allowedPairs,
    );

    final progressRepo = ref.read(progressRepositoryProvider);
    await progressRepo.addSession(
      scriptId: widget.scriptId,
      mode: 'voice',
      level: widget.level,
      score: result.similarityScore,
      durationSeconds: _elapsedSeconds,
      recognizedText: _recognizedText,
    );
    await progressRepo.updateScriptProgress(
        _script, result.similarityScore, 'voice', widget.level);
    ref.read(scriptsListProvider.notifier).refresh();

    _isProcessing = false;

    // Section 5-F: スコアアニメーション設定してから結果表示
    _scoreAnim = Tween<double>(begin: 0, end: result.similarityScore).animate(
      CurvedAnimation(parent: _scoreAnimCtrl, curve: Curves.easeOutCubic),
    );

    setState(() {
      _matchResult = result;
      _showResult = true;
    });

    _scoreAnimCtrl.forward(from: 0);
  }

  Future<void> _markAsCorrect(
      String originalWord, String recognizedWord) async {
    final repo = ref.read(allowedPairsRepositoryProvider);
    if (repo.exists(widget.scriptId, originalWord, recognizedWord)) return;

    await repo.add(
      scriptId: widget.scriptId,
      originalWord: originalWord,
      recognizedWord: recognizedWord,
    );

    setState(() {
      _allowedKeys.add('$originalWord→$recognizedWord');
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('「$recognizedWord」→「$originalWord」を許容語として登録しました'),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    await _recalculateScore();
  }

  Future<void> _recalculateScore() async {
    if (_recognizedText.isEmpty) return;

    final matcher = TextMatcher();
    final parentheses =
        TextNormalizer.parseParenthesesMode(_script.parenthesesMode);
    final allowedPairsRepo = ref.read(allowedPairsRepositoryProvider);
    final allowedPairs = allowedPairsRepo.getByScriptId(widget.scriptId);
    final result = await matcher.matchAsync(
      _script.content,
      _recognizedText,
      parentheses: parentheses,
      cachedOriginalHiragana: _script.fullTextHiragana,
      allowedPairs: allowedPairs,
    );

    final progressRepo = ref.read(progressRepositoryProvider);
    await progressRepo.updateScriptProgress(
        _script, result.similarityScore, 'voice', widget.level);
    ref.read(scriptsListProvider.notifier).refresh();

    setState(() {
      _matchResult = result;
    });
  }

  Widget _buildRecognitionText() {
    if (_partialText.isEmpty && !_isRecording) {
      return Text(
        '録音ボタンを押して暗唱してください',
        style: TextStyle(fontSize: 16, height: 1.8, color: AppTheme.grey400),
      );
    }

    final state = _realtimeState;
    if (state == null || _partialText.isEmpty) {
      return Text(
        _partialText,
        style: const TextStyle(
          fontSize: 16,
          height: 1.8,
          color: AppTheme.textDark,
        ),
      );
    }

    final cutoff = state.rawMatchedUpTo.clamp(0, _partialText.length);
    final matchedPart = _partialText.substring(0, cutoff);
    final mismatchPart = _partialText.substring(cutoff);

    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 16, height: 1.8),
        children: [
          if (matchedPart.isNotEmpty)
            TextSpan(
              text: matchedPart,
              style: const TextStyle(color: AppTheme.secondary),
            ),
          if (mismatchPart.isNotEmpty)
            TextSpan(
              text: mismatchPart,
              style: const TextStyle(color: AppTheme.diffMissing),
            ),
        ],
      ),
    );
  }

  Widget _buildResultScreen() {
    final result = _matchResult!;
    final scoreDiff = _previousScore != null
        ? result.similarityScore - _previousScore!
        : null;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/detail/${widget.scriptId}'),
        ),
        title: const Text('暗記確認結果'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.cardDecoration,
              child: Text(
                '${_script.sortOrder}. ${_script.title}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            // Section 5-F: カウントアップアニメーション
            AnimatedBuilder(
              animation: _scoreAnim,
              builder: (context, child) {
                return Column(
                  children: [
                    Text(
                      '${_scoreAnim.value.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 64,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.scoreColor(result.similarityScore),
                      ),
                    ),
                    Text(
                      result.scoreLabel,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.scoreColor(result.similarityScore),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            // Diff 表示
            DiffResultWidget(
              segments: result.diffSegments,
              onMarkCorrect: _markAsCorrect,
              alreadyAllowed: _allowedKeys,
            ),
            const SizedBox(height: 16),
            // 前回比較
            if (scoreDiff != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scoreDiff >= 0
                      ? AppTheme.secondary.withValues(alpha: 0.1)
                      : AppTheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Text(
                  '前回: ${_previousScore!.toStringAsFixed(0)}% → 今回: ${result.similarityScore.toStringAsFixed(0)}% '
                  '(${scoreDiff >= 0 ? "↑" : "↓"}${scoreDiff.abs().toStringAsFixed(0)}%)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: scoreDiff >= 0 ? AppTheme.secondary : AppTheme.error,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 24),
            // ボタン
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            context.go('/detail/${widget.scriptId}'),
                        child: const Text('詳細に戻る'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          final passed = result.similarityScore >= 80;
                          if (passed && widget.level < 8) {
                            context.pushReplacement(
                                '/voice-check/${widget.scriptId}/${widget.level + 1}');
                          } else {
                            _realtimeMatcher?.reset();
                            setState(() {
                              _showResult = false;
                              _matchResult = null;
                              _partialText = '';
                              _recognizedText = '';
                              _realtimeState = null;
                            });
                          }
                        },
                        child: Text((result.similarityScore >= 80 && widget.level < 8)
                            ? '次のレベル（レベル${widget.level + 1}）へ'
                            : 'もう一度挑戦'),
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
                if (_nextScript != null && result.similarityScore >= 80) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        context.pushReplacement('/voice-check/${_nextScript!.id}/${widget.level}');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.secondary,
                        foregroundColor: Colors.white,
                      ),
                      child: Text('次の問題（No.${_nextScript!.sortOrder}）へ'),
                    ),
                  ),
                ],
                if (result.similarityScore < 80 && widget.level > 2) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final prevLevel = widget.level - 1;
                        if (prevLevel < 5) {
                          context.pushReplacement(
                              '/practice/${widget.scriptId}/$prevLevel');
                        } else {
                          context.pushReplacement(
                              '/voice-check/${widget.scriptId}/$prevLevel');
                        }
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
    );
  }
  String _getHintText(String text, HintLevel level) {
    switch (level) {
      case HintLevel.showAll:
        try {
          final lines = text.split('\n');
          final processedLines = lines.map((line) {
            if (line.isEmpty) return '';
            final chunks = _budouxParser.parse(line);
            return chunks.join('　');
          });
          return processedLines.join('\n');
        } catch (_) {
          return text;
        }
      case HintLevel.firstAndLastChars:
        return _applyFirstAndLastCharsHint(text);
      case HintLevel.particles:
        return _applyParticlesHint(text);
      case HintLevel.hidden:
        return '';
    }
  }

  String _applyFirstAndLastCharsHint(String text) {
    final lines = text.split('\n');
    final resultLines = lines.map((line) {
      if (line.isEmpty) return '';

      // 1. 文頭の記号・番号（①、1.、- など）を検出
      final symbolRegex = RegExp(r'^([0-9０-９a-zA-Zａ-ｚＡ-Ｚ①-⑳㈠-㈩\.\-－‐—―−⁃✓■◆▲●○・\s　]+)');
      final match = symbolRegex.firstMatch(line);
      final prefixLength = match != null ? match.group(0)!.length : 0;
      final prefixText = prefixLength > 0 ? line.substring(0, prefixLength) : '';
      final bodyText = prefixLength > 0 ? line.substring(prefixLength) : line;

      if (bodyText.isEmpty) {
        return prefixText;
      }

      // 2. 本文の文頭キーワード（最初の2文字）を取得
      final punc = RegExp(r'[。、？！\s　]');
      final validBodyIndices = <int>[];
      for (int i = 0; i < bodyText.length; i++) {
        if (!punc.hasMatch(bodyText[i])) {
          validBodyIndices.add(i);
        }
      }

      // 本文が短すぎる場合はそのまま返す
      if (validBodyIndices.length <= 4) {
        return prefixText + bodyText;
      }

      // 文頭の表示対象インデックス（本文基準）
      final showIndices = <int>{};
      if (validBodyIndices.isNotEmpty) showIndices.add(validBodyIndices[0]);
      if (validBodyIndices.length >= 2) showIndices.add(validBodyIndices[1]);

      // 3. Budoux を使用した文末キーワードの抽出
      String lastWord = '';
      try {
        final chunks = _budouxParser.parse(bodyText).toList();
        if (chunks.isNotEmpty) {
          var lastChunk = chunks.last;
          // 文末の句読点等は除く
          lastChunk = lastChunk.replaceAll(RegExp(r'[。、？！\s　]+$'), '');
          
          if (lastChunk.length <= 2 && chunks.length >= 2) {
            // 末尾チャンクが短い（例: 「ある」「だ」など）場合は、一つ前のチャンクも結合
            var prevChunk = chunks[chunks.length - 2];
            lastWord = prevChunk + lastChunk;
          } else {
            lastWord = lastChunk;
          }
        }
      } catch (_) {}

      // もしBudouxでの抽出がうまくいかない・空の場合は従来の末尾2文字にフォールバック
      if (lastWord.isEmpty) {
        final lastIdx1 = validBodyIndices[validBodyIndices.length - 1];
        final lastIdx2 = validBodyIndices[validBodyIndices.length - 2];
        lastWord = bodyText[lastIdx2] + bodyText[lastIdx1];
      }

      // 本文内の文末キーワードの開始位置を検索（末尾から検索して安全にマッチさせる）
      final lastWordStart = bodyText.lastIndexOf(lastWord);

      final buffer = StringBuffer();
      // 記号部分はそのまま追加
      buffer.write(prefixText);

      for (int i = 0; i < bodyText.length; i++) {
        final char = bodyText[i];
        
        // 句読点等の記号、または文頭ヒント位置、または文末キーワードに含まれる範囲ならそのまま表示
        final isPunc = punc.hasMatch(char);
        final isFrontHint = showIndices.contains(i);
        final isBackHint = lastWordStart != -1 && i >= lastWordStart && i < lastWordStart + lastWord.length;

        if (isPunc || isFrontHint || isBackHint) {
          buffer.write(char);
        } else {
          buffer.write('＿');
        }
      }

      return buffer.toString();
    });
    return resultLines.join('\n');
  }

  String _applyParticlesHint(String text) {
    const particles = {'は', 'が', 'を', 'に', 'へ', 'と', 'で', 'も', 'の', 'か', 'や', 'から', 'より'};
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      if (particles.contains(char) ||
          char == '。' ||
          char == '、' ||
          char == '\n' ||
          char == '？' ||
          char == '！' ||
          char == ' ' ||
          char == '　') {
        buffer.write(char);
      } else {
        buffer.write('＿');
      }
    }
    return buffer.toString();
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
            for (int lvl = 5; lvl <= 8; lvl++) ...[
              _buildLevelOption(ctx, lvl, scriptId, currentLevel),
              if (lvl < 8) const SizedBox(height: 8),
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
      5: 'Level 5: 全文表示',
      6: 'Level 6: 文頭・文末ヒント',
      7: 'Level 7: 助詞ヒント',
      8: 'Level 8: 完全暗唱',
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
          context.pushReplacement('/voice-check/$scriptId/$level');
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
