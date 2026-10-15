import 'package:engineering_core/engineering_core.dart';
import 'package:test/test.dart';

void main() {
  group('P6 radial constant-current DC solver', () {
    test('golden one-section feeder conserves exact source power', () {
      final result = solveDcConstantCurrentTree(
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

      expect(result.status, PowerEvaluationStatus.pass);
      expect(result.sourceCurrentA, _r('2'));
      expect(result.sections.single.dropV, _r('2'));
      expect(result.sections.single.lossW, _r('4'));
      expect(result.terminals.single.nominalV, _r('22'));
      expect(result.sourceNominalW, _r('48'));
      expect(result.deliveredNominalW, _r('44'));
      expect(result.totalLossW, _r('4'));
      expect(result.conservationResidualW, PowerRational.zero);
    });

    test('conductor resistance uses installed route and explicit contacts', () {
      final section = DcSection.conductorPerMeter(
        sectionId: 'run',
        parentNodeId: 'a',
        childNodeId: 'b',
        installedLengthM: _r('10'),
        forwardOhmPerM: _r('0.01'),
        returnOhmPerM: _r('0.01'),
        contactResistanceOhm: _r('0.1'),
        currentRatingA: _r('5'),
        evidenceRef: 'fixture:route-run',
      );
      expect(section.loopResistanceOhm, _r('0.3'));
    });

    test('undervoltage and overcurrent fail independently', () {
      final result = solveDcConstantCurrentTree(
        DcTreeInput(
          sourceNodeId: 'source',
          sourceVoltage: _dcEnvelope('24', '24', '24'),
          sections: [
            DcSection.loopTotal(
              sectionId: 's1',
              parentNodeId: 'source',
              childNodeId: 'load-node',
              loopResistanceOhm: _r('2'),
              currentRatingA: _r('2'),
              evidenceRef: 'fixture:s1',
            ),
          ],
          loads: [
            DcConstantCurrentLoad(
              loadId: 'lock',
              nodeId: 'load-node',
              currentA: _r('3'),
              allowedMinV: _r('20'),
              allowedMaxV: _r('25'),
            ),
          ],
        ),
      );

      expect(result.status, PowerEvaluationStatus.fail);
      expect(result.terminals.single.nominalV, _r('18'));
      expect(result.sections.single.currentMarginA, _r('-1'));
    });

    test('shared-return or two-parent structure is rejected before solving', () {
      expect(
        () => solveDcConstantCurrentTree(
          DcTreeInput(
            sourceNodeId: 'source',
            sourceVoltage: _dcEnvelope('24', '24', '24'),
            sections: [
              DcSection.loopTotal(
                sectionId: 'a-c',
                parentNodeId: 'a',
                childNodeId: 'c',
                loopResistanceOhm: _r('1'),
                currentRatingA: _r('2'),
                evidenceRef: 'a-c',
              ),
              DcSection.loopTotal(
                sectionId: 'b-c',
                parentNodeId: 'b',
                childNodeId: 'c',
                loopResistanceOhm: _r('1'),
                currentRatingA: _r('2'),
                evidenceRef: 'b-c',
              ),
            ],
            loads: const [],
          ),
        ),
        throwsArgumentError,
      );
    });
  });

  group('P6 bounded constant-power feeder', () {
    test('one-terminal high-voltage solution converges conservatively', () {
      final result = solveSingleConstantPowerFeeder(
        sourceVoltageV: _r('24'),
        loadPowerW: _r('10'),
        loopResistanceOhm: _r('1'),
      );

      expect(result.status, PowerEvaluationStatus.pass);
      expect(result.terminalVoltage, isNotNull);
      expect(result.terminalVoltage!.width <= _r('0.000000001'), isTrue);
      expect(result.terminalVoltage!.lower > _r('23'), isTrue);
      expect(result.current!.lower > PowerRational.zero, isTrue);
      expect(result.lossW!.upper > PowerRational.zero, isTrue);
    });

    test('infeasible constant-power feeder fails instead of inventing a current',
        () {
      final result = solveSingleConstantPowerFeeder(
        sourceVoltageV: _r('24'),
        loadPowerW: _r('200'),
        loopResistanceOhm: _r('1'),
      );
      expect(result.status, PowerEvaluationStatus.fail);
      expect(result.terminalVoltage, isNull);
      expect(result.current, isNull);
    });
  });

  group('P6 battery sequence and recharge', () {
    test('sequence Wh and correction factors are applied exactly once', () {
      final result = evaluateBatterySequence(
        segments: [
          BackupEnergySegment(
            segmentId: 'alarm',
            durationSeconds: _r('3600'),
            bankInputW: _r('100'),
          ),
          BackupEnergySegment(
            segmentId: 'standby',
            durationSeconds: _r('1800'),
            bankInputW: _r('50'),
          ),
        ],
        availability: BatteryWhAvailabilityModel(
          modelVoltageV: _r('24'),
          bankAh: _r('10'),
          initialSocFraction: _r('1'),
          minimumSocFraction: _r('0.2'),
          temperatureFactor: _r('0.8'),
          agingFactor: _r('0.9'),
          rateFactor: _r('1'),
        ),
      );

      expect(result.requiredWh, _r('125'));
      expect(result.availableWh, _r('172.8'));
      expect(result.marginWh, _r('47.8'));
      expect(result.status, PowerEvaluationStatus.pass);
      expect(result.estimatedAutonomySeconds, isNull);
    });

    test('autonomy is only exposed when an extension policy is explicit', () {
      final result = evaluateBatterySequence(
        segments: [
          BackupEnergySegment(
            segmentId: 'backup',
            durationSeconds: _r('3600'),
            bankInputW: _r('50'),
          ),
        ],
        availability: BatteryWhAvailabilityModel(
          modelVoltageV: _r('24'),
          bankAh: _r('10'),
          initialSocFraction: _r('1'),
          minimumSocFraction: _r('0.5'),
          temperatureFactor: _r('1'),
          agingFactor: _r('1'),
          rateFactor: _r('1'),
        ),
        extensionPolicy: PowerExtensionPolicy.continueLast,
      );

      expect(result.availableWh, _r('120'));
      expect(result.requiredWh, _r('50'));
      expect(result.estimatedAutonomySeconds, _r('8640'));
    });

    test('charger combines operating and recharge loads before efficiency', () {
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

      final result = evaluateChargerDemand(
        charger: charger,
        battery: battery,
        operatingOutputW: _r('20'),
        chargeVoltageV: _r('24'),
        selectedChargeCurrentA: _r('2'),
        chargingSelected: true,
        dischargingSelected: false,
      );
      expect(result.chargingOutputW, _r('48'));
      expect(result.combinedOutputW, _r('68'));
      expect(result.upstreamInputW, _r('87'));
      expect(result.status, PowerEvaluationStatus.pass);

      expect(
        () => evaluateChargerDemand(
          charger: charger,
          battery: battery,
          operatingOutputW: _r('20'),
          chargeVoltageV: _r('24'),
          selectedChargeCurrentA: _r('2'),
          chargingSelected: true,
          dischargingSelected: true,
        ),
        throwsArgumentError,
      );
    });
  });
}

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
