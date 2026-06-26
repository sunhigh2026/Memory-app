import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
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
  bool _isWarmedUp = false;
  bool _stopping = false;
  String _accumulatedText = '';
  RecognitionMode _currentMode = RecognitionMode.fullRecitation;

  // 無音自動停止用の状態変数
  bool _hasSpeechStarted = false;
  int _silenceSamplesCount = 0;

  // しきい値設定
  static const double _speechVolumeThreshold = 0.015; // 発話開始とみなすRMSしきい値
  static const double _silenceVolumeThreshold = 0.010; // 無音とみなすRMSしきい値
  static const int _silenceDurationSamples = 19200; // 1.2秒の無音 @ 16kHz (1.2 * 16000)


  // コールバック
  Function(String)? _onResult;
  Function(String)? _onPartialResult;
  Function(String)? _onError;

  // 音声バッファ（VADセグメント用）
  final List<double> _audioBuffer = [];
  static const int _sampleRate = 16000;

  // プリパディング用リングバッファ（直近300ms = 4800サンプル）
  static const int _prePadSamples = 4800; // 300ms @ 16kHz
  final Queue<double> _ringBuffer = Queue<double>();

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
          minSilenceDuration: 0.8, // 0.3秒から0.8秒に延長（話の合間の途切れ防止）
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

  /// マイクを常時起動状態（ウォーム）にする。
  /// 練習画面を開いた直後に呼び出し、マイクストリームを維持し続けることで
  /// 録音開始時のラグをゼロにする。音声はリングバッファに蓄積するのみで認識はしない。
  @override
  Future<void> warmUp() async {
    // センスボイスのマイク常時接続を廃止するため、no-op化
    _isWarmedUp = false;
  }

  /// ウォーム状態を解除してマイクストリームを完全に停止する。
  /// 練習画面から離脱するタイミングで呼び出す。
  @override
  Future<void> coolDown() async {
    // センスボイスのマイク常時接続を廃止するため、no-op化
    _isWarmedUp = false;
    _isListening = false;
    _stopping = false;

    _audioSubscription?.cancel();
    _audioSubscription = null;
    await _audioRecorder.stop();
    _ringBuffer.clear();
    _audioBuffer.clear();
    _vad?.reset();
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
    _onError = onError;
    _hasSpeechStarted = false;
    _silenceSamplesCount = 0;

    // ignore: avoid_print
    print('【音声認識】認識開始: $mode, ウォーム状態: $_isWarmedUp');

    if (_isWarmedUp) {
      // ウォーム状態: マイクは既に起動済み。ボタンタップ前のノイズ（タップ音など）混入を防ぐため、
      // プリパディング（先読み）は適用せず、バッファをクリアしてタップした瞬間から開始します。
      _ringBuffer.clear();

      // 起動ラグがないため即座に通知（コールバックが設定されている場合のみ）
      onListeningStarted?.call();
    } else {
      // ウォーム状態ではない場合はフォールバック（通常起動）
      try {
        final audioStream = await _audioRecorder.startStream(
          const RecordConfig(
            encoder: AudioEncoder.pcm16bits,
            sampleRate: _sampleRate,
            numChannels: 1,
            autoGain: true,
            echoCancel: false,
            noiseSuppress: false,
          ),
        );

        _audioSubscription = audioStream.listen(
          (data) => _processAudioChunk(_bytesToFloat32(Uint8List.fromList(data))),
          onError: (error) {
            _onError?.call('音声取得エラー: $error');
          },
        );

        onListeningStarted?.call();
      } catch (e) {
        _isListening = false;
        onError('録音開始エラー: $e');
      }
    }
  }

  /// 音声データをパイプラインに流す（ウォーム状態でstartListening後に呼ばれる）
  void _processAudioChunk(Float32List samples) {
    if (_stopping || !_isListening) return;

    _audioBuffer.addAll(samples);

    // VAD に音声を渡す
    _vad?.acceptWaveform(samples);

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

    // 無音自動停止の監視 (手動トグル停止に統一するため廃止)
    // if (_currentMode == RecognitionMode.immediate && !_stopping) {
    //   _checkSilenceAndAutoStop(samples);
    // }
  }

  /// 音声のRMS（音量）を計算し、無音による自動停止を判定する
  void _checkSilenceAndAutoStop(Float32List samples) {
    if (samples.isEmpty) return;

    double sum = 0.0;
    for (int i = 0; i < samples.length; i++) {
      sum += samples[i] * samples[i];
    }
    final double volume = math.sqrt(sum / samples.length);

    if (!_hasSpeechStarted) {
      if (volume >= _speechVolumeThreshold) {
        _hasSpeechStarted = true;
        _silenceSamplesCount = 0;
        // ignore: avoid_print
        print('【音声認識】発話を検知しました (RMS: ${volume.toStringAsFixed(4)})');
      }
    } else {
      if (volume < _silenceVolumeThreshold) {
        _silenceSamplesCount += samples.length;
        if (_silenceSamplesCount >= _silenceDurationSamples) {
          // ignore: avoid_print
          print('【音声認識】自動停止トリガー: 無音検知 (${(_silenceSamplesCount / _sampleRate * 1000).toInt()}ms 継続)');
          
          // 非同期で音声認識停止を実行
          Future.microtask(() => stopListening());
        }
      } else {
        _silenceSamplesCount = 0; // 発話が継続しているので無音カウントリセット
      }
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
    print('【音声認識】認識停止. 最後のバッファ回収のため100ms待機...');

    // マイクバッファにたまっている音声が処理されるよう少し待つ
    await Future.delayed(const Duration(milliseconds: 100));

    _isListening = false;

    if (!_isWarmedUp) {
      // ウォーム状態でない場合はマイクも停止
      _audioSubscription?.cancel();
      _audioSubscription = null;
      await _audioRecorder.stop();
    } else {
      // ウォーム状態の場合はマイクストリームは維持したまま
      // リングバッファを新しい待機状態用にリセット
      _ringBuffer.clear();
    }

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
    _stopping = false;
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
    _isWarmedUp = false;
    _audioSubscription?.cancel();
    _audioRecorder.dispose();
    _vad?.free();
    _recognizer?.free();
    _vad = null;
    _recognizer = null;
  }
}
