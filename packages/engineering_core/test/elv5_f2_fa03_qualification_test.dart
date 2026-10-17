import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:test/test.dart';

import 'support/elv5_foundation_qualification_support.dart';

void main() {
  group('F2 FA-03 terminal voltage', () {
    test(
        'Q0 contract inventory preserves model, scope, terminals and voltage policy',
        () {
      final input = _input(<Fa03TerminalEvidence>[
        _terminal('t-1', 'ALARM', '23.5', '24.0'),
      ]);

      expect(input.circuitId, 'circuit-1');
      expect(input.model, Fa03ElectricalModel.radialDc);
      expect(input.expectedScopeFingerprint, _scope);
      expect(input.terminals.single.caseId, 'ALARM');
      expect(input.policy.minimum.value, Elv5Rational.integer(22));
      expect(input.policy.maximum.value, Elv5Rational.integer(26));
    });

    test('Q1 exact reference vector returns +1.5 V governing margin', () {
      final result = const Fa03TerminalVoltageKernel().evaluate(
        _input(<Fa03TerminalEvidence>[
          _terminal('t-1', 'ALARM', '23.5', '24.0'),
        ]),
      );

      expect(result.status, Fa03AssessmentStatus.pass);
      expect(result.governingTerminalId, 't-1');
      expect(result.governingCaseId, 'ALARM');
      expect(
        result.terminals.single.lowMargin.value,
        Elv5Rational.parseDecimal('1.5'),
      );
      expect(
        result.terminals.single.highMargin.value,
        Elv5Rational.integer(2),
      );
      expect(
        result.terminals.single.governingMargin.value,
        Elv5Rational.parseDecimal('1.5'),
      );
    });

    test('Q2 independent oracle reproduces both voltage margins', () {
      final input = _input(<Fa03TerminalEvidence>[
        _terminal('t-1', 'ALARM', '23.51', '24.17'),
      ]);
      final production = const Fa03TerminalVoltageKernel().evaluate(input);
      final terminal = input.terminals.single;

      final oracleLow = terminal.voltage.lower - input.policy.minimum;
      final oracleHigh = input.policy.maximum - terminal.voltage.upper;

      requireIndependentOracle<Elv5Rational>(
        production: production.terminals.single.lowMargin.value,
        oracle: oracleLow.value,
      );
      requireIndependentOracle<Elv5Rational>(
        production: production.terminals.single.highMargin.value,
        oracle: oracleHigh.value,
      );
      expect(oracleLow.value, Elv5Rational.parseDecimal('1.51'));
      expect(oracleHigh.value, Elv5Rational.parseDecimal('1.83'));
    });

    test('Q3 lower-voltage boundary is inclusive below/exact/above', () {
      final triplet = Elv5BoundaryTriplet<String>(
        below: '21.999999',
        exact: '22',
        above: '22.000001',
      );
      final statuses = <Fa03AssessmentStatus>[
        for (final lower in triplet.values)
          const Fa03TerminalVoltageKernel()
              .evaluate(
                _input(<Fa03TerminalEvidence>[
                  _terminal('t-1', 'ALARM', lower, '25'),
                ]),
              )
              .status,
      ];

      expect(statuses, <Fa03AssessmentStatus>[
        Fa03AssessmentStatus.fail,
        Fa03AssessmentStatus.pass,
        Fa03AssessmentStatus.pass,
      ]);
    });

    test('Q3 upper-voltage boundary is inclusive below/exact/above', () {
      final triplet = Elv5BoundaryTriplet<String>(
        below: '25.999999',
        exact: '26',
        above: '26.000001',
      );
      final statuses = <Fa03AssessmentStatus>[
        for (final upper in triplet.values)
          const Fa03TerminalVoltageKernel()
              .evaluate(
                _input(<Fa03TerminalEvidence>[
                  _terminal('t-1', 'ALARM', '23', upper),
                ]),
              )
              .status,
      ];

      expect(statuses, <Fa03AssessmentStatus>[
        Fa03AssessmentStatus.pass,
        Fa03AssessmentStatus.pass,
        Fa03AssessmentStatus.fail,
      ]);
    });

    test(
        'Q4 terminal input permutation cannot change result or governing identity',
        () {
      final baseline = const Fa03TerminalVoltageKernel().evaluate(
        _input(<Fa03TerminalEvidence>[
          _terminal('t-2', 'ALARM', '22.4', '25.5'),
          _terminal('t-1', 'ALARM', '23.4', '24.5'),
        ]),
      );
      final transformed = const Fa03TerminalVoltageKernel().evaluate(
        _input(<Fa03TerminalEvidence>[
          _terminal('t-1', 'ALARM', '23.4', '24.5'),
          _terminal('t-2', 'ALARM', '22.4', '25.5'),
        ]),
      );

      requireMetamorphicInvariant<Fa03Result>(
        relation: 'FA03_TERMINAL_PERMUTATION_INVARIANCE',
        baseline: baseline,
        transformed: transformed,
        invariant: (left, right) =>
            left.status == right.status &&
            left.governingTerminalId == right.governingTerminalId &&
            left.governingCaseId == right.governingCaseId &&
            _resultsEqual(left.terminals, right.terminals),
      );
      expect(baseline.governingTerminalId, 't-2');
    });

    test('Q4 worse terminal envelope cannot improve assessment', () {
      final baseline = const Fa03TerminalVoltageKernel().evaluate(
        _input(<Fa03TerminalEvidence>[
          _terminal('t-1', 'ALARM', '23', '25'),
        ]),
      );
      final worse = const Fa03TerminalVoltageKernel().evaluate(
        _input(<Fa03TerminalEvidence>[
          _terminal('t-1', 'ALARM', '21.9', '25'),
        ]),
      );

      expect(baseline.status, Fa03AssessmentStatus.pass);
      expect(worse.status, Fa03AssessmentStatus.fail);
    });

    test('Q5 realistic multi-case circuit selects worst terminal/case', () {
      final result = const Fa03TerminalVoltageKernel().evaluate(
        _input(<Fa03TerminalEvidence>[
          _terminal('sounder-01', 'QUIESCENT', '24.6', '25.0'),
          _terminal('sounder-01', 'ALARM', '22.35', '23.1'),
          _terminal('sounder-02', 'QUIESCENT', '24.4', '25.1'),
          _terminal('sounder-02', 'ALARM', '21.95', '22.8'),
        ]),
      );

      expect(result.status, Fa03AssessmentStatus.fail);
      expect(result.governingTerminalId, 'sounder-02');
      expect(result.governingCaseId, 'ALARM');
      final governing = result.terminals.singleWhere(
        (value) => value.terminalId == 'sounder-02' && value.caseId == 'ALARM',
      );
      expect(governing.lowMargin.value, Elv5Rational.parseDecimal('-0.05'));
    });

    test('Q5 mismatched physical scope blocks instead of producing a verdict',
        () {
      final result = const Fa03TerminalVoltageKernel().evaluate(
        Fa03Input(
          circuitId: 'circuit-1',
          model: Fa03ElectricalModel.radialDc,
          expectedScopeFingerprint: _scope,
          terminals: <Fa03TerminalEvidence>[
            Fa03TerminalEvidence(
              terminalId: 't-1',
              caseId: 'ALARM',
              scopeFingerprint: _otherScope,
              voltage: Elv5Interval<VoltageDim>(
                Voltage(Elv5Rational.integer(23)),
                Voltage(Elv5Rational.integer(24)),
              ),
            ),
          ],
          policy: Fa03VoltagePolicy(
            minimum: Voltage(Elv5Rational.integer(22)),
            maximum: Voltage(Elv5Rational.integer(26)),
          ),
        ),
      );

      expect(result.status, Fa03AssessmentStatus.blocked);
      expect(result.blockingReason, 'FA03_PWR03_SCOPE_MISMATCH');
      expect(result.terminals, isEmpty);
    });

    test('Q9 bounded 256-terminal fold is deterministic', () {
      const count = 256;
      final terminals = <Fa03TerminalEvidence>[
        for (var i = 0; i < count; i++)
          _terminal(
            't-${i.toString().padLeft(3, '0')}',
            i.isEven ? 'QUIESCENT' : 'ALARM',
            i == 197 ? '22.1' : '23.0',
            '25.0',
          ),
      ];
      final kernel = const Fa03TerminalVoltageKernel();
      final first = kernel.evaluate(_input(terminals));
      final second = kernel.evaluate(_input(terminals.reversed.toList()));

      expect(first.terminals, hasLength(count));
      expect(first.status, Fa03AssessmentStatus.pass);
      expect(first.governingTerminalId, 't-197');
      expect(second.governingTerminalId, first.governingTerminalId);
      expect(second.governingCaseId, first.governingCaseId);
      expect(_resultsEqual(first.terminals, second.terminals), isTrue);
    });
  });
}

Fa03Input _input(List<Fa03TerminalEvidence> terminals) => Fa03Input(
      circuitId: 'circuit-1',
      model: Fa03ElectricalModel.radialDc,
      expectedScopeFingerprint: _scope,
      terminals: terminals,
      policy: Fa03VoltagePolicy(
        minimum: Voltage(Elv5Rational.integer(22)),
        maximum: Voltage(Elv5Rational.integer(26)),
      ),
    );

Fa03TerminalEvidence _terminal(
  String terminalId,
  String caseId,
  String lower,
  String upper,
) =>
    Fa03TerminalEvidence(
      terminalId: terminalId,
      caseId: caseId,
      scopeFingerprint: _scope,
      voltage: Elv5Interval<VoltageDim>(
        Voltage(Elv5Rational.parseDecimal(lower)),
        Voltage(Elv5Rational.parseDecimal(upper)),
      ),
    );

bool _resultsEqual(
    List<Fa03TerminalResult> left, List<Fa03TerminalResult> right) {
  if (left.length != right.length) return false;
  for (var i = 0; i < left.length; i++) {
    final a = left[i];
    final b = right[i];
    if (a.terminalId != b.terminalId ||
        a.caseId != b.caseId ||
        a.voltage.lower != b.voltage.lower ||
        a.voltage.upper != b.voltage.upper ||
        a.lowMargin != b.lowMargin ||
        a.highMargin != b.highMargin ||
        a.status != b.status) {
      return false;
    }
  }
  return true;
}

const _scope =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _otherScope =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
