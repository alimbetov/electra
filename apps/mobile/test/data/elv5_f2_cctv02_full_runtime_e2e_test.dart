import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/elv5_f2_cctv_sources.dart';
import '../support/elv5_f2_production_lifecycle.dart';

void main() {
  test(
    'F2 CCTV-02 production Q6/Q7/Q8 exact recorder ingress follows authoritative stream replacement across restart and freeze',
    () async {
      final lifecycle = Elv5F2ProductionLifecycle(
        process: Elv5ProcessCode.cctv02,
        subjectKind: 'CAMERA',
        subjectId: 'cam-1',
      );
      await lifecycle.run(
        seed: (db) async {
          await seedF2CctvTopology(db);
          await replaceF2CctvRecorder(db, f2CctvRecorder(), 'seed-recorder');
          await replaceF2CctvAggregate(
            db,
            operation: 'REPLACE_CAMERA_STREAMS',
            payload: f2CctvStreams(),
            commandId: 'seed-streams',
          );
        },
        mutate:
            (db) => replaceF2CctvAggregate(
              db,
              operation: 'REPLACE_CAMERA_STREAMS',
              payload: f2CctvStreams(expected: 16000000, peak: 24000000),
              commandId: 'raise-bitrate',
            ),
        initialAssessment: 'NOTASSESSED',
        changedAssessment: 'NOTASSESSED',
        dependencyDomains: {
          'CCTV_CAMERA_STREAMS',
          'CCTV_STREAM',
          'CCTV_SUBSCRIPTION',
          'CCTV_RECORDER_ASSIGNMENT',
        },
        initialOutput: (o) => _check(o, 8000000, 12000000),
        changedOutput: (o) => _check(o, 16000000, 24000000),
        mutationAfterFreeze: (db) async {
          await expectLater(
            replaceF2CctvAggregate(
              db,
              operation: 'REPLACE_CAMERA_STREAMS',
              payload: f2CctvStreams(),
              commandId: 'frozen-streams',
            ),
            throwsA(
              predicate(
                (e) => e.toString().contains('ELV5_DESIGN_REVISION_READ_ONLY'),
              ),
            ),
          );
        },
      );
    },
  );
}

void _check(Map<String, dynamic> o, int expected, int peak) {
  for (final traffic in [
    (o['edges'] as Map)['edge-1'],
    (o['recorderIngress'] as Map)['rec-1'],
  ]) {
    expect(
      traffic['expected']['loadBps'],
      Elv5Rational.integer(expected).toMap(),
    );
    expect(traffic['peak']['loadBps'], Elv5Rational.integer(peak).toMap());
    expect(traffic['peak']['complete'], true);
  }
}
