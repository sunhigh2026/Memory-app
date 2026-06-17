import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../../features/voice_check/data/speech_engine_type.dart';

/// アプリ設定の永続化リポジトリ
class AppSettingsRepository {
  static const String boxName = 'app_settings';
  static const String _keySpeechEngine = 'speechEngine';
  static const String _keyDefaultReviewPace = 'defaultReviewPace';

  Box get _box => Hive.box(boxName);

  String getDefaultReviewPace() {
    return _box.get(_keyDefaultReviewPace, defaultValue: 'normal') as String;
  }

  Future<void> setDefaultReviewPace(String pace) async {
    await _box.put(_keyDefaultReviewPace, pace);
  }

  SpeechEngineType getSpeechEngine() {
    final value = _box.get(_keySpeechEngine, defaultValue: 'native');
    return value == 'sherpaOnnx'
        ? SpeechEngineType.sherpaOnnx
        : SpeechEngineType.native;
  }

  static const String _keyDailyGoal = 'dailyGoal';
  static const String _keyGoalSettingMode = 'goalSettingMode';

  Future<void> setSpeechEngine(SpeechEngineType type) async {
    await _box.put(
      _keySpeechEngine,
      type == SpeechEngineType.sherpaOnnx ? 'sherpaOnnx' : 'native',
    );
  }

  int getDailyGoal() {
    return _box.get(_keyDailyGoal, defaultValue: 10) as int;
  }

  Future<void> setDailyGoal(int goal) async {
    await _box.put(_keyDailyGoal, goal);
  }

  String getGoalSettingMode() {
    return _box.get(_keyGoalSettingMode, defaultValue: 'manual') as String;
  }

  Future<void> setGoalSettingMode(String mode) async {
    await _box.put(_keyGoalSettingMode, mode);
  }
}

final appSettingsRepositoryProvider = Provider<AppSettingsRepository>((ref) {
  return AppSettingsRepository();
});

/// 目標設定モードの状態プロバイダ ('auto' / 'manual')
final goalSettingModeProvider =
    StateNotifierProvider<GoalSettingModeNotifier, String>((ref) {
  final repo = ref.watch(appSettingsRepositoryProvider);
  return GoalSettingModeNotifier(repo);
});

class GoalSettingModeNotifier extends StateNotifier<String> {
  final AppSettingsRepository _repo;

  GoalSettingModeNotifier(this._repo) : super(_repo.getGoalSettingMode());

  Future<void> setMode(String mode) async {
    await _repo.setGoalSettingMode(mode);
    state = mode;
  }
}

/// 今日の目標練習回数の状態プロバイダ
final dailyGoalProvider =
    StateNotifierProvider<DailyGoalNotifier, int>((ref) {
  final repo = ref.watch(appSettingsRepositoryProvider);
  return DailyGoalNotifier(repo);
});

class DailyGoalNotifier extends StateNotifier<int> {
  final AppSettingsRepository _repo;

  DailyGoalNotifier(this._repo) : super(_repo.getDailyGoal());

  Future<void> setGoal(int goal) async {
    await _repo.setDailyGoal(goal);
    state = goal;
  }
}

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
