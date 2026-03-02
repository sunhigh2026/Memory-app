import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/text_normalizer.dart';
import '../../scripts/data/scripts_repository.dart';
import '../../progress/data/progress_repository.dart';
import '../data/speech_recognition_service.dart';
import '../domain/recognition_mode.dart';
import '../domain/text_matcher.dart';
import 'diff_result_widget.dart';
import '../../../models/script.dart';

class VoiceCheckScreen extends ConsumerStatefulWidget {
  final String scriptId;

  const VoiceCheckScreen({super.key, required this.scriptId});

  @override
  ConsumerState<VoiceCheckScreen> createState() => _VoiceCheckScreenState();
}

class _VoiceCheckScreenState extends ConsumerState<VoiceCheckScreen> {
  late Script _script;
  RecognitionMode _mode = RecognitionMode.immediate;
  bool _isRecording = false;
  bool _showOriginal = true;
  String _partialText = '';
  String _recognizedText = '';
  int _elapsedSeconds = 0;
  Timer? _timer;
  MatchResult? _matchResult;
  bool _showResult = false;
  bool _initialized = false;
  double? _previousScore;

  int get _maxSeconds =>
      _mode == RecognitionMode.fullRecitation ? 300 : 60;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final scripts = ref.read(scriptsListProvider);
    _script = scripts.firstWhere((s) => s.id == widget.scriptId);

    // 前回スコア取得
    final progressRepo = ref.read(progressRepositoryProvider);
    _previousScore = progressRepo.getPreviousScore(widget.scriptId, 'voice');

    setState(() => _initialized = true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_showResult && _matchResult != null) {
      return _buildResultScreen();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('音声暗記確認')),
      body: Padding(
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
            const SizedBox(height: 16),
            // 原文表示エリア
            GestureDetector(
              onTap: () => setState(() => _showOriginal = !_showOriginal),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _showOriginal ? Icons.visibility : Icons.visibility_off,
                          size: 16,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '原文（タップで表示/非表示）',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                    if (_showOriginal) ...[
                      const SizedBox(height: 8),
                      Text(
                        _script.content,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.8,
                          color: AppTheme.textDark,
                        ),
                      ),
                    ],
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
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isRecording ? AppTheme.primary : Colors.grey[200]!,
                    width: _isRecording ? 2 : 1,
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _partialText.isEmpty && !_isRecording
                            ? '録音ボタンを押して暗唱してください'
                            : _partialText,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.8,
                          color: _partialText.isEmpty
                              ? Colors.grey[400]
                              : AppTheme.textDark,
                        ),
                      ),
                      if (_isRecording)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.primary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '認識中',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
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
                        color: _isRecording ? AppTheme.error : AppTheme.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (_isRecording ? AppTheme.error : AppTheme.primary)
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
                      color: _isRecording ? AppTheme.error : Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
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
    // マイク権限チェック
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
      _isRecording = true;
      _partialText = '';
      _recognizedText = '';
      _elapsedSeconds = 0;
    });

    // タイマー開始
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _elapsedSeconds++);
      if (_elapsedSeconds >= _maxSeconds) {
        _stopRecording();
      }
    });

    await speechService.startListening(
      mode: _mode,
      listenFor: Duration(seconds: _maxSeconds),
      onResult: (text) {
        setState(() {
          _recognizedText = text;
          _partialText = text;
        });
        // 即時中断モードのみ自動停止
        if (_mode == RecognitionMode.immediate) {
          _stopRecording();
        }
      },
      onPartialResult: (text) {
        setState(() => _partialText = text);
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
    _timer?.cancel();
    final speechService = ref.read(speechRecognitionServiceProvider);
    await speechService.stopListening();

    // 全文暗唱モード: 蓄積テキストを使用
    if (_mode == RecognitionMode.fullRecitation) {
      final accumulated = speechService.accumulatedText;
      if (accumulated.isNotEmpty) {
        _recognizedText = accumulated;
        _partialText = accumulated;
      }
    } else if (_partialText.isNotEmpty) {
      _recognizedText = _partialText;
    }

    setState(() => _isRecording = false);

    if (_recognizedText.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('音声が認識できませんでした。もう一度お試しください。')),
        );
      }
      return;
    }

    // マッチング（括弧設定を適用）
    final matcher = TextMatcher();
    final parentheses =
        TextNormalizer.parseParenthesesMode(_script.parenthesesMode);
    final result = matcher.match(
      _script.content,
      _recognizedText,
      parentheses: parentheses,
    );

    // 進捗保存
    final progressRepo = ref.read(progressRepositoryProvider);
    await progressRepo.addSession(
      scriptId: widget.scriptId,
      mode: 'voice',
      level: 4,
      score: result.similarityScore,
      durationSeconds: _elapsedSeconds,
      recognizedText: _recognizedText,
    );
    await progressRepo.updateScriptProgress(
        _script, result.similarityScore, 'voice', 4);
    ref.read(scriptsListProvider.notifier).refresh();

    setState(() {
      _matchResult = result;
      _showResult = true;
    });
  }

  Widget _buildResultScreen() {
    final result = _matchResult!;
    final scoreDiff = _previousScore != null
        ? result.similarityScore - _previousScore!
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('暗記確認結果'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // スコア表示
            const SizedBox(height: 16),
            Text(
              '${result.similarityScore.toStringAsFixed(0)}%',
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
            const SizedBox(height: 24),
            // Diff 表示
            DiffResultWidget(segments: result.diffSegments),
            const SizedBox(height: 16),
            // 注記
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '音声認識の特性上、正しく発音しても異なる漢字で表示される場合があります',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
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
                  borderRadius: BorderRadius.circular(8),
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
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.go('/detail/${widget.scriptId}'),
                    child: const Text('原文確認'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _showResult = false;
                        _matchResult = null;
                        _partialText = '';
                        _recognizedText = '';
                      });
                    },
                    child: const Text('もう一度挑戦'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
