import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../application/component_placement_history.dart';
import '../../application/engineering_placement_repository.dart';
import '../../application/power_workspace_controller.dart';
import '../../application/power_workspace_overlay_geometry.dart';
import 'power_workspace_editor_binding.dart';
import 'room_editor_screen.dart';

/// Persistent route boundary for the Room Editor.
///
/// Project, floor, room, geometry, component instances and the P7 power read
/// model are loaded from application/data services. Only ephemeral editor
/// interaction state lives inside [RoomEditorScreen].
class PersistedRoomEditorScreen extends ConsumerStatefulWidget {
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
  ConsumerState<PersistedRoomEditorScreen> createState() =>
      _PersistedRoomEditorScreenState();
}

class _PersistedRoomEditorScreenState
    extends ConsumerState<PersistedRoomEditorScreen> {
  late var history = ComponentPlacementHistory(
    ref.read(componentInstanceRepositoryProvider),
  );
  late PowerWorkspaceController powerController;
  PowerWorkspaceSessionSnapshot? powerSession;
  List<PowerWorkspaceOverlaySegment> powerOverlaySegments = const [];
  Object? powerWorkspaceError;
  int _powerLoadGeneration = 0;

  String get projectId => widget.projectId;
  String get floorId => widget.floorId;
  String get roomId => widget.roomId;

  @override
  void initState() {
    super.initState();
    powerController = _newPowerController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openPowerWorkspace());
  }

  PowerWorkspaceController _newPowerController() => PowerWorkspaceController(
    repository: ref.read(powerWorkspaceRepositoryProvider),
  );

  @override
  void didUpdateWidget(covariant PersistedRoomEditorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roomId != widget.roomId) {
      history = ComponentPlacementHistory(
        ref.read(componentInstanceRepositoryProvider),
      );
    }
    if (oldWidget.projectId != widget.projectId) {
      powerController = _newPowerController();
      powerSession = null;
      powerOverlaySegments = const [];
      powerWorkspaceError = null;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _openPowerWorkspace(),
      );
    }
  }

  Future<void> _openPowerWorkspace() async {
    final generation = ++_powerLoadGeneration;
    try {
      final snapshot = await powerController.open(projectId);
      if (!mounted || generation != _powerLoadGeneration) return;
      if (snapshot == null) {
        setState(() {
          powerSession = null;
          powerOverlaySegments = const [];
          powerWorkspaceError = null;
        });
        return;
      }
      await _acceptPowerSession(snapshot, generation: generation);
    } catch (error) {
      if (!mounted || generation != _powerLoadGeneration) return;
      setState(() {
        powerSession = null;
        powerOverlaySegments = const [];
        powerWorkspaceError = error;
      });
    }
  }

  Future<void> _refreshPowerWorkspace() async {
    if (!powerController.isOpen) {
      await _openPowerWorkspace();
      return;
    }
    final generation = ++_powerLoadGeneration;
    try {
      final snapshot = await powerController.refresh();
      if (!mounted || generation != _powerLoadGeneration) return;
      await _acceptPowerSession(snapshot, generation: generation);
    } catch (error) {
      if (!mounted || generation != _powerLoadGeneration) return;
      setState(() => powerWorkspaceError = error);
    }
  }

  Future<void> _acceptPowerSession(
    PowerWorkspaceSessionSnapshot snapshot, {
    int? generation,
  }) async {
    final requestGeneration = generation ?? ++_powerLoadGeneration;
    final segments = await ref
        .read(powerWorkspaceOverlayGeometryRepositoryProvider)
        .load(
          projectId: snapshot.state.context.projectId,
          designRevisionId: snapshot.state.context.designRevisionId,
          cableRunIds: snapshot.projection.overlay.highlightedCableRunIds,
        );
    if (!mounted || requestGeneration != _powerLoadGeneration) return;
    setState(() {
      powerSession = snapshot;
      powerOverlaySegments = segments;
      powerWorkspaceError = null;
    });
  }

  Future<void> changeHistory(bool undo) async {
    try {
      if (undo) {
        await history.undo();
      } else {
        await history.redo();
      }
      await _refreshPowerWorkspace();
    } finally {
      if (mounted) setState(() {});
    }
  }

  PowerWorkspaceEditorBinding? get _powerBinding {
    if (powerSession == null || !powerController.isOpen) return null;
    return PowerWorkspaceEditorBinding(
      controller: powerController,
      onSessionChanged: _acceptPowerSession,
    );
  }

  @override
  Widget build(BuildContext context) {
    final projectAsync = ref.watch(projectProvider(projectId));
    final floorAsync = ref.watch(floorProvider(floorId));
    final roomAsync = ref.watch(roomProvider(roomId));
    final geometryAsync = ref.watch(roomGeometryProvider(roomId));
    final componentsAsync = ref.watch(roomComponentsProvider(roomId));
    final referencesAsync = ref.watch(
      projectEngineeringReferencesProvider(projectId),
    );
    final topologyAsync = ref.watch(
      projectEngineeringTopologyProvider(projectId),
    );

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
                              key: ValueKey(room.id),
                              project: project,
                              room: room,
                              geometry: geometry,
                              components: components,
                              powerWorkspace: _powerBinding,
                              powerOverlaySegments: powerOverlaySegments,
                              powerWorkspaceError: powerWorkspaceError,
                              engineeringReferences:
                                  referencesAsync.asData?.value,
                              engineeringReferenceMessage:
                                  referencesAsync.hasError
                                      ? 'Unable to load reference catalogs: ${referencesAsync.error}'
                                      : 'Loading engineering reference catalogs…',
                              engineeringTopologyProfiles:
                                  topologyAsync
                                      .asData
                                      ?.value
                                      .topologyProfiles ??
                                  const [],
                              catalogPreferences: ref.watch(
                                catalogPreferencesRepositoryProvider,
                              ),
                              canUndoPlacement: history.canUndo,
                              canRedoPlacement: history.canRedo,
                              onUndoPlacement: () => changeHistory(true),
                              onRedoPlacement: () => changeHistory(false),
                              onPlaceEngineeringProfile: (command) async {
                                final placementHistory = history;
                                final repository = ref.read(
                                  engineeringPlacementRepositoryProvider,
                                );
                                final result = await repository.place(command);
                                placementHistory.recordEngineering(
                                  EngineeringPlacementHistoryEntry(
                                    command: command,
                                    result: result,
                                  ),
                                  repository,
                                );
                                await _refreshPowerWorkspace();
                                if (mounted) setState(() {});
                                return result;
                              },
                              onPlaceComponent: (
                                definition,
                                hostSurfacePatchId,
                                localPosition,
                              ) async {
                                final placementHistory = history;
                                final instance = await ref
                                    .read(componentPlacementServiceProvider)
                                    .place(
                                      roomId: room.id,
                                      definition: definition,
                                      hostSurfacePatchId: hostSurfacePatchId,
                                      localPosition: localPosition,
                                    );
                                placementHistory.record(instance);
                                await _refreshPowerWorkspace();
                                if (mounted) setState(() {});
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
