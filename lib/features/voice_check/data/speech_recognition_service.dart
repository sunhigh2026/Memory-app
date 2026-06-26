import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../../core/data/app_settings_repository.dart';
import '../domain/recognition_mode.dart';
import 'speech_engine_type.dart';
// Web環境ではsherpa_onnx（FFI）が使えないため条件付きインポート
import 'sherpa_speech_recognition.dart'
    if (dart.library.js_interop) 'sherpa_speech_recognition_stub.dart';
import 'model_download_service.dart';

/// 音声認識エンジンの抽象インターフェース
/// Phase 2 で sherpa-onnx に差し替え可能
abstract class SpeechRecognitionService {
  Future<bool> initialize();

  /// マイクを常時起動状態（ウォーム）にする。
  /// センスボイス使用時は、練習画面を開いている間ずっとマイクストリームを維持し
  /// リングバッファに音声を溜め続けることで、startListening 呼び出し時の起動ラグをゼロにする。
  /// Android標準エンジンでは何もしない（no-op）。
  Future<void> warmUp();

  /// ウォーム状態を解除してマイクストリームを完全に停止する。
  /// 練習画面から離脱するタイミングで呼び出す。
  Future<void> coolDown();

  Future<void> startListening({
    required Function(String) onResult,
    required Function(String) onPartialResult,
    required Function(String) onError,
    Function()? onListeningStarted,
    RecognitionMode mode = RecognitionMode.fullRecitation,
    Duration listenFor = const Duration(seconds: 60),
  });
  Future<void> stopListening();
  bool get isListening;
  String get accumulatedText;
  void dispose();
}

/// Phase 1: Android 標準 SpeechRecognizer 実装
class NativeSpeechRecognition implements SpeechRecognitionService {
  final SpeechToText _speech = SpeechToText();
  bool _isListening = false;
  RecognitionMode _currentMode = RecognitionMode.immediate;
  String _accumulatedText = '';
  bool _stopping = false;

  // コールバック保持（再開時に必要）
  Function(String)? _onResult;
  Function(String)? _onPartialResult;
  Function(String)? _onError;
  Function()? _onListeningStarted;
  Duration _listenFor = const Duration(seconds: 60);

  bool _isInitialized = false;

  @override
  String get accumulatedText => _accumulatedText;

  @override
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    final available = await _speech.initialize(
      onError: (error) {
        if (_currentMode == RecognitionMode.fullRecitation && !_stopping) {
          // 全文暗唱モードではエラー時も自動再開を試みる
          _restartListening();
        } else {
          _isListening = false;
          _onError?.call(error.errorMsg);
        }
      },
    );
    if (available) {
      _isInitialized = true;
    }
    return available;
  }

  @override
  Future<void> warmUp() async {
    // Android標準エンジンは常時起動不要のため何もしない
  }

  @override
  Future<void> coolDown() async {
    // Android標準エンジンは常時起動不要のため何もしない
  }

  @override
  Future<void> startListening({
    required Function(String) onResult,
    required Function(String) onPartialResult,
    required Function(String) onError,
    Function()? onListeningStarted,
    RecognitionMode mode = RecognitionMode.fullRecitation,
    Duration listenFor = const Duration(seconds: 60),
  }) async {
    _isListening = true;
    _stopping = false;
    _currentMode = mode;
    _accumulatedText = '';
    _onResult = onResult;
    _onPartialResult = onPartialResult;
    _onError = onError;
    _onListeningStarted = onListeningStarted;
    _listenFor = listenFor;

    await _startListeningInternal();
  }

  Future<void> _startListeningInternal() async {
    _onListeningStarted?.call();

    await _speech.listen(
      onResult: (result) {
        if (_stopping) return;

        if (_currentMode == RecognitionMode.immediate) {
          // 即時中断モード: 従来通り
          if (result.finalResult) {
            _onResult?.call(result.recognizedWords);
          } else {
            _onPartialResult?.call(result.recognizedWords);
          }
        } else {
          // 全文暗唱モード: テキストを蓄積
          if (result.finalResult) {
            if (result.recognizedWords.isNotEmpty) {
              _accumulatedText += result.recognizedWords;
            }
            _onPartialResult?.call(_accumulatedText);
            // 自動的に再開
            _restartListening();
          } else {
            // 部分結果: 蓄積済み + 現在の部分を表示
            _onPartialResult
                ?.call(_accumulatedText + result.recognizedWords);
          }
        }
      },
      listenFor: _listenFor,
      pauseFor: const Duration(seconds: 10),
      localeId: 'ja-JP',
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: false,
        listenMode: ListenMode.dictation,
      ),
      onSoundLevelChange: null,
    );
  }

  Future<void> _restartListening() async {
    if (_stopping || !_isListening) return;
    // プラットフォームエラー防止のため短い遅延
    await Future.delayed(const Duration(milliseconds: 150));
    if (_stopping || !_isListening) return;
    try {
      await _startListeningInternal();
    } catch (_) {
      // 再開失敗時は蓄積テキストを最終結果として返す
      if (_accumulatedText.isNotEmpty) {
        _onResult?.call(_accumulatedText);
      }
      _isListening = false;
    }
  }

  @override
  Future<void> stopListening() async {
    _stopping = true;
    _isListening = false;
    await _speech.stop();

    // 全文暗唱モード: 蓄積テキストを最終結果として返す
    if (_currentMode == RecognitionMode.fullRecitation &&
        _accumulatedText.isNotEmpty) {
      _onResult?.call(_accumulatedText);
    }
  }

  @override
  bool get isListening => _isListening || _speech.isListening;

  @override
  void dispose() {
    _stopping = true;
    _speech.stop();
    _speech.cancel();
  }
}

final speechRecognitionServiceProvider =
    Provider<SpeechRecognitionService>((ref) {
  final engineType = ref.watch(speechEngineTypeProvider);

  // Web環境ではsherpa-onnxは使用不可（FFI非対応）
  if (!kIsWeb && engineType == SpeechEngineType.sherpaOnnx) {
    final downloadService = ref.watch(modelDownloadServiceProvider);
    final service = SherpaSpeechRecognition(downloadService);
    ref.onDispose(() => service.dispose());
    return service;
  } else {
    final service = NativeSpeechRecognition();
    ref.onDispose(() => service.dispose());
    return service;
  }
});

