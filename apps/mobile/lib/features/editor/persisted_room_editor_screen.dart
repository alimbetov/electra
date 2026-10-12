import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models.dart';
import 'room_editor_screen.dart';

/// Route boundary for the legacy room editor presentation.
///
/// Canonical project and room state is loaded from SQLite-backed repository
/// streams. The temporary [ProjectDraft]/[RoomDraft] adaptation exists only at
/// the presentation boundary until WP-FL4 migrates the editor to canonical
/// records directly.
class PersistedRoomEditorScreen extends ConsumerWidget {
  const PersistedRoomEditorScreen({
    super.key,
    required this.projectId,
    required this.floorId,
    required this.roomId,
  });

  final String projectId;
  final String floorId;
  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectAsync = ref.watch(projectProvider(projectId));
    final floorAsync = ref.watch(floorProvider(floorId));
    final roomAsync = ref.watch(roomProvider(roomId));

    return projectAsync.when(
      loading: () => const _LoadingScaffold(),
      error: (error, stackTrace) => _ErrorScaffold(error: error),
      data: (project) {
        if (project == null) {
          return const _ErrorScaffold(error: 'Project not found.');
        }
        return floorAsync.when(
          loading: () => const _LoadingScaffold(),
          error: (error, stackTrace) => _ErrorScaffold(error: error),
          data: (floor) {
            if (floor == null || floor.projectId != projectId) {
              return const _ErrorScaffold(error: 'Floor context is invalid.');
            }
            return roomAsync.when(
              loading: () => const _LoadingScaffold(),
              error: (error, stackTrace) => _ErrorScaffold(error: error),
              data: (room) {
                if (room == null || room.floorId != floorId) {
                  return const _ErrorScaffold(
                    error: 'Room context is invalid.',
                  );
                }

                return RoomEditorScreen(
                  project: ProjectDraft(
                    id: project.id,
                    name: project.name,
                    reference: project.reference,
                    measurementSystem: project.measurementSystem,
                    defaultStructuralHeightMm:
                        project.defaultStructuralHeightMm,
                    defaultFinishedCeilingHeightMm:
                        project.defaultFinishedCeilingHeightMm,
                  ),
                  room: RoomDraft(
                    id: room.id,
                    name: room.name,
                    type: room.type,
                    widthMm: room.widthMm,
                    depthMm: room.depthMm,
                    structuralHeightMmOverride: room.structuralHeightMmOverride,
                    finishedCeilingHeightMmOverride:
                        room.finishedCeilingHeightMmOverride,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _ErrorScaffold extends StatelessWidget {
  const _ErrorScaffold({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text('Unable to open room editor: $error')));
}
