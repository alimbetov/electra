import 'package:electra_mobile/application/elv5/cctv/cctv05_capability_contract.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_elv5_cctv_contract_mutation_coordinator.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_elv5_current_evaluation_source.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/elv5_f2_cctv_sources.dart';
import '../support/elv5_f2_production_lifecycle.dart';

void main() {
  test(
    'F2 CCTV-05 production Q6/Q7/Q8 consumes real current CCTV02 and CCTV03 without reapplying reserve across restart and freeze',
    () async {
      final lifecycle = Elv5F2ProductionLifecycle(
        process: Elv5ProcessCode.cctv05,
        subjectKind: 'RECORDER',
        subjectId: 'rec-1',
      );
      late String cameraFingerprint, poolFingerprint;
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
          await replaceF2CctvAggregate(
            db,
            operation: 'REPLACE_RECORDING_ASSIGNMENTS',
            payload: f2CctvRecordingPool(),
            commandId: 'seed-pool',
          );
          for (final item in [
            (Elv5ProcessCode.cctv02, 'CAMERA', 'cam-1'),
            (Elv5ProcessCode.cctv03, 'RECORDING_POOL', 'pool-1'),
          ]) {
            final upstream = Elv5F2ProductionLifecycle(
              process: item.$1,
              subjectKind: item.$2,
              subjectId: item.$3,
            )..db = db;
            await upstream
                .runtime(db)
                .service
                .execute(
                  upstream.command(
                    'seed-${item.$1.wireCode}',
                    await upstream.revision(),
                    0,
                  ),
                );
          }
          final source = DriftElv5CurrentEvaluationSource(db);
          final camera =
              (await source.loadCurrent(
                projectId: 'p',
                designRevisionId: 'd',
                processCode: Elv5ProcessCode.cctv02,
                subjectId: 'cam-1',
              )).single;
          final pool =
              (await source.loadCurrent(
                projectId: 'p',
                designRevisionId: 'd',
                processCode: Elv5ProcessCode.cctv03,
                subjectId: 'pool-1',
              )).single;
          expect(camera.execution, 'SUCCEEDED');
          expect(camera.completion, 'COMPLETE');
          expect(pool.execution, 'SUCCEEDED');
          expect(pool.completion, 'COMPLETE');
          expect(pool.output['sizingBasis'], 'guaranteedUpperBound');
          cameraFingerprint = camera.inputFingerprint;
          poolFingerprint = pool.inputFingerprint;
          await _replace(
            db,
            cameraFingerprint,
            poolFingerprint,
            await lifecycle.revision(),
            null,
            false,
          );
        },
        mutate:
            (db) async => _replace(
              db,
              cameraFingerprint,
              poolFingerprint,
              await lifecycle.revision(),
              1,
              true,
            ),
        dependencyDomains: {
          'CCTV05_CAPABILITY_CONTRACT',
          'CCTV_CAMERA_STREAMS',
          'CCTV_RECORDER',
          'CCTV02_CURRENT',
          'CCTV03_CURRENT',
        },
        initialOutput: (o) => _check(o, 'pass', 70400000000),
        changedOutput: (o) => _check(o, 'fail', -29600000000),
        mutationAfterFreeze: (db) async {
          await expectLater(
            _replace(
              db,
              cameraFingerprint,
              poolFingerprint,
              await lifecycle.revision(),
              2,
              false,
            ),
            throwsA(
              predicate(
                (e) =>
                    e.toString().contains('CCTV05_DESIGN_REVISION_READ_ONLY'),
              ),
            ),
          );
        },
      );
    },
  );
}

void _check(Map<String, dynamic> o, String status, int storageMargin) {
  expect(o['status'], status);
  expect(o['consumedChannels'], 1);
  expect(o['channelMargin'], 1);
  expect(o['peakIngressBps'], Elv5Rational.integer(12000000).toMap());
  expect(o['ingressMarginBps'], Elv5Rational.integer(8000000).toMap());
  expect(o['requiredUsableBytes'], Elv5Rational.integer(129600000000).toMap());
  expect(o['storageMarginBytes'], Elv5Rational.integer(storageMargin).toMap());
}

Future<void> _replace(
  AppDatabase db,
  String camera,
  String pool,
  int revision,
  int? bindingRevision,
  bool changed,
) => DriftElv5CctvContractMutationCoordinator(
  db,
  originDeviceId: 'f2-cctv',
  nowUtc: Elv5F2ProductionLifecycle.now,
).replaceCctv05(
  ReplaceCctv05CapabilityContractCommand(
    projectId: 'p',
    designRevisionId: 'd',
    bindingId: 'recorder-policy',
    expectedBindingRevision: bindingRevision,
    expectedDesignRevision: revision,
    contract: Cctv05CapabilityContract(
      recorderId: 'rec-1',
      expectedDefinitionId: 'fictional-rec-1',
      expectedDefinitionVersion: 1,
      channelLimit: 2,
      peakIngressCapacityBps: Elv5Rational.integer(20000000),
      usableStorageCapacityBytes: Elv5Rational.integer(
        changed ? 100000000000 : 200000000000,
      ),
      supportedCodecProfiles: const ['H264'],
      requireGuaranteedStorage: true,
      expectedCctv02InputFingerprintByCamera: {'cam-1': camera},
      expectedCctv03InputFingerprintByPool: {'pool-1': pool},
    ),
  ),
);
