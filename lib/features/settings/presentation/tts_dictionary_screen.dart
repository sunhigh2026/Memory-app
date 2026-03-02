import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/tts_dictionary_entry.dart';
import '../../tts/data/tts_dictionary_repository.dart';

class TtsDictionaryScreen extends ConsumerWidget {
  const TtsDictionaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(ttsDictionaryListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('読み上げ辞書'),
      ),
      body: entries.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.menu_book, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    '辞書エントリがありません\n＋ボタンで追加してください',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '例: 「行った」→「おこなった」',
                    style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: entries.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return _DictionaryEntryCard(entry: entry);
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    _showEntryDialog(
      context: context,
      title: '辞書エントリ追加',
      onSave: (original, reading) {
        ref.read(ttsDictionaryListProvider.notifier).add(original, reading);
      },
    );
  }
}

class _DictionaryEntryCard extends ConsumerWidget {
  final TtsDictionaryEntry entry;

  const _DictionaryEntryCard({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.original,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.arrow_forward, size: 14, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Text(
                      entry.reading,
                      style: TextStyle(
                        fontSize: 15,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, size: 20),
            color: Colors.grey[400],
            onPressed: () => _showEditDialog(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            color: AppTheme.error,
            onPressed: () => _showDeleteConfirm(context, ref),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref) {
    _showEntryDialog(
      context: context,
      title: '辞書エントリ編集',
      initialOriginal: entry.original,
      initialReading: entry.reading,
      onSave: (original, reading) {
        ref
            .read(ttsDictionaryListProvider.notifier)
            .update(entry, original, reading);
      },
    );
  }

  void _showDeleteConfirm(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除確認'),
        content: Text('「${entry.original}」→「${entry.reading}」を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              ref.read(ttsDictionaryListProvider.notifier).delete(entry);
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

void _showEntryDialog({
  required BuildContext context,
  required String title,
  String? initialOriginal,
  String? initialReading,
  required void Function(String original, String reading) onSave,
}) {
  final originalController = TextEditingController(text: initialOriginal ?? '');
  final readingController = TextEditingController(text: initialReading ?? '');

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: originalController,
            decoration: const InputDecoration(
              labelText: '原文',
              hintText: '例: 行った',
            ),
            autofocus: true,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: readingController,
            decoration: const InputDecoration(
              labelText: '読み',
              hintText: '例: おこなった',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        TextButton(
          onPressed: () {
            final original = originalController.text.trim();
            final reading = readingController.text.trim();
            if (original.isNotEmpty && reading.isNotEmpty) {
              onSave(original, reading);
              Navigator.of(context).pop();
            }
          },
          child: const Text('保存'),
        ),
      ],
    ),
  );
}
