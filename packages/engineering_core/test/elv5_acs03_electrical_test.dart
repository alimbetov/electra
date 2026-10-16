import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:test/test.dart';

Voltage _v(String value) => Voltage(Elv5Rational.parseDecimal(value));
Current _a(String value) => Current(Elv5Rational.parseDecimal(value));

void main() {
  group('ACS-03 electrical projection', () {
    test('retains shared trunk evidence and computes terminal margin', () {
      final input = Acs03Input(
        doorId: 'door-1',
        lockId: 'lock-1',
        conductiveFeedPathId: 'feed-1',
        controlPathId: 'relay-1',
        requiredMembershipFingerprint: 'closure-v1',
        minimumTerminalVoltage: _v('22'),
        events: [
          Acs03OperatingEvent(
            eventId: 'holding',
            state: Acs03StateCode.holding,
            durationMicroseconds: BigInt.from(1000000),
            lockCurrent: _a('0.3'),
          ),
        ],
        evidence: [
          Acs03PwrEvidence(
            eventId: 'holding',
            membershipFingerprint: 'closure-v1',
            terminalVoltage: Elv5Interval.exact(_v('23.51')),
            sharedTrunkCurrent: Elv5Interval.exact(_a('0.8')),
          ),
        ],
      );

      final result = const Acs03ElectricalKernel().evaluate(input);
      expect(result.status, Acs03AssessmentStatus.pass);
      expect(result.cases.single.minimumVoltageMargin, _v('1.51'));
      expect(result.cases.single.sharedTrunkCurrent!.lower, _a('0.8'));
    });

    test('zero startup voltage margin passes and governs over holding', () {
      final input = Acs03Input(
        doorId: 'door-1',
        lockId: 'lock-1',
        conductiveFeedPathId: 'feed-1',
        controlPathId: 'relay-1',
        requiredMembershipFingerprint: 'closure-v1',
        minimumTerminalVoltage: _v('22'),
        events: [
          Acs03OperatingEvent(
            eventId: 'holding',
            state: Acs03StateCode.holding,
            durationMicroseconds: BigInt.from(1000000),
          ),
          Acs03OperatingEvent(
            eventId: 'startup',
            state: Acs03StateCode.startupInrush,
            durationMicroseconds: BigInt.from(100000),
          ),
        ],
        evidence: [
          Acs03PwrEvidence(
            eventId: 'holding',
            membershipFingerprint: 'closure-v1',
            terminalVoltage: Elv5Interval.exact(_v('23.5')),
            sharedTrunkCurrent: Elv5Interval.exact(_a('0.5')),
          ),
          Acs03PwrEvidence(
            eventId: 'startup',
            membershipFingerprint: 'closure-v1',
            terminalVoltage: Elv5Interval.exact(_v('22')),
            sharedTrunkCurrent: Elv5Interval.exact(_a('1.2')),
          ),
        ],
      );

      final result = const Acs03ElectricalKernel().evaluate(input);
      expect(result.status, Acs03AssessmentStatus.pass);
      expect(result.governingCaseId, 'startup');
      expect(
        result.cases.firstWhere((e) => e.eventId == 'startup').minimumVoltageMargin,
        _v('0'),
      );
    });

    test('short startup event fails when upstream terminal evidence is low', () {
      final input = Acs03Input(
        doorId: 'door-1',
        lockId: 'lock-1',
        conductiveFeedPathId: 'feed-1',
        controlPathId: 'relay-1',
        requiredMembershipFingerprint: 'closure-v1',
        minimumTerminalVoltage: _v('22'),
        events: [
          Acs03OperatingEvent(
            eventId: 'startup',
            state: Acs03StateCode.startupInrush,
            durationMicroseconds: BigInt.from(50000),
          ),
        ],
        evidence: [
          Acs03PwrEvidence(
            eventId: 'startup',
            membershipFingerprint: 'closure-v1',
            terminalVoltage: Elv5Interval.exact(_v('20.8')),
            sharedTrunkCurrent: Elv5Interval.exact(_a('1.4')),
          ),
        ],
      );

      final result = const Acs03ElectricalKernel().evaluate(input);
      expect(result.status, Acs03AssessmentStatus.fail);
      expect(result.cases.single.minimumVoltageMargin, _v('-1.2'));
    });

    test('dry control path without conductive feed blocks evaluation', () {
      final input = Acs03Input(
        doorId: 'door-1',
        lockId: 'lock-1',
        conductiveFeedPathId: null,
        controlPathId: 'relay-1',
        requiredMembershipFingerprint: 'closure-v1',
        events: [
          Acs03OperatingEvent(
            eventId: 'holding',
            state: Acs03StateCode.holding,
            durationMicroseconds: BigInt.one,
          ),
        ],
        evidence: const [],
      );

      final result = const Acs03ElectricalKernel().evaluate(input);
      expect(result.status, Acs03AssessmentStatus.blocked);
      expect(result.limitingReason, 'ACS03_REQUIRED_CONDUCTIVE_FEED_MISSING');
    });

    test('reduced shared membership closure is rejected', () {
      final input = Acs03Input(
        doorId: 'door-1',
        lockId: 'lock-1',
        conductiveFeedPathId: 'feed-1',
        controlPathId: 'relay-1',
        requiredMembershipFingerprint: 'global-closure',
        events: [
          Acs03OperatingEvent(
            eventId: 'holding',
            state: Acs03StateCode.holding,
            durationMicroseconds: BigInt.one,
          ),
        ],
        evidence: [
          Acs03PwrEvidence(
            eventId: 'holding',
            membershipFingerprint: 'acs-only',
            terminalVoltage: Elv5Interval.exact(_v('24')),
            sharedTrunkCurrent: Elv5Interval.exact(_a('0.3')),
          ),
        ],
      );

      final result = const Acs03ElectricalKernel().evaluate(input);
      expect(result.status, Acs03AssessmentStatus.blocked);
      expect(result.limitingReason, 'ACS03_SHARED_MEMBERSHIP_CLOSURE_MISMATCH');
    });
  });
}
