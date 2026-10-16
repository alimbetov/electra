import 'package:engineering_core/engineering_core.dart';
import 'package:test/test.dart';

void main() {
  test('PWR-01 PASS requires complete watt load/accounting, not solved A/VA', () {
    final evidence = buildPowerDemandEvidence(
      evaluationId: 'pwr01-qualification',
      revisionId: 'revision-1',
      scenarioId: 'normal',
      segmentId: 'steady',
      subjectKind: 'SOURCE',
      subjectId: 'aggregate',
      demand: aggregatePowerDemand([
        PowerDemandContribution(
          originId: 'load-1',
          componentId: 'device-1',
          inputPortId: 'input-1',
          stateCode: 'NORMAL',
          demand: DcConstantPowerDemand(PowerRational.integer(25)),
        ),
      ]),
    );

    expect(evidence.status, PowerEvaluationStatus.pass);
    expect(evidence.output['completeW'], isTrue);
    expect(evidence.output['completeA'], isFalse);
    expect(evidence.output['completeVa'], isFalse);
    expect(evidence.output['unresolvedWOriginIds'], isEmpty);
    expect(evidence.findings, isEmpty);
  });
}
