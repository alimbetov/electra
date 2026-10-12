import 'package:engineering_core/engineering_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/system_component_catalog.dart';

class ElectricalLoadsScreen extends ConsumerWidget {
  const ElectricalLoadsScreen({
    super.key,
    required this.roomId,
    required this.roomName,
  });
  final String roomId;
  final String roomName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final components = ref.watch(roomComponentsProvider(roomId));
    final loads = ref.watch(roomElectricalLoadsProvider(roomId));
    final groups = ref.watch(roomConsumptionGroupsProvider(roomId));
    return Scaffold(
      appBar: AppBar(title: Text('$roomName · Electrical loads')),
      body: components.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, _) =>
                Center(child: Text('Unable to load equipment: $error')),
        data:
            (items) => groups.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:
                  (error, _) =>
                      Center(child: Text('Unable to load groups: $error')),
              data:
                  (roomGroups) => loads.when(
                    loading:
                        () => const Center(child: CircularProgressIndicator()),
                    error:
                        (error, _) =>
                            Center(child: Text('Unable to load loads: $error')),
                    data: (roomLoads) {
                      final loadByComponent = {
                        for (final load in roomLoads)
                          load.componentInstanceId: load,
                      };
                      final groupNames = {
                        for (final group in roomGroups) group.id: group.name,
                      };
                      final definitions = {
                        for (final definition
                            in electricalSystemComponentLibrary.definitions)
                          definition.id: definition,
                      };
                      return ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: FilledButton.tonalIcon(
                              icon: const Icon(
                                Icons.create_new_folder_outlined,
                              ),
                              label: const Text('New consumption group'),
                              onPressed:
                                  () => showDialog<void>(
                                    context: context,
                                    builder:
                                        (_) => _GroupDialog(
                                          onSave:
                                              (name) => ref
                                                  .read(
                                                    electricalLoadRepositoryProvider,
                                                  )
                                                  .saveGroup(
                                                    RoomConsumptionGroup(
                                                      id:
                                                          ref
                                                              .read(
                                                                idGeneratorProvider,
                                                              )
                                                              .next(),
                                                      roomId: roomId,
                                                      name: name,
                                                    ),
                                                  ),
                                        ),
                                  ),
                            ),
                          ),
                          if (roomGroups.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Wrap(
                                spacing: 8,
                                children:
                                    roomGroups
                                        .map(
                                          (group) => Chip(
                                            label: Text(
                                              '${group.name} · ${roomLoads.where((load) => load.consumptionGroupId == group.id).length} loads',
                                            ),
                                          ),
                                        )
                                        .toList(),
                              ),
                            ),
                          if (items.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'Place equipment in the room before adding loads.',
                              ),
                            ),
                          for (final component in items)
                            Builder(
                              builder: (context) {
                                final load = loadByComponent[component.id];
                                final definition =
                                    definitions[component.definitionId];
                                final title =
                                    component.displayNameOverride ??
                                    definition?.displayName ??
                                    component.definitionId;
                                final profile = load?.profile;
                                return Card(
                                  child: ListTile(
                                    title: Text(title),
                                    subtitle: Text(
                                      '${component.hostSurfacePatchId} · ${component.localPosition.xMm}, ${component.localPosition.yMm} mm\n${profile == null ? 'Load not configured' : '${profile.nominalVoltageV} V · ${profile.phases} phases · ${profile.ratedPowerW ?? '—'} W · ${profile.ratedCurrentA ?? '—'} A'}\n${groupNames[load?.consumptionGroupId] ?? 'Ungrouped'}',
                                    ),
                                    isThreeLine: true,
                                    trailing: const Icon(Icons.edit_outlined),
                                    onTap:
                                        () => showDialog<void>(
                                          context: context,
                                          builder:
                                              (_) => ElectricalLoadDialog(
                                                component: component,
                                                title: title,
                                                existing: load,
                                                defaultProfile:
                                                    definition
                                                        ?.electricalLoadProfile,
                                                groups: roomGroups,
                                                onSave:
                                                    ref
                                                        .read(
                                                          electricalLoadRepositoryProvider,
                                                        )
                                                        .saveLoad,
                                              ),
                                        ),
                                  ),
                                );
                              },
                            ),
                        ],
                      );
                    },
                  ),
            ),
      ),
    );
  }
}

class ElectricalLoadDialog extends StatefulWidget {
  const ElectricalLoadDialog({
    super.key,
    required this.component,
    required this.title,
    required this.groups,
    required this.onSave,
    this.existing,
    this.defaultProfile,
  });
  final ComponentInstance component;
  final String title;
  final List<RoomConsumptionGroup> groups;
  final EquipmentElectricalLoad? existing;
  final ElectricalLoadProfile? defaultProfile;
  final Future<void> Function(EquipmentElectricalLoad load) onSave;

  @override
  State<ElectricalLoadDialog> createState() => _ElectricalLoadDialogState();
}

class _ElectricalLoadDialogState extends State<ElectricalLoadDialog> {
  late final base =
      widget.existing?.profile ??
      widget.defaultProfile ??
      const ElectricalLoadProfile(nominalVoltageV: 230, phases: 1);
  late final voltage = TextEditingController(text: '${base.nominalVoltageV}');
  late final power = TextEditingController(
    text: base.ratedPowerW?.toString() ?? '',
  );
  late final current = TextEditingController(
    text: base.ratedCurrentA?.toString() ?? '',
  );
  late final powerFactor = TextEditingController(
    text: base.powerFactor?.toString() ?? '',
  );
  late final efficiency = TextEditingController(
    text: base.efficiency?.toString() ?? '',
  );
  late SupplySystem supply = base.supplySystem;
  late int phases = base.phases;
  late String groupId = widget.existing?.consumptionGroupId ?? '';
  bool saving = false;
  String? error;

  @override
  void dispose() {
    for (final controller in [
      voltage,
      power,
      current,
      powerFactor,
      efficiency,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  double? optionalNumber(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty
        ? null
        : double.tryParse(text.replaceAll(',', '.')) ?? double.nan;
  }

  Future<void> save() async {
    if (saving) return;
    final profile = ElectricalLoadProfile(
      nominalVoltageV: optionalNumber(voltage) ?? double.nan,
      phases: phases,
      supplySystem: supply,
      phaseConfiguration:
          supply == base.supplySystem && phases == base.phases
              ? base.phaseConfiguration
              : null,
      ratedPowerW: optionalNumber(power),
      ratedCurrentA: optionalNumber(current),
      powerFactor: optionalNumber(powerFactor),
      efficiency: optionalNumber(efficiency),
      frequencyHz: base.frequencyHz,
      startingMethod: base.startingMethod,
      startingCurrentFactor: base.startingCurrentFactor,
      loadType: base.loadType,
      dedicatedCircuitRecommended: base.dedicatedCircuitRecommended,
      requiresNeutral: base.requiresNeutral,
      requiresProtectiveEarth: base.requiresProtectiveEarth,
    );
    final violations = ElectricalLoadValidator.validate(profile);
    if (violations.isNotEmpty) {
      setState(() => error = 'Check load parameters: ${violations.join(', ')}');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.onSave(
        EquipmentElectricalLoad(
          componentInstanceId: widget.component.id,
          profile: profile,
          consumptionGroupId: groupId.isEmpty ? null : groupId,
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (failure) {
      if (mounted) setState(() => error = 'Unable to save load: $failure');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('${widget.title} · Load'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Equipment: ${widget.component.id}'),
            DropdownButtonFormField<SupplySystem>(
              initialValue: supply,
              decoration: const InputDecoration(labelText: 'Supply system'),
              items:
                  SupplySystem.values
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
                            supply = value;
                            if (value == SupplySystem.threePhaseAc) phases = 3;
                            if (value == SupplySystem.singlePhaseAc) phases = 1;
                          });
                      },
            ),
            DropdownButtonFormField<int>(
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
            for (final field in [
              (voltage, 'Nominal voltage (V)'),
              (power, 'Rated power (W)'),
              (current, 'Rated current (A)'),
              (powerFactor, 'Power factor (0–1)'),
              (efficiency, 'Efficiency (0–1)'),
            ])
              TextField(
                controller: field.$1,
                enabled: !saving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(labelText: field.$2),
              ),
            DropdownButtonFormField<String>(
              initialValue: groupId,
              decoration: const InputDecoration(labelText: 'Consumption group'),
              items: [
                const DropdownMenuItem(value: '', child: Text('Ungrouped')),
                ...widget.groups.map(
                  (group) => DropdownMenuItem(
                    value: group.id,
                    child: Text(group.name),
                  ),
                ),
              ],
              onChanged:
                  saving
                      ? null
                      : (value) {
                        if (value != null) setState(() => groupId = value);
                      },
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
        child: Text(saving ? 'Saving…' : 'Save load'),
      ),
    ],
  );
}

class _GroupDialog extends StatefulWidget {
  const _GroupDialog({required this.onSave});
  final Future<void> Function(String name) onSave;
  @override
  State<_GroupDialog> createState() => _GroupDialogState();
}

class _GroupDialogState extends State<_GroupDialog> {
  final name = TextEditingController();
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
      setState(() => error = 'Enter a group name.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.onSave(name.text.trim());
      if (mounted) Navigator.of(context).pop();
    } catch (failure) {
      if (mounted) setState(() => error = 'Unable to save group: $failure');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('New consumption group'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: name,
          enabled: !saving,
          decoration: const InputDecoration(labelText: 'Name'),
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
        child: const Text('Save group'),
      ),
    ],
  );
}
