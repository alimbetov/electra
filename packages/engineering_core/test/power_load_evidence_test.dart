import 'package:engineering_core/engineering_core.dart';
import 'package:test/test.dart';

void main() {
  group('P4 deterministic evaluation evidence', () {
    test(
        'PWR-01 fingerprint and evidence ignore contribution enumeration order',
        () {
      final a = PowerDemandContribution(
        originId: 'camera-a:normal',
        componentId: 'camera-a',
        inputPortId: 'poe-a',
        stateCode: 'normal',
        demand: DcConstantPowerDemand(_r('8')),
      );
      final b = PowerDemandContribution(
        originId: 'camera-b:normal',
        componentId: 'camera-b',
        inputPortId: 'poe-b',
        stateCode: 'normal',
        demand: DcConstantPowerDemand(_r('12')),
      );

      final first = buildPowerDemandEvidence(
        evaluationId: 'eval-1',
        revisionId: 'revision-1',
        scenarioId: 'normal',
        segmentId: 'segment-1',
        subjectKind: 'SOURCE',
        subjectId: 'switch-1',
        demand: aggregatePowerDemand([a, b]),
      );
      final reordered = buildPowerDemandEvidence(
        evaluationId: 'eval-1',
        revisionId: 'revision-1',
        scenarioId: 'normal',
        segmentId: 'segment-1',
        subjectKind: 'SOURCE',
        subjectId: 'switch-1',
        demand: aggregatePowerDemand([b, a]),
      );

      expect(first.inputFingerprint, reordered.inputFingerprint);
      expect(first.evidenceSha256, reordered.evidenceSha256);
      expect(first.nodeKey.processCode, PowerProcessCode.pwr01);
      expect(first.output['completeW'], isTrue);
      expect(first.arithmeticSteps, hasLength(3));
    });

    test('PWR-01 unresolved contribution is explicit instead of zero-filled',
        () {
      final evidence = buildPowerDemandEvidence(
        evaluationId: 'eval-unresolved',
        revisionId: 'revision-1',
        scenarioId: 'normal',
        segmentId: 'segment-1',
        subjectKind: 'SOURCE',
        subjectId: 'psu-1',
        demand: aggregatePowerDemand([
          PowerDemandContribution(
            originId: 'unknown-load',
            componentId: 'device-1',
            inputPortId: 'dc-in',
            stateCode: 'normal',
            demand: null,
          ),
        ]),
      );

      expect(evidence.status, PowerEvaluationStatus.unresolved);
      expect(evidence.output['knownW'], PowerRational.zero.toMap());
      expect(evidence.output['completeW'], isFalse);
      expect(
        evidence.findings.map((value) => value.code),
        ['ELV4_POWER_DEMAND_INCOMPLETE'],
      );
    });

    test('PWR-02 evidence preserves reserve derating and signed margin', () {
      final input = PowerCapabilityDimension(
        dimension: PowerQuantityDimension.watt,
        demand: _r('30'),
        nameplate: _r('50'),
        reserveMultiplier: _r('1.2'),
        deratingFactor: _r('0.8'),
      );
      final assessment = evaluateSupplyCapability(input);
      final evidence = buildPowerCapabilityEvidence(
        evaluationId: 'eval-capacity',
        revisionId: 'revision-1',
        scenarioId: 'normal',
        segmentId: 'segment-1',
        subjectKind: 'CAPACITY_GROUP',
        subjectId: 'psu-1:main',
        input: input,
        assessment: assessment,
      );

      expect(evidence.status, PowerEvaluationStatus.pass);
      expect(evidence.nodeKey.processCode, PowerProcessCode.pwr02);
      expect(evidence.inputs['reserveMultiplier'], _r('1.2').toMap());
      expect(evidence.inputs['deratingFactor'], _r('0.8').toMap());
      expect(evidence.output['required'], _r('36').toMap());
      expect(evidence.output['available'], _r('40').toMap());
      expect(evidence.output['margin'], _r('4').toMap());
    });

    test('PWR-02 zero capacity reports undefined utilization explicitly', () {
      final input = PowerCapabilityDimension(
        dimension: PowerQuantityDimension.watt,
        demand: PowerRational.zero,
        nameplate: PowerRational.zero,
        reserveMultiplier: PowerRational.one,
        deratingFactor: PowerRational.one,
      );
      final evidence = buildPowerCapabilityEvidence(
        evaluationId: 'eval-zero',
        revisionId: 'revision-1',
        scenarioId: 'normal',
        segmentId: 'segment-1',
        subjectKind: 'CAPACITY_GROUP',
        subjectId: 'psu-1:zero',
        input: input,
        assessment: evaluateSupplyCapability(input),
      );

      expect(evidence.output['utilization'], isNull);
      expect(
        evidence.findings.map((value) => value.code),
        contains('ELV4_POWER_ZERO_AVAILABLE_CAPACITY'),
      );
    });
  });
}

PowerRational _r(String value) => PowerRational.fromWireDecimal(value);
