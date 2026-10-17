import 'package:electra_mobile/application/elv5/acs/acs05_autonomy_contract.dart';
import 'package:electra_mobile/application/elv5/fire/fa05_autonomy_contract.dart';
import 'package:flutter_test/flutter_test.dart';

String _hash(String ch) => List<String>.filled(64, ch).join();

void main() {
  test('ACS-05 and FA-05 share sequence and protected-load fingerprints', () {
    final acs = Acs05AutonomyContract(
      bankId: 'bank-1',
      scenarioId: 'BACKUP',
      sequenceId: 'sequence-1',
      expectedPwr04InputFingerprint: _hash('a'),
      segments: <Acs05SequenceSegmentContract>[
        Acs05SequenceSegmentContract(
          segmentId: 'standby',
          durationMicroseconds: BigInt.from(3600000000),
        ),
        Acs05SequenceSegmentContract(
          segmentId: 'alarm',
          durationMicroseconds: BigInt.from(900000000),
        ),
      ],
      globalProtectedLoadIds: const <String>{'acs-lock', 'fire-loop', 'aux'},
      acsProtectedLoadIds: const <String>{'acs-lock'},
    );
    final fire = Fa05AutonomyContract(
      bankId: 'bank-1',
      scenarioId: 'BACKUP',
      sequenceId: 'sequence-1',
      expectedPwr04InputFingerprint: _hash('a'),
      segments: <Fa05SequenceSegmentContract>[
        Fa05SequenceSegmentContract(
          segmentId: 'standby',
          durationMicroseconds: BigInt.from(3600000000),
        ),
        Fa05SequenceSegmentContract(
          segmentId: 'alarm',
          durationMicroseconds: BigInt.from(900000000),
        ),
      ],
      globalProtectedLoadIds: const <String>{'acs-lock', 'fire-loop', 'aux'},
      fireProtectedLoadIds: const <String>{'fire-loop'},
    );

    expect(fire.sequenceFingerprint, acs.sequenceFingerprint);
    expect(fire.protectedLoadSetFingerprint, acs.protectedLoadSetFingerprint);
  });
}
