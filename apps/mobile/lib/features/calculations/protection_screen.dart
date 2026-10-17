import 'package:engineering_core/engineering_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../application/protection_repository.dart';
import 'project_recalculation_screen.dart';
import 'manufacturer_screen.dart';

class ProtectionScreen extends ConsumerWidget {
  const ProtectionScreen({super.key, required this.projectId});
  final String projectId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(
      title: const Text('Protection / Normative catalog'),
      actions: [
        IconButton(
          tooltip: 'Manufacturer catalogs',
          icon: const Icon(Icons.inventory_2_outlined),
          onPressed:
              () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ManufacturerScreen(projectId: projectId),
                ),
              ),
        ),
      ],
    ),
    body: ref
        .watch(projectProtectionProvider(projectId))
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error:
              (error, _) =>
                  Center(child: Text('Unable to load protection: $error')),
          data: (snapshot) {
            if (snapshot.recalculation.project == null)
              return const Center(child: Text('Project is unavailable.'));
            final repo = ref.read(protectionRepositoryProvider);
            return ProtectionWorkspace(
              snapshot: snapshot,
              nextId: ref.read(idGeneratorProvider).next,
              onSaveDocument: repo.saveDocument,
              onSaveRuleset: repo.saveRuleset,
              onSaveSettings:
                  (settings) => repo.saveSettings(projectId, settings),
              onRecalculate: () => repo.recalculate(projectId),
              onConfirm:
                  (id, fingerprint) => repo.confirm(projectId, id, fingerprint),
              onChanges:
                  () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder:
                          (_) =>
                              ProjectRecalculationScreen(projectId: projectId),
                    ),
                  ),
            );
          },
        ),
  );
}

class ProtectionWorkspace extends StatefulWidget {
  const ProtectionWorkspace({
    super.key,
    required this.snapshot,
    required this.nextId,
    required this.onSaveDocument,
    required this.onSaveRuleset,
    required this.onSaveSettings,
    required this.onRecalculate,
    required this.onConfirm,
    required this.onChanges,
  });
  final ProjectProtectionSnapshot snapshot;
  final String Function() nextId;
  final Future<void> Function(NormativeDocument) onSaveDocument;
  final Future<void> Function(ProtectionRuleset) onSaveRuleset;
  final Future<void> Function(CircuitProtectionInputs) onSaveSettings;
  final Future<void> Function() onRecalculate;
  final Future<void> Function(String, String) onConfirm;
  final VoidCallback onChanges;
  @override
  State<ProtectionWorkspace> createState() => _ProtectionWorkspaceState();
}

class _ProtectionWorkspaceState extends State<ProtectionWorkspace> {
  bool busy = false;
  String? error;
  Future<void> action(Future<void> Function() work) async {
    setState(() => busy = true);
    try {
      await work();
      if (mounted) setState(() => error = null);
    } catch (failure) {
      if (mounted) setState(() => error = '$failure');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> edit(String kind, {CircuitProtectionView? circuit}) =>
      showDialog<void>(
        context: context,
        builder:
            (_) => ProtectionInputDialog(
              kind: kind,
              snapshot: widget.snapshot,
              id: widget.nextId(),
              circuit: circuit,
              onSaveDocument: widget.onSaveDocument,
              onSaveRuleset: widget.onSaveRuleset,
              onSaveSettings: widget.onSaveSettings,
            ),
      );
  @override
  Widget build(BuildContext context) {
    final snapshot = widget.snapshot;
    return DefaultTabController(
      length: 3,
      initialIndex: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Normatives'),
              Tab(text: 'Rulesets'),
              Tab(text: 'Circuits'),
            ],
          ),
          if (error != null)
            Text(error!, style: const TextStyle(color: Colors.red)),
          Expanded(
            child: TabBarView(
              children: [
                ListView(
                  key: const ValueKey('normative-list'),
                  padding: const EdgeInsets.all(12),
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => edit('document'),
                      icon: const Icon(Icons.library_books),
                      label: const Text('Add document edition'),
                    ),
                    const Text(
                      'Versioned references and curated criteria. National applicability is explicit; IEC metadata does not imply a complete executable national ruleset.',
                    ),
                    for (final doc in snapshot.documents)
                      Card(
                        child: ExpansionTile(
                          title: Text('${doc.standardCode} · ${doc.version}'),
                          subtitle: Text(
                            '${doc.kind.name} · ${doc.jurisdiction}',
                          ),
                          expandedCrossAxisAlignment: CrossAxisAlignment.start,
                          childrenPadding: const EdgeInsets.all(12),
                          children: [
                            Text(doc.title),
                            Text('Publisher: ${doc.publisher}'),
                            SelectableText(doc.source),
                            Text(
                              'Section: ${doc.clauseReference.isEmpty ? "Not curated" : doc.clauseReference}',
                            ),
                            Text(
                              'Executable criteria: ${doc.criteria.map((c) => c.name).join(", ")}',
                            ),
                            Text(doc.notes),
                          ],
                        ),
                      ),
                  ],
                ),
                ListView(
                  key: const ValueKey('ruleset-list'),
                  padding: const EdgeInsets.all(12),
                  children: [
                    FilledButton(
                      onPressed: () => edit('ruleset'),
                      child: const Text('New ruleset version'),
                    ),
                    const Text(
                      'Project rating options reference a catalog document. Existing editions and ruleset versions are immutable.',
                    ),
                    for (final r in snapshot.rulesets)
                      Card(
                        child: ListTile(
                          title: Text(
                            '${r.reference.id} · ${r.reference.version}',
                          ),
                          subtitle: Text(
                            '${r.reference.standardCode}\nAllowed currents: ${r.nominalCurrentsA.join(", ")} A\nCatalog: ${snapshot.documents.where((d) => d.id == r.normativeDocumentId).firstOrNull?.version ?? "Unavailable"}',
                          ),
                        ),
                      ),
                  ],
                ),
                ListView(
                  key: const ValueKey('protection-list'),
                  padding: const EdgeInsets.all(12),
                  children: [
                    Text(
                      snapshot.recalculation.project!.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed:
                              busy ? null : () => action(widget.onRecalculate),
                          icon: const Icon(Icons.calculate),
                          label: Text(
                            busy ? 'Recalculating…' : 'Recalculate protection',
                          ),
                        ),
                        TextButton(
                          onPressed: widget.onChanges,
                          child: const Text('What changed?'),
                        ),
                      ],
                    ),
                    if (snapshot.circuits.isEmpty)
                      const Text('Create a circuit with assigned loads first.'),
                    for (final c in snapshot.circuits)
                      Card(
                        child: ExpansionTile(
                          key: ValueKey(c.circuitId),
                          title: Text(c.label),
                          subtitle: Text(c.status),
                          childrenPadding: const EdgeInsets.all(12),
                          expandedCrossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.stale
                                  ? 'Previous proposal · recalculation required'
                                  : 'Functional protection requirement',
                            ),
                            if (c.checkpoint == null)
                              const Text('No saved proposal yet.')
                            else
                              ..._proposal(c.checkpoint!.proposal.values),
                            if (c.checkpoint != null)
                              for (final issue in c.checkpoint!.proposal.issues)
                                Text(
                                  issue,
                                  style: const TextStyle(color: Colors.red),
                                ),
                            Wrap(
                              spacing: 8,
                              children: [
                                OutlinedButton(
                                  onPressed: () => edit('settings', circuit: c),
                                  child: const Text('Edit protection inputs'),
                                ),
                                FilledButton(
                                  onPressed:
                                      busy ||
                                              c.stale ||
                                              c
                                                      .checkpoint
                                                      ?.proposal
                                                      .values['proposalState'] !=
                                                  'proposed' ||
                                              snapshot.recalculation.session.state(
                                                    'protection:${c.circuitId}',
                                                  ) !=
                                                  EngineeringDerivedState
                                                      .current
                                          ? null
                                          : () => action(
                                            () => widget.onConfirm(
                                              c.circuitId,
                                              c.fingerprint,
                                            ),
                                          ),
                                  child: const Text(
                                    'Confirm functional requirement',
                                  ),
                                ),
                              ],
                            ),
                            const Text(
                              'Confirmation acknowledges this functional proposal; it does not validate installation compliance or select a manufacturer product.',
                            ),
                          ],
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

  List<Widget> _proposal(Map<String, Object?> p) {
    final inputs = p['inputs'] as Map?;
    final doc = inputs?['normativeDocument'] as Map?;
    final rule = p['ruleset'] as Map?;
    return [
      if (p['role'] != null)
        Text(
          '${p["role"]} · In ${p["ratedCurrentA"]} A · ${p["poles"]} poles · ${p["tripCurve"]}',
        ),
      Text(
        'Ib: ${inputs?["designCurrentA"] ?? "—"} A · Iz: ${inputs?["allowableCurrentA"] ?? "—"} A',
      ),
      if (p['breakingCapacityKa'] != null)
        Text('Minimum breaking capacity: ${p["breakingCapacityKa"]} kA'),
      if (p['residualCurrentMa'] != null)
        Text('Residual: ${p["residualCurrentMa"]} mA · ${p["residualType"]}'),
      if (rule != null) Text('Ruleset: ${rule["ruleId"]} · ${rule["version"]}'),
      if (doc != null) ...[
        Text('Normative catalog: ${doc["standardCode"]} · ${doc["version"]}'),
        Text('Section: ${doc["clauseReference"]}'),
        SelectableText(doc['source'] as String),
      ],
      const Text('Reasons', style: TextStyle(fontWeight: FontWeight.bold)),
      for (final reason in p['reasons'] as List? ?? []) Text(reason as String),
      const Text(
        'Warnings / missing inputs',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      for (final warning in p['warnings'] as List? ?? [])
        Text(warning as String),
    ];
  }
}

/// Forms keep input drafts on validation or persistence failure.
class ProtectionInputDialog extends StatefulWidget {
  const ProtectionInputDialog({
    super.key,
    required this.kind,
    required this.snapshot,
    required this.id,
    required this.onSaveDocument,
    required this.onSaveRuleset,
    required this.onSaveSettings,
    this.circuit,
  });
  final String kind, id;
  final ProjectProtectionSnapshot snapshot;
  final CircuitProtectionView? circuit;
  final Future<void> Function(NormativeDocument) onSaveDocument;
  final Future<void> Function(ProtectionRuleset) onSaveRuleset;
  final Future<void> Function(CircuitProtectionInputs) onSaveSettings;
  @override
  State<ProtectionInputDialog> createState() => _ProtectionInputDialogState();
}

class _ProtectionInputDialogState extends State<ProtectionInputDialog> {
  final fields = <String, TextEditingController>{};
  String? documentId, rulesetId, error;
  NormativeDocumentKind documentKind = NormativeDocumentKind.standard;
  ResidualProtectionPolicy residual = ResidualProtectionPolicy.undetermined;
  bool curated = false, busy = false;
  @override
  void initState() {
    super.initState();
    final s = widget.circuit?.settings;
    rulesetId = s?.rulesetId;
    residual = s?.residualPolicy ?? residual;
    for (final entry
        in {
          'Iz': s?.allowableCurrentA?.toString() ?? '',
          'Fault kA': s?.prospectiveFaultKa?.toString() ?? '',
          'Poles': s?.poles?.toString() ?? '',
          'Curve': s?.tripCurve ?? '',
          'Residual mA': s?.residualCurrentMa?.toString() ?? '',
          'Residual type': s?.residualType ?? '',
          'Evidence': s?.evidence ?? '',
        }.entries) {
      fields[entry.key] = TextEditingController(text: entry.value);
    }
  }

  @override
  void dispose() {
    for (final c in fields.values) c.dispose();
    super.dispose();
  }

  String text(String name) => fields[name]?.text.trim() ?? '';
  Widget field(String name) => TextField(
    controller: fields.putIfAbsent(name, () => TextEditingController()),
    enabled: !busy,
    decoration: InputDecoration(labelText: name),
  );
  double? number(String name) {
    if (text(name).isEmpty) return null;
    final value = double.tryParse(text(name));
    if (value == null || !value.isFinite || value <= 0)
      throw ArgumentError('Enter a positive finite $name.');
    return value;
  }

  List<String> strings(String name) =>
      text(
        name,
      ).split(',').map((v) => v.trim()).where((v) => v.isNotEmpty).toList();
  Future<void> save() async {
    setState(() => busy = true);
    try {
      if (widget.kind == 'document') {
        final doc = NormativeDocument(
          id: widget.id,
          standardCode: text('Document code'),
          title: text('Title'),
          version: text('Edition'),
          jurisdiction: text('Jurisdiction'),
          publisher: text('Publisher'),
          source: text('Source reference'),
          kind: documentKind,
          criteria: curated ? NormativeCriterion.values : [],
          clauseReference: text('Clause / section'),
          notes: text('Notes'),
        );
        if (doc.validate().isNotEmpty)
          throw ArgumentError(doc.validate().join(' '));
        await widget.onSaveDocument(doc);
      } else if (widget.kind == 'ruleset') {
        final doc =
            widget.snapshot.documents
                .where((d) => d.id == documentId)
                .firstOrNull;
        if (doc == null) throw ArgumentError('Choose a catalog document.');
        final currents =
            strings('Allowed currents A').map((v) {
              final n = double.tryParse(v);
              if (n == null) throw ArgumentError('Invalid nominal current.');
              return n;
            }).toList();
        final rule = ProtectionRuleset(
          id: widget.id,
          projectId: widget.snapshot.recalculation.project!.id,
          normativeDocumentId: doc.id,
          reference: ElectricalRulesetRef(
            id: text('Rule code'),
            jurisdiction: doc.jurisdiction,
            standardCode: doc.standardCode,
            version: text('Rule version'),
            sourceReference: doc.source,
          ),
          nominalCurrentsA: currents,
          tripCurves: strings('Allowed curves'),
          residualTypes: strings('Allowed residual types'),
          minimumBreakingCapacityKa: number('Minimum breaking kA'),
        );
        if (rule.validate().isNotEmpty)
          throw ArgumentError(rule.validate().join(' '));
        await widget.onSaveRuleset(rule);
      } else {
        final poles =
            text('Poles').isEmpty ? null : int.tryParse(text('Poles'));
        if (text('Poles').isNotEmpty && poles == null)
          throw ArgumentError('Poles must be an integer.');
        final settings = CircuitProtectionInputs(
          circuitId: widget.circuit!.circuitId,
          rulesetId: rulesetId,
          allowableCurrentA: number('Iz'),
          prospectiveFaultKa: number('Fault kA'),
          poles: poles,
          tripCurve: text('Curve').isEmpty ? null : text('Curve'),
          residualPolicy: residual,
          residualCurrentMa:
              residual == ResidualProtectionPolicy.required
                  ? number('Residual mA')
                  : null,
          residualType:
              residual == ResidualProtectionPolicy.required &&
                      text('Residual type').isNotEmpty
                  ? text('Residual type')
                  : null,
          evidence: text('Evidence'),
        );
        if (settings.validate().isNotEmpty)
          throw ArgumentError(settings.validate().join(' '));
        await widget.onSaveSettings(settings);
      }
      if (mounted) Navigator.pop(context);
    } catch (failure) {
      if (mounted) setState(() => error = '$failure');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(switch (widget.kind) {
      'document' => 'Normative document edition',
      'ruleset' => 'Ruleset version',
      _ => 'Protection inputs',
    }),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.kind == 'document') ...[
              for (final name in [
                'Document code',
                'Title',
                'Edition',
                'Jurisdiction',
                'Publisher',
                'Source reference',
                'Clause / section',
                'Notes',
              ])
                field(name),
              DropdownButtonFormField<NormativeDocumentKind>(
                initialValue: documentKind,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Document kind'),
                items:
                    NormativeDocumentKind.values
                        .map(
                          (v) =>
                              DropdownMenuItem(value: v, child: Text(v.name)),
                        )
                        .toList(),
                onChanged:
                    busy ? null : (v) => setState(() => documentKind = v!),
              ),
              CheckboxListTile(
                title: const Text('Curated basic breaker criteria'),
                subtitle: const Text(
                  'Declare sourced overload-range and breaking-capacity criteria for this edition.',
                ),
                value: curated,
                onChanged: busy ? null : (v) => setState(() => curated = v!),
              ),
            ] else if (widget.kind == 'ruleset') ...[
              DropdownButtonFormField<String>(
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Normative catalog',
                ),
                items:
                    widget.snapshot.documents
                        .map(
                          (d) => DropdownMenuItem(
                            value: d.id,
                            child: Text(
                              '${d.standardCode} · ${d.version}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                onChanged: busy ? null : (v) => setState(() => documentId = v),
              ),
              for (final name in [
                'Rule code',
                'Rule version',
                'Allowed currents A',
                'Allowed curves',
                'Allowed residual types',
                'Minimum breaking kA',
              ])
                field(name),
              const Text(
                'Lists are comma-separated project options; source and jurisdiction come from the selected catalog entry.',
              ),
            ] else ...[
              DropdownButtonFormField<String>(
                initialValue:
                    widget.snapshot.rulesets.any((r) => r.id == rulesetId)
                        ? rulesetId
                        : null,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Ruleset'),
                items:
                    widget.snapshot.rulesets
                        .map(
                          (r) => DropdownMenuItem(
                            value: r.id,
                            child: Text(
                              '${r.reference.id} · ${r.reference.version}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                onChanged: busy ? null : (v) => setState(() => rulesetId = v),
              ),
              for (final name in ['Iz', 'Fault kA', 'Poles', 'Curve'])
                field(name),
              DropdownButtonFormField<ResidualProtectionPolicy>(
                initialValue: residual,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Residual policy'),
                items:
                    ResidualProtectionPolicy.values
                        .map(
                          (p) =>
                              DropdownMenuItem(value: p, child: Text(p.name)),
                        )
                        .toList(),
                onChanged: busy ? null : (v) => setState(() => residual = v!),
              ),
              if (residual == ResidualProtectionPolicy.required) ...[
                field('Residual mA'),
                field('Residual type'),
              ],
              field('Evidence'),
            ],
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red)),
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
        child: Text(busy ? 'Saving…' : 'Save'),
      ),
    ],
  );
}
