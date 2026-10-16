import 'package:engineering_core/engineering_core.dart';
import 'package:test/test.dart';

void main() {
  test('PWR-05 evidence is derived from UPS W/VA/input evaluation', () {
    final loss = PowerLossDefinition(
      efficiency: PowerRational(BigInt.from(9), BigInt.from(10)),
      idleW: PowerRational.zero,
      idleAccounting: PowerIdleAccounting.includesIdle,
    );

    PowerEvaluationEvidence build(String id) => buildUpsLoadingEvidence(
          evaluationId: id,
          revisionId: 'revision-1',
          scenarioId: 'backup',
          segmentId: 'steady',
          upsId: 'ups-1',
          protectedOutputW: PowerRational.integer(100),
          protectedOutputVa: PowerRational.integer(125),
          ratedOutputW: PowerRational.integer(500),
          ratedOutputVa: PowerRational.integer(625),
          transferLoss: loss,
          reserveMultiplier: PowerRational.one,
          deratingFactor: PowerRational.one,
          inputPowerFactor: PowerRational.one,
        );

    final first = build('eval-ups-1');
    final second = build('eval-ups-2');

    expect(first.status, PowerEvaluationStatus.pass);
    expect(first.nodeKey.processCode, PowerProcessCode.pwr05);
    expect(first.nodeKey.subjectKind, 'UPS');
    expect(first.output['inputVa'], isNotNull);
    expect(
      (first.output['outputW']! as Map<String, Object?>)['status'],
      'PASS',
    );
    expect(
      (first.output['outputVa']! as Map<String, Object?>)['status'],
      'PASS',
    );
    expect(first.inputFingerprint, second.inputFingerprint);
    expect(first.evidenceSha256, isNot(second.evidenceSha256));
  });
}
