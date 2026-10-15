import 'dart:async';
import '../../application/engineering_placement_command.dart';
import '../../application/id_generator.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../application/geometry_repository.dart';
import '../../application/engineering_profile_palette.dart';
import '../../application/engineering_reference_repository.dart';
import 'engineering_profile_palette.dart';
import 'engineering_placement_preview.dart';
import '../../application/catalog_preferences_repository.dart';
import '../../application/power_workspace_overlay_geometry.dart';
import '../../application/power_workspace_projection.dart';
import '../../application/power_workspace_state.dart';
import '../../domain/models.dart';
import '../../domain/project_models.dart';
import '../../domain/system_component_catalog.dart';
import '../calculations/calculations_screen.dart';
import '../reports/reports_screen.dart';
import 'component_catalog_sheet.dart';
import 'editor_interaction.dart';
import 'electrical_loads_screen.dart';
import 'electrical_circuits_screen.dart';
import 'power_workspace_editor_binding.dart';
import 'power_workspace_overlay_painter.dart';
import 'power_workspace_panel.dart';
import 'power_workspace_panel_host.dart';
import 'room_routing_screen.dart';

typedef ComponentPlacementCallback =
    Future<void> Function(
      ComponentDefinition definition,
      String hostSurfacePatchId,
      Point2Mm localPosition,
    );

class RoomEditorScreen extends StatefulWidget {
  const RoomEditorScreen({
    super.key,
    required this.project,
    required this.room,
    required this.geometry,
    this.components = const [],
    this.powerWorkspace,
    this.powerOverlaySegments = const [],
    this.powerWorkspaceError,
    this.engineeringReferences,
    this.engineeringReferenceMessage,
    this.engineeringTopologyProfiles = const [],
    this.onPlaceComponent,
    this.onPlaceEngineeringProfile,
    this.catalogPreferences,
    this.onUndoPlacement,
    this.onRedoPlacement,
    this.canUndoPlacement = false,
    this.canRedoPlacement = false,
  });

  final ProjectRecord project;
  final RoomRecord room;
  final RoomGeometrySnapshot geometry;
  final List<ComponentInstance> components;
  final PowerWorkspaceEditorBinding? powerWorkspace;
  final List<PowerWorkspaceOverlaySegment> powerOverlaySegments;
  final Object? powerWorkspaceError;
  final ProjectEngineeringReferences? engineeringReferences;
  final String? engineeringReferenceMessage;
  final List<TopologyProfile> engineeringTopologyProfiles;
  final ComponentPlacementCallback? onPlaceComponent;
  final Future<EngineeringPlacementResult> Function(
    PlaceEngineeringProfileCommand,
  )?
  onPlaceEngineeringProfile;
  final CatalogPreferencesRepository? catalogPreferences;
  final Future<void> Function()? onUndoPlacement;
  final Future<void> Function()? onRedoPlacement;
  final bool canUndoPlacement;
  final bool canRedoPlacement;

  @override
  State<RoomEditorScreen> createState() => _RoomEditorScreenState();
}

class _RoomEditorScreenState extends State<RoomEditorScreen> {
  static const _navigationResolver = SurfaceNavigationResolver();
  static const _wideEditorBreakpoint = 900.0;
  final FocusNode _powerWorkspaceFocusNode = FocusNode(
    debugLabel: 'power-workspace',
  );
  bool powerInspectorVisible = false;

  EditorTool tool = EditorTool.select;
  Discipline discipline = Discipline.electrical;
  ArchitecturalFeatureType? featureType;
  String? activePatchId;
  EditorSelection? selection;
  Point2Mm? measurementStart;
  EditorMeasurement? measurement;
  SurfaceEdgeCandidate? navigationCandidate;
  String? currentPreviewEdgeId;
  ComponentDefinition? activeComponentDefinition;

  CanonicalProfileChoice? engineeringChoice;
  PlacementCandidateContext? candidateContext;
  Point2Mm? candidatePoint;
  bool candidateLocked = false;
  PlaceEngineeringProfileCommand? pendingEngineeringCommand;
  final engineeringOperationIds = UuidV7IdGenerator();

  void clearEngineeringPreview() {
    pendingEngineeringCommand = null;
    engineeringChoice = null;
    candidateContext = null;
    candidatePoint = null;
    candidateLocked = false;
  }

  void resetCandidate() {
    pendingEngineeringCommand = null;
    candidatePoint = null;
    candidateLocked = false;
    final patch = activePatch, choice = engineeringChoice;
    candidateContext =
        patch == null || choice == null
            ? null
            : emptyPaletteContext(
              projectId: widget.project.id,
              roomId: widget.room.id,
              surfaceId: patch.id,
              topologyShape: resolvePaletteTopology(
                choice.system,
                widget.engineeringTopologyProfiles,
              ),
            );
  }

  @override
  void didUpdateWidget(covariant RoomEditorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final choice = engineeringChoice;
    if (choice == null) return;
    if (oldWidget.project.id != widget.project.id ||
        oldWidget.room.id != widget.room.id ||
        !isCurrentPaletteChoice(
          choice,
          widget.engineeringReferences,
          widget.project.id,
        )) {
      clearEngineeringPreview();
    } else if (oldWidget.geometry != widget.geometry ||
        oldWidget.engineeringTopologyProfiles !=
            widget.engineeringTopologyProfiles) {
      resetCandidate();
    }
  }

  @override
  void dispose() {
    _powerWorkspaceFocusNode.dispose();
    super.dispose();
  }

  PlacementCompatibilityResult? get placementPreview {
    final choice = engineeringChoice, context = candidateContext;
    if (choice == null || context == null) return null;
    return const PlacementCompatibilityEngine().evaluate(
      profile: choice.profile,
      catalogId: choice.catalog.id,
      catalogVersion: choice.catalog.version,
      context: context,
    );
  }

  Future<void> openEngineeringPalette() async {
    final snapshot = widget.engineeringReferences;
    if (snapshot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.engineeringReferenceMessage ??
                'Reference catalogs are not available.',
          ),
        ),
      );
      return;
    }
    final choice = await EngineeringProfilePalette.show(
      context,
      snapshot: snapshot,
      projectId: widget.project.id,
      initialSystemId: engineeringChoice?.system.id,
    );
    if (!mounted || choice == null) return;
    if (!isCurrentPaletteChoice(
      choice,
      widget.engineeringReferences,
      widget.project.id,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The system or catalog changed. Select the profile again.',
          ),
        ),
      );
      return;
    }
    setState(() {
      engineeringChoice = choice;
      activeComponentDefinition = null;
      tool = EditorTool.equipment;
      discipline = switch (choice.profile.discipline) {
        ReferenceDiscipline.cctv => Discipline.cctv,
        ReferenceDiscipline.lan => Discipline.lowVoltage,
        ReferenceDiscipline.acs => Discipline.accessControl,
        ReferenceDiscipline.fire => Discipline.fireAlarm,
      };
      navigationCandidate = null;
      currentPreviewEdgeId = null;
      measurementStart = null;
      measurement = null;
      resetCandidate();
    });
  }

  void previewCandidate(
    SurfacePatch patch,
    Point2Mm point, {
    bool lock = false,
  }) {
    if (placingComponent || candidateLocked && !lock) return;
    final next = patch.boundary.containsPointInclusive(point) ? point : null;
    if (next == candidatePoint &&
        candidateContext?.surfaceId == patch.id &&
        (!lock || candidateLocked))
      return;
    setState(() {
      if (next != candidatePoint || candidateContext?.surfaceId != patch.id)
        resetCandidate();
      candidatePoint = next;
      candidateLocked = lock && next != null;
    });
  }

  Future<void> editCandidateConditions() async {
    if (placingComponent) return;
    final choice = engineeringChoice, initial = candidateContext;
    if (choice == null || initial == null) return;
    final value = await showDialog<PlacementCandidateContext>(
      context: context,
      builder:
          (_) => CandidateConditionsDialog(
            initial: initial,
            system: choice.system,
            topologyProfiles: widget.engineeringTopologyProfiles,
          ),
    );
    if (!mounted ||
        value == null ||
        engineeringChoice?.identity != choice.identity ||
        candidateContext?.surfaceId != value.surfaceId ||
        candidateContext != initial)
      return;
    setState(() {
      candidateContext = value;
      pendingEngineeringCommand = null;
    });
  }

  Future<void> commitEngineeringCandidate() async {
    final place = widget.onPlaceEngineeringProfile;
    final choice = engineeringChoice,
        context = candidateContext,
        point = candidatePoint;
    if (place == null ||
        choice == null ||
        context == null ||
        point == null ||
        placingComponent ||
        placementPreview?.compatible != true)
      return;
    final command =
        pendingEngineeringCommand ??= PlaceEngineeringProfileCommand(
          operationId: engineeringOperationIds.next(),
          projectId: widget.project.id,
          roomId: widget.room.id,
          systemId: choice.system.id,
          membershipRole: canonicalElvMembershipRole,
          catalogId: choice.catalog.id,
          catalogVersion: choice.catalog.version,
          profileCode: choice.profile.code,
          hostSurfacePatchId: context.surfaceId,
          localPosition: point,
          rotationRadians: 0,
          placementContext: context,
          displayNameOverride: choice.profile.label,
        );
    setState(() => placingComponent = true);
    try {
      await place(command);
      if (mounted) setState(resetCandidate);
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(this.context).showSnackBar(
          SnackBar(
            content: Text(
              error is EngineeringPlacementFailure
                  ? '${error.code.name}: ${error.message} ${error.findings.map((f) => f.explanation).join(' ')}'
                  : 'Placement failed: $error',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => placingComponent = false);
    }
  }

  Widget previewDetails() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const Text(
        'Pre-placement review',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      if (candidatePoint == null)
        const Text('Select a location to evaluate the candidate.'),
      if (candidatePoint != null && placementPreview != null)
        PlacementFindingsView(result: placementPreview!),
      if (engineeringChoice != null)
        CanonicalProfileDetails(choice: engineeringChoice!),
    ],
  );
  void openPreviewDetails() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder:
        (_) => FractionallySizedBox(
          heightFactor: .78,
          child: SafeArea(child: previewDetails()),
        ),
  );

  bool placingComponent = false;

  int get ceilingHeight =>
      widget.room.finishedCeilingHeightMmOverride ??
      widget.project.defaultFinishedCeilingHeightMm;

  SurfacePatch? get activePatch {
    if (widget.geometry.patches.isEmpty) return null;
    final requested = activePatchId;
    if (requested != null) {
      for (final patch in widget.geometry.patches) {
        if (patch.id == requested) return patch;
      }
    }
    return widget.geometry.patches.first;
  }

  SurfacePatch? get adjacentPreviewPatch {
    final adjacentId = navigationCandidate?.adjacentPatchId;
    if (adjacentId == null) return null;
    for (final patch in widget.geometry.patches) {
      if (patch.id == adjacentId) return patch;
    }
    return null;
  }

  void selectPatch(String patchId) {
    setState(() {
      activePatchId = patchId;
      resetCandidate();
      selection = null;
      measurementStart = null;
      measurement = null;
      navigationCandidate = null;
      currentPreviewEdgeId = null;
    });
  }

  void changeTool(EditorTool value) {
    if (value == EditorTool.route) {
      setState(clearEngineeringPreview);
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder:
              (_) => RoomRoutingScreen(
                roomId: widget.room.id,
                roomName: widget.room.name,
              ),
        ),
      );
      return;
    }
    setState(() {
      tool = value;
      if (value != EditorTool.architecturalFeature) {
        featureType = null;
      }
      if (value != EditorTool.measure) {
        measurementStart = null;
      }
      if (value != EditorTool.select) {
        navigationCandidate = null;
        currentPreviewEdgeId = null;
      }
      if (value != EditorTool.equipment) {
        activeComponentDefinition = null;
        clearEngineeringPreview();
      }
    });
  }

  SurfaceEdgeCandidate? _resolveNavigationCandidate(
    SurfacePatch patch,
    Point2Mm localPoint,
  ) => _navigationResolver.nearestNavigableCandidate(
    pointer: localPoint,
    activePatch: patch,
    edges: widget.geometry.edges,
    adjacencies: widget.geometry.adjacencies,
    currentPreviewEdgeId: currentPreviewEdgeId,
  );

  void handleSurfacePointer(SurfacePatch patch, Point2Mm localPoint) {
    if (tool == EditorTool.equipment && engineeringChoice != null) {
      previewCandidate(patch, localPoint);
      return;
    }
    if (tool != EditorTool.select) return;
    final candidate = _resolveNavigationCandidate(patch, localPoint);
    final keepPreview = switch (candidate?.proximity) {
      SurfaceEdgeProximity.preview ||
      SurfaceEdgeProximity.strongPreview => true,
      _ => false,
    };
    final nextPreviewId = keepPreview ? candidate?.edge.id : null;

    if (candidate?.edge.id == navigationCandidate?.edge.id &&
        candidate?.proximity == navigationCandidate?.proximity &&
        nextPreviewId == currentPreviewEdgeId) {
      return;
    }

    setState(() {
      navigationCandidate = candidate;
      currentPreviewEdgeId = nextPreviewId;
    });
  }

  bool _navigateAcrossStrongEdge(SurfacePatch patch, Point2Mm localPoint) {
    if (tool != EditorTool.select) return false;
    final candidate = _resolveNavigationCandidate(patch, localPoint);
    if (candidate?.proximity != SurfaceEdgeProximity.strongPreview) {
      return false;
    }
    final adjacentPatchId = candidate?.adjacentPatchId;
    if (adjacentPatchId == null) return false;
    selectPatch(adjacentPatchId);
    return true;
  }

  Future<void> openComponentCatalog() async {
    try {
      final repository = widget.catalogPreferences;
      final preferences =
          await repository?.load() ?? const CatalogPreferences();
      if (!mounted) return;
      final selected = await ComponentCatalogSheet.show(
        context,
        definitions: electricalSystemComponentLibrary.definitions,
        recentDefinitionIds: preferences.recentIds,
        favoriteDefinitionIds: preferences.favoriteIds,
        onSetFavorite: repository?.setFavorite,
      );
      if (selected == null || !mounted) return;
      await repository?.recordUse(selected.id);
      if (!mounted) return;
      setState(() {
        tool = EditorTool.equipment;
        activeComponentDefinition = selected;
        clearEngineeringPreview();
        navigationCandidate = null;
        currentPreviewEdgeId = null;
        measurementStart = null;
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to open catalog: $error')),
        );
      }
    }
  }

  Future<void> runHistory(Future<void> Function() operation) async {
    if (placingComponent) return;
    setState(() => placingComponent = true);
    try {
      await operation();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to change placement: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => placingComponent = false);
    }
  }

  void finishComponentPlacement() {
    setState(() {
      activeComponentDefinition = null;
      clearEngineeringPreview();
      tool = EditorTool.select;
    });
  }

  Future<void> placeActiveComponent(
    SurfacePatch patch,
    Point2Mm localPoint,
  ) async {
    final definition = activeComponentDefinition;
    final place = widget.onPlaceComponent;
    if (definition == null || place == null || placingComponent) return;

    setState(() => placingComponent = true);
    try {
      await place(definition, patch.id, localPoint);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to place component: $error')),
      );
    } finally {
      if (mounted) setState(() => placingComponent = false);
    }
  }

  Future<void> openPowerWorkspace() async {
    final binding = widget.powerWorkspace;
    if (binding == null) return;
    if (MediaQuery.sizeOf(context).width >= _wideEditorBreakpoint) {
      setState(() => powerInspectorVisible = !powerInspectorVisible);
      return;
    }
    await showPowerWorkspaceSheet(
      context: context,
      restoreFocusTo: _powerWorkspaceFocusNode,
      child: PowerWorkspacePanelHost(
        binding: binding,
        onFindingSelected: handlePowerFinding,
      ),
    );
  }

  void handlePowerFinding(PowerWorkspaceFindingProjection finding) {
    final entityId = finding.entityRef;
    if (entityId == null) return;
    ComponentInstance? component;
    for (final candidate in widget.components) {
      if (candidate.id == entityId) {
        component = candidate;
        break;
      }
    }
    if (component == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Referenced entity: $entityId')));
      return;
    }
    setState(() {
      activePatchId = component!.hostSurfacePatchId;
      selection = EditorSelection(
        kind: EditorSelectionKind.component,
        id: component.id,
        hostPatchId: component.hostSurfacePatchId,
      );
      tool = EditorTool.select;
      navigationCandidate = null;
      currentPreviewEdgeId = null;
    });
    unawaited(widget.powerWorkspace?.selectComponent(component.id));
  }

  void handleSurfaceTap(SurfacePatch patch, Point2Mm localPoint) {
    if (_navigateAcrossStrongEdge(patch, localPoint)) return;

    switch (tool) {
      case EditorTool.select:
        final nextSelection = hitTestSurface(
          geometry: widget.geometry,
          patch: patch,
          localPoint: localPoint,
          components: widget.components,
        );
        setState(() => selection = nextSelection);
        unawaited(
          widget.powerWorkspace?.selectComponent(
            nextSelection?.kind == EditorSelectionKind.component
                ? nextSelection!.id
                : null,
          ),
        );
      case EditorTool.measure:
        final start = measurementStart;
        if (start == null) {
          setState(() {
            selection = null;
            measurement = null;
            measurementStart = localPoint;
          });
          return;
        }
        if (start == localPoint) return;
        setState(() {
          measurement = EditorMeasurement(start: start, end: localPoint);
          measurementStart = null;
        });
      case EditorTool.equipment:
        if (engineeringChoice != null) {
          previewCandidate(patch, localPoint, lock: true);
        } else if (activeComponentDefinition != null) {
          unawaited(placeActiveComponent(patch, localPoint));
        }
      case EditorTool.point:
      case EditorTool.route:
      case EditorTool.architecturalFeature:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final patch = activePatch;
    final previewPatch = adjacentPreviewPatch;
    final baseInspector =
        engineeringChoice != null
            ? previewDetails()
            : _Inspector(
              project: widget.project,
              room: widget.room,
              geometry: widget.geometry,
              activePatch: patch,
              discipline: discipline,
              selection: selection,
              measurement: measurement,
              measurementStart: measurementStart,
              navigationCandidate: navigationCandidate,
              adjacentPreviewPatch: previewPatch,
              components: widget.components,
              activeComponentDefinition: activeComponentDefinition,
            );
    final inspector =
        powerInspectorVisible && widget.powerWorkspace != null
            ? PowerWorkspacePanelHost(
              binding: widget.powerWorkspace!,
              onFindingSelected: handlePowerFinding,
            )
            : baseInspector;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          patch == null
              ? widget.room.name
              : '${widget.room.name} · ${patch.surfaceId}',
        ),
        actions: [
          if (widget.powerWorkspace != null)
            IconButton(
              key: const ValueKey('power-workspace-open'),
              focusNode: _powerWorkspaceFocusNode,
              tooltip: 'Power workspace',
              icon: Icon(
                powerInspectorVisible ? Icons.bolt : Icons.bolt_outlined,
              ),
              onPressed: openPowerWorkspace,
            )
          else if (widget.powerWorkspaceError != null)
            IconButton(
              tooltip:
                  'Power workspace unavailable: ${widget.powerWorkspaceError}',
              icon: const Icon(Icons.power_off_outlined),
              onPressed: null,
            ),
          IconButton(
            tooltip: 'Undo placement',
            icon: const Icon(Icons.undo),
            onPressed:
                !placingComponent &&
                        widget.canUndoPlacement &&
                        widget.onUndoPlacement != null
                    ? () => runHistory(widget.onUndoPlacement!)
                    : null,
          ),
          IconButton(
            tooltip: 'Redo placement',
            icon: const Icon(Icons.redo),
            onPressed:
                !placingComponent &&
                        widget.canRedoPlacement &&
                        widget.onRedoPlacement != null
                    ? () => runHistory(widget.onRedoPlacement!)
                    : null,
          ),
          PopupMenuButton<String>(
            tooltip: 'Project tools',
            onSelected: (value) {
              if (value == 'routes') {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder:
                        (_) => RoomRoutingScreen(
                          roomId: widget.room.id,
                          roomName: widget.room.name,
                        ),
                  ),
                );
              } else if (value == 'circuits') {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder:
                        (_) => ElectricalCircuitsScreen(
                          roomId: widget.room.id,
                          roomName: widget.room.name,
                        ),
                  ),
                );
              } else if (value == 'loads') {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder:
                        (_) => ElectricalLoadsScreen(
                          roomId: widget.room.id,
                          roomName: widget.room.name,
                        ),
                  ),
                );
              } else if (value == 'calculations') {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder:
                        (_) => CalculationsScreen(
                          roomName: widget.room.name,
                          projectId: widget.project.id,
                        ),
                  ),
                );
              } else if (value == 'reports') {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ReportsScreen(roomName: widget.room.name),
                  ),
                );
              }
            },
            itemBuilder:
                (_) => const [
                  PopupMenuItem(value: 'routes', child: Text('Cable routing')),
                  PopupMenuItem(value: 'circuits', child: Text('Circuits')),
                  PopupMenuItem(
                    value: 'loads',
                    child: Text('Electrical loads'),
                  ),
                  PopupMenuItem(
                    value: 'calculations',
                    child: Text('Calculations'),
                  ),
                  PopupMenuItem(value: 'reports', child: Text('Reports')),
                ],
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= _wideEditorBreakpoint;
          final editor = _EditorCanvasShell(
            geometry: widget.geometry,
            activePatch: patch,
            ceilingHeightMm: ceilingHeight,
            onPatchTap: selectPatch,
            featureType: featureType,
            tool: tool,
            selection: selection,
            measurement: measurement,
            measurementStart: measurementStart,
            navigationCandidate: navigationCandidate,
            adjacentPreviewPatch: previewPatch,
            components: widget.components,
            activeComponentDefinition: activeComponentDefinition,
            placingComponent: placingComponent,
            onSurfaceTap: handleSurfaceTap,
            onSurfacePointer: handleSurfacePointer,
            engineeringFeedback:
                engineeringChoice == null
                    ? null
                    : EngineeringPlacementFeedback(
                      choice: engineeringChoice!,
                      result: placementPreview,
                      hasCandidate: candidatePoint != null,
                      onContext: editCandidateConditions,
                      onDetails: openPreviewDetails,
                      canPlace:
                          widget.onPlaceEngineeringProfile != null &&
                          placementPreview?.compatible == true &&
                          candidatePoint != null &&
                          !placingComponent,
                      isSaving: placingComponent,
                      onPlace:
                          widget.onPlaceEngineeringProfile == null
                              ? null
                              : commitEngineeringCandidate,
                    ),
            candidatePoint: candidatePoint,
            candidateStatus:
                candidatePoint == null ? null : placementPreview?.status,
            powerOverlaySegments: widget.powerOverlaySegments,
            powerOverlay: widget.powerWorkspace?.projection.overlay,
            powerOverlayMode:
                widget.powerWorkspace?.state.overlayMode ??
                PowerWorkspaceOverlayMode.none,
            selectedPowerComponentId:
                widget.powerWorkspace?.state.selectedComponentId,
          );

          return Column(
            children: [
              _EditorToolbar(
                tool: tool,
                discipline: discipline,
                onToolChanged: changeTool,
                onDisciplineChanged:
                    (value) => setState(() {
                      discipline = value;
                      clearEngineeringPreview();
                    }),
                activeComponentDefinition: activeComponentDefinition,
                onOpenComponentCatalog: openComponentCatalog,
                onOpenEngineeringPalette: openEngineeringPalette,
                engineeringProfileLabel: engineeringChoice?.profile.label,
                onFinishComponentPlacement: finishComponentPlacement,
                onFeatureChanged:
                    (value) => setState(() {
                      tool = EditorTool.architecturalFeature;
                      featureType = value;
                      measurementStart = null;
                      navigationCandidate = null;
                      currentPreviewEdgeId = null;
                    }),
              ),
              Expanded(
                child:
                    wide
                        ? Row(
                          children: [
                            Expanded(child: editor),
                            SizedBox(
                              width:
                                  powerInspectorVisible &&
                                          widget.powerWorkspace != null
                                      ? 360
                                      : 320,
                              child: inspector,
                            ),
                          ],
                        )
                        : Column(
                          children: [
                            Expanded(child: editor),
                            _CompactContextBar(
                              engineeringPreview: engineeringChoice != null,
                              tool: tool,
                              selection: selection,
                              measurement: measurement,
                              measurementStart: measurementStart,
                              navigationCandidate: navigationCandidate,
                              adjacentPreviewPatch: previewPatch,
                              activeComponentDefinition:
                                  activeComponentDefinition,
                              placingComponent: placingComponent,
                              onOpen:
                                  () => showModalBottomSheet<void>(
                                    context: context,
                                    isScrollControlled: true,
                                    builder:
                                        (_) => SafeArea(
                                          child: SizedBox(
                                            height: math.min(
                                              MediaQuery.sizeOf(
                                                    context,
                                                  ).height *
                                                  0.72,
                                              560,
                                            ),
                                            child: inspector,
                                          ),
                                        ),
                                  ),
                            ),
                          ],
                        ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EditorToolbar extends StatelessWidget {
  const _EditorToolbar({
    required this.tool,
    required this.discipline,
    required this.onToolChanged,
    required this.onDisciplineChanged,
    required this.onFeatureChanged,
    required this.activeComponentDefinition,
    required this.onOpenComponentCatalog,
    required this.onFinishComponentPlacement,
    required this.onOpenEngineeringPalette,
    this.engineeringProfileLabel,
  });

  final EditorTool tool;
  final Discipline discipline;
  final ValueChanged<EditorTool> onToolChanged;
  final ValueChanged<Discipline> onDisciplineChanged;
  final ValueChanged<ArchitecturalFeatureType> onFeatureChanged;
  final ComponentDefinition? activeComponentDefinition;
  final VoidCallback onOpenComponentCatalog;
  final VoidCallback onFinishComponentPlacement;
  final VoidCallback onOpenEngineeringPalette;
  final String? engineeringProfileLabel;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 1,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            if (tool == EditorTool.equipment) ...[
              FilledButton.tonalIcon(
                onPressed: onOpenComponentCatalog,
                icon: const Icon(Icons.widgets_outlined, size: 18),
                label: Text(
                  activeComponentDefinition?.displayName ?? 'Catalog',
                ),
              ),
              const SizedBox(width: 6),
              OutlinedButton.icon(
                onPressed: onOpenEngineeringPalette,
                icon: const Icon(Icons.schema_outlined, size: 18),
                label: Text(
                  engineeringProfileLabel == null
                      ? 'ELV profiles'
                      : 'ELV: $engineeringProfileLabel',
                ),
              ),
              if (activeComponentDefinition != null ||
                  engineeringProfileLabel != null) ...[
                const SizedBox(width: 6),
                TextButton(
                  onPressed: onFinishComponentPlacement,
                  child: const Text('Done'),
                ),
              ],
              const SizedBox(width: 12),
            ],
            for (final value in EditorTool.values)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(value.name),
                  selected: tool == value,
                  onSelected: (_) => onToolChanged(value),
                ),
              ),
            const SizedBox(width: 12),
            DropdownButton<Discipline>(
              value: discipline,
              items:
                  Discipline.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.name),
                        ),
                      )
                      .toList(),
              onChanged: (value) {
                if (value != null) onDisciplineChanged(value);
              },
            ),
            const SizedBox(width: 12),
            PopupMenuButton<ArchitecturalFeatureType>(
              tooltip: 'Add opening / feature',
              onSelected: onFeatureChanged,
              itemBuilder:
                  (_) =>
                      ArchitecturalFeatureType.values
                          .map(
                            (value) => PopupMenuItem(
                              value: value,
                              child: Text(value.name),
                            ),
                          )
                          .toList(),
              child: const Chip(
                avatar: Icon(Icons.architecture, size: 18),
                label: Text('Door / Window / Beam...'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditorCanvasShell extends StatelessWidget {
  const _EditorCanvasShell({
    required this.geometry,
    required this.activePatch,
    required this.ceilingHeightMm,
    required this.onPatchTap,
    required this.featureType,
    required this.tool,
    required this.selection,
    required this.measurement,
    required this.measurementStart,
    required this.navigationCandidate,
    required this.adjacentPreviewPatch,
    required this.components,
    required this.activeComponentDefinition,
    required this.placingComponent,
    required this.onSurfaceTap,
    required this.onSurfacePointer,
    this.engineeringFeedback,
    this.candidatePoint,
    this.candidateStatus,
    this.powerOverlaySegments = const [],
    this.powerOverlay,
    this.powerOverlayMode = PowerWorkspaceOverlayMode.none,
    this.selectedPowerComponentId,
  });

  final RoomGeometrySnapshot geometry;
  final SurfacePatch? activePatch;
  final int ceilingHeightMm;
  final ValueChanged<String> onPatchTap;
  final ArchitecturalFeatureType? featureType;
  final EditorTool tool;
  final EditorSelection? selection;
  final EditorMeasurement? measurement;
  final Point2Mm? measurementStart;
  final SurfaceEdgeCandidate? navigationCandidate;
  final SurfacePatch? adjacentPreviewPatch;
  final List<ComponentInstance> components;
  final ComponentDefinition? activeComponentDefinition;
  final bool placingComponent;
  final void Function(SurfacePatch patch, Point2Mm localPoint) onSurfaceTap;
  final void Function(SurfacePatch patch, Point2Mm localPoint) onSurfacePointer;
  final Widget? engineeringFeedback;
  final Point2Mm? candidatePoint;
  final PlacementCompatibilityStatus? candidateStatus;
  final List<PowerWorkspaceOverlaySegment> powerOverlaySegments;
  final PowerWorkspaceOverlayProjection? powerOverlay;
  final PowerWorkspaceOverlayMode powerOverlayMode;
  final String? selectedPowerComponentId;

  @override
  Widget build(BuildContext context) {
    final patch = activePatch;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Text(
            patch == null
                ? 'No persisted surface geometry · ceiling $ceilingHeightMm mm'
                : 'Active surface: ${patch.surfaceId} · ceiling $ceilingHeightMm mm',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (engineeringFeedback != null) engineeringFeedback!,
          if (tool == EditorTool.equipment &&
              activeComponentDefinition != null &&
              patch != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                placingComponent
                    ? 'Saving ${activeComponentDefinition!.displayName}…'
                    : 'Place ${activeComponentDefinition!.displayName} · tap repeatedly on ${patch.surfaceId}',
              ),
            ),
          if (featureType != null && patch != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Place feature: ${featureType!.name} on ${patch.surfaceId}',
              ),
            ),
          const SizedBox(height: 8),
          if (geometry.patches.length > 1)
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: geometry.patches.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final candidate = geometry.patches[index];
                  return ChoiceChip(
                    label: Text(candidate.surfaceId),
                    selected: candidate.id == patch?.id,
                    onSelected: (_) => onPatchTap(candidate.id),
                  );
                },
              ),
            ),
          Expanded(
            child: Card(
              clipBehavior: Clip.antiAlias,
              child:
                  patch == null
                      ? const Center(
                        child: Text(
                          'Room geometry is empty.\nCreate persisted SurfacePatch data to begin.',
                          textAlign: TextAlign.center,
                        ),
                      )
                      : LayoutBuilder(
                        builder: (context, constraints) {
                          final transform = SurfaceViewportTransform(
                            boundary: patch.boundary,
                            viewportWidth: constraints.maxWidth,
                            viewportHeight: constraints.maxHeight,
                          );

                          Point2Mm toLocal(Offset position) => transform
                              .viewportToLocal(position.dx, position.dy);

                          return InteractiveViewer(
                            minScale: 0.25,
                            maxScale: 8,
                            boundaryMargin: const EdgeInsets.all(300),
                            child: SizedBox(
                              width: constraints.maxWidth,
                              height: constraints.maxHeight,
                              child: Listener(
                                onPointerHover:
                                    (event) => onSurfacePointer(
                                      patch,
                                      toLocal(event.localPosition),
                                    ),
                                onPointerMove:
                                    (event) => onSurfacePointer(
                                      patch,
                                      toLocal(event.localPosition),
                                    ),
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTapDown:
                                      (details) => onSurfaceTap(
                                        patch,
                                        toLocal(details.localPosition),
                                      ),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      CustomPaint(
                                        painter: _RoomSurfacePainter(
                                          patch: patch,
                                          openings: geometry.openings
                                              .where(
                                                (item) =>
                                                    item.hostSurfacePatchId ==
                                                    patch.id,
                                              )
                                              .toList(growable: false),
                                          features: geometry.features
                                              .where(
                                                (item) =>
                                                    item.hostSurfacePatchId ==
                                                    patch.id,
                                              )
                                              .toList(growable: false),
                                          components: components
                                              .where(
                                                (item) =>
                                                    item.hostSurfacePatchId ==
                                                    patch.id,
                                              )
                                              .toList(growable: false),
                                          selection: selection,
                                          measurement: measurement,
                                          measurementStart: measurementStart,
                                          navigationCandidate:
                                              navigationCandidate,
                                        ),
                                      ),
                                      if (powerOverlay != null &&
                                          powerOverlayMode !=
                                              PowerWorkspaceOverlayMode.none)
                                        IgnorePointer(
                                          child: CustomPaint(
                                            painter:
                                                PowerWorkspaceOverlayPainter(
                                                  surfacePatchId: patch.id,
                                                  boundary: patch.boundary,
                                                  components: components,
                                                  segments:
                                                      powerOverlaySegments,
                                                  overlay: powerOverlay!,
                                                  mode: powerOverlayMode,
                                                  colorScheme:
                                                      Theme.of(
                                                        context,
                                                      ).colorScheme,
                                                  selectedComponentId:
                                                      selectedPowerComponentId,
                                                ),
                                          ),
                                        ),
                                      if (candidatePoint != null &&
                                          candidateStatus != null)
                                        IgnorePointer(
                                          child: CustomPaint(
                                            painter:
                                                EngineeringCandidatePainter(
                                                  patch: patch,
                                                  point: candidatePoint!,
                                                  status: candidateStatus!,
                                                ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
            ),
          ),
          if (engineeringFeedback == null)
            _ToolContextBar(
              tool: tool,
              selection: selection,
              measurement: measurement,
              measurementStart: measurementStart,
              navigationCandidate: navigationCandidate,
              adjacentPreviewPatch: adjacentPreviewPatch,
              activeComponentDefinition: activeComponentDefinition,
              placingComponent: placingComponent,
            ),
        ],
      ),
    );
  }
}

class _ToolContextBar extends StatelessWidget {
  const _ToolContextBar({
    required this.tool,
    required this.selection,
    required this.measurement,
    required this.measurementStart,
    required this.navigationCandidate,
    required this.adjacentPreviewPatch,
    required this.activeComponentDefinition,
    required this.placingComponent,
  });

  final EditorTool tool;
  final EditorSelection? selection;
  final EditorMeasurement? measurement;
  final Point2Mm? measurementStart;
  final SurfaceEdgeCandidate? navigationCandidate;
  final SurfacePatch? adjacentPreviewPatch;
  final ComponentDefinition? activeComponentDefinition;
  final bool placingComponent;

  @override
  Widget build(BuildContext context) {
    String text;
    final candidate = navigationCandidate;
    final target =
        adjacentPreviewPatch?.surfaceId ?? candidate?.adjacentPatchId;

    if (tool == EditorTool.equipment) {
      final definition = activeComponentDefinition;
      if (definition == null) {
        text = 'Equipment · open Catalog';
      } else if (placingComponent) {
        text = 'Equipment · saving ${definition.displayName}…';
      } else {
        text =
            'Equipment · ${definition.displayName} · tap to place repeatedly';
      }
    } else if (tool == EditorTool.measure) {
      if (measurementStart != null) {
        text = 'Measure · choose second point';
      } else if (measurement != null) {
        text = 'Measure · ${measurement!.lengthMm.toStringAsFixed(0)} mm';
      } else {
        text = 'Measure · choose first point';
      }
    } else if (tool == EditorTool.select && candidate != null) {
      text = switch (candidate.proximity) {
        SurfaceEdgeProximity.strongPreview => 'Open → $target · tap edge',
        SurfaceEdgeProximity.preview => 'Preview → $target',
        SurfaceEdgeProximity.highlight =>
          'Edge → $target · ${candidate.distanceMm.toStringAsFixed(0)} mm',
        SurfaceEdgeProximity.none => 'Select · tap a surface object',
      };
    } else if (tool == EditorTool.select) {
      text =
          selection == null
              ? 'Select · tap a surface object'
              : 'Selected · ${selection!.kind.name} · ${selection!.id}';
    } else {
      text = '${tool.name} · contextual actions will appear here';
    }

    return SizedBox(
      height: 44,
      child: Align(alignment: Alignment.centerLeft, child: Text(text)),
    );
  }
}

class _CompactContextBar extends StatelessWidget {
  const _CompactContextBar({
    this.engineeringPreview = false,
    required this.tool,
    required this.selection,
    required this.measurement,
    required this.measurementStart,
    required this.navigationCandidate,
    required this.adjacentPreviewPatch,
    required this.activeComponentDefinition,
    required this.placingComponent,
    required this.onOpen,
  });

  final EditorTool tool;
  final EditorSelection? selection;
  final EditorMeasurement? measurement;
  final Point2Mm? measurementStart;
  final SurfaceEdgeCandidate? navigationCandidate;
  final SurfacePatch? adjacentPreviewPatch;
  final ComponentDefinition? activeComponentDefinition;
  final bool placingComponent;
  final VoidCallback onOpen;
  final bool engineeringPreview;

  @override
  Widget build(BuildContext context) {
    final target =
        adjacentPreviewPatch?.surfaceId ?? navigationCandidate?.adjacentPatchId;
    final summary = switch (tool) {
      EditorTool.equipment when engineeringPreview => 'Pre-placement review',
      EditorTool.equipment when placingComponent => 'Saving component…',
      EditorTool.equipment when activeComponentDefinition != null =>
        'Place ${activeComponentDefinition!.displayName}',
      EditorTool.equipment => 'Equipment catalog',
      EditorTool.measure when measurementStart != null => 'Choose second point',
      EditorTool.measure when measurement != null =>
        '${measurement!.lengthMm.toStringAsFixed(0)} mm',
      EditorTool.select
          when navigationCandidate?.proximity ==
              SurfaceEdgeProximity.strongPreview =>
        'Open → $target',
      EditorTool.select
          when navigationCandidate?.proximity == SurfaceEdgeProximity.preview =>
        'Preview → $target',
      EditorTool.select when selection != null => selection!.id,
      _ => 'Context',
    };

    return Material(
      elevation: 2,
      child: InkWell(
        onTap: onOpen,
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.tune),
                const SizedBox(width: 12),
                Expanded(child: Text(summary)),
                const Icon(Icons.keyboard_arrow_up),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoomSurfacePainter extends CustomPainter {
  const _RoomSurfacePainter({
    required this.patch,
    required this.openings,
    required this.features,
    required this.components,
    required this.selection,
    required this.measurement,
    required this.measurementStart,
    required this.navigationCandidate,
  });

  final SurfacePatch patch;
  final List<Opening> openings;
  final List<SpatialFeature> features;
  final List<ComponentInstance> components;
  final EditorSelection? selection;
  final EditorMeasurement? measurement;
  final Point2Mm? measurementStart;
  final SurfaceEdgeCandidate? navigationCandidate;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint =
        Paint()
          ..color = Colors.blueGrey.withValues(alpha: 0.15)
          ..strokeWidth = 1;
    const gridStep = 32.0;
    for (double x = 0; x <= size.width; x += gridStep) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y <= size.height; y += gridStep) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final transform = SurfaceViewportTransform(
      boundary: patch.boundary,
      viewportWidth: size.width,
      viewportHeight: size.height,
    );

    Offset mapPoint(Point2Mm point) {
      final mapped = transform.localToViewport(point);
      return Offset(mapped.x, mapped.y);
    }

    Path polygonPath(Polygon2Mm polygon) {
      final path = Path();
      final first = mapPoint(polygon.vertices.first);
      path.moveTo(first.dx, first.dy);
      for (final point in polygon.vertices.skip(1)) {
        final mapped = mapPoint(point);
        path.lineTo(mapped.dx, mapped.dy);
      }
      path.close();
      return path;
    }

    final patchSelected =
        selection?.kind == EditorSelectionKind.surfacePatch &&
        selection?.id == patch.id;
    final boundaryPaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = patchSelected ? 3 : 2;
    canvas.drawPath(polygonPath(patch.boundary), boundaryPaint);

    for (final opening in openings) {
      final selected =
          selection?.kind == EditorSelectionKind.opening &&
          selection?.id == opening.id;
      final paint =
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = selected ? 3 : 1.5;
      canvas.drawPath(polygonPath(opening.boundary), paint);
    }

    for (final feature in features) {
      final selected =
          selection?.kind == EditorSelectionKind.spatialFeature &&
          selection?.id == feature.id;
      final paint =
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = selected ? 3 : 1;
      canvas.drawPath(polygonPath(feature.footprint), paint);
    }

    for (final component in components) {
      final center = mapPoint(component.localPosition);
      final selected =
          selection?.kind == EditorSelectionKind.component &&
          selection?.id == component.id;
      final paint =
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = selected ? 3 : 1.5;
      canvas.drawCircle(center, 8, paint);
      canvas.drawLine(
        center + const Offset(-6, 0),
        center + const Offset(6, 0),
        paint,
      );
      canvas.drawLine(
        center + const Offset(0, -6),
        center + const Offset(0, 6),
        paint,
      );
    }

    final candidate = navigationCandidate;
    if (candidate != null && candidate.edge.patchId == patch.id) {
      final width = switch (candidate.proximity) {
        SurfaceEdgeProximity.none => 0.0,
        SurfaceEdgeProximity.highlight => 2.0,
        SurfaceEdgeProximity.preview => 4.0,
        SurfaceEdgeProximity.strongPreview => 6.0,
      };
      if (width > 0) {
        final segment = candidate.edge.segment;
        final paint =
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = width
              ..strokeCap = StrokeCap.round;
        canvas.drawLine(mapPoint(segment.start), mapPoint(segment.end), paint);
      }
    }

    final pending = measurementStart;
    if (pending != null) {
      final point = mapPoint(pending);
      canvas.drawCircle(point, 4, Paint()..style = PaintingStyle.fill);
    }

    final completed = measurement;
    if (completed != null) {
      final start = mapPoint(completed.start);
      final end = mapPoint(completed.end);
      final paint =
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5;
      canvas.drawLine(start, end, paint);
      canvas.drawCircle(start, 4, Paint()..style = PaintingStyle.fill);
      canvas.drawCircle(end, 4, Paint()..style = PaintingStyle.fill);

      final textPainter = TextPainter(
        text: TextSpan(
          text: '${completed.lengthMm.toStringAsFixed(0)} mm',
          style: const TextStyle(fontSize: 12, color: Colors.black),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final midpoint = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
      textPainter.paint(canvas, midpoint + const Offset(6, -18));
    }
  }

  @override
  bool shouldRepaint(covariant _RoomSurfacePainter oldDelegate) =>
      oldDelegate.patch != patch ||
      oldDelegate.openings != openings ||
      oldDelegate.features != features ||
      oldDelegate.components != components ||
      oldDelegate.selection != selection ||
      oldDelegate.measurement != measurement ||
      oldDelegate.measurementStart != measurementStart ||
      oldDelegate.navigationCandidate?.edge.id !=
          navigationCandidate?.edge.id ||
      oldDelegate.navigationCandidate?.proximity !=
          navigationCandidate?.proximity;
}

class _Inspector extends StatelessWidget {
  const _Inspector({
    required this.project,
    required this.room,
    required this.geometry,
    required this.activePatch,
    required this.discipline,
    required this.selection,
    required this.measurement,
    required this.measurementStart,
    required this.navigationCandidate,
    required this.adjacentPreviewPatch,
    required this.components,
    required this.activeComponentDefinition,
  });

  final ProjectRecord project;
  final RoomRecord room;
  final RoomGeometrySnapshot geometry;
  final SurfacePatch? activePatch;
  final Discipline discipline;
  final EditorSelection? selection;
  final EditorMeasurement? measurement;
  final Point2Mm? measurementStart;
  final SurfaceEdgeCandidate? navigationCandidate;
  final SurfacePatch? adjacentPreviewPatch;
  final List<ComponentInstance> components;
  final ComponentDefinition? activeComponentDefinition;

  @override
  Widget build(BuildContext context) {
    final structural =
        room.structuralHeightMmOverride ?? project.defaultStructuralHeightMm;
    final ceiling =
        room.finishedCeilingHeightMmOverride ??
        project.defaultFinishedCeilingHeightMm;
    final selected = selection;
    final candidate = navigationCandidate;

    return Card(
      margin: const EdgeInsets.all(12),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Inspector', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Text('Room: ${room.name}'),
          Text('Type: ${room.type.name}'),
          Text('Discipline: ${discipline.name}'),
          Text('Structural height: $structural mm'),
          Text('Finished ceiling: $ceiling mm'),
          Text('Units: ${project.measurementSystem.name}'),
          const Divider(),
          Text('Patches: ${geometry.patches.length}'),
          Text('Edges: ${geometry.edges.length}'),
          Text('Openings: ${geometry.openings.length}'),
          Text('Features: ${geometry.features.length}'),
          Text('Placed components: ${components.length}'),
          if (activeComponentDefinition != null)
            Text('Placement: ${activeComponentDefinition!.displayName}'),
          if (activePatch != null) ...[
            const Divider(),
            Text('Surface: ${activePatch!.surfaceId}'),
            Text('Orientation: ${activePatch!.orientation.name}'),
            Text('Boundary vertices: ${activePatch!.boundary.vertices.length}'),
          ],
          if (candidate != null) ...[
            const Divider(),
            Text('Edge proximity: ${candidate.proximity.name}'),
            Text(
              'Edge distance: ${candidate.distanceMm.toStringAsFixed(0)} mm',
            ),
            Text(
              'Adjacent surface: ${adjacentPreviewPatch?.surfaceId ?? candidate.adjacentPatchId}',
            ),
          ],
          if (selected != null) ...[
            const Divider(),
            Text('Selected type: ${selected.kind.name}'),
            Text('Selected id: ${selected.id}'),
          ],
          if (measurementStart != null) ...[
            const Divider(),
            Text(
              'Measurement start: ${measurementStart!.xMm}, ${measurementStart!.yMm} mm',
            ),
          ],
          if (measurement != null) ...[
            const Divider(),
            Text('Measurement: ${measurement!.lengthMm.toStringAsFixed(0)} mm'),
            Text(
              'From: ${measurement!.start.xMm}, ${measurement!.start.yMm} mm',
            ),
            Text('To: ${measurement!.end.xMm}, ${measurement!.end.yMm} mm'),
          ],
        ],
      ),
    );
  }
}
