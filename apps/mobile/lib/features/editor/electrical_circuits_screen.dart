import 'package:engineering_core/engineering_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/system_component_catalog.dart';

String _supplyName(SupplySystem supply) => switch (supply) {
  SupplySystem.singlePhaseAc => 'Single-phase AC',
  SupplySystem.threePhaseAc => 'Balanced three-phase AC',
  SupplySystem.directCurrent => 'DC',
  SupplySystem.controlVoltage => 'Control voltage',
  SupplySystem.custom => 'Custom',
};

class ElectricalCircuitsScreen extends ConsumerWidget {
  const ElectricalCircuitsScreen({
    super.key,
    required this.roomId,
    required this.roomName,
  });
  final String roomId;
  final String roomName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final circuits = ref.watch(roomElectricalCircuitsProvider(roomId));
    final loads = ref.watch(roomElectricalLoadsProvider(roomId));
    final groups = ref.watch(roomConsumptionGroupsProvider(roomId));
    final components = ref.watch(roomComponentsProvider(roomId));
    final states = [circuits, loads, groups, components];
    Widget body;
    if (states.any((value) => value.hasError)) {
      body = Center(
        child: Text(
          'Unable to load circuits: ${states.firstWhere((value) => value.hasError).error}',
        ),
      );
    } else if (states.any((value) => !value.hasValue)) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      final roomCircuits = circuits.requireValue;
      final roomLoads = loads.requireValue;
      final roomGroups = groups.requireValue;
      final definitions = {
        for (final definition in electricalSystemComponentLibrary.definitions)
          definition.id: definition.displayName,
      };
      final titles = {
        for (final component in components.requireValue)
          component.id:
              component.displayNameOverride ??
              definitions[component.definitionId] ??
              component.definitionId,
      };
      final assignments = {
        for (final snapshot in roomCircuits)
          for (final id in snapshot.circuit.loadIds) id: snapshot.circuit.id,
      };
      Future<void> openEditor({
        CircuitSnapshot? existing,
        RoomConsumptionGroup? group,
      }) => showDialog<void>(
        context: context,
        builder:
            (_) => ElectricalCircuitDialog(
              circuitId:
                  existing?.circuit.id ?? ref.read(idGeneratorProvider).next(),
              roomId: roomId,
              existing: existing?.circuit,
              sourceGroup: group,
              loads: roomLoads,
              titles: titles,
              assignedCircuitIds: assignments,
              onSave: ref.read(electricalCircuitRepositoryProvider).saveCircuit,
            ),
      );
      body = ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => openEditor(),
                icon: const Icon(Icons.add),
                label: const Text('New circuit'),
              ),
              for (final group in roomGroups)
                OutlinedButton(
                  onPressed: () => openEditor(group: group),
                  child: Text('From ${group.name}'),
                ),
            ],
          ),
          if (roomCircuits.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Create a circuit or start from a consumption group.',
              ),
            ),
          for (final snapshot in roomCircuits)
            Card(
              child: ExpansionTile(
                title: Text(snapshot.circuit.name),
                subtitle: Text(
                  '${switch (snapshot.status) {
                    CircuitStatus.proposed => 'Proposed',
                    CircuitStatus.confirmed => 'Confirmed',
                    CircuitStatus.reviewRequired => 'Review required',
                  }} · ${snapshot.calculation.ready ? 'Ib ${snapshot.calculation.designCurrentA!.toStringAsFixed(2)} A' : 'Current needs input'}',
                ),
                childrenPadding: const EdgeInsets.all(16),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_supplyName(snapshot.circuit.inputs.supplySystem)} · ${snapshot.circuit.inputs.nominalVoltageV} V${snapshot.circuit.inputs.phases == 3 ? ' line-to-line' : ''}',
                  ),
                  Text(
                    'Demand factor kD = ${snapshot.circuit.inputs.demandFactor}',
                  ),
                  const Text(
                    'Ib = kD × sum of load-current magnitudes (conservative).',
                  ),
                  if (snapshot.circuit.sourceGroupId != null)
                    Text(
                      'Source group: ${roomGroups.where((group) => group.id == snapshot.circuit.sourceGroupId).map((group) => group.name).firstOrNull ?? snapshot.circuit.sourceGroupId}',
                    ),
                  if (snapshot.status == CircuitStatus.reviewRequired)
                    const Text(
                      'Inputs changed since confirmation. Review the updated proposal.',
                    ),
                  for (final issue in snapshot.calculation.issues)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '${issue.loadId == null ? '' : '${titles[issue.loadId] ?? issue.loadId}: '}${issue.message}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  for (final evidence in snapshot.calculation.evidence)
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text(
                        '${titles[evidence.loadId] ?? evidence.loadId}: ${evidence.currentA.toStringAsFixed(2)} A',
                      ),
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${evidence.formula}\n${evidence.inputs.entries.where((entry) => entry.value != null).map((entry) => '${entry.key}: ${entry.value}').join(' · ')}',
                          ),
                        ),
                      ],
                    ),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: () => openEditor(existing: snapshot),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit assignments'),
                      ),
                      FilledButton.tonal(
                        onPressed:
                            !snapshot.calculation.ready ||
                                    snapshot.status == CircuitStatus.confirmed
                                ? null
                                : () async {
                                  try {
                                    await ref
                                        .read(
                                          electricalCircuitRepositoryProvider,
                                        )
                                        .confirmCircuit(snapshot.circuit.id);
                                  } catch (error) {
                                    if (context.mounted)
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Unable to confirm: $error',
                                          ),
                                        ),
                                      );
                                  }
                                },
                        child: const Text('Confirm proposal'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text('$roomName · Circuits')),
      body: body,
    );
  }
}

class ElectricalCircuitDialog extends StatefulWidget {
  const ElectricalCircuitDialog({
    super.key,
    required this.circuitId,
    required this.roomId,
    required this.loads,
    required this.onSave,
    this.existing,
    this.sourceGroup,
    this.titles = const {},
    this.assignedCircuitIds = const {},
  });
  final String circuitId;
  final String roomId;
  final List<EquipmentElectricalLoad> loads;
  final Future<void> Function(ElectricalCircuit circuit) onSave;
  final ElectricalCircuit? existing;
  final RoomConsumptionGroup? sourceGroup;
  final Map<String, String> titles;
  final Map<String, String> assignedCircuitIds;
  @override
  State<ElectricalCircuitDialog> createState() =>
      _ElectricalCircuitDialogState();
}

class _ElectricalCircuitDialogState extends State<ElectricalCircuitDialog> {
  late final selected = {
    ...widget.existing?.loadIds ??
        widget.loads
            .where(
              (load) =>
                  widget.sourceGroup != null &&
                  load.consumptionGroupId == widget.sourceGroup!.id,
            )
            .map((load) => load.componentInstanceId),
  };
  late final initialProfile =
      widget.loads
          .where((load) => selected.contains(load.componentInstanceId))
          .firstOrNull
          ?.profile;
  late final name = TextEditingController(
    text:
        widget.existing?.name ??
        (widget.sourceGroup == null
            ? ''
            : '${widget.sourceGroup!.name} circuit'),
  );
  late final voltage = TextEditingController(
    text:
        '${widget.existing?.inputs.nominalVoltageV ?? initialProfile?.nominalVoltageV ?? 230}',
  );
  late final demand = TextEditingController(
    text: '${widget.existing?.inputs.demandFactor ?? 1}',
  );
  late SupplySystem supply =
      widget.existing?.inputs.supplySystem ??
      initialProfile?.supplySystem ??
      SupplySystem.singlePhaseAc;
  late int phases =
      widget.existing?.inputs.phases ?? initialProfile?.phases ?? 1;
  bool saving = false;
  String? error;

  @override
  void dispose() {
    name.dispose();
    voltage.dispose();
    demand.dispose();
    super.dispose();
  }

  ElectricalCircuit draft() => ElectricalCircuit(
    id: widget.circuitId,
    roomId: widget.roomId,
    name: name.text.trim(),
    sourceGroupId: widget.existing?.sourceGroupId ?? widget.sourceGroup?.id,
    inputs: ElectricalCircuitInputs(
      nominalVoltageV:
          double.tryParse(voltage.text.trim().replaceAll(',', '.')) ??
          double.nan,
      phases: phases,
      supplySystem: supply,
      demandFactor:
          double.tryParse(demand.text.trim().replaceAll(',', '.')) ??
          double.nan,
    ),
    loadIds: selected,
  );
  Future<void> save() async {
    if (saving) return;
    final circuit = draft();
    if (circuit.name.isEmpty || circuit.inputs.validate().isNotEmpty) {
      setState(
        () =>
            error =
                'Enter a name, positive voltage and demand factor above zero and at most one; match the phase count to the supply.',
      );
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.onSave(circuit);
      if (mounted) Navigator.of(context).pop();
    } catch (failure) {
      if (mounted) setState(() => error = 'Unable to save circuit: $failure');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final calculation = CircuitCurrentCalculator.calculate(
      draft(),
      widget.loads,
    );
    final availableIds =
        widget.loads.map((load) => load.componentInstanceId).toSet();
    return AlertDialog(
      title: Text(widget.existing == null ? 'New circuit' : 'Edit circuit'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: name,
                enabled: !saving,
                decoration: const InputDecoration(labelText: 'Circuit name'),
                onChanged: (_) => setState(() {}),
              ),
              DropdownButtonFormField<SupplySystem>(
                isExpanded: true,
                initialValue: supply,
                decoration: const InputDecoration(labelText: 'Supply system'),
                items:
                    SupplySystem.values
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(
                              _supplyName(value),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                onChanged:
                    saving
                        ? null
                        : (value) {
                          if (value != null)
                            setState(() {
                              supply = value;
                              phases =
                                  value == SupplySystem.threePhaseAc ? 3 : 1;
                            });
                        },
              ),
              DropdownButtonFormField<int>(
                isExpanded: true,
                key: ValueKey(phases),
                initialValue: phases,
                decoration: const InputDecoration(labelText: 'Phases'),
                items:
                    [1, 2, 3]
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text('$value'),
                          ),
                        )
                        .toList(),
                onChanged:
                    saving
                        ? null
                        : (value) {
                          if (value != null) setState(() => phases = value);
                        },
              ),
              TextField(
                controller: voltage,
                enabled: !saving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText:
                      phases == 3
                          ? 'Line-to-line voltage (V)'
                          : 'Nominal voltage (V)',
                ),
                onChanged: (_) => setState(() {}),
              ),
              TextField(
                controller: demand,
                enabled: !saving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Demand factor kD (above 0, up to 1)',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              const Text('Assigned loads'),
              if (widget.loads.isEmpty)
                const Text('Configure equipment loads first.'),
              for (final load in widget.loads)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    widget.titles[load.componentInstanceId] ??
                        load.componentInstanceId,
                  ),
                  subtitle: Text(
                    '${load.profile.nominalVoltageV} V · ${load.profile.phases} phases${widget.assignedCircuitIds[load.componentInstanceId] != null && widget.assignedCircuitIds[load.componentInstanceId] != widget.circuitId ? ' · assigned to another circuit' : ''}',
                  ),
                  value: selected.contains(load.componentInstanceId),
                  onChanged:
                      saving ||
                              (widget.assignedCircuitIds[load
                                          .componentInstanceId] !=
                                      null &&
                                  widget.assignedCircuitIds[load
                                          .componentInstanceId] !=
                                      widget.circuitId &&
                                  !selected.contains(load.componentInstanceId))
                          ? null
                          : (value) => setState(() {
                            if (value == true)
                              selected.add(load.componentInstanceId);
                            else
                              selected.remove(load.componentInstanceId);
                          }),
                ),
              for (final id in selected.difference(availableIds))
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${widget.titles[id] ?? id} · unavailable'),
                  value: true,
                  onChanged:
                      saving
                          ? null
                          : (_) => setState(() => selected.remove(id)),
                ),
              Text(
                calculation.ready
                    ? 'Design current Ib: ${calculation.designCurrentA!.toStringAsFixed(2)} A'
                    : 'Current needs input',
              ),
              for (final issue in calculation.issues)
                Text(
                  '${issue.loadId == null ? '' : '${widget.titles[issue.loadId] ?? issue.loadId}: '}${issue.message}',
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
          onPressed: saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: saving ? null : save,
          child: const Text('Save circuit'),
        ),
      ],
    );
  }
}
