import 'package:engineering_core/engineering_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../application/engineering_topology_repository.dart';
import 'engineering_systems_screen.dart';

enum TopologyFormKind {
  port,
  connection,
  internalMapping,
  group,
  assembly,
  compatibilityProfile,
  topologyProfile,
  assemblyProfile,
}

class EngineeringTopologyScreen extends ConsumerWidget {
  const EngineeringTopologyScreen({super.key, required this.projectId});
  final String projectId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Ports / connections / topology')),
    body: ref
        .watch(projectEngineeringTopologyProvider(projectId))
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Unable to load topology: $e')),
          data: (snapshot) {
            if (snapshot.systems.project == null)
              return const Center(child: Text('Project is unavailable.'));
            final repo = ref.read(engineeringTopologyRepositoryProvider);
            Future<void> save(Object value) => switch (value) {
              EngineeringPort p => repo.savePort(projectId, p),
              EngineeringConnection c => repo.saveConnection(projectId, c),
              InternalConnectivity m => repo.saveInternal(projectId, m),
              TopologyGroup g => repo.saveGroup(projectId, g),
              ComponentAssembly a => repo.saveAssembly(projectId, a),
              ConnectionCompatibilityProfile p => repo.saveConnectionProfile(p),
              TopologyProfile p => repo.saveTopologyProfile(p),
              AssemblyProfile p => repo.saveAssemblyProfile(p),
              _ => throw ArgumentError('Unsupported topology object'),
            };
            return EngineeringTopologyWorkspace(
              snapshot: snapshot,
              nextId: ref.read(idGeneratorProvider).next,
              onSave: save,
              onArchive: (kind, id) => repo.archive(projectId, kind, id),
              onSystems:
                  () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder:
                          (_) => EngineeringSystemsScreen(projectId: projectId),
                    ),
                  ),
            );
          },
        ),
  );
}

class EngineeringTopologyWorkspace extends StatefulWidget {
  const EngineeringTopologyWorkspace({
    super.key,
    required this.snapshot,
    required this.nextId,
    required this.onSave,
    required this.onArchive,
    required this.onSystems,
  });
  final ProjectEngineeringTopologySnapshot snapshot;
  final String Function() nextId;
  final Future<void> Function(Object) onSave;
  final Future<void> Function(TopologyObjectKind, String) onArchive;
  final VoidCallback onSystems;
  @override
  State<EngineeringTopologyWorkspace> createState() =>
      _EngineeringTopologyWorkspaceState();
}

class _EngineeringTopologyWorkspaceState
    extends State<EngineeringTopologyWorkspace> {
  bool busy = false;
  String? error, tracePort, systemFilter;
  TraceLayer traceLayer = TraceLayer.all;
  TopologyTraceDirection traceDirection = TopologyTraceDirection.both;
  Future<void> work(Future<void> Function() action) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void edit(TopologyFormKind kind, [Object? value]) => showDialog<void>(
    context: context,
    builder:
        (_) => EngineeringTopologyDialog(
          kind: kind,
          snapshot: widget.snapshot,
          id: _id(value) ?? widget.nextId(),
          initial: value,
          onSave: widget.onSave,
        ),
  );
  String? _id(Object? value) => switch (value) {
    EngineeringPort v => v.id,
    EngineeringConnection v => v.id,
    InternalConnectivity v => v.id,
    TopologyGroup v => v.id,
    ComponentAssembly v => v.id,
    _ => null,
  };
  String portName(String id) {
    final p = widget.snapshot.ports.where((p) => p.id == id).firstOrNull;
    final c =
        widget.snapshot.systems.components
            .where((c) => c.id == p?.componentId)
            .firstOrNull;
    return p == null
        ? 'Unavailable port $id'
        : '${c?.name ?? p.componentId}.${p.code}';
  }

  Widget actions(
    TopologyFormKind form,
    TopologyObjectKind kind,
    Object value,
  ) => Wrap(
    children: [
      TextButton(
        onPressed: busy ? null : () => edit(form, value),
        child: const Text('Edit'),
      ),
      TextButton(
        onPressed:
            busy ? null : () => work(() => widget.onArchive(kind, _id(value)!)),
        child: const Text('Retire'),
      ),
    ],
  );
  Widget findings(List<TopologyFinding> items) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final f in items)
        Text(
          '${f.draft ? 'Draft' : f.code}: ${f.message}',
          style: TextStyle(
            color: f.draft ? null : Theme.of(context).colorScheme.error,
          ),
        ),
    ],
  );
  @override
  Widget build(BuildContext context) {
    final s = widget.snapshot, graph = s.graph();
    if (tracePort != null && !graph.ports.containsKey(tracePort))
      tracePort = null;
    if (systemFilter != null && !graph.systems.containsKey(systemFilter))
      systemFilter = null;
    return DefaultTabController(
      length: 5,
      child: Column(
        children: [
          const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Ports'),
              Tab(text: 'Connections / trace'),
              Tab(text: 'Groups'),
              Tab(text: 'Assemblies'),
              Tab(text: 'Profiles'),
            ],
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Expanded(
            child: TabBarView(
              children: [
                ListView(
                  key: const ValueKey('topology-ports'),
                  padding: const EdgeInsets.all(16),
                  children: [
                    Wrap(
                      spacing: 8,
                      children: [
                        FilledButton(
                          onPressed:
                              busy || s.systems.components.isEmpty
                                  ? null
                                  : () => edit(TopologyFormKind.port),
                          child: const Text('New port'),
                        ),
                        OutlinedButton(
                          onPressed:
                              busy || s.ports.length < 2
                                  ? null
                                  : () =>
                                      edit(TopologyFormKind.internalMapping),
                          child: const Text('Internal passive mapping'),
                        ),
                        TextButton(
                          onPressed: widget.onSystems,
                          child: const Text('Systems / participants'),
                        ),
                      ],
                    ),
                    const Text(
                      'Ports belong to existing placed devices. Unknown interface parameters remain unresolved. Catalog template instantiation is ELV2.',
                    ),
                    for (final p in s.ports)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                portName(p.id),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                '${p.kind.name} · ${p.direction.name} · ${s.connections.where((c) => c.fromPortId == p.id || c.toPortId == p.id).length}/${p.capacity} external connections',
                              ),
                              Text(
                                '${p.connector ?? 'Connector unresolved'} · ${p.protocol == null ? 'Protocol unresolved' : '${p.protocol!.id} / ${p.protocol!.version}'}',
                              ),
                              if (p.voltage != null)
                                Text(
                                  '${p.voltage!.currentKind.name.toUpperCase()} ${p.voltage!.minimumV}–${p.voltage!.maximumV} V · power ${p.powerDirection?.name ?? 'unresolved'}',
                                ),
                              if (p.templateProvenance != null)
                                Text(
                                  'Frozen template: ${p.templateProvenance!.id} / ${p.templateProvenance!.version}',
                                ),
                              findings(graph.portFindings(p)),
                              actions(
                                TopologyFormKind.port,
                                TopologyObjectKind.port,
                                p,
                              ),
                            ],
                          ),
                        ),
                      ),
                    for (final m in s.internalLinks)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Internal: ${portName(m.fromPortId)} → ${portName(m.toPortId)}',
                              ),
                              Text(
                                '${m.layer.name} · ${m.bidirectional ? 'bidirectional' : 'directed'}\n${m.evidence}',
                              ),
                              const Text(
                                'Passive device mapping; no cable or CableRun is created.',
                              ),
                              findings(graph.internalFindings(m)),
                              actions(
                                TopologyFormKind.internalMapping,
                                TopologyObjectKind.internalMapping,
                                m,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                ListView(
                  key: const ValueKey('topology-connections'),
                  padding: const EdgeInsets.all(16),
                  children: [
                    FilledButton(
                      onPressed:
                          busy ||
                                  s.ports.length < 2 ||
                                  s.connectionProfiles.isEmpty ||
                                  s.systems.systems.isEmpty
                              ? null
                              : () => edit(TopologyFormKind.connection),
                      child: const Text('New connection'),
                    ),
                    const Text(
                      'Compatibility uses explicitly authored project profiles. Wired links are planned; cable allocation and installed routing are ELV3.',
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: systemFilter ?? '',
                      decoration: const InputDecoration(
                        labelText: 'System filter',
                      ),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('All systems'),
                        ),
                        for (final sys in s.systems.systems)
                          DropdownMenuItem(
                            value: sys.id,
                            child: Text(sys.code),
                          ),
                      ],
                      onChanged:
                          (v) =>
                              setState(() => systemFilter = v == '' ? null : v),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: tracePort ?? '',
                      decoration: const InputDecoration(
                        labelText: 'Trace from port',
                      ),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('Choose port'),
                        ),
                        for (final p in s.ports)
                          DropdownMenuItem(
                            value: p.id,
                            child: Text(
                              portName(p.id),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged:
                          (v) => setState(() => tracePort = v == '' ? null : v),
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        DropdownButton<TraceLayer>(
                          value: traceLayer,
                          items: [
                            for (final v in TraceLayer.values)
                              DropdownMenuItem(value: v, child: Text(v.name)),
                          ],
                          onChanged: (v) => setState(() => traceLayer = v!),
                        ),
                        DropdownButton<TopologyTraceDirection>(
                          value: traceDirection,
                          items: [
                            for (final v in TopologyTraceDirection.values)
                              DropdownMenuItem(value: v, child: Text(v.name)),
                          ],
                          onChanged: (v) => setState(() => traceDirection = v!),
                        ),
                      ],
                    ),
                    if (tracePort != null)
                      Builder(
                        builder: (_) {
                          final trace = graph.trace(
                            tracePort!,
                            layer: traceLayer,
                            direction: traceDirection,
                            systemId: systemFilter,
                          );
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                'Reachable ports:\n${trace.portIds.map(portName).join('\n')}\nExternal links: ${trace.connectionIds.join(', ')}\nInternal mappings: ${trace.internalLinkIds.join(', ')}',
                              ),
                            ),
                          );
                        },
                      ),
                    for (final c in s.connections.where(
                      (c) => systemFilter == null || c.systemId == systemFilter,
                    ))
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${portName(c.fromPortId)} → ${portName(c.toPortId)}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                '${s.systems.systems.where((sys) => sys.id == c.systemId).firstOrNull?.code ?? c.systemId} · ${s.connectionProfiles.where((p) => p.id == c.profileId).firstOrNull?.semanticCode ?? 'profile unresolved'} · ${c.medium.name}',
                              ),
                              if (c.medium == ConnectionMedium.wired)
                                const Text(
                                  'Physical realization: awaiting ELV3 cable allocation / routing',
                                ),
                              findings(graph.connectionFindings(c)),
                              actions(
                                TopologyFormKind.connection,
                                TopologyObjectKind.connection,
                                c,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                ListView(
                  key: const ValueKey('topology-groups'),
                  padding: const EdgeInsets.all(16),
                  children: [
                    FilledButton(
                      onPressed:
                          busy ||
                                  s.ports.isEmpty ||
                                  s.topologyProfiles.isEmpty ||
                                  s.systems.systems.isEmpty
                              ? null
                              : () => edit(TopologyFormKind.group),
                      child: const Text('New topology group'),
                    ),
                    for (final g in s.groups)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${g.code} · ${graph.groupFindings(g).isEmpty ? 'Topology complete' : 'Needs input'}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                '${s.topologyProfiles.where((p) => p.id == g.profileId).firstOrNull?.shape.name ?? 'Unresolved profile'} · ${s.connections.where((c) => c.groupId == g.id).length} external links',
                              ),
                              Text(
                                'Source ${portName(g.startPortId)}${g.endPortId == null ? '' : '\nEnd / return ${portName(g.endPortId!)}'}',
                              ),
                              const Text(
                                'Topology status only; physical installation and normative validation follow later.',
                              ),
                              findings(graph.groupFindings(g)),
                              actions(
                                TopologyFormKind.group,
                                TopologyObjectKind.group,
                                g,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                ListView(
                  key: const ValueKey('topology-assemblies'),
                  padding: const EdgeInsets.all(16),
                  children: [
                    FilledButton(
                      onPressed:
                          busy || s.assemblyProfiles.isEmpty
                              ? null
                              : () => edit(TopologyFormKind.assembly),
                      child: const Text('New functional assembly'),
                    ),
                    const Text(
                      'A functional set does not contain or own its equipment. Members retain their placement, systems and connections.',
                    ),
                    for (final a in s.assemblies)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${a.code} · ${graph.assemblyFindings(a).isEmpty ? 'Roles complete' : 'Needs input'}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              for (final m in a.members)
                                Text(
                                  '${m.role}: ${s.systems.components.where((c) => c.id == m.componentId).firstOrNull?.name ?? m.componentId}',
                                ),
                              findings(graph.assemblyFindings(a)),
                              actions(
                                TopologyFormKind.assembly,
                                TopologyObjectKind.assembly,
                                a,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                ListView(
                  key: const ValueKey('topology-profiles'),
                  padding: const EdgeInsets.all(16),
                  children: [
                    Wrap(
                      spacing: 8,
                      children: [
                        FilledButton(
                          onPressed:
                              busy
                                  ? null
                                  : () => edit(
                                    TopologyFormKind.compatibilityProfile,
                                  ),
                          child: const Text('Connection profile'),
                        ),
                        OutlinedButton(
                          onPressed:
                              busy
                                  ? null
                                  : () =>
                                      edit(TopologyFormKind.topologyProfile),
                          child: const Text('Topology profile'),
                        ),
                        OutlinedButton(
                          onPressed:
                              busy
                                  ? null
                                  : () =>
                                      edit(TopologyFormKind.assemblyProfile),
                          child: const Text('Assembly profile'),
                        ),
                      ],
                    ),
                    const Text(
                      'Immutable project engineering profiles. These are declared compatibility/topology conditions, not approved national normative packs.',
                    ),
                    for (final p in s.connectionProfiles)
                      ListTile(
                        title: Text(
                          '${p.identity.code} / ${p.identity.version}',
                        ),
                        subtitle: Text(
                          '${p.semanticCode} · ${p.layer.name}\n${p.kindA.name} / ${p.connectorA} / ${p.protocolA.id}:${p.protocolA.version} → ${p.kindB.name} / ${p.connectorB} / ${p.protocolB.id}:${p.protocolB.version}\n${p.familyCodes.join(', ')} · ${p.media.map((m) => m.name).join(', ')}\nSource: ${p.identity.source}',
                        ),
                      ),
                    for (final p in s.topologyProfiles)
                      ListTile(
                        title: Text(
                          '${p.identity.code} / ${p.identity.version}',
                        ),
                        subtitle: Text(
                          '${p.shape.name} · ${p.layer.name}\nSource: ${p.identity.source}',
                        ),
                      ),
                    for (final p in s.assemblyProfiles)
                      ListTile(
                        title: Text(
                          '${p.identity.code} / ${p.identity.version}',
                        ),
                        subtitle: Text(
                          '${p.roles.map((r) => '${r.code}: ${r.minimum}–${r.maximum}').join(', ')}\nShared members: ${p.allowSharedComponents}\nSource: ${p.identity.source}',
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class EngineeringTopologyDialog extends StatefulWidget {
  const EngineeringTopologyDialog({
    super.key,
    required this.kind,
    required this.snapshot,
    required this.id,
    required this.onSave,
    this.initial,
  });
  final TopologyFormKind kind;
  final ProjectEngineeringTopologySnapshot snapshot;
  final String id;
  final Object? initial;
  final Future<void> Function(Object) onSave;
  @override
  State<EngineeringTopologyDialog> createState() =>
      _EngineeringTopologyDialogState();
}

class _EngineeringTopologyDialogState extends State<EngineeringTopologyDialog> {
  final fields = <String, TextEditingController>{},
      selected = <String, String>{};
  final familyCodes = <String>{};
  final members = <AssemblyMember>[], roles = <AssemblyRoleRule>[];
  bool busy = false, bidirectional = true, shared = false;
  String? error;
  void field(String label, [Object? value]) =>
      fields[label] = TextEditingController(text: value?.toString() ?? '');
  void choice(String label, [String? value]) => selected[label] = value ?? '';
  @override
  void initState() {
    super.initState();
    final v = widget.initial;
    switch (widget.kind) {
      case TopologyFormKind.port:
        final p = v as EngineeringPort?;
        field('Code', p?.code);
        field('External capacity', p?.capacity);
        field('Connector', p?.connector);
        field('Protocol ID', p?.protocol?.id);
        field('Protocol edition', p?.protocol?.version);
        field('Minimum voltage V', p?.voltage?.minimumV);
        field('Maximum voltage V', p?.voltage?.maximumV);
        field('Source port rating W', p?.powerLimitW);
        field('Endpoint demand W', p?.powerDemandW);
        field('Template ID', p?.templateProvenance?.id);
        field('Template edition', p?.templateProvenance?.version);
        choice('Owner device', p?.componentId);
        choice('Port kind', p?.kind.name ?? EngineeringPortKind.data.name);
        choice(
          'Interface direction',
          p?.direction.name ?? PortDirection.bidirectional.name,
        );
        choice('Power direction', p?.powerDirection?.name);
        choice('AC / DC', p?.voltage?.currentKind.name);
      case TopologyFormKind.connection:
        final c = v as EngineeringConnection?;
        choice('System', c?.systemId);
        choice('From port', c?.fromPortId);
        choice('To port', c?.toPortId);
        choice('Compatibility profile', c?.profileId);
        choice('Group (optional)', c?.groupId);
        choice('Medium', c?.medium.name ?? ConnectionMedium.wired.name);
      case TopologyFormKind.internalMapping:
        final m = v as InternalConnectivity?;
        choice('Owner device', m?.componentId);
        choice('From port', m?.fromPortId);
        choice('To port', m?.toPortId);
        choice('Layer', m?.layer.name ?? ConnectionLayer.data.name);
        bidirectional = m?.bidirectional ?? true;
        field('Static passive mapping evidence', m?.evidence);
      case TopologyFormKind.group:
        final g = v as TopologyGroup?;
        field('Code', g?.code);
        choice('System', g?.systemId);
        choice('Topology profile', g?.profileId);
        choice('Source port', g?.startPortId);
        choice('End / return port', g?.endPortId);
      case TopologyFormKind.assembly:
        final a = v as ComponentAssembly?;
        field('Code', a?.code);
        choice('Assembly profile', a?.profileId);
        choice('Member role');
        choice('Member device');
        members.addAll(a?.members ?? []);
      case TopologyFormKind.compatibilityProfile:
        field('Code');
        field('Edition');
        field('Source / engineering evidence');
        field('Semantic code');
        field('Connector A');
        field('Connector B');
        field('Protocol A ID');
        field('Protocol A edition');
        field('Protocol B ID');
        field('Protocol B edition');
        choice('Layer', ConnectionLayer.data.name);
        choice('Flow', CompatibilityFlow.bidirectional.name);
        choice('Kind A', EngineeringPortKind.data.name);
        choice('Kind B', EngineeringPortKind.data.name);
        choice('Allowed medium', ConnectionMedium.wired.name);
      case TopologyFormKind.topologyProfile:
        field('Code');
        field('Edition');
        field('Source / engineering evidence');
        choice('Shape', TopologyShape.path.name);
        choice('Trace layer', TraceLayer.data.name);
      case TopologyFormKind.assemblyProfile:
        field('Code');
        field('Edition');
        field('Source / engineering evidence');
        field('Role code');
        field('Minimum members');
        field('Maximum members');
    }
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  String text(String label) => fields[label]!.text.trim();
  String pick(String label) => selected[label]!;
  double? optionalNumber(String label) =>
      text(label).isEmpty ? null : double.parse(text(label));
  EngineeringProfileReference? reference(String id, String edition) =>
      text(id).isEmpty && text(edition).isEmpty
          ? null
          : EngineeringProfileReference(id: text(id), version: text(edition));
  ProfileIdentity identity() => ProfileIdentity(
    id: widget.id,
    projectId: widget.snapshot.systems.project!.id,
    code: text('Code').toUpperCase(),
    version: text('Edition'),
    source: text('Source / engineering evidence'),
  );
  Object candidate() {
    switch (widget.kind) {
      case TopologyFormKind.port:
        final minimum = optionalNumber('Minimum voltage V'),
            maximum = optionalNumber('Maximum voltage V');
        if ((minimum != null || maximum != null) &&
            (minimum == null || maximum == null || pick('AC / DC').isEmpty))
          throw ArgumentError(
            'Voltage domain needs AC/DC, minimum and maximum.',
          );
        return EngineeringPort(
          id: widget.id,
          componentId: pick('Owner device'),
          code: text('Code').toUpperCase(),
          kind: EngineeringPortKind.values.byName(pick('Port kind')),
          direction: PortDirection.values.byName(pick('Interface direction')),
          capacity: int.parse(text('External capacity')),
          connector: text('Connector').isEmpty ? null : text('Connector'),
          protocol: reference('Protocol ID', 'Protocol edition'),
          voltage:
              minimum == null
                  ? null
                  : PortVoltageDomain(
                    currentKind: PortCurrentKind.values.byName(pick('AC / DC')),
                    minimumV: minimum,
                    maximumV: maximum!,
                  ),
          powerDirection:
              pick('Power direction').isEmpty
                  ? null
                  : PortDirection.values.byName(pick('Power direction')),
          powerLimitW: optionalNumber('Source port rating W'),
          powerDemandW: optionalNumber('Endpoint demand W'),
          templateProvenance: reference('Template ID', 'Template edition'),
        );
      case TopologyFormKind.connection:
        return EngineeringConnection(
          id: widget.id,
          systemId: pick('System'),
          fromPortId: pick('From port'),
          toPortId: pick('To port'),
          profileId: pick('Compatibility profile'),
          medium: ConnectionMedium.values.byName(pick('Medium')),
          groupId:
              pick('Group (optional)').isEmpty
                  ? null
                  : pick('Group (optional)'),
        );
      case TopologyFormKind.internalMapping:
        return InternalConnectivity(
          id: widget.id,
          componentId: pick('Owner device'),
          fromPortId: pick('From port'),
          toPortId: pick('To port'),
          layer: ConnectionLayer.values.byName(pick('Layer')),
          bidirectional: bidirectional,
          evidence: text('Static passive mapping evidence'),
        );
      case TopologyFormKind.group:
        return TopologyGroup(
          id: widget.id,
          code: text('Code').toUpperCase(),
          systemId: pick('System'),
          profileId: pick('Topology profile'),
          startPortId: pick('Source port'),
          endPortId:
              pick('End / return port').isEmpty
                  ? null
                  : pick('End / return port'),
        );
      case TopologyFormKind.assembly:
        return ComponentAssembly(
          id: widget.id,
          code: text('Code').toUpperCase(),
          profileId: pick('Assembly profile'),
          members: members,
        );
      case TopologyFormKind.compatibilityProfile:
        return ConnectionCompatibilityProfile(
          identity: identity(),
          familyCodes: familyCodes,
          media: [ConnectionMedium.values.byName(pick('Allowed medium'))],
          semanticCode: text('Semantic code').toUpperCase(),
          layer: ConnectionLayer.values.byName(pick('Layer')),
          flow: CompatibilityFlow.values.byName(pick('Flow')),
          kindA: EngineeringPortKind.values.byName(pick('Kind A')),
          kindB: EngineeringPortKind.values.byName(pick('Kind B')),
          connectorA: text('Connector A'),
          connectorB: text('Connector B'),
          protocolA: EngineeringProfileReference(
            id: text('Protocol A ID'),
            version: text('Protocol A edition'),
          ),
          protocolB: EngineeringProfileReference(
            id: text('Protocol B ID'),
            version: text('Protocol B edition'),
          ),
        );
      case TopologyFormKind.topologyProfile:
        return TopologyProfile(
          identity: identity(),
          shape: TopologyShape.values.byName(pick('Shape')),
          layer: TraceLayer.values.byName(pick('Trace layer')),
        );
      case TopologyFormKind.assemblyProfile:
        return AssemblyProfile(
          identity: identity(),
          roles: roles,
          allowSharedComponents: shared,
        );
    }
  }

  List<TopologyFinding> preview(Object value) {
    final s = widget.snapshot;
    return switch (value) {
      EngineeringPort p => s.graph(port: p).portFindings(p),
      EngineeringConnection c => [
        ...s.graph(connection: c).connectionFindings(c),
        if (c.groupId != null && s.groups.any((g) => g.id == c.groupId))
          ...s
              .graph(connection: c)
              .groupFindings(s.groups.firstWhere((g) => g.id == c.groupId)),
      ],
      InternalConnectivity m => s.graph(internal: m).internalFindings(m),
      TopologyGroup g => s.graph(group: g).groupFindings(g),
      ComponentAssembly a => s.graph(assembly: a).assemblyFindings(a),
      _ => [],
    };
  }

  Future<void> save() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final value = candidate();
      final invalid = preview(value).where((f) => !f.draft).toList();
      if (invalid.isNotEmpty)
        throw StateError(
          invalid.map((f) => '${f.code}: ${f.message}').join('\n'),
        );
      final profileErrors = switch (value) {
        ConnectionCompatibilityProfile p => p.validate(),
        TopologyProfile p => p.validate(),
        AssemblyProfile p => p.validate(),
        _ => <String>[],
      };
      if (profileErrors.isNotEmpty)
        throw ArgumentError(profileErrors.join(' '));
      await widget.onSave(value);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Map<String, String> enums(Iterable<Enum> values) => {
    for (final v in values) v.name: v.name,
  };
  Widget choose(
    String label,
    Map<String, String> values, {
    VoidCallback? changed,
  }) {
    final current = pick(label);
    if (current.isNotEmpty && !values.containsKey(current))
      selected[label] = '';
    return DropdownButtonFormField<String>(
      key: ValueKey('$label:${pick(label)}'),
      initialValue: pick(label),
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        const DropdownMenuItem(value: '', child: Text('Choose / unset')),
        for (final e in values.entries)
          DropdownMenuItem(
            value: e.key,
            child: Text(e.value, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged:
          busy
              ? null
              : (v) => setState(() {
                selected[label] = v!;
                changed?.call();
              }),
    );
  }

  Widget input(String label) => TextField(
    controller: fields[label],
    enabled: !busy,
    decoration: InputDecoration(labelText: label),
  );
  String portName(EngineeringPort p) =>
      '${widget.snapshot.systems.components.where((c) => c.id == p.componentId).firstOrNull?.name ?? p.componentId}.${p.code}';
  void addRole() {
    try {
      final role = AssemblyRoleRule(
        code: text('Role code').toUpperCase(),
        minimum: int.parse(text('Minimum members')),
        maximum: int.parse(text('Maximum members')),
      );
      if (role.code.isEmpty ||
          role.minimum < 0 ||
          role.maximum <= 0 ||
          role.maximum < role.minimum ||
          roles.any((r) => r.code == role.code))
        throw ArgumentError('Provide a unique role and valid cardinalities.');
      setState(() {
        roles.add(role);
        fields['Role code']!.clear();
        fields['Minimum members']!.clear();
        fields['Maximum members']!.clear();
        error = null;
      });
    } catch (e) {
      setState(() => error = '$e');
    }
  }

  void addMember() {
    final role = pick('Member role'), component = pick('Member device');
    if (role.isEmpty ||
        component.isEmpty ||
        members.any((m) => m.componentId == component && m.role == role)) {
      setState(() => error = 'Choose a unique device-role pair.');
      return;
    }
    setState(() {
      members.add(AssemblyMember(componentId: component, role: role));
      error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.snapshot;
    final devices = {
      for (final c in s.systems.components) c.id: '${c.roomName} · ${c.name}',
    };
    final systems = {for (final sys in s.systems.systems) sys.id: sys.code};
    final allPorts = {for (final p in s.ports) p.id: portName(p)};
    final ownedPorts = {
      for (final p in s.ports.where(
        (p) => p.componentId == selected['Owner device'],
      ))
        p.id: portName(p),
    };
    final controls = <Widget>[];
    switch (widget.kind) {
      case TopologyFormKind.port:
        controls.addAll([
          choose('Owner device', devices),
          input('Code'),
          choose('Port kind', enums(EngineeringPortKind.values)),
          choose('Interface direction', enums(PortDirection.values)),
          input('External capacity'),
          ExpansionTile(
            title: const Text('Interface / power / template provenance'),
            initiallyExpanded: true,
            children: [
              input('Connector'),
              input('Protocol ID'),
              input('Protocol edition'),
              choose('AC / DC', enums(PortCurrentKind.values)),
              input('Minimum voltage V'),
              input('Maximum voltage V'),
              choose('Power direction', enums(PortDirection.values)),
              input('Source port rating W'),
              input('Endpoint demand W'),
              input('Template ID'),
              input('Template edition'),
            ],
          ),
        ]);
      case TopologyFormKind.connection:
        controls.addAll([
          choose(
            'System',
            systems,
            changed: () => selected['Group (optional)'] = '',
          ),
          choose('From port', allPorts),
          choose('To port', allPorts),
          choose('Compatibility profile', {
            for (final p in s.connectionProfiles)
              p.id: '${p.identity.code} / ${p.identity.version}',
          }),
          choose('Medium', enums(ConnectionMedium.values)),
          choose('Group (optional)', {
            for (final g in s.groups.where(
              (g) => g.systemId == selected['System'],
            ))
              g.id: g.code,
          }),
        ]);
      case TopologyFormKind.internalMapping:
        controls.addAll([
          choose(
            'Owner device',
            devices,
            changed: () {
              selected['From port'] = '';
              selected['To port'] = '';
            },
          ),
          choose('From port', ownedPorts),
          choose('To port', ownedPorts),
          choose('Layer', enums(ConnectionLayer.values)),
          SwitchListTile(
            title: const Text('Bidirectional passive mapping'),
            value: bidirectional,
            onChanged: busy ? null : (v) => setState(() => bidirectional = v),
          ),
          input('Static passive mapping evidence'),
          const Text(
            'Static passive paths only. Do not model relay switching, conversion or switching fabric as a permanent bridge.',
          ),
        ]);
      case TopologyFormKind.group:
        controls.addAll([
          input('Code'),
          choose('System', systems),
          choose('Topology profile', {
            for (final p in s.topologyProfiles)
              p.id:
                  '${p.identity.code} / ${p.identity.version} · ${p.shape.name}',
          }),
          choose('Source port', allPorts),
          choose('End / return port', allPorts),
        ]);
      case TopologyFormKind.assembly:
        final profile =
            s.assemblyProfiles
                .where((p) => p.id == selected['Assembly profile'])
                .firstOrNull;
        controls.addAll([
          input('Code'),
          choose('Assembly profile', {
            for (final p in s.assemblyProfiles)
              p.id: '${p.identity.code} / ${p.identity.version}',
          }),
          choose('Member role', {
            for (final r in profile?.roles ?? <AssemblyRoleRule>[])
              r.code: r.code,
          }),
          choose('Member device', devices),
          OutlinedButton(
            onPressed: busy ? null : addMember,
            child: const Text('Add member'),
          ),
          for (final m in members)
            ListTile(
              title: Text(
                '${m.role} · ${devices[m.componentId] ?? m.componentId}',
              ),
              trailing: IconButton(
                tooltip: 'Remove member',
                onPressed:
                    busy ? null : () => setState(() => members.remove(m)),
                icon: const Icon(Icons.remove_circle_outline),
              ),
            ),
        ]);
      case TopologyFormKind.compatibilityProfile:
        controls.addAll([
          input('Code'),
          input('Edition'),
          input('Source / engineering evidence'),
          input('Semantic code'),
          const Text('Allowed system families'),
          Wrap(
            spacing: 4,
            children: [
              for (final code in s.systems.families.map((f) => f.code).toSet())
                FilterChip(
                  label: Text(code),
                  selected: familyCodes.contains(code),
                  onSelected:
                      busy
                          ? null
                          : (v) => setState(() {
                            if (v) {
                              familyCodes.add(code);
                            } else {
                              familyCodes.remove(code);
                            }
                          }),
                ),
            ],
          ),
          choose('Layer', enums(ConnectionLayer.values)),
          choose('Flow', enums(CompatibilityFlow.values)),
          choose('Allowed medium', enums(ConnectionMedium.values)),
          choose('Kind A', enums(EngineeringPortKind.values)),
          input('Connector A'),
          input('Protocol A ID'),
          input('Protocol A edition'),
          choose('Kind B', enums(EngineeringPortKind.values)),
          input('Connector B'),
          input('Protocol B ID'),
          input('Protocol B edition'),
        ]);
      case TopologyFormKind.topologyProfile:
        controls.addAll([
          input('Code'),
          input('Edition'),
          input('Source / engineering evidence'),
          choose('Shape', enums(TopologyShape.values)),
          choose(
            'Trace layer',
            enums(TraceLayer.values.where((l) => l != TraceLayer.all)),
          ),
        ]);
      case TopologyFormKind.assemblyProfile:
        controls.addAll([
          input('Code'),
          input('Edition'),
          input('Source / engineering evidence'),
          SwitchListTile(
            title: const Text('Allow sharing members across assemblies'),
            value: shared,
            onChanged: busy ? null : (v) => setState(() => shared = v),
          ),
          input('Role code'),
          input('Minimum members'),
          input('Maximum members'),
          OutlinedButton(
            onPressed: busy ? null : addRole,
            child: const Text('Add role'),
          ),
          for (final r in roles)
            ListTile(
              title: Text('${r.code} · ${r.minimum}–${r.maximum}'),
              trailing: IconButton(
                tooltip: 'Remove role',
                onPressed: busy ? null : () => setState(() => roles.remove(r)),
                icon: const Icon(Icons.remove_circle_outline),
              ),
            ),
        ]);
    }
    if (widget.kind == TopologyFormKind.connection ||
        widget.kind == TopologyFormKind.group ||
        widget.kind == TopologyFormKind.assembly) {
      try {
        for (final f in preview(candidate())) {
          controls.add(Text('${f.code}: ${f.message}'));
        }
      } catch (_) {
        controls.add(const Text('Choose references to preview validation.'));
      }
    }
    if (error != null)
      controls.add(
        Text(
          error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
    return AlertDialog(
      title: Text(switch (widget.kind) {
        TopologyFormKind.port => 'Engineering port',
        TopologyFormKind.connection => 'Port connection',
        TopologyFormKind.internalMapping => 'Internal passive mapping',
        TopologyFormKind.group => 'Topology group',
        TopologyFormKind.assembly => 'Functional assembly',
        TopologyFormKind.compatibilityProfile =>
          'Connection compatibility edition',
        TopologyFormKind.topologyProfile => 'Topology profile edition',
        TopologyFormKind.assemblyProfile => 'Assembly profile edition',
      }),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: controls),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: busy ? null : save,
          child: Text(busy ? 'Saving…' : 'Save topology'),
        ),
      ],
    );
  }
}
