import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../../../models/tts_dictionary_entry.dart';

/// TTS読み上げ辞書リポジトリ
class TtsDictionaryRepository {
  final Box<TtsDictionaryEntry> _box;

  TtsDictionaryRepository(this._box);

  List<TtsDictionaryEntry> getAll() => _box.values.toList();

  Future<void> add(String original, String reading) async {
    final entry = TtsDictionaryEntry(original: original, reading: reading);
    await _box.add(entry);
  }

  Future<void> update(TtsDictionaryEntry entry, String original, String reading) async {
    entry.original = original;
    entry.reading = reading;
    await entry.save();
  }

  Future<void> delete(TtsDictionaryEntry entry) async {
    await entry.delete();
  }

  /// テキストに辞書の置換を適用（長い語優先）
  String applySubstitutions(String text) {
    final entries = getAll();
    if (entries.isEmpty) return text;

    // 長い語から先に置換（部分一致の干渉を防ぐ）
    entries.sort((a, b) => b.original.length.compareTo(a.original.length));

    var result = text;
    for (final entry in entries) {
      result = result.replaceAll(entry.original, entry.reading);
    }
    return result;
  }
}

final ttsDictionaryRepositoryProvider = Provider<TtsDictionaryRepository>((ref) {
  final box = Hive.box<TtsDictionaryEntry>('tts_dictionary');
  return TtsDictionaryRepository(box);
});

/// 辞書一覧用プロバイダ（更新検知可能）
class TtsDictionaryNotifier extends StateNotifier<List<TtsDictionaryEntry>> {
  final TtsDictionaryRepository _repo;

  TtsDictionaryNotifier(this._repo) : super(_repo.getAll());

  Future<void> add(String original, String reading) async {
    await _repo.add(original, reading);
    state = _repo.getAll();
  }

  Future<void> update(TtsDictionaryEntry entry, String original, String reading) async {
    await _repo.update(entry, original, reading);
    state = _repo.getAll();
  }

  Future<void> delete(TtsDictionaryEntry entry) async {
    await _repo.delete(entry);
    state = _repo.getAll();
  }
}

final ttsDictionaryListProvider =
    StateNotifierProvider<TtsDictionaryNotifier, List<TtsDictionaryEntry>>((ref) {
  final repo = ref.watch(ttsDictionaryRepositoryProvider);
  return TtsDictionaryNotifier(repo);
});
