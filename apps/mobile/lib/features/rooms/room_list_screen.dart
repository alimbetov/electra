import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../domain/models.dart';
import '../editor/room_editor_screen.dart';
import 'room_create_screen.dart';

class RoomListScreen extends StatelessWidget {
  const RoomListScreen({
    super.key,
    required this.appState,
    required this.project,
  });

  final ElectraAppState appState;
  final ProjectDraft project;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(project.name)),
      body: AnimatedBuilder(
        animation: appState,
        builder: (context, _) {
          if (project.rooms.isEmpty) {
            return const Center(child: Text('No rooms yet.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: project.rooms.length,
            itemBuilder: (context, index) {
              final room = project.rooms[index];
              return Card(
                child: ListTile(
                  title: Text(room.name),
                  subtitle: Text(
                    '${room.type.name} · ${room.widthMm} × ${room.depthMm} mm',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => RoomEditorScreen(
                        project: project,
                        room: room,
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
          final room = await Navigator.of(context).push<RoomDraft>(
            MaterialPageRoute<RoomDraft>(
              builder: (_) => RoomCreateScreen(project: project),
            ),
          );
          if (room != null) appState.addRoom(project.id, room);
        },
        icon: const Icon(Icons.add),
        label: const Text('New room'),
      ),
    );
  }
}
