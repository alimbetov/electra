import '../../numeric/quantity.dart';
import '../../numeric/rational.dart';

enum Acs04AssessmentStatus { pass, fail, blocked }

enum Acs04GoverningDimension { power, current }

final class Acs04PowerCaseEvidence {
  Acs04PowerCaseEvidence({
    required this.caseId,
    required this.globalDemand,
    required this.requiredCapability,
    required this.availableCapability,
  }) {
    if (caseId.isEmpty) throw ArgumentError('ACS04 caseId must not be empty.');
    if (globalDemand.value < Elv5Rational.zero ||
        requiredCapability.value < Elv5Rational.zero ||
        availableCapability.value < Elv5Rational.zero) {
      throw ArgumentError('ACS04 power values must be nonnegative.');
    }
  }

  final String caseId;
  final Power globalDemand;
  final Power requiredCapability;
  final Power availableCapability;
}

final class Acs04CurrentCaseEvidence {
  Acs04CurrentCaseEvidence({
    required this.caseId,
    required this.globalDemand,
    required this.requiredCapability,
    required this.availableCapability,
  }) {
    if (caseId.isEmpty) throw ArgumentError('ACS04 caseId must not be empty.');
    if (globalDemand.value < Elv5Rational.zero ||
        requiredCapability.value < Elv5Rational.zero ||
        availableCapability.value < Elv5Rational.zero) {
      throw ArgumentError('ACS04 current values must be nonnegative.');
    }
  }

  final String caseId;
  final Current globalDemand;
  final Current requiredCapability;
  final Current availableCapability;
}

final class Acs04Input {
  Acs04Input({
    required this.sourceId,
    required this.expectedGlobalDemandFingerprint,
    required this.pwr01GlobalDemandFingerprint,
    required this.pwr02GlobalDemandFingerprint,
    required this.expectedRequirementSetFingerprint,
    required this.pwr02RequirementSetFingerprint,
    required this.requirementContributors,
    required this.powerCases,
    required this.currentCases,
    this.requirementConflict = false,
  }) {
    if (sourceId.isEmpty ||
        expectedGlobalDemandFingerprint.isEmpty ||
        pwr01GlobalDemandFingerprint.isEmpty ||
        pwr02GlobalDemandFingerprint.isEmpty ||
        expectedRequirementSetFingerprint.isEmpty ||
        pwr02RequirementSetFingerprint.isEmpty) {
      throw ArgumentError('ACS04 fingerprints and source identity must not be empty.');
    }
    if (powerCases.isEmpty && currentCases.isEmpty) {
      throw ArgumentError('ACS04 requires at least one source capability dimension.');
    }
    _requireUnique(powerCases.map((e) => 'P:${e.caseId}'));
    _requireUnique(currentCases.map((e) => 'I:${e.caseId}'));
  }

  final String sourceId;
  final String expectedGlobalDemandFingerprint;
  final String pwr01GlobalDemandFingerprint;
  final String pwr02GlobalDemandFingerprint;
  final String expectedRequirementSetFingerprint;
  final String pwr02RequirementSetFingerprint;
  final List<String> requirementContributors;
  final List<Acs04PowerCaseEvidence> powerCases;
  final List<Acs04CurrentCaseEvidence> currentCases;
  final bool requirementConflict;

  static void _requireUnique(Iterable<String> values) {
    final seen = <String>{};
    for (final value in values) {
      if (!seen.add(value)) {
        throw ArgumentError('ACS04 duplicate case dimension: $value');
      }
    }
  }
}

final class Acs04PowerCaseResult {
  const Acs04PowerCaseResult({
    required this.caseId,
    required this.globalDemand,
    required this.requiredCapability,
    required this.availableCapability,
    required this.margin,
    required this.status,
  });

  final String caseId;
  final Power globalDemand;
  final Power requiredCapability;
  final Power availableCapability;
  final Power margin;
  final Acs04AssessmentStatus status;
}

final class Acs04CurrentCaseResult {
  const Acs04CurrentCaseResult({
    required this.caseId,
    required this.globalDemand,
    required this.requiredCapability,
    required this.availableCapability,
    required this.margin,
    required this.status,
  });

  final String caseId;
  final Current globalDemand;
  final Current requiredCapability;
  final Current availableCapability;
  final Current margin;
  final Acs04AssessmentStatus status;
}

final class Acs04Result {
  const Acs04Result({
    required this.status,
    required this.powerCases,
    required this.currentCases,
    required this.requirementContributors,
    this.governingCaseId,
    this.governingDimension,
    this.blockingReason,
  });

  final Acs04AssessmentStatus status;
  final List<Acs04PowerCaseResult> powerCases;
  final List<Acs04CurrentCaseResult> currentCases;
  final List<String> requirementContributors;
  final String? governingCaseId;
  final Acs04GoverningDimension? governingDimension;
  final String? blockingReason;
}

final class Acs04SourceRequirementKernel {
  const Acs04SourceRequirementKernel();

  Acs04Result evaluate(Acs04Input input) {
    if (input.requirementConflict) {
      return _blocked(input, 'ACS04_REQUIREMENT_SEMANTICS_CONFLICT');
    }
    if (input.pwr01GlobalDemandFingerprint != input.expectedGlobalDemandFingerprint ||
        input.pwr02GlobalDemandFingerprint != input.expectedGlobalDemandFingerprint) {
      return _blocked(input, 'ACS04_GLOBAL_DEMAND_CLOSURE_MISMATCH');
    }
    if (input.pwr02RequirementSetFingerprint != input.expectedRequirementSetFingerprint) {
      return _blocked(input, 'ACS04_REQUIREMENT_SET_FINGERPRINT_MISMATCH');
    }

    final power = [...input.powerCases]
      ..sort((a, b) => a.caseId.compareTo(b.caseId));
    final current = [...input.currentCases]
      ..sort((a, b) => a.caseId.compareTo(b.caseId));
    final powerResults = <Acs04PowerCaseResult>[];
    final currentResults = <Acs04CurrentCaseResult>[];

    for (final item in power) {
      final margin = item.availableCapability - item.requiredCapability;
      powerResults.add(
        Acs04PowerCaseResult(
          caseId: item.caseId,
          globalDemand: item.globalDemand,
          requiredCapability: item.requiredCapability,
          availableCapability: item.availableCapability,
          margin: margin,
          status: margin.value >= Elv5Rational.zero
              ? Acs04AssessmentStatus.pass
              : Acs04AssessmentStatus.fail,
        ),
      );
    }
    for (final item in current) {
      final margin = item.availableCapability - item.requiredCapability;
      currentResults.add(
        Acs04CurrentCaseResult(
          caseId: item.caseId,
          globalDemand: item.globalDemand,
          requiredCapability: item.requiredCapability,
          availableCapability: item.availableCapability,
          margin: margin,
          status: margin.value >= Elv5Rational.zero
              ? Acs04AssessmentStatus.pass
              : Acs04AssessmentStatus.fail,
        ),
      );
    }

    final failures = <_FailureRef>[
      for (final result in powerResults)
        if (result.status == Acs04AssessmentStatus.fail)
          _FailureRef(result.caseId, Acs04GoverningDimension.power),
      for (final result in currentResults)
        if (result.status == Acs04AssessmentStatus.fail)
          _FailureRef(result.caseId, Acs04GoverningDimension.current),
    ]
      ..sort((a, b) {
        final byCase = a.caseId.compareTo(b.caseId);
        if (byCase != 0) return byCase;
        return a.dimension.index.compareTo(b.dimension.index);
      });
    if (failures.isNotEmpty) {
      final governing = failures.first;
      return Acs04Result(
        status: Acs04AssessmentStatus.fail,
        powerCases: List.unmodifiable(powerResults),
        currentCases: List.unmodifiable(currentResults),
        requirementContributors: List.unmodifiable(input.requirementContributors),
        governingCaseId: governing.caseId,
        governingDimension: governing.dimension,
      );
    }

    final governingPower = _smallestPowerMargin(powerResults);
    final governingCurrent = _smallestCurrentMargin(currentResults);
    final singleDimension = powerResults.isEmpty || currentResults.isEmpty;
    return Acs04Result(
      status: Acs04AssessmentStatus.pass,
      powerCases: List.unmodifiable(powerResults),
      currentCases: List.unmodifiable(currentResults),
      requirementContributors: List.unmodifiable(input.requirementContributors),
      governingCaseId: singleDimension
          ? (governingPower?.caseId ?? governingCurrent?.caseId)
          : null,
      governingDimension: singleDimension
          ? (governingPower != null
              ? Acs04GoverningDimension.power
              : (governingCurrent != null
                  ? Acs04GoverningDimension.current
                  : null))
          : null,
    );
  }

  static Acs04Result _blocked(Acs04Input input, String reason) => Acs04Result(
        status: Acs04AssessmentStatus.blocked,
        powerCases: const [],
        currentCases: const [],
        requirementContributors: List.unmodifiable(input.requirementContributors),
        blockingReason: reason,
      );

  static Acs04PowerCaseResult? _smallestPowerMargin(
    List<Acs04PowerCaseResult> values,
  ) {
    Acs04PowerCaseResult? best;
    for (final value in values) {
      if (best == null || value.margin < best.margin) best = value;
    }
    return best;
  }

  static Acs04CurrentCaseResult? _smallestCurrentMargin(
    List<Acs04CurrentCaseResult> values,
  ) {
    Acs04CurrentCaseResult? best;
    for (final value in values) {
      if (best == null || value.margin < best.margin) best = value;
    }
    return best;
  }
}

final class _FailureRef {
  const _FailureRef(this.caseId, this.dimension);

  final String caseId;
  final Acs04GoverningDimension dimension;
}
