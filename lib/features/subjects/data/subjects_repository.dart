import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../../../models/subject.dart';

class SubjectsRepository {
  static const String _boxName = 'subjects';
  static const String _settingsBoxName = 'app_settings';
  static const String _keyCurrentSubjectId = 'current_subject_id';
  
  static const String defaultSubjectId = 'default_subject';
  static const String defaultSubjectName = '一般';

  final Uuid _uuid = const Uuid();

  Box<Subject> get _box => Hive.box<Subject>(_boxName);
  Box get _settingsBox => Hive.box(_settingsBoxName);

  /// 全科目をソート順（sortOrder）で取得。
  /// もし科目が1件も存在しなければ、初期科目を自動作成する。
  List<Subject> getAll() {
    _ensureDefaultSubject();
    final list = _box.values.toList();
    list.sort((a, b) {
      final orderCompare = a.sortOrder.compareTo(b.sortOrder);
      if (orderCompare != 0) return orderCompare;
      return a.createdAt.compareTo(b.createdAt);
    });
    return list;
  }

  /// 初期科目の作成を保証
  Subject _ensureDefaultSubject() {
    if (_box.isEmpty) {
      final defaultSubject = Subject(
        id: defaultSubjectId,
        name: defaultSubjectName,
        createdAt: DateTime.now(),
        sortOrder: 1,
      );
      _box.put(defaultSubject.id, defaultSubject);
      _settingsBox.put(_keyCurrentSubjectId, defaultSubject.id);
      return defaultSubject;
    }
    return _box.values.first;
  }

  /// 現在選択中の科目IDを取得
  String getCurrentSubjectId() {
    _ensureDefaultSubject();
    final savedId = _settingsBox.get(_keyCurrentSubjectId) as String?;
    if (savedId != null && _box.containsKey(savedId)) {
      return savedId;
    }
    // 保存されているIDが存在しない場合は最初の科目を使用
    final first = getAll().first;
    _settingsBox.put(_keyCurrentSubjectId, first.id);
    return first.id;
  }

  /// 現在選択中の科目を設定
  Future<void> setCurrentSubjectId(String id) async {
    await _settingsBox.put(_keyCurrentSubjectId, id);
  }

  /// 現在選択中の科目オブジェクトを取得
  Subject getCurrentSubject() {
    final currentId = getCurrentSubjectId();
    return getById(currentId) ?? _ensureDefaultSubject();
  }

  /// IDで科目を取得
  Subject? getById(String id) {
    try {
      return _box.get(id);
    } catch (_) {
      return null;
    }
  }

  /// 新規科目を追加
  Future<Subject> add(String name) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('科目名を入力してください。');
    }

    final subjects = getAll();
    final maxOrder = subjects.isEmpty
        ? 0
        : subjects.map((s) => s.sortOrder).reduce((a, b) => a > b ? a : b);

    final subject = Subject(
      id: _uuid.v4(),
      name: trimmedName,
      createdAt: DateTime.now(),
      sortOrder: maxOrder + 1,
    );

    await _box.put(subject.id, subject);
    // 新規作成した科目を自動的にアクティブにする
    await setCurrentSubjectId(subject.id);
    return subject;
  }

  /// 科目名を更新
  Future<void> update(Subject subject) async {
    await subject.save();
  }

  /// 科目を削除
  /// 最後の1件は削除できません。
  /// 削除対象が現在選択中の科目の場合、他の科目に自動で切り替えます。
  Future<bool> delete(String id) async {
    final subjects = getAll();
    if (subjects.length <= 1) {
      // 最後の1件は削除不可
      return false;
    }

    final subject = getById(id);
    if (subject == null) return false;

    await subject.delete();

    // 現在選択中の科目を削除した場合、残りの最初の科目に切り替える
    if (getCurrentSubjectId() == id) {
      final remaining = getAll();
      if (remaining.isNotEmpty) {
        await setCurrentSubjectId(remaining.first.id);
      }
    }

    return true;
  }
}

/// SubjectsRepository Provider
final subjectsRepositoryProvider = Provider<SubjectsRepository>((ref) {
  return SubjectsRepository();
});

/// 現在選択中の科目IDを管理するNotifier & Provider
final currentSubjectIdProvider =
    StateNotifierProvider<CurrentSubjectIdNotifier, String>((ref) {
  final repo = ref.watch(subjectsRepositoryProvider);
  return CurrentSubjectIdNotifier(repo);
});

class CurrentSubjectIdNotifier extends StateNotifier<String> {
  final SubjectsRepository _repo;

  CurrentSubjectIdNotifier(this._repo) : super(_repo.getCurrentSubjectId());

  Future<void> selectSubject(String id) async {
    await _repo.setCurrentSubjectId(id);
    state = id;
  }
}

/// 全科目リストを管理するNotifier & Provider
final subjectsListProvider =
    StateNotifierProvider<SubjectsListNotifier, List<Subject>>((ref) {
  final repo = ref.watch(subjectsRepositoryProvider);
  return SubjectsListNotifier(repo, ref);
});

class SubjectsListNotifier extends StateNotifier<List<Subject>> {
  final SubjectsRepository _repo;
  final Ref _ref;

  SubjectsListNotifier(this._repo, this._ref) : super([]) {
    refresh();
  }

  void refresh() {
    state = _repo.getAll();
  }

  Future<Subject> addSubject(String name) async {
    final subject = await _repo.add(name);
    refresh();
    _ref.read(currentSubjectIdProvider.notifier).selectSubject(subject.id);
    return subject;
  }

  Future<void> updateSubjectName(String id, String newName) async {
    final subject = _repo.getById(id);
    if (subject != null) {
      subject.name = newName.trim();
      await _repo.update(subject);
      refresh();
    }
  }

  Future<bool> deleteSubject(String id) async {
    final currentId = _ref.read(currentSubjectIdProvider);
    final success = await _repo.delete(id);
    if (success) {
      refresh();
      if (currentId == id) {
        final newCurrent = _repo.getCurrentSubjectId();
        _ref.read(currentSubjectIdProvider.notifier).selectSubject(newCurrent);
      }
    }
    return success;
  }
}

/// 現在選択中のSubjectオブジェクトを取得するProvider
final currentSubjectProvider = Provider<Subject>((ref) {
  final currentId = ref.watch(currentSubjectIdProvider);
  final repo = ref.watch(subjectsRepositoryProvider);
  // subjectsListProvider を監視してリスト変更時にも再評価
  ref.watch(subjectsListProvider);
  return repo.getById(currentId) ?? repo.getAll().first;
});
