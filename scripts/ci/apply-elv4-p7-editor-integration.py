from pathlib import Path

path = Path('apps/mobile/lib/features/editor/room_editor_screen.dart')
text = path.read_text()

import_anchor = "import '../../application/catalog_preferences_repository.dart';\n"
imports = """import '../../application/power_workspace_overlay_geometry.dart';
import '../../application/power_workspace_projection.dart';
import '../../application/power_workspace_state.dart';
"""
if imports not in text:
    if import_anchor not in text:
        raise SystemExit('power import anchor missing')
    text = text.replace(import_anchor, import_anchor + imports, 1)

feature_anchor = "import 'room_routing_screen.dart';\n"
feature_imports = """import 'power_workspace_editor_binding.dart';
import 'power_workspace_overlay_painter.dart';
import 'power_workspace_panel.dart';
import 'power_workspace_panel_host.dart';
"""
if feature_imports not in text:
    if feature_anchor not in text:
        raise SystemExit('feature import anchor missing')
    text = text.replace(feature_anchor, feature_imports + feature_anchor, 1)

ctor_anchor = """    this.components = const [],
    this.engineeringReferences,
"""
ctor_replacement = """    this.components = const [],
    this.powerWorkspace,
    this.powerOverlaySegments = const [],
    this.powerWorkspaceError,
    this.engineeringReferences,
"""
if ctor_anchor in text:
    text = text.replace(ctor_anchor, ctor_replacement, 1)
elif 'this.powerWorkspace,' not in text:
    raise SystemExit('RoomEditorScreen constructor anchor missing')

field_anchor = """  final List<ComponentInstance> components;
  final ProjectEngineeringReferences? engineeringReferences;
"""
field_replacement = """  final List<ComponentInstance> components;
  final PowerWorkspaceEditorBinding? powerWorkspace;
  final List<PowerWorkspaceOverlaySegment> powerOverlaySegments;
  final Object? powerWorkspaceError;
  final ProjectEngineeringReferences? engineeringReferences;
"""
if field_anchor in text:
    text = text.replace(field_anchor, field_replacement, 1)
elif 'final PowerWorkspaceEditorBinding? powerWorkspace;' not in text:
    raise SystemExit('RoomEditorScreen field anchor missing')

state_anchor = """class _RoomEditorScreenState extends State<RoomEditorScreen> {
  static const _navigationResolver = SurfaceNavigationResolver();

"""
state_replacement = """class _RoomEditorScreenState extends State<RoomEditorScreen> {
  static const _navigationResolver = SurfaceNavigationResolver();
  static const _wideEditorBreakpoint = 900.0;
  final FocusNode _powerWorkspaceFocusNode = FocusNode(
    debugLabel: 'power-workspace',
  );
  bool powerInspectorVisible = false;

"""
if state_anchor in text:
    text = text.replace(state_anchor, state_replacement, 1)
elif '_wideEditorBreakpoint' not in text:
    raise SystemExit('RoomEditorScreen state anchor missing')

dispose_anchor = """  PlacementCompatibilityResult? get placementPreview {
"""
dispose_block = """  @override
  void dispose() {
    _powerWorkspaceFocusNode.dispose();
    super.dispose();
  }

  PlacementCompatibilityResult? get placementPreview {
"""
if dispose_anchor in text and '_powerWorkspaceFocusNode.dispose();' not in text:
    text = text.replace(dispose_anchor, dispose_block, 1)

tap_anchor = """  void handleSurfaceTap(SurfacePatch patch, Point2Mm localPoint) {
"""
helper_block = """  Future<void> openPowerWorkspace() async {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Referenced entity: $entityId')),
      );
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
"""
if tap_anchor in text and 'Future<void> openPowerWorkspace()' not in text:
    text = text.replace(tap_anchor, helper_block, 1)

old_select = """      case EditorTool.select:
        setState(() {
          selection = hitTestSurface(
            geometry: widget.geometry,
            patch: patch,
            localPoint: localPoint,
          );
        });
"""
new_select = """      case EditorTool.select:
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
"""
if old_select in text:
    text = text.replace(old_select, new_select, 1)
elif 'components: widget.components,' not in text:
    raise SystemExit('component selection integration anchor missing')

inspector_anchor = """    final inspector =
        engineeringChoice != null
            ? previewDetails()
            : _Inspector(
"""
inspector_replacement = """    final baseInspector =
        engineeringChoice != null
            ? previewDetails()
            : _Inspector(
"""
if inspector_anchor in text:
    text = text.replace(inspector_anchor, inspector_replacement, 1)

inspector_end_anchor = """              activeComponentDefinition: activeComponentDefinition,
            );

    return Scaffold(
"""
inspector_end_replacement = """              activeComponentDefinition: activeComponentDefinition,
            );
    final inspector =
        powerInspectorVisible && widget.powerWorkspace != null
            ? PowerWorkspacePanelHost(
              binding: widget.powerWorkspace!,
              onFindingSelected: handlePowerFinding,
            )
            : baseInspector;

    return Scaffold(
"""
if inspector_end_anchor in text:
    text = text.replace(inspector_end_anchor, inspector_end_replacement, 1)
elif 'final baseInspector' in text and 'powerInspectorVisible && widget.powerWorkspace != null' not in text:
    raise SystemExit('power inspector integration anchor missing')

actions_anchor = """        actions: [
          IconButton(
            tooltip: 'Undo placement',
"""
actions_replacement = """        actions: [
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
              tooltip: 'Power workspace unavailable: ${widget.powerWorkspaceError}',
              icon: const Icon(Icons.power_off_outlined),
              onPressed: null,
            ),
          IconButton(
            tooltip: 'Undo placement',
"""
if actions_anchor in text:
    text = text.replace(actions_anchor, actions_replacement, 1)
elif "ValueKey('power-workspace-open')" not in text:
    raise SystemExit('power app bar action anchor missing')

text = text.replace(
    'final wide = constraints.maxWidth >= 900;',
    'final wide = constraints.maxWidth >= _wideEditorBreakpoint;',
    1,
)

canvas_anchor = """            candidateStatus:
                candidatePoint == null ? null : placementPreview?.status,
          );
"""
canvas_replacement = """            candidateStatus:
                candidatePoint == null ? null : placementPreview?.status,
            powerOverlaySegments: widget.powerOverlaySegments,
            powerOverlay: widget.powerWorkspace?.projection.overlay,
            powerOverlayMode:
                widget.powerWorkspace?.state.overlayMode ??
                PowerWorkspaceOverlayMode.none,
            selectedPowerComponentId:
                widget.powerWorkspace?.state.selectedComponentId,
          );
"""
if canvas_anchor in text:
    text = text.replace(canvas_anchor, canvas_replacement, 1)
elif 'powerOverlaySegments: widget.powerOverlaySegments' not in text:
    raise SystemExit('power canvas argument anchor missing')

if 'SizedBox(width: 320, child: inspector),' in text:
    text = text.replace(
        'SizedBox(width: 320, child: inspector),',
        """SizedBox(
                              width:
                                  powerInspectorVisible &&
                                          widget.powerWorkspace != null
                                      ? 360
                                      : 320,
                              child: inspector,
                            ),""",
        1,
    )

shell_ctor_anchor = """    this.engineeringFeedback,
    this.candidatePoint,
    this.candidateStatus,
  });
"""
shell_ctor_replacement = """    this.engineeringFeedback,
    this.candidatePoint,
    this.candidateStatus,
    this.powerOverlaySegments = const [],
    this.powerOverlay,
    this.powerOverlayMode = PowerWorkspaceOverlayMode.none,
    this.selectedPowerComponentId,
  });
"""
if shell_ctor_anchor in text:
    text = text.replace(shell_ctor_anchor, shell_ctor_replacement, 1)
elif 'this.powerOverlaySegments = const []' not in text:
    raise SystemExit('editor shell constructor anchor missing')

shell_fields_anchor = """  final PlacementCompatibilityStatus? candidateStatus;

  @override
"""
shell_fields_replacement = """  final PlacementCompatibilityStatus? candidateStatus;
  final List<PowerWorkspaceOverlaySegment> powerOverlaySegments;
  final PowerWorkspaceOverlayProjection? powerOverlay;
  final PowerWorkspaceOverlayMode powerOverlayMode;
  final String? selectedPowerComponentId;

  @override
"""
if shell_fields_anchor in text:
    text = text.replace(shell_fields_anchor, shell_fields_replacement, 1)
elif 'final List<PowerWorkspaceOverlaySegment> powerOverlaySegments;' not in text:
    raise SystemExit('editor shell field anchor missing')

old_custom_paint = """                                  child: CustomPaint(
                                    foregroundPainter:
                                        candidatePoint == null ||
                                                candidateStatus == null
                                            ? null
                                            : EngineeringCandidatePainter(
                                              patch: patch,
                                              point: candidatePoint!,
                                              status: candidateStatus!,
                                            ),
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
                                      navigationCandidate: navigationCandidate,
                                    ),
                                  ),
"""
new_custom_paint = """                                  child: Stack(
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
                                          navigationCandidate: navigationCandidate,
                                        ),
                                      ),
                                      if (powerOverlay != null &&
                                          powerOverlayMode !=
                                              PowerWorkspaceOverlayMode.none)
                                        IgnorePointer(
                                          child: CustomPaint(
                                            painter: PowerWorkspaceOverlayPainter(
                                              surfacePatchId: patch.id,
                                              boundary: patch.boundary,
                                              components: components,
                                              segments: powerOverlaySegments,
                                              overlay: powerOverlay!,
                                              mode: powerOverlayMode,
                                              colorScheme:
                                                  Theme.of(context).colorScheme,
                                              selectedComponentId:
                                                  selectedPowerComponentId,
                                            ),
                                          ),
                                        ),
                                      if (candidatePoint != null &&
                                          candidateStatus != null)
                                        IgnorePointer(
                                          child: CustomPaint(
                                            painter: EngineeringCandidatePainter(
                                              patch: patch,
                                              point: candidatePoint!,
                                              status: candidateStatus!,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
"""
if old_custom_paint in text:
    text = text.replace(old_custom_paint, new_custom_paint, 1)
elif 'PowerWorkspaceOverlayPainter(' not in text:
    raise SystemExit('canvas integration anchor missing')

old_component_paint = """    for (final component in components) {
      final center = mapPoint(component.localPosition);
      final paint =
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5;
"""
new_component_paint = """    for (final component in components) {
      final center = mapPoint(component.localPosition);
      final selected =
          selection?.kind == EditorSelectionKind.component &&
          selection?.id == component.id;
      final paint =
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = selected ? 3 : 1.5;
"""
if old_component_paint in text:
    text = text.replace(old_component_paint, new_component_paint, 1)

path.write_text(text)
