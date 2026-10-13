import 'dart:convert';
import 'package:engineering_core/engineering_core.dart';
import 'package:test/test.dart';

final doc = bundledNormativeDocuments.firstWhere((d) => d.supportsPlanner);
final rule = ProtectionRuleset(
    id: 'rules',
    projectId: 'project',
    normativeDocumentId: doc.id,
    reference: ElectricalRulesetRef(
        id: 'test',
        jurisdiction: doc.jurisdiction,
        standardCode: doc.standardCode,
        version: '1',
        sourceReference: doc.source),
    nominalCurrentsA: [6, 10, 16, 20, 25, 32, 40, 63, 80, 100],
    tripCurves: ['C'],
    residualTypes: ['A']);
CircuitProtectionInputs settings(int poles, double iz,
        {bool residual = false}) =>
    CircuitProtectionInputs(
        circuitId: 'proposal',
        rulesetId: 'rules',
        allowableCurrentA: iz,
        prospectiveFaultKa: 6,
        poles: poles,
        tripCurve: 'C',
        residualPolicy: residual
            ? ResidualProtectionPolicy.required
            : ResidualProtectionPolicy.notRequired,
        residualCurrentMa: residual ? 30 : null,
        residualType: residual ? 'A' : null,
        evidence: 'Fictional declared test data');
PanelGenerationPolicy policy(
        {int phases = 3,
        double reserve = 25,
        Map<String, int> widths = const {'mcb:2': 2, 'mcb:4': 4},
        bool residual = false}) =>
    PanelGenerationPolicy(
        id: 'panel',
        projectId: 'project',
        floorId: 'floor',
        name: 'Test panel',
        rulesetId: 'rules',
        phases: phases,
        phaseVoltageV: 230,
        lineVoltageV: 400,
        demandFactor: 1,
        reservePercent: reserve,
        minimumSpareModules: 2,
        moduleWidths: widths,
        outgoing: settings(2, 32, residual: residual),
        incoming: settings(phases == 3 ? 4 : 2, 100));
RoomConsumptionGroup group(String id) =>
    RoomConsumptionGroup(id: id, roomId: 'room', name: id);
EquipmentElectricalLoad load(String id, String? groupId, double current,
        {bool dedicated = false,
        PhaseConfiguration? phase,
        double? frequency = 50}) =>
    EquipmentElectricalLoad(
        componentInstanceId: id,
        consumptionGroupId: groupId,
        profile: ElectricalLoadProfile(
            nominalVoltageV: 230,
            phases: 1,
            ratedCurrentA: current,
            frequencyHz: frequency,
            phaseConfiguration: phase,
            dedicatedCircuitRecommended: dedicated));
DependencyProposal generate(List<EquipmentElectricalLoad> loads,
        {PanelGenerationPolicy? p, List<RoomConsumptionGroup>? groups}) =>
    PanelGenerationEngine.generate(
        policy: p ?? policy(),
        groups: groups ??
            loads
                .map((l) => l.consumptionGroupId)
                .whereType<String>()
                .toSet()
                .map(group)
                .toList(),
        loads: loads,
        ruleset: rule,
        normativeDocument: doc);
void main() {
  test(
      'phase balance respects fixed phases, deterministic current order and traceable protection',
      () {
    final result = generate([
      load('a', 'a', 10),
      load('b', 'b', 8),
      load('c', 'c', 6, phase: PhaseConfiguration.l2N)
    ]);
    expect(result.requiresReview, isFalse);
    expect(result.values['phaseCurrentsA'], {'L1': 10.0, 'L2': 6.0, 'L3': 8.0});
    expect(result.values['incomingDesignCurrentA'], 10);
    expect((result.values['incoming'] as Map)['ratedCurrentA'], 10);
    expect(result.values['estimatedModuleCount'], 10);
    expect(result.values['recommendedSpareModules'], 3);
    expect(result.values['recommendedCapacityModules'], 13);
    final circuits = result.values['circuits'] as List;
    expect((circuits.first as Map)['sourceGroupId'], 'a');
    expect(((circuits.first as Map)['protection'] as Map)['ruleset'],
        rule.toMap());
    expect((circuits.first as Map)['currentEvidence'], isNotEmpty);
    final reversed = generate([
      load('c', 'c', 6, phase: PhaseConfiguration.l2N),
      load('b', 'b', 8),
      load('a', 'a', 10)
    ]);
    expect(canonicalEngineeringJson(reversed.values),
        canonicalEngineeringJson(result.values));
  });
  test(
      'compatible loads combine but dedicated equipment splits with stable IDs',
      () {
    final result = generate([
      load('a', 'g', 4),
      load('b', 'g', 5),
      load('c', 'g', 6, dedicated: true)
    ]);
    final circuits = result.values['circuits'] as List;
    expect(circuits.length, 2);
    expect(
        circuits.map((c) => (c as Map)['designCurrentA']).toSet(), {9.0, 6.0});
    expect(circuits.where((c) => (c as Map)['dedicated'] == true).length, 1);
    final changed = generate([
      load('a', 'g', 5),
      load('b', 'g', 5),
      load('c', 'g', 7, dedicated: true)
    ]);
    expect((changed.values['circuits'] as List).map((c) => (c as Map)['id']),
        circuits.map((c) => (c as Map)['id']));
  });
  test(
      'invalid, ungrouped, over-ampacity and incompatible supplies cannot produce confirmed totals',
      () {
    for (final loads in [
      [load('x', null, 5)],
      [load('x', 'g', 50)],
      [load('x', 'g', 0)],
      [load('x', 'g', 5, phase: PhaseConfiguration.l2N)]
    ]) {
      final result = generate(loads, p: policy(phases: 1));
      expect(result.requiresReview, isTrue);
      expect(result.values['incomingDesignCurrentA'], isNull);
      expect(result.values['phaseCurrentsA'], isNull);
      expect(result.values['inputIssues'], isNotEmpty);
    }
    expect(
        generate([
          load('a', 'a', 5, frequency: 50),
          load('b', 'b', 5, frequency: 60)
        ]).requiresReview,
        isTrue);
  });
  test('empty groups and missing module widths remain explicit', () {
    final result = generate([load('a', 'a', 5)],
        p: policy(widths: {}), groups: [group('a'), group('empty')]);
    expect((result.values['circuits'] as List).length, 1);
    expect(result.values['estimatedModuleCount'], isNull);
    expect(result.values['recommendedCapacityModules'], isNull);
    expect(
        (result.values['warnings'] as List)
            .any((s) => '$s'.contains('Empty group')),
        isTrue);
    expect(generate([], groups: [group('empty')]).requiresReview, isTrue);
  });
  test(
      'residual function and reserve are explicit policy and codec persists them',
      () {
    final p =
        policy(residual: true, reserve: 0, widths: {'rcbo:2': 2, 'mcb:4': 4});
    final decoded = PanelGenerationPolicy.fromMap(
        jsonDecode(jsonEncode(p.toMap())) as Map<String, dynamic>);
    expect(decoded.toMap(), p.toMap());
    final result = generate([load('a', 'a', 5)], p: decoded);
    expect(result.requiresReview, isFalse);
    expect(
        (((result.values['circuits'] as List).single as Map)['protection']
            as Map)['role'],
        'rcbo');
    expect(result.values['recommendedSpareModules'], 2);
  });
  test(
      'balanced three-phase loads contribute current to all phases without a second demand factor',
      () {
    final p = PanelGenerationPolicy.fromMap({
      ...policy().toMap(),
      'outgoing': settings(4, 32).toMap(),
      'demandFactor': 0.5
    });
    final result = generate([
      const EquipmentElectricalLoad(
          componentInstanceId: '3p',
          consumptionGroupId: 'g',
          profile: ElectricalLoadProfile(
              nominalVoltageV: 400,
              phases: 3,
              supplySystem: SupplySystem.threePhaseAc,
              ratedCurrentA: 20))
    ], p: p);
    expect(result.requiresReview, isFalse);
    expect(
        result.values['phaseCurrentsA'], {'L1': 10.0, 'L2': 10.0, 'L3': 10.0});
    expect(result.values['incomingDesignCurrentA'], 10);
  });
}
