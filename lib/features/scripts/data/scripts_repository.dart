import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../../../models/script.dart';
import '../../../core/utils/text_normalizer.dart';
import '../../progress/domain/schedule_generator.dart';

class ScriptsRepository {
  static const String _boxName = 'scripts';
  final Uuid _uuid = const Uuid();

  Box<Script> get _box => Hive.box<Script>(_boxName);

  List<Script> getAll() {
    final scripts = _box.values.toList();
    
    // 自動マイグレーション: 未学習なのにレベルが1以上になっているものは0に補正
    for (final s in scripts) {
      if (s.practiceCount == 0 && s.currentLevel > 0) {
        s.currentLevel = 0;
        s.save();
      }
    }

    // 自動マイグレーション: sortOrderが0のものに連番を付与する（既存データの修復）
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

    int finalSortOrder = sortOrder;
    if (finalSortOrder == 0) {
      final currentScripts = _box.values;
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
    );
    await _box.add(script);
    return script;
  }

  Future<void> update(Script script) async {
    // content 変更時にひらがなキャッシュを再生成
    final parentheses = TextNormalizer.parseParenthesesMode(script.parenthesesMode);
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

  Future<void> updateTargetDateMultiple(List<String> ids, DateTime? targetDate) async {
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

// 並び替えモード: 'lastPracticed' | 'sortOrder' | 'level'
final sortModeProvider = StateProvider<String>((ref) => 'lastPracticed');

// レベルフィルタ用プロバイダ（null = すべて）
final levelFilterProvider = StateProvider<int?>((ref) => null);

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
    DateTime? targetDate,
    int sortOrder = 0,
    List<String>? pinnedClozeWords,
  }) async {
    final script = await _repository.add(
      title: title,
      content: content,
      tags: tags,
      parenthesesMode: parenthesesMode,
      targetDate: targetDate,
      sortOrder: sortOrder,
      pinnedClozeWords: pinnedClozeWords,
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
    await _repository.deleteAll();
    refresh();
  }

  Future<void> deleteMultipleScripts(List<String> ids) async {
    await _repository.deleteMultiple(ids);
    refresh();
  }

  Future<void> updateTargetDateMultiple(List<String> ids, DateTime? targetDate) async {
    await _repository.updateTargetDateMultiple(ids, targetDate);
    refresh();
  }
}
