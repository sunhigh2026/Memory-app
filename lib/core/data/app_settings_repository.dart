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
  static const String _keyVadThreshold = 'vad_threshold';
  static const String _keyVadMinSilenceDuration = 'vad_min_silence_duration';
  static const String _keyVadSpeechPadMs = 'vad_speech_pad_ms';

  // VAD初期値の定義（コメントで根拠を示す）
  // threshold: 0.40。0.50だと静かな部屋以外で小さな声を取りこぼし、0.30未満だとノイズを過剰検知するため、中間の0.40を初期値とする。
  static const double defaultVadThreshold = 0.40;
  
  // minSilenceDuration: 0.8秒。通常の会話では0.3秒で十分だが、暗記確認時は
  // 「言葉を思い出しながら話す」ため息継ぎが多くなることを考慮し、長めの0.8秒を初期値とする。
  static const double defaultVadMinSilenceDuration = 0.8;
  
  // speechPadMs: 150ms。発声開始時の子音（特に無声音の /p, t, k, s/ など）は音量が小さく、
  // VADの検知が約100〜150ms遅れる傾向があるため、直前の150msの実音声を結合して語頭の欠けを防ぐ。
  static const int defaultVadSpeechPadMs = 150;

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

  double getVadThreshold() {
    return _box.get(_keyVadThreshold, defaultValue: defaultVadThreshold) as double;
  }

  Future<void> setVadThreshold(double value) async {
    await _box.put(_keyVadThreshold, value);
  }

  double getVadMinSilenceDuration() {
    return _box.get(_keyVadMinSilenceDuration, defaultValue: defaultVadMinSilenceDuration) as double;
  }

  Future<void> setVadMinSilenceDuration(double value) async {
    await _box.put(_keyVadMinSilenceDuration, value);
  }

  int getVadSpeechPadMs() {
    return _box.get(_keyVadSpeechPadMs, defaultValue: defaultVadSpeechPadMs) as int;
  }

  Future<void> setVadSpeechPadMs(int value) async {
    await _box.put(_keyVadSpeechPadMs, value);
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

/// VAD しきい値の状態プロバイダ
final vadThresholdProvider =
    StateNotifierProvider<VadThresholdNotifier, double>((ref) {
  final repo = ref.watch(appSettingsRepositoryProvider);
  return VadThresholdNotifier(repo);
});

class VadThresholdNotifier extends StateNotifier<double> {
  final AppSettingsRepository _repo;

  VadThresholdNotifier(this._repo) : super(_repo.getVadThreshold());

  Future<void> setValue(double value) async {
    await _repo.setVadThreshold(value);
    state = value;
  }
}

/// VAD 無音判定秒数の状態プロバイダ
final vadMinSilenceDurationProvider =
    StateNotifierProvider<VadMinSilenceDurationNotifier, double>((ref) {
  final repo = ref.watch(appSettingsRepositoryProvider);
  return VadMinSilenceDurationNotifier(repo);
});

class VadMinSilenceDurationNotifier extends StateNotifier<double> {
  final AppSettingsRepository _repo;

  VadMinSilenceDurationNotifier(this._repo)
      : super(_repo.getVadMinSilenceDuration());

  Future<void> setValue(double value) async {
    await _repo.setVadMinSilenceDuration(value);
    state = value;
  }
}

/// VAD 前後パディング時間（ms）の状態プロバイダ
final vadSpeechPadMsProvider =
    StateNotifierProvider<VadSpeechPadMsNotifier, int>((ref) {
  final repo = ref.watch(appSettingsRepositoryProvider);
  return VadSpeechPadMsNotifier(repo);
});

class VadSpeechPadMsNotifier extends StateNotifier<int> {
  final AppSettingsRepository _repo;

  VadSpeechPadMsNotifier(this._repo) : super(_repo.getVadSpeechPadMs());

  Future<void> setValue(int value) async {
    await _repo.setVadSpeechPadMs(value);
    state = value;
  }
}
