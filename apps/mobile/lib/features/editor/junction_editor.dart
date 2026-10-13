import 'package:engineering_core/engineering_core.dart';
import 'package:flutter/material.dart';
import '../../application/cable_routing_repository.dart';

/// Placement is anchored to a selected incoming endpoint, never a freehand crossing.
class JunctionEditor extends StatefulWidget {
  const JunctionEditor({
    super.key,
    required this.snapshot,
    required this.id,
    required this.onSave,
    this.junction,
    required this.onOpenRun,
  });
  final RoomRoutingSnapshot snapshot;
  final String id;
  final RoutingJunction? junction;
  final Future<void> Function(RoutingJunction) onSave;
  final void Function(CableRun) onOpenRun;
  @override
  State<JunctionEditor> createState() => _JunctionEditorState();
}

class _JunctionEditorState extends State<JunctionEditor> {
  late final TextEditingController code;
  late final TextEditingController notes;
  late RoutingJunctionType kind;
  final Map<String, RoutingConnectionDirection> selected = {};
  bool saving = false;
  String? error;
  @override
  void initState() {
    super.initState();
    code = TextEditingController(text: widget.junction?.code ?? '');
    notes = TextEditingController(text: widget.junction?.notes ?? '');
    kind = widget.junction?.type ?? RoutingJunctionType.junctionBox;
    for (final c
        in widget.junction?.connections ?? <RoutingJunctionConnection>[]) {
      selected[c.runId] = c.direction;
    }
  }

  @override
  void dispose() {
    code.dispose();
    notes.dispose();
    super.dispose();
  }

  RoutingJunction? buildJunction() {
    final incoming =
        selected.entries
            .where((e) => e.value == RoutingConnectionDirection.incoming)
            .firstOrNull;
    final run =
        widget.snapshot.runs.where((r) => r.id == incoming?.key).firstOrNull;
    final route =
        widget.snapshot.routes.where((r) => r.id == run?.routeId).firstOrNull;
    if (route == null || route.nodes.isEmpty) return null;
    final node = route.nodes.last;
    return RoutingJunction(
      id: widget.id,
      code: code.text.trim(),
      type: kind,
      roomId: run!.roomId,
      surfacePatchId: node.anchor.patchId,
      localPosition: node.anchor.localPosition,
      xMm: node.worldPosition.xMm,
      yMm: node.worldPosition.yMm,
      zMm: node.worldPosition.zMm,
      notes: notes.text,
      connections: selected.entries
          .map((entry) {
            final r = widget.snapshot.runs.firstWhere((r) => r.id == entry.key);
            final path = widget.snapshot.routes.firstWhere(
              (path) => path.id == r.routeId,
            );
            final incoming = entry.value == RoutingConnectionDirection.incoming;
            return RoutingJunctionConnection(
              runId: r.id,
              direction: entry.value,
              nodeId: (incoming ? path.nodes.last : path.nodes.first).id,
              circuitOrNetworkId: r.circuitId,
              physicalChannelId:
                  (incoming ? path.segments.last : path.segments.first)
                      .physicalChannelId,
            );
          })
          .toList(growable: false),
    );
  }

  Future<void> save() async {
    try {
      final junction = buildJunction();
      if (junction == null) throw StateError('Choose an incoming run.');
      final issues = widget.snapshot.junctionIssues(junction);
      if (issues.isNotEmpty) throw StateError(issues.join(' '));
      setState(() {
        saving = true;
        error = null;
      });
      await widget.onSave(junction);
      if (mounted) Navigator.pop(context);
    } catch (failure) {
      if (mounted) setState(() => error = '$failure');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.junction?.code ?? 'New junction')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: code,
          enabled: !saving,
          decoration: const InputDecoration(labelText: 'Junction code'),
        ),
        DropdownButtonFormField<RoutingJunctionType>(
          initialValue: kind,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Junction type'),
          items:
              RoutingJunctionType.values
                  .map((t) => DropdownMenuItem(value: t, child: Text(t.name)))
                  .toList(),
          onChanged: saving ? null : (value) => setState(() => kind = value!),
        ),
        TextField(
          controller: notes,
          enabled: !saving,
          decoration: const InputDecoration(labelText: 'Installation notes'),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Text(
            'Incoming: route end → junction. Outgoing: junction → route start. All endpoints must coincide on the same surface.',
          ),
        ),
        if (widget.junction != null) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Branch schematic'),
                  for (final c in widget.junction!.incoming)
                    Text(
                      '${c.runId} → ${widget.junction!.code} · ${c.circuitOrNetworkId ?? "unassigned"}',
                    ),
                  for (final c in widget.junction!.outgoing)
                    Text(
                      '${widget.junction!.code} → ${c.runId} · ${c.circuitOrNetworkId ?? "unassigned"}',
                    ),
                ],
              ),
            ),
          ),

          Text(
            'Surface: ${widget.junction!.surfacePatchId} · ${widget.junction!.xMm}, ${widget.junction!.yMm}, ${widget.junction!.zMm} mm',
          ),
          for (final issue in widget.snapshot.junctionIssues(widget.junction!))
            Text(issue, style: const TextStyle(color: Colors.red)),
        ],
        for (final id in selected.keys.where(
          (id) => !widget.snapshot.runs.any((run) => run.id == id),
        ))
          ListTile(
            title: Text('Missing run: $id'),
            trailing: IconButton(
              tooltip: 'Remove missing connection',
              onPressed:
                  saving ? null : () => setState(() => selected.remove(id)),
              icon: const Icon(Icons.link_off),
            ),
          ),
        for (final run in widget.snapshot.runs)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${run.name} · circuit ${run.circuitId}'),
                  Text(
                    'Route ${run.routeId} · ${widget.snapshot.cableLength(run)?.toStringAsFixed(0) ?? "review"} mm',
                  ),
                  DropdownButtonFormField<String>(
                    key: ValueKey('${run.id}-${selected[run.id]}'),
                    initialValue: selected[run.id]?.name ?? 'none',
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(
                        value: 'none',
                        child: Text('Not connected'),
                      ),
                      DropdownMenuItem(
                        value: 'incoming',
                        child: Text('Incoming → junction'),
                      ),
                      DropdownMenuItem(
                        value: 'outgoing',
                        child: Text('Outgoing ← junction'),
                      ),
                    ],
                    onChanged:
                        saving
                            ? null
                            : (value) => setState(() {
                              if (value == 'none') {
                                selected.remove(run.id);
                              } else {
                                selected[run.id] = RoutingConnectionDirection
                                    .values
                                    .byName(value!);
                              }
                            }),
                  ),
                  TextButton(
                    onPressed: saving ? null : () => widget.onOpenRun(run),
                    child: const Text('Open route'),
                  ),
                ],
              ),
            ),
          ),
        if (error != null)
          Text(error!, style: const TextStyle(color: Colors.red)),
        FilledButton(
          onPressed: saving ? null : save,
          child: Text(saving ? 'Saving…' : 'Save junction'),
        ),
      ],
    ),
  );
}
