import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:test/test.dart';

void main() {
  Power w(String value) => Power(Elv5Rational.parseDecimal(value));

  Lan03Pwr06Evidence evidence({
    String closure = 'closure-v1',
    String pse = 'pse-1',
    String margin = '5',
  }) =>
      Lan03Pwr06Evidence(
        pseId: pse,
        closureFingerprint: closure,
        globalDemand: w('30'),
        availableCapability: w('35'),
        globalMargin: w(margin),
        governingCaseId: 'peak',
        contributors: [
          Lan03Pwr06Contributor(loadId: 'lan-1', power: w('10')),
          Lan03Pwr06Contributor(loadId: 'lan-2', power: w('8')),
          Lan03Pwr06Contributor(loadId: 'cctv-1', power: w('12')),
        ],
      );

  test('projects LAN contribution without filtering global physical demand',
      () {
    final result = const Lan03PoeProjectionKernel().evaluate(Lan03Input(
      pseId: 'pse-1',
      expectedClosureFingerprint: 'closure-v1',
      lanLoadIds: {'lan-1', 'lan-2'},
      evidence: evidence(),
    ));
    expect(result.status, Lan03AssessmentStatus.pass);
    expect(result.globalDemand, w('30'));
    expect(result.lanContribution, w('18'));
    expect(result.globalMargin, w('5'));
  });

  test('zero upstream margin remains inclusive PASS', () {
    final result = const Lan03PoeProjectionKernel().evaluate(Lan03Input(
      pseId: 'pse-1',
      expectedClosureFingerprint: 'closure-v1',
      lanLoadIds: {'lan-1'},
      evidence: evidence(margin: '0'),
    ));
    expect(result.status, Lan03AssessmentStatus.pass);
  });

  test('negative global margin fails even when LAN contribution is small', () {
    final result = const Lan03PoeProjectionKernel().evaluate(Lan03Input(
      pseId: 'pse-1',
      expectedClosureFingerprint: 'closure-v1',
      lanLoadIds: {'lan-2'},
      evidence: evidence(margin: '-3'),
    ));
    expect(result.status, Lan03AssessmentStatus.fail);
    expect(result.lanContribution, w('8'));
  });

  test('reduced or stale physical closure is blocked', () {
    final result = const Lan03PoeProjectionKernel().evaluate(Lan03Input(
      pseId: 'pse-1',
      expectedClosureFingerprint: 'closure-v2',
      lanLoadIds: {'lan-1'},
      evidence: evidence(),
    ));
    expect(result.status, Lan03AssessmentStatus.blocked);
    expect(result.blockingReason, 'LAN03_PWR06_CLOSURE_MISMATCH');
  });
}
