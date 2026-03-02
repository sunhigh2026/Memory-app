import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../data/scripts_repository.dart';
import '../../tts/presentation/tts_player_widget.dart';
import '../../../models/script.dart';

class ScriptDetailScreen extends ConsumerWidget {
  final String scriptId;

  const ScriptDetailScreen({super.key, required this.scriptId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scripts = ref.watch(scriptsListProvider);
    final script = scripts.cast<Script?>().firstWhere(
          (s) => s?.id == scriptId,
          orElse: () => null,
        );

    if (script == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('エラー')),
        body: const Center(child: Text('テキストが見つかりません')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(script.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => context.push('/edit/${script.id}'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // メタ情報
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _InfoChip(
                  icon: Icons.bar_chart,
                  label: 'Level ${script.currentLevel}',
                ),
                _InfoChip(
                  icon: Icons.repeat,
                  label: '${script.practiceCount}回練習',
                ),
                ...script.tags.map((tag) => _InfoChip(
                      icon: Icons.label_outline,
                      label: tag,
                    )),
              ],
            ),
            const SizedBox(height: 16),
            // 原文表示
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: SelectableText(
                script.content,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.8,
                  color: AppTheme.textDark,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // TTS プレイヤー
            TtsPlayerWidget(text: script.content),
            const SizedBox(height: 24),
            // アクションボタン
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final level = script.currentLevel.clamp(1, 3);
                      context.push('/practice/${script.id}/$level');
                    },
                    icon: const Icon(Icons.edit_note),
                    label: const Text('穴埋め練習'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => context.push('/voice-check/${script.id}'),
                    icon: const Icon(Icons.mic),
                    label: const Text('音声で確認'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.secondary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // ベストスコア表示
            if (script.bestVoiceScore > 0)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.scoreColor(script.bestVoiceScore)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.scoreColor(script.bestVoiceScore)
                        .withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.emoji_events,
                      color: AppTheme.scoreColor(script.bestVoiceScore),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'ベストスコア: ${script.bestVoiceScore.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.scoreColor(script.bestVoiceScore),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
