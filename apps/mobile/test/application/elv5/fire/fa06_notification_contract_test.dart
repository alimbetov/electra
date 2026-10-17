import 'package:electra_mobile/application/elv5/fire/fa06_notification_contract.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('round-trips exact FA-06 notification contract', () {
    final contract = Fa06NotificationContract(
      circuitId: 'nac-1',
      deviceLimit: 4,
      outputCurrentLimitA: Elv5Rational.parseDecimal('0.5'),
      minimumTerminalVoltageV: Elv5Rational.integer(22),
      maximumTerminalVoltageV: Elv5Rational.integer(26),
      cases: <Fa06CaseContract>[
        Fa06CaseContract(
          operatingCase: Fa06ContractCase.activeNotification,
          stateCode: 'ALARM',
          scenarioId: 'FIRE_ALARM',
          segmentId: 'NAC_ACTIVE',
          pwr01SubjectKind: 'NOTIFICATION_OUTPUT',
          pwr01SubjectId: 'nac-1',
          pwr03SubjectKind: 'DC_DOMAIN',
          pwr03SubjectId: 'nac-domain-1',
        ),
      ],
      terminalLoadIdByDeviceId: const <String, String>{
        'horn-1': 'horn-1',
        'horn-2': 'horn-2',
        'horn-3': 'horn-3',
      },
      supervision: Fa06SupervisionContract(
        required: true,
        modelSupported: true,
        modelCode: 'EOL-SUPERVISION-V1',
        evidenceRef: 'SUP:nac-1:v1',
        evidenceContentHash: _hash('a'),
        faultResults: <Fa06SupervisionFaultResult>[
          Fa06SupervisionFaultResult(faultCode: 'OPEN', passed: true),
          Fa06SupervisionFaultResult(faultCode: 'SHORT', passed: true),
          Fa06SupervisionFaultResult(faultCode: 'RETURN_LOSS', passed: true),
        ],
      ),
    );

    final restored = Fa06NotificationContract.fromMap(contract.toCanonicalValue());
    expect(restored.circuitId, 'nac-1');
    expect(restored.outputCurrentLimitA, Elv5Rational.parseDecimal('0.5'));
    expect(restored.cases.single.stateCode, 'ALARM');
    expect(restored.supervision.passed, isTrue);
    expect(restored.supervision.faultResults, hasLength(3));
    expect(
      restored.membershipFingerprint(const <String>['horn-3', 'horn-1', 'horn-2']),
      contract.membershipFingerprint(const <String>['horn-1', 'horn-2', 'horn-3']),
    );
  });

  test('requires ACTIVE_NOTIFICATION case', () {
    expect(
      () => Fa06NotificationContract(
        circuitId: 'nac-1',
        deviceLimit: 4,
        outputCurrentLimitA: Elv5Rational.parseDecimal('0.5'),
        minimumTerminalVoltageV: Elv5Rational.integer(22),
        maximumTerminalVoltageV: Elv5Rational.integer(26),
        cases: <Fa06CaseContract>[
          Fa06CaseContract(
            operatingCase: Fa06ContractCase.startupInrush,
            stateCode: 'STARTUP',
            scenarioId: 'FIRE_ALARM',
            segmentId: 'NAC_STARTUP',
            pwr01SubjectKind: 'NOTIFICATION_OUTPUT',
            pwr01SubjectId: 'nac-1',
            pwr03SubjectKind: 'DC_DOMAIN',
            pwr03SubjectId: 'nac-domain-1',
          ),
        ],
        terminalLoadIdByDeviceId: const <String, String>{'horn-1': 'horn-1'},
        supervision: Fa06SupervisionContract(
          required: false,
          modelSupported: false,
        ),
      ),
      throwsArgumentError,
    );
  });

  test('required supported supervision needs explicit fault results', () {
    expect(
      () => Fa06SupervisionContract(
        required: true,
        modelSupported: true,
        modelCode: 'EOL-SUPERVISION-V1',
        evidenceRef: 'SUP:nac-1:v1',
        evidenceContentHash: _hash('b'),
      ),
      throwsArgumentError,
    );
  });
}

String _hash(String char) => List<String>.filled(64, char).join();
