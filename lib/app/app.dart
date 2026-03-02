import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_theme.dart';
import '../features/scripts/presentation/home_screen.dart';
import '../features/scripts/presentation/script_add_screen.dart';
import '../features/scripts/presentation/script_detail_screen.dart';
import '../features/practice/presentation/practice_screen.dart';
import '../features/practice/presentation/practice_result_screen.dart';
import '../features/voice_check/presentation/voice_check_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/settings/presentation/tts_dictionary_screen.dart';
import '../features/voice_check/presentation/model_download_screen.dart';

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/add',
      builder: (context, state) => const ScriptAddScreen(),
    ),
    GoRoute(
      path: '/edit/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return ScriptAddScreen(scriptId: id);
      },
    ),
    GoRoute(
      path: '/detail/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return ScriptDetailScreen(scriptId: id);
      },
    ),
    GoRoute(
      path: '/practice/:id/:level',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        final level = int.parse(state.pathParameters['level']!);
        return PracticeScreen(scriptId: id, level: level);
      },
    ),
    GoRoute(
      path: '/practice-result',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return PracticeResultScreen(
          scriptId: extra['scriptId'] as String,
          score: extra['score'] as double,
          level: extra['level'] as int,
          totalQuestions: extra['totalQuestions'] as int,
          correctAnswers: extra['correctAnswers'] as int,
        );
      },
    ),
    GoRoute(
      path: '/voice-check/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return VoiceCheckScreen(scriptId: id);
      },
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/tts-dictionary',
      builder: (context, state) => const TtsDictionaryScreen(),
    ),
    GoRoute(
      path: '/model-download',
      builder: (context, state) => const ModelDownloadScreen(),
    ),
  ],
);

class MemorizationApp extends StatelessWidget {
  const MemorizationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '暗記サポート',
      theme: AppTheme.theme,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
