import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_theme.dart';
import '../features/scripts/presentation/home_screen.dart';
import '../features/scripts/presentation/script_add_screen.dart';
import '../features/scripts/presentation/script_detail_screen.dart';
import '../features/practice/presentation/practice_screen.dart';
import '../features/practice/presentation/practice_result_screen.dart';
import '../features/practice/presentation/flip_mode_screen.dart';
import '../features/practice/presentation/review_list_screen.dart';



import '../features/voice_check/presentation/voice_check_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/settings/presentation/tts_dictionary_screen.dart';
import '../features/settings/presentation/how_to_use_screen.dart';
import '../features/voice_check/presentation/model_download_screen.dart';
import '../features/progress/presentation/statistics_screen.dart';

// Section 5-E: フェードトランジション用ヘルパー
CustomTransitionPage<T> _fadePage<T>(
    BuildContext context, GoRouterState state, Widget child,
    {Duration duration = const Duration(milliseconds: 200)}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: duration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

// Section 5-E: スライド+フェードトランジション（モーダル系）
CustomTransitionPage<T> _slideFadePage<T>(
    BuildContext context, GoRouterState state, Widget child,
    {Duration duration = const Duration(milliseconds: 250)}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: duration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final slide = Tween(
        begin: const Offset(0, 0.1),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));
      return FadeTransition(
        opacity: animation,
        child: SlideTransition(position: slide, child: child),
      );
    },
  );
}

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      pageBuilder: (context, state) =>
          _fadePage(context, state, const HomeScreen()),
    ),
    GoRoute(
      path: '/review-list',
      pageBuilder: (context, state) =>
          _fadePage(context, state, const ReviewListScreen()),
    ),
    GoRoute(
      path: '/add',
      pageBuilder: (context, state) =>
          _slideFadePage(context, state, const ScriptAddScreen()),
    ),
    GoRoute(
      path: '/edit/:id',
      pageBuilder: (context, state) {
        final id = state.pathParameters['id']!;
        return _slideFadePage(context, state, ScriptAddScreen(scriptId: id));
      },
    ),
    GoRoute(
      path: '/detail/:id',
      pageBuilder: (context, state) {
        final id = state.pathParameters['id']!;
        return _fadePage(context, state, ScriptDetailScreen(scriptId: id));
      },
    ),
    GoRoute(
      path: '/practice/:id/:level',
      pageBuilder: (context, state) {
        final id = state.pathParameters['id']!;
        final level = int.parse(state.pathParameters['level']!);
        if (level == 2) {
          final extra = state.extra as Map<String, dynamic>?;
          final retryWords = extra?['retryWords'] as List<String>?;
          return _fadePage(
              context, state, FlipModeScreen(scriptId: id, retryWords: retryWords));
        }
        return _fadePage(
            context, state, PracticeScreen(scriptId: id, level: level));
      },
    ),


    GoRoute(
      path: '/practice-result',
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return _fadePage(
          context,
          state,
          PracticeResultScreen(
            scriptId: extra['scriptId'] as String,
            score: extra['score'] as double,
            level: extra['level'] as int,
            totalQuestions: extra['totalQuestions'] as int,
            correctAnswers: extra['correctAnswers'] as int,
            durationSeconds: extra['durationSeconds'] as int? ?? 0,
            mistakes: (extra['mistakes'] as List<dynamic>?)?.cast<String>() ?? const [],
            isRetry: extra['isRetry'] as bool? ?? false,
            isReviewSession: extra['isReviewSession'] as bool? ?? false,
          ),
        );
      },
    ),
    GoRoute(
      path: '/voice-check/:id',
      pageBuilder: (context, state) {
        final id = state.pathParameters['id']!;
        return _fadePage(context, state, VoiceCheckScreen(scriptId: id, level: 5));
      },
    ),
    GoRoute(
      path: '/voice-check/:id/:level',
      pageBuilder: (context, state) {
        final id = state.pathParameters['id']!;
        final level = int.tryParse(state.pathParameters['level'] ?? '') ?? 5;
        return _fadePage(
            context, state, VoiceCheckScreen(scriptId: id, level: level));
      },
    ),
    GoRoute(
      path: '/settings',
      pageBuilder: (context, state) =>
          _slideFadePage(context, state, const SettingsScreen()),
      routes: [
        GoRoute(
          path: 'tts-dictionary',
          pageBuilder: (context, state) =>
              _slideFadePage(context, state, const TtsDictionaryScreen()),
        ),
        GoRoute(
          path: 'how-to-use',
          pageBuilder: (context, state) =>
              _slideFadePage(context, state, const HowToUseScreen()),
        ),
      ],
    ),
    GoRoute(
      path: '/model-download',
      pageBuilder: (context, state) =>
          _slideFadePage(context, state, const ModelDownloadScreen()),
    ),
    GoRoute(
      path: '/statistics',
      pageBuilder: (context, state) =>
          _fadePage(context, state, const StatisticsScreen()),
    ),
  ],
);

class MemorizationApp extends StatelessWidget {
  const MemorizationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '暗リピ',
      theme: AppTheme.theme,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ja', 'JP'),
      ],
    );
  }
}
