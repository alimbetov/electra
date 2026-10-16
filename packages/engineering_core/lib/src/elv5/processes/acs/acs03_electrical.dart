import '../../numeric/interval.dart';
import '../../numeric/quantity.dart';
import '../../numeric/rational.dart';

enum Acs03AssessmentStatus { pass, fail, unresolved, blocked }

enum Acs03StateCode { holding, activeRelease, startupInrush, fireRelease, powerFailure }

final class Acs03OperatingEvent {
  Acs03OperatingEvent({
    required this.eventId,
    required this.state,
    required this.durationMicroseconds,
    this.lockCurrent,
  }) {
    if (eventId.isEmpty) throw ArgumentError('ACS03 eventId must not be empty.');
    if (durationMicroseconds <= BigInt.zero) {
      throw ArgumentError('ACS03 event duration must be positive.');
    }
    if (lockCurrent != null && lockCurrent!.value < Elv5Rational.zero) {
      throw ArgumentError('ACS03 lock current must be nonnegative.');
    }
  }

  final String eventId;
  final Acs03StateCode state;
  final BigInt durationMicroseconds;
  final Current? lockCurrent;
}

final class Acs03PwrEvidence {
  Acs03PwrEvidence({
    required this.eventId,
    required this.membershipFingerprint,
    required this.terminalVoltage,
    required this.sharedTrunkCurrent,
    this.sourceCurrentMargin,
  }) {
    if (eventId.isEmpty || membershipFingerprint.isEmpty) {
      throw ArgumentError('ACS03 evidence identity must not be empty.');
    }
    if (sharedTrunkCurrent.lower.value < Elv5Rational.zero) {
      throw ArgumentError('ACS03 shared trunk current must be nonnegative.');
    }
  }

  final String eventId;
  final String membershipFingerprint;
  final Elv5Interval<VoltageDim> terminalVoltage;
  final Elv5Interval<CurrentDim> sharedTrunkCurrent;
  final Elv5Interval<CurrentDim>? sourceCurrentMargin;
}

final class Acs03Input {
  Acs03Input({
    required this.doorId,
    required this.lockId,
    required this.conductiveFeedPathId,
    required this.controlPathId,
    required this.requiredMembershipFingerprint,
    required this.events,
    required this.evidence,
    this.minimumTerminalVoltage,
    this.maximumTerminalVoltage,
  }) {
    if (doorId.isEmpty || lockId.isEmpty || requiredMembershipFingerprint.isEmpty) {
      throw ArgumentError('ACS03 required identity must not be empty.');
    }
    if (events.isEmpty) throw ArgumentError('ACS03 requires at least one event.');
    final ids = <String>{};
    for (final event in events) {
      if (!ids.add(event.eventId)) {
        throw ArgumentError('ACS03 duplicate eventId: ${event.eventId}');
      }
    }
    final evidenceIds = <String>{};
    for (final item in evidence) {
      if (!evidenceIds.add(item.eventId)) {
        throw ArgumentError('ACS03 duplicate evidence eventId: ${item.eventId}');
      }
    }
    if (minimumTerminalVoltage != null && maximumTerminalVoltage != null &&
        minimumTerminalVoltage! > maximumTerminalVoltage!) {
      throw ArgumentError('ACS03 voltage requirements are reversed.');
    }
  }

  final String doorId;
  final String lockId;
  final String? conductiveFeedPathId;
  final String? controlPathId;
  final String requiredMembershipFingerprint;
  final List<Acs03OperatingEvent> events;
  final List<Acs03PwrEvidence> evidence;
  final Voltage? minimumTerminalVoltage;
  final Voltage? maximumTerminalVoltage;
}

final class Acs03CaseResult {
  const Acs03CaseResult({
    required this.eventId,
    required this.state,
    required this.durationMicroseconds,
    required this.status,
    required this.terminalVoltage,
    required this.sharedTrunkCurrent,
    required this.minimumVoltageMargin,
    required this.maximumVoltageMargin,
    required this.sourceCurrentMargin,
    this.reason,
  });

  final String eventId;
  final Acs03StateCode state;
  final BigInt durationMicroseconds;
  final Acs03AssessmentStatus status;
  final Elv5Interval<VoltageDim>? terminalVoltage;
  final Elv5Interval<CurrentDim>? sharedTrunkCurrent;
  final Voltage? minimumVoltageMargin;
  final Voltage? maximumVoltageMargin;
  final Elv5Interval<CurrentDim>? sourceCurrentMargin;
  final String? reason;
}

final class Acs03Result {
  const Acs03Result({
    required this.status,
    required this.cases,
    required this.governingCaseId,
    this.limitingReason,
  });

  final Acs03AssessmentStatus status;
  final List<Acs03CaseResult> cases;
  final String? governingCaseId;
  final String? limitingReason;
}

final class Acs03ElectricalKernel {
  const Acs03ElectricalKernel();

  Acs03Result evaluate(Acs03Input input) {
    if (input.conductiveFeedPathId == null || input.conductiveFeedPathId!.isEmpty) {
      return const Acs03Result(
        status: Acs03AssessmentStatus.blocked,
        cases: <Acs03CaseResult>[],
        governingCaseId: null,
        limitingReason: 'ACS03_REQUIRED_CONDUCTIVE_FEED_MISSING',
      );
    }

    final evidenceByEvent = <String, Acs03PwrEvidence>{
      for (final item in input.evidence) item.eventId: item,
    };
    final orderedEvents = [...input.events]..sort((a, b) => a.eventId.compareTo(b.eventId));
    final results = <Acs03CaseResult>[];

    for (final event in orderedEvents) {
      final evidence = evidenceByEvent[event.eventId];
      if (evidence == null) {
        results.add(Acs03CaseResult(
          eventId: event.eventId,
          state: event.state,
          durationMicroseconds: event.durationMicroseconds,
          status: Acs03AssessmentStatus.unresolved,
          terminalVoltage: null,
          sharedTrunkCurrent: null,
          minimumVoltageMargin: null,
          maximumVoltageMargin: null,
          sourceCurrentMargin: null,
          reason: 'ACS03_PWR_EVIDENCE_MISSING',
        ));
        continue;
      }
      if (evidence.membershipFingerprint != input.requiredMembershipFingerprint) {
        results.add(Acs03CaseResult(
          eventId: event.eventId,
          state: event.state,
          durationMicroseconds: event.durationMicroseconds,
          status: Acs03AssessmentStatus.blocked,
          terminalVoltage: evidence.terminalVoltage,
          sharedTrunkCurrent: evidence.sharedTrunkCurrent,
          minimumVoltageMargin: null,
          maximumVoltageMargin: null,
          sourceCurrentMargin: evidence.sourceCurrentMargin,
          reason: 'ACS03_SHARED_MEMBERSHIP_CLOSURE_MISMATCH',
        ));
        continue;
      }

      final minMargin = input.minimumTerminalVoltage == null
          ? null
          : evidence.terminalVoltage.lower - input.minimumTerminalVoltage!;
      final maxMargin = input.maximumTerminalVoltage == null
          ? null
          : input.maximumTerminalVoltage! - evidence.terminalVoltage.upper;
      var status = Acs03AssessmentStatus.pass;
      String? reason;
      if (minMargin != null && minMargin.value < Elv5Rational.zero) {
        status = Acs03AssessmentStatus.fail;
        reason = 'ACS03_MINIMUM_TERMINAL_VOLTAGE';
      } else if (maxMargin != null && maxMargin.value < Elv5Rational.zero) {
        status = Acs03AssessmentStatus.fail;
        reason = 'ACS03_MAXIMUM_TERMINAL_VOLTAGE';
      } else if (evidence.sourceCurrentMargin != null &&
          evidence.sourceCurrentMargin!.lower.value < Elv5Rational.zero) {
        status = Acs03AssessmentStatus.fail;
        reason = 'ACS03_SOURCE_CURRENT_MARGIN';
      }

      results.add(Acs03CaseResult(
        eventId: event.eventId,
        state: event.state,
        durationMicroseconds: event.durationMicroseconds,
        status: status,
        terminalVoltage: evidence.terminalVoltage,
        sharedTrunkCurrent: evidence.sharedTrunkCurrent,
        minimumVoltageMargin: minMargin,
        maximumVoltageMargin: maxMargin,
        sourceCurrentMargin: evidence.sourceCurrentMargin,
        reason: reason,
      ));
    }

    final governing = _selectGoverning(results);
    return Acs03Result(
      status: governing?.status ?? Acs03AssessmentStatus.unresolved,
      cases: List.unmodifiable(results),
      governingCaseId: governing?.eventId,
      limitingReason: governing?.reason,
    );
  }

  static Acs03CaseResult? _selectGoverning(List<Acs03CaseResult> results) {
    for (final status in const [
      Acs03AssessmentStatus.blocked,
      Acs03AssessmentStatus.fail,
      Acs03AssessmentStatus.unresolved,
    ]) {
      for (final result in results) {
        if (result.status == status) return result;
      }
    }
    Acs03CaseResult? best;
    for (final result in results) {
      if (best == null) {
        best = result;
        continue;
      }
      final a = result.minimumVoltageMargin?.value;
      final b = best.minimumVoltageMargin?.value;
      if (a != null && (b == null || a < b)) best = result;
    }
    return best;
  }
}
