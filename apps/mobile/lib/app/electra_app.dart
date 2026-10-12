import 'package:flutter/material.dart';

import 'app_router.dart';

class ElectraApp extends StatefulWidget {
  const ElectraApp({super.key});

  @override
  State<ElectraApp> createState() => _ElectraAppState();
}

class _ElectraAppState extends State<ElectraApp> {
  late final router = createElectraRouter();

  @override
  void dispose() {
    router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF315CFF),
      brightness: Brightness.light,
    );

    return MaterialApp.router(
      title: 'Electra',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF6F7F9),
        visualDensity: VisualDensity.standard,
        appBarTheme: const AppBarTheme(centerTitle: false),
        cardTheme: const CardThemeData(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
        ),
        tooltipTheme: const TooltipThemeData(
          waitDuration: Duration(milliseconds: 450),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
    );
  }
}
