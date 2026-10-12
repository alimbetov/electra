import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../application/geometry_repository.dart';
import '../../domain/models.dart';
import '../../domain/project_models.dart';
import '../calculations/calculations_screen.dart';
import '../reports/reports_screen.dart';

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
    setState(() => activePatchId = patchId);
  }

  @override
  Widget build(BuildContext context) {
    final patch = activePatch;
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
                    builder: (_) => CalculationsScreen(roomName: widget.room.name),
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
            itemBuilder: (_) => const [
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
          );
          final inspector = _Inspector(
            project: widget.project,
            room: widget.room,
            geometry: widget.geometry,
            activePatch: patch,
            discipline: discipline,
          );

          return Column(
            children: [
              _EditorToolbar(
                tool: tool,
                discipline: discipline,
                onToolChanged: (value) => setState(() {
                  tool = value;
                  if (value != EditorTool.architecturalFeature) {
                    featureType = null;
                  }
                }),
                onDisciplineChanged: (value) =>
                    setState(() => discipline = value),
                onFeatureChanged: (value) => setState(() {
                  tool = EditorTool.architecturalFeature;
                  featureType = value;
                }),
              ),
              Expanded(
                child: wide
                    ? Row(
                        children: [
                          Expanded(child: editor),
                          SizedBox(width: 320, child: inspector),
                        ],
                      )
                    : Column(
                        children: [
                          Expanded(child: editor),
                          SizedBox(height: 210, child: inspector),
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
              items: Discipline.values
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
              itemBuilder: (_) => ArchitecturalFeatureType.values
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
  });

  final RoomGeometrySnapshot geometry;
  final SurfacePatch? activePatch;
  final int ceilingHeightMm;
  final ValueChanged<String> onPatchTap;
  final ArchitecturalFeatureType? featureType;

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
              child: patch == null
                  ? const Center(
                      child: Text(
                        'Room geometry is empty.\nCreate persisted SurfacePatch data to begin.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : InteractiveViewer(
                      minScale: 0.25,
                      maxScale: 8,
                      boundaryMargin: const EdgeInsets.all(300),
                      child: CustomPaint(
                        painter: _RoomSurfacePainter(
                          patch: patch,
                          openings: geometry.openings
                              .where(
                                (item) => item.hostSurfacePatchId == patch.id,
                              )
                              .toList(growable: false),
                          features: geometry.features
                              .where(
                                (item) => item.hostSurfacePatchId == patch.id,
                              )
                              .toList(growable: false),
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomSurfacePainter extends CustomPainter {
  const _RoomSurfacePainter({
    required this.patch,
    required this.openings,
    required this.features,
  });

  final SurfacePatch patch;
  final List<Opening> openings;
  final List<SpatialFeature> features;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.blueGrey.withValues(alpha: 0.15)
      ..strokeWidth = 1;
    const gridStep = 32.0;
    for (double x = 0; x <= size.width; x += gridStep) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y <= size.height; y += gridStep) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final vertices = patch.boundary.vertices;
    final minX = vertices.map((p) => p.xMm).reduce(math.min).toDouble();
    final maxX = vertices.map((p) => p.xMm).reduce(math.max).toDouble();
    final minY = vertices.map((p) => p.yMm).reduce(math.min).toDouble();
    final maxY = vertices.map((p) => p.yMm).reduce(math.max).toDouble();
    final widthMm = math.max(1.0, maxX - minX);
    final heightMm = math.max(1.0, maxY - minY);
    final scale = math.min(
      (size.width - 48) / widthMm,
      (size.height - 48) / heightMm,
    );
    final origin = Offset(
      (size.width - widthMm * scale) / 2 - minX * scale,
      (size.height - heightMm * scale) / 2 + maxY * scale,
    );

    Offset mapPoint(Point2Mm point) => Offset(
          origin.dx + point.xMm * scale,
          origin.dy - point.yMm * scale,
        );

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

    final boundaryPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(polygonPath(patch.boundary), boundaryPaint);

    final openingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final opening in openings) {
      canvas.drawPath(polygonPath(opening.boundary), openingPaint);
    }

    final featurePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final feature in features) {
      canvas.drawPath(polygonPath(feature.footprint), featurePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RoomSurfacePainter oldDelegate) =>
      oldDelegate.patch != patch ||
      oldDelegate.openings != openings ||
      oldDelegate.features != features;
}

class _Inspector extends StatelessWidget {
  const _Inspector({
    required this.project,
    required this.room,
    required this.geometry,
    required this.activePatch,
    required this.discipline,
  });

  final ProjectRecord project;
  final RoomRecord room;
  final RoomGeometrySnapshot geometry;
  final SurfacePatch? activePatch;
  final Discipline discipline;

  @override
  Widget build(BuildContext context) {
    final structural =
        room.structuralHeightMmOverride ?? project.defaultStructuralHeightMm;
    final ceiling =
        room.finishedCeilingHeightMmOverride ??
        project.defaultFinishedCeilingHeightMm;
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
            Text(
              'Boundary vertices: ${activePatch!.boundary.vertices.length}',
            ),
          ],
        ],
      ),
    );
  }
}
