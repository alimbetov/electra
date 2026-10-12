import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../application/geometry_repository.dart';
import '../../domain/models.dart';
import '../../domain/project_models.dart';
import '../calculations/calculations_screen.dart';
import '../reports/reports_screen.dart';
import 'editor_interaction.dart';

class RoomEditorScreen extends StatefulWidget {
  const RoomEditorScreen({
    super.key,
    required this.project,
    required this.room,
    required this.geometry,
  });

  final ProjectRecord project;
  final RoomRecord room;
  final RoomGeometrySnapshot geometry;

  @override
  State<RoomEditorScreen> createState() => _RoomEditorScreenState();
}

class _RoomEditorScreenState extends State<RoomEditorScreen> {
  EditorTool tool = EditorTool.select;
  Discipline discipline = Discipline.electrical;
  ArchitecturalFeatureType? featureType;
  String? activePatchId;
  EditorSelection? selection;
  Point2Mm? measurementStart;
  EditorMeasurement? measurement;

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

  void selectPatch(String patchId) {
    setState(() {
      activePatchId = patchId;
      selection = null;
      measurementStart = null;
      measurement = null;
    });
  }

  void changeTool(EditorTool value) {
    setState(() {
      tool = value;
      if (value != EditorTool.architecturalFeature) {
        featureType = null;
      }
      if (value != EditorTool.measure) {
        measurementStart = null;
      }
    });
  }

  void handleSurfaceTap(SurfacePatch patch, Point2Mm localPoint) {
    switch (tool) {
      case EditorTool.select:
        setState(() {
          selection = hitTestSurface(
            geometry: widget.geometry,
            patch: patch,
            localPoint: localPoint,
          );
        });
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
      case EditorTool.point:
      case EditorTool.equipment:
      case EditorTool.route:
      case EditorTool.architecturalFeature:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final patch = activePatch;
    final inspector = _Inspector(
      project: widget.project,
      room: widget.room,
      geometry: widget.geometry,
      activePatch: patch,
      discipline: discipline,
      selection: selection,
      measurement: measurement,
      measurementStart: measurementStart,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          patch == null
              ? widget.room.name
              : '${widget.room.name} · ${patch.surfaceId}',
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Project tools',
            onSelected: (value) {
              if (value == 'calculations') {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder:
                        (_) => CalculationsScreen(roomName: widget.room.name),
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
          final wide = constraints.maxWidth >= 900;
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
            onSurfaceTap: handleSurfaceTap,
          );

          return Column(
            children: [
              _EditorToolbar(
                tool: tool,
                discipline: discipline,
                onToolChanged: changeTool,
                onDisciplineChanged:
                    (value) => setState(() => discipline = value),
                onFeatureChanged:
                    (value) => setState(() {
                      tool = EditorTool.architecturalFeature;
                      featureType = value;
                      measurementStart = null;
                    }),
              ),
              Expanded(
                child:
                    wide
                        ? Row(
                          children: [
                            Expanded(child: editor),
                            SizedBox(width: 320, child: inspector),
                          ],
                        )
                        : Column(
                          children: [
                            Expanded(child: editor),
                            _CompactContextBar(
                              tool: tool,
                              selection: selection,
                              measurement: measurement,
                              measurementStart: measurementStart,
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
  });

  final EditorTool tool;
  final Discipline discipline;
  final ValueChanged<EditorTool> onToolChanged;
  final ValueChanged<Discipline> onDisciplineChanged;
  final ValueChanged<ArchitecturalFeatureType> onFeatureChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 1,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
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
    required this.onSurfaceTap,
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
  final void Function(SurfacePatch patch, Point2Mm localPoint) onSurfaceTap;

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
                          return InteractiveViewer(
                            minScale: 0.25,
                            maxScale: 8,
                            boundaryMargin: const EdgeInsets.all(300),
                            child: SizedBox(
                              width: constraints.maxWidth,
                              height: constraints.maxHeight,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTapDown: (details) {
                                  final local = transform.viewportToLocal(
                                    details.localPosition.dx,
                                    details.localPosition.dy,
                                  );
                                  onSurfaceTap(patch, local);
                                },
                                child: CustomPaint(
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
                                    selection: selection,
                                    measurement: measurement,
                                    measurementStart: measurementStart,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
            ),
          ),
          _ToolContextBar(
            tool: tool,
            selection: selection,
            measurement: measurement,
            measurementStart: measurementStart,
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
  });

  final EditorTool tool;
  final EditorSelection? selection;
  final EditorMeasurement? measurement;
  final Point2Mm? measurementStart;

  @override
  Widget build(BuildContext context) {
    String text;
    if (tool == EditorTool.measure) {
      if (measurementStart != null) {
        text = 'Measure · choose second point';
      } else if (measurement != null) {
        text = 'Measure · ${measurement!.lengthMm.toStringAsFixed(0)} mm';
      } else {
        text = 'Measure · choose first point';
      }
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
    required this.tool,
    required this.selection,
    required this.measurement,
    required this.measurementStart,
    required this.onOpen,
  });

  final EditorTool tool;
  final EditorSelection? selection;
  final EditorMeasurement? measurement;
  final Point2Mm? measurementStart;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final summary = switch (tool) {
      EditorTool.measure when measurementStart != null => 'Choose second point',
      EditorTool.measure when measurement != null =>
        '${measurement!.lengthMm.toStringAsFixed(0)} mm',
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
    required this.selection,
    required this.measurement,
    required this.measurementStart,
  });

  final SurfacePatch patch;
  final List<Opening> openings;
  final List<SpatialFeature> features;
  final EditorSelection? selection;
  final EditorMeasurement? measurement;
  final Point2Mm? measurementStart;

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
      oldDelegate.selection != selection ||
      oldDelegate.measurement != measurement ||
      oldDelegate.measurementStart != measurementStart;
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
  });

  final ProjectRecord project;
  final RoomRecord room;
  final RoomGeometrySnapshot geometry;
  final SurfacePatch? activePatch;
  final Discipline discipline;
  final EditorSelection? selection;
  final EditorMeasurement? measurement;
  final Point2Mm? measurementStart;

  @override
  Widget build(BuildContext context) {
    final structural =
        room.structuralHeightMmOverride ?? project.defaultStructuralHeightMm;
    final ceiling =
        room.finishedCeilingHeightMmOverride ??
        project.defaultFinishedCeilingHeightMm;
    final selected = selection;

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
          if (activePatch != null) ...[
            const Divider(),
            Text('Surface: ${activePatch!.surfaceId}'),
            Text('Orientation: ${activePatch!.orientation.name}'),
            Text('Boundary vertices: ${activePatch!.boundary.vertices.length}'),
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
