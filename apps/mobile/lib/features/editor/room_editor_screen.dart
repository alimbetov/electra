import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../calculations/calculations_screen.dart';
import '../reports/reports_screen.dart';

class RoomEditorScreen extends StatefulWidget {
  const RoomEditorScreen({
    super.key,
    required this.project,
    required this.room,
  });

  final ProjectDraft project;
  final RoomDraft room;

  @override
  State<RoomEditorScreen> createState() => _RoomEditorScreenState();
}

class _RoomEditorScreenState extends State<RoomEditorScreen> {
  EditorTool tool = EditorTool.select;
  Discipline discipline = Discipline.electrical;
  ArchitecturalFeatureType? featureType;
  String activeSurface = 'Wall A';

  int get ceilingHeight => widget.room.finishedCeilingHeightMmOverride ??
      widget.project.defaultFinishedCeilingHeightMm;

  void switchSurface(String surface) {
    setState(() => activeSurface = surface);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.room.name} · $activeSurface'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Project tools',
            onSelected: (value) {
              if (value == 'calculations') {
                Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => CalculationsScreen(roomName: widget.room.name),
                ));
              } else if (value == 'reports') {
                Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => ReportsScreen(roomName: widget.room.name),
                ));
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'calculations', child: Text('Calculations')),
              PopupMenuItem(value: 'reports', child: Text('Reports')),
            ],
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          final editor = _EditorCanvasShell(
            room: widget.room,
            activeSurface: activeSurface,
            ceilingHeightMm: ceilingHeight,
            onSurfaceTap: switchSurface,
            featureType: featureType,
          );
          final inspector = _Inspector(
            project: widget.project,
            room: widget.room,
            activeSurface: activeSurface,
            discipline: discipline,
          );

          return Column(
            children: [
              _EditorToolbar(
                tool: tool,
                discipline: discipline,
                onToolChanged: (value) => setState(() {
                  tool = value;
                  if (value != EditorTool.architecturalFeature) featureType = null;
                }),
                onDisciplineChanged: (value) => setState(() => discipline = value),
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
                          SizedBox(width: 300, child: inspector),
                        ],
                      )
                    : Column(
                        children: [
                          Expanded(child: editor),
                          SizedBox(height: 190, child: inspector),
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
                  .map((value) => DropdownMenuItem(
                        value: value,
                        child: Text(value.name),
                      ))
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
                  .map((value) => PopupMenuItem(
                        value: value,
                        child: Text(value.name),
                      ))
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
    required this.room,
    required this.activeSurface,
    required this.ceilingHeightMm,
    required this.onSurfaceTap,
    required this.featureType,
  });

  final RoomDraft room;
  final String activeSurface;
  final int ceilingHeightMm;
  final ValueChanged<String> onSurfaceTap;
  final ArchitecturalFeatureType? featureType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Text(
            'Active surface: $activeSurface · ceiling $ceilingHeightMm mm',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (featureType != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Place feature: ${featureType!.name} on $activeSurface'),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              children: [
                _EdgeButton(label: 'Wall D', icon: Icons.chevron_left, onTap: () => onSurfaceTap('Wall D')),
                Expanded(
                  child: Column(
                    children: [
                      _EdgeButton(label: 'Ceiling', icon: Icons.keyboard_arrow_up, onTap: () => onSurfaceTap('Ceiling')),
                      Expanded(
                        child: Card(
                          clipBehavior: Clip.antiAlias,
                          child: CustomPaint(
                            painter: _RoomSurfacePainter(),
                            child: const Center(
                              child: Text(
                                'Surface canvas foundation\nCustomPainter + edge proximity follows next',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ),
                      _EdgeButton(label: 'Floor', icon: Icons.keyboard_arrow_down, onTap: () => onSurfaceTap('Floor')),
                    ],
                  ),
                ),
                _EdgeButton(label: 'Wall B', icon: Icons.chevron_right, onTap: () => onSurfaceTap('Wall B')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EdgeButton extends StatelessWidget {
  const _EdgeButton({required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [Icon(icon), Text(label, style: const TextStyle(fontSize: 11))],
          ),
        ),
      ),
    );
  }
}

class _RoomSurfacePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blueGrey.withValues(alpha: 0.25)
      ..strokeWidth = 1;
    const step = 32.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RoomSurfacePainter oldDelegate) => false;
}

class _Inspector extends StatelessWidget {
  const _Inspector({
    required this.project,
    required this.room,
    required this.activeSurface,
    required this.discipline,
  });

  final ProjectDraft project;
  final RoomDraft room;
  final String activeSurface;
  final Discipline discipline;

  @override
  Widget build(BuildContext context) {
    final structural = room.structuralHeightMmOverride ?? project.defaultStructuralHeightMm;
    final ceiling = room.finishedCeilingHeightMmOverride ?? project.defaultFinishedCeilingHeightMm;
    return Card(
      margin: const EdgeInsets.all(12),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Inspector', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Text('Room: ${room.name}'),
          Text('Type: ${room.type.name}'),
          Text('Surface: $activeSurface'),
          Text('Discipline: ${discipline.name}'),
          Text('Structural height: $structural mm'),
          Text('Finished ceiling: $ceiling mm'),
          Text('Units: ${project.measurementSystem.name}'),
          const SizedBox(height: 12),
          const Text('Object inspector fields will appear here after selection.'),
        ],
      ),
    );
  }
}
