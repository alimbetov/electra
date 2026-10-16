import '../../numeric/quantity.dart';
import '../../numeric/rational.dart';

enum Acs05AssessmentStatus { pass, fail, blocked }

enum Acs05GoverningDimension { energy, peakCurrent, endOfDischarge }

final class Acs05SequenceSegment {
  Acs05SequenceSegment({
    required this.segmentId,
    required this.durationMicroseconds,
  }) {
    if (segmentId.isEmpty) throw ArgumentError('ACS05 segmentId must not be empty.');
    if (durationMicroseconds <= BigInt.zero) {
      throw ArgumentError('ACS05 segment duration must be positive.');
    }
  }

  final String segmentId;
  final BigInt durationMicroseconds;
}

final class Acs05ContributorEnergy {
  Acs05ContributorEnergy({required this.loadId, required this.energy}) {
    if (loadId.isEmpty) throw ArgumentError('ACS05 loadId must not be empty.');
    if (energy.value < Elv5Rational.zero) {
      throw ArgumentError('ACS05 contributor energy must be nonnegative.');
    }
  }

  final String loadId;
  final Energy energy;
}

final class Acs05Pwr04Evidence {
  Acs05Pwr04Evidence({
    required this.sequenceFingerprint,
    required this.protectedLoadSetFingerprint,
    required this.coveredSegmentIds,
    required this.globalRequiredEnergy,
    required this.availableEnergy,
    required this.contributors,
    required this.governingDimension,
    this.governingSegmentId,
    this.peakCurrentMargin,
    this.endOfDischargePass = true,
  }) {
    if (sequenceFingerprint.isEmpty || protectedLoadSetFingerprint.isEmpty) {
      throw ArgumentError('ACS05 evidence fingerprints must not be empty.');
    }
    if (globalRequiredEnergy.value < Elv5Rational.zero ||
        availableEnergy.value < Elv5Rational.zero) {
      throw ArgumentError('ACS05 energy values must be nonnegative.');
    }
    final ids = <String>{};
    for (final contributor in contributors) {
      if (!ids.add(contributor.loadId)) {
        throw ArgumentError('ACS05 duplicate contributor loadId: ${contributor.loadId}');
      }
    }
    if (governingDimension != Acs05GoverningDimension.energy &&
        (governingSegmentId == null || governingSegmentId!.isEmpty)) {
      throw ArgumentError(
        'ACS05 non-energy governing dimension requires a governing segment.',
      );
    }
  }

  final String sequenceFingerprint;
  final String protectedLoadSetFingerprint;
  final Set<String> coveredSegmentIds;
  final Energy globalRequiredEnergy;
  final Energy availableEnergy;
  final List<Acs05ContributorEnergy> contributors;
  final Acs05GoverningDimension governingDimension;
  final String? governingSegmentId;
  final Current? peakCurrentMargin;
  final bool endOfDischargePass;
}

final class Acs05Input {
  Acs05Input({
    required this.bankId,
    required this.expectedSequenceFingerprint,
    required this.expectedProtectedLoadSetFingerprint,
    required this.sequence,
    required this.acsProtectedLoadIds,
    required this.evidence,
  }) {
    if (bankId.isEmpty ||
        expectedSequenceFingerprint.isEmpty ||
        expectedProtectedLoadSetFingerprint.isEmpty) {
      throw ArgumentError('ACS05 required identity must not be empty.');
    }
    if (sequence.isEmpty) throw ArgumentError('ACS05 sequence must not be empty.');
    final ids = <String>{};
    for (final segment in sequence) {
      if (!ids.add(segment.segmentId)) {
        throw ArgumentError('ACS05 duplicate segmentId: ${segment.segmentId}');
      }
    }
  }

  final String bankId;
  final String expectedSequenceFingerprint;
  final String expectedProtectedLoadSetFingerprint;
  final List<Acs05SequenceSegment> sequence;
  final Set<String> acsProtectedLoadIds;
  final Acs05Pwr04Evidence evidence;
}

final class Acs05Result {
  const Acs05Result({
    required this.status,
    required this.globalRequiredEnergy,
    required this.availableEnergy,
    required this.energyMargin,
    required this.acsContributionEnergy,
    required this.governingDimension,
    required this.governingSegmentId,
    this.blockingReason,
  });

  final Acs05AssessmentStatus status;
  final Energy globalRequiredEnergy;
  final Energy availableEnergy;
  final Energy energyMargin;
  final Energy acsContributionEnergy;
  final Acs05GoverningDimension governingDimension;
  final String? governingSegmentId;
  final String? blockingReason;
}

final class Acs05AutonomyProjectionKernel {
  const Acs05AutonomyProjectionKernel();

  Acs05Result evaluate(Acs05Input input) {
    final evidence = input.evidence;
    if (evidence.sequenceFingerprint != input.expectedSequenceFingerprint) {
      return _blocked(input, 'ACS05_SEQUENCE_FINGERPRINT_MISMATCH');
    }
    if (evidence.protectedLoadSetFingerprint != input.expectedProtectedLoadSetFingerprint) {
      return _blocked(input, 'ACS05_PROTECTED_LOAD_CLOSURE_MISMATCH');
    }
    final requiredSegments = input.sequence.map((e) => e.segmentId).toSet();
    if (!evidence.coveredSegmentIds.containsAll(requiredSegments)) {
      return _blocked(input, 'ACS05_DURATION_COVERAGE_INCOMPLETE');
    }

    var acsContribution = Energy(Elv5Rational.zero);
    final contributorIds = evidence.contributors.map((e) => e.loadId).toSet();
    if (!contributorIds.containsAll(input.acsProtectedLoadIds)) {
      return _blocked(input, 'ACS05_ACS_CONTRIBUTOR_EVIDENCE_INCOMPLETE');
    }
    for (final contributor in evidence.contributors) {
      if (input.acsProtectedLoadIds.contains(contributor.loadId)) {
        acsContribution = acsContribution + contributor.energy;
      }
    }

    final energyMargin = evidence.availableEnergy - evidence.globalRequiredEnergy;
    var status = energyMargin.value >= Elv5Rational.zero
        ? Acs05AssessmentStatus.pass
        : Acs05AssessmentStatus.fail;
    var governingDimension = evidence.governingDimension;
    var governingSegmentId = evidence.governingSegmentId;
    if (evidence.peakCurrentMargin != null &&
        evidence.peakCurrentMargin!.value < Elv5Rational.zero) {
      status = Acs05AssessmentStatus.fail;
      governingDimension = Acs05GoverningDimension.peakCurrent;
    } else if (!evidence.endOfDischargePass) {
      status = Acs05AssessmentStatus.fail;
      governingDimension = Acs05GoverningDimension.endOfDischarge;
    } else if (energyMargin.value < Elv5Rational.zero) {
      governingDimension = Acs05GoverningDimension.energy;
      governingSegmentId = null;
    }

    return Acs05Result(
      status: status,
      globalRequiredEnergy: evidence.globalRequiredEnergy,
      availableEnergy: evidence.availableEnergy,
      energyMargin: energyMargin,
      acsContributionEnergy: acsContribution,
      governingDimension: governingDimension,
      governingSegmentId: governingSegmentId,
    );
  }

  static Acs05Result _blocked(Acs05Input input, String reason) {
    final evidence = input.evidence;
    return Acs05Result(
      status: Acs05AssessmentStatus.blocked,
      globalRequiredEnergy: evidence.globalRequiredEnergy,
      availableEnergy: evidence.availableEnergy,
      energyMargin: evidence.availableEnergy - evidence.globalRequiredEnergy,
      acsContributionEnergy: Energy(Elv5Rational.zero),
      governingDimension: evidence.governingDimension,
      governingSegmentId: evidence.governingSegmentId,
      blockingReason: reason,
    );
  }
}
