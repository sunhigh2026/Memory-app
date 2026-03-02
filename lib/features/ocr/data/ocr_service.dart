import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// OCR エンジンの抽象インターフェース
abstract class OcrService {
  /// 画像ファイルからテキストを認識
  Future<String> recognizeFromFile(String imagePath);
  void dispose();
}

/// Google ML Kit 実装（日本語対応）
class MlKitOcrService implements OcrService {
  TextRecognizer? _recognizer;

  TextRecognizer get _textRecognizer {
    _recognizer ??= TextRecognizer(script: TextRecognitionScript.japanese);
    return _recognizer!;
  }

  @override
  Future<String> recognizeFromFile(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final recognized = await _textRecognizer.processImage(inputImage);

    // ブロック → 行 → テキストを連結
    final buffer = StringBuffer();
    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        buffer.writeln(line.text);
      }
      buffer.writeln(); // ブロック間に空行
    }

    return buffer.toString().trim();
  }

  @override
  void dispose() {
    _recognizer?.close();
    _recognizer = null;
  }
}

final ocrServiceProvider = Provider<OcrService>((ref) {
  final service = MlKitOcrService();
  ref.onDispose(() => service.dispose());
  return service;
});
