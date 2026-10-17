import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:test/test.dart';

import 'support/elv5_foundation_qualification_support.dart';

void main() {
  group('F2 ACS-03 electrical', () {
    test('Q0 contract inventory separates feed, control, events and PWR evidence', () {
      final input = _input(<Acs03OperatingEvent>[_event('holding')], <Acs03PwrEvidence>[
        _evidence('holding', '23.51', '24.10'),
      ]);

      expect(input.doorId, 'door-1');
      expect(input.lockId, 'lock-1');
      expect(input.conductiveFeedPathId, 'feed-1');
      expect(input.controlPathId, 'control-1');
      expect(input.requiredMembershipFingerprint, _membership);
      expect(input.minimumTerminalVoltage!.value, Elv5Rational.integer(22));
      expect(input.maximumTerminalVoltage!.value, Elv5Rational.integer(26));
    });

    test('Q1 canonical reference vector is 23.51 V with +1.51 V low margin', () {
      final result = const Acs03ElectricalKernel().evaluate(
        _input(<Acs03OperatingEvent>[_event('holding')], <Acs03PwrEvidence>[
          _evidence('holding', '23.51', '24.10'),
        ]),
      );

      expect(result.status, Acs03AssessmentStatus.pass);
      expect(result.governingCaseId, 'holding');
      final value = result.cases.single;
      expect(value.terminalVoltage!.lower.value, Elv5Rational.parseDecimal('23.51'));
      expect(value.minimumVoltageMargin!.value, Elv5Rational.parseDecimal('1.51'));
      expect(value.maximumVoltageMargin!.value, Elv5Rational.parseDecimal('1.90'));
    });

    test('Q2 independent oracle reproduces +1.51 V without production kernel math', () {
      final input = _input(<Acs03OperatingEvent>[_event('holding')], <Acs03PwrEvidence>[
        _evidence('holding', '23.51', '24.10'),
      ]);
      final production = const Acs03ElectricalKernel().evaluate(input);
      final terminalLower = input.evidence.single.terminalVoltage.lower;
      final oracle = terminalLower - input.minimumTerminalVoltage!;

      requireIndependentOracle<Elv5Rational>(
        production: production.cases.single.minimumVoltageMargin!.value,
        oracle: oracle.value,
      );
      expect(oracle.value, Elv5Rational.parseDecimal('1.51'));
    });

    test('Q3 minimum-voltage below/exact/above boundary is inclusive', () {
      final values = Elv5BoundaryTriplet<String>(
        below: '21.999999',
        exact: '22',
        above: '22.000001',
      );
      final statuses = <Acs03AssessmentStatus>[
        for (final lower in values.values)
          const Acs03ElectricalKernel()
              .evaluate(
                _input(<Acs03OperatingEvent>[_event('holding')], <Acs03PwrEvidence>[
                  _evidence('holding', lower, '25'),
                ]),
              )
              .status,
      ];
      expect(statuses, <Acs03AssessmentStatus>[
        Acs03AssessmentStatus.fail,
        Acs03AssessmentStatus.pass,
        Acs03AssessmentStatus.pass,
      ]);
    });

    test('Q3 source-current margin exact zero passes, negative fails', () {
      final exact = const Acs03ElectricalKernel().evaluate(
        _input(<Acs03OperatingEvent>[_event('holding')], <Acs03PwrEvidence>[
          _evidence('holding', '23', '24', currentMarginLower: '0'),
        ]),
      );
      final negative = const Acs03ElectricalKernel().evaluate(
        _input(<Acs03OperatingEvent>[_event('holding')], <Acs03PwrEvidence>[
          _evidence('holding', '23', '24', currentMarginLower: '-0.000001'),
        ]),
      );

      expect(exact.status, Acs03AssessmentStatus.pass);
      expect(negative.status, Acs03AssessmentStatus.fail);
      expect(negative.limitingReason, 'ACS03_SOURCE_CURRENT_MARGIN');
    });

    test('Q4 event/evidence permutation is deterministic', () {
      final events = <Acs03OperatingEvent>[
        _event('release', state: Acs03StateCode.activeRelease),
        _event('holding'),
      ];
      final evidence = <Acs03PwrEvidence>[
        _evidence('release', '22.4', '24.8'),
        _evidence('holding', '23.5', '24.2'),
      ];
      final left = const Acs03ElectricalKernel().evaluate(_input(events, evidence));
      final right = const Acs03ElectricalKernel().evaluate(
        _input(events.reversed.toList(), evidence.reversed.toList()),
      );

      requireMetamorphicInvariant<Acs03Result>(
        relation: 'ACS03_EVENT_EVIDENCE_PERMUTATION_INVARIANCE',
        baseline: left,
        transformed: right,
        invariant: (a, b) =>
            a.status == b.status &&
            a.governingCaseId == b.governingCaseId &&
            _sameCases(a.cases, b.cases),
      );
      expect(left.governingCaseId, 'release');
    });

    test('Q4 lowering terminal voltage cannot improve assessment', () {
      final good = const Acs03ElectricalKernel().evaluate(
        _input(<Acs03OperatingEvent>[_event('holding')], <Acs03PwrEvidence>[
          _evidence('holding', '23', '24'),
        ]),
      );
      final worse = const Acs03ElectricalKernel().evaluate(
        _input(<Acs03OperatingEvent>[_event('holding')], <Acs03PwrEvidence>[
          _evidence('holding', '21.9', '24'),
        ]),
      );
      expect(good.status, Acs03AssessmentStatus.pass);
      expect(worse.status, Acs03AssessmentStatus.fail);
    });

    test('Q5 realistic operating sequence selects release voltage failure', () {
      final result = const Acs03ElectricalKernel().evaluate(
        _input(
          <Acs03OperatingEvent>[
            _event('holding'),
            _event('startup', state: Acs03StateCode.startupInrush, durationUs: 250000),
            _event('release', state: Acs03StateCode.activeRelease, durationUs: 1500000),
          ],
          <Acs03PwrEvidence>[
            _evidence('holding', '23.8', '24.4'),
            _evidence('startup', '22.2', '24.2', currentMarginLower: '0.2'),
            _evidence('release', '21.95', '23.0'),
          ],
        ),
      );

      expect(result.status, Acs03AssessmentStatus.fail);
      expect(result.governingCaseId, 'release');
      expect(result.limitingReason, 'ACS03_MINIMUM_TERMINAL_VOLTAGE');
    });

    test('Q5 missing evidence is unresolved and membership mismatch is blocked', () {
      final unresolved = const Acs03ElectricalKernel().evaluate(
        _input(<Acs03OperatingEvent>[_event('holding')], const <Acs03PwrEvidence>[]),
      );
      final blocked = const Acs03ElectricalKernel().evaluate(
        _input(<Acs03OperatingEvent>[_event('holding')], <Acs03PwrEvidence>[
          _evidence('holding', '23', '24', membership: _otherMembership),
        ]),
      );

      expect(unresolved.status, Acs03AssessmentStatus.unresolved);
      expect(unresolved.cases.single.reason, 'ACS03_PWR_EVIDENCE_MISSING');
      expect(blocked.status, Acs03AssessmentStatus.blocked);
      expect(blocked.limitingReason, 'ACS03_SHARED_MEMBERSHIP_CLOSURE_MISMATCH');
    });

    test('Q9 bounded 256-event sequence is deterministic', () {
      const count = 256;
      final events = <Acs03OperatingEvent>[
        for (var i = 0; i < count; i++)
          _event('event-${i.toString().padLeft(3, '0')}'),
      ];
      final evidence = <Acs03PwrEvidence>[
        for (var i = 0; i < count; i++)
          _evidence(
            'event-${i.toString().padLeft(3, '0')}',
            i == 211 ? '22.1' : '23',
            '25',
          ),
      ];
      final kernel = const Acs03ElectricalKernel();
      final first = kernel.evaluate(_input(events, evidence));
      final second = kernel.evaluate(
        _input(events.reversed.toList(), evidence.reversed.toList()),
      );

      expect(first.cases, hasLength(count));
      expect(first.status, Acs03AssessmentStatus.pass);
      expect(first.governingCaseId, 'event-211');
      expect(second.governingCaseId, first.governingCaseId);
      expect(_sameCases(first.cases, second.cases), isTrue);
    });
  });
}

Acs03Input _input(
  List<Acs03OperatingEvent> events,
  List<Acs03PwrEvidence> evidence,
) => Acs03Input(
  doorId: 'door-1',
  lockId: 'lock-1',
  conductiveFeedPathId: 'feed-1',
  controlPathId: 'control-1',
  requiredMembershipFingerprint: _membership,
  events: events,
  evidence: evidence,
  minimumTerminalVoltage: Voltage(Elv5Rational.integer(22)),
  maximumTerminalVoltage: Voltage(Elv5Rational.integer(26)),
);

Acs03OperatingEvent _event(
  String id, {
  Acs03StateCode state = Acs03StateCode.holding,
  int durationUs = 1000000,
}) => Acs03OperatingEvent(
  eventId: id,
  state: state,
  durationMicroseconds: BigInt.from(durationUs),
);

Acs03PwrEvidence _evidence(
  String eventId,
  String lowerV,
  String upperV, {
  String currentMarginLower = '1',
  String membership = _membership,
}) => Acs03PwrEvidence(
  eventId: eventId,
  membershipFingerprint: membership,
  terminalVoltage: Elv5Interval<VoltageDim>(
    Voltage(Elv5Rational.parseDecimal(lowerV)),
    Voltage(Elv5Rational.parseDecimal(upperV)),
  ),
  sharedTrunkCurrent: Elv5Interval<CurrentDim>(
    Current(Elv5Rational.parseDecimal('0.3')),
    Current(Elv5Rational.parseDecimal('0.4')),
  ),
  sourceCurrentMargin: Elv5Interval<CurrentDim>(
    Current(Elv5Rational.parseDecimal(currentMarginLower)),
    Current(Elv5Rational.parseDecimal('2')),
  ),
);

bool _sameCases(List<Acs03CaseResult> left, List<Acs03CaseResult> right) {
  if (left.length != right.length) return false;
  for (var i = 0; i < left.length; i++) {
    final a = left[i];
    final b = right[i];
    if (a.eventId != b.eventId ||
        a.state != b.state ||
        a.durationMicroseconds != b.durationMicroseconds ||
        a.status != b.status ||
        a.terminalVoltage?.lower != b.terminalVoltage?.lower ||
        a.terminalVoltage?.upper != b.terminalVoltage?.upper ||
        a.minimumVoltageMargin != b.minimumVoltageMargin ||
        a.maximumVoltageMargin != b.maximumVoltageMargin ||
        a.sourceCurrentMargin?.lower != b.sourceCurrentMargin?.lower ||
        a.reason != b.reason) {
      return false;
    }
  }
  return true;
}

const _membership = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _otherMembership = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
