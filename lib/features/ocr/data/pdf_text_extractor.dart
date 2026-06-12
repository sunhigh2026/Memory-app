import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfx/pdfx.dart';
import 'package:path_provider/path_provider.dart';
import 'ocr_service.dart';

/// PDF からテキストを抽出するサービス
/// ページを画像にレンダリングして OCR で認識する
class PdfTextExtractor {
  final OcrService _ocrService;

  PdfTextExtractor(this._ocrService);

  /// PDFファイルのページ数を取得
  Future<int> getPageCount(String filePath) async {
    final document = await PdfDocument.openFile(filePath);
    final count = document.pagesCount;
    await document.close();
    return count;
  }

  /// PDFファイルからテキストを抽出
  Future<String> extractText(
    String filePath, {
    int? startPage,
    int? endPage,
    void Function(int current, int total)? onProgress,
  }) async {
    final document = await PdfDocument.openFile(filePath);
    final buffer = StringBuffer();
    final tempDir = await getTemporaryDirectory();

    try {
      final start = startPage ?? 1;
      final end = endPage ?? document.pagesCount;
      final totalToProcess = end - start + 1;
      int processedCount = 0;

      for (int i = start; i <= end; i++) {
        processedCount++;
        onProgress?.call(processedCount, totalToProcess);

        final page = await document.getPage(i);
        // ページを画像としてレンダリング（2倍解像度でOCR精度向上）
        final pageImage = await page.render(
          width: page.width * 2,
          height: page.height * 2,
          format: PdfPageImageFormat.png,
        );
        await page.close();

        if (pageImage == null) continue;

        // pdfx の render() は raw RGBA バイトを返す場合がある
        // PNG に変換して一時ファイルに保存
        final tempFile = File('${tempDir.path}/pdf_page_$i.png');
        try {
          final pngBytes = await _toPng(
            pageImage.bytes,
            pageImage.width ?? (page.width * 2).toInt(),
            pageImage.height ?? (page.height * 2).toInt(),
          );
          if (pngBytes != null) {
            await tempFile.writeAsBytes(pngBytes);

            // OCR 実行
            final text = await _ocrService.recognizeFromFile(tempFile.path);
            if (text.isNotEmpty) {
              buffer.writeln(text);
              buffer.writeln();
            }
          }
        } finally {
          // 一時ファイル削除
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        }
      }
    } finally {
      await document.close();
    }

    return buffer.toString().trim();
  }

  /// raw RGBA バイトを PNG に変換
  Future<List<int>?> _toPng(
    List<int> rawBytes,
    int width,
    int height,
  ) async {
    try {
      final bytes =
          rawBytes is Uint8List ? rawBytes : Uint8List.fromList(rawBytes);
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: width,
        targetHeight: height,
      );
      final frame = await codec.getNextFrame();
      final byteData =
          await frame.image.toByteData(format: ui.ImageByteFormat.png);
      frame.image.dispose();
      return byteData?.buffer.asUint8List();
    } catch (_) {
      // rawBytes が既に PNG の場合はそのまま返す
      return rawBytes;
    }
  }
}

final pdfTextExtractorProvider = Provider<PdfTextExtractor>((ref) {
  final ocrService = ref.watch(ocrServiceProvider);
  return PdfTextExtractor(ocrService);
});
