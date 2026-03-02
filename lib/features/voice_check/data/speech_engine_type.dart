/// 音声認識エンジンの種類
enum SpeechEngineType {
  /// Android 標準（speech_to_text）
  native,

  /// sherpa-onnx + SenseVoice（オフライン）
  sherpaOnnx,
}
