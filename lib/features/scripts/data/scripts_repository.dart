import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../../../models/script.dart';

class ScriptsRepository {
  static const String _boxName = 'scripts';
  final Uuid _uuid = const Uuid();

  Box<Script> get _box => Hive.box<Script>(_boxName);

  List<Script> getAll() {
    final scripts = _box.values.toList();
    scripts.sort((a, b) => b.lastPracticedAt.compareTo(a.lastPracticedAt));
    return scripts;
  }

  Script? getById(String id) {
    try {
      return _box.values.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<Script> add({
    required String title,
    required String content,
    required List<String> tags,
    String parenthesesMode = 'stripContent',
  }) async {
    final script = Script(
      id: _uuid.v4(),
      title: title,
      content: content,
      category: tags.isNotEmpty ? tags.first : '',
      tags: tags,
      parenthesesMode: parenthesesMode,
    );
    await _box.add(script);
    return script;
  }

  Future<void> update(Script script) async {
    await script.save();
  }

  Future<void> delete(Script script) async {
    await script.delete();
  }

  List<String> getAllTags() {
    final tags = <String>{};
    for (final script in _box.values) {
      tags.addAll(script.tags);
    }
    final sorted = tags.toList()..sort();
    return sorted;
  }

  int get totalCount => _box.length;

  int get masteredCount =>
      _box.values.where((s) => s.isMastered).length;
}

final scriptsRepositoryProvider = Provider<ScriptsRepository>((ref) {
  return ScriptsRepository();
});

final scriptsListProvider = StateNotifierProvider<ScriptsListNotifier, List<Script>>((ref) {
  final repository = ref.watch(scriptsRepositoryProvider);
  return ScriptsListNotifier(repository);
});

// タグフィルタ用プロバイダ
final selectedTagsProvider = StateProvider<Set<String>>((ref) => {});

class ScriptsListNotifier extends StateNotifier<List<Script>> {
  final ScriptsRepository _repository;

  ScriptsListNotifier(this._repository) : super([]) {
    refresh();
  }

  void refresh() {
    state = _repository.getAll();
  }

  Future<Script> addScript({
    required String title,
    required String content,
    required List<String> tags,
    String parenthesesMode = 'stripContent',
  }) async {
    final script = await _repository.add(
      title: title,
      content: content,
      tags: tags,
      parenthesesMode: parenthesesMode,
    );
    refresh();
    return script;
  }

  Future<void> updateScript(Script script) async {
    await _repository.update(script);
    refresh();
  }

  Future<void> deleteScript(Script script) async {
    await _repository.delete(script);
    refresh();
  }
}
