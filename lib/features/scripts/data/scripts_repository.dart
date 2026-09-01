import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../../../models/script.dart';
import '../../../core/utils/text_normalizer.dart';
import '../../progress/domain/schedule_generator.dart';
import '../../subjects/data/subjects_repository.dart';

class ScriptsRepository {
  static const String _boxName = 'scripts';
  final Uuid _uuid = const Uuid();

  Box<Script> get _box => Hive.box<Script>(_boxName);

  /// カード一覧を取得
  /// [subjectId] が指定されている場合、その科目のカードのみを返す。
  List<Script> getAll({String? subjectId}) {
    final allScripts = _box.values.toList();

    // 自動マイグレーション 1: 未学習なのにレベルが1以上になっているものは0に補正
    for (final s in allScripts) {
      if (s.practiceCount == 0 && s.currentLevel > 0) {
        s.currentLevel = 0;
        s.save();
      }
    }

    // 自動マイグレーション 2: subjectId が空のデータにデフォルト科目IDを付与
    for (final s in allScripts) {
      if (s.subjectId.isEmpty) {
        s.subjectId = SubjectsRepository.defaultSubjectId;
        s.save();
      }
    }

    // 科目フィルタリング
    final scripts = subjectId != null
        ? allScripts.where((s) => s.subjectId == subjectId).toList()
        : allScripts;

    // 自動マイグレーション 3: sortOrderが0のものに連番を付与する（科目単位で修復）
    bool hasZeroOrder = false;
    for (final s in scripts) {
      if (s.sortOrder == 0) {
        hasZeroOrder = true;
        break;
      }
    }
    if (hasZeroOrder) {
      int maxOrder = 0;
      for (final s in scripts) {
        if (s.sortOrder > maxOrder) {
          maxOrder = s.sortOrder;
        }
      }
      for (final s in scripts) {
        if (s.sortOrder == 0) {
          maxOrder++;
          s.sortOrder = maxOrder;
          s.save();
        }
      }
    }

    scripts.sort((a, b) {
      final aTime = a.lastPracticedAt;
      final bTime = b.lastPracticedAt;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });
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
    DateTime? targetDate,
    int sortOrder = 0,
    List<String>? pinnedClozeWords,
    String rank = 'B',
    String? subjectId,
  }) async {
    final parentheses = TextNormalizer.parseParenthesesMode(parenthesesMode);
    final hiragana = await TextNormalizer.fullNormalize(
      content,
      parentheses: parentheses,
    );

    List<DateTime> generatedSchedule = [];
    DateTime? nextReviewAt;
    if (targetDate != null) {
      generatedSchedule = ScheduleGenerator.generate(
        startDate: DateTime.now(),
        targetDate: targetDate,
      );
      if (generatedSchedule.isNotEmpty) {
        nextReviewAt = generatedSchedule[0];
      }
    }

    final targetSubjectId = subjectId ?? SubjectsRepository.defaultSubjectId;

    int finalSortOrder = sortOrder;
    if (finalSortOrder == 0) {
      final currentScripts =
          _box.values.where((s) => s.subjectId == targetSubjectId);
      if (currentScripts.isNotEmpty) {
        final maxOrder = currentScripts
            .map((s) => s.sortOrder)
            .reduce((curr, next) => curr > next ? curr : next);
        finalSortOrder = maxOrder + 1;
      } else {
        finalSortOrder = 1;
      }
    }

    final script = Script(
      id: _uuid.v4(),
      title: title,
      content: content,
      category: tags.isNotEmpty ? tags.first : '',
      tags: tags,
      parenthesesMode: parenthesesMode,
      fullTextHiragana: hiragana,
      targetDate: targetDate,
      generatedSchedule: generatedSchedule,
      nextReviewAt: nextReviewAt,
      sortOrder: finalSortOrder,
      pinnedClozeWords: pinnedClozeWords ?? [],
      rank: rank,
      subjectId: targetSubjectId,
    );
    await _box.add(script);
    return script;
  }

  Future<void> update(Script script) async {
    // content 変更時にひらがなキャッシュを再生成
    final parentheses =
        TextNormalizer.parseParenthesesMode(script.parenthesesMode);
    script.fullTextHiragana = await TextNormalizer.fullNormalize(
      script.content,
      parentheses: parentheses,
    );
    await script.save();
  }

  Future<void> delete(Script script) async {
    await script.delete();
  }

  Future<void> deleteAll() async {
    await _box.clear();
  }

  Future<void> deleteMultiple(List<String> ids) async {
    for (final id in ids) {
      final script = getById(id);
      if (script != null) {
        await script.delete();
      }
    }
  }

  /// 指定した科目に属するカードを一括削除
  Future<void> deleteBySubjectId(String subjectId) async {
    final targets = _box.values.where((s) => s.subjectId == subjectId).toList();
    for (final script in targets) {
      await script.delete();
    }
  }

  Future<void> updateTargetDateMultiple(
      List<String> ids, DateTime? targetDate) async {
    for (final id in ids) {
      final script = getById(id);
      if (script != null) {
        script.targetDate = targetDate;
        if (targetDate != null) {
          script.generatedSchedule = ScheduleGenerator.generate(
            startDate: DateTime.now(),
            targetDate: targetDate,
          );
          if (script.generatedSchedule.isNotEmpty) {
            script.nextReviewAt = script.generatedSchedule[0];
            script.scheduleIndex = 0;
          }
        } else {
          script.generatedSchedule = [];
          script.nextReviewAt = null;
          script.scheduleIndex = 0;
        }
        await script.save();
      }
    }
  }

  List<String> getAllTags({String? subjectId}) {
    final tags = <String>{};
    final scripts = getAll(subjectId: subjectId);
    for (final script in scripts) {
      tags.addAll(script.tags);
    }
    final sorted = tags.toList()..sort();
    return sorted;
  }

  int getTotalCount({String? subjectId}) {
    if (subjectId == null) return _box.length;
    return _box.values.where((s) => s.subjectId == subjectId).length;
  }

  int getMasteredCount({String? subjectId}) {
    final scripts = getAll(subjectId: subjectId);
    return scripts.where((s) => s.isMastered).length;
  }
}

final scriptsRepositoryProvider = Provider<ScriptsRepository>((ref) {
  return ScriptsRepository();
});

final scriptsListProvider =
    StateNotifierProvider<ScriptsListNotifier, List<Script>>((ref) {
  final repository = ref.watch(scriptsRepositoryProvider);
  final currentSubjectId = ref.watch(currentSubjectIdProvider);
  return ScriptsListNotifier(repository, currentSubjectId);
});

// タグフィルタ用プロバイダ
final selectedTagsProvider = StateProvider<Set<String>>((ref) => {});

// 並び替えモード: 'lastPracticed' | 'sortOrder' | 'level'
final sortModeProvider = StateProvider<String>((ref) => 'sortOrder');

// レベルフィルタ用プロバイダ（複数選択、空は「すべて」）
final levelFilterProvider = StateProvider<Set<int>>((ref) => {});

// ランクフィルタ用プロバイダ（複数選択、空は「すべて」）
final rankFilterProvider = StateProvider<Set<String>>((ref) => {});

class ScriptsListNotifier extends StateNotifier<List<Script>> {
  final ScriptsRepository _repository;
  final String _currentSubjectId;

  ScriptsListNotifier(this._repository, this._currentSubjectId) : super([]) {
    refresh();
  }

  void refresh() {
    state = _repository.getAll(subjectId: _currentSubjectId);
  }

  Future<Script> addScript({
    required String title,
    required String content,
    required List<String> tags,
    String parenthesesMode = 'stripContent',
    DateTime? targetDate,
    int sortOrder = 0,
    List<String>? pinnedClozeWords,
    String rank = 'B',
    String? subjectId,
  }) async {
    final script = await _repository.add(
      title: title,
      content: content,
      tags: tags,
      parenthesesMode: parenthesesMode,
      targetDate: targetDate,
      sortOrder: sortOrder,
      pinnedClozeWords: pinnedClozeWords,
      rank: rank,
      subjectId: subjectId ?? _currentSubjectId,
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

  Future<void> deleteAllScripts() async {
    // 現在の科目のカードのみ削除
    await _repository.deleteBySubjectId(_currentSubjectId);
    refresh();
  }

  Future<void> deleteMultipleScripts(List<String> ids) async {
    await _repository.deleteMultiple(ids);
    refresh();
  }

  Future<void> updateTargetDateMultiple(
      List<String> ids, DateTime? targetDate) async {
    await _repository.updateTargetDateMultiple(ids, targetDate);
    refresh();
  }
}
