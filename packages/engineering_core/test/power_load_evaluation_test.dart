import 'package:engineering_core/engineering_core.dart';
import 'package:test/test.dart';

void main() {
  group('P4 leaf demand and distinct-origin aggregation', () {
    test('missing demand stays unresolved while explicit zero remains known', () {
      final missing = resolvePowerContribution(
        PowerDemandContribution(
          originId: 'missing',
          componentId: 'device-a',
          inputPortId: 'in-a',
          stateCode: 'normal',
          demand: null,
        ),
      );
      expect(missing.watt, isNull);
      expect(
        missing.unresolvedDimensions,
        contains(PowerQuantityDimension.watt),
      );

      final zero = resolvePowerContribution(
        PowerDemandContribution(
          originId: 'off-state',
          componentId: 'device-a',
          inputPortId: 'in-a',
          stateCode: 'off',
          demand: DcConstantPowerDemand(PowerRational.zero),
        ),
      );
      expect(zero.watt, PowerRational.zero);
    });

    test('DC constant current never invents terminal voltage from nameplate', () {
      final unresolved = resolvePowerContribution(
        PowerDemandContribution(
          originId: 'lock-current',
          componentId: 'lock',
          inputPortId: 'dc-in',
          stateCode: 'normal',
          demand: DcConstantCurrentDemand(_r('0.5')),
        ),
      );
      expect(unresolved.ampere, _r('0.5'));
      expect(unresolved.watt, isNull);

      final solved = resolvePowerContribution(
        PowerDemandContribution(
          originId: 'lock-current',
          componentId: 'lock',
          inputPortId: 'dc-in',
          stateCode: 'normal',
          demand: DcConstantCurrentDemand(_r('0.5')),
          solvedTerminalVoltageV: _r('23'),
        ),
      );
      expect(solved.watt, _r('11.5'));
    });

    test('shared membership contributes once by origin and distinct loads twice',
        () {
      final camera = PowerDemandContribution(
        originId: 'camera-1:normal',
        componentId: 'camera-1',
        inputPortId: 'poe-in',
        stateCode: 'normal',
        demand: DcConstantPowerDemand(_r('10')),
      );
      final recorder = PowerDemandContribution(
        originId: 'recorder-1:normal',
        componentId: 'recorder-1',
        inputPortId: 'dc-in',
        stateCode: 'normal',
        demand: DcConstantPowerDemand(_r('10')),
      );

      final result = aggregatePowerDemand([camera, recorder, camera]);
      expect(result.contributions, hasLength(2));
      expect(result.knownW, _r('20'));
      expect(result.arithmeticSteps.first.inputRefs, [
        'camera-1:normal:W',
        'recorder-1:normal:W',
      ]);
    });

    test('same physical origin with contradictory demand is rejected', () {
      expect(
        () => aggregatePowerDemand([
          PowerDemandContribution(
            originId: 'camera-1:normal',
            componentId: 'camera-1',
            inputPortId: 'poe-in',
            stateCode: 'normal',
            demand: DcConstantPowerDemand(_r('10')),
          ),
          PowerDemandContribution(
            originId: 'camera-1:normal',
            componentId: 'camera-1',
            inputPortId: 'poe-in',
            stateCode: 'normal',
            demand: DcConstantPowerDemand(_r('12')),
          ),
        ]),
        throwsArgumentError,
      );
    });
  });

  group('P4 conversion and capacity', () {
    test('exclusive idle is added exactly once at transfer boundary', () {
      final result = evaluateTransferInputDemand(
        transferId: 'PSU-1',
        deliveredOutputW: _r('30'),
        loss: PowerLossDefinition(
          efficiency: _r('0.8'),
          idleW: _r('2'),
          idleAccounting: PowerIdleAccounting.excludesSeparateIdle,
        ),
      );

      expect(result.inputW, _r('39.5'));
      expect(result.lossW, _r('9.5'));
      expect(result.steps, hasLength(2));
    });

    test('reserve and derating affect sizing but not physical demand', () {
      final result = evaluateSupplyCapability(
        PowerCapabilityDimension(
          dimension: PowerQuantityDimension.watt,
          demand: _r('30'),
          nameplate: _r('50'),
          reserveMultiplier: _r('1.2'),
          deratingFactor: _r('0.8'),
        ),
      );

      expect(result.physicalDemand, _r('30'));
      expect(result.required, _r('36'));
      expect(result.available, _r('40'));
      expect(result.margin, _r('4'));
      expect(result.utilization, _r('0.9'));
      expect(result.status, PowerDimensionStatus.pass);
    });

    test('zero available capacity never divides by zero', () {
      final result = evaluateSupplyCapability(
        PowerCapabilityDimension(
          dimension: PowerQuantityDimension.watt,
          demand: PowerRational.zero,
          nameplate: PowerRational.zero,
          reserveMultiplier: PowerRational.one,
          deratingFactor: PowerRational.one,
        ),
      );

      expect(result.zeroCapacity, isTrue);
      expect(result.utilization, isNull);
    });

    test('UPS W and VA are independent dimensions', () {
      final result = evaluateUpsLoading(
        protectedOutputW: _r('40'),
        protectedOutputVa: _r('48'),
        ratedOutputW: _r('50'),
        ratedOutputVa: _r('45'),
        transferLoss: PowerLossDefinition(
          efficiency: _r('0.9'),
          idleW: PowerRational.zero,
          idleAccounting: PowerIdleAccounting.includesIdle,
        ),
        inputPowerFactor: _r('0.8'),
      );

      expect(result.watt.status, PowerDimensionStatus.pass);
      expect(result.voltAmpere.status, PowerDimensionStatus.fail);
      expect(result.status, PowerEvaluationStatus.fail);
      expect(result.inputW, PowerRational(BigInt.from(400), BigInt.from(9)));
      expect(result.inputVa, PowerRational(BigInt.from(500), BigInt.from(9)));
    });

    test('missing UPS input PF keeps upstream VA unresolved', () {
      final result = evaluateUpsLoading(
        protectedOutputW: _r('20'),
        protectedOutputVa: _r('25'),
        ratedOutputW: _r('50'),
        ratedOutputVa: _r('60'),
        transferLoss: PowerLossDefinition(
          efficiency: _r('1'),
          idleW: PowerRational.zero,
          idleAccounting: PowerIdleAccounting.includesIdle,
        ),
      );

      expect(result.watt.status, PowerDimensionStatus.pass);
      expect(result.voltAmpere.status, PowerDimensionStatus.pass);
      expect(result.inputVa, isNull);
      expect(result.status, PowerEvaluationStatus.unresolved);
    });
  });

  group('P4 peak envelope', () {
    test('ALL_SIMULTANEOUS preserves duration and does not average into steady',
        () {
      final pass = evaluateAllSimultaneousPeak(
        steadyW: _r('20'),
        pulses: [
          PowerPeakPulse(
            originId: 'motor-a',
            incrementW: _r('10'),
            durationSeconds: _r('1'),
          ),
          PowerPeakPulse(
            originId: 'motor-b',
            incrementW: _r('15'),
            durationSeconds: _r('2'),
          ),
        ],
        peakRatingW: _r('45'),
        ratingDurationSeconds: _r('2'),
      );
      expect(pass.maximumW, _r('45'));
      expect(pass.requiredDurationSeconds, _r('2'));
      expect(pass.status, PowerDimensionStatus.pass);

      final failDuration = evaluateAllSimultaneousPeak(
        steadyW: _r('20'),
        pulses: [
          PowerPeakPulse(
            originId: 'motor-b',
            incrementW: _r('15'),
            durationSeconds: _r('2'),
          ),
        ],
        peakRatingW: _r('100'),
        ratingDurationSeconds: _r('1'),
      );
      expect(failDuration.status, PowerDimensionStatus.fail);
    });
  });
}

PowerRational _r(String value) => PowerRational.fromWireDecimal(value);
