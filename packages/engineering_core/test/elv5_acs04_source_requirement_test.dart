import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:test/test.dart';

Power _w(String v) => Power(Elv5Rational.parseDecimal(v));

Acs04Input _input({required Power demand, required Power required, required Power available, bool conflict = false, String pwr01 = 'global', String pwr02 = 'global', String req = 'req'}) => Acs04Input(
  sourceId: 'psu-1',
  expectedGlobalDemandFingerprint: 'global',
  pwr01GlobalDemandFingerprint: pwr01,
  pwr02GlobalDemandFingerprint: pwr02,
  expectedRequirementSetFingerprint: 'req',
  pwr02RequirementSetFingerprint: req,
  requirementContributors: const ['ACS_POLICY'],
  powerCases: [Acs04PowerCaseEvidence(caseId: 'normal', globalDemand: demand, requiredCapability: required, availableCapability: available)],
  currentCases: const [],
  requirementConflict: conflict,
);

void main() {
  group('ACS-04 source requirement projection', () {
    test('projects global PWR-02 requirement without rewriting demand', () {
      final r = const Acs04SourceRequirementKernel().evaluate(_input(demand: _w('30'), required: _w('36'), available: _w('40')));
      expect(r.status, Acs04AssessmentStatus.pass);
      expect(r.powerCases.single.globalDemand, _w('30'));
      expect(r.powerCases.single.margin, _w('4'));
    });

    test('zero margin passes', () {
      final r = const Acs04SourceRequirementKernel().evaluate(_input(demand: _w('30'), required: _w('40'), available: _w('40')));
      expect(r.status, Acs04AssessmentStatus.pass);
      expect(r.powerCases.single.margin, _w('0'));
    });

    test('negative source margin fails', () {
      final r = const Acs04SourceRequirementKernel().evaluate(_input(demand: _w('35'), required: _w('42'), available: _w('40')));
      expect(r.status, Acs04AssessmentStatus.fail);
      expect(r.powerCases.single.margin, _w('-2'));
    });

    test('reduced ACS-only demand closure is blocked', () {
      final r = const Acs04SourceRequirementKernel().evaluate(_input(demand: _w('10'), required: _w('12'), available: _w('40'), pwr01: 'acs-only'));
      expect(r.status, Acs04AssessmentStatus.blocked);
      expect(r.blockingReason, 'ACS04_GLOBAL_DEMAND_CLOSURE_MISMATCH');
    });

    test('requirement semantic conflict is blocked', () {
      final r = const Acs04SourceRequirementKernel().evaluate(_input(demand: _w('30'), required: _w('36'), available: _w('40'), conflict: true));
      expect(r.status, Acs04AssessmentStatus.blocked);
    });
  });
}
