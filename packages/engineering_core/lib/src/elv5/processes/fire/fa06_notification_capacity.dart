import '../../numeric/interval.dart';
import '../../numeric/quantity.dart';
import '../../numeric/rational.dart';

enum Fa06OperatingCase { activeNotification, startupInrush }

enum Fa06AssessmentStatus { pass, fail, blocked }

enum Fa06GoverningDimension { deviceCount, outputCurrent, terminalLow, terminalHigh, supervision }

final class Fa06ElectricalCaseEvidence {
  Fa06ElectricalCaseEvidence({
    required this.operatingCase,
    required this.membershipFingerprint,
    required this.outputCurrent,
    required this.terminalVoltage,
    required this.outputCurrentLimit,
    required this.minimumTerminalVoltage,
    required this.maximumTerminalVoltage,
  }) {
    if (membershipFingerprint.isEmpty) {
      throw ArgumentError('FA06 membership fingerprint must not be empty.');
    }
    if (outputCurrent.lower.value < Elv5Rational.zero ||
        outputCurrent.upper.value < Elv5Rational.zero ||
        outputCurrentLimit.value < Elv5Rational.zero) {
      throw ArgumentError('FA06 current values must be nonnegative.');
    }
    if (minimumTerminalVoltage > maximumTerminalVoltage) {
      throw ArgumentError('FA06 terminal-voltage limits are reversed.');
    }
  }

  final Fa06OperatingCase operatingCase;
  final String membershipFingerprint;
  final Elv5Interval<CurrentDim> outputCurrent;
  final Elv5Interval<VoltageDim> terminalVoltage;
  final Current outputCurrentLimit;
  final Voltage minimumTerminalVoltage;
  final Voltage maximumTerminalVoltage;
}

final class Fa06SupervisionEvidence {
  const Fa06SupervisionEvidence({
    required this.required,
    required this.modelSupported,
    required this.passed,
  });

  final bool required;
  final bool modelSupported;
  final bool passed;
}

final class Fa06Input {
  Fa06Input({
    required this.circuitId,
    required this.deviceIds,
    required this.expectedMembershipFingerprint,
    required this.deviceLimit,
    required this.cases,
    required this.supervision,
  }) {
    if (circuitId.isEmpty || expectedMembershipFingerprint.isEmpty) {
      throw ArgumentError('FA06 circuit identity/fingerprint must not be empty.');
    }
    if (deviceLimit < 0) throw ArgumentError('FA06 device limit must be nonnegative.');
    if (deviceIds.isEmpty) throw ArgumentError('FA06 requires at least one notification device.');
    if (deviceIds.length != deviceIds.toSet().length) {
      throw ArgumentError('FA06 duplicate notification device identity.');
    }
    final seen = <Fa06OperatingCase>{};
    for (final item in cases) {
      if (!seen.add(item.operatingCase)) {
        throw ArgumentError('FA06 duplicate electrical case: ${item.operatingCase}');
      }
    }
    if (!seen.contains(Fa06OperatingCase.activeNotification)) {
      throw ArgumentError('FA06 ACTIVE_NOTIFICATION case is mandatory.');
    }
  }

  final String circuitId;
  final List<String> deviceIds;
  final String expectedMembershipFingerprint;
  final int deviceLimit;
  final List<Fa06ElectricalCaseEvidence> cases;
  final Fa06SupervisionEvidence supervision;
}

final class Fa06CaseResult {
  const Fa06CaseResult({
    required this.operatingCase,
    required this.outputCurrent,
    required this.currentMargin,
    required this.terminalVoltage,
    required this.lowVoltageMargin,
    required this.highVoltageMargin,
    required this.status,
    this.governingDimension,
  });

  final Fa06OperatingCase operatingCase;
  final Elv5Interval<CurrentDim> outputCurrent;
  final Current currentMargin;
  final Elv5Interval<VoltageDim> terminalVoltage;
  final Voltage lowVoltageMargin;
  final Voltage highVoltageMargin;
  final Fa06AssessmentStatus status;
  final Fa06GoverningDimension? governingDimension;
}

final class Fa06Result {
  const Fa06Result({
    required this.status,
    required this.activeDeviceCount,
    required this.deviceCountMargin,
    required this.cases,
    required this.acousticCoverageAssessed,
    this.governingCase,
    this.governingDimension,
    this.blockingReason,
  });

  final Fa06AssessmentStatus status;
  final int activeDeviceCount;
  final int deviceCountMargin;
  final Map<Fa06OperatingCase, Fa06CaseResult> cases;
  final bool acousticCoverageAssessed;
  final Fa06OperatingCase? governingCase;
  final Fa06GoverningDimension? governingDimension;
  final String? blockingReason;
}

final class Fa06NotificationCapacityKernel {
  const Fa06NotificationCapacityKernel();

  Fa06Result evaluate(Fa06Input input) {
    final countMargin = input.deviceLimit - input.deviceIds.length;
    if (countMargin < 0) {
      return Fa06Result(
        status: Fa06AssessmentStatus.fail,
        activeDeviceCount: input.deviceIds.length,
        deviceCountMargin: countMargin,
        cases: const {},
        acousticCoverageAssessed: false,
        governingDimension: Fa06GoverningDimension.deviceCount,
      );
    }

    if (input.supervision.required && !input.supervision.modelSupported) {
      return _blocked(input, countMargin, 'FA06_REQUIRED_SUPERVISION_MODEL_UNSUPPORTED');
    }
    if (input.supervision.required && !input.supervision.passed) {
      return Fa06Result(
        status: Fa06AssessmentStatus.fail,
        activeDeviceCount: input.deviceIds.length,
        deviceCountMargin: countMargin,
        cases: const {},
        acousticCoverageAssessed: false,
        governingDimension: Fa06GoverningDimension.supervision,
      );
    }

    final results = <Fa06OperatingCase, Fa06CaseResult>{};
    final ordered = [...input.cases]
      ..sort((a, b) => a.operatingCase.index.compareTo(b.operatingCase.index));
    for (final item in ordered) {
      if (item.membershipFingerprint != input.expectedMembershipFingerprint) {
        return _blocked(input, countMargin, 'FA06_MEMBERSHIP_CLOSURE_MISMATCH');
      }
      final currentMargin = item.outputCurrentLimit - item.outputCurrent.upper;
      final lowMargin = item.terminalVoltage.lower - item.minimumTerminalVoltage;
      final highMargin = item.maximumTerminalVoltage - item.terminalVoltage.upper;
      final failedDimensions = <Fa06GoverningDimension>[
        if (currentMargin.value < Elv5Rational.zero)
          Fa06GoverningDimension.outputCurrent,
        if (lowMargin.value < Elv5Rational.zero)
          Fa06GoverningDimension.terminalLow,
        if (highMargin.value < Elv5Rational.zero)
          Fa06GoverningDimension.terminalHigh,
      ];
      results[item.operatingCase] = Fa06CaseResult(
        operatingCase: item.operatingCase,
        outputCurrent: item.outputCurrent,
        currentMargin: currentMargin,
        terminalVoltage: item.terminalVoltage,
        lowVoltageMargin: lowMargin,
        highVoltageMargin: highMargin,
        status: failedDimensions.isEmpty
            ? Fa06AssessmentStatus.pass
            : Fa06AssessmentStatus.fail,
        // Current and voltage margins are dimensionally different. Only expose
        // a governing dimension when exactly one independent dimension fails.
        governingDimension:
            failedDimensions.length == 1 ? failedDimensions.single : null,
      );
    }

    for (final operatingCase in Fa06OperatingCase.values) {
      final result = results[operatingCase];
      if (result?.status == Fa06AssessmentStatus.fail) {
        return Fa06Result(
          status: Fa06AssessmentStatus.fail,
          activeDeviceCount: input.deviceIds.length,
          deviceCountMargin: countMargin,
          cases: Map.unmodifiable(results),
          acousticCoverageAssessed: false,
          governingCase: operatingCase,
          governingDimension: result!.governingDimension,
        );
      }
    }

    // PASS has no synthetic cross-unit governing dimension. Current and voltage
    // headroom remain independently available in each case result.
    return Fa06Result(
      status: Fa06AssessmentStatus.pass,
      activeDeviceCount: input.deviceIds.length,
      deviceCountMargin: countMargin,
      cases: Map.unmodifiable(results),
      acousticCoverageAssessed: false,
    );
  }

  static Fa06Result _blocked(Fa06Input input, int countMargin, String reason) =>
      Fa06Result(
        status: Fa06AssessmentStatus.blocked,
        activeDeviceCount: input.deviceIds.length,
        deviceCountMargin: countMargin,
        cases: const {},
        acousticCoverageAssessed: false,
        blockingReason: reason,
      );
}
