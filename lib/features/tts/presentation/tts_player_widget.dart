import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../data/tts_service.dart';

class TtsPlayerWidget extends ConsumerStatefulWidget {
  final String text;

  const TtsPlayerWidget({super.key, required this.text});

  @override
  ConsumerState<TtsPlayerWidget> createState() => _TtsPlayerWidgetState();
}

class _TtsPlayerWidgetState extends ConsumerState<TtsPlayerWidget> {
  late TtsService _ttsService;
  TtsState _ttsState = TtsState.stopped;
  double _speechRate = 0.9;
  bool _sentenceBySentence = false;
  bool _initialized = false;

  static const List<double> speedOptions = [0.5, 0.75, 1.0, 1.25];

  @override
  void initState() {
    super.initState();
    _ttsService = ref.read(ttsServiceProvider);
    _init();
  }

  Future<void> _init() async {
    await _ttsService.initialize();
    _ttsService.stateStream.listen((state) {
      if (mounted) {
        setState(() => _ttsState = state);
      }
    });
    setState(() => _initialized = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const SizedBox.shrink();
    }

    return Container(
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
              const Icon(Icons.volume_up, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              const Text(
                '読み上げ',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 再生コントロール
          Row(
            children: [
              // 再生/一時停止
              IconButton.filled(
                onPressed: _ttsState == TtsState.playing ? _stop : _play,
                icon: Icon(
                  _ttsState == TtsState.playing
                      ? Icons.stop_circle
                      : Icons.play_circle_outline,
                ),
                iconSize: 36,
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              // 次の文へ（一文ずつモード時）
              if (_sentenceBySentence && _ttsService.waitingForNext)
                IconButton(
                  onPressed: () => _ttsService.nextSentence(),
                  icon: const Icon(Icons.skip_next),
                  tooltip: '次の文へ',
                  color: AppTheme.primary,
                ),
              const Spacer(),
              // 速度表示
              Text(
                '${_speechRate}x',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 速度調整
          Row(
            children: [
              const Text('速度: ', style: TextStyle(fontSize: 13)),
              Expanded(
                child: Slider(
                  value: _speechRate,
                  min: 0.5,
                  max: 1.25,
                  divisions: 3,
                  label: '${_speechRate}x',
                  onChanged: (value) {
                    setState(() {
                      _speechRate = speedOptions.reduce(
                          (prev, curr) =>
                              (curr - value).abs() < (prev - value).abs()
                                  ? curr
                                  : prev);
                    });
                    _ttsService.setSpeechRate(_speechRate);
                  },
                ),
              ),
            ],
          ),
          // 一文ずつモード
          Row(
            children: [
              Switch(
                value: _sentenceBySentence,
                onChanged: (value) {
                  setState(() => _sentenceBySentence = value);
                  if (_ttsState == TtsState.playing) {
                    _stop();
                  }
                },
                activeThumbColor: AppTheme.primary,
              ),
              const Text('一文ずつモード', style: TextStyle(fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _play() async {
    await _ttsService.setSpeechRate(_speechRate);
    if (_sentenceBySentence) {
      await _ttsService.speakSentenceBySentence(widget.text);
    } else {
      await _ttsService.speak(widget.text);
    }
  }

  Future<void> _stop() async {
    await _ttsService.stop();
  }
}
