import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/data/app_settings_repository.dart';
import '../../scripts/data/scripts_repository.dart';
import '../../tts/data/tts_dictionary_repository.dart';
import '../../voice_check/data/speech_engine_type.dart';
import '../../voice_check/data/model_download_service.dart';
import '../../../core/data/backup_service.dart';

// 設定用プロバイダ
final clozeDensityProvider = StateProvider<int>((ref) => 15);
final defaultSpeechRateProvider = StateProvider<double>((ref) => 0.9);

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Widget _buildEngineSelector(BuildContext context, WidgetRef ref) {
    final currentEngine = ref.watch(speechEngineTypeProvider);
    return SegmentedButton<SpeechEngineType>(
      segments: const [
        ButtonSegment(
          value: SpeechEngineType.native,
          label: Text('Android標準'),
          icon: Icon(Icons.phone_android, size: 16),
        ),
        ButtonSegment(
          value: SpeechEngineType.sherpaOnnx,
          label: Text('SenseVoice'),
          icon: Icon(Icons.offline_bolt, size: 16),
        ),
      ],
      selected: {currentEngine},
      onSelectionChanged: (newSelection) async {
        final selected = newSelection.first;
        if (selected == SpeechEngineType.sherpaOnnx) {
          // モデルが未DLならDL画面に誘導
          final downloadService = ref.read(modelDownloadServiceProvider);
          final isDownloaded = await downloadService.isModelDownloaded();
          if (!isDownloaded && context.mounted) {
            context.push('/model-download');
            return;
          }
        }
        ref.read(speechEngineTypeProvider.notifier).setEngine(selected);
      },
      style: const ButtonStyle(
        textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 13)),
      ),
    );
  }

  Widget _buildModelManagementTile(BuildContext context, WidgetRef ref) {
    final downloadInfo = ref.watch(modelDownloadStateProvider);
    final isDownloaded =
        downloadInfo.status == ModelDownloadStatus.downloaded;

    return Container(
      decoration: AppTheme.outlineDecoration,
      child: ListTile(
        leading: Icon(
          isDownloaded ? Icons.check_circle : Icons.cloud_download,
          color: isDownloaded ? AppTheme.secondary : AppTheme.primary,
        ),
        title: const Text('モデル管理', style: TextStyle(fontSize: 16)),
        subtitle: Text(
          isDownloaded ? 'ダウンロード済み' : '未ダウンロード',
          style: TextStyle(fontSize: 12, color: AppTheme.grey500),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/model-download'),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clozeDensity = ref.watch(clozeDensityProvider);
    final speechRate = ref.watch(defaultSpeechRateProvider);
    final dictionaryEntries = ref.watch(ttsDictionaryListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 穴埋め設定
          const SectionHeader(title: '穴埋め練習'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.outlineDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('穴埋め密度', style: TextStyle(fontSize: 16)),
                    Text(
                      '$clozeDensity%',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: clozeDensity.toDouble(),
                  min: 5,
                  max: 30,
                  divisions: 5,
                  label: '$clozeDensity%',
                  onChanged: (value) {
                    ref.read(clozeDensityProvider.notifier).state =
                        value.round();
                  },
                ),
                Text(
                  '穴埋めにする単語の割合を設定します',
                  style: TextStyle(fontSize: 12, color: AppTheme.grey500),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 読み上げ設定
          const SectionHeader(title: '音声読み上げ'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.outlineDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('デフォルト速度', style: TextStyle(fontSize: 16)),
                    Text(
                      '${speechRate}x',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: speechRate,
                  min: 0.5,
                  max: 1.25,
                  divisions: 3,
                  label: '${speechRate}x',
                  onChanged: (value) {
                    final rates = [0.5, 0.75, 1.0, 1.25];
                    final closest = rates.reduce((prev, curr) =>
                        (curr - value).abs() < (prev - value).abs()
                            ? curr
                            : prev);
                    ref.read(defaultSpeechRateProvider.notifier).state =
                        closest;
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 読み上げ辞書
          Container(
            decoration: AppTheme.outlineDecoration,
            child: ListTile(
              leading: const Icon(Icons.menu_book, color: AppTheme.primary),
              title: const Text('読み上げ辞書', style: TextStyle(fontSize: 16)),
              subtitle: Text(
                '${dictionaryEntries.length}件の登録',
                style: TextStyle(fontSize: 12, color: AppTheme.grey500),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/tts-dictionary'),
            ),
          ),
          const SizedBox(height: 16),
          // 音声認識設定
          const SectionHeader(title: '音声認識'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.outlineDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('認識エンジン', style: TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                _buildEngineSelector(context, ref),
                const SizedBox(height: 8),
                Text(
                  '音声認識の特性上、正しく発音しても異なる漢字で表示される場合があります。'
                  'ひらがなに変換して比較することで、同音異義語の影響を軽減しています。',
                  style: TextStyle(fontSize: 12, color: AppTheme.grey500),
                ),
              ],
            ),
          ),
          // モデル管理（SenseVoice選択時）
          if (ref.watch(speechEngineTypeProvider) ==
              SpeechEngineType.sherpaOnnx) ...[
            const SizedBox(height: 8),
            _buildModelManagementTile(context, ref),
          ],
          const SizedBox(height: 16),
          // 復習ペース
          const SectionHeader(title: '復習'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.outlineDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('デフォルト復習ペース', style: TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                _ReviewPaceSelector(ref: ref),
                const SizedBox(height: 8),
                Text(
                  '新規テキストに適用されます。各テキストの詳細画面で個別に変更できます。\n'
                  '本番日が設定されているテキストは本番日スケジュールが優先されます。',
                  style: TextStyle(fontSize: 12, color: AppTheme.grey500),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                const Text('目標設定モード', style: TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'auto',
                      label: Text('自動 (要復習件数)'),
                      icon: Icon(Icons.auto_awesome, size: 16),
                    ),
                    ButtonSegment(
                      value: 'manual',
                      label: Text('手動 (カスタム)'),
                      icon: Icon(Icons.edit, size: 16),
                    ),
                  ],
                  selected: {ref.watch(goalSettingModeProvider)},
                  onSelectionChanged: (newSelection) {
                    ref.read(goalSettingModeProvider.notifier).setMode(newSelection.first);
                  },
                  style: const ButtonStyle(
                    textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 13)),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  ref.watch(goalSettingModeProvider) == 'auto'
                      ? '本日の「要復習」カード件数を自動的に今日の目標練習回数に設定します。'
                      : '自分で設定した目標練習回数を今日の目標に設定します。',
                  style: TextStyle(fontSize: 12, color: AppTheme.grey500),
                ),
                if (ref.watch(goalSettingModeProvider) == 'manual') ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('1日の目標練習回数', style: TextStyle(fontSize: 16)),
                      Text(
                        '${ref.watch(dailyGoalProvider)}回',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: ref.watch(dailyGoalProvider).toDouble(),
                    min: 5,
                    max: 50,
                    divisions: 9,
                    label: '${ref.watch(dailyGoalProvider)}回',
                    onChanged: (value) {
                      ref.read(dailyGoalProvider.notifier).setGoal(value.round());
                    },
                  ),
                  Text(
                    '1日に達成したい目標練習回数（カードを1回練習＝1セッション）を設定します。',
                    style: TextStyle(fontSize: 12, color: AppTheme.grey500),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          // データ管理
          const SectionHeader(title: 'データ管理'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.outlineDecoration,
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.backup, color: AppTheme.primary),
                  title: const Text('バックアップの作成', style: TextStyle(fontSize: 16)),
                  subtitle: Text(
                    '現在のデータ（カード、練習履歴、辞書など）をファイルに保存します',
                    style: TextStyle(fontSize: 12, color: AppTheme.grey500),
                  ),
                  onTap: () async {
                    final success = await BackupService.exportBackup();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            success ? 'バックアップを保存しました' : 'バックアップの保存をキャンセルまたは失敗しました',
                          ),
                        ),
                      );
                    }
                  },
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.restore, color: AppTheme.primary),
                  title: const Text('バックアップから復元', style: TextStyle(fontSize: 16)),
                  subtitle: Text(
                    '以前保存したバックアップファイルからデータを復元します\n※現在のデータは上書きされます',
                    style: TextStyle(fontSize: 12, color: AppTheme.grey500),
                  ),
                  onTap: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('バックアップ復元の確認'),
                        content: const Text(
                          'データを復元すると、現在登録されているカードや練習履歴はすべて消去され、バックアップデータに上書きされます。\n本当に復元しますか？',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('キャンセル'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('復元する'),
                          ),
                        ],
                      ),
                    );

                    if (confirmed == true && context.mounted) {
                      final success = await BackupService.importBackup();
                      if (context.mounted) {
                        if (success) {
                          ref.read(scriptsListProvider.notifier).refresh();
                          ref.invalidate(ttsDictionaryListProvider);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('データを復元しました')),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('データの復元に失敗しました')),
                          );
                        }
                      }
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // アプリ情報
          const SectionHeader(title: 'アプリ情報'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.outlineDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('暗リピ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('バージョン 1.0.0', style: TextStyle(fontSize: 12, color: AppTheme.grey500)),
                const SizedBox(height: 8),
                Text(
                  '文章暗記をサポートするアプリです。テキストを登録し、音声読み上げで耳から覚え、'
                  '穴埋め練習と音声認識による暗記確認で完全暗記を目指せます。',
                  style: TextStyle(fontSize: 13, color: AppTheme.grey600),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.help_outline, color: AppTheme.primary),
                  title: const Text('使い方ガイド', style: TextStyle(fontSize: 15)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/how-to-use'),
                ),
                const Divider(height: 1),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.grey500,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                minimumSize: const Size(0, 36),
              ),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('すべてをリセットの確認'),
                    content: const Text(
                      '本当にすべての暗記テキストを削除し、初期状態にリセットしますか？\n'
                      'この操作は取り消せません。',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('キャンセル'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.error,
                        ),
                        child: const Text('リセットする'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true && context.mounted) {
                  await ref.read(scriptsListProvider.notifier).deleteAllScripts();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('すべてのテキストを削除し、リセットしました')),
                  );
                }
              },
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('すべてをリセット', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewPaceSelector extends StatelessWidget {
  final WidgetRef ref;

  const _ReviewPaceSelector({required this.ref});

  @override
  Widget build(BuildContext context) {
    final settingsRepo = ref.watch(appSettingsRepositoryProvider);
    final currentPace = settingsRepo.getDefaultReviewPace();

    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'relaxed', label: Text('ゆっくり')),
        ButtonSegment(value: 'normal', label: Text('ふつう')),
        ButtonSegment(value: 'intensive', label: Text('しっかり')),
        ButtonSegment(value: 'daily', label: Text('毎日')),
      ],
      selected: {currentPace},
      onSelectionChanged: (newSelection) async {
        final pace = newSelection.first;
        await settingsRepo.setDefaultReviewPace(pace);
        // 本番日未設定の全スクリプトに反映
        final scripts = ref.read(scriptsListProvider);
        for (final script in scripts) {
          if (!script.isTargetDateMode) {
            script.reviewPace = pace;
            await script.save();
          }
        }
        ref.read(scriptsListProvider.notifier).refresh();
      },
      style: const ButtonStyle(
        textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 11)),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

