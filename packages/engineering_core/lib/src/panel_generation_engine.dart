import 'dart:convert';
import 'dart:math' as math;
import 'component_catalog.dart';
import 'electrical_load.dart';
import 'electrical_circuit.dart';
import 'protection_requirements.dart';
import 'normative_catalog.dart';
import 'dependency_recalculation.dart';

class PanelGenerationPolicy {
  const PanelGenerationPolicy(
      {required this.id,
      required this.projectId,
      required this.floorId,
      required this.name,
      required this.rulesetId,
      required this.phases,
      required this.phaseVoltageV,
      required this.lineVoltageV,
      required this.demandFactor,
      required this.reservePercent,
      required this.minimumSpareModules,
      required this.moduleWidths,
      required this.outgoing,
      required this.incoming});
  final String id, projectId, floorId, name, rulesetId;
  final int phases, minimumSpareModules;
  final double phaseVoltageV, lineVoltageV, demandFactor, reservePercent;
  final Map<String, int> moduleWidths;
  final CircuitProtectionInputs outgoing, incoming;
  List<String> validate() => [
        if ([id, projectId, floorId, name, rulesetId]
            .any((s) => s.trim().isEmpty))
          'Panel identity, scope, name and ruleset are required.',
        if (phases != 1 && phases != 3)
          'Use a single-phase or three-phase AC panel.',
        if ([phaseVoltageV, lineVoltageV].any((v) => !v.isFinite || v <= 0))
          'Invalid voltage.',
        if (!demandFactor.isFinite || demandFactor <= 0 || demandFactor > 1)
          'Invalid demand factor.',
        if (!reservePercent.isFinite ||
            reservePercent < 0 ||
            minimumSpareModules < 0)
          'Invalid reserve.',
        if (moduleWidths.values.any((v) => v <= 0))
          'Module estimates must be positive.',
        ...outgoing.validate(),
        ...incoming.validate(),
        if (outgoing.rulesetId != rulesetId || incoming.rulesetId != rulesetId)
          'Protection ruleset mismatch.',
      ];
  Map<String, Object?> toMap() => {
        'id': id,
        'projectId': projectId,
        'floorId': floorId,
        'name': name,
        'rulesetId': rulesetId,
        'phases': phases,
        'phaseVoltageV': phaseVoltageV,
        'lineVoltageV': lineVoltageV,
        'demandFactor': demandFactor,
        'reservePercent': reservePercent,
        'minimumSpareModules': minimumSpareModules,
        'moduleWidths': moduleWidths,
        'outgoing': outgoing.toMap(),
        'incoming': incoming.toMap(),
      };
  factory PanelGenerationPolicy.fromMap(Map<String, dynamic> m) =>
      PanelGenerationPolicy(
          id: m['id'] as String,
          projectId: m['projectId'] as String,
          floorId: m['floorId'] as String,
          name: m['name'] as String,
          rulesetId: m['rulesetId'] as String,
          phases: m['phases'] as int,
          phaseVoltageV: (m['phaseVoltageV'] as num).toDouble(),
          lineVoltageV: (m['lineVoltageV'] as num).toDouble(),
          demandFactor: (m['demandFactor'] as num).toDouble(),
          reservePercent: (m['reservePercent'] as num).toDouble(),
          minimumSpareModules: m['minimumSpareModules'] as int,
          moduleWidths: (m['moduleWidths'] as Map)
              .map((k, v) => MapEntry(k as String, v as int)),
          outgoing: CircuitProtectionInputs.fromMap(
              m['outgoing'] as Map<String, dynamic>),
          incoming: CircuitProtectionInputs.fromMap(
              m['incoming'] as Map<String, dynamic>));
}

abstract final class PanelGenerationEngine {
  static const algorithmVersion = 'fl15-panel-generation-v1';
  static DependencyProposal generate(
      {required PanelGenerationPolicy policy,
      required List<RoomConsumptionGroup> groups,
      required List<EquipmentElectricalLoad> loads,
      required ProtectionRuleset? ruleset,
      required NormativeDocument? normativeDocument}) {
    final issues = [...policy.validate()];
    final warnings = <String>[
      'Proposal only: existing circuits, routes and manufacturer selections are not modified.',
      'Module estimate uses declared widths. Enclosure dimensions, terminals, ducts and mounting clearances require FL16.',
      'Coordination, selectivity and additional protection require separate verification.',
    ];
    if (groups.map((g) => g.id).toSet().length != groups.length ||
        loads.map((l) => l.componentInstanceId).toSet().length != loads.length)
      issues.add('Duplicate group or load identity.');
    if (ruleset?.projectId != policy.projectId ||
        ruleset?.id != policy.rulesetId)
      issues.add('Choose an active ruleset of this project.');
    final groupIds = groups.map((g) => g.id).toSet();
    for (final l in loads) {
      if (!groupIds.contains(l.consumptionGroupId))
        issues.add(
            'Load ${l.componentInstanceId} has no active consumption group.');
    }
    final frequencies =
        loads.map((l) => l.profile.frequencyHz).whereType<double>().toSet();
    if (frequencies.length > 1)
      issues.add('Panel loads have incompatible AC frequencies.');
    if (loads.any((l) => l.profile.frequencyHz == null))
      warnings.add(
          'Verify supply frequency for loads without a declared frequency.');
    final circuits = <Map<String, Object?>>[];
    final ordered = groups.toList()..sort((a, b) => a.id.compareTo(b.id));
    for (final group in ordered) {
      final members = loads
          .where((l) => l.consumptionGroupId == group.id)
          .toList()
        ..sort(
            (a, b) => a.componentInstanceId.compareTo(b.componentInstanceId));
      if (members.isEmpty) {
        warnings.add('Empty group ${group.name} has no outgoing circuit.');
        continue;
      }
      final buckets = <String, List<EquipmentElectricalLoad>>{};
      for (final load in members) {
        final p = load.profile;
        final invalid = ElectricalLoadValidator.validate(p);
        if (invalid.isNotEmpty) {
          issues.add('${load.componentInstanceId}: ${invalid.join(', ')}');
          continue;
        }
        final key = jsonEncode([
          p.nominalVoltageV,
          p.phases,
          p.supplySystem.name,
          p.phaseConfiguration?.name,
          p.frequencyHz,
          if (p.dedicatedCircuitRecommended) load.componentInstanceId
        ]);
        buckets.putIfAbsent(key, () => []).add(load);
      }
      final keys = buckets.keys.toList()..sort();
      for (final key in keys) {
        final bucket = buckets[key]!, p = bucket.first.profile;
        final circuit = ElectricalCircuit(
            id: jsonEncode([policy.id, group.id, key]),
            roomId: group.roomId,
            name: group.name,
            sourceGroupId: group.id,
            inputs: ElectricalCircuitInputs(
                nominalVoltageV: p.nominalVoltageV,
                phases: p.phases,
                supplySystem: p.supplySystem,
                demandFactor: policy.demandFactor),
            loadIds: bucket.map((l) => l.componentInstanceId));
        final current = CircuitCurrentCalculator.calculate(circuit, bucket);
        issues.addAll(current.issues.map((i) => '${group.name}: ${i.message}'));
        if ((p.nominalVoltageV -
                        (p.phases == 3
                            ? policy.lineVoltageV
                            : policy.phaseVoltageV))
                    .abs() >
                1e-6 ||
            (p.phases == 3 && policy.phases != 3) ||
            (p.supplySystem != SupplySystem.singlePhaseAc &&
                p.supplySystem != SupplySystem.threePhaseAc))
          issues.add('${group.name}: incompatible panel supply.');
        final protection = ProtectionRequirementPlanner.propose(
            settings: policy.outgoing,
            ruleset: ruleset,
            normativeDocument: normativeDocument,
            designCurrentA: current.designCurrentA,
            nominalVoltageV: p.nominalVoltageV,
            phases: p.phases,
            supplySystem: p.supplySystem);
        if (!protection.ready)
          issues.addAll([...protection.issues, ...protection.warnings]
              .map((s) => '${group.name}: $s'));
        warnings.addAll(protection.warnings);
        String? phase;
        switch (p.phaseConfiguration) {
          case PhaseConfiguration.l1N:
            phase = 'L1';
          case PhaseConfiguration.l2N:
            phase = 'L2';
          case PhaseConfiguration.l3N:
            phase = 'L3';
          case null:
            break;
          case PhaseConfiguration.l1L2L3:
          case PhaseConfiguration.l1L2L3N:
            break;
          default:
            issues.add(
                '${group.name}: phase configuration needs explicit review.');
        }
        if (policy.phases == 1 && phase != null && phase != 'L1')
          issues.add('${group.name}: fixed phase outside panel supply.');
        circuits.add({
          'id': circuit.id,
          'name': group.name,
          'sourceGroupId': group.id,
          'loadIds': circuit.loadIds,
          'phases': p.phases,
          'phase': phase,
          'dedicated': p.dedicatedCircuitRecommended,
          'designCurrentA': current.designCurrentA,
          'protection': protection.toMap(),
          'currentEvidence': [
            for (final e in current.evidence)
              {
                'loadId': e.loadId,
                'currentA': e.currentA,
                'formula': e.formula,
                'inputs': e.inputs
              }
          ],
          'reasons': [
            'Separate circuits by group and compatible supply.',
            if (p.dedicatedCircuitRecommended)
              'Dedicated equipment has its own circuit.',
            'Explicit demand factor ${policy.demandFactor}.'
          ]
        });
      }
    }
    final phaseCurrents = <String, double>{
      'L1': 0,
      if (policy.phases == 3) 'L2': 0,
      if (policy.phases == 3) 'L3': 0
    };
    final flexible = <Map<String, Object?>>[];
    for (final c in circuits) {
      final current = c['designCurrentA'] as double?;
      if (current == null) continue;
      if (c['phases'] == 3) {
        c['phase'] = 'L1/L2/L3';
        for (final phase in phaseCurrents.keys) {
          phaseCurrents[phase] = phaseCurrents[phase]! + current;
        }
      } else if (phaseCurrents.containsKey(c['phase'])) {
        final phase = c['phase'] as String;
        phaseCurrents[phase] = phaseCurrents[phase]! + current;
      } else {
        flexible.add(c);
      }
    }
    flexible.sort((a, b) {
      final n = (b['designCurrentA'] as double)
          .compareTo(a['designCurrentA'] as double);
      return n != 0 ? n : (a['id'] as String).compareTo(b['id'] as String);
    });
    for (final c in flexible) {
      final phases = phaseCurrents.keys.toList()
        ..sort((a, b) {
          final n = phaseCurrents[a]!.compareTo(phaseCurrents[b]!);
          return n != 0 ? n : a.compareTo(b);
        });
      final phase = phases.first;
      c['phase'] = phase;
      phaseCurrents[phase] =
          phaseCurrents[phase]! + (c['designCurrentA'] as double);
      (c['reasons'] as List<String>)
          .add('Assigned $phase to minimize accumulated design current.');
    }
    if (circuits.isEmpty)
      issues.add('Add at least one nonempty consumption group.');
    final incomingCurrent =
        issues.isEmpty ? phaseCurrents.values.reduce(math.max) : null;
    final incoming = ProtectionRequirementPlanner.propose(
        settings: policy.incoming,
        ruleset: ruleset,
        normativeDocument: normativeDocument,
        designCurrentA: incomingCurrent,
        nominalVoltageV:
            policy.phases == 3 ? policy.lineVoltageV : policy.phaseVoltageV,
        phases: policy.phases,
        supplySystem: policy.phases == 3
            ? SupplySystem.threePhaseAc
            : SupplySystem.singlePhaseAc);
    if (!incoming.ready)
      issues.addAll([...incoming.issues, ...incoming.warnings]
          .map((s) => 'Incoming: $s'));
    warnings.addAll(incoming.warnings);
    int? occupied = 0;
    for (final protection in [
      incoming.toMap(),
      ...circuits.map((c) => c['protection'] as Map<String, Object?>)
    ]) {
      final width =
          policy.moduleWidths['${protection['role']}:${protection['poles']}'];
      if (width == null) {
        occupied = null;
        warnings.add(
            'Declare module width for ${protection['role']}:${protection['poles']}.');
        break;
      }
      occupied = occupied! + width;
    }
    final spare = occupied == null
        ? null
        : math.max(policy.minimumSpareModules,
            (occupied * policy.reservePercent / 100).ceil());
    return DependencyProposal(values: {
      'panelId': policy.id,
      'proposalState': issues.isEmpty ? 'proposed' : 'needsInput',
      'ruleset': ruleset?.toMap(),
      'normativeDocument': normativeDocument?.toMap(),
      'circuits': circuits,
      'incoming': incoming.toMap(),
      'phaseCurrentsA': issues.isEmpty ? phaseCurrents : null,
      'incomingDesignCurrentA': incomingCurrent,
      'estimatedModuleCount': occupied,
      'recommendedSpareModules': spare,
      'recommendedCapacityModules': occupied == null ? null : occupied + spare!,
      'warnings': warnings.toSet().toList(),
      'inputIssues': issues.toSet().toList()
    }, requiresReview: issues.isNotEmpty);
  }
}
