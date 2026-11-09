import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'controller.dart';
import '../features/tasks/presentation/workspace_screen.dart';

class DaymindApp extends ConsumerStatefulWidget {
  const DaymindApp({super.key});
  @override
  ConsumerState<DaymindApp> createState() => _DaymindAppState();
}

class _DaymindAppState extends ConsumerState<DaymindApp> {
  late final router = GoRouter(
    initialLocation: ref.read(workspaceProvider).notificationOpenRequest > 0
        ? '/notifications'
        : '/today',
    routes: [
      GoRoute(
        path: '/:page',
        builder: (context, state) =>
            WorkspaceScreen(page: state.pathParameters['page']!),
      ),
    ],
  );
  @override
  void dispose() {
    router.dispose();
    super.dispose();
  }

  ThemeData theme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xff526b4b),
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'BeVietnamPro',
      scaffoldBackgroundColor: brightness == Brightness.light
          ? const Color(0xfff5f6f1)
          : const Color(0xff19221c),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(
      workspaceProvider.select((c) => c.notificationOpenRequest),
      (previous, next) {
        router.go('/notifications');
      },
    );
    final prefs = ref.watch(workspaceProvider).preferences;
    return MaterialApp.router(
      title: 'DayMind SMART',
      debugShowCheckedModeBanner: false,
      locale: const Locale('vi'),
      supportedLocales: const [Locale('vi'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      themeMode: switch (prefs.theme) {
        'dark' => ThemeMode.dark,
        'light' => ThemeMode.light,
        _ => ThemeMode.system,
      },
      routerConfig: router,
    );
  }
}
