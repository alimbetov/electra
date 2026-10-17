import 'package:electra_mobile/data/repositories/elv5/drift_elv5_current_evaluation_source.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:electra_mobile/application/elv5/cctv/elv5_cctv_mutation_service.dart';
import 'package:electra_mobile/application/elv5/cctv/elv5_cctv_recorder_mutation_service.dart';
import 'package:electra_mobile/application/elv5/wire/elv5_wire_command.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_elv5_cctv_write_unit_of_work.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_elv5_cctv_recorder_write_unit_of_work.dart';
import 'elv5_f2_production_lifecycle.dart';
import 'elv5_f2_fire_sources.dart';

Future<void> seedF2CctvTopology(AppDatabase db) async {
  await seedF2FireTopology(db);
  await seedF2FireComponent(db, 'cam-1');
  await seedF2FireComponent(db, 'rec-1');
}

Future<void> replaceF2CctvAggregate(
  AppDatabase db, {
  required String operation,
  required Map<String, Object?> payload,
  required String commandId,
}) async {
  final service = Elv5CctvMutationService(
    unitOfWork: DriftElv5CctvWriteUnitOfWork(db, originDeviceId: 'f2-cctv'),
    originDeviceId: 'f2-cctv',
    now: Elv5F2ProductionLifecycle.now,
  );
  final preview = await service.preview(
    projectId: 'p',
    designRevisionId: 'd',
    operation: operation,
    payload: payload,
  );
  await service.execute(
    Elv5WireCommandEnvelope(
      operation: operation,
      projectId: 'p',
      designRevisionId: 'd',
      commandId: commandId,
      expectedDesignRowRevision: preview.designRowRevision,
      expectedRows: preview.expectedRows,
      reviewedImpactFingerprint: preview.reviewedImpactFingerprint,
      payload: payload,
    ),
  );
}

Future<void> replaceF2CctvRecorder(
  AppDatabase db,
  Map<String, Object?> payload,
  String commandId,
) async {
  final service = Elv5CctvRecorderMutationService(
    unitOfWork: DriftElv5CctvRecorderWriteUnitOfWork(
      db,
      originDeviceId: 'f2-cctv',
    ),
    originDeviceId: 'f2-cctv',
    now: Elv5F2ProductionLifecycle.now,
  );
  final preview = await service.preview(
    projectId: 'p',
    designRevisionId: 'd',
    payload: payload,
  );
  await service.execute(
    Elv5WireCommandEnvelope(
      operation: 'REPLACE_RECORDER_ASSIGNMENTS',
      projectId: 'p',
      designRevisionId: 'd',
      commandId: commandId,
      expectedDesignRowRevision: preview.designRowRevision,
      expectedRows: preview.expectedRows,
      reviewedImpactFingerprint: preview.reviewedImpactFingerprint,
      payload: payload,
    ),
  );
}

Map<String, Object?> f2CctvStreams({
  int expected = 8000000,
  int peak = 12000000,
}) => {
  'cameraId': 'cam-1',
  'streams': [
    {
      'encodedStreamId': 'stream-main',
      'codecProfileRef': 'H264',
      'expectedBitrateBps': '$expected',
      'peakBitrateBps': '$peak',
      'expectedRateEvidence': _rateEvidence('CONFIGURED_TARGET'),
      'peakRateEvidence': _rateEvidence('GUARANTEED_POINTWISE_UPPER_BOUND'),
    },
  ],
  'subscriptions': [
    {
      'subscriptionId': 'recording-feed',
      'encodedStreamId': 'stream-main',
      'receiverId': 'rec-1',
      'deliveryMode': 'UNICAST',
      'orderedNetworkEdgeIds': ['edge-1'],
      'multicastGroupId': null,
      'multicastTree': null,
    },
  ],
  'transportOverheadModelRef': null,
};
Map<String, Object?> _rateEvidence(String kind) => {
  'kind': kind,
  'averagingWindowMs': null,
  'rateBoundary': 'PAYLOAD',
  'evidenceRef': {
    'sourceKind': 'EXPLICIT_TEST_VECTOR',
    'sourceId': 'rate-v1',
    'contentHash': List.filled(64, 'a').join(),
  },
  'applicabilityHash': List.filled(64, 'b').join(),
};
Map<String, Object?> f2CctvRecorder() => {
  'recorderId': 'rec-1',
  'accountingBasis': 'ENCODED_STREAM',
  'assignments': [
    {
      'assignmentId': 'a1',
      'cameraId': 'cam-1',
      'encodedStreamId': 'stream-main',
      'licenseChannelId': 'ch-1',
      'storagePoolId': 'pool-1',
    },
  ],
};

Map<String, Object?> f2CctvRecordingPool() => {
  'poolId': 'pool-1',
  'horizon': {
    'startUtc': '2026-10-17T00:00:00.000Z',
    'endUtc': '2026-10-18T00:00:00.000Z',
  },
  'temporalPolicy': {
    'timeZoneId': 'UTC',
    'tzdbVersion': '2026a',
    'gapRule': 'SHIFT_FORWARD',
    'overlapRule': 'EARLIER_OFFSET',
  },
  'assignments': [
    {
      'encodedStreamId': 'stream-main',
      'copyRole': 'PRIMARY',
      'scheduleProfileId': 'always',
      'expectedBitrateBps': '8000000',
      'upperBoundBitrateBps': '12000000',
      'evidenceBasis': 'GUARANTEED_POINTWISE_UPPER_BOUND',
    },
  ],
  'scheduleSegments': [
    {
      'scheduleProfileId': 'always',
      'segmentId': 'always-1',
      'absoluteWindow': {
        'startUtc': '2026-10-17T00:00:00.000Z',
        'endUtc': '2026-10-18T00:00:00.000Z',
      },
      'recurrence': null,
    },
  ],
  'sizingBasis': 'GUARANTEED_UPPER_BOUND',
  'reserveMultiplier': '1.00',
  'redundancyModel': {
    'modelCode': 'SINGLE_EXPLICIT',
    'usableFraction': '1.00',
    'contentHash': List.filled(64, 'c').join(),
  },
  'policyRef': null,
};

Future<(String, String)> seedF2CctvCurrentDependencies(AppDatabase db) async {
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
  return (camera.inputFingerprint, pool.inputFingerprint);
}
