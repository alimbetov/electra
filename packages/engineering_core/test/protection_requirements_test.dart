import 'package:engineering_core/engineering_core.dart';
import 'package:test/test.dart';

void main() {
  final doc = bundledNormativeDocuments.last;
  ProtectionRuleset rule(
          {String version = '1',
          List<double> ratings = const [10, 16, 20, 25]}) =>
      ProtectionRuleset(
          id: 'rule-$version',
          projectId: 'project',
          normativeDocumentId: doc.id,
          reference: ElectricalRulesetRef(
              id: 'Test policy',
              jurisdiction: doc.jurisdiction,
              standardCode: doc.standardCode,
              version: version,
              sourceReference: doc.source),
          nominalCurrentsA: ratings,
          tripCurves: const ['B', 'C'],
          residualTypes: const ['A', 'B'],
          minimumBreakingCapacityKa: 6);
  CircuitProtectionInputs settings(
          {double iz = 25,
          int poles = 2,
          ResidualProtectionPolicy residual =
              ResidualProtectionPolicy.notRequired,
          double? ma,
          String? type,
          String version = '1'}) =>
      CircuitProtectionInputs(
          circuitId: 'c',
          rulesetId: 'rule-$version',
          allowableCurrentA: iz,
          prospectiveFaultKa: 7.1,
          poles: poles,
          tripCurve: 'C',
          residualPolicy: residual,
          residualCurrentMa: ma,
          residualType: type,
          evidence:
              'Test declared ampacity, fault current and residual applicability.');
  ProtectionRequirementProposal propose(
          {double ib = 12,
          CircuitProtectionInputs? input,
          ProtectionRuleset? policy,
          NormativeDocument? document,
          SupplySystem supply = SupplySystem.singlePhaseAc,
          int phases = 1}) =>
      ProtectionRequirementPlanner.propose(
          settings: input ?? settings(),
          ruleset: policy ?? rule(),
          normativeDocument: document ?? doc,
          designCurrentA: ib,
          nominalVoltageV: 230,
          phases: phases,
          supplySystem: supply);
  test(
      'smallest project option in declared range produces explainable vendor-neutral MCB',
      () {
    final p = propose();
    expect(p.ready, isTrue);
    expect(p.requirement!.ratedCurrentA, 16);
    expect(p.requirement!.breakingCapacityKa, 7.1);
    expect(p.requirement!.role, FunctionalDeviceRole.mcb);
    expect(p.toMap().containsKey('manufacturer'), isFalse);
    expect(p.toMap()['ruleset'], isNotNull);
    expect((p.toMap()['inputs'] as Map)['normativeDocument'], doc.toMap());
    expect(p.reasons, isNotEmpty);
    expect(p.warnings, isNotEmpty);
  });
  test('equality boundaries accepted, insufficient Iz has no partial device',
      () {
    expect(propose(ib: 16, input: settings(iz: 16)).requirement!.ratedCurrentA,
        16);
    final bad = propose(ib: 26, input: settings(iz: 25));
    expect(bad.state, ProtectionProposalState.invalid);
    expect(bad.requirement, isNull);
  });
  test(
      'explicit residual policy produces RCBO only with complete allowed parameters',
      () {
    final p = propose(
        input: settings(
            residual: ResidualProtectionPolicy.required, ma: 30, type: 'A'));
    expect(p.requirement!.role, FunctionalDeviceRole.rcbo);
    expect(p.requirement!.residualCurrentMa, 30);
    expect(
        propose(input: settings(residual: ResidualProtectionPolicy.required))
            .state,
        ProtectionProposalState.needsInput);
    expect(
        propose(
                input: settings(
                    residual: ResidualProtectionPolicy.required,
                    ma: 30,
                    type: 'AC'))
            .state,
        ProtectionProposalState.invalid);
  });
  test(
      'unconfigured inputs and reference-only IEC edition do not become executable proposals',
      () {
    final empty = ProtectionRequirementPlanner.propose(
        settings: const CircuitProtectionInputs(circuitId: 'c'),
        ruleset: null,
        normativeDocument: null,
        designCurrentA: 12,
        nominalVoltageV: 230,
        phases: 1,
        supplySystem: SupplySystem.singlePhaseAc);
    expect(empty.state, ProtectionProposalState.needsInput);
    expect(empty.requirement, isNull);
    final ref = bundledNormativeDocuments.first;
    final policy = ProtectionRuleset(
        id: 'rule-1',
        projectId: 'project',
        normativeDocumentId: ref.id,
        reference: ElectricalRulesetRef(
            id: 'Reference',
            jurisdiction: ref.jurisdiction,
            standardCode: ref.standardCode,
            version: '1',
            sourceReference: ref.source),
        nominalCurrentsA: const [16],
        tripCurves: const ['C'],
        residualTypes: const []);
    expect(propose(policy: policy, document: ref).state,
        ProtectionProposalState.needsInput);
  });
  test(
      'DC, insufficient poles and invalid quantities do not silently select AC devices',
      () {
    expect(propose(supply: SupplySystem.directCurrent).state,
        ProtectionProposalState.needsInput);
    expect(
        propose(
                phases: 3,
                supply: SupplySystem.threePhaseAc,
                input: settings(poles: 2))
            .state,
        ProtectionProposalState.invalid);
    expect(propose(ib: double.nan).state, ProtectionProposalState.invalid);
    expect(rule(ratings: const [10, 10]).validate(), isNotEmpty);
    expect(settings(iz: double.infinity).validate(), isNotEmpty);
  });
  test(
      'catalog editions and ruleset versions round-trip with explicit provenance',
      () {
    expect(NormativeDocument.fromMap(doc.toMap()).toMap(), doc.toMap());
    final r = rule(version: '2');
    expect(ProtectionRuleset.fromMap(r.toMap()).toMap(), r.toMap());
    expect(
        CircuitProtectionInputs.fromMap(settings(version: '2').toMap()).toMap(),
        settings(version: '2').toMap());
    expect(
        propose(policy: r, input: settings(version: '2'))
            .ruleset!
            .reference
            .version,
        '2');
  });
}
