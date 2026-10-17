import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:test/test.dart';

Power _w(String v) => Power(Elv5Rational.parseDecimal(v));
Current _a(String v) => Current(Elv5Rational.parseDecimal(v));

void main() {
  test('FA04 projects exact PWR02 source margin without re-adding FA02', () {
    final result = const Fa04SourceRequirementKernel().evaluate(Fa04Input(
      sourceId: 'psu-1',
      expectedGlobalDemandFingerprint: 'demand-v1',
      pwr01GlobalDemandFingerprint: 'demand-v1',
      pwr02GlobalDemandFingerprint: 'demand-v1',
      expectedRequirementSetFingerprint: 'req-v1',
      pwr02RequirementSetFingerprint: 'req-v1',
      requirementContributors: ['fire-policy'],
      powerCases: [
        Fa04PowerCaseEvidence(
          caseId: 'alarm',
          globalDemand: _w('24'),
          requiredCapability: _w('30'),
          availableCapability: _w('40'),
        ),
      ],
      currentCases: [],
    ));
    expect(result.status, Fa04AssessmentStatus.pass);
    expect(result.powerCases.single.globalDemand, _w('24'));
    expect(result.powerCases.single.margin, _w('10'));
  });

  test('FA04 blocks reduced or mismatched global demand closure', () {
    final result = const Fa04SourceRequirementKernel().evaluate(Fa04Input(
      sourceId: 'psu-1',
      expectedGlobalDemandFingerprint: 'global',
      pwr01GlobalDemandFingerprint: 'fire-only',
      pwr02GlobalDemandFingerprint: 'global',
      expectedRequirementSetFingerprint: 'req-v1',
      pwr02RequirementSetFingerprint: 'req-v1',
      requirementContributors: ['fire-policy'],
      powerCases: [
        Fa04PowerCaseEvidence(
          caseId: 'alarm',
          globalDemand: _w('24'),
          requiredCapability: _w('30'),
          availableCapability: _w('40'),
        ),
      ],
      currentCases: [],
    ));
    expect(result.status, Fa04AssessmentStatus.blocked);
    expect(result.blockingReason, 'FA04_GLOBAL_DEMAND_CLOSURE_MISMATCH');
  });

  test('FA04 does not invent one PASS governing margin across W and A', () {
    final result = const Fa04SourceRequirementKernel().evaluate(Fa04Input(
      sourceId: 'psu-1',
      expectedGlobalDemandFingerprint: 'global',
      pwr01GlobalDemandFingerprint: 'global',
      pwr02GlobalDemandFingerprint: 'global',
      expectedRequirementSetFingerprint: 'req-v1',
      pwr02RequirementSetFingerprint: 'req-v1',
      requirementContributors: ['acs-policy', 'fire-policy'],
      powerCases: [
        Fa04PowerCaseEvidence(
          caseId: 'alarm-w',
          globalDemand: _w('30'),
          requiredCapability: _w('36'),
          availableCapability: _w('40'),
        ),
      ],
      currentCases: [
        Fa04CurrentCaseEvidence(
          caseId: 'alarm-a',
          globalDemand: _a('1.2'),
          requiredCapability: _a('1.5'),
          availableCapability: _a('2'),
        ),
      ],
    ));
    expect(result.status, Fa04AssessmentStatus.pass);
    expect(result.governingCaseId, isNull);
    expect(result.governingDimension, isNull);
  });
}
