import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

enum ImageSourceType { camera, gallery }

/// 画像・ファイル取得サービス
class ImageSourceService {
  final ImagePicker _imagePicker = ImagePicker();

  /// カメラ撮影またはギャラリーから画像を取得
  Future<String?> pickImage(ImageSourceType source) async {
    final XFile? image = await _imagePicker.pickImage(
      source: source == ImageSourceType.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 90,
    );
    return image?.path;
  }

  /// PDFファイルを選択
  Future<String?> pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result == null) return null;
    
    final path = result.files.single.path;
    if (path != null && !path.toLowerCase().endsWith('.pdf')) {
      return null;
    }
    return path;
  }
}

final imageSourceServiceProvider = Provider<ImageSourceService>((ref) {
  return ImageSourceService();
});
