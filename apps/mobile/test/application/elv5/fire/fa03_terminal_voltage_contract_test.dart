import 'package:electra_mobile/application/elv5/fire/fa03_terminal_voltage_contract.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('round-trips exact FA-03 terminal-voltage contract', () {
    final contract = _contract(_hash('a'));
    final restored = Fa03TerminalVoltageContract.fromMap(
      contract.toCanonicalValue(),
    );

    expect(restored.circuitId, 'fire-circuit-1');
    expect(restored.model, Fa03ContractModel.radialDc);
    expect(restored.minimumTerminalVoltageV, Elv5Rational.integer(22));
    expect(restored.maximumTerminalVoltageV, Elv5Rational.integer(26));
    expect(
      restored.cases.single.terminalLoadIdByTerminalId['last-device'],
      'load-3',
    );
    expect(restored.scopeFingerprint, contract.scopeFingerprint);
  });

  test(
    'PWR-03 input identity participates independently from scope fingerprint',
    () {
      final a = _contract(_hash('a'));
      final b = _contract(_hash('b'));
      expect(a.scopeFingerprint, b.scopeFingerprint);
      expect(
        a.cases.single.expectedPwr03InputFingerprint,
        isNot(b.cases.single.expectedPwr03InputFingerprint),
      );
    },
  );
}

Fa03TerminalVoltageContract _contract(String pwr03Input) =>
    Fa03TerminalVoltageContract(
      circuitId: 'fire-circuit-1',
      model: Fa03ContractModel.radialDc,
      minimumTerminalVoltageV: Elv5Rational.integer(22),
      maximumTerminalVoltageV: Elv5Rational.integer(26),
      cases: <Fa03CaseContract>[
        Fa03CaseContract(
          caseId: 'alarm',
          scenarioId: 'FIRE_ALARM',
          segmentId: 'FIRE_SEGMENT',
          pwr03SubjectKind: 'DC_DOMAIN',
          pwr03SubjectId: 'fire-domain-1',
          expectedPwr03InputFingerprint: pwr03Input,
          terminalLoadIdByTerminalId: const <String, String>{
            'first-device': 'load-1',
            'last-device': 'load-3',
          },
        ),
      ],
    );

String _hash(String char) => List<String>.filled(64, char).join();
