import 'dart:async';
import 'dart:typed_data';
import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
import '../domain/recognition_mode.dart';
import 'speech_recognition_service.dart';
import 'model_download_service.dart';

/// sherpa-onnx + SenseVoice によるオフライン音声認識実装
class SherpaSpeechRecognition implements SpeechRecognitionService {
  sherpa.OfflineRecognizer? _recognizer;
  sherpa.VoiceActivityDetector? _vad;
  final AudioRecorder _audioRecorder = AudioRecorder();
  StreamSubscription? _audioSubscription;

  bool _isListening = false;
  bool _stopping = false;
  String _accumulatedText = '';
  RecognitionMode _currentMode = RecognitionMode.fullRecitation;

  // デバッグ用状態管理
  DateTime? _recordingStartTime;
  int _totalSamplesReceived = 0;
  bool _firstChunkReceived = false;

  // コールバック
  Function(String)? _onResult;
  Function(String)? _onPartialResult;
  Function(String)? _onError;
  Function()? _onListeningStarted;

  // 音声バッファ（VADセグメント用）
  final List<double> _audioBuffer = [];
  static const int _sampleRate = 16000;

  final ModelDownloadService _downloadService;

  SherpaSpeechRecognition(this._downloadService);

  @override
  String get accumulatedText => _accumulatedText;

  @override
  bool get isListening => _isListening;

  bool _isInitialized = false;

  @override
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    try {
      // モデルの存在確認
      if (!await _downloadService.isModelDownloaded()) {
        return false;
      }

      final modelDir = await _downloadService.getModelDir();

      // sherpa-onnx バインディング初期化
      sherpa.initBindings();

      // SenseVoice オフライン認識器を構成
      final modelConfig = sherpa.OfflineModelConfig(
        senseVoice: sherpa.OfflineSenseVoiceModelConfig(
          model: '$modelDir/model.onnx',
          language: 'ja',
          useInverseTextNormalization: false,
        ),
        tokens: '$modelDir/tokens.txt',
        numThreads: 2,
        debug: false,
        provider: 'cpu',
      );

      final recognizerConfig = sherpa.OfflineRecognizerConfig(
        model: modelConfig,
        decodingMethod: 'greedy_search',
      );

      _recognizer = sherpa.OfflineRecognizer(recognizerConfig);

      // VAD（音声活動検出器）を構成
      final vadConfig = sherpa.VadModelConfig(
        sileroVad: sherpa.SileroVadModelConfig(
          // silero_vad モデルは sherpa-onnx に内蔵
          model: '$modelDir/silero_vad.onnx',
          threshold: 0.4,
          minSilenceDuration: 0.3,
          minSpeechDuration: 0.15,
          maxSpeechDuration: 30.0,
        ),
        sampleRate: _sampleRate,
        numThreads: 1,
        debug: false,
      );

      _vad = sherpa.VoiceActivityDetector(config: vadConfig, bufferSizeInSeconds: 60);

      _isInitialized = true;
      return true;
    } catch (e) {
      _onError?.call('初期化エラー: $e');
      return false;
    }
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
    if (_recognizer == null) {
      onError('認識器が初期化されていません');
      return;
    }

    _isListening = true;
    _stopping = false;
    _currentMode = mode;
    _accumulatedText = '';
    _audioBuffer.clear();
    _onResult = onResult;
    _onPartialResult = onPartialResult;
    _onListeningStarted = onListeningStarted;
    _onError = onError;

    // デバッグ状態初期化
    _recordingStartTime = DateTime.now();
    _totalSamplesReceived = 0;
    _firstChunkReceived = false;
    // ignore: avoid_print
    print('【音声認識】録音開始要求: $mode, 設定: 16kHz Mono');

    try {
      // 音声ストリームを開始（PCM 16bit, 16kHz, mono）
      final audioStream = await _audioRecorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: _sampleRate,
          numChannels: 1,
          autoGain: true,
          echoCancel: true,
          noiseSuppress: true,
        ),
      );

      _audioSubscription = audioStream.listen(
        (data) => _processAudioChunk(Uint8List.fromList(data)),
        onError: (error) {
          _onError?.call('音声取得エラー: $error');
        },
      );
    } catch (e) {
      _isListening = false;
      onError('録音開始エラー: $e');
    }
  }

  /// 音声チャンクを処理
  void _processAudioChunk(Uint8List bytes) {
    if (_stopping || !_isListening) return;

    if (!_firstChunkReceived) {
      _firstChunkReceived = true;
      final elapsed = DateTime.now().difference(_recordingStartTime!);
      // ignore: avoid_print
      print('【音声認識】最初の音声チャンク受信完了: ${elapsed.inMilliseconds}ms');
      
      // 最初の音声チャンクが届いた（確実に録音が開始された）タイミングで振動を通知
      _onListeningStarted?.call();
      _onListeningStarted = null;
    }

    _totalSamplesReceived += bytes.length ~/ 2; // pcm16bits なので 2bytes = 1sample

    // PCM 16bit LE → Float32 に変換
    final samples = _bytesToFloat32(bytes);
    _audioBuffer.addAll(samples);

    // VAD に音声を渡す
    _vad?.acceptWaveform(Float32List.fromList(samples));

    // VAD が音声セグメントを検出したか確認
    while (_vad != null && !(_vad!.isEmpty())) {
      final segment = _vad!.front();
      _vad!.pop();

      // セグメントの音声を認識
      _recognizeSegment(Float32List.fromList(segment.samples));
    }

    // 録音中は「認識中」を表示
    if (_accumulatedText.isNotEmpty) {
      _onPartialResult?.call('$_accumulatedText...');
    }
  }

  /// 音声セグメントを認識
  void _recognizeSegment(Float32List samples) {
    if (_recognizer == null) return;

    final stream = _recognizer!.createStream();
    stream.acceptWaveform(samples: samples, sampleRate: _sampleRate);
    _recognizer!.decode(stream);
    final result = _recognizer!.getResult(stream);
    stream.free();

    final text = result.text.trim();
    if (text.isEmpty) return;

    if (_currentMode == RecognitionMode.immediate) {
      // 即時中断モード: 最初の認識結果で停止
      _onResult?.call(text);
    } else {
      // 全文暗唱モード: テキストを蓄積
      _accumulatedText += text;
      _onPartialResult?.call(_accumulatedText);
    }
  }

  @override
  Future<void> stopListening() async {
    if (_stopping || !_isListening) return;
    _stopping = true;

    // ignore: avoid_print
    print('【音声認識】録音停止要求. 最後のマイクバッファ回収のため250ms待機します... (総受信サンプル数: $_totalSamplesReceived)');

    // マイクバッファにたまっている音声が処理されるよう少し待つ
    await Future.delayed(const Duration(milliseconds: 250));

    _isListening = false;

    _audioSubscription?.cancel();
    _audioSubscription = null;
    await _audioRecorder.stop();

    // VAD をフラッシュして残りのセグメントを処理
    _vad?.flush();
    while (_vad != null && !(_vad!.isEmpty())) {
      final segment = _vad!.front();
      _vad!.pop();
      _recognizeSegment(Float32List.fromList(segment.samples));
    }

    // 全文暗唱モード: 蓄積テキストを最終結果として返す
    if (_currentMode == RecognitionMode.fullRecitation &&
        _accumulatedText.isNotEmpty) {
      _onResult?.call(_accumulatedText);
    }

    // VAD にバッファが残っておらず、即時モードで結果が出なかった場合
    // バッファ全体を認識にかける
    if (_currentMode == RecognitionMode.immediate &&
        _audioBuffer.isNotEmpty) {
      _recognizeSegment(Float32List.fromList(_audioBuffer));
    }

    _audioBuffer.clear();
    _vad?.reset();
  }

  /// PCM 16bit LE バイト列を Float32 サンプル列に変換
  Float32List _bytesToFloat32(Uint8List bytes) {
    final int16Data = Int16List.view(bytes.buffer);
    final float32Data = Float32List(int16Data.length);
    for (int i = 0; i < int16Data.length; i++) {
      float32Data[i] = int16Data[i] / 32768.0;
    }
    return float32Data;
  }

  @override
  void dispose() {
    _stopping = true;
    _isListening = false;
    _audioSubscription?.cancel();
    _audioRecorder.dispose();
    _vad?.free();
    _recognizer?.free();
    _vad = null;
    _recognizer = null;
  }
}
