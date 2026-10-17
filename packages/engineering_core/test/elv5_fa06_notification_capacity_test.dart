import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:test/test.dart';

Current _a(String v) => Current(Elv5Rational.parseDecimal(v));
Voltage _v(String v) => Voltage(Elv5Rational.parseDecimal(v));
Elv5Interval<CurrentDim> _ci(String v) => Elv5Interval.exact(_a(v));
Elv5Interval<VoltageDim> _vi(String v) => Elv5Interval.exact(_v(v));

void main() {
  test(
      'FA06 passes active notification with exact current and voltage headroom',
      () {
    final result = const Fa06NotificationCapacityKernel().evaluate(Fa06Input(
      circuitId: 'nac-1',
      deviceIds: ['n1', 'n2', 'n3'],
      expectedMembershipFingerprint: 'members-v1',
      deviceLimit: 4,
      cases: [
        Fa06ElectricalCaseEvidence(
            operatingCase: Fa06OperatingCase.activeNotification,
            membershipFingerprint: 'members-v1',
            outputCurrent: _ci('0.3'),
            terminalVoltage: _vi('23'),
            outputCurrentLimit: _a('0.5'),
            minimumTerminalVoltage: _v('22'),
            maximumTerminalVoltage: _v('26'))
      ],
      supervision: const Fa06SupervisionEvidence(
          required: false, modelSupported: false, passed: false),
    ));
    expect(result.status, Fa06AssessmentStatus.pass);
    expect(result.cases[Fa06OperatingCase.activeNotification]!.currentMargin,
        _a('0.2'));
    expect(result.governingCase, isNull);
    expect(result.governingDimension, isNull);
    expect(result.acousticCoverageAssessed, isFalse);
  });

  test('FA06 startup overcurrent fails independently of device count', () {
    final result = const Fa06NotificationCapacityKernel().evaluate(Fa06Input(
      circuitId: 'nac-1',
      deviceIds: ['n1', 'n2', 'n3'],
      expectedMembershipFingerprint: 'members-v1',
      deviceLimit: 4,
      cases: [
        Fa06ElectricalCaseEvidence(
            operatingCase: Fa06OperatingCase.activeNotification,
            membershipFingerprint: 'members-v1',
            outputCurrent: _ci('0.3'),
            terminalVoltage: _vi('23'),
            outputCurrentLimit: _a('0.5'),
            minimumTerminalVoltage: _v('22'),
            maximumTerminalVoltage: _v('26')),
        Fa06ElectricalCaseEvidence(
            operatingCase: Fa06OperatingCase.startupInrush,
            membershipFingerprint: 'members-v1',
            outputCurrent: _ci('0.62'),
            terminalVoltage: _vi('22.5'),
            outputCurrentLimit: _a('0.5'),
            minimumTerminalVoltage: _v('22'),
            maximumTerminalVoltage: _v('26')),
      ],
      supervision: const Fa06SupervisionEvidence(
          required: false, modelSupported: false, passed: false),
    ));
    expect(result.status, Fa06AssessmentStatus.fail);
    expect(result.governingCase, Fa06OperatingCase.startupInrush);
    expect(result.governingDimension, Fa06GoverningDimension.outputCurrent);
    expect(result.cases[Fa06OperatingCase.startupInrush]!.currentMargin,
        _a('-0.12'));
  });

  test('FA06 does not compare failed current and voltage margins across units',
      () {
    final result = const Fa06NotificationCapacityKernel().evaluate(Fa06Input(
      circuitId: 'nac-1',
      deviceIds: ['n1'],
      expectedMembershipFingerprint: 'members-v1',
      deviceLimit: 4,
      cases: [
        Fa06ElectricalCaseEvidence(
          operatingCase: Fa06OperatingCase.activeNotification,
          membershipFingerprint: 'members-v1',
          outputCurrent: _ci('0.6'),
          terminalVoltage: _vi('21'),
          outputCurrentLimit: _a('0.5'),
          minimumTerminalVoltage: _v('22'),
          maximumTerminalVoltage: _v('26'),
        ),
      ],
      supervision: const Fa06SupervisionEvidence(
          required: false, modelSupported: false, passed: false),
    ));
    expect(result.status, Fa06AssessmentStatus.fail);
    expect(result.governingCase, Fa06OperatingCase.activeNotification);
    expect(result.governingDimension, isNull);
    expect(
        result.cases[Fa06OperatingCase.activeNotification]!.governingDimension,
        isNull);
  });
}
