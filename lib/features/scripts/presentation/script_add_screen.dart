import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
          IconButton(
            icon: const Icon(Icons.document_scanner),
            tooltip: 'OCR取り込み',
            onPressed: _showOcrImport,
          ),
          TextButton(
            onPressed: _save,
            child: Text(
              _isEditing ? '更新' : '保存',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
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
            Text(
              'タグ',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
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
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
            // 本文
            TextFormField(
              controller: _contentController,
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
      final currentText = _contentController.text;
      _contentController.text =
          currentText.isEmpty ? result : '$currentText\n$result';
      setState(() {});
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
