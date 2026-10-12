import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import 'room_editor_screen.dart';

/// Persistent route boundary for the Room Editor.
///
/// Project, floor, room, geometry and component instances are loaded from
/// SQLite-backed repository streams. Only ephemeral editor interaction state
/// lives inside [RoomEditorScreen].
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
    final geometryAsync = ref.watch(roomGeometryProvider(roomId));
    final componentsAsync = ref.watch(roomComponentsProvider(roomId));

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
                return geometryAsync.when(
                  loading: () => const _LoadingScaffold(),
                  error: (error, stackTrace) => _ErrorScaffold(error: error),
                  data:
                      (geometry) => componentsAsync.when(
                        loading: () => const _LoadingScaffold(),
                        error:
                            (error, stackTrace) => _ErrorScaffold(error: error),
                        data:
                            (components) => RoomEditorScreen(
                              project: project,
                              room: room,
                              geometry: geometry,
                              components: components,
                              onPlaceComponent: (
                                definition,
                                hostSurfacePatchId,
                                localPosition,
                              ) async {
                                await ref
                                    .read(componentPlacementServiceProvider)
                                    .place(
                                      roomId: room.id,
                                      definition: definition,
                                      hostSurfacePatchId: hostSurfacePatchId,
                                      localPosition: localPosition,
                                    );
                              },
                            ),
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
