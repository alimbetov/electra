import '../../numeric/quantity.dart';
import '../../numeric/rational.dart';

enum Cctv04AssessmentStatus { pass, fail, blocked }

final class Cctv04Pwr06Contributor {
  Cctv04Pwr06Contributor({required this.loadId, required this.power}) {
    if (loadId.isEmpty) throw ArgumentError('CCTV04 loadId must not be empty.');
    if (power.value < Elv5Rational.zero) {
      throw ArgumentError('CCTV04 contributor power must be nonnegative.');
    }
  }

  final String loadId;
  final Power power;
}

final class Cctv04Pwr06Evidence {
  Cctv04Pwr06Evidence({
    required this.pseId,
    required this.closureFingerprint,
    required this.globalDemand,
    required this.availableCapability,
    required this.globalMargin,
    required this.governingCaseId,
    required this.contributors,
  }) {
    if (pseId.isEmpty || closureFingerprint.isEmpty || governingCaseId.isEmpty) {
      throw ArgumentError('CCTV04 evidence identity must not be empty.');
    }
    final seen = <String>{};
    for (final contributor in contributors) {
      if (!seen.add(contributor.loadId)) {
        throw ArgumentError('CCTV04 duplicate contributor loadId: ${contributor.loadId}');
      }
    }
  }

  final String pseId;
  final String closureFingerprint;
  final Power globalDemand;
  final Power availableCapability;
  final Power globalMargin;
  final String governingCaseId;
  final List<Cctv04Pwr06Contributor> contributors;
}

final class Cctv04Input {
  Cctv04Input({
    required this.pseId,
    required this.expectedClosureFingerprint,
    required this.cctvLoadIds,
    required this.evidence,
  }) {
    if (pseId.isEmpty || expectedClosureFingerprint.isEmpty) {
      throw ArgumentError('CCTV04 input identity must not be empty.');
    }
  }

  final String pseId;
  final String expectedClosureFingerprint;
  final Set<String> cctvLoadIds;
  final Cctv04Pwr06Evidence evidence;
}

final class Cctv04Result {
  const Cctv04Result({
    required this.status,
    required this.globalDemand,
    required this.availableCapability,
    required this.globalMargin,
    required this.cctvContribution,
    required this.governingCaseId,
    required this.blockingReason,
  });

  final Cctv04AssessmentStatus status;
  final Power globalDemand;
  final Power availableCapability;
  final Power globalMargin;
  final Power cctvContribution;
  final String governingCaseId;
  final String? blockingReason;
}

final class Cctv04PseProjectionKernel {
  const Cctv04PseProjectionKernel();

  Cctv04Result evaluate(Cctv04Input input) {
    final evidence = input.evidence;
    if (evidence.pseId != input.pseId) {
      return _blocked(input, 'CCTV04_PSE_ID_MISMATCH');
    }
    if (evidence.closureFingerprint != input.expectedClosureFingerprint) {
      return _blocked(input, 'CCTV04_PWR06_CLOSURE_MISMATCH');
    }

    final byId = <String, Cctv04Pwr06Contributor>{
      for (final contributor in evidence.contributors) contributor.loadId: contributor,
    };
    if (!byId.keys.toSet().containsAll(input.cctvLoadIds)) {
      return _blocked(input, 'CCTV04_CCTV_CONTRIBUTOR_EVIDENCE_INCOMPLETE');
    }

    var contribution = Power(Elv5Rational.zero);
    final ids = input.cctvLoadIds.toList()..sort();
    for (final id in ids) {
      contribution = contribution + byId[id]!.power;
    }

    return Cctv04Result(
      status: evidence.globalMargin.value >= Elv5Rational.zero
          ? Cctv04AssessmentStatus.pass
          : Cctv04AssessmentStatus.fail,
      globalDemand: evidence.globalDemand,
      availableCapability: evidence.availableCapability,
      globalMargin: evidence.globalMargin,
      cctvContribution: contribution,
      governingCaseId: evidence.governingCaseId,
      blockingReason: null,
    );
  }

  Cctv04Result _blocked(Cctv04Input input, String reason) {
    final evidence = input.evidence;
    return Cctv04Result(
      status: Cctv04AssessmentStatus.blocked,
      globalDemand: evidence.globalDemand,
      availableCapability: evidence.availableCapability,
      globalMargin: evidence.globalMargin,
      cctvContribution: Power(Elv5Rational.zero),
      governingCaseId: evidence.governingCaseId,
      blockingReason: reason,
    );
  }
}
