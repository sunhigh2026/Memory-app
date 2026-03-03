import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/text_normalizer.dart';
import '../data/cloze_generator.dart';
import '../../scripts/data/scripts_repository.dart';
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

class _PracticeScreenState extends ConsumerState<PracticeScreen> {
  late Script _script;
  late List<ClozeWord> _clozeWords;
  int _currentIndex = 0;
  int _correctCount = 0;
  int _hintUsed = 0;
  bool _showingResult = false;
  bool? _lastAnswerCorrect;
  String _correctAnswer = '';
  final _inputController = TextEditingController();
  final _generator = ClozeGenerator();

  @override
  void initState() {
    super.initState();
    _loadScript();
  }

  void _loadScript() {
    final scripts = ref.read(scriptsListProvider);
    _script = scripts.firstWhere((s) => s.id == widget.scriptId);

    final density = ClozeGenerator.densityForLevel(widget.level);
    _clozeWords = _generator.generate(_script.content, densityPercent: density);

    if (_clozeWords.isEmpty) {
      _clozeWords = _generator.generate(_script.content, densityPercent: 30);
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
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

    return Scaffold(
      appBar: AppBar(
        title: Text('Level ${widget.level} 穴埋め練習'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '${_currentIndex + 1} / ${_clozeWords.length}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
            backgroundColor: Colors.grey[200],
            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
          ),
          // テキスト表示（穴あき）— スクロール可能
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildClozeText(currentWord),
            ),
          ),
          // 回答エリア（画面下部に固定）
          Container(
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
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_showingResult) ...[
                      _buildResultDisplay(),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _next,
                          child: Text(
                            _currentIndex < _clozeWords.length - 1 ? '次へ' : '結果を見る',
                          ),
                        ),
                      ),
                    ],
                    if (!_showingResult) ...[
                      widget.level == 1
                          ? _buildChoices(currentWord)
                          : _buildInputField(currentWord),
                      if (widget.level > 1 && _hintUsed < 3)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: OutlinedButton.icon(
                            onPressed: () => _showHint(currentWord),
                            icon: const Icon(Icons.lightbulb_outline, size: 18),
                            label: Text('ヒント (${3 - _hintUsed})'),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClozeText(ClozeWord target) {
    final content = _script.content;
    final spans = <TextSpan>[];

    int lastEnd = 0;
    for (final cw in _clozeWords) {
      // 穴埋め前のテキスト
      if (cw.startIndex > lastEnd) {
        spans.add(TextSpan(
          text: content.substring(lastEnd, cw.startIndex),
          style: const TextStyle(fontSize: 16, height: 1.8, color: AppTheme.textDark),
        ));
      }

      if (cw == target) {
        // 現在の問題箇所
        spans.add(TextSpan(
          text: '＿' * cw.word.length,
          style: const TextStyle(
            fontSize: 16,
            height: 1.8,
            color: AppTheme.primary,
            fontWeight: FontWeight.bold,
            decoration: TextDecoration.underline,
            decorationColor: AppTheme.primary,
          ),
        ));
      } else {
        // 他の穴埋め箇所（グレーの下線）
        spans.add(TextSpan(
          text: '＿' * cw.word.length,
          style: TextStyle(
            fontSize: 16,
            height: 1.8,
            color: Colors.grey[400],
          ),
        ));
      }
      lastEnd = cw.endIndex;
    }

    // 残りのテキスト
    if (lastEnd < content.length) {
      spans.add(TextSpan(
        text: content.substring(lastEnd),
        style: const TextStyle(fontSize: 16, height: 1.8, color: AppTheme.textDark),
      ));
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Text.rich(TextSpan(children: spans)),
    );
  }

  Widget _buildChoices(ClozeWord target) {
    final choices = _generator.generateChoices(target.word, _clozeWords);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: choices.map((choice) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: OutlinedButton(
            onPressed: () => _checkAnswer(choice, target.word),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(fontSize: 16),
            ),
            child: Text(choice),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInputField(ClozeWord target) {
    return Column(
      children: [
        TextField(
          controller: _inputController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: '答えを入力してください',
            suffixIcon: IconButton(
              icon: const Icon(Icons.send),
              onPressed: () =>
                  _checkAnswer(_inputController.text.trim(), target.word),
            ),
          ),
          onSubmitted: (value) => _checkAnswer(value.trim(), target.word),
        ),
      ],
    );
  }

  Widget _buildResultDisplay() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _lastAnswerCorrect == true
            ? AppTheme.secondary.withValues(alpha: 0.1)
            : AppTheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
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
            color: _lastAnswerCorrect == true ? AppTheme.secondary : AppTheme.error,
            size: 48,
          ),
          const SizedBox(height: 8),
          Text(
            _lastAnswerCorrect == true ? '正解！' : '不正解',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _lastAnswerCorrect == true ? AppTheme.secondary : AppTheme.error,
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

  void _checkAnswer(String answer, String correct) {
    if (answer.isEmpty) return;

    // 正規化して比較
    final normalizedAnswer = TextNormalizer.katakanaToHiragana(answer);
    final normalizedCorrect = TextNormalizer.katakanaToHiragana(correct);

    final isCorrect = normalizedAnswer == normalizedCorrect ||
        answer == correct;

    setState(() {
      _showingResult = true;
      _lastAnswerCorrect = isCorrect;
      _correctAnswer = correct;
      if (isCorrect) _correctCount++;
    });

    _inputController.clear();
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
    if (_currentIndex < _clozeWords.length - 1) {
      setState(() {
        _currentIndex++;
        _showingResult = false;
        _lastAnswerCorrect = null;
      });
    } else {
      // 練習完了 → 結果画面へ
      final score = _clozeWords.isEmpty
          ? 0.0
          : (_correctCount / _clozeWords.length) * 100;
      context.pushReplacement('/practice-result', extra: {
        'scriptId': widget.scriptId,
        'score': score,
        'level': widget.level,
        'totalQuestions': _clozeWords.length,
        'correctAnswers': _correctCount,
      });
    }
  }
}
