import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// モデルダウンロードの状態
enum ModelDownloadStatus { notDownloaded, downloading, downloaded, error }

class ModelDownloadInfo {
  final ModelDownloadStatus status;
  final double progress;
  final String? errorMessage;

  const ModelDownloadInfo({
    this.status = ModelDownloadStatus.notDownloaded,
    this.progress = 0.0,
    this.errorMessage,
  });

  ModelDownloadInfo copyWith({
    ModelDownloadStatus? status,
    double? progress,
    String? errorMessage,
  }) {
    return ModelDownloadInfo(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// モデルファイル定義
class _ModelFile {
  final String name;
  final String url;
  final int sizeBytes;

  const _ModelFile({
    required this.name,
    required this.url,
    required this.sizeBytes,
  });
}

/// SenseVoice モデルのダウンロード管理
class ModelDownloadService {
  // SenseVoice 用のモデルファイル群
  static const List<_ModelFile> _modelFiles = [
    _ModelFile(
      name: 'model.onnx',
      url:
          'https://huggingface.co/csukuangfj/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17/resolve/main/model.int8.onnx',
      sizeBytes: 230000000, // ~230MB
    ),
    _ModelFile(
      name: 'tokens.txt',
      url:
          'https://huggingface.co/csukuangfj/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17/resolve/main/tokens.txt',
      sizeBytes: 500000, // ~500KB
    ),
    _ModelFile(
      name: 'silero_vad.onnx',
      url:
          'https://github.com/snakers4/silero-vad/raw/master/src/silero_vad/data/silero_vad.onnx',
      sizeBytes: 2200000, // ~2.2MB
    ),
  ];

  /// モデル保存ディレクトリのパスを取得
  Future<String> getModelDir() async {
    final appDir = await getApplicationSupportDirectory();
    return '${appDir.path}/sherpa_models/sensevoice';
  }

  /// モデルがダウンロード済みか確認
  Future<bool> isModelDownloaded() async {
    final modelDir = await getModelDir();
    for (final file in _modelFiles) {
      if (!await File('$modelDir/${file.name}').exists()) {
        return false;
      }
    }
    return true;
  }

  /// モデルの合計サイズ（バイト）
  int get totalModelSizeBytes {
    int total = 0;
    for (final f in _modelFiles) {
      total += f.sizeBytes;
    }
    return total;
  }

  /// モデルをダウンロード
  Future<void> downloadModel({
    required void Function(double progress) onProgress,
    required void Function() onComplete,
    required void Function(String error) onError,
  }) async {
    try {
      final modelDir = await getModelDir();
      await Directory(modelDir).create(recursive: true);

      int totalDownloaded = 0;
      final totalSize = totalModelSizeBytes;

      for (final file in _modelFiles) {
        final outputPath = '$modelDir/${file.name}';
        final partPath = '$outputPath.part';

        final request = http.Request('GET', Uri.parse(file.url));
        final response = await http.Client().send(request);

        if (response.statusCode != 200) {
          throw HttpException(
            'ダウンロード失敗: HTTP ${response.statusCode}',
            uri: Uri.parse(file.url),
          );
        }

        final sink = File(partPath).openWrite();

        await for (final chunk in response.stream) {
          sink.add(chunk);
          totalDownloaded += chunk.length;
          onProgress(totalDownloaded / totalSize);
        }

        await sink.close();

        // ダウンロード完了 → リネーム
        await File(partPath).rename(outputPath);
      }

      onComplete();
    } catch (e) {
      // エラー時は部分ファイルを削除
      await _cleanupPartialFiles();
      onError(e.toString());
    }
  }

  /// モデルを削除
  Future<void> deleteModel() async {
    final modelDir = await getModelDir();
    final dir = Directory(modelDir);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  /// 部分ダウンロードファイルをクリーンアップ
  Future<void> _cleanupPartialFiles() async {
    try {
      final modelDir = await getModelDir();
      final dir = Directory(modelDir);
      if (await dir.exists()) {
        await for (final entity in dir.list()) {
          if (entity is File && entity.path.endsWith('.part')) {
            await entity.delete();
          }
        }
      }
    } catch (_) {
      // クリーンアップ失敗は無視
    }
  }
}

final modelDownloadServiceProvider = Provider<ModelDownloadService>((ref) {
  return ModelDownloadService();
});

/// モデルダウンロード状態の管理
class ModelDownloadStateNotifier extends StateNotifier<ModelDownloadInfo> {
  final ModelDownloadService _service;

  ModelDownloadStateNotifier(this._service)
      : super(const ModelDownloadInfo());

  Future<void> checkStatus() async {
    final downloaded = await _service.isModelDownloaded();
    state = ModelDownloadInfo(
      status: downloaded
          ? ModelDownloadStatus.downloaded
          : ModelDownloadStatus.notDownloaded,
    );
  }

  Future<void> startDownload() async {
    state = const ModelDownloadInfo(
      status: ModelDownloadStatus.downloading,
      progress: 0.0,
    );

    await _service.downloadModel(
      onProgress: (progress) {
        state = ModelDownloadInfo(
          status: ModelDownloadStatus.downloading,
          progress: progress,
        );
      },
      onComplete: () {
        state = const ModelDownloadInfo(
          status: ModelDownloadStatus.downloaded,
          progress: 1.0,
        );
      },
      onError: (error) {
        state = ModelDownloadInfo(
          status: ModelDownloadStatus.error,
          errorMessage: error,
        );
      },
    );
  }

  Future<void> deleteModel() async {
    await _service.deleteModel();
    state = const ModelDownloadInfo(
      status: ModelDownloadStatus.notDownloaded,
    );
  }
}

final modelDownloadStateProvider =
    StateNotifierProvider<ModelDownloadStateNotifier, ModelDownloadInfo>((ref) {
  final service = ref.watch(modelDownloadServiceProvider);
  final notifier = ModelDownloadStateNotifier(service);
  // 初回ステータス確認
  notifier.checkStatus();
  return notifier;
});
