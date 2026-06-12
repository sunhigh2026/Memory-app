// Web環境用のスタブ実装
// sherpa_onnxはFFIを使うためWebでは動作しない
import '../domain/recognition_mode.dart';
import 'speech_recognition_service.dart';
import 'model_download_service.dart';

/// Web環境用のダミー実装（sherpa-onnxはWeb非対応）
class SherpaSpeechRecognition implements SpeechRecognitionService {
  SherpaSpeechRecognition(ModelDownloadService downloadService);

  @override
  String get accumulatedText => '';

  @override
  bool get isListening => false;

  @override
  Future<bool> initialize() async => false;

  @override
  Future<void> startListening({
    required Function(String) onResult,
    required Function(String) onPartialResult,
    required Function(String) onError,
    RecognitionMode mode = RecognitionMode.immediate,
    Duration listenFor = const Duration(seconds: 60),
  }) async {
    onError('sherpa-onnxはWeb環境では使用できません');
  }

  @override
  Future<void> stopListening() async {}

  @override
  void dispose() {}
}
