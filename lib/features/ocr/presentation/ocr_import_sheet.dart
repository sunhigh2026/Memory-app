import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
        IOSUiSettings(
          title: 'OCR範囲を選択',
          doneButtonTitle: '確定',
          cancelButtonTitle: 'キャンセル',
          aspectRatioLockEnabled: false,
          resetAspectRatioEnabled: true,
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

    if (!mounted) return;

    final extractor = ref.read(pdfTextExtractorProvider);
    int pagesCount = 1;
    try {
      pagesCount = await extractor.getPageCount(path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDFの読み込みに失敗しました: $e')),
        );
      }
      return;
    }

    if (!mounted) return;

    int? startPage = 1;
    int? endPage = pagesCount;

    if (pagesCount > 1) {
      final result = await showDialog<Map<String, int>>(
        context: context,
        builder: (context) => _PdfPageSelectionDialog(pagesCount: pagesCount),
      );
      if (result == null) return; // キャンセル
      startPage = result['start'];
      endPage = result['end'];
    }

    setState(() {
      _processing = true;
      _statusText = 'PDFを処理中...';
    });

    try {
      final text = await extractor.extractText(
        path,
        startPage: startPage,
        endPage: endPage,
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

class _PdfPageSelectionDialog extends StatefulWidget {
  final int pagesCount;
  const _PdfPageSelectionDialog({required this.pagesCount});

  @override
  State<_PdfPageSelectionDialog> createState() => _PdfPageSelectionDialogState();
}

class _PdfPageSelectionDialogState extends State<_PdfPageSelectionDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _startController;
  late final TextEditingController _endController;

  @override
  void initState() {
    super.initState();
    _startController = TextEditingController(text: '1');
    _endController = TextEditingController(text: widget.pagesCount.toString());
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('ページ範囲の指定'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('PDFの全ページ数: ${widget.pagesCount}ページ'),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _startController,
                    decoration: const InputDecoration(
                      labelText: '開始ページ',
                      hintText: '1',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if (value == null || value.isEmpty) return '入力してください';
                      final val = int.tryParse(value);
                      if (val == null || val < 1 || val > widget.pagesCount) {
                        return '1〜${widget.pagesCount}の範囲';
                      }
                      return null;
                    },
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  child: Text('〜'),
                ),
                Expanded(
                  child: TextFormField(
                    controller: _endController,
                    decoration: const InputDecoration(
                      labelText: '終了ページ',
                      hintText: '1',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if (value == null || value.isEmpty) return '入力してください';
                      final val = int.tryParse(value);
                      if (val == null || val < 1 || val > widget.pagesCount) {
                        return '1〜${widget.pagesCount}の範囲';
                      }
                      final startVal = int.tryParse(_startController.text);
                      if (startVal != null && val < startVal) {
                        return '開始ページ以降';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              final start = int.parse(_startController.text);
              final end = int.parse(_endController.text);
              Navigator.of(context).pop({'start': start, 'end': end});
            }
          },
          child: const Text('確定'),
        ),
      ],
    );
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
