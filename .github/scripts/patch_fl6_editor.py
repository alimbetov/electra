from pathlib import Path

path = Path('apps/mobile/lib/features/editor/room_editor_screen.dart')
text = path.read_text()


def replace_once(old: str, new: str) -> None:
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(
            f'Expected exactly one anchor, found {count}: {old[:120]!r}'
        )
    text = text.replace(old, new, 1)


replace_once(
    "import 'dart:math' as math;\n",
    "import 'dart:async';\nimport 'dart:math' as math;\n",
)
replace_once(
    "import '../../domain/project_models.dart';\n",
    "import '../../domain/project_models.dart';\n"
    "import '../../domain/system_component_catalog.dart';\n",
)
replace_once(
    "import '../reports/reports_screen.dart';\nimport 'editor_interaction.dart';\n",
    "import '../reports/reports_screen.dart';\n"
    "import 'component_catalog_sheet.dart';\n"
    "import 'editor_interaction.dart';\n",
)
replace_once(
    "class RoomEditorScreen extends StatefulWidget {\n",
    "typedef ComponentPlacementCallback = Future<void> Function(\n"
    "  ComponentDefinition definition,\n"
    "  String hostSurfacePatchId,\n"
    "  Point2Mm localPosition,\n"
    ");\n\n"
    "class RoomEditorScreen extends StatefulWidget {\n",
)
replace_once(
    "    required this.geometry,\n"
    "  });\n\n"
    "  final ProjectRecord project;\n"
    "  final RoomRecord room;\n"
    "  final RoomGeometrySnapshot geometry;\n",
    "    required this.geometry,\n"
    "    this.components = const [],\n"
    "    this.onPlaceComponent,\n"
    "  });\n\n"
    "  final ProjectRecord project;\n"
    "  final RoomRecord room;\n"
    "  final RoomGeometrySnapshot geometry;\n"
    "  final List<ComponentInstance> components;\n"
    "  final ComponentPlacementCallback? onPlaceComponent;\n",
)
replace_once(
    "  SurfaceEdgeCandidate? navigationCandidate;\n"
    "  String? currentPreviewEdgeId;\n",
    "  SurfaceEdgeCandidate? navigationCandidate;\n"
    "  String? currentPreviewEdgeId;\n"
    "  ComponentDefinition? activeComponentDefinition;\n"
    "  final List<String> recentComponentDefinitionIds = [];\n"
    "  final Set<String> favoriteComponentDefinitionIds = {};\n"
    "  bool placingComponent = false;\n",
)
replace_once(
    "      if (value != EditorTool.select) {\n"
    "        navigationCandidate = null;\n"
    "        currentPreviewEdgeId = null;\n"
    "      }\n",
    "      if (value != EditorTool.select) {\n"
    "        navigationCandidate = null;\n"
    "        currentPreviewEdgeId = null;\n"
    "      }\n"
    "      if (value != EditorTool.equipment) {\n"
    "        activeComponentDefinition = null;\n"
    "      }\n",
)

methods = '''  Future<void> openComponentCatalog() async {
    final selected = await ComponentCatalogSheet.show(
      context,
      definitions: electricalSystemComponentLibrary.definitions,
      recentDefinitionIds: recentComponentDefinitionIds,
      favoriteDefinitionIds: favoriteComponentDefinitionIds,
    );
    if (selected == null || !mounted) return;
    setState(() {
      tool = EditorTool.equipment;
      activeComponentDefinition = selected;
      recentComponentDefinitionIds
        ..remove(selected.id)
        ..insert(0, selected.id);
      if (recentComponentDefinitionIds.length > 8) {
        recentComponentDefinitionIds.removeRange(
          8,
          recentComponentDefinitionIds.length,
        );
      }
      navigationCandidate = null;
      currentPreviewEdgeId = null;
      measurementStart = null;
    });
  }

  void finishComponentPlacement() {
    setState(() {
      activeComponentDefinition = null;
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

'''
replace_once(
    "  void handleSurfaceTap(SurfacePatch patch, Point2Mm localPoint) {\n",
    methods + "  void handleSurfaceTap(SurfacePatch patch, Point2Mm localPoint) {\n",
)
replace_once(
    "      case EditorTool.point:\n"
    "      case EditorTool.equipment:\n"
    "      case EditorTool.route:\n",
    "      case EditorTool.equipment:\n"
    "        if (activeComponentDefinition != null) {\n"
    "          unawaited(placeActiveComponent(patch, localPoint));\n"
    "        }\n"
    "      case EditorTool.point:\n"
    "      case EditorTool.route:\n",
)
replace_once(
    "      navigationCandidate: navigationCandidate,\n"
    "      adjacentPreviewPatch: previewPatch,\n"
    "    );\n",
    "      navigationCandidate: navigationCandidate,\n"
    "      adjacentPreviewPatch: previewPatch,\n"
    "      components: widget.components,\n"
    "      activeComponentDefinition: activeComponentDefinition,\n"
    "    );\n",
)
replace_once(
    "            adjacentPreviewPatch: previewPatch,\n"
    "            onSurfaceTap: handleSurfaceTap,\n",
    "            adjacentPreviewPatch: previewPatch,\n"
    "            components: widget.components,\n"
    "            activeComponentDefinition: activeComponentDefinition,\n"
    "            placingComponent: placingComponent,\n"
    "            onSurfaceTap: handleSurfaceTap,\n",
)
replace_once(
    "                onFeatureChanged:\n"
    "                    (value) => setState(() {\n",
    "                activeComponentDefinition: activeComponentDefinition,\n"
    "                onOpenComponentCatalog: openComponentCatalog,\n"
    "                onFinishComponentPlacement: finishComponentPlacement,\n"
    "                onFeatureChanged:\n"
    "                    (value) => setState(() {\n",
)
replace_once(
    "                              adjacentPreviewPatch: previewPatch,\n"
    "                              onOpen:\n",
    "                              adjacentPreviewPatch: previewPatch,\n"
    "                              activeComponentDefinition: activeComponentDefinition,\n"
    "                              placingComponent: placingComponent,\n"
    "                              onOpen:\n",
)
replace_once(
    "    required this.onDisciplineChanged,\n"
    "    required this.onFeatureChanged,\n"
    "  });\n\n"
    "  final EditorTool tool;\n"
    "  final Discipline discipline;\n"
    "  final ValueChanged<EditorTool> onToolChanged;\n"
    "  final ValueChanged<Discipline> onDisciplineChanged;\n"
    "  final ValueChanged<ArchitecturalFeatureType> onFeatureChanged;\n",
    "    required this.onDisciplineChanged,\n"
    "    required this.onFeatureChanged,\n"
    "    required this.activeComponentDefinition,\n"
    "    required this.onOpenComponentCatalog,\n"
    "    required this.onFinishComponentPlacement,\n"
    "  });\n\n"
    "  final EditorTool tool;\n"
    "  final Discipline discipline;\n"
    "  final ValueChanged<EditorTool> onToolChanged;\n"
    "  final ValueChanged<Discipline> onDisciplineChanged;\n"
    "  final ValueChanged<ArchitecturalFeatureType> onFeatureChanged;\n"
    "  final ComponentDefinition? activeComponentDefinition;\n"
    "  final VoidCallback onOpenComponentCatalog;\n"
    "  final VoidCallback onFinishComponentPlacement;\n",
)
replace_once(
    "            PopupMenuButton<ArchitecturalFeatureType>(\n",
    "            if (tool == EditorTool.equipment) ...[\n"
    "              FilledButton.tonalIcon(\n"
    "                onPressed: onOpenComponentCatalog,\n"
    "                icon: const Icon(Icons.widgets_outlined, size: 18),\n"
    "                label: Text(\n"
    "                  activeComponentDefinition?.displayName ?? 'Catalog',\n"
    "                ),\n"
    "              ),\n"
    "              if (activeComponentDefinition != null) ...[\n"
    "                const SizedBox(width: 6),\n"
    "                TextButton(\n"
    "                  onPressed: onFinishComponentPlacement,\n"
    "                  child: const Text('Done'),\n"
    "                ),\n"
    "              ],\n"
    "              const SizedBox(width: 12),\n"
    "            ],\n"
    "            PopupMenuButton<ArchitecturalFeatureType>(\n",
)
replace_once(
    "    required this.adjacentPreviewPatch,\n"
    "    required this.onSurfaceTap,\n",
    "    required this.adjacentPreviewPatch,\n"
    "    required this.components,\n"
    "    required this.activeComponentDefinition,\n"
    "    required this.placingComponent,\n"
    "    required this.onSurfaceTap,\n",
)
replace_once(
    "  final SurfacePatch? adjacentPreviewPatch;\n"
    "  final void Function(SurfacePatch patch, Point2Mm localPoint) onSurfaceTap;\n",
    "  final SurfacePatch? adjacentPreviewPatch;\n"
    "  final List<ComponentInstance> components;\n"
    "  final ComponentDefinition? activeComponentDefinition;\n"
    "  final bool placingComponent;\n"
    "  final void Function(SurfacePatch patch, Point2Mm localPoint) onSurfaceTap;\n",
)
replace_once(
    "          if (featureType != null && patch != null)\n"
    "            Padding(\n",
    "          if (tool == EditorTool.equipment &&\n"
    "              activeComponentDefinition != null &&\n"
    "              patch != null)\n"
    "            Padding(\n"
    "              padding: const EdgeInsets.only(top: 6),\n"
    "              child: Text(\n"
    "                placingComponent\n"
    "                    ? 'Saving ${activeComponentDefinition!.displayName}…'\n"
    "                    : 'Place ${activeComponentDefinition!.displayName} · tap repeatedly on ${patch.surfaceId}',\n"
    "              ),\n"
    "            ),\n"
    "          if (featureType != null && patch != null)\n"
    "            Padding(\n",
)
replace_once(
    "                                      features: geometry.features\n"
    "                                          .where(\n"
    "                                            (item) =>\n"
    "                                                item.hostSurfacePatchId ==\n"
    "                                                patch.id,\n"
    "                                          )\n"
    "                                          .toList(growable: false),\n"
    "                                      selection: selection,\n",
    "                                      features: geometry.features\n"
    "                                          .where(\n"
    "                                            (item) =>\n"
    "                                                item.hostSurfacePatchId ==\n"
    "                                                patch.id,\n"
    "                                          )\n"
    "                                          .toList(growable: false),\n"
    "                                      components: components\n"
    "                                          .where(\n"
    "                                            (item) =>\n"
    "                                                item.hostSurfacePatchId ==\n"
    "                                                patch.id,\n"
    "                                          )\n"
    "                                          .toList(growable: false),\n"
    "                                      selection: selection,\n",
)
replace_once(
    "            adjacentPreviewPatch: adjacentPreviewPatch,\n"
    "          ),\n",
    "            adjacentPreviewPatch: adjacentPreviewPatch,\n"
    "            activeComponentDefinition: activeComponentDefinition,\n"
    "            placingComponent: placingComponent,\n"
    "          ),\n",
)
replace_once(
    "    required this.adjacentPreviewPatch,\n"
    "  });\n\n"
    "  final EditorTool tool;\n",
    "    required this.adjacentPreviewPatch,\n"
    "    required this.activeComponentDefinition,\n"
    "    required this.placingComponent,\n"
    "  });\n\n"
    "  final EditorTool tool;\n",
)
replace_once(
    "  final SurfacePatch? adjacentPreviewPatch;\n\n"
    "  @override\n"
    "  Widget build(BuildContext context) {\n",
    "  final SurfacePatch? adjacentPreviewPatch;\n"
    "  final ComponentDefinition? activeComponentDefinition;\n"
    "  final bool placingComponent;\n\n"
    "  @override\n"
    "  Widget build(BuildContext context) {\n",
)
replace_once(
    "    if (tool == EditorTool.measure) {\n",
    "    if (tool == EditorTool.equipment) {\n"
    "      final definition = activeComponentDefinition;\n"
    "      if (definition == null) {\n"
    "        text = 'Equipment · open Catalog';\n"
    "      } else if (placingComponent) {\n"
    "        text = 'Equipment · saving ${definition.displayName}…';\n"
    "      } else {\n"
    "        text = 'Equipment · ${definition.displayName} · tap to place repeatedly';\n"
    "      }\n"
    "    } else if (tool == EditorTool.measure) {\n",
)
replace_once(
    "    required this.adjacentPreviewPatch,\n"
    "    required this.onOpen,\n",
    "    required this.adjacentPreviewPatch,\n"
    "    required this.activeComponentDefinition,\n"
    "    required this.placingComponent,\n"
    "    required this.onOpen,\n",
)
replace_once(
    "  final SurfacePatch? adjacentPreviewPatch;\n"
    "  final VoidCallback onOpen;\n",
    "  final SurfacePatch? adjacentPreviewPatch;\n"
    "  final ComponentDefinition? activeComponentDefinition;\n"
    "  final bool placingComponent;\n"
    "  final VoidCallback onOpen;\n",
)
replace_once(
    "    final summary = switch (tool) {\n",
    "    final summary = switch (tool) {\n"
    "      EditorTool.equipment when placingComponent => 'Saving component…',\n"
    "      EditorTool.equipment when activeComponentDefinition != null =>\n"
    "        'Place ${activeComponentDefinition!.displayName}',\n"
    "      EditorTool.equipment => 'Equipment catalog',\n",
)
replace_once(
    "    required this.features,\n"
    "    required this.selection,\n",
    "    required this.features,\n"
    "    required this.components,\n"
    "    required this.selection,\n",
)
replace_once(
    "  final List<SpatialFeature> features;\n"
    "  final EditorSelection? selection;\n",
    "  final List<SpatialFeature> features;\n"
    "  final List<ComponentInstance> components;\n"
    "  final EditorSelection? selection;\n",
)
replace_once(
    "    final candidate = navigationCandidate;\n",
    "    for (final component in components) {\n"
    "      final center = mapPoint(component.localPosition);\n"
    "      final paint =\n"
    "          Paint()\n"
    "            ..style = PaintingStyle.stroke\n"
    "            ..strokeWidth = 1.5;\n"
    "      canvas.drawCircle(center, 8, paint);\n"
    "      canvas.drawLine(\n"
    "        center + const Offset(-6, 0),\n"
    "        center + const Offset(6, 0),\n"
    "        paint,\n"
    "      );\n"
    "      canvas.drawLine(\n"
    "        center + const Offset(0, -6),\n"
    "        center + const Offset(0, 6),\n"
    "        paint,\n"
    "      );\n"
    "    }\n\n"
    "    final candidate = navigationCandidate;\n",
)
replace_once(
    "      oldDelegate.features != features ||\n"
    "      oldDelegate.selection != selection ||\n",
    "      oldDelegate.features != features ||\n"
    "      oldDelegate.components != components ||\n"
    "      oldDelegate.selection != selection ||\n",
)
replace_once(
    "    required this.adjacentPreviewPatch,\n"
    "  });\n\n"
    "  final ProjectRecord project;\n",
    "    required this.adjacentPreviewPatch,\n"
    "    required this.components,\n"
    "    required this.activeComponentDefinition,\n"
    "  });\n\n"
    "  final ProjectRecord project;\n",
)
replace_once(
    "  final SurfacePatch? adjacentPreviewPatch;\n\n"
    "  @override\n"
    "  Widget build(BuildContext context) {\n"
    "    final structural =\n",
    "  final SurfacePatch? adjacentPreviewPatch;\n"
    "  final List<ComponentInstance> components;\n"
    "  final ComponentDefinition? activeComponentDefinition;\n\n"
    "  @override\n"
    "  Widget build(BuildContext context) {\n"
    "    final structural =\n",
)
replace_once(
    "          Text('Features: ${geometry.features.length}'),\n",
    "          Text('Features: ${geometry.features.length}'),\n"
    "          Text('Placed components: ${components.length}'),\n"
    "          if (activeComponentDefinition != null)\n"
    "            Text('Placement: ${activeComponentDefinition!.displayName}'),\n",
)

path.write_text(text)
