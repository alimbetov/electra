import 'package:flutter/material.dart';

import '../features/projects/project_list_screen.dart';
import 'app_state.dart';

class ElectraApp extends StatefulWidget {
  const ElectraApp({super.key});

  @override
  State<ElectraApp> createState() => _ElectraAppState();
}

class _ElectraAppState extends State<ElectraApp> {
  final ElectraAppState appState = ElectraAppState();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Electra',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: ProjectListScreen(appState: appState),
    );
  }
}
