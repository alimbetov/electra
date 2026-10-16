import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:test/test.dart';

void main() {
  Voltage v(String value) => Voltage(Elv5Rational.parseDecimal(value));

  Fa03Input input(Elv5Interval<VoltageDim> voltage,
          {Fa03ElectricalModel model = Fa03ElectricalModel.radialDc}) =>
      Fa03Input(
        circuitId: 'fire-circuit',
        model: model,
        expectedScopeFingerprint: 'scope-v1',
        terminals: [
          Fa03TerminalEvidence(
            terminalId: 'terminal-1',
            caseId: 'alarm',
            scopeFingerprint: 'scope-v1',
            voltage: voltage,
          ),
        ],
        policy: Fa03VoltagePolicy(minimum: v('22'), maximum: v('26')),
      );

  test('23.9 V fixture passes with exact low/high margins', () {
    final result = const Fa03TerminalVoltageKernel().evaluate(
      input(Elv5Interval<VoltageDim>.exact(v('23.9'))),
    );
    expect(result.status, Fa03AssessmentStatus.pass);
    expect(result.terminals.single.lowMargin, v('1.9'));
    expect(result.terminals.single.highMargin, v('2.1'));
  });

  test('exact 22 V lower boundary is inclusive PASS', () {
    final result = const Fa03TerminalVoltageKernel().evaluate(
      input(Elv5Interval<VoltageDim>.exact(v('22'))),
    );
    expect(result.status, Fa03AssessmentStatus.pass);
    expect(result.terminals.single.lowMargin, v('0'));
  });

  test('21.5 V terminal fails with -0.5 V margin', () {
    final result = const Fa03TerminalVoltageKernel().evaluate(
      input(Elv5Interval<VoltageDim>.exact(v('21.5'))),
    );
    expect(result.status, Fa03AssessmentStatus.fail);
    expect(result.terminals.single.lowMargin, v('-0.5'));
  });

  test('unsupported electrical loop model blocks instead of approximating', () {
    final result = const Fa03TerminalVoltageKernel().evaluate(
      input(
        Elv5Interval<VoltageDim>.exact(v('24')),
        model: Fa03ElectricalModel.unsupported,
      ),
    );
    expect(result.status, Fa03AssessmentStatus.blocked);
    expect(result.blockingReason, 'FA03_UNSUPPORTED_ELECTRICAL_MODEL');
  });
}
