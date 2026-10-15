import 'package:engineering_core/engineering_core.dart';
import 'package:test/test.dart';

void main() {
  group('P5 closure orchestration', () {
    test('leaf PWR01 -> PWR06 -> parent PWR01 -> PWR02 is exact and acyclic',
        () {
      final context = _context();
      final leaf = _leafDemand(context);
      final result = evaluatePoeToCapabilityPipeline(
        context: context,
        poeInput: _poeInput(),
        pdDemandEvaluation: leaf,
        scenarioFacts: const {'state': 'NORMAL'},
        poeEvaluationId: 'pwr06-poe',
        parentDemandEvaluationId: 'pwr01-parent',
        capabilityEvaluationId: 'pwr02-source',
        parentBoundaryRef: 'AC-PANEL-A',
        parentSubjectKind: 'SOURCE_INPUT',
        parentSubjectId: 'panel-a',
        capabilitySubjectKind: 'SOURCE',
        capabilitySubjectId: 'source-a',
        sourceNameplateW: _r('75'),
        reserveMultiplier: _r('1.2'),
        deratingFactor: _r('0.8'),
        directContributions: [
          PowerDemandContribution(
            originId: 'panel-own-load',
            componentId: 'panel-a',
            inputPortId: 'panel-a-input',
            stateCode: 'NORMAL',
            demand: DcConstantPowerDemand(_r('10')),
          ),
        ],
      );

      final pseInput = PowerRational(BigInt.from(115), BigInt.from(3));
      final parentPhysical = PowerRational(BigInt.from(145), BigInt.from(3));
      expect(result.poeResult.groupReservedW, _r('30'));
      expect(result.poeResult.upstreamInputW, pseInput);
      expect(result.parentDemand.outputDemandW, parentPhysical);
      expect(result.parentDemand.upstreamInputW, parentPhysical);
      expect(
        result.parentDemand.accountingKeys,
        ['P5_PSE_GROUP_TRANSFER_PSE-GROUP-A'],
      );

      expect(result.capabilityResolved, isTrue);
      expect(result.capability!.physicalDemand, parentPhysical);
      expect(result.capability!.required, _r('58'));
      expect(result.capability!.available, _r('60'));
      expect(result.capability!.margin, _r('2'));
      expect(result.capability!.status, PowerDimensionStatus.pass);

      expect(result.poeEvidence.evaluation.dependencies, [leaf.nodeKey]);
      expect(
        result.parentDemandEvidence.dependencies,
        [result.poeEvidence.evaluation.nodeKey],
      );
      expect(
        result.capabilityEvidence!.dependencies,
        [result.parentDemandEvidence.nodeKey],
      );
    });

    test('missing actual PSE group basis blocks PWR02 instead of becoming zero',
        () {
      final context = _context();
      final result = evaluatePoeToCapabilityPipeline(
        context: context,
        poeInput: _poeInput(
          groupInputBasis: PoeGroupInputBasis.estimatedActual,
        ),
        pdDemandEvaluation: _leafDemand(context),
        scenarioFacts: const {'state': 'NORMAL'},
        poeEvaluationId: 'pwr06-poe',
        parentDemandEvaluationId: 'pwr01-parent',
        capabilityEvaluationId: 'pwr02-source',
        parentBoundaryRef: 'AC-PANEL-A',
        parentSubjectKind: 'SOURCE_INPUT',
        parentSubjectId: 'panel-a',
        capabilitySubjectKind: 'SOURCE',
        capabilitySubjectId: 'source-a',
        sourceNameplateW: _r('75'),
      );

      expect(result.poeResult.status, PowerEvaluationStatus.unresolved);
      expect(result.poeResult.upstreamInputW, isNull);
      expect(result.parentDemand.upstreamInputW, isNull);
      expect(result.parentDemandEvidence.output['completeW'], isFalse);
      expect(result.capability, isNull);
      expect(result.capabilityEvidence, isNull);
    });

    test('known PoE capacity failure does not erase known upstream demand', () {
      final context = _context();
      final result = evaluatePoeToCapabilityPipeline(
        context: context,
        poeInput: _poeInput(groupBudgetW: _r('29')),
        pdDemandEvaluation: _leafDemand(context),
        scenarioFacts: const {'state': 'NORMAL'},
        poeEvaluationId: 'pwr06-poe',
        parentDemandEvaluationId: 'pwr01-parent',
        capabilityEvaluationId: 'pwr02-source',
        parentBoundaryRef: 'AC-PANEL-A',
        parentSubjectKind: 'SOURCE_INPUT',
        parentSubjectId: 'panel-a',
        capabilitySubjectKind: 'SOURCE',
        capabilitySubjectId: 'source-a',
        sourceNameplateW: _r('50'),
      );

      expect(result.poeResult.status, PowerEvaluationStatus.fail);
      expect(
        result.poeResult.findings.map((finding) => finding.code),
        contains('ELV4_POE_GROUP_BUDGET_EXCEEDED'),
      );
      expect(
        result.parentDemand.upstreamInputW,
        PowerRational(BigInt.from(115), BigInt.from(3)),
      );
      expect(result.capability, isNotNull);
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

PowerEvaluationEvidence _leafDemand(PoeEvidenceContext context) =>
    buildPowerDemandEvidence(
      evaluationId: 'pwr01-leaf',
      revisionId: context.revisionId,
      scenarioId: context.scenarioId,
      segmentId: context.segmentId,
      subjectKind: 'CONSUMER_PORT',
      subjectId: 'camera-poe',
      demand: aggregatePowerDemand([
        PowerDemandContribution(
          originId: 'camera-load',
          componentId: 'camera',
          inputPortId: 'camera-poe',
          stateCode: 'NORMAL',
          demand: DcConstantPowerDemand(_r('15')),
        ),
      ]),
    );

PoeEvaluationInput _poeInput({
  PoeGroupInputBasis groupInputBasis = PoeGroupInputBasis.conservativeReserved,
  PowerRational? groupBudgetW,
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
      sharedGroupBudgetW: groupBudgetW ?? _r('35'),
      existingGroupReservations: [
        PoeReservedAllocation(
          originId: 'delivery-a',
          portId: 'pse-a',
          reservedW: _r('12'),
        ),
      ],
      pathStages: [
        PoePathStage(
          stageId: 'copper',
          kind: PoePathStageKind.copperCable,
          resourceKind: 'COPPER_PAIR',
          physicalRealized: true,
          powerPass: true,
          pairMappingResolved: true,
          allocationId: 'allocation-copper',
          cableRunId: 'run-copper',
        ),
      ],
      pseRoleConfirmed: true,
      pdRoleConfirmed: true,
      pseTransferLoss: PowerLossDefinition(
        efficiency: _r('0.9'),
        idleW: _r('5'),
        idleAccounting: PowerIdleAccounting.excludesSeparateIdle,
      ),
    );

PowerRational _r(String value) => PowerRational.fromWireDecimal(value);
