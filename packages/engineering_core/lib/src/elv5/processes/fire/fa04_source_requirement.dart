import '../../numeric/quantity.dart';
import '../../numeric/rational.dart';

enum Fa04AssessmentStatus { pass, fail, blocked }

enum Fa04GoverningDimension { power, current }

final class Fa04PowerCaseEvidence {
  Fa04PowerCaseEvidence({
    required this.caseId,
    required this.globalDemand,
    required this.requiredCapability,
    required this.availableCapability,
  }) {
    if (caseId.isEmpty) throw ArgumentError('FA04 caseId must not be empty.');
    if (globalDemand.value < Elv5Rational.zero ||
        requiredCapability.value < Elv5Rational.zero ||
        availableCapability.value < Elv5Rational.zero) {
      throw ArgumentError('FA04 power values must be nonnegative.');
    }
  }

  final String caseId;
  final Power globalDemand;
  final Power requiredCapability;
  final Power availableCapability;
}

final class Fa04CurrentCaseEvidence {
  Fa04CurrentCaseEvidence({
    required this.caseId,
    required this.globalDemand,
    required this.requiredCapability,
    required this.availableCapability,
  }) {
    if (caseId.isEmpty) throw ArgumentError('FA04 caseId must not be empty.');
    if (globalDemand.value < Elv5Rational.zero ||
        requiredCapability.value < Elv5Rational.zero ||
        availableCapability.value < Elv5Rational.zero) {
      throw ArgumentError('FA04 current values must be nonnegative.');
    }
  }

  final String caseId;
  final Current globalDemand;
  final Current requiredCapability;
  final Current availableCapability;
}

final class Fa04Input {
  Fa04Input({
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
      throw ArgumentError('FA04 identities/fingerprints must not be empty.');
    }
    if (powerCases.isEmpty && currentCases.isEmpty) {
      throw ArgumentError('FA04 requires at least one source dimension.');
    }
    final keys = <String>{};
    for (final c in powerCases) {
      if (!keys.add('P:${c.caseId}')) {
        throw ArgumentError('FA04 duplicate case dimension.');
      }
    }
    for (final c in currentCases) {
      if (!keys.add('I:${c.caseId}')) {
        throw ArgumentError('FA04 duplicate case dimension.');
      }
    }
  }

  final String sourceId;
  final String expectedGlobalDemandFingerprint;
  final String pwr01GlobalDemandFingerprint;
  final String pwr02GlobalDemandFingerprint;
  final String expectedRequirementSetFingerprint;
  final String pwr02RequirementSetFingerprint;
  final List<String> requirementContributors;
  final List<Fa04PowerCaseEvidence> powerCases;
  final List<Fa04CurrentCaseEvidence> currentCases;
  final bool requirementConflict;
}

final class Fa04PowerCaseResult {
  const Fa04PowerCaseResult({
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
  final Fa04AssessmentStatus status;
}

final class Fa04CurrentCaseResult {
  const Fa04CurrentCaseResult({
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
  final Fa04AssessmentStatus status;
}

final class Fa04Result {
  const Fa04Result({
    required this.status,
    required this.powerCases,
    required this.currentCases,
    required this.requirementContributors,
    this.governingCaseId,
    this.governingDimension,
    this.blockingReason,
  });
  final Fa04AssessmentStatus status;
  final List<Fa04PowerCaseResult> powerCases;
  final List<Fa04CurrentCaseResult> currentCases;
  final List<String> requirementContributors;
  final String? governingCaseId;
  final Fa04GoverningDimension? governingDimension;
  final String? blockingReason;
}

final class Fa04SourceRequirementKernel {
  const Fa04SourceRequirementKernel();

  Fa04Result evaluate(Fa04Input input) {
    if (input.requirementConflict) {
      return _blocked(input, 'FA04_REQUIREMENT_SEMANTICS_CONFLICT');
    }
    if (input.pwr01GlobalDemandFingerprint !=
            input.expectedGlobalDemandFingerprint ||
        input.pwr02GlobalDemandFingerprint !=
            input.expectedGlobalDemandFingerprint) {
      return _blocked(input, 'FA04_GLOBAL_DEMAND_CLOSURE_MISMATCH');
    }
    if (input.pwr02RequirementSetFingerprint !=
        input.expectedRequirementSetFingerprint) {
      return _blocked(input, 'FA04_REQUIREMENT_SET_FINGERPRINT_MISMATCH');
    }

    final power = [...input.powerCases]
      ..sort((a, b) => a.caseId.compareTo(b.caseId));
    final current = [...input.currentCases]
      ..sort((a, b) => a.caseId.compareTo(b.caseId));
    final powerResults = <Fa04PowerCaseResult>[];
    final currentResults = <Fa04CurrentCaseResult>[];

    for (final item in power) {
      final margin = item.availableCapability - item.requiredCapability;
      powerResults.add(Fa04PowerCaseResult(
        caseId: item.caseId,
        globalDemand: item.globalDemand,
        requiredCapability: item.requiredCapability,
        availableCapability: item.availableCapability,
        margin: margin,
        status: margin.value >= Elv5Rational.zero
            ? Fa04AssessmentStatus.pass
            : Fa04AssessmentStatus.fail,
      ));
    }
    for (final item in current) {
      final margin = item.availableCapability - item.requiredCapability;
      currentResults.add(Fa04CurrentCaseResult(
        caseId: item.caseId,
        globalDemand: item.globalDemand,
        requiredCapability: item.requiredCapability,
        availableCapability: item.availableCapability,
        margin: margin,
        status: margin.value >= Elv5Rational.zero
            ? Fa04AssessmentStatus.pass
            : Fa04AssessmentStatus.fail,
      ));
    }

    for (final result in powerResults) {
      if (result.status == Fa04AssessmentStatus.fail) {
        return _result(
          input,
          powerResults,
          currentResults,
          Fa04AssessmentStatus.fail,
          result.caseId,
          Fa04GoverningDimension.power,
        );
      }
    }
    for (final result in currentResults) {
      if (result.status == Fa04AssessmentStatus.fail) {
        return _result(
          input,
          powerResults,
          currentResults,
          Fa04AssessmentStatus.fail,
          result.caseId,
          Fa04GoverningDimension.current,
        );
      }
    }

    // PASS headroom in W and A is not physically comparable. Preserve both
    // dimension results without fabricating one cross-unit governing margin.
    final hasPower = powerResults.isNotEmpty;
    final hasCurrent = currentResults.isNotEmpty;
    if (hasPower && hasCurrent) {
      return _result(
        input,
        powerResults,
        currentResults,
        Fa04AssessmentStatus.pass,
        null,
        null,
      );
    }
    if (hasPower) {
      final governing = _smallestPowerMargin(powerResults);
      return _result(
        input,
        powerResults,
        currentResults,
        Fa04AssessmentStatus.pass,
        governing?.caseId,
        Fa04GoverningDimension.power,
      );
    }
    final governing = _smallestCurrentMargin(currentResults);
    return _result(
      input,
      powerResults,
      currentResults,
      Fa04AssessmentStatus.pass,
      governing?.caseId,
      Fa04GoverningDimension.current,
    );
  }

  static Fa04Result _blocked(Fa04Input input, String reason) => Fa04Result(
        status: Fa04AssessmentStatus.blocked,
        powerCases: const [],
        currentCases: const [],
        requirementContributors:
            List.unmodifiable(input.requirementContributors),
        blockingReason: reason,
      );

  static Fa04Result _result(
    Fa04Input input,
    List<Fa04PowerCaseResult> power,
    List<Fa04CurrentCaseResult> current,
    Fa04AssessmentStatus status,
    String? caseId,
    Fa04GoverningDimension? dimension,
  ) =>
      Fa04Result(
        status: status,
        powerCases: List.unmodifiable(power),
        currentCases: List.unmodifiable(current),
        requirementContributors:
            List.unmodifiable(input.requirementContributors),
        governingCaseId: caseId,
        governingDimension: dimension,
      );

  static Fa04PowerCaseResult? _smallestPowerMargin(
    List<Fa04PowerCaseResult> values,
  ) {
    Fa04PowerCaseResult? best;
    for (final value in values) {
      if (best == null || value.margin < best.margin) best = value;
    }
    return best;
  }

  static Fa04CurrentCaseResult? _smallestCurrentMargin(
    List<Fa04CurrentCaseResult> values,
  ) {
    Fa04CurrentCaseResult? best;
    for (final value in values) {
      if (best == null || value.margin < best.margin) best = value;
    }
    return best;
  }
}
