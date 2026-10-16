import 'package:engineering_core/engineering_core.dart';
import 'package:test/test.dart';

void main() {
  group('P5 PoE qualification and path', () {
    test('roles are explicit and never inferred from connector labels', () {
      final result = evaluatePoeDelivery(
        _input(
          pseRoleConfirmed: false,
          pdRoleConfirmed: true,
        ),
      );

      expect(result.status, PowerEvaluationStatus.blocked);
      expect(
        result.findings.map((finding) => finding.code),
        contains('ELV4_POE_ROLE_MISMATCH'),
      );
    });

    test('missing realization is unresolved while known fiber blocks power',
        () {
      final missing = evaluatePoeDelivery(
        _input(
          pathStages: [
            _stage('copper', physicalRealized: false),
          ],
        ),
      );
      expect(missing.status, PowerEvaluationStatus.unresolved);

      final fiber = evaluatePoeDelivery(
        _input(
          pathStages: [
            PoePathStage(
              stageId: 'fiber',
              kind: PoePathStageKind.fiber,
              resourceKind: 'FIBER',
              physicalRealized: true,
              powerPass: false,
              pairMappingResolved: true,
              allocationId: 'alloc-fiber',
              cableRunId: 'run-fiber',
            ),
          ],
        ),
      );
      expect(fiber.status, PowerEvaluationStatus.blocked);
      expect(
        fiber.findings.map((finding) => finding.code),
        contains('ELV4_POE_FIBER_NONCONDUCTIVE'),
      );
    });

    test('explicit path loss remains blocked until balanced-pair model exists',
        () {
      final result = evaluatePoeDelivery(
        _input(accountingMode: PoeAccountingMode.explicitPathLoss),
      );
      expect(result.status, PowerEvaluationStatus.blocked);
      expect(
        result.findings.map((finding) => finding.code),
        contains('ELV4_POE_EXPLICIT_PATH_LOSS_UNSUPPORTED'),
      );
    });
  });

  group('P5 GUARANTEED_PD accounting', () {
    test('golden shared reservation and upstream PSE input are exact', () {
      final result = evaluatePoeDelivery(
        _input(
          deliveryId: 'delivery-b',
          pdDemandW: _r('15'),
          reservedPseW: _r('18'),
          portAllocationLimitW: _r('20'),
          groupBudgetW: _r('35'),
          existing: [
            PoeReservedAllocation(
              originId: 'delivery-a',
              portId: 'pse-a',
              reservedW: _r('12'),
            ),
          ],
        ),
      );

      expect(result.status, PowerEvaluationStatus.pass);
      expect(result.groupReservedW, _r('30'));
      expect(result.groupMarginW, _r('5'));
      expect(result.pdMarginW, _r('0'));
      expect(result.portMarginW, _r('2'));
      expect(
        result.upstreamInputW,
        PowerRational(BigInt.from(115), BigInt.from(3)),
      );
    });

    test('port and group limits fail independently', () {
      final portFail = evaluatePoeDelivery(
        _input(
          deliveryId: 'delivery-b',
          pdDemandW: _r('15'),
          reservedPseW: _r('18'),
          portAllocationLimitW: _r('17'),
          groupBudgetW: _r('35'),
          existing: [
            PoeReservedAllocation(
              originId: 'delivery-a',
              portId: 'pse-a',
              reservedW: _r('12'),
            ),
          ],
        ),
      );
      expect(portFail.status, PowerEvaluationStatus.fail);
      expect(
        portFail.findings.map((finding) => finding.code),
        contains('ELV4_POE_PORT_ALLOCATION_EXCEEDED'),
      );
      expect(portFail.groupMarginW, _r('5'));

      final groupFail = evaluatePoeDelivery(
        _input(
          deliveryId: 'delivery-b',
          pdDemandW: _r('15'),
          reservedPseW: _r('18'),
          portAllocationLimitW: _r('20'),
          groupBudgetW: _r('29'),
          existing: [
            PoeReservedAllocation(
              originId: 'delivery-a',
              portId: 'pse-a',
              reservedW: _r('12'),
            ),
          ],
        ),
      );
      expect(groupFail.status, PowerEvaluationStatus.fail);
      expect(
        groupFail.findings.map((finding) => finding.code),
        contains('ELV4_POE_GROUP_BUDGET_EXCEEDED'),
      );
      expect(groupFail.portMarginW, _r('2'));
    });

    test('same reservation origin is counted once across shared memberships',
        () {
      final result = evaluatePoeDelivery(
        _input(
          deliveryId: 'delivery-a',
          reservedPseW: _r('12'),
          existing: [
            PoeReservedAllocation(
              originId: 'delivery-a',
              portId: 'pse-a',
              reservedW: _r('12'),
            ),
          ],
        ),
      );
      expect(result.groupReservedW, _r('12'));
    });

    test('actual group basis never silently falls back to reserved basis', () {
      final result = evaluatePoeDelivery(
        _input(groupInputBasis: PoeGroupInputBasis.estimatedActual),
      );
      expect(result.status, PowerEvaluationStatus.unresolved);
      expect(result.upstreamInputW, isNull);
      expect(
        result.findings.map((finding) => finding.code),
        contains('ELV4_POE_ACTUAL_GROUP_OUTPUT_MISSING'),
      );
    });
  });

  group('P5 midspan boundary', () {
    test('midspan has separate data and supply ports and requires support', () {
      final unsupported = evaluatePoeDelivery(
        _input(
          definition: _definition(supportsMidspan: false),
          midspan: PoeMidspanContext(
            injectorComponentId: 'injector',
            dataInputPortId: 'data-in',
            combinedOutputPortId: 'data-power-out',
            supplyInputPortId: 'dc-in',
          ),
        ),
      );
      expect(unsupported.status, PowerEvaluationStatus.blocked);
      expect(
        unsupported.findings.map((finding) => finding.code),
        contains('ELV4_POE_MIDSPAN_UNSUPPORTED'),
      );
    });
  });
}

PoeEvaluationInput _input({
  String deliveryId = 'delivery',
  PoeDeliveryDefinition? definition,
  PoeAccountingMode accountingMode = PoeAccountingMode.guaranteedPd,
  PoeGroupInputBasis groupInputBasis = PoeGroupInputBasis.conservativeReserved,
  PowerRational? pdDemandW,
  PowerRational? reservedPseW,
  PowerRational? portAllocationLimitW,
  PowerRational? groupBudgetW,
  Iterable<PoeReservedAllocation> existing = const [],
  Iterable<PoePathStage>? pathStages,
  bool pseRoleConfirmed = true,
  bool pdRoleConfirmed = true,
  PoeMidspanContext? midspan,
}) =>
    PoeEvaluationInput(
      deliveryId: deliveryId,
      definition: definition ?? _definition(),
      accountingMode: accountingMode,
      groupInputBasis: groupInputBasis,
      pdDemandW: pdDemandW ?? _r('10'),
      reservedPseW: reservedPseW ?? _r('12'),
      portAllocationLimitW: portAllocationLimitW ?? _r('20'),
      sharedGroupBudgetW: groupBudgetW ?? _r('35'),
      existingGroupReservations: existing,
      pathStages: pathStages ?? [_stage('copper')],
      pseRoleConfirmed: pseRoleConfirmed,
      pdRoleConfirmed: pdRoleConfirmed,
      pseTransferLoss: PowerLossDefinition(
        efficiency: _r('0.9'),
        idleW: _r('5'),
        idleAccounting: PowerIdleAccounting.excludesSeparateIdle,
      ),
      midspan: midspan,
    );

PoePathStage _stage(
  String id, {
  bool physicalRealized = true,
}) =>
    PoePathStage(
      stageId: id,
      kind: PoePathStageKind.copperCable,
      resourceKind: 'COPPER_PAIR',
      physicalRealized: physicalRealized,
      powerPass: true,
      pairMappingResolved: true,
      allocationId: physicalRealized ? 'alloc-$id' : null,
      cableRunId: physicalRealized ? 'run-$id' : null,
    );

PoeDeliveryDefinition _definition({bool supportsMidspan = true}) =>
    PoeDeliveryDefinition(
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
      supportsMidspan: supportsMidspan,
    );

PowerRational _r(String value) => PowerRational.fromWireDecimal(value);
