import 'package:electra_mobile/application/elv5/acs/acs05_autonomy_contract.dart';
import 'package:flutter_test/flutter_test.dart';

String _sha(String ch) => List<String>.filled(64, ch).join();

void main() {
  test(
    'ACS-05 contract round-trips with stable sequence/load fingerprints',
    () {
      final contract = Acs05AutonomyContract(
        bankId: 'bank-1',
        scenarioId: 'BACKUP',
        sequenceId: 'sequence-1',
        expectedPwr04InputFingerprint: _sha('a'),
        segments: <Acs05SequenceSegmentContract>[
          Acs05SequenceSegmentContract(
            segmentId: 'standby',
            durationMicroseconds: BigInt.from(3600000000),
          ),
          Acs05SequenceSegmentContract(
            segmentId: 'release',
            durationMicroseconds: BigInt.from(30000000),
          ),
        ],
        globalProtectedLoadIds: const <String>{'acs-lock', 'fire-loop'},
        acsProtectedLoadIds: const <String>{'acs-lock'},
      );

      final restored = Acs05AutonomyContract.fromMap(
        contract.toCanonicalValue(),
      );
      expect(restored.toCanonicalValue(), contract.toCanonicalValue());
      expect(restored.sequenceFingerprint, contract.sequenceFingerprint);
      expect(
        restored.protectedLoadSetFingerprint,
        contract.protectedLoadSetFingerprint,
      );
    },
  );

  test('rejects ACS subset outside global protected-load closure', () {
    expect(
      () => Acs05AutonomyContract(
        bankId: 'bank-1',
        scenarioId: 'BACKUP',
        sequenceId: 'sequence-1',
        expectedPwr04InputFingerprint: _sha('b'),
        segments: <Acs05SequenceSegmentContract>[
          Acs05SequenceSegmentContract(
            segmentId: 'standby',
            durationMicroseconds: BigInt.from(1000000),
          ),
        ],
        globalProtectedLoadIds: const <String>{'fire-loop'},
        acsProtectedLoadIds: const <String>{'acs-lock'},
      ),
      throwsArgumentError,
    );
  });

  test('persists explicit unsupported-dimension requirements in contract', () {
    final contract = Acs05AutonomyContract(
      bankId: 'bank-1',
      scenarioId: 'BACKUP',
      sequenceId: 'sequence-1',
      expectedPwr04InputFingerprint: _sha('c'),
      segments: <Acs05SequenceSegmentContract>[
        Acs05SequenceSegmentContract(
          segmentId: 'standby',
          durationMicroseconds: BigInt.from(1000000),
        ),
      ],
      globalProtectedLoadIds: const <String>{'acs-lock'},
      acsProtectedLoadIds: const <String>{'acs-lock'},
      requirePeakCurrentEvidence: true,
      requireEndOfDischargeEvidence: true,
    );

    expect(contract.toCanonicalValue()['requirePeakCurrentEvidence'], isTrue);
    expect(
      contract.toCanonicalValue()['requireEndOfDischargeEvidence'],
      isTrue,
    );
  });
}
