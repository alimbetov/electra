import 'package:flutter/material.dart';

import 'project_recalculation_screen.dart';

class CalculationsScreen extends StatelessWidget {
  const CalculationsScreen({
    super.key,
    required this.roomName,
    required this.projectId,
  });
  final String roomName, projectId;
  @override
  Widget build(BuildContext context) =>
      ProjectRecalculationScreen(projectId: projectId);
}
