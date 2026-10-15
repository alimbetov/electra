import 'package:engineering_core/engineering_core.dart';
import 'package:test/test.dart';

void main() {
  group('P5-T08 deterministic PWR-06 evidence', () {
    test('complete PWR-01 W may feed P5 even when A/VA remain unresolved', () {
      final context = _context();
      final demandEvidence = _demandEvidence(context);
      final input = _input();
      final result = evaluatePoeDelivery(input);
      final record = buildPoeEvaluationRecord(
        evaluationId: 'poe-eval-1',
        context: context,
        input: input,
        result: result,
        pdDemandEvaluation: demandEvidence,
        scenarioFacts: const {'state': 'NORMAL'},
      );

      expect(demandEvidence.status, PowerEvaluationStatus.unresolved);
      expect(demandEvidence.output['completeW'], isTrue);
      expect(record.evaluation.status, PowerEvaluationStatus.pass);
      expect(record.evaluation.nodeKey.processCode, PowerProcessCode.pwr06);
      expect(record.evaluation.dependencies, [demandEvidence.nodeKey]);
      expect(
        _rational(record.evaluation.output['upstreamInputW']),
        PowerRational(BigInt.from(115), BigInt.from(3)),
      );
      expect(
        record.evaluation.arithmeticSteps
            .map((step) => step['boundaryRef'])
            .toSet(),
        {'POE_GROUP:pse-group-a'},
      );
      expect(
        record.evaluation.inputFingerprint,
        record.consumedInput.inputFingerprint,
      );
    });

    test('reordered path enumeration keeps fingerprint and evidence stable',
        () {
      final context = _context();
      final demandEvidence = _demandEvidence(context);
      final firstInput = _input(
        pathStages: [_stage('patch-a'), _stage('patch-b')],
      );
      final secondInput = _input(
        pathStages: [_stage('patch-b'), _stage('patch-a')],
      );

      final first = buildPoeEvaluationRecord(
        evaluationId: 'poe-eval-1',
        context: context,
        input: firstInput,
        result: evaluatePoeDelivery(firstInput),
        pdDemandEvaluation: demandEvidence,
        scenarioFacts: const {'state': 'NORMAL'},
      );
      final reopened = buildPoeEvaluationRecord(
        evaluationId: 'poe-eval-1',
        context: context,
        input: secondInput,
        result: evaluatePoeDelivery(secondInput),
        pdDemandEvaluation: demandEvidence,
        scenarioFacts: const {'state': 'NORMAL'},
      );

      expect(reopened.consumedInput.inputFingerprint,
          first.consumedInput.inputFingerprint);
      expect(reopened.evidenceSha256, first.evidenceSha256);
      expect(reopened.diff(first).requiresRecalculation, isFalse);
    });

    test('group membership edit invalidates the group membership fact only',
        () {
      final context = _context();
      final demandEvidence = _demandEvidence(context);
      final firstInput = _input(
        existing: [_reservation('delivery-a', '12')],
      );
      final changedInput = _input(
        existing: [
          _reservation('delivery-a', '12'),
          _reservation('delivery-c', '3'),
        ],
      );

      final first = buildPoeConsumedInput(
        context: context,
        input: firstInput,
        pdDemandEvaluation: demandEvidence,
        scenarioFacts: const {'state': 'NORMAL'},
      );
      final changed = buildPoeConsumedInput(
        context: context,
        input: changedInput,
        pdDemandEvaluation: demandEvidence,
        scenarioFacts: const {'state': 'NORMAL'},
      );
      final diff = changed.diff(first);

      expect(diff.requiresRecalculation, isTrue);
      expect(diff.changedEvaluationNodeKeys, isEmpty);
      expect(diff.changedDependencyKeys, hasLength(1));
      expect(diff.changedDependencyKeys.single, contains('GROUP_MEMBERSHIP'));
      expect(diff.changedDependencyKeys.single, contains('POE_MEMBERSHIP'));
    });

    test('missing physical realization remains explicit missing evidence', () {
      final context = _context();
      final demandEvidence = _demandEvidence(context);
      final input = _input(
        pathStages: [
          PoePathStage(
            stageId: 'draft-run',
            kind: PoePathStageKind.copperCable,
            resourceKind: 'COPPER_PAIR',
            physicalRealized: false,
            powerPass: true,
            pairMappingResolved: true,
          ),
        ],
      );
      final result = evaluatePoeDelivery(input);
      final record = buildPoeEvaluationRecord(
        evaluationId: 'poe-eval-draft',
        context: context,
        input: input,
        result: result,
        pdDemandEvaluation: demandEvidence,
        scenarioFacts: const {'state': 'NORMAL'},
      );

      final missing = record.consumedInput.facts
          .where((fact) => fact.presence == PowerDependencyPresence.missing)
          .toList();
      expect(record.evaluation.status, PowerEvaluationStatus.unresolved);
      expect(record.evaluation.output['upstreamInputW'], isNull);
      expect(missing, hasLength(2));
      expect(
        missing.map((fact) => fact.key.kind).toSet(),
        {PowerDependencyKind.allocation, PowerDependencyKind.cableRun},
      );
    });

    test('estimated actual basis records missing group output dependency', () {
      final context = _context();
      final demandEvidence = _demandEvidence(context);
      final input = _input(
        groupInputBasis: PoeGroupInputBasis.estimatedActual,
      );
      final consumed = buildPoeConsumedInput(
        context: context,
        input: input,
        pdDemandEvaluation: demandEvidence,
        scenarioFacts: const {'state': 'NORMAL'},
      );

      final actual = consumed.facts.singleWhere(
        (fact) => fact.key.purpose == 'ACTUAL_GROUP_OUTPUT',
      );
      expect(actual.presence, PowerDependencyPresence.missing);
    });
  });
}

PoeEvidenceContext _context() => PoeEvidenceContext(
      projectId: 'project-1',
      revisionId: 'revision-1',
      scenarioId: 'scenario-1',
      segmentId: 'segment-1',
      groupId: 'pse-group-a',
    );

PowerEvaluationEvidence _demandEvidence(PoeEvidenceContext context) {
  final demand = aggregatePowerDemand([
    PowerDemandContribution(
      originId: 'pd-load',
      componentId: 'camera',
      inputPortId: 'camera-poe',
      stateCode: 'NORMAL',
      demand: DcConstantPowerDemand(_r('15')),
    ),
  ]);
  return buildPowerDemandEvidence(
    evaluationId: 'pwr01-pd',
    revisionId: context.revisionId,
    scenarioId: context.scenarioId,
    segmentId: context.segmentId,
    subjectKind: 'CONSUMER_PORT',
    subjectId: 'camera-poe',
    demand: demand,
  );
}

PoeEvaluationInput _input({
  PoeGroupInputBasis groupInputBasis = PoeGroupInputBasis.conservativeReserved,
  Iterable<PoeReservedAllocation>? existing,
  Iterable<PoePathStage>? pathStages,
}) =>
    PoeEvaluationInput(
      deliveryId: 'delivery-b',
      definition: PoeDeliveryDefinition(
        definitionRef: PowerDefinitionRef(
          catalogId: 'catalog',
          catalogVersion: '1',
          definitionKind: PowerDefinitionKind.poe,
          definitionCode: 'POE_FIXTURE',
          definitionVersion: '1',
          definitionSchema: 'electra.fixture.v1',
          contentSha256:
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          sourceRef: 'fixture:poe',
        ),
        guaranteedPdPowerW: _r('15'),
        psePortLimitW: _r('20'),
        maxChannelLossW: _r('5'),
        compatibleResourceKinds: const ['COPPER_PAIR'],
        supportsMidspan: true,
      ),
      accountingMode: PoeAccountingMode.guaranteedPd,
      groupInputBasis: groupInputBasis,
      pdDemandW: _r('15'),
      reservedPseW: _r('18'),
      portAllocationLimitW: _r('20'),
      sharedGroupBudgetW: _r('40'),
      existingGroupReservations: existing ?? [_reservation('delivery-a', '12')],
      pathStages: pathStages ?? [_stage('copper')],
      pseRoleConfirmed: true,
      pdRoleConfirmed: true,
      pseTransferLoss: PowerLossDefinition(
        efficiency: _r('0.9'),
        idleW: _r('5'),
        idleAccounting: PowerIdleAccounting.excludesSeparateIdle,
      ),
    );

PoeReservedAllocation _reservation(String originId, String watts) =>
    PoeReservedAllocation(
      originId: originId,
      portId: 'pse-$originId',
      reservedW: _r(watts),
    );

PoePathStage _stage(String id) => PoePathStage(
      stageId: id,
      kind: PoePathStageKind.copperCable,
      resourceKind: 'COPPER_PAIR',
      physicalRealized: true,
      powerPass: true,
      pairMappingResolved: true,
      allocationId: 'allocation-$id',
      cableRunId: 'run-$id',
    );

PowerRational _rational(Object? value) => PowerRational.fromMap(
      (value as Map<Object?, Object?>).cast<String, Object?>(),
    );

PowerRational _r(String value) => PowerRational.fromWireDecimal(value);
