import '../../numeric/quantity.dart';
import '../../numeric/rational.dart';

enum Fa05AssessmentStatus { pass, fail, blocked }

enum Fa05GoverningDimension { energy, peakCurrent, endOfDischarge }

final class Fa05SequenceSegment {
  Fa05SequenceSegment({
    required this.segmentId,
    required this.durationMicroseconds,
  }) {
    if (segmentId.isEmpty)
      throw ArgumentError('FA05 segmentId must not be empty.');
    if (durationMicroseconds <= BigInt.zero) {
      throw ArgumentError('FA05 segment duration must be positive.');
    }
  }

  final String segmentId;
  final BigInt durationMicroseconds;
}

final class Fa05ContributorEnergy {
  Fa05ContributorEnergy({required this.loadId, required this.energy}) {
    if (loadId.isEmpty) throw ArgumentError('FA05 loadId must not be empty.');
    if (energy.value < Elv5Rational.zero) {
      throw ArgumentError('FA05 contributor energy must be nonnegative.');
    }
  }

  final String loadId;
  final Energy energy;
}

final class Fa05Pwr04Evidence {
  Fa05Pwr04Evidence({
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
      throw ArgumentError('FA05 evidence fingerprints must not be empty.');
    }
    if (globalRequiredEnergy.value < Elv5Rational.zero ||
        availableEnergy.value < Elv5Rational.zero) {
      throw ArgumentError('FA05 energy values must be nonnegative.');
    }
    if (governingDimension != Fa05GoverningDimension.energy &&
        (governingSegmentId == null || governingSegmentId!.isEmpty)) {
      throw ArgumentError(
        'FA05 non-energy governing dimension requires a segment identity.',
      );
    }
    final ids = <String>{};
    for (final contributor in contributors) {
      if (!ids.add(contributor.loadId)) {
        throw ArgumentError(
            'FA05 duplicate contributor loadId: ${contributor.loadId}');
      }
    }
  }

  final String sequenceFingerprint;
  final String protectedLoadSetFingerprint;
  final Set<String> coveredSegmentIds;
  final Energy globalRequiredEnergy;
  final Energy availableEnergy;
  final List<Fa05ContributorEnergy> contributors;
  final Fa05GoverningDimension governingDimension;
  final String? governingSegmentId;
  final Current? peakCurrentMargin;
  final bool endOfDischargePass;
}

final class Fa05Input {
  Fa05Input({
    required this.bankId,
    required this.expectedSequenceFingerprint,
    required this.expectedProtectedLoadSetFingerprint,
    required this.sequence,
    required this.fireProtectedLoadIds,
    required this.evidence,
  }) {
    if (bankId.isEmpty ||
        expectedSequenceFingerprint.isEmpty ||
        expectedProtectedLoadSetFingerprint.isEmpty) {
      throw ArgumentError('FA05 required identity must not be empty.');
    }
    if (sequence.isEmpty)
      throw ArgumentError('FA05 sequence must not be empty.');
    final ids = <String>{};
    for (final segment in sequence) {
      if (!ids.add(segment.segmentId)) {
        throw ArgumentError('FA05 duplicate segmentId: ${segment.segmentId}');
      }
    }
  }

  final String bankId;
  final String expectedSequenceFingerprint;
  final String expectedProtectedLoadSetFingerprint;
  final List<Fa05SequenceSegment> sequence;
  final Set<String> fireProtectedLoadIds;
  final Fa05Pwr04Evidence evidence;
}

final class Fa05Result {
  const Fa05Result({
    required this.status,
    required this.globalRequiredEnergy,
    required this.availableEnergy,
    required this.energyMargin,
    required this.fireContributionEnergy,
    required this.governingDimension,
    this.governingSegmentId,
    this.blockingReason,
  });

  final Fa05AssessmentStatus status;
  final Energy globalRequiredEnergy;
  final Energy availableEnergy;
  final Energy energyMargin;
  final Energy fireContributionEnergy;
  final Fa05GoverningDimension governingDimension;
  final String? governingSegmentId;
  final String? blockingReason;
}

final class Fa05AutonomyProjectionKernel {
  const Fa05AutonomyProjectionKernel();

  Fa05Result evaluate(Fa05Input input) {
    final evidence = input.evidence;
    if (evidence.sequenceFingerprint != input.expectedSequenceFingerprint) {
      return _blocked(input, 'FA05_SEQUENCE_FINGERPRINT_MISMATCH');
    }
    if (evidence.protectedLoadSetFingerprint !=
        input.expectedProtectedLoadSetFingerprint) {
      return _blocked(input, 'FA05_PROTECTED_LOAD_CLOSURE_MISMATCH');
    }
    final requiredSegments = input.sequence.map((e) => e.segmentId).toSet();
    if (!evidence.coveredSegmentIds.containsAll(requiredSegments)) {
      return _blocked(input, 'FA05_DURATION_COVERAGE_INCOMPLETE');
    }

    final contributorIds = evidence.contributors.map((e) => e.loadId).toSet();
    if (!contributorIds.containsAll(input.fireProtectedLoadIds)) {
      return _blocked(input, 'FA05_FIRE_CONTRIBUTOR_EVIDENCE_INCOMPLETE');
    }
    var fireContribution = Energy(Elv5Rational.zero);
    for (final contributor in evidence.contributors) {
      if (input.fireProtectedLoadIds.contains(contributor.loadId)) {
        fireContribution = fireContribution + contributor.energy;
      }
    }

    final energyMargin =
        evidence.availableEnergy - evidence.globalRequiredEnergy;
    var status = energyMargin.value >= Elv5Rational.zero
        ? Fa05AssessmentStatus.pass
        : Fa05AssessmentStatus.fail;
    var governing = evidence.governingDimension;
    var governingSegment = evidence.governingSegmentId;
    if (evidence.peakCurrentMargin != null &&
        evidence.peakCurrentMargin!.value < Elv5Rational.zero) {
      status = Fa05AssessmentStatus.fail;
      governing = Fa05GoverningDimension.peakCurrent;
    } else if (!evidence.endOfDischargePass) {
      status = Fa05AssessmentStatus.fail;
      governing = Fa05GoverningDimension.endOfDischarge;
    } else if (energyMargin.value < Elv5Rational.zero) {
      governing = Fa05GoverningDimension.energy;
      governingSegment = null;
    } else if (governing == Fa05GoverningDimension.energy) {
      governingSegment = null;
    }

    return Fa05Result(
      status: status,
      globalRequiredEnergy: evidence.globalRequiredEnergy,
      availableEnergy: evidence.availableEnergy,
      energyMargin: energyMargin,
      fireContributionEnergy: fireContribution,
      governingDimension: governing,
      governingSegmentId: governingSegment,
    );
  }

  static Fa05Result _blocked(Fa05Input input, String reason) {
    final e = input.evidence;
    return Fa05Result(
      status: Fa05AssessmentStatus.blocked,
      globalRequiredEnergy: e.globalRequiredEnergy,
      availableEnergy: e.availableEnergy,
      energyMargin: e.availableEnergy - e.globalRequiredEnergy,
      fireContributionEnergy: Energy(Elv5Rational.zero),
      governingDimension: e.governingDimension,
      governingSegmentId: e.governingSegmentId,
      blockingReason: reason,
    );
  }
}
