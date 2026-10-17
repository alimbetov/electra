import '../../numeric/interval.dart';
import '../../numeric/quantity.dart';
import '../../numeric/rational.dart';

enum Fa03AssessmentStatus { pass, fail, blocked }

enum Fa03ElectricalModel { radialDc, declaredOneControlPointDc, unsupported }

final class Fa03TerminalEvidence {
  Fa03TerminalEvidence({
    required this.terminalId,
    required this.caseId,
    required this.scopeFingerprint,
    required this.voltage,
  }) {
    if (terminalId.isEmpty || caseId.isEmpty || scopeFingerprint.isEmpty) {
      throw ArgumentError('FA03 terminal evidence identity must not be empty.');
    }
  }

  final String terminalId;
  final String caseId;
  final String scopeFingerprint;
  final Elv5Interval<VoltageDim> voltage;
}

final class Fa03VoltagePolicy {
  Fa03VoltagePolicy({required this.minimum, required this.maximum}) {
    if (minimum > maximum) {
      throw ArgumentError('FA03 voltage policy range is reversed.');
    }
  }

  final Voltage minimum;
  final Voltage maximum;
}

final class Fa03Input {
  Fa03Input({
    required this.circuitId,
    required this.model,
    required this.expectedScopeFingerprint,
    required this.terminals,
    required this.policy,
  }) {
    if (circuitId.isEmpty || expectedScopeFingerprint.isEmpty) {
      throw ArgumentError('FA03 circuit/scope identity must not be empty.');
    }
    if (terminals.isEmpty)
      throw ArgumentError('FA03 requires terminal evidence.');
    final seen = <String>{};
    for (final terminal in terminals) {
      final key = '${terminal.caseId}|${terminal.terminalId}';
      if (!seen.add(key)) {
        throw ArgumentError('FA03 duplicate terminal/case evidence: $key');
      }
    }
  }

  final String circuitId;
  final Fa03ElectricalModel model;
  final String expectedScopeFingerprint;
  final List<Fa03TerminalEvidence> terminals;
  final Fa03VoltagePolicy policy;
}

final class Fa03TerminalResult {
  const Fa03TerminalResult({
    required this.terminalId,
    required this.caseId,
    required this.voltage,
    required this.lowMargin,
    required this.highMargin,
    required this.status,
  });

  final String terminalId;
  final String caseId;
  final Elv5Interval<VoltageDim> voltage;
  final Voltage lowMargin;
  final Voltage highMargin;
  final Fa03AssessmentStatus status;

  Voltage get governingMargin =>
      lowMargin <= highMargin ? lowMargin : highMargin;
}

final class Fa03Result {
  const Fa03Result({
    required this.status,
    required this.terminals,
    required this.governingTerminalId,
    required this.governingCaseId,
    required this.blockingReason,
  });

  final Fa03AssessmentStatus status;
  final List<Fa03TerminalResult> terminals;
  final String? governingTerminalId;
  final String? governingCaseId;
  final String? blockingReason;
}

final class Fa03TerminalVoltageKernel {
  const Fa03TerminalVoltageKernel();

  Fa03Result evaluate(Fa03Input input) {
    if (input.model == Fa03ElectricalModel.unsupported) {
      return const Fa03Result(
        status: Fa03AssessmentStatus.blocked,
        terminals: [],
        governingTerminalId: null,
        governingCaseId: null,
        blockingReason: 'FA03_UNSUPPORTED_ELECTRICAL_MODEL',
      );
    }
    for (final terminal in input.terminals) {
      if (terminal.scopeFingerprint != input.expectedScopeFingerprint) {
        return const Fa03Result(
          status: Fa03AssessmentStatus.blocked,
          terminals: [],
          governingTerminalId: null,
          governingCaseId: null,
          blockingReason: 'FA03_PWR03_SCOPE_MISMATCH',
        );
      }
    }

    final evidence = [...input.terminals]..sort((a, b) {
        final byTerminal = a.terminalId.compareTo(b.terminalId);
        return byTerminal != 0 ? byTerminal : a.caseId.compareTo(b.caseId);
      });
    final results = <Fa03TerminalResult>[];
    for (final terminal in evidence) {
      final low = terminal.voltage.lower - input.policy.minimum;
      final high = input.policy.maximum - terminal.voltage.upper;
      results.add(Fa03TerminalResult(
        terminalId: terminal.terminalId,
        caseId: terminal.caseId,
        voltage: terminal.voltage,
        lowMargin: low,
        highMargin: high,
        status:
            low.value >= Elv5Rational.zero && high.value >= Elv5Rational.zero
                ? Fa03AssessmentStatus.pass
                : Fa03AssessmentStatus.fail,
      ));
    }

    Fa03TerminalResult governing = results.first;
    for (final result in results.skip(1)) {
      if (result.governingMargin < governing.governingMargin)
        governing = result;
    }
    final overall = results.any((e) => e.status == Fa03AssessmentStatus.fail)
        ? Fa03AssessmentStatus.fail
        : Fa03AssessmentStatus.pass;
    return Fa03Result(
      status: overall,
      terminals: List.unmodifiable(results),
      governingTerminalId: governing.terminalId,
      governingCaseId: governing.caseId,
      blockingReason: null,
    );
  }
}
