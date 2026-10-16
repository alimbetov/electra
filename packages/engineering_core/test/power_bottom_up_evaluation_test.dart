import 'package:engineering_core/engineering_core.dart';
import 'package:test/test.dart';

void main() {
  group('P4-T08 bottom-up boundary contract', () {
    test('P5 PoE upstream demand enters P4 exactly once', () {
      final input = _poeInput();
      final poe = evaluatePoeDelivery(input);
      final child = poeUpstreamBoundary(
        groupId: 'pse-group-a',
        input: input,
        result: poe,
      );

      expect(poe.groupReservedW, _r('30'));
      expect(
        child.demandW,
        PowerRational(BigInt.from(115), BigInt.from(3)),
      );

      final result = evaluateBottomUpPowerBoundary(
        PowerBottomUpEvaluationInput(
          boundaryRef: 'ROOM-A',
          childBoundaries: [child],
        ),
      );

      expect(result.status, PowerEvaluationStatus.pass);
      expect(result.outputDemandW, child.demandW);
      expect(result.upstreamInputW, child.demandW);
      expect(result.localLossW, PowerRational.zero);
      expect(
        result.accountingKeys,
        contains('P5_PSE_GROUP_TRANSFER_PSE-GROUP-A'),
      );
    });

    test('shared PSE group-wide demand cannot be counted per delivery', () {
      final input = _poeInput();
      final first = poeUpstreamBoundary(
        groupId: 'pse-group-a',
        input: input,
        result: evaluatePoeDelivery(input),
      );

      final repeated = evaluateBottomUpPowerBoundary(
        PowerBottomUpEvaluationInput(
          boundaryRef: 'ROOM-A',
          childBoundaries: [first, first],
        ),
      );
      expect(repeated.upstreamInputW, first.demandW);

      final secondInput = _poeInput(deliveryId: 'delivery-c');
      final second = poeUpstreamBoundary(
        groupId: 'pse-group-a',
        input: secondInput,
        result: evaluatePoeDelivery(secondInput),
      );
      expect(
        () => evaluateBottomUpPowerBoundary(
          PowerBottomUpEvaluationInput(
            boundaryRef: 'ROOM-A',
            childBoundaries: [first, second],
          ),
        ),
        throwsArgumentError,
      );
    });

    test('a different parent transfer is applied once above a P5 boundary', () {
      final input = _poeInput();
      final child = poeUpstreamBoundary(
        groupId: 'pse-group-a',
        input: input,
        result: evaluatePoeDelivery(input),
      );

      final result = evaluateBottomUpPowerBoundary(
        PowerBottomUpEvaluationInput(
          boundaryRef: 'UPS-OUTPUT',
          childBoundaries: [child],
          localTransfer: PowerOwnedTransfer(
            transferId: 'UPS-1',
            accountingKey: 'P4_UPS_TRANSFER_UPS-1',
            loss: PowerLossDefinition(
              efficiency: _r('0.8'),
              idleW: _r('2'),
              idleAccounting: PowerIdleAccounting.excludesSeparateIdle,
            ),
          ),
        ),
      );

      expect(
        result.outputDemandW,
        PowerRational(BigInt.from(115), BigInt.from(3)),
      );
      expect(
        result.upstreamInputW,
        PowerRational(BigInt.from(599), BigInt.from(12)),
      );
      expect(
        result.accountingKeys,
        containsAll([
          'P5_PSE_GROUP_TRANSFER_PSE-GROUP-A',
          'P4_UPS_TRANSFER_UPS-1',
        ]),
      );
    });

    test('reusing an already-applied accounting key is rejected', () {
      final input = _poeInput();
      final child = poeUpstreamBoundary(
        groupId: 'pse-group-a',
        input: input,
        result: evaluatePoeDelivery(input),
      );

      expect(
        () => evaluateBottomUpPowerBoundary(
          PowerBottomUpEvaluationInput(
            boundaryRef: 'INVALID',
            childBoundaries: [child],
            localTransfer: PowerOwnedTransfer(
              transferId: 'PSE:delivery-b',
              accountingKey: child.accountingKeys.single,
              loss: PowerLossDefinition(
                efficiency: _r('0.9'),
                idleW: _r('5'),
                idleAccounting: PowerIdleAccounting.excludesSeparateIdle,
              ),
            ),
          ),
        ),
        throwsArgumentError,
      );
    });

    test('missing P5 upstream basis remains unresolved and never becomes zero',
        () {
      final input = _poeInput(
        groupInputBasis: PoeGroupInputBasis.estimatedActual,
      );
      final child = poeUpstreamBoundary(
        groupId: 'pse-group-a',
        input: input,
        result: evaluatePoeDelivery(input),
      );

      final result = evaluateBottomUpPowerBoundary(
        PowerBottomUpEvaluationInput(
          boundaryRef: 'ROOM-A',
          childBoundaries: [child],
        ),
      );

      expect(child.demandW, isNull);
      expect(result.status, PowerEvaluationStatus.unresolved);
      expect(result.upstreamInputW, isNull);
      expect(
        result.findings.map((finding) => finding.code),
        contains('ELV4_BOTTOM_UP_BOUNDARY_W_UNRESOLVED'),
      );
    });

    test('reserve changes capability sizing but never physical boundary demand',
        () {
      final child = PowerBoundaryDemand(
        originId: 'load-a',
        boundaryRef: 'LOAD-A',
        sourceRef: 'PWR01:load-a',
        status: PowerEvaluationStatus.pass,
        demandW: _r('10'),
        sourceOutputW: _r('10'),
        accountedLossW: PowerRational.zero,
      );
      final result = evaluateBottomUpPowerBoundary(
        PowerBottomUpEvaluationInput(
          boundaryRef: 'PANEL-A',
          childBoundaries: [child],
        ),
      );
      final capability = evaluateSupplyCapability(
        PowerCapabilityDimension(
          dimension: PowerQuantityDimension.watt,
          demand: result.upstreamInputW!,
          nameplate: _r('20'),
          reserveMultiplier: _r('1.2'),
          deratingFactor: PowerRational.one,
        ),
      );

      expect(result.upstreamInputW, _r('10'));
      expect(capability.physicalDemand, _r('10'));
      expect(capability.required, _r('12'));
    });
  });

  group('P6 -> P4 boundary adapters', () {
    test('DC feeder source demand already contains feeder loss exactly once',
        () {
      final dc = solveDcConstantCurrentTree(
        DcTreeInput(
          sourceNodeId: 'source',
          sourceVoltage: _dcEnvelope('24', '24', '24'),
          sections: [
            DcSection.loopTotal(
              sectionId: 's1',
              parentNodeId: 'source',
              childNodeId: 'load-node',
              loopResistanceOhm: _r('1'),
              currentRatingA: _r('3'),
              evidenceRef: 'fixture:s1',
            ),
          ],
          loads: [
            DcConstantCurrentLoad(
              loadId: 'lock',
              nodeId: 'load-node',
              currentA: _r('2'),
              allowedMinV: _r('20'),
              allowedMaxV: _r('25'),
            ),
          ],
        ),
      );
      final child = dcTreeSourceBoundary(
        originId: 'dc-domain-a',
        domainId: 'dc-a',
        result: dc,
      );
      final parent = evaluateBottomUpPowerBoundary(
        PowerBottomUpEvaluationInput(
          boundaryRef: 'PANEL-DC',
          childBoundaries: [child],
        ),
      );

      expect(dc.deliveredNominalW, _r('44'));
      expect(dc.totalLossW, _r('4'));
      expect(child.demandW, _r('48'));
      expect(parent.upstreamInputW, _r('48'));
      expect(parent.accountingKeys, contains('P6_DC_FEEDER_DC-A'));
    });

    test('charger conversion and idle enter P4 as one pre-accounted demand',
        () {
      final charger = PowerChargerDefinition(
        definitionRef: _ref(PowerDefinitionKind.transfer, 'CHARGER'),
        outputVoltage: _dcEnvelope('23', '24', '25'),
        maxChargeCurrentA: _r('5'),
        lossDefinition: PowerLossDefinition(
          efficiency: _r('0.8'),
          idleW: _r('2'),
          idleAccounting: PowerIdleAccounting.excludesSeparateIdle,
        ),
        supportedBatteryTechnologies: const ['VRLA'],
      );
      final battery = BatteryUnitDefinition(
        definitionRef: _ref(PowerDefinitionKind.battery, 'BATTERY'),
        technology: 'VRLA',
        nominalV: _r('24'),
        capacityBasis: BatteryCapacityBasis.ampHour,
        ratedCapacity: _r('10'),
        usableFraction: _r('0.8'),
        maxSeriesCount: 1,
        maxParallelCount: 2,
      );
      final evaluated = evaluateChargerDemand(
        charger: charger,
        battery: battery,
        operatingOutputW: _r('20'),
        chargeVoltageV: _r('24'),
        selectedChargeCurrentA: _r('2'),
        chargingSelected: true,
        dischargingSelected: false,
      );
      final child = chargerUpstreamBoundary(
        originId: 'charger-a',
        chargerId: 'charger-a',
        result: evaluated,
      );
      final parent = evaluateBottomUpPowerBoundary(
        PowerBottomUpEvaluationInput(
          boundaryRef: 'AC-PANEL',
          childBoundaries: [child],
        ),
      );

      expect(evaluated.combinedOutputW, _r('68'));
      expect(evaluated.upstreamInputW, _r('87'));
      expect(child.accountedLossW, _r('19'));
      expect(parent.upstreamInputW, _r('87'));
      expect(
        parent.accountingKeys,
        contains('P6_CHARGER_TRANSFER_CHARGER-A'),
      );
    });
  });
}

PoeEvaluationInput _poeInput({
  String deliveryId = 'delivery-b',
  PoeGroupInputBasis groupInputBasis = PoeGroupInputBasis.conservativeReserved,
}) =>
    PoeEvaluationInput(
      deliveryId: deliveryId,
      definition: PoeDeliveryDefinition(
        definitionRef: _ref(PowerDefinitionKind.poe, 'POE_FIXTURE'),
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
      sharedGroupBudgetW: _r('35'),
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
          allocationId: 'alloc-copper',
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

PowerVoltageEnvelope _dcEnvelope(String minV, String nominalV, String maxV) =>
    PowerVoltageEnvelope(
      currentKind: PowerCurrentKind.dc,
      minV: _r(minV),
      nominalV: _r(nominalV),
      maxV: _r(maxV),
    );

PowerDefinitionRef _ref(PowerDefinitionKind kind, String code) =>
    PowerDefinitionRef(
      catalogId: 'catalog',
      catalogVersion: '1',
      definitionKind: kind,
      definitionCode: code,
      definitionVersion: '1',
      definitionSchema: 'electra.fixture.v1',
      contentSha256:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      sourceRef: 'fixture:$code',
    );

PowerRational _r(String value) => PowerRational.fromWireDecimal(value);
