import '../../numeric/quantity.dart';
import '../../numeric/rational.dart';

enum Lan03AssessmentStatus { pass, fail, blocked }

final class Lan03Pwr06Contributor {
  Lan03Pwr06Contributor({required this.loadId, required this.power}) {
    if (loadId.isEmpty) throw ArgumentError('LAN03 loadId must not be empty.');
    if (power.value < Elv5Rational.zero) {
      throw ArgumentError('LAN03 contributor power must be nonnegative.');
    }
  }

  final String loadId;
  final Power power;
}

final class Lan03Pwr06Evidence {
  Lan03Pwr06Evidence({
    required this.pseId,
    required this.closureFingerprint,
    required this.globalDemand,
    required this.availableCapability,
    required this.globalMargin,
    required this.governingCaseId,
    required this.contributors,
  }) {
    if (pseId.isEmpty ||
        closureFingerprint.isEmpty ||
        governingCaseId.isEmpty) {
      throw ArgumentError('LAN03 evidence identity must not be empty.');
    }
    final seen = <String>{};
    for (final contributor in contributors) {
      if (!seen.add(contributor.loadId)) {
        throw ArgumentError(
            'LAN03 duplicate contributor loadId: ${contributor.loadId}');
      }
    }
  }

  final String pseId;
  final String closureFingerprint;
  final Power globalDemand;
  final Power availableCapability;
  final Power globalMargin;
  final String governingCaseId;
  final List<Lan03Pwr06Contributor> contributors;
}

final class Lan03Input {
  Lan03Input({
    required this.pseId,
    required this.expectedClosureFingerprint,
    required this.lanLoadIds,
    required this.evidence,
  }) {
    if (pseId.isEmpty || expectedClosureFingerprint.isEmpty) {
      throw ArgumentError('LAN03 input identity must not be empty.');
    }
  }

  final String pseId;
  final String expectedClosureFingerprint;
  final Set<String> lanLoadIds;
  final Lan03Pwr06Evidence evidence;
}

final class Lan03Result {
  const Lan03Result({
    required this.status,
    required this.globalDemand,
    required this.availableCapability,
    required this.globalMargin,
    required this.lanContribution,
    required this.governingCaseId,
    required this.blockingReason,
  });

  final Lan03AssessmentStatus status;
  final Power globalDemand;
  final Power availableCapability;
  final Power globalMargin;
  final Power lanContribution;
  final String governingCaseId;
  final String? blockingReason;
}

final class Lan03PoeProjectionKernel {
  const Lan03PoeProjectionKernel();

  Lan03Result evaluate(Lan03Input input) {
    final evidence = input.evidence;
    if (evidence.pseId != input.pseId) {
      return _blocked(input, 'LAN03_PSE_ID_MISMATCH');
    }
    if (evidence.closureFingerprint != input.expectedClosureFingerprint) {
      return _blocked(input, 'LAN03_PWR06_CLOSURE_MISMATCH');
    }

    final byId = <String, Lan03Pwr06Contributor>{
      for (final contributor in evidence.contributors)
        contributor.loadId: contributor,
    };
    if (!byId.keys.toSet().containsAll(input.lanLoadIds)) {
      return _blocked(input, 'LAN03_LAN_CONTRIBUTOR_EVIDENCE_INCOMPLETE');
    }

    var contribution = Power(Elv5Rational.zero);
    final ids = input.lanLoadIds.toList()..sort();
    for (final id in ids) {
      contribution = contribution + byId[id]!.power;
    }

    return Lan03Result(
      status: evidence.globalMargin.value >= Elv5Rational.zero
          ? Lan03AssessmentStatus.pass
          : Lan03AssessmentStatus.fail,
      globalDemand: evidence.globalDemand,
      availableCapability: evidence.availableCapability,
      globalMargin: evidence.globalMargin,
      lanContribution: contribution,
      governingCaseId: evidence.governingCaseId,
      blockingReason: null,
    );
  }

  Lan03Result _blocked(Lan03Input input, String reason) {
    final evidence = input.evidence;
    return Lan03Result(
      status: Lan03AssessmentStatus.blocked,
      globalDemand: evidence.globalDemand,
      availableCapability: evidence.availableCapability,
      globalMargin: evidence.globalMargin,
      lanContribution: Power(Elv5Rational.zero),
      governingCaseId: evidence.governingCaseId,
      blockingReason: reason,
    );
  }
}
