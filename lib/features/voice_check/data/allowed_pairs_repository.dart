import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../../../models/allowed_pair.dart';
import '../../../core/utils/text_normalizer.dart';

class AllowedPairsRepository {
  static const String _boxName = 'allowed_pairs';
  final Uuid _uuid = const Uuid();

  Box<AllowedPair> get _box => Hive.box<AllowedPair>(_boxName);

  List<AllowedPair> getByScriptId(String scriptId) {
    return _box.values
        .where((pair) => pair.scriptId == scriptId)
        .toList();
  }

  /// 重複チェック（同じ scriptId + originalWord + recognizedWord は登録しない）
  bool exists(String scriptId, String originalWord, String recognizedWord) {
    return _box.values.any((pair) =>
        pair.scriptId == scriptId &&
        pair.originalWord == originalWord &&
        pair.recognizedWord == recognizedWord);
  }

  Future<AllowedPair> add({
    required String scriptId,
    required String originalWord,
    required String recognizedWord,
  }) async {
    final originalHira = await TextNormalizer.fullNormalize(originalWord);
    final recognizedHira = await TextNormalizer.fullNormalize(recognizedWord);

    final pair = AllowedPair(
      id: _uuid.v4(),
      scriptId: scriptId,
      originalWord: originalWord,
      recognizedWord: recognizedWord,
      originalHira: originalHira,
      recognizedHira: recognizedHira,
    );
    await _box.put(pair.id, pair);
    return pair;
  }

  Future<void> delete(AllowedPair pair) async {
    await _box.delete(pair.key);
  }
}

final allowedPairsRepositoryProvider = Provider<AllowedPairsRepository>((ref) {
  return AllowedPairsRepository();
});
