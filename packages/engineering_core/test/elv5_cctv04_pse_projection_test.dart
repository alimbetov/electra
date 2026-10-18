import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:test/test.dart';

void main() {
  Power w(String value) => Power(Elv5Rational.parseDecimal(value));

  Cctv04Pwr06Evidence evidence(
          {String closure = 'closure-v1', String margin = '5'}) =>
      Cctv04Pwr06Evidence(
        pseId: 'pse-1',
        closureFingerprint: closure,
        globalDemand: w('30'),
        availableCapability: w('35'),
        globalMargin: w(margin),
        governingCaseId: 'peak',
        contributors: [
          Cctv04Pwr06Contributor(loadId: 'cctv-1', power: w('12')),
          Cctv04Pwr06Contributor(loadId: 'lan-1', power: w('10')),
          Cctv04Pwr06Contributor(loadId: 'lan-2', power: w('8')),
        ],
      );

  test('projects CCTV contribution while preserving global PSE totals', () {
    final result = const Cctv04PseProjectionKernel().evaluate(Cctv04Input(
      pseId: 'pse-1',
      expectedClosureFingerprint: 'closure-v1',
      cctvLoadIds: {'cctv-1'},
      evidence: evidence(),
    ));
    expect(result.status, Cctv04AssessmentStatus.pass);
    expect(result.globalDemand, w('30'));
    expect(result.cctvContribution, w('12'));
    expect(result.globalMargin, w('5'));
  });

  test('negative global margin fails despite small CCTV contribution', () {
    final result = const Cctv04PseProjectionKernel().evaluate(Cctv04Input(
      pseId: 'pse-1',
      expectedClosureFingerprint: 'closure-v1',
      cctvLoadIds: {'cctv-1'},
      evidence: evidence(margin: '-2'),
    ));
    expect(result.status, Cctv04AssessmentStatus.fail);
    expect(result.cctvContribution, w('12'));
  });

  test('mismatched physical closure is blocked', () {
    final result = const Cctv04PseProjectionKernel().evaluate(Cctv04Input(
      pseId: 'pse-1',
      expectedClosureFingerprint: 'closure-v2',
      cctvLoadIds: {'cctv-1'},
      evidence: evidence(),
    ));
    expect(result.status, Cctv04AssessmentStatus.blocked);
    expect(result.blockingReason, 'CCTV04_PWR06_CLOSURE_MISMATCH');
  });
}
