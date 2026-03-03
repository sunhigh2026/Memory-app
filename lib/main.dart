import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/script.dart';
import 'models/cloze_word.dart';
import 'models/practice_session.dart';
import 'models/tts_dictionary_entry.dart';
import 'models/allowed_pair.dart';
import 'app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Hive 初期化
  await Hive.initFlutter();

  // アダプタ登録
  Hive.registerAdapter(ScriptAdapter());
  Hive.registerAdapter(ClozeWordAdapter());
  Hive.registerAdapter(PracticeSessionAdapter());
  Hive.registerAdapter(TtsDictionaryEntryAdapter());
  Hive.registerAdapter(AllowedPairAdapter());

  // Box を開く
  await Hive.openBox<Script>('scripts');
  await Hive.openBox<PracticeSession>('practice_sessions');
  await Hive.openBox<TtsDictionaryEntry>('tts_dictionary');
  await Hive.openBox<AllowedPair>('allowed_pairs');
  await Hive.openBox('app_settings');

  runApp(
    const ProviderScope(
      child: MemorizationApp(),
    ),
  );
}
