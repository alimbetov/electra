import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core_elv5.dart';

import '../../../application/elv5/cctv/elv5_cctv_persistence.dart';
import '../../../application/elv5/persistence/elv5_replacement_persistence.dart';
import '../../../application/elv5/persistence/elv5_runtime_persistence.dart';
import '../../../application/elv_write_unit_of_work.dart';
import '../../database/app_database.dart';
import '../../database/drift_raw_statement.dart';
import 'drift_elv5_replacement_write_unit_of_work.dart';

final class DriftElv5CctvWriteUnitOfWork implements Elv5CctvWriteUnitOfWork {
  const DriftElv5CctvWriteUnitOfWork(
    this.database, {
    required this.originDeviceId,
  });

  final AppDatabase database;
  final String originDeviceId;

  @override
  Future<T> run<T>(Future<T> Function(Elv5CctvWriteSession session) action) =>
      DriftElv5ReplacementWriteUnitOfWork(
        database,
        originDeviceId: originDeviceId,
      ).run((replacement) async {
        final session = _DriftElv5CctvWriteSession(
          replacement,
          cctv: _DriftElv5CctvMutationStore(
            database,
            originDeviceId: originDeviceId,
          ),
        );
        return action(session);
      });
}

final class _DriftElv5CctvWriteSession implements Elv5CctvWriteSession {
  const _DriftElv5CctvWriteSession(this.replacement, {required this.cctv});

  final Elv5ReplacementWriteSession replacement;

  @override
  ElvCommandLedgerStore get commandLedger => replacement.commandLedger;

  @override
  Elv5EvaluationStore get evaluations => replacement.evaluations;

  @override
  Elv5PointerStore get pointers => replacement.pointers;

  @override
  Elv5DependencyStore get dependencies => replacement.dependencies;

  @override
  Elv5RevisionMutationStore get revisions => replacement.revisions;

  @override
  Elv5RevisionHistoryStore get history => replacement.history;

  @override
  final Elv5CctvMutationStore cctv;
}

final class _DriftElv5CctvMutationStore implements Elv5CctvMutationStore {
  const _DriftElv5CctvMutationStore(
    this.database, {
    required this.originDeviceId,
  });

  static const _encoder = Elv5CanonicalJsonV1();

  final AppDatabase database;
  final String originDeviceId;

  @override
  Future<Elv5CctvAggregateSnapshot?> loadCameraStreams({
    required String projectId,
    required String designRevisionId,
    required String cameraId,
  }) async {
    final root = await database
        .customSelect(
          'SELECT id, revision, transport_overhead_model_ref_json '
          'FROM camera_stream_set_bindings WHERE project_id = ? '
          'AND design_revision_id = ? AND camera_id = ? AND deleted_at IS NULL',
          variables: [
            Variable.withString(projectId),
            Variable.withString(designRevisionId),
            Variable.withString(cameraId),
          ],
        )
        .getSingleOrNull();
    if (root == null) return null;
    final bindingId = root.read<String>('id');
    final streams = await database
        .customSelect(
          'SELECT stream_profile_json FROM camera_stream_bindings '
          'WHERE project_id = ? AND design_revision_id = ? AND binding_id = ? '
          'ORDER BY ordinal, encoded_stream_id',
          variables: [
            Variable.withString(projectId),
            Variable.withString(designRevisionId),
            Variable.withString(bindingId),
          ],
        )
        .get();
    final subscriptions = await database
        .customSelect(
          'SELECT subscription_id, encoded_stream_id, receiver_id, delivery_mode, '
          'ordered_network_edge_ids_json, multicast_group_id, multicast_tree_json '
          'FROM camera_stream_subscriptions WHERE project_id = ? '
          'AND design_revision_id = ? AND binding_id = ? ORDER BY ordinal, subscription_id',
          variables: [
            Variable.withString(projectId),
            Variable.withString(designRevisionId),
            Variable.withString(bindingId),
          ],
        )
        .get();
    final overheadJson = root.readNullable<String>(
      'transport_overhead_model_ref_json',
    );
    return Elv5CctvAggregateSnapshot(
      aggregateKind: 'CCTV_CAMERA_STREAMS',
      aggregateId: bindingId,
      subjectId: cameraId,
      revision: root.read<int>('revision'),
      payload: {
        'cameraId': cameraId,
        'streams': [
          for (final row in streams)
            _jsonObject(row.read<String>('stream_profile_json')),
        ],
        'subscriptions': [
          for (final row in subscriptions)
            {
              'subscriptionId': row.read<String>('subscription_id'),
              'encodedStreamId': row.read<String>('encoded_stream_id'),
              'receiverId': row.read<String>('receiver_id'),
              'deliveryMode': row.read<String>('delivery_mode'),
              'orderedNetworkEdgeIds': jsonDecode(
                row.read<String>('ordered_network_edge_ids_json'),
              ),
              'multicastGroupId': row.readNullable<String>(
                'multicast_group_id',
              ),
              'multicastTree':
                  row.readNullable<String>('multicast_tree_json') == null
                  ? null
                  : jsonDecode(row.read<String>('multicast_tree_json')),
            },
        ],
        'transportOverheadModelRef': overheadJson == null
            ? null
            : jsonDecode(overheadJson),
      },
    );
  }

  @override
  Future<void> replaceCameraStreams({
    required String projectId,
    required String designRevisionId,
    required String cameraId,
    required String bindingId,
    required int? expectedRootRevision,
    required Map<String, Object?> payload,
    required DateTime updatedAtUtc,
  }) async {
    final overhead = payload['transportOverheadModelRef'];
    final overheadJson = overhead == null ? null : _canonicalJson(overhead);
    final overheadSha = overhead == null ? null : _encoder.sha256(overhead);
    if (expectedRootRevision == null) {
      await runRawStatement(
        database,
        'INSERT INTO camera_stream_set_bindings '
        '(project_id, design_revision_id, id, revision, created_at, updated_at, '
        'deleted_at, origin_device_id, camera_id, '
        'transport_overhead_model_ref_json, transport_overhead_model_sha256) '
        'VALUES (?, ?, ?, 1, ?, ?, NULL, ?, ?, ?, ?)',
        [
          Variable.withString(projectId),
          Variable.withString(designRevisionId),
          Variable.withString(bindingId),
          Variable<DateTime>(updatedAtUtc.toUtc()),
          Variable<DateTime>(updatedAtUtc.toUtc()),
          Variable.withString(originDeviceId),
          Variable.withString(cameraId),
          Variable<String>(overheadJson),
          Variable<String>(overheadSha),
        ],
      );
    } else {
      final changed = await database.customUpdate(
        'UPDATE camera_stream_set_bindings SET revision = revision + 1, '
        'updated_at = ?, origin_device_id = ?, '
        'transport_overhead_model_ref_json = ?, transport_overhead_model_sha256 = ? '
        'WHERE project_id = ? AND design_revision_id = ? AND id = ? '
        'AND camera_id = ? AND revision = ? AND deleted_at IS NULL',
        variables: [
          Variable<DateTime>(updatedAtUtc.toUtc()),
          Variable.withString(originDeviceId),
          Variable<String>(overheadJson),
          Variable<String>(overheadSha),
          Variable.withString(projectId),
          Variable.withString(designRevisionId),
          Variable.withString(bindingId),
          Variable.withString(cameraId),
          Variable<int>(expectedRootRevision),
        ],
      );
      if (changed != 1) throw StateError('ELV5_CCTV_STREAM_ROOT_CAS_CONFLICT');
    }

    await database.customUpdate(
      'DELETE FROM camera_stream_subscriptions WHERE project_id = ? '
      'AND design_revision_id = ? AND binding_id = ?',
      variables: [
        Variable.withString(projectId),
        Variable.withString(designRevisionId),
        Variable.withString(bindingId),
      ],
    );
    await database.customUpdate(
      'DELETE FROM camera_stream_bindings WHERE project_id = ? '
      'AND design_revision_id = ? AND binding_id = ?',
      variables: [
        Variable.withString(projectId),
        Variable.withString(designRevisionId),
        Variable.withString(bindingId),
      ],
    );

    final streams = (payload['streams']! as List).cast<Map>();
    for (var i = 0; i < streams.length; i++) {
      final stream = Map<String, Object?>.from(streams[i]);
      final canonical = _canonicalJson(stream);
      await runRawStatement(
        database,
        'INSERT INTO camera_stream_bindings '
        '(project_id, design_revision_id, binding_id, camera_id, encoded_stream_id, '
        'stream_profile_json, stream_profile_sha256, ordinal) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [
          Variable.withString(projectId),
          Variable.withString(designRevisionId),
          Variable.withString(bindingId),
          Variable.withString(cameraId),
          Variable.withString(stream['encodedStreamId']! as String),
          Variable.withString(canonical),
          Variable.withString(_encoder.sha256(stream)),
          Variable<int>(i),
        ],
      );
    }

    final subscriptions = (payload['subscriptions']! as List).cast<Map>();
    for (var i = 0; i < subscriptions.length; i++) {
      final subscription = Map<String, Object?>.from(subscriptions[i]);
      final tree = subscription['multicastTree'];
      await runRawStatement(
        database,
        'INSERT INTO camera_stream_subscriptions '
        '(project_id, design_revision_id, binding_id, camera_id, subscription_id, '
        'encoded_stream_id, receiver_id, delivery_mode, '
        'ordered_network_edge_ids_json, multicast_group_id, multicast_tree_json, '
        'multicast_tree_sha256, ordinal) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          Variable.withString(projectId),
          Variable.withString(designRevisionId),
          Variable.withString(bindingId),
          Variable.withString(cameraId),
          Variable.withString(subscription['subscriptionId']! as String),
          Variable.withString(subscription['encodedStreamId']! as String),
          Variable.withString(subscription['receiverId']! as String),
          Variable.withString(subscription['deliveryMode']! as String),
          Variable.withString(
            _canonicalJson(subscription['orderedNetworkEdgeIds']),
          ),
          Variable<String>(subscription['multicastGroupId'] as String?),
          Variable<String>(tree == null ? null : _canonicalJson(tree)),
          Variable<String>(tree == null ? null : _encoder.sha256(tree)),
          Variable<int>(i),
        ],
      );
    }
  }

  @override
  Future<Elv5CctvAggregateSnapshot?> loadRecordingPool({
    required String projectId,
    required String designRevisionId,
    required String poolId,
  }) async {
    final root = await database
        .customSelect(
          'SELECT id, revision, horizon_json, temporal_policy_json, sizing_basis, '
          'reserve_multiplier_json, redundancy_model_json, policy_ref_json '
          'FROM recording_pool_bindings WHERE project_id = ? '
          'AND design_revision_id = ? AND pool_id = ? AND deleted_at IS NULL',
          variables: [
            Variable.withString(projectId),
            Variable.withString(designRevisionId),
            Variable.withString(poolId),
          ],
        )
        .getSingleOrNull();
    if (root == null) return null;
    final bindingId = root.read<String>('id');
    final assignments = await database
        .customSelect(
          'SELECT encoded_stream_id, copy_role, schedule_profile_id, bitrate_value_json, '
          'bitrate_evidence_json FROM recording_assignments WHERE project_id = ? '
          'AND design_revision_id = ? AND binding_id = ? ORDER BY ordinal, encoded_stream_id, copy_role',
          variables: [
            Variable.withString(projectId),
            Variable.withString(designRevisionId),
            Variable.withString(bindingId),
          ],
        )
        .get();
    final segments = await database
        .customSelect(
          'SELECT schedule_profile_id, segment_id, schedule_json FROM recording_schedule_segments '
          'WHERE project_id = ? AND design_revision_id = ? AND binding_id = ? '
          'ORDER BY ordinal, schedule_profile_id, segment_id',
          variables: [
            Variable.withString(projectId),
            Variable.withString(designRevisionId),
            Variable.withString(bindingId),
          ],
        )
        .get();
    return Elv5CctvAggregateSnapshot(
      aggregateKind: 'CCTV_RECORDING_POOL',
      aggregateId: bindingId,
      subjectId: poolId,
      revision: root.read<int>('revision'),
      payload: {
        'poolId': poolId,
        'horizon': jsonDecode(root.read<String>('horizon_json')),
        'temporalPolicy': jsonDecode(root.read<String>('temporal_policy_json')),
        'assignments': [
          for (final row in assignments)
            {
              'encodedStreamId': row.read<String>('encoded_stream_id'),
              'copyRole': row.read<String>('copy_role'),
              'scheduleProfileId': row.read<String>('schedule_profile_id'),
              ..._jsonObject(row.read<String>('bitrate_value_json')),
              ..._jsonObject(row.read<String>('bitrate_evidence_json')),
            },
        ],
        'scheduleSegments': [
          for (final row in segments)
            {
              'scheduleProfileId': row.read<String>('schedule_profile_id'),
              'segmentId': row.read<String>('segment_id'),
              ..._jsonObject(row.read<String>('schedule_json')),
            },
        ],
        'sizingBasis': root.read<String>('sizing_basis'),
        'reserveMultiplier': jsonDecode(
          root.read<String>('reserve_multiplier_json'),
        ),
        'redundancyModel':
            root.readNullable<String>('redundancy_model_json') == null
            ? null
            : jsonDecode(root.read<String>('redundancy_model_json')),
        'policyRef': root.readNullable<String>('policy_ref_json') == null
            ? null
            : jsonDecode(root.read<String>('policy_ref_json')),
      },
    );
  }

  @override
  Future<void> replaceRecordingPool({
    required String projectId,
    required String designRevisionId,
    required String poolId,
    required String bindingId,
    required int? expectedRootRevision,
    required Map<String, Object?> payload,
    required DateTime updatedAtUtc,
  }) async {
    final redundancy = payload['redundancyModel'];
    final policy = payload['policyRef'];
    if (expectedRootRevision == null) {
      await runRawStatement(
        database,
        'INSERT INTO recording_pool_bindings '
        '(project_id, design_revision_id, id, revision, created_at, updated_at, '
        'deleted_at, origin_device_id, pool_id, horizon_json, temporal_policy_json, '
        'sizing_basis, reserve_multiplier_json, redundancy_model_json, policy_ref_json) '
        'VALUES (?, ?, ?, 1, ?, ?, NULL, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          Variable.withString(projectId),
          Variable.withString(designRevisionId),
          Variable.withString(bindingId),
          Variable<DateTime>(updatedAtUtc.toUtc()),
          Variable<DateTime>(updatedAtUtc.toUtc()),
          Variable.withString(originDeviceId),
          Variable.withString(poolId),
          Variable.withString(_canonicalJson(payload['horizon'])),
          Variable.withString(_canonicalJson(payload['temporalPolicy'])),
          Variable.withString(payload['sizingBasis']! as String),
          Variable.withString(_canonicalJson(payload['reserveMultiplier'])),
          Variable<String>(
            redundancy == null ? null : _canonicalJson(redundancy),
          ),
          Variable<String>(policy == null ? null : _canonicalJson(policy)),
        ],
      );
    } else {
      final changed = await database.customUpdate(
        'UPDATE recording_pool_bindings SET revision = revision + 1, updated_at = ?, '
        'origin_device_id = ?, horizon_json = ?, temporal_policy_json = ?, '
        'sizing_basis = ?, reserve_multiplier_json = ?, redundancy_model_json = ?, '
        'policy_ref_json = ? WHERE project_id = ? AND design_revision_id = ? '
        'AND id = ? AND pool_id = ? AND revision = ? AND deleted_at IS NULL',
        variables: [
          Variable<DateTime>(updatedAtUtc.toUtc()),
          Variable.withString(originDeviceId),
          Variable.withString(_canonicalJson(payload['horizon'])),
          Variable.withString(_canonicalJson(payload['temporalPolicy'])),
          Variable.withString(payload['sizingBasis']! as String),
          Variable.withString(_canonicalJson(payload['reserveMultiplier'])),
          Variable<String>(
            redundancy == null ? null : _canonicalJson(redundancy),
          ),
          Variable<String>(policy == null ? null : _canonicalJson(policy)),
          Variable.withString(projectId),
          Variable.withString(designRevisionId),
          Variable.withString(bindingId),
          Variable.withString(poolId),
          Variable<int>(expectedRootRevision),
        ],
      );
      if (changed != 1) throw StateError('ELV5_RECORDING_ROOT_CAS_CONFLICT');
    }

    await database.customUpdate(
      'DELETE FROM recording_assignments WHERE project_id = ? '
      'AND design_revision_id = ? AND binding_id = ?',
      variables: [
        Variable.withString(projectId),
        Variable.withString(designRevisionId),
        Variable.withString(bindingId),
      ],
    );
    await database.customUpdate(
      'DELETE FROM recording_schedule_segments WHERE project_id = ? '
      'AND design_revision_id = ? AND binding_id = ?',
      variables: [
        Variable.withString(projectId),
        Variable.withString(designRevisionId),
        Variable.withString(bindingId),
      ],
    );

    final assignments = (payload['assignments']! as List).cast<Map>();
    for (var i = 0; i < assignments.length; i++) {
      final row = Map<String, Object?>.from(assignments[i]);
      final bitrate = {
        'expectedBitrateBps': row['expectedBitrateBps'],
        'upperBoundBitrateBps': row['upperBoundBitrateBps'],
      };
      final evidence = {'evidenceBasis': row['evidenceBasis']};
      await runRawStatement(
        database,
        'INSERT INTO recording_assignments '
        '(project_id, design_revision_id, binding_id, encoded_stream_id, copy_role, '
        'schedule_profile_id, bitrate_value_json, bitrate_evidence_json, ordinal) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          Variable.withString(projectId),
          Variable.withString(designRevisionId),
          Variable.withString(bindingId),
          Variable.withString(row['encodedStreamId']! as String),
          Variable.withString(row['copyRole']! as String),
          Variable.withString(row['scheduleProfileId']! as String),
          Variable.withString(_canonicalJson(bitrate)),
          Variable.withString(_canonicalJson(evidence)),
          Variable<int>(i),
        ],
      );
    }

    final segments = (payload['scheduleSegments']! as List).cast<Map>();
    for (var i = 0; i < segments.length; i++) {
      final row = Map<String, Object?>.from(segments[i]);
      final schedule = {
        'absoluteWindow': row['absoluteWindow'],
        'recurrence': row['recurrence'],
      };
      await runRawStatement(
        database,
        'INSERT INTO recording_schedule_segments '
        '(project_id, design_revision_id, binding_id, schedule_profile_id, '
        'segment_id, ordinal, schedule_json, schedule_sha256) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [
          Variable.withString(projectId),
          Variable.withString(designRevisionId),
          Variable.withString(bindingId),
          Variable.withString(row['scheduleProfileId']! as String),
          Variable.withString(row['segmentId']! as String),
          Variable<int>(i),
          Variable.withString(_canonicalJson(schedule)),
          Variable.withString(_encoder.sha256(schedule)),
        ],
      );
    }
  }

  Map<String, Object?> _jsonObject(String value) =>
      Map<String, Object?>.from(jsonDecode(value) as Map);

  String _canonicalJson(Object? value) =>
      utf8.decode(_encoder.encode(value), allowMalformed: false);
}
