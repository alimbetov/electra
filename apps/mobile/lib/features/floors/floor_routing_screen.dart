import 'dart:math' as math;

import 'package:engineering_core/engineering_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../application/floor_routing_repository.dart';
import '../editor/room_routing_screen.dart';
import '../editor/junction_editor.dart';

class FloorRoutingScreen extends ConsumerWidget {
  const FloorRoutingScreen({
    super.key,
    required this.projectId,
    required this.floorId,
  });
  final String projectId, floorId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(floorRoutingProvider(floorId))
      .when(
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (error, _) => Scaffold(
          appBar: AppBar(title: const Text('Floor routing')),
          body: Center(child: Text('Unable to load floor routing: $error')),
        ),
        data: (snapshot) {
          if (snapshot.floor == null || snapshot.project?.id != projectId) {
            return Scaffold(
              appBar: AppBar(title: const Text('Floor routing')),
              body: const Center(child: Text('Floor/project is unavailable.')),
            );
          }
          final repository = ref.read(floorRoutingRepositoryProvider);
          final contextName =
              '${snapshot.project!.name} · ${snapshot.floor!.name}';
          void openRun(CableRun run) {
            final room = snapshot.rooms.firstWhere((r) => r.id == run.roomId);
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => RoomRoutingScreen(
                  roomId: room.id,
                  roomName: '$contextName · ${room.name}',
                  initialRunId: run.id,
                ),
              ),
            );
          }

          return Scaffold(
            appBar: AppBar(title: Text('$contextName · Routing')),
            body: FloorRoutingWorkspace(
              snapshot: snapshot,
              nextId: ref.read(idGeneratorProvider).next,
              onSavePanel: repository.savePanel,
              onSaveHandoff: repository.saveHandoff,
              onDeletePanel: repository.deletePanel,
              onDeleteHandoff: repository.deleteHandoff,
              onOpenRun: openRun,
              onOpenJunction: (junction) {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (detailContext) => JunctionEditor(
                      snapshot: snapshot.routing[junction.roomId]!,
                      id: junction.id,
                      junction: junction,
                      onSave: ref
                          .read(cableRoutingRepositoryProvider)
                          .saveJunction,
                      onOpenRun: (run) {
                        Navigator.of(detailContext).pop();
                        openRun(run);
                      },
                    ),
                  ),
                );
              },
            ),
          );
        },
      );
}

class FloorRoutingWorkspace extends StatefulWidget {
  const FloorRoutingWorkspace({
    super.key,
    required this.snapshot,
    required this.nextId,
    required this.onSavePanel,
    required this.onSaveHandoff,
    required this.onDeletePanel,
    required this.onDeleteHandoff,
    required this.onOpenRun,
    required this.onOpenJunction,
  });
  final FloorRoutingSnapshot snapshot;
  final String Function() nextId;
  final Future<void> Function(FloorRoutingPanel) onSavePanel;
  final Future<void> Function(FloorRoutingHandoff) onSaveHandoff;
  final Future<void> Function(String) onDeletePanel, onDeleteHandoff;
  final ValueChanged<CableRun> onOpenRun;
  final ValueChanged<RoutingJunction> onOpenJunction;
  @override
  State<FloorRoutingWorkspace> createState() => _FloorRoutingWorkspaceState();
}

class _FloorRoutingWorkspaceState extends State<FloorRoutingWorkspace> {
  FloorGraphMode mode = FloorGraphMode.overview;
  FloorTraceDirection direction = FloorTraceDirection.upstream;
  String? selectedRunId, selectedPanelId, channelId;
  Future<void> panel([FloorRoutingPanel? existing]) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _PanelEditor(
            snapshot: widget.snapshot,
            id: existing?.id ?? widget.nextId(),
            panel: existing,
            onSave: widget.onSavePanel,
          ),
        ),
      );
  Future<void> handoff([FloorRoutingHandoff? existing]) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _HandoffEditor(
            snapshot: widget.snapshot,
            id: existing?.id ?? widget.nextId(),
            handoff: existing,
            onSave: widget.onSaveHandoff,
          ),
        ),
      );
  Future<void> remove(Future<void> Function(String) action, String id) async {
    try {
      await action(id);
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.snapshot, graph = snapshot.graph();
    final traces = <FloorRoutingTrace>[];
    if (selectedRunId != null)
      traces.add(graph.trace(selectedRunId!, direction));
    final source = graph.panels
        .where((p) => p.id == selectedPanelId)
        .firstOrNull;
    if (source != null) {
      for (final feed in source.feeds)
        traces.add(graph.trace(feed.runId, FloorTraceDirection.downstream));
    }
    final highlighted = traces.expand((t) => t.runIds).toSet();
    var visible = mode == FloorGraphMode.branch && source != null
        ? highlighted
        : graph.visibleRuns(mode, selectedRunId: selectedRunId);
    if (channelId != null) {
      visible = visible
          .where(
            (id) => graph.runs[id]!.route.segments.any(
              (s) => s.physicalChannelId == channelId,
            ),
          )
          .toSet();
    }
    final selected = graph.runs[selectedRunId];
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Text(
          'Logical floor topology · physical handoffs add no measured length',
        ),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => panel(),
              icon: const Icon(Icons.electrical_services),
              label: const Text('Add source panel'),
            ),
            OutlinedButton.icon(
              onPressed: graph.runs.length < 2 ? null : () => handoff(),
              icon: const Icon(Icons.route),
              label: const Text('Add room handoff'),
            ),
          ],
        ),
        DropdownButtonFormField<FloorGraphMode>(
          key: ValueKey(mode),
          initialValue: mode,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Display mode'),
          items: FloorGraphMode.values
              .map((m) => DropdownMenuItem(value: m, child: Text(m.name)))
              .toList(),
          onChanged: (value) => setState(() => mode = value!),
        ),
        Wrap(
          spacing: 8,
          children: [
            for (final d in FloorTraceDirection.values)
              ChoiceChip(
                label: Text(d.name),
                selected: direction == d,
                onSelected: (_) => setState(() {
                  direction = d;
                  selectedPanelId = null;
                }),
              ),
            TextButton(
              onPressed: () => setState(() {
                selectedRunId = null;
                selectedPanelId = null;
                channelId = null;
                mode = FloorGraphMode.overview;
              }),
              child: const Text('Clear selection'),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          children: [
            for (final room in snapshot.routing.values)
              for (final channel in room.channels)
                FilterChip(
                  label: Text(
                    '${graph.roomNames[channel.roomId]} · ${channel.name}',
                  ),
                  selected: channelId == channel.id,
                  onSelected: (value) =>
                      setState(() => channelId = value ? channel.id : null),
                ),
          ],
        ),
        if (graph.runs.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No CableRun on this floor. Create routes in a room first.',
            ),
          ),
        if (mode == FloorGraphMode.branch &&
            selectedRunId == null &&
            source == null)
          const Text('Select a run or source panel to inspect its branch.'),
        SizedBox(
          height: 360,
          child: _FloorTopology(
            graph: graph,
            visible: visible,
            highlighted: highlighted,
            onRun: (id) => setState(() {
              selectedRunId = id;
              selectedPanelId = null;
            }),
            onPanel: (id) => setState(() {
              selectedPanelId = id;
              selectedRunId = null;
              direction = FloorTraceDirection.downstream;
            }),
          ),
        ),
        if (selectedRunId != null && selected == null)
          const Text(
            'Selected run is unavailable. Clear selection to continue.',
          ),
        if (selected != null)
          Card(
            child: ListTile(
              title: Text(selected.run.name),
              subtitle: Text(
                '${graph.roomNames[selected.run.roomId]} · circuit ${selected.run.circuitId}',
              ),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => widget.onOpenRun(selected.run),
            ),
          ),
        if (traces.isNotEmpty) ...[
          Text(
            'Trace: ${highlighted.length} runs · ${traces.expand((t) => t.panelIds).toSet().length} source panels',
          ),
          for (final issue in traces.expand((t) => t.issues).toSet())
            Text(issue, style: const TextStyle(color: Colors.red)),
          for (final edge in traces.expand((t) => t.edges).toSet())
            Text(
              '${edge.from} → ${edge.label} → ${edge.to}${edge.physical ? " · physical transport" : " · electrical junction"}',
            ),
        ] else
          for (final issue in graph.issues.entries)
            Text(
              '${issue.key}: ${issue.value.join(" ")}',
              style: const TextStyle(color: Colors.red),
            ),
        const Divider(),
        const Text('Source panels'),
        for (final p in graph.panels)
          ListTile(
            title: Text('${p.code} · ${p.name}'),
            subtitle: Text('${p.feeds.length} outgoing feeds'),
            onTap: () => setState(() {
              selectedPanelId = p.id;
              selectedRunId = null;
              direction = FloorTraceDirection.downstream;
            }),
            trailing: Wrap(
              children: [
                IconButton(
                  tooltip: 'Edit panel',
                  onPressed: () => panel(p),
                  icon: const Icon(Icons.edit),
                ),
                IconButton(
                  tooltip: 'Remove panel',
                  onPressed: () => remove(widget.onDeletePanel, p.id),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
        const Text('Physical room handoffs'),
        for (final h in graph.handoffs)
          ListTile(
            title: Text(h.name),
            subtitle: Text('${h.fromRunId} → ${h.toRunId}'),
            onTap: () => handoff(h),
            trailing: IconButton(
              tooltip: 'Remove handoff',
              onPressed: () => remove(widget.onDeleteHandoff, h.id),
              icon: const Icon(Icons.delete_outline),
            ),
          ),
        const Text('Rooms and runs'),
        for (final room in snapshot.rooms)
          ExpansionTile(
            title: Text(room.name),
            children: [
              for (final r in graph.runs.values.where(
                (r) => r.run.roomId == room.id && visible.contains(r.run.id),
              ))
                ListTile(
                  title: Text(r.run.name),
                  subtitle: Text(
                    '${r.route.name} · ${r.ready ? "Ready" : "Review required"}',
                  ),
                  selected: highlighted.contains(r.run.id),
                  onTap: () => setState(() {
                    selectedRunId = r.run.id;
                    selectedPanelId = null;
                  }),
                  trailing: IconButton(
                    tooltip: 'Open room route',
                    onPressed: () => widget.onOpenRun(r.run),
                    icon: const Icon(Icons.open_in_new),
                  ),
                ),
              for (final j
                  in snapshot.routing[room.id]?.junctions ??
                      <RoutingJunction>[])
                ListTile(
                  leading: const Icon(Icons.account_tree),
                  title: Text(j.code),
                  subtitle: Text(
                    '${j.incoming.length} in → ${j.outgoing.length} out',
                  ),
                  onTap: () => widget.onOpenJunction(j),
                ),
            ],
          ),
      ],
    );
  }
}

class _FloorTopology extends StatelessWidget {
  const _FloorTopology({
    required this.graph,
    required this.visible,
    required this.highlighted,
    required this.onRun,
    required this.onPanel,
  });
  final FloorRoutingGraph graph;
  final Set<String> visible, highlighted;
  final ValueChanged<String> onRun, onPanel;
  @override
  Widget build(BuildContext context) {
    final positions = <String, Offset>{};
    var height = 360.0;
    final rooms = graph.roomNames.keys.toList()..sort();
    for (var column = 0; column < rooms.length; column++) {
      final runs =
          graph.runs.values
              .where(
                (r) =>
                    r.run.roomId == rooms[column] && visible.contains(r.run.id),
              )
              .toList()
            ..sort((a, b) => a.run.id.compareTo(b.run.id));
      for (var row = 0; row < runs.length; row++) {
        positions['run:${runs[row].run.id}'] = Offset(
          340.0 + column * 250,
          80.0 + row * 95,
        );
      }
      height = math.max(height, 130.0 + runs.length * 95);
    }
    for (var i = 0; i < graph.panels.length; i++) {
      positions['panel:${graph.panels[i].id}'] = Offset(100, 80.0 + i * 95);
    }
    height = math.max(height, 130.0 + graph.panels.length * 95);
    final width = math.max(600.0, 250.0 + rooms.length * 250);
    return InteractiveViewer(
      constrained: false,
      minScale: 0.25,
      maxScale: 3,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (tap) {
          for (final entry in positions.entries) {
            if (Rect.fromCenter(
              center: entry.value,
              width: 210,
              height: 62,
            ).contains(tap.localPosition)) {
              if (entry.key.startsWith('run:'))
                onRun(entry.key.substring(4));
              else
                onPanel(entry.key.substring(6));
              return;
            }
          }
        },
        child: CustomPaint(
          size: Size(width, height),
          painter: _FloorTopologyPainter(graph, positions, highlighted),
        ),
      ),
    );
  }
}

class _FloorTopologyPainter extends CustomPainter {
  _FloorTopologyPainter(this.graph, this.positions, this.highlighted);
  final FloorRoutingGraph graph;
  final Map<String, Offset> positions;
  final Set<String> highlighted;
  void text(Canvas canvas, String value, Offset point, {double width = 210}) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: const TextStyle(color: Colors.black, fontSize: 12),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 3,
      ellipsis: '…',
    )..layout(maxWidth: width);
    painter.paint(canvas, point);
  }

  void arrow(Canvas canvas, Offset a, Offset b, bool physical) {
    final paint = Paint()
      ..color = physical ? Colors.blueGrey : Colors.indigo
      ..strokeWidth = 2;
    canvas.drawLine(a, b, paint);
    final angle = math.atan2(b.dy - a.dy, b.dx - a.dx);
    for (final offset in [-0.5, 0.5]) {
      canvas.drawLine(
        b,
        b -
            Offset(
              math.cos(angle + offset) * 12,
              math.sin(angle + offset) * 12,
            ),
        paint,
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final edge in graph.edges) {
      final from = positions['run:${edge.from}'],
          to = positions['run:${edge.to}'];
      if (from != null && to != null) {
        arrow(
          canvas,
          from + const Offset(100, 0),
          to - const Offset(100, 0),
          edge.physical,
        );
        text(
          canvas,
          edge.label,
          Offset((from.dx + to.dx) / 2, (from.dy + to.dy) / 2 - 20),
          width: 120,
        );
      }
    }
    for (final panel in graph.panels) {
      final from = positions['panel:${panel.id}']!;
      for (final feed in panel.feeds) {
        final to = positions['run:${feed.runId}'];
        if (to != null && !graph.issues.containsKey('panel:${panel.id}'))
          arrow(
            canvas,
            from + const Offset(100, 0),
            to - const Offset(100, 0),
            false,
          );
      }
    }
    for (final entry in positions.entries) {
      final run = entry.key.startsWith('run:')
          ? graph.runs[entry.key.substring(4)]
          : null;
      final invalid = graph.issues.containsKey(entry.key);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: entry.value, width: 210, height: 62),
          const Radius.circular(5),
        ),
        Paint()
          ..color = invalid
              ? Colors.red.shade100
              : run != null && highlighted.contains(run.run.id)
              ? Colors.lightBlue.shade100
              : Colors.grey.shade100,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: entry.value, width: 210, height: 62),
          const Radius.circular(5),
        ),
        Paint()
          ..color = Colors.blueGrey
          ..style = PaintingStyle.stroke,
      );
      final label = run == null
          ? graph.panels.firstWhere((p) => entry.key == 'panel:${p.id}').code
          : '${graph.roomNames[run.run.roomId]} · ${run.run.name}\n${run.run.circuitId} · ${run.ready ? "Ready" : "Review"}';
      text(canvas, label, entry.value - const Offset(98, 24), width: 195);
    }
  }

  @override
  bool shouldRepaint(covariant _FloorTopologyPainter oldDelegate) => true;
}

class _PanelEditor extends StatefulWidget {
  const _PanelEditor({
    required this.snapshot,
    required this.id,
    required this.onSave,
    this.panel,
  });
  final FloorRoutingSnapshot snapshot;
  final String id;
  final FloorRoutingPanel? panel;
  final Future<void> Function(FloorRoutingPanel) onSave;
  @override
  State<_PanelEditor> createState() => _PanelEditorState();
}

class _PanelEditorState extends State<_PanelEditor> {
  late final TextEditingController code, name;
  final Set<String> feeds = {};
  bool saving = false;
  String? error;
  @override
  void initState() {
    super.initState();
    code = TextEditingController(text: widget.panel?.code ?? '');
    name = TextEditingController(text: widget.panel?.name ?? '');
    feeds.addAll(widget.panel?.feeds.map((f) => f.runId) ?? []);
  }

  @override
  void dispose() {
    code.dispose();
    name.dispose();
    super.dispose();
  }

  Future<void> save() async {
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final graph = widget.snapshot.graph();
      final panel = FloorRoutingPanel(
        id: widget.id,
        floorId: widget.snapshot.floor!.id,
        code: code.text.trim(),
        name: name.text.trim(),
        feeds: feeds.map((id) {
          final run = graph.runs[id];
          if (run == null) throw StateError('Remove unavailable feeds.');
          return FloorPanelFeed(
            runId: id,
            endpointSignature: run.endpointSignature(start: true),
          );
        }).toList(),
      );
      await widget.onSave(panel);
      if (mounted) Navigator.pop(context);
    } catch (failure) {
      if (mounted) setState(() => error = '$failure');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final graph = widget.snapshot.graph();
    return Scaffold(
      appBar: AppBar(title: const Text('Source panel')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: code,
            enabled: !saving,
            decoration: const InputDecoration(labelText: 'Panel code'),
          ),
          TextField(
            controller: name,
            enabled: !saving,
            decoration: const InputDecoration(labelText: 'Panel name'),
          ),
          const Text(
            'Select outgoing feeds. This declares source ownership; panel sizing is a later step.',
          ),
          for (final id in feeds.where((id) => !graph.runs.containsKey(id)))
            ListTile(
              title: Text('Unavailable: $id'),
              trailing: IconButton(
                onPressed: saving
                    ? null
                    : () => setState(() => feeds.remove(id)),
                icon: const Icon(Icons.link_off),
              ),
            ),
          for (final r in graph.runs.values)
            CheckboxListTile(
              title: Text('${graph.roomNames[r.run.roomId]} · ${r.run.name}'),
              subtitle: Text('Circuit ${r.run.circuitId}'),
              value: feeds.contains(r.run.id),
              onChanged: saving
                  ? null
                  : (value) => setState(() {
                      if (value!)
                        feeds.add(r.run.id);
                      else
                        feeds.remove(r.run.id);
                    }),
            ),
          if (error != null)
            Text(error!, style: const TextStyle(color: Colors.red)),
          FilledButton(
            onPressed: saving ? null : save,
            child: const Text('Save panel'),
          ),
        ],
      ),
    );
  }
}

class _HandoffEditor extends StatefulWidget {
  const _HandoffEditor({
    required this.snapshot,
    required this.id,
    required this.onSave,
    this.handoff,
  });
  final FloorRoutingSnapshot snapshot;
  final String id;
  final FloorRoutingHandoff? handoff;
  final Future<void> Function(FloorRoutingHandoff) onSave;
  @override
  State<_HandoffEditor> createState() => _HandoffEditorState();
}

class _HandoffEditorState extends State<_HandoffEditor> {
  late final TextEditingController name;
  String? fromId, toId, error;
  bool saving = false;
  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.handoff?.name ?? '');
    fromId = widget.handoff?.fromRunId;
    toId = widget.handoff?.toRunId;
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> save() async {
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final graph = widget.snapshot.graph(),
          from = widget.snapshot.graph().runs[fromId],
          to = widget.snapshot.graph().runs[toId];
      if (from == null || to == null) throw StateError('Choose both runs.');
      final h = FloorRoutingHandoff(
        id: widget.id,
        floorId: widget.snapshot.floor!.id,
        name: name.text.trim(),
        fromRunId: from.run.id,
        toRunId: to.run.id,
        fromSignature: from.endpointSignature(start: false),
        toSignature: to.endpointSignature(start: true),
      );
      final issues = graph.handoffIssues(h);
      if (issues.isNotEmpty) throw StateError(issues.join(' '));
      await widget.onSave(h);
      if (mounted) Navigator.pop(context);
    } catch (failure) {
      if (mounted) setState(() => error = '$failure');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final graph = widget.snapshot.graph();
    return Scaffold(
      appBar: AppBar(title: const Text('Physical room handoff')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: name,
            enabled: !saving,
            decoration: const InputDecoration(labelText: 'Handoff name'),
          ),
          const Text(
            'Declared transport continuity between rooms on this floor. End → start, matching tray/conduit. No electrical splice or measured inter-room length is inferred.',
          ),
          for (final incoming in [true, false])
            DropdownButtonFormField<String>(
              initialValue: graph.runs.containsKey(incoming ? fromId : toId)
                  ? incoming
                        ? fromId
                        : toId
                  : null,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: incoming ? 'From run end' : 'To run start',
              ),
              items: graph.runs.values
                  .map(
                    (r) => DropdownMenuItem(
                      value: r.run.id,
                      child: Text(
                        '${graph.roomNames[r.run.roomId]} · ${r.run.name}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: saving
                  ? null
                  : (value) => setState(() {
                      if (incoming)
                        fromId = value;
                      else
                        toId = value;
                    }),
            ),
          if (error != null)
            Text(error!, style: const TextStyle(color: Colors.red)),
          FilledButton(
            onPressed: saving ? null : save,
            child: const Text('Save handoff'),
          ),
        ],
      ),
    );
  }
}
