import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'screens/home_screen.dart';
import 'screens/diary/diary_edit_screen.dart';
import 'screens/diary/diary_detail_screen.dart';
import 'screens/milestone/milestone_edit_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import 'services/notification_service.dart';
import 'services/background_sync_task.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  if (!kIsWeb && Platform.isAndroid) {
    try {
      await Workmanager().initialize(callbackDispatcher);
      await Workmanager().registerPeriodicTask(
        kBgTaskName,
        kBgTaskName,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
    } catch (_) {}
  }
  runApp(const ProviderScope(child: BabyDiaryApp()));
}

final _router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/diary/new',
      builder: (context, state) => const DiaryEditScreen(),
    ),
    GoRoute(
      path: '/diary/:id',
      builder: (context, state) => DiaryDetailScreen(id: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/diary/:id/edit',
      builder: (context, state) => DiaryEditScreen(diaryId: state.pathParameters['id']),
    ),
    GoRoute(
      path: '/milestone/new',
      builder: (context, state) => const MilestoneEditScreen(),
    ),
    GoRoute(
      path: '/milestone/:id/edit',
      builder: (context, state) => MilestoneEditScreen(milestoneId: state.pathParameters['id']),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);

class BabyDiaryApp extends StatelessWidget {
  const BabyDiaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '宝宝日记',
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
      locale: const Locale('zh', 'CN'),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF8FAB),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'sans-serif',
        cardTheme: const CardThemeData(elevation: 2),
        appBarTheme: const AppBarTheme(centerTitle: true),
      ),
    );
  }
}
