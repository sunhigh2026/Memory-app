import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../data/model_download_service.dart';

/// SenseVoice モデル管理画面
class ModelDownloadScreen extends ConsumerWidget {
  const ModelDownloadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadInfo = ref.watch(modelDownloadStateProvider);
    final service = ref.watch(modelDownloadServiceProvider);
    final totalMb = (service.totalModelSizeBytes / 1024 / 1024).round();

    return Scaffold(
      appBar: AppBar(title: const Text('音声認識モデル管理')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // モデル情報
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SenseVoice モデル',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'オフライン音声認識用のAIモデルです。\n'
                    'ダウンロード後はインターネット接続なしで音声認識が使えます。',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.storage, size: 16, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        'サイズ: 約 ${totalMb}MB',
                        style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.language, size: 16, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        '対応言語: 日本語, 英語, 中国語, 韓国語, 広東語',
                        style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // ステータス・アクション
            _buildStatusSection(context, ref, downloadInfo, totalMb),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSection(
    BuildContext context,
    WidgetRef ref,
    ModelDownloadInfo info,
    int totalMb,
  ) {
    switch (info.status) {
      case ModelDownloadStatus.notDownloaded:
        return Column(
          children: [
            Icon(Icons.cloud_download, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'モデルがダウンロードされていません',
              style: TextStyle(fontSize: 15, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  ref.read(modelDownloadStateProvider.notifier).startDownload();
                },
                icon: const Icon(Icons.download),
                label: Text('ダウンロード (約 ${totalMb}MB)'),
              ),
            ),
          ],
        );

      case ModelDownloadStatus.downloading:
        final percent = (info.progress * 100).toStringAsFixed(0);
        final downloadedMb = (info.progress * totalMb).round();
        return Column(
          children: [
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: info.progress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 12),
            Text(
              'ダウンロード中... $percent% ($downloadedMb / ${totalMb}MB)',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Wi-Fi環境でのダウンロードを推奨します',
              style: TextStyle(fontSize: 12, color: Colors.grey[400]),
            ),
          ],
        );

      case ModelDownloadStatus.downloaded:
        return Column(
          children: [
            const Icon(Icons.check_circle, size: 64, color: AppTheme.secondary),
            const SizedBox(height: 16),
            const Text(
              'ダウンロード済み',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.secondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'オフライン音声認識が利用可能です',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => _confirmDelete(context, ref),
              icon: const Icon(Icons.delete_outline, color: AppTheme.error),
              label: const Text('モデルを削除',
                  style: TextStyle(color: AppTheme.error)),
            ),
          ],
        );

      case ModelDownloadStatus.error:
        return Column(
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppTheme.error),
            const SizedBox(height: 16),
            const Text(
              'ダウンロードに失敗しました',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.error,
              ),
            ),
            if (info.errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                info.errorMessage!,
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  ref.read(modelDownloadStateProvider.notifier).startDownload();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('再試行'),
              ),
            ),
          ],
        );
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('モデル削除'),
        content: const Text(
          'SenseVoiceモデルを削除しますか？\n'
          'オフライン音声認識が使用できなくなります。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              ref.read(modelDownloadStateProvider.notifier).deleteModel();
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }
}
