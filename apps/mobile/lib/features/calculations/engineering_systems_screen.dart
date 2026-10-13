import 'engineering_reference_screen.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../application/engineering_system_repository.dart';
import 'engineering_topology_screen.dart';

class EngineeringSystemsScreen extends ConsumerWidget {
  const EngineeringSystemsScreen({super.key, required this.projectId});
  final String projectId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(
      title: const Text('Engineering systems'),
      actions: [
        IconButton(
          tooltip: "Reference catalogs",
          icon: const Icon(Icons.library_books_outlined),
          onPressed:
              () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder:
                      (_) => EngineeringReferenceScreen(projectId: projectId),
                ),
              ),
        ),
        IconButton(
          tooltip: 'Ports / topology',
          icon: const Icon(Icons.account_tree_outlined),
          onPressed:
              () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder:
                      (_) => EngineeringTopologyScreen(projectId: projectId),
                ),
              ),
        ),
      ],
    ),
    body: ref
        .watch(projectEngineeringSystemsProvider(projectId))
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Unable to load systems: $e')),
          data: (snapshot) {
            if (snapshot.project == null)
              return const Center(child: Text('Project is unavailable.'));
            final repo = ref.read(engineeringSystemRepositoryProvider);
            return EngineeringSystemsWorkspace(
              snapshot: snapshot,
              nextId: ref.read(idGeneratorProvider).next,
              onSave: repo.saveSystem,
              onFamily: repo.saveFamily,
              onAssign: (m) => repo.assign(projectId, m),
              onDetach: (s, c) => repo.detach(projectId, s, c),
              onArchive: (s) => repo.archiveSystem(projectId, s),
            );
          },
        ),
  );
}

class EngineeringSystemsWorkspace extends StatefulWidget {
  const EngineeringSystemsWorkspace({
    super.key,
    required this.snapshot,
    required this.nextId,
    required this.onSave,
    required this.onFamily,
    required this.onAssign,
    required this.onDetach,
    required this.onArchive,
  });
  final ProjectEngineeringSystemsSnapshot snapshot;
  final String Function() nextId;
  final Future<void> Function(EngineeringSystem) onSave;
  final Future<void> Function(EngineeringSystemFamily) onFamily;
  final Future<void> Function(ComponentSystemMembership) onAssign;
  final Future<void> Function(String, String) onDetach;
  final Future<void> Function(String) onArchive;
  @override
  State<EngineeringSystemsWorkspace> createState() =>
      _EngineeringSystemsWorkspaceState();
}

class _EngineeringSystemsWorkspaceState
    extends State<EngineeringSystemsWorkspace> {
  bool busy = false;
  String? error;
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

  void edit([EngineeringSystem? system]) => showDialog<void>(
    context: context,
    builder:
        (_) => EngineeringSystemDialog(
          snapshot: widget.snapshot,
          id: system?.id ?? widget.nextId(),
          initial: system,
          onSave: widget.onSave,
        ),
  );
  void assign(EngineeringSystem system) => showDialog<void>(
    context: context,
    builder:
        (_) => SystemMembershipDialog(
          snapshot: widget.snapshot,
          system: system,
          onSave: widget.onAssign,
        ),
  );
  @override
  Widget build(BuildContext context) {
    final s = widget.snapshot;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 8,
          children: [
            FilledButton(
              onPressed: busy || s.families.isEmpty ? null : () => edit(),
              child: const Text('New system'),
            ),
            OutlinedButton(
              onPressed:
                  busy
                      ? null
                      : () => showDialog<void>(
                        context: context,
                        builder:
                            (_) => EngineeringFamilyDialog(
                              id: widget.nextId(),
                              onSave: widget.onFamily,
                            ),
                      ),
              child: const Text('New family edition'),
            ),
          ],
        ),
        const Text(
          'A placed device can participate in several systems. Assignments reuse its physical identity. Manage ports and connections from Ports / topology. Discipline calculations and room-editor system visibility are subsequent stages.',
        ),
        if (error != null)
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (s.systems.isEmpty)
          const Text(
            'Create the first project network: CCTV, LAN, access control, fire alarm or another catalog family.',
          ),
        if (s.archivedSystems.isNotEmpty)
          ExpansionTile(
            title: const Text('Archived systems'),
            children: [
              for (final system in s.archivedSystems)
                ListTile(
                  title: Text('${system.code} · ${system.name}'),
                  trailing: TextButton(
                    onPressed:
                        busy ? null : () => work(() => widget.onSave(system)),
                    child: const Text('Restore system'),
                  ),
                ),
            ],
          ),
        for (final system in s.systems)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${system.code} · ${system.name}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    '${s.families.firstWhere((f) => f.id == system.familyId).name} · edition ${system.familyVersion}',
                  ),
                  Text(
                    'Normative profile: ${system.normativeProfile == null ? 'not assigned' : '${system.normativeProfile!.id} · ${system.normativeProfile!.version}'}',
                  ),
                  const Text(
                    'Profile references are recorded; no ELV compliance calculation is enabled yet.',
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: busy ? null : () => edit(system),
                        child: const Text('Edit system'),
                      ),
                      TextButton(
                        onPressed:
                            busy || s.components.isEmpty
                                ? null
                                : () => assign(system),
                        child: const Text('Assign placed device'),
                      ),
                      TextButton(
                        onPressed:
                            busy
                                ? null
                                : () => work(() => widget.onArchive(system.id)),
                        child: const Text('Archive system'),
                      ),
                    ],
                  ),
                  for (final m in s.memberships.where(
                    (m) => m.systemId == system.id,
                  ))
                    Builder(
                      builder: (context) {
                        final c =
                            s.components
                                .where((c) => c.id == m.componentId)
                                .firstOrNull;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            c?.name ?? 'Unavailable device ${m.componentId}',
                          ),
                          subtitle: Text(
                            '${c?.roomName ?? 'Placement archived'} · ${m.role}',
                          ),
                          trailing: IconButton(
                            tooltip: 'Detach from this system',
                            icon: const Icon(Icons.link_off),
                            onPressed:
                                busy
                                    ? null
                                    : () => work(
                                      () => widget.onDetach(
                                        system.id,
                                        m.componentId,
                                      ),
                                    ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class EngineeringSystemDialog extends StatefulWidget {
  const EngineeringSystemDialog({
    super.key,
    required this.snapshot,
    required this.id,
    required this.onSave,
    this.initial,
  });
  final ProjectEngineeringSystemsSnapshot snapshot;
  final String id;
  final EngineeringSystem? initial;
  final Future<void> Function(EngineeringSystem) onSave;
  @override
  State<EngineeringSystemDialog> createState() =>
      _EngineeringSystemDialogState();
}

class _EngineeringSystemDialogState extends State<EngineeringSystemDialog> {
  final fields = <String, TextEditingController>{};
  late String familyId;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    final s = widget.initial;
    familyId = s?.familyId ?? widget.snapshot.families.first.id;
    final values = {
      'Code': s?.code,
      'Name': s?.name,
      'Normative profile ID (optional)': s?.normativeProfile?.id,
      'Normative profile version': s?.normativeProfile?.version,
      'Topology profile ID (optional)': s?.topologyProfile?.id,
      'Topology profile version': s?.topologyProfile?.version,
    };
    for (final e in values.entries) {
      fields[e.key] = TextEditingController(text: e.value ?? '');
    }
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      EngineeringProfileReference? profile(String kind) {
        final id = fields['$kind profile ID (optional)']!.text.trim(),
            version = fields['$kind profile version']!.text.trim();
        if (id.isEmpty && version.isEmpty) return null;
        return EngineeringProfileReference(id: id, version: version);
      }

      final family = widget.snapshot.families.firstWhere(
        (f) => f.id == familyId,
      );
      final s = EngineeringSystem(
        id: widget.id,
        projectId: widget.snapshot.project!.id,
        code: fields['Code']!.text.trim(),
        name: fields['Name']!.text.trim(),
        familyId: family.id,
        familyVersion: family.version,
        normativeProfile: profile('Normative'),
        topologyProfile: profile('Topology'),
      );
      if (s.validate().isNotEmpty) throw ArgumentError(s.validate().join(' '));
      await widget.onSave(s);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Project engineering system'),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: familyId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Family edition'),
              items: [
                for (final f in widget.snapshot.families)
                  DropdownMenuItem(
                    value: f.id,
                    child: Text('${f.name} · ${f.version}'),
                  ),
              ],
              onChanged: busy ? null : (v) => setState(() => familyId = v!),
            ),
            for (final e in fields.entries)
              TextField(
                controller: e.value,
                enabled: !busy,
                decoration: InputDecoration(labelText: e.key),
              ),
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: busy ? null : save,
        child: const Text('Save system'),
      ),
    ],
  );
}

class SystemMembershipDialog extends StatefulWidget {
  const SystemMembershipDialog({
    super.key,
    required this.snapshot,
    required this.system,
    required this.onSave,
  });
  final ProjectEngineeringSystemsSnapshot snapshot;
  final EngineeringSystem system;
  final Future<void> Function(ComponentSystemMembership) onSave;
  @override
  State<SystemMembershipDialog> createState() => _SystemMembershipDialogState();
}

class _SystemMembershipDialogState extends State<SystemMembershipDialog> {
  late String componentId;
  final role = TextEditingController();
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    componentId = widget.snapshot.components.first.id;
  }

  @override
  void dispose() {
    role.dispose();
    super.dispose();
  }

  Future<void> save() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final membership = ComponentSystemMembership(
        systemId: widget.system.id,
        componentId: componentId,
        role: role.text.trim(),
      );
      if (membership.validate().isNotEmpty)
        throw ArgumentError(membership.validate().join(' '));
      await widget.onSave(membership);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Assign to ${widget.system.code}'),
    content: SizedBox(
      width: 520,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: componentId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Existing placed device',
            ),
            items: [
              for (final c in widget.snapshot.components)
                DropdownMenuItem(
                  value: c.id,
                  child: Text(
                    '${c.roomName} · ${c.name}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: busy ? null : (v) => setState(() => componentId = v!),
          ),
          TextField(
            controller: role,
            enabled: !busy,
            decoration: const InputDecoration(labelText: 'Participation role'),
          ),
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: busy ? null : save,
        child: const Text('Assign device'),
      ),
    ],
  );
}

class EngineeringFamilyDialog extends StatefulWidget {
  const EngineeringFamilyDialog({
    super.key,
    required this.id,
    required this.onSave,
  });
  final String id;
  final Future<void> Function(EngineeringSystemFamily) onSave;
  @override
  State<EngineeringFamilyDialog> createState() =>
      _EngineeringFamilyDialogState();
}

class _EngineeringFamilyDialogState extends State<EngineeringFamilyDialog> {
  final fields = {
    for (final key in ['Code', 'Name', 'Version', 'Source', 'Routing class'])
      key: TextEditingController(),
  };
  bool busy = false;
  String? error;
  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      String v(String key) => fields[key]!.text.trim();
      final f = EngineeringSystemFamily(
        id: widget.id,
        code: v('Code'),
        name: v('Name'),
        version: v('Version'),
        source: v('Source'),
        routingClass: v('Routing class'),
      );
      if (f.validate().isNotEmpty) throw ArgumentError(f.validate().join(' '));
      await widget.onSave(f);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('New family edition'),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final e in fields.entries)
              TextField(
                controller: e.value,
                enabled: !busy,
                decoration: InputDecoration(labelText: e.key),
              ),
            if (error != null) Text(error!),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: busy ? null : save,
        child: const Text('Save family'),
      ),
    ],
  );
}
