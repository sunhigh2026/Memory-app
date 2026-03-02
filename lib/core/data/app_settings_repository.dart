import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../../features/voice_check/data/speech_engine_type.dart';

/// アプリ設定の永続化リポジトリ
class AppSettingsRepository {
  static const String boxName = 'app_settings';
  static const String _keySpeechEngine = 'speechEngine';

  Box get _box => Hive.box(boxName);

  SpeechEngineType getSpeechEngine() {
    final value = _box.get(_keySpeechEngine, defaultValue: 'native');
    return value == 'sherpaOnnx'
        ? SpeechEngineType.sherpaOnnx
        : SpeechEngineType.native;
  }

  Future<void> setSpeechEngine(SpeechEngineType type) async {
    await _box.put(
      _keySpeechEngine,
      type == SpeechEngineType.sherpaOnnx ? 'sherpaOnnx' : 'native',
    );
  }
}

final appSettingsRepositoryProvider = Provider<AppSettingsRepository>((ref) {
  return AppSettingsRepository();
});

/// 音声認識エンジン選択の状態プロバイダ
final speechEngineTypeProvider =
    StateNotifierProvider<SpeechEngineTypeNotifier, SpeechEngineType>((ref) {
  final repo = ref.watch(appSettingsRepositoryProvider);
  return SpeechEngineTypeNotifier(repo);
});

class SpeechEngineTypeNotifier extends StateNotifier<SpeechEngineType> {
  final AppSettingsRepository _repo;

  SpeechEngineTypeNotifier(this._repo) : super(_repo.getSpeechEngine());

  Future<void> setEngine(SpeechEngineType type) async {
    await _repo.setSpeechEngine(type);
    state = type;
  }
}
