import 'package:engineering_core/engineering_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../application/panel_generation_repository.dart';
import 'protection_screen.dart';

class PanelGenerationScreen extends ConsumerWidget {
  const PanelGenerationScreen({super.key, required this.projectId});
  final String projectId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Panel structure')),
    body: ref
        .watch(projectPanelGenerationProvider(projectId))
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Unable to load panels: $e')),
          data: (snapshot) {
            if (snapshot.protection.recalculation.project == null)
              return const Center(child: Text('Project is unavailable.'));
            final repo = ref.read(panelGenerationRepositoryProvider);
            return PanelGenerationWorkspace(
              snapshot: snapshot,
              nextId: ref.read(idGeneratorProvider).next,
              onSave: repo.save,
              onRecalculate: () => repo.recalculate(projectId),
              onConfirm:
                  (id, fingerprint) => repo.confirm(projectId, id, fingerprint),
              onRules:
                  () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ProtectionScreen(projectId: projectId),
                    ),
                  ),
            );
          },
        ),
  );
}

class PanelGenerationWorkspace extends StatefulWidget {
  const PanelGenerationWorkspace({
    super.key,
    required this.snapshot,
    required this.nextId,
    required this.onSave,
    required this.onRecalculate,
    required this.onConfirm,
    required this.onRules,
  });
  final ProjectPanelGenerationSnapshot snapshot;
  final String Function() nextId;
  final Future<void> Function(PanelGenerationPolicy) onSave;
  final Future<void> Function() onRecalculate;
  final Future<void> Function(String, String) onConfirm;
  final VoidCallback onRules;
  @override
  State<PanelGenerationWorkspace> createState() =>
      _PanelGenerationWorkspaceState();
}

class _PanelGenerationWorkspaceState extends State<PanelGenerationWorkspace> {
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

  void edit([PanelGenerationPolicy? policy]) => showDialog<void>(
    context: context,
    builder:
        (_) => PanelPolicyDialog(
          snapshot: widget.snapshot,
          id: policy?.id ?? widget.nextId(),
          initial: policy,
          onSave: widget.onSave,
        ),
  );
  @override
  Widget build(BuildContext context) {
    final s = widget.snapshot, session = s.protection.recalculation.session;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 8,
          children: [
            FilledButton(
              onPressed:
                  busy || s.floors.isEmpty || s.protection.rulesets.isEmpty
                      ? null
                      : () => edit(),
              child: const Text('New panel policy'),
            ),
            OutlinedButton(
              onPressed: busy ? null : () => work(widget.onRecalculate),
              child: const Text('Recalculate'),
            ),
            TextButton(
              onPressed: widget.onRules,
              child: const Text('Rules / Normatives'),
            ),
          ],
        ),
        const Text(
          'One generated panel per floor. All active floor groups are included. Common outgoing protection conditions must be verified for every proposed circuit.',
        ),
        if (s.protection.rulesets.isEmpty)
          const Text('Create a versioned protection ruleset first.'),
        if (error != null)
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        for (final p in s.panels)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${p.policy.name} · ${s.status(p)}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    '${s.floors.firstWhere((f) => f.id == p.policy.floorId).name} · ${p.policy.phases} phases · rule ${p.policy.rulesetId}',
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: busy ? null : () => edit(p.policy),
                        child: const Text('Edit policy'),
                      ),
                      OutlinedButton(
                        onPressed:
                            busy ||
                                    ![
                                      'Proposed',
                                      'Review required',
                                    ].contains(s.status(p))
                                ? null
                                : () => work(
                                  () => widget.onConfirm(
                                    p.policy.id,
                                    session.fingerprints[p.key]!,
                                  ),
                                ),
                        child: const Text('Confirm proposal'),
                      ),
                    ],
                  ),
                  if (session.cache[p.key] != null)
                    PanelProposalDetails(
                      values: session.cache[p.key]!.proposal.values,
                      stale: s.status(p) == 'Stale',
                    ),
                ],
              ),
            ),
          ),
        if (s.panels.isEmpty)
          const Text(
            'No panel proposal yet. Configure the floor supply, protection evidence and reserve policy.',
          ),
      ],
    );
  }
}

class PanelProposalDetails extends StatelessWidget {
  const PanelProposalDetails({
    super.key,
    required this.values,
    required this.stale,
  });
  final Map<String, Object?> values;
  final bool stale;
  @override
  Widget build(BuildContext context) {
    final circuits = (values['circuits'] as List?) ?? [],
        incoming = values['incoming'] as Map?;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (stale) const Text('Previous proposal. Recalculate before use.'),
        Text('Incoming → distribution → ${circuits.length} outgoing circuits'),
        Text(
          'Incoming: Ib ${values['incomingDesignCurrentA'] ?? '—'} A · ${incoming?['role'] ?? '—'} ${incoming?['ratedCurrentA'] ?? '—'} A',
        ),
        Text('Phase currents: ${values['phaseCurrentsA'] ?? 'unavailable'}'),
        Text(
          'Modules: ${values['estimatedModuleCount'] ?? 'widths needed'} + reserve ${values['recommendedSpareModules'] ?? '—'} = ${values['recommendedCapacityModules'] ?? '—'}',
        ),
        const Text(
          'Recommended module capacity only. Physical enclosure dimensions follow in FL16.',
        ),
        for (final item in circuits)
          Builder(
            builder: (context) {
              final c = item as Map, protection = c['protection'] as Map;
              return ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                  '${c['name']} · ${c['phase']} · ${c['designCurrentA'] ?? '—'} A',
                ),
                subtitle: Text(
                  '${protection['role'] ?? 'needs input'} ${protection['ratedCurrentA'] ?? '—'} A · ${protection['poles'] ?? '—'} poles${c['dedicated'] == true ? ' · dedicated' : ''}',
                ),
                children: [
                  ListTile(
                    title: Text(
                      'Group: ${c['sourceGroupId']}\nLoads: ${(c['loadIds'] as List).join(', ')}',
                    ),
                    subtitle: Text(
                      [
                        ...(c['reasons'] as List),
                        ...(protection['reasons'] as List),
                        for (final e in (c['currentEvidence'] as List?) ?? [])
                          '${(e as Map)['loadId']}: ${e['currentA']} A · ${e['formula']}',
                      ].join('\n'),
                    ),
                  ),
                ],
              );
            },
          ),
        for (final issue in (values['inputIssues'] as List?) ?? [])
          Text(
            '$issue',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ExpansionTile(
          title: const Text('Sources and limitations'),
          children: [
            Text(
              'Ruleset: ${(values['ruleset'] as Map?)?['ruleId'] ?? '—'} · ${(values['ruleset'] as Map?)?['version'] ?? '—'}\nSource: ${(values['normativeDocument'] as Map?)?['standardCode'] ?? '—'} · ${(values['normativeDocument'] as Map?)?['version'] ?? '—'}\n${(values['normativeDocument'] as Map?)?['source'] ?? ''}',
            ),
            for (final warning in (values['warnings'] as List?) ?? [])
              Text('$warning'),
          ],
        ),
      ],
    );
  }
}

class PanelPolicyDialog extends StatefulWidget {
  const PanelPolicyDialog({
    super.key,
    required this.snapshot,
    required this.id,
    required this.onSave,
    this.initial,
  });
  final ProjectPanelGenerationSnapshot snapshot;
  final String id;
  final PanelGenerationPolicy? initial;
  final Future<void> Function(PanelGenerationPolicy) onSave;
  @override
  State<PanelPolicyDialog> createState() => _PanelPolicyDialogState();
}

class _PanelPolicyDialogState extends State<PanelPolicyDialog> {
  final fields = <String, TextEditingController>{};
  late String floorId, ruleId;
  late int phases;
  late ResidualProtectionPolicy residual, incomingResidual;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    floorId = p?.floorId ?? widget.snapshot.floors.first.id;
    ruleId = p?.rulesetId ?? widget.snapshot.protection.rulesets.first.id;
    phases = p?.phases ?? 1;
    residual =
        p?.outgoing.residualPolicy ?? ResidualProtectionPolicy.undetermined;
    incomingResidual =
        p?.incoming.residualPolicy ?? ResidualProtectionPolicy.undetermined;
    final initial = <String, Object?>{
      'Name': p?.name,
      'Phase voltage V': p?.phaseVoltageV,
      'Line voltage V': p?.lineVoltageV,
      'Demand factor': p?.demandFactor,
      'Reserve percent of occupied modules': p?.reservePercent,
      'Minimum spare modules': p?.minimumSpareModules,
      'Outgoing Iz A': p?.outgoing.allowableCurrentA,
      'Outgoing fault kA': p?.outgoing.prospectiveFaultKa,
      'Outgoing poles': p?.outgoing.poles,
      'Outgoing curve': p?.outgoing.tripCurve,
      'Residual trip mA': p?.outgoing.residualCurrentMa,
      'Residual type': p?.outgoing.residualType,
      'Outgoing evidence': p?.outgoing.evidence,
      'Incoming Iz A': p?.incoming.allowableCurrentA,
      'Incoming fault kA': p?.incoming.prospectiveFaultKa,
      'Incoming poles': p?.incoming.poles,
      'Incoming curve': p?.incoming.tripCurve,
      'Incoming evidence': p?.incoming.evidence,
      'Incoming residual trip mA': p?.incoming.residualCurrentMa,
      'Incoming residual type': p?.incoming.residualType,
      'Outgoing module width':
          p?.moduleWidths['${p.outgoing.residualPolicy == ResidualProtectionPolicy.required ? 'rcbo' : 'mcb'}:${p.outgoing.poles}'],
      'Incoming module width':
          p?.moduleWidths['${p.incoming.residualPolicy == ResidualProtectionPolicy.required ? 'rcbo' : 'mcb'}:${p.incoming.poles}'],
    };
    for (final e in initial.entries) {
      fields[e.key] = TextEditingController(text: e.value?.toString() ?? '');
    }
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  String value(String key) => fields[key]!.text.trim();
  double number(String key) => double.parse(value(key));
  int integer(String key) => int.parse(value(key));
  Future<void> save() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      CircuitProtectionInputs settings(String prefix) =>
          CircuitProtectionInputs(
            circuitId: '${widget.id}:$prefix',
            rulesetId: ruleId,
            allowableCurrentA: number('$prefix Iz A'),
            prospectiveFaultKa: number('$prefix fault kA'),
            poles: integer('$prefix poles'),
            tripCurve: value('$prefix curve'),
            residualPolicy: prefix == 'Outgoing' ? residual : incomingResidual,
            residualCurrentMa:
                (prefix == 'Outgoing' ? residual : incomingResidual) ==
                        ResidualProtectionPolicy.required
                    ? number(
                      prefix == 'Outgoing'
                          ? 'Residual trip mA'
                          : 'Incoming residual trip mA',
                    )
                    : null,
            residualType:
                (prefix == 'Outgoing' ? residual : incomingResidual) ==
                        ResidualProtectionPolicy.required
                    ? value(
                      prefix == 'Outgoing'
                          ? 'Residual type'
                          : 'Incoming residual type',
                    )
                    : null,
            evidence: value('$prefix evidence'),
          );
      final outgoing = settings('Outgoing'), incoming = settings('Incoming');
      final widths = <String, int>{...widget.initial?.moduleWidths ?? {}};
      void width(String key, String field) {
        if (value(field).isNotEmpty) {
          widths[key] = integer(field);
        } else {
          widths.remove(key);
        }
      }

      width(
        '${residual == ResidualProtectionPolicy.required ? 'rcbo' : 'mcb'}:${outgoing.poles}',
        'Outgoing module width',
      );
      final incomingKey =
          '${incomingResidual == ResidualProtectionPolicy.required ? 'rcbo' : 'mcb'}:${incoming.poles}';
      if (incomingKey ==
              '${residual == ResidualProtectionPolicy.required ? 'rcbo' : 'mcb'}:${outgoing.poles}' &&
          value('Incoming module width') != value('Outgoing module width'))
        throw ArgumentError(
          'Same role and poles require one consistent module width.',
        );
      width(incomingKey, 'Incoming module width');
      final policy = PanelGenerationPolicy(
        id: widget.id,
        projectId: widget.snapshot.protection.recalculation.project!.id,
        floorId: floorId,
        name: value('Name'),
        rulesetId: ruleId,
        phases: phases,
        phaseVoltageV: number('Phase voltage V'),
        lineVoltageV: number('Line voltage V'),
        demandFactor: number('Demand factor'),
        reservePercent: number('Reserve percent of occupied modules'),
        minimumSpareModules: integer('Minimum spare modules'),
        moduleWidths: widths,
        outgoing: outgoing,
        incoming: incoming,
      );
      final issues = policy.validate();
      if (issues.isNotEmpty) throw ArgumentError(issues.join(' '));
      await widget.onSave(policy);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Panel generation policy'),
    content: SizedBox(
      width: 540,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: floorId,
              decoration: const InputDecoration(labelText: 'Floor'),
              items: [
                for (final f in widget.snapshot.floors)
                  DropdownMenuItem(value: f.id, child: Text(f.name)),
              ],
              onChanged:
                  widget.initial != null || busy
                      ? null
                      : (v) => setState(() => floorId = v!),
            ),
            DropdownButtonFormField<String>(
              initialValue: ruleId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Ruleset'),
              items: [
                for (final r in widget.snapshot.protection.rulesets)
                  DropdownMenuItem(
                    value: r.id,
                    child: Text('${r.reference.id} · ${r.reference.version}'),
                  ),
              ],
              onChanged: busy ? null : (v) => setState(() => ruleId = v!),
            ),
            DropdownButtonFormField<int>(
              initialValue: phases,
              decoration: const InputDecoration(labelText: 'Panel phases'),
              items: [
                for (final p in [1, 3])
                  DropdownMenuItem(value: p, child: Text('$p')),
              ],
              onChanged: busy ? null : (v) => setState(() => phases = v!),
            ),
            const Text(
              'All outgoing circuits share the declared protection conditions. Verify these conditions for every proposed circuit. Declare incoming and outgoing residual policies explicitly.',
            ),
            DropdownButtonFormField<ResidualProtectionPolicy>(
              initialValue: residual,
              decoration: const InputDecoration(
                labelText: 'Outgoing residual protection',
              ),
              items: [
                for (final p in ResidualProtectionPolicy.values)
                  DropdownMenuItem(value: p, child: Text(p.name)),
              ],
              onChanged: busy ? null : (v) => setState(() => residual = v!),
            ),
            DropdownButtonFormField<ResidualProtectionPolicy>(
              initialValue: incomingResidual,
              decoration: const InputDecoration(
                labelText: 'Incoming residual protection',
              ),
              items: [
                for (final p in ResidualProtectionPolicy.values)
                  DropdownMenuItem(value: p, child: Text(p.name)),
              ],
              onChanged:
                  busy ? null : (v) => setState(() => incomingResidual = v!),
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
        child: Text(busy ? 'Saving…' : 'Save and generate'),
      ),
    ],
  );
}
