import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/data/app_settings_repository.dart';
import '../../scripts/data/scripts_repository.dart';
import '../../subjects/data/subjects_repository.dart';
import '../../tts/data/tts_dictionary_repository.dart';
import '../../voice_check/data/speech_engine_type.dart';
import '../../voice_check/data/model_download_service.dart';
import '../../../core/data/backup_service.dart';
import '../../../models/subject.dart';

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

  Widget _buildStrictnessSelector(BuildContext context, WidgetRef ref) {
    final currentStrictness = ref.watch(matchStrictnessProvider);
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(
          value: 'easy',
          label: Text('やさしい'),
          icon: Icon(Icons.sentiment_satisfied_alt, size: 16),
        ),
        ButtonSegment(
          value: 'normal',
          label: Text('ふつう'),
          icon: Icon(Icons.sentiment_neutral, size: 16),
        ),
        ButtonSegment(
          value: 'strict',
          label: Text('きびしい'),
          icon: Icon(Icons.gavel, size: 16),
        ),
      ],
      selected: {currentStrictness},
      onSelectionChanged: (newSelection) {
        ref.read(matchStrictnessProvider.notifier).setValue(newSelection.first);
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

  Widget _buildVadTuningPanel(BuildContext context, WidgetRef ref) {
    final threshold = ref.watch(vadThresholdProvider);
    final minSilence = ref.watch(vadMinSilenceDurationProvider);
    final speechPad = ref.watch(vadSpeechPadMsProvider);

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.outlineDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '音声検出詳細設定 (VAD)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                onPressed: () {
                  ref
                      .read(vadThresholdProvider.notifier)
                      .setValue(AppSettingsRepository.defaultVadThreshold);
                  ref
                      .read(vadMinSilenceDurationProvider.notifier)
                      .setValue(AppSettingsRepository.defaultVadMinSilenceDuration);
                  ref
                      .read(vadSpeechPadMsProvider.notifier)
                      .setValue(AppSettingsRepository.defaultVadSpeechPadMs);
                },
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('初期値', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // しきい値 (Threshold)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('発話判定のしきい値', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              Text(
                threshold.toStringAsFixed(2),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primary),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: threshold,
                  min: 0.1,
                  max: 0.9,
                  divisions: 16,
                  onChanged: (val) {
                    ref.read(vadThresholdProvider.notifier).setValue(double.parse(val.toStringAsFixed(2)));
                  },
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '低いと小さな声も拾いますが雑音に弱くなります。高いと雑音を無視しますが話し始めが消えやすくなります（初期値: 0.40）。',
              style: TextStyle(fontSize: 11, color: AppTheme.grey500),
            ),
          ),
          const SizedBox(height: 16),

          // 無音判定秒数 (minSilenceDuration)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('無音判定の秒数', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              Text(
                '${minSilence.toStringAsFixed(1)}秒',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primary),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: minSilence,
                  min: 0.3,
                  max: 2.0,
                  divisions: 17,
                  onChanged: (val) {
                    ref.read(vadMinSilenceDurationProvider.notifier).setValue(double.parse(val.toStringAsFixed(1)));
                  },
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '言葉を思い出しながら話す際の間隔を許容する長さです。長くすると、発話終了の判定まで余裕を持って待機します（初期値: 0.8秒）。',
              style: TextStyle(fontSize: 11, color: AppTheme.grey500),
            ),
          ),
          const SizedBox(height: 16),

          // パディング (speechPadMs)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('前後のパディング時間', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              Text(
                '${speechPad}ms',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primary),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: speechPad.toDouble(),
                  min: 0,
                  max: 500,
                  divisions: 10,
                  onChanged: (val) {
                    ref.read(vadSpeechPadMsProvider.notifier).setValue(val.round());
                  },
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '検出した発声区間の前後の実音声を結合して認識に回します。発話開始時や終了時の言葉の欠けを防ぎます（初期値: 150ms）。',
              style: TextStyle(fontSize: 11, color: AppTheme.grey500),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddSubjectDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新しい科目を作成'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '科目名',
              hintText: '例: 行政書士 憲法, 英単語 など',
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return '科目名を入力してください';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(context).pop(true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('作成'),
          ),
        ],
      ),
    );

    if (created == true && context.mounted) {
      final name = controller.text.trim();
      if (name.isNotEmpty) {
        await ref.read(subjectsListProvider.notifier).addSubject(name);
        // フィルタのリセット
        ref.read(selectedTagsProvider.notifier).state = {};
        ref.read(levelFilterProvider.notifier).state = {};
        ref.read(rankFilterProvider.notifier).state = {};
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('「$name」を作成し、選択しました')),
          );
        }
      }
    }
  }

  Future<void> _showEditSubjectDialog(
      BuildContext context, WidgetRef ref, Subject subject) async {
    final controller = TextEditingController(text: subject.name);
    final formKey = GlobalKey<FormState>();

    final updated = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('科目名を変更'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '科目名',
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return '科目名を入力してください';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(context).pop(true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (updated == true && context.mounted) {
      final newName = controller.text.trim();
      if (newName.isNotEmpty && newName != subject.name) {
        await ref
            .read(subjectsListProvider.notifier)
            .updateSubjectName(subject.id, newName);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('科目名を「$newName」に変更しました')),
          );
        }
      }
    }
  }

  Future<void> _showDeleteSubjectDialog(
      BuildContext context, WidgetRef ref, Subject subject) async {
    final scriptsRepo = ref.read(scriptsRepositoryProvider);
    final cardCount = scriptsRepo.getTotalCount(subjectId: subject.id);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('「${subject.name}」を削除'),
        content: Text(
          cardCount > 0
              ? '「${subject.name}」を削除すると、この科目に登録されている $cardCount 件の暗記カードもすべて削除されます。\n本当に削除しますか？\n※この操作は取り消せません。'
              : '「${subject.name}」を削除しますか？',
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
            child: const Text('削除する'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      // 科目に属するカードを削除
      await scriptsRepo.deleteBySubjectId(subject.id);
      // 科目自体を削除
      final deleted =
          await ref.read(subjectsListProvider.notifier).deleteSubject(subject.id);
      if (deleted && context.mounted) {
        // フィルタのリセット
        ref.read(selectedTagsProvider.notifier).state = {};
        ref.read(levelFilterProvider.notifier).state = {};
        ref.read(rankFilterProvider.notifier).state = {};
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('「${subject.name}」を削除しました')),
        );
      }
    }
  }

  Widget _buildSubjectSection(BuildContext context, WidgetRef ref) {
    final subjects = ref.watch(subjectsListProvider);
    final currentSubject = ref.watch(currentSubjectProvider);
    final currentSubjectId = ref.watch(currentSubjectIdProvider);
    final scriptsRepo = ref.watch(scriptsRepositoryProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.outlineDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: const Icon(Icons.school, color: AppTheme.primary, size: 20),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '科目一覧 (${currentSubject.name})',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              FilledButton.tonalIcon(
                onPressed: () => _showAddSubjectDialog(context, ref),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('科目を追加', style: TextStyle(fontSize: 12)),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 科目一覧カードリスト
          ...subjects.map((subject) {
            final isSelected = subject.id == currentSubjectId;
            final count = scriptsRepo.getTotalCount(subjectId: subject.id);
            final mastered = scriptsRepo.getMasteredCount(subjectId: subject.id);

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primary.withValues(alpha: 0.06) : Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(
                  color: isSelected ? AppTheme.primary : AppTheme.grey300,
                  width: isSelected ? 1.5 : 1.0,
                ),
              ),
              child: ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                leading: Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: isSelected ? AppTheme.primary : AppTheme.grey400,
                  size: 22,
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        subject.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? AppTheme.primary : AppTheme.textDark,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isSelected)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          '選択中',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                subtitle: Text(
                  'カード: $count件 (習得済: $mastered件)',
                  style: TextStyle(fontSize: 11, color: AppTheme.grey600),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 18),
                      tooltip: '名前を変更',
                      color: AppTheme.grey500,
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _showEditSubjectDialog(context, ref, subject),
                    ),
                    if (subjects.length > 1)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        tooltip: '科目を削除',
                        color: AppTheme.error,
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _showDeleteSubjectDialog(context, ref, subject),
                      ),
                  ],
                ),
                onTap: () {
                  if (!isSelected) {
                    ref.read(currentSubjectIdProvider.notifier).selectSubject(subject.id);
                    // フィルタのリセット
                    ref.read(selectedTagsProvider.notifier).state = {};
                    ref.read(levelFilterProvider.notifier).state = {};
                    ref.read(rankFilterProvider.notifier).state = {};
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('科目を「${subject.name}」に切り替えました'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  }
                },
              ),
            );
          }),
          const SizedBox(height: 4),
          Text(
            '科目を切り替えると、ホーム画面のカード一覧や復習タスク、統計情報がその科目のデータに切り替わります。',
            style: TextStyle(fontSize: 12, color: AppTheme.grey500),
          ),
        ],
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
          // 学習科目セクション
          const SectionHeader(title: '学習科目'),
          _buildSubjectSection(context, ref),
          const SizedBox(height: 16),
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
                const Divider(height: 32),
                const Text('照合の厳しさ', style: TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                _buildStrictnessSelector(context, ref),
                const SizedBox(height: 8),
                Text(
                  '「きびしい」は一字一句正確な暗記向け、「やさしい」は多少の言い淀みや誤認識を許容します。',
                  style: TextStyle(fontSize: 12, color: AppTheme.grey500),
                ),
              ],
            ),
          ),
          // モデル管理とVAD詳細設定（SenseVoice選択時）
          if (ref.watch(speechEngineTypeProvider) ==
              SpeechEngineType.sherpaOnnx) ...[
            const SizedBox(height: 8),
            _buildModelManagementTile(context, ref),
            _buildVadTuningPanel(context, ref),
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

