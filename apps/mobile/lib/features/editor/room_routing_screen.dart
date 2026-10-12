import 'package:engineering_core/engineering_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../application/cable_routing_repository.dart';
import 'editor_interaction.dart';

class RoomRoutingScreen extends ConsumerWidget {
  const RoomRoutingScreen({
    super.key,
    required this.roomId,
    required this.roomName,
  });
  final String roomId;
  final String roomName;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routing = ref.watch(roomRoutingProvider(roomId));
    final circuits = ref.watch(roomElectricalCircuitsProvider(roomId));
    return Scaffold(
      appBar: AppBar(title: Text('$roomName · Cable routing')),
      body: routing.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, _) => Center(child: Text('Unable to load routing: $error')),
        data:
            (snapshot) => circuits.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:
                  (error, _) =>
                      Center(child: Text('Unable to load circuits: $error')),
              data:
                  (items) => CableRouteEditor(
                    snapshot: snapshot,
                    circuits: {
                      for (final item in items)
                        item.circuit.id: item.circuit.name,
                    },
                    nextId: ref.read(idGeneratorProvider).next,
                    onSave:
                        ({required route, required run}) => ref
                            .read(cableRoutingRepositoryProvider)
                            .saveRouteWithRun(route: route, run: run),
                    onSaveChannel:
                        ref.read(cableRoutingRepositoryProvider).saveChannel,
                  ),
            ),
      ),
    );
  }
}

class CableRouteEditor extends StatefulWidget {
  const CableRouteEditor({
    super.key,
    required this.snapshot,
    required this.circuits,
    required this.nextId,
    required this.onSave,
    this.onSaveChannel,
  });
  final RoomRoutingSnapshot snapshot;
  final Map<String, String> circuits;
  final String Function() nextId;
  final Future<void> Function({
    required CableRoute route,
    required CableRun run,
  })
  onSave;
  final Future<void> Function(PhysicalChannel channel)? onSaveChannel;
  @override
  State<CableRouteEditor> createState() => _CableRouteEditorState();
}

class _CableRouteEditorState extends State<CableRouteEditor> {
  SurfaceRouteDraft? draft;
  String? patchId, routeId, runId, circuitId;
  LayingMethod method = LayingMethod.surface;
  String? channelId;
  final name = TextEditingController();
  final reserve = TextEditingController(text: '0');
  final allowance = TextEditingController(text: '0');
  bool saving = false;
  @override
  void dispose() {
    name.dispose();
    reserve.dispose();
    allowance.dispose();
    super.dispose();
  }

  SurfacePatch? get patch =>
      widget.snapshot.geometry.patches
          .where((patch) => patch.id == patchId)
          .firstOrNull ??
      widget.snapshot.geometry.patches.firstOrNull;
  void message(Object error) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text('$error')));
  void begin({CableRoute? route, CableRun? run}) {
    setState(() {
      draft = SurfaceRouteDraft(
        nextId: widget.nextId,
        nodes: route?.nodes ?? const [],
        segments: route?.segments ?? const [],
      );
      routeId = route?.id ?? widget.nextId();
      runId = run?.id ?? widget.nextId();
      patchId = draft!.activePatchId ?? patch?.id;
      circuitId = run?.circuitId ?? widget.circuits.keys.firstOrNull;
      name.text = route?.name ?? 'Route ${widget.snapshot.routes.length + 1}';
      reserve.text = '${run?.reservePercent ?? 0}';
      allowance.text = '${run?.terminationAllowanceMm ?? 0}';
      method = LayingMethod.surface;
      channelId = null;
    });
  }

  CableRoute currentRoute() => draft!.route(
    id: routeId!,
    roomId: widget.snapshot.geometry.roomId,
    name: name.text.trim(),
  );
  void tapPoint(Point2Mm point) {
    if (draft == null || saving || patch == null) return;
    try {
      final candidate = const SurfaceNavigationResolver()
          .nearestNavigableCandidate(
            pointer: point,
            activePatch: patch!,
            edges: widget.snapshot.geometry.edges,
            adjacencies: widget.snapshot.geometry.adjacencies,
          );
      if (draft!.nodes.isNotEmpty &&
          candidate?.proximity == SurfaceEdgeProximity.strongPreview) {
        final adjacency = widget.snapshot.geometry.adjacencies.firstWhere(
          (adjacency) => adjacency.id == candidate!.adjacencyId,
        );
        final target = draft!.cross(
          adjacency: adjacency,
          nearPoint: point,
          patches: widget.snapshot.geometry.patches,
          edges: widget.snapshot.geometry.edges,
          method: method,
          channelId: channelId,
        );
        setState(() => patchId = target);
      } else {
        draft!.addPoint(patch!, point, method: method, channelId: channelId);
        setState(() {});
      }
    } catch (error) {
      message(error);
    }
  }

  Future<void> save() async {
    if (draft == null || saving) return;
    if (circuitId == null) {
      message('Create or select a circuit before saving a CableRun.');
      return;
    }
    final route = currentRoute();
    final run = CableRun(
      id: runId!,
      roomId: route.roomId,
      name: route.name,
      circuitId: circuitId!,
      routeId: route.id,
      reservePercent:
          double.tryParse(reserve.text.trim().replaceAll(',', '.')) ??
          double.nan,
      terminationAllowanceMm: int.tryParse(allowance.text.trim()) ?? -1,
    );
    final calculation = widget.snapshot.calculate(route);
    if (run.validate().isNotEmpty ||
        !calculation.ready ||
        calculation.cableLengthMm(run) == null) {
      message(
        calculation.issues.isNotEmpty
            ? calculation.issues.map((issue) => issue.message).join(' ')
            : 'Check the route name, reserve and integer-millimetre allowance.',
      );
      return;
    }
    setState(() => saving = true);
    try {
      await widget.onSave(route: route, run: run);
      if (!mounted) return;
      setState(() => draft = null);
      message('Route and CableRun saved.');
    } catch (error) {
      if (mounted) message('Unable to save route: $error');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> newChannel() async {
    final saveChannel = widget.onSaveChannel;
    if (saveChannel == null) return;
    await showDialog<void>(
      context: context,
      builder:
          (_) => _ChannelDialog(
            onSave:
                (channelName, kind) => saveChannel(
                  PhysicalChannel(
                    id: widget.nextId(),
                    roomId: widget.snapshot.geometry.roomId,
                    name: channelName,
                    kind: kind,
                  ),
                ),
          ),
    );
  }

  void editSegment(
    int index, {
    LayingMethod? newMethod,
    String? newChannel,
    bool changeChannel = false,
  }) {
    final segment = draft!.segments[index];
    final channel =
        widget.snapshot.channels
            .where((channel) => channel.id == newChannel)
            .firstOrNull;
    setState(
      () =>
          draft!.segments[index] = RouteSegment(
            id: segment.id,
            fromNodeId: segment.fromNodeId,
            toNodeId: segment.toNodeId,
            surfacePatchId: segment.surfacePatchId,
            layingMethod:
                channel != null
                    ? LayingMethod.values.byName(channel.kind.name)
                    : newMethod ?? segment.layingMethod,
            physicalChannelId:
                changeChannel
                    ? newChannel
                    : newMethod != null
                    ? null
                    : segment.physicalChannelId,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final active = patch;
    if (active == null)
      return const Center(
        child: Text('Create room surfaces before drawing routes.'),
      );
    final preview = draft == null ? null : currentRoute();
    final calculation =
        preview == null ? null : widget.snapshot.calculate(preview);
    return LayoutBuilder(
      builder:
          (context, constraints) => ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: ValueKey(active.id),
                      initialValue: active.id,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Surface'),
                      items:
                          widget.snapshot.geometry.patches
                              .map(
                                (patch) => DropdownMenuItem(
                                  value: patch.id,
                                  child: Text(
                                    patch.surfaceId,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged:
                          saving
                              ? null
                              : (value) => setState(() => patchId = value),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (draft == null)
                    FilledButton.icon(
                      onPressed: saving ? null : () => begin(),
                      icon: const Icon(Icons.add),
                      label: const Text('New route'),
                    )
                  else
                    IconButton(
                      tooltip: 'Undo route point',
                      icon: const Icon(Icons.undo),
                      onPressed:
                          saving || draft!.nodes.isEmpty
                              ? null
                              : () => setState(() {
                                draft!.removeLast();
                                patchId = draft!.activePatchId ?? patchId;
                              }),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height:
                    (constraints.maxHeight * 0.45)
                        .clamp(220.0, 420.0)
                        .toDouble(),
                child: _RoutingCanvas(
                  patch: active,
                  snapshot: widget.snapshot,
                  preview: preview,
                  enabled: draft != null && !saving,
                  onTap: tapPoint,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  draft == null
                      ? 'Choose New route to draw on the surfaces.'
                      : 'Tap to add points. Tap within 120 mm of a highlighted fold to cross to its adjacent surface.',
                ),
              ),
              if (draft != null) ...[
                if (draft!.activePatchId != null &&
                    draft!.activePatchId != active.id)
                  TextButton(
                    onPressed:
                        () => setState(() => patchId = draft!.activePatchId),
                    child: const Text('Return to current route surface'),
                  ),
                Text(
                  'Nodes: ${draft!.nodes.length} · ${calculation!.ready ? 'Geometry: ${calculation.geometricLengthMm!.toStringAsFixed(2)} mm' : 'Route needs input'}',
                ),
                TextField(
                  controller: name,
                  enabled: !saving,
                  decoration: const InputDecoration(
                    labelText: 'Route / CableRun name',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                DropdownButtonFormField<String>(
                  key: ValueKey(circuitId),
                  initialValue:
                      widget.circuits.containsKey(circuitId) ? circuitId : null,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Circuit'),
                  items:
                      widget.circuits.entries
                          .map(
                            (entry) => DropdownMenuItem(
                              value: entry.key,
                              child: Text(
                                entry.value,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                  onChanged:
                      saving
                          ? null
                          : (value) => setState(() => circuitId = value),
                ),
                DropdownButtonFormField<LayingMethod>(
                  key: ValueKey(method),
                  initialValue: method,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'New segment method',
                  ),
                  items:
                      LayingMethod.values
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value.name),
                            ),
                          )
                          .toList(),
                  onChanged:
                      saving
                          ? null
                          : (value) {
                            if (value != null)
                              setState(() {
                                method = value;
                                channelId = null;
                              });
                          },
                ),
                DropdownButtonFormField<String>(
                  key: ValueKey(channelId),
                  initialValue:
                      widget.snapshot.channels.any(
                            (channel) => channel.id == channelId,
                          )
                          ? channelId
                          : '',
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'New segment physical channel',
                  ),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('None')),
                    ...widget.snapshot.channels.map(
                      (channel) => DropdownMenuItem(
                        value: channel.id,
                        child: Text(
                          channel.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged:
                      saving
                          ? null
                          : (value) => setState(() {
                            channelId =
                                value == null || value.isEmpty ? null : value;
                            final channel =
                                widget.snapshot.channels
                                    .where((channel) => channel.id == channelId)
                                    .firstOrNull;
                            if (channel != null)
                              method = LayingMethod.values.byName(
                                channel.kind.name,
                              );
                          }),
                ),
                TextButton.icon(
                  onPressed:
                      saving || widget.onSaveChannel == null
                          ? null
                          : newChannel,
                  icon: const Icon(Icons.add),
                  label: const Text('New physical channel'),
                ),
                TextField(
                  controller: reserve,
                  enabled: !saving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Reserve (%)'),
                ),
                TextField(
                  controller: allowance,
                  enabled: !saving,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Termination allowance (mm)',
                  ),
                ),
                ExpansionTile(
                  title: Text('Segment details (${draft!.segments.length})'),
                  children: [
                    for (var i = 0; i < draft!.segments.length; i++)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Segment ${i + 1} · ${draft!.segments[i].surfacePatchId}',
                          ),
                          DropdownButtonFormField<LayingMethod>(
                            key: ValueKey(
                              'method-${draft!.segments[i].id}-${draft!.segments[i].layingMethod}',
                            ),
                            initialValue: draft!.segments[i].layingMethod,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Laying method',
                            ),
                            items:
                                LayingMethod.values
                                    .map(
                                      (value) => DropdownMenuItem(
                                        value: value,
                                        child: Text(value.name),
                                      ),
                                    )
                                    .toList(),
                            onChanged:
                                saving
                                    ? null
                                    : (value) {
                                      if (value != null)
                                        editSegment(i, newMethod: value);
                                    },
                          ),
                          DropdownButtonFormField<String>(
                            key: ValueKey(
                              'channel-${draft!.segments[i].id}-${draft!.segments[i].physicalChannelId}',
                            ),
                            initialValue:
                                widget.snapshot.channels.any(
                                      (channel) =>
                                          channel.id ==
                                          draft!.segments[i].physicalChannelId,
                                    )
                                    ? draft!.segments[i].physicalChannelId
                                    : '',
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Physical channel',
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: '',
                                child: Text('None'),
                              ),
                              ...widget.snapshot.channels.map(
                                (channel) => DropdownMenuItem(
                                  value: channel.id,
                                  child: Text(
                                    channel.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                            onChanged:
                                saving
                                    ? null
                                    : (value) => editSegment(
                                      i,
                                      newChannel:
                                          value == null || value.isEmpty
                                              ? null
                                              : value,
                                      changeChannel: true,
                                    ),
                          ),
                        ],
                      ),
                  ],
                ),
                for (final issue in calculation.issues)
                  Text(
                    issue.message,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton(
                      onPressed: saving ? null : save,
                      child: Text(saving ? 'Saving…' : 'Save route'),
                    ),
                    TextButton(
                      onPressed:
                          saving ? null : () => setState(() => draft = null),
                      child: const Text('Cancel draft'),
                    ),
                  ],
                ),
              ],
              const Divider(),
              for (final run in widget.snapshot.runs)
                Builder(
                  builder: (context) {
                    final route =
                        widget.snapshot.routes
                            .where((route) => route.id == run.routeId)
                            .firstOrNull;
                    final length = widget.snapshot.cableLength(run);
                    return Card(
                      child: ListTile(
                        title: Text(run.name),
                        subtitle: Text(
                          '${widget.circuits[run.circuitId] ?? 'Circuit unavailable'} · ${length == null ? 'Route needs review' : 'Cable ${length.toStringAsFixed(2)} mm'}\nReserve ${run.reservePercent}% · allowance ${run.terminationAllowanceMm} mm',
                        ),
                        trailing: const Icon(Icons.edit_outlined),
                        onTap:
                            saving || route == null
                                ? null
                                : () => begin(route: route, run: run),
                      ),
                    );
                  },
                ),
            ],
          ),
    );
  }
}

class _RoutingCanvas extends StatelessWidget {
  const _RoutingCanvas({
    required this.patch,
    required this.snapshot,
    required this.preview,
    required this.enabled,
    required this.onTap,
  });
  final SurfacePatch patch;
  final RoomRoutingSnapshot snapshot;
  final CableRoute? preview;
  final bool enabled;
  final ValueChanged<Point2Mm> onTap;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final transform = SurfaceViewportTransform(
        boundary: patch.boundary,
        viewportWidth: constraints.maxWidth,
        viewportHeight: constraints.maxHeight,
      );
      return InteractiveViewer(
        minScale: 0.5,
        maxScale: 4,
        child: SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp:
                enabled
                    ? (details) => onTap(
                      transform.viewportToLocal(
                        details.localPosition.dx,
                        details.localPosition.dy,
                      ),
                    )
                    : null,
            child: CustomPaint(
              painter: _RoutingPainter(
                patch: patch,
                snapshot: snapshot,
                routes: preview == null ? snapshot.routes : [preview],
                transform: transform,
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _RoutingPainter extends CustomPainter {
  const _RoutingPainter({
    required this.patch,
    required this.snapshot,
    required this.routes,
    required this.transform,
  });
  final SurfacePatch patch;
  final RoomRoutingSnapshot snapshot;
  final List<CableRoute> routes;
  final SurfaceViewportTransform transform;
  Offset map(Point2Mm point) {
    final result = transform.localToViewport(point);
    return Offset(result.x, result.y);
  }

  Path polygon(Polygon2Mm boundary) {
    final result = Path();
    final first = map(boundary.vertices.first);
    result.moveTo(first.dx, first.dy);
    for (final point in boundary.vertices.skip(1)) {
      final p = map(point);
      result.lineTo(p.dx, p.dy);
    }
    return result..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      polygon(patch.boundary),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.blueGrey,
    );
    for (final opening in snapshot.geometry.openings.where(
      (opening) => opening.hostSurfacePatchId == patch.id,
    )) {
      canvas.drawPath(
        polygon(opening.boundary),
        Paint()..color = Colors.red.withValues(alpha: 0.15),
      );
    }
    final navigableIds = {
      for (final adjacency in snapshot.geometry.adjacencies)
        adjacency.fromEdgeId,
      for (final adjacency in snapshot.geometry.adjacencies) adjacency.toEdgeId,
    };
    for (final edge in snapshot.geometry.edges.where(
      (edge) => edge.patchId == patch.id && navigableIds.contains(edge.id),
    )) {
      canvas.drawLine(
        map(edge.start),
        map(edge.end),
        Paint()
          ..color = Colors.lightBlue
          ..strokeWidth = 5,
      );
    }
    for (final route in routes) {
      final nodes = {for (final node in route.nodes) node.id: node};
      for (final segment in route.segments.where(
        (segment) => segment.surfacePatchId == patch.id,
      )) {
        final from = nodes[segment.fromNodeId]?.anchorOn(patch.id),
            to = nodes[segment.toNodeId]?.anchorOn(patch.id);
        if (from != null && to != null)
          canvas.drawLine(
            map(from.localPosition),
            map(to.localPosition),
            Paint()
              ..color = Colors.indigo
              ..strokeWidth = 3,
          );
      }
      for (final node in route.nodes) {
        final anchor = node.anchorOn(patch.id);
        if (anchor != null)
          canvas.drawCircle(
            map(anchor.localPosition),
            node.kind == RouteNodeKind.surfaceTransition ? 6 : 4,
            Paint()..color = Colors.indigo,
          );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RoutingPainter old) => true;
}

class _ChannelDialog extends StatefulWidget {
  const _ChannelDialog({required this.onSave});
  final Future<void> Function(String name, PhysicalChannelKind kind) onSave;
  @override
  State<_ChannelDialog> createState() => _ChannelDialogState();
}

class _ChannelDialogState extends State<_ChannelDialog> {
  final name = TextEditingController();
  PhysicalChannelKind kind = PhysicalChannelKind.conduit;
  bool saving = false;
  String? error;
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving) return;
    if (name.text.trim().isEmpty) {
      setState(() => error = 'Enter a channel name.');
      return;
    }
    setState(() => saving = true);
    try {
      await widget.onSave(name.text.trim(), kind);
      if (mounted) Navigator.of(context).pop();
    } catch (failure) {
      if (mounted) setState(() => error = 'Unable to save channel: $failure');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Physical channel'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: name,
          enabled: !saving,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        DropdownButtonFormField<PhysicalChannelKind>(
          initialValue: kind,
          isExpanded: true,
          items:
              PhysicalChannelKind.values
                  .map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text(value.name)),
                  )
                  .toList(),
          onChanged:
              saving
                  ? null
                  : (value) {
                    if (value != null) setState(() => kind = value);
                  },
        ),
        if (error != null) Text(error!),
      ],
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: saving ? null : save,
        child: const Text('Save channel'),
      ),
    ],
  );
}
