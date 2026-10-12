import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../domain/models.dart';
import '../rooms/room_list_screen.dart';
import 'project_create_screen.dart';

class ProjectListScreen extends StatelessWidget {
  const ProjectListScreen({super.key, required this.appState});

  final ElectraAppState appState;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Projects')),
      body: AnimatedBuilder(
        animation: appState,
        builder: (context, _) {
          if (appState.projects.isEmpty) {
            return const Center(
              child: Text('No projects yet. Create the first engineering project.'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: appState.projects.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final project = appState.projects[index];
              return Card(
                child: ListTile(
                  title: Text(project.name),
                  subtitle: Text(
                    '${project.reference.isEmpty ? 'No reference' : project.reference} · ${project.measurementSystem.name.toUpperCase()} · ${project.rooms.length} rooms',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => RoomListScreen(
                        appState: appState,
                        project: project,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final project = await Navigator.of(context).push<ProjectDraft>(
            MaterialPageRoute<ProjectDraft>(
              builder: (_) => const ProjectCreateScreen(),
            ),
          );
          if (project != null) appState.addProject(project);
        },
        icon: const Icon(Icons.add),
        label: const Text('New project'),
      ),
    );
  }
}
