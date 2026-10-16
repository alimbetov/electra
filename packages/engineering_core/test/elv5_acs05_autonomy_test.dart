import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:test/test.dart';

Energy _e(String v) => Energy(Elv5Rational.parseDecimal(v));
Current _a(String v) => Current(Elv5Rational.parseDecimal(v));

Acs05Input _input({
  required Energy required,
  required Energy available,
  Current? peakMargin,
  bool eodPass = true,
  String sequenceFingerprint = 'seq-v1',
  String loadFingerprint = 'loads-v1',
  Set<String> covered = const {'standby'},
  List<Acs05ContributorEnergy>? contributors,
}) => Acs05Input(
  bankId: 'bank-1',
  expectedSequenceFingerprint: 'seq-v1',
  expectedProtectedLoadSetFingerprint: 'loads-v1',
  sequence: [Acs05SequenceSegment(segmentId: 'standby', durationMicroseconds: BigInt.from(3600000000))],
  acsProtectedLoadIds: const {'acs-lock'},
  evidence: Acs05Pwr04Evidence(
    sequenceFingerprint: sequenceFingerprint,
    protectedLoadSetFingerprint: loadFingerprint,
    coveredSegmentIds: covered,
    globalRequiredEnergy: required,
    availableEnergy: available,
    contributors: contributors ?? [Acs05ContributorEnergy(loadId: 'acs-lock', energy: _e('10'))],
    governingDimension: Acs05GoverningDimension.energy,
    governingSegmentId: 'standby',
    peakCurrentMargin: peakMargin,
    endOfDischargePass: eodPass,
  ),
);

void main() {
  group('ACS-05 autonomy projection', () {
    test('projects global PWR-04 energy and ACS contribution', () {
      final r = const Acs05AutonomyProjectionKernel().evaluate(_input(required: _e('19.2'), available: _e('134.4')));
      expect(r.status, Acs05AssessmentStatus.pass);
      expect(r.energyMargin, _e('115.2'));
      expect(r.acsContributionEnergy, _e('10'));
    });

    test('zero energy margin passes', () {
      final r = const Acs05AutonomyProjectionKernel().evaluate(_input(required: _e('134.4'), available: _e('134.4')));
      expect(r.status, Acs05AssessmentStatus.pass);
      expect(r.energyMargin, _e('0'));
    });

    test('peak-current failure governs even with positive energy margin', () {
      final r = const Acs05AutonomyProjectionKernel().evaluate(_input(required: _e('19.2'), available: _e('134.4'), peakMargin: _a('-0.5')));
      expect(r.status, Acs05AssessmentStatus.fail);
      expect(r.governingDimension, Acs05GoverningDimension.peakCurrent);
    });

    test('shared protected-load closure mismatch blocks ACS-only shortcut', () {
      final r = const Acs05AutonomyProjectionKernel().evaluate(_input(required: _e('10'), available: _e('134.4'), loadFingerprint: 'acs-only'));
      expect(r.status, Acs05AssessmentStatus.blocked);
      expect(r.blockingReason, 'ACS05_PROTECTED_LOAD_CLOSURE_MISMATCH');
    });

    test('missing sequence segment coverage blocks qualification', () {
      final r = const Acs05AutonomyProjectionKernel().evaluate(_input(required: _e('19.2'), available: _e('134.4'), covered: const {}));
      expect(r.status, Acs05AssessmentStatus.blocked);
      expect(r.blockingReason, 'ACS05_DURATION_COVERAGE_INCOMPLETE');
    });
  });
}
