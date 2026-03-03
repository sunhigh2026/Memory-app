import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../ocr/presentation/ocr_import_sheet.dart';
import '../data/scripts_repository.dart';

class ScriptAddScreen extends ConsumerStatefulWidget {
  final String? scriptId;

  const ScriptAddScreen({super.key, this.scriptId});

  @override
  ConsumerState<ScriptAddScreen> createState() => _ScriptAddScreenState();
}

class _ScriptAddScreenState extends ConsumerState<ScriptAddScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _tagController = TextEditingController();
  final _contentFocusNode = FocusNode();
  List<String> _tags = [];
  String _parenthesesMode = 'stripContent';
  bool _isEditing = false;

  static const int maxContentLength = 5000;

  static const Map<String, String> parenthesesOptions = {
    'stripContent': '括弧と内容を除外',
    'stripSymbols': '括弧記号のみ除去',
    'keep': 'そのまま保持',
  };

  @override
  void initState() {
    super.initState();
    if (widget.scriptId != null) {
      _isEditing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadScript();
      });
    }
  }

  void _loadScript() {
    final scripts = ref.read(scriptsListProvider);
    final script = scripts.firstWhere(
      (s) => s.id == widget.scriptId,
      orElse: () => throw Exception('Script not found'),
    );
    _titleController.text = script.title;
    _contentController.text = script.content;
    setState(() {
      _tags = List<String>.from(script.tags);
      _parenthesesMode = script.parenthesesMode;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagController.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'テキスト編集' : 'テキスト追加'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              color: AppTheme.error,
              onPressed: _confirmDelete,
            ),
          TextButton(
            onPressed: _save,
            child: Text(
              _isEditing ? '更新' : '保存',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // タイトル
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'タイトル',
                hintText: '例: 民法第1条',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'タイトルを入力してください';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // タグ
            Text('タグ', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _tags.map((tag) {
                return Chip(
                  label: Text(tag, style: const TextStyle(fontSize: 13)),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () {
                    setState(() => _tags.remove(tag));
                  },
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                  side: BorderSide.none,
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tagController,
                    decoration: const InputDecoration(
                      hintText: 'タグを入力',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    onSubmitted: (_) => _addTag(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _addTag,
                  icon: const Icon(Icons.add_circle_outline),
                  color: AppTheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 括弧の扱い
            Text(
              '括弧の扱い（音声確認時）',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _parenthesesMode,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              items: parenthesesOptions.entries.map((e) {
                return DropdownMenuItem(value: e.key, child: Text(e.value));
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _parenthesesMode = value);
                }
              },
            ),
            const SizedBox(height: 16),
            // 本文インポート方法
            Text(
              '本文の入力方法',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _ImportButton(
                  icon: Icons.edit_note,
                  label: '手動入力',
                  onTap: () => _contentFocusNode.requestFocus(),
                ),
                const SizedBox(width: 8),
                _ImportButton(
                  icon: Icons.content_paste,
                  label: 'クリップボード',
                  onTap: _pasteFromClipboard,
                ),
                const SizedBox(width: 8),
                _ImportButton(
                  icon: Icons.file_open,
                  label: 'ファイル',
                  onTap: _importFromFile,
                ),
                const SizedBox(width: 8),
                _ImportButton(
                  icon: Icons.document_scanner,
                  label: 'OCR',
                  onTap: _showOcrImport,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 本文
            TextFormField(
              controller: _contentController,
              focusNode: _contentFocusNode,
              decoration: InputDecoration(
                labelText: '本文',
                hintText: '暗記したいテキストを入力してください',
                alignLabelWithHint: true,
                counterText:
                    '${_contentController.text.length} / $maxContentLength',
              ),
              maxLines: 15,
              maxLength: maxContentLength,
              onChanged: (_) => setState(() {}),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '本文を入力してください';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showOcrImport() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const OcrImportSheet(),
    );
    if (result != null && result.isNotEmpty) {
      _appendContent(result);
    }
  }

  void _appendContent(String text) {
    final current = _contentController.text;
    _contentController.text =
        current.isEmpty ? text : '$current\n$text';
    setState(() {});
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    if (data == null || data.text == null || data.text!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('クリップボードにテキストがありません')),
      );
      return;
    }
    _appendContent(data.text!.trim());
  }

  Future<void> _importFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt'],
      );
      if (result == null || result.files.single.path == null) return;
      final file = File(result.files.single.path!);
      final text = await file.readAsString();
      if (!mounted) return;
      if (text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ファイルが空です')),
        );
        return;
      }
      _appendContent(text.trim());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ファイル読み込みエラー: $e')),
      );
    }
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isEmpty || _tags.contains(tag)) return;
    setState(() {
      _tags.add(tag);
      _tagController.clear();
    });
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除確認'),
        content: Text('「${_titleController.text}」を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final scripts = ref.read(scriptsListProvider);
      final script = scripts.firstWhere((s) => s.id == widget.scriptId);
      await ref.read(scriptsListProvider.notifier).deleteScript(script);
      if (mounted) context.go('/');
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    final notifier = ref.read(scriptsListProvider.notifier);

    if (_isEditing) {
      final scripts = ref.read(scriptsListProvider);
      final script = scripts.firstWhere((s) => s.id == widget.scriptId);
      script.title = title;
      script.content = content;
      script.tags = _tags;
      script.category = _tags.isNotEmpty ? _tags.first : '';
      script.parenthesesMode = _parenthesesMode;
      await notifier.updateScript(script);
    } else {
      await notifier.addScript(
        title: title,
        content: content,
        tags: _tags,
        parenthesesMode: _parenthesesMode,
      );
    }

    if (mounted) context.pop();
  }
}

class _ImportButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ImportButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppTheme.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: AppTheme.primary, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
