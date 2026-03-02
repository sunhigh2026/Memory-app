import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/theme/app_theme.dart';
import '../data/ocr_service.dart';
import '../data/image_source_service.dart';
import '../data/pdf_text_extractor.dart';

/// OCR 取り込みモーダルボトムシート
/// カメラ / ギャラリー / PDF の3択を表示し、OCR結果テキストを返す
class OcrImportSheet extends ConsumerStatefulWidget {
  const OcrImportSheet({super.key});

  @override
  ConsumerState<OcrImportSheet> createState() => _OcrImportSheetState();
}

class _OcrImportSheetState extends ConsumerState<OcrImportSheet> {
  bool _processing = false;
  String _statusText = '';
  double? _progress;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: _processing ? _buildProcessing() : _buildOptions(),
      ),
    );
  }

  Widget _buildOptions() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'テキスト取り込み',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        _OptionTile(
          icon: Icons.camera_alt,
          label: 'カメラで撮影',
          subtitle: '書籍やプリントを撮影してテキスト化',
          onTap: () => _processImage(ImageSourceType.camera),
        ),
        const SizedBox(height: 8),
        _OptionTile(
          icon: Icons.photo_library,
          label: 'ギャラリーから選択',
          subtitle: '保存済みの画像からテキスト化',
          onTap: () => _processImage(ImageSourceType.gallery),
        ),
        const SizedBox(height: 8),
        _OptionTile(
          icon: Icons.picture_as_pdf,
          label: 'PDFファイル',
          subtitle: 'PDFからテキストを抽出',
          onTap: _processPdf,
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildProcessing() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 20),
        if (_progress != null)
          LinearProgressIndicator(value: _progress)
        else
          const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(
          _statusText,
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Future<void> _processImage(ImageSourceType source) async {
    // カメラ使用時は権限チェック
    if (source == ImageSourceType.camera) {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('カメラの権限が必要です')),
          );
        }
        return;
      }
    }

    final imageService = ref.read(imageSourceServiceProvider);
    final path = await imageService.pickImage(source);
    if (path == null) return;

    // クロップ画面を表示（範囲選択）
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'OCR範囲を選択',
          toolbarColor: AppTheme.primary,
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: AppTheme.primary,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
          hideBottomControls: false,
        ),
      ],
    );
    if (croppedFile == null) return; // キャンセル

    if (!mounted) return;

    setState(() {
      _processing = true;
      _statusText = 'テキストを認識中...';
    });

    try {
      final ocrService = ref.read(ocrServiceProvider);
      final text = await ocrService.recognizeFromFile(croppedFile.path);

      if (!mounted) return;

      if (text.isEmpty) {
        setState(() => _processing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('テキストが検出できませんでした')),
        );
        return;
      }

      Navigator.of(context).pop(text);
    } catch (e) {
      if (mounted) {
        setState(() => _processing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OCRエラー: $e')),
        );
      }
    }
  }

  Future<void> _processPdf() async {
    final imageService = ref.read(imageSourceServiceProvider);
    final path = await imageService.pickPdf();
    if (path == null) return;

    setState(() {
      _processing = true;
      _statusText = 'PDFを処理中...';
    });

    try {
      final extractor = ref.read(pdfTextExtractorProvider);
      final text = await extractor.extractText(
        path,
        onProgress: (current, total) {
          if (mounted) {
            setState(() {
              _statusText = 'ページ $current / $total を処理中...';
              _progress = current / total;
            });
          }
        },
      );

      if (!mounted) return;

      if (text.isEmpty) {
        setState(() => _processing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('テキストが検出できませんでした')),
        );
        return;
      }

      Navigator.of(context).pop(text);
    } catch (e) {
      if (mounted) {
        setState(() => _processing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF処理エラー: $e')),
        );
      }
    }
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppTheme.primary, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}
