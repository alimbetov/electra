import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core_elv5.dart';

import '../../../application/elv5/cctv/elv5_cctv_recorder_persistence.dart';
import '../../../application/elv5/persistence/elv5_replacement_persistence.dart';
import '../../../application/elv5/persistence/elv5_runtime_persistence.dart';
import '../../../application/elv_write_unit_of_work.dart';
import '../../database/app_database.dart';
import '../../database/drift_raw_statement.dart';
import 'drift_elv5_replacement_write_unit_of_work.dart';

final class DriftElv5CctvRecorderWriteUnitOfWork
    implements Elv5CctvRecorderWriteUnitOfWork {
  const DriftElv5CctvRecorderWriteUnitOfWork(
    this.database, {
    required this.originDeviceId,
  });

  final AppDatabase database;
  final String originDeviceId;

  @override
  Future<T> run<T>(
    Future<T> Function(Elv5CctvRecorderWriteSession session) action,
  ) =>
      DriftElv5ReplacementWriteUnitOfWork(
        database,
        originDeviceId: originDeviceId,
      ).run((replacement) async {
        return action(
          _DriftElv5CctvRecorderWriteSession(
            replacement,
            recorder: _DriftElv5CctvRecorderMutationStore(
              database,
              originDeviceId: originDeviceId,
            ),
          ),
        );
      });
}

final class _DriftElv5CctvRecorderWriteSession
    implements Elv5CctvRecorderWriteSession {
  const _DriftElv5CctvRecorderWriteSession(
    this.replacement, {
    required this.recorder,
  });

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
  final Elv5CctvRecorderMutationStore recorder;
}

final class _DriftElv5CctvRecorderMutationStore
    implements Elv5CctvRecorderMutationStore {
  const _DriftElv5CctvRecorderMutationStore(
    this.database, {
    required this.originDeviceId,
  });

  static const _encoder = Elv5CanonicalJsonV1();

  final AppDatabase database;
  final String originDeviceId;

  @override
  Future<Elv5CctvRecorderSnapshot?> loadRecorder({
    required String projectId,
    required String designRevisionId,
    required String recorderId,
  }) async {
    final root = await database
        .customSelect(
          'SELECT id, revision, accounting_basis, recorder_definition_ref_json, '
          'recorder_definition_sha256 FROM recorder_capacity_bindings '
          'WHERE project_id = ? AND design_revision_id = ? AND recorder_id = ? '
          'AND deleted_at IS NULL',
          variables: [
            Variable.withString(projectId),
            Variable.withString(designRevisionId),
            Variable.withString(recorderId),
          ],
        )
        .getSingleOrNull();
    if (root == null) return null;
    final bindingId = root.read<String>('id');
    final rows = await database
        .customSelect(
          'SELECT assignment_id, camera_id, encoded_stream_id, license_channel_id, '
          'storage_pool_id FROM recorder_assignments WHERE project_id = ? '
          'AND design_revision_id = ? AND binding_id = ? ORDER BY ordinal, assignment_id',
          variables: [
            Variable.withString(projectId),
            Variable.withString(designRevisionId),
            Variable.withString(bindingId),
          ],
        )
        .get();
    return Elv5CctvRecorderSnapshot(
      aggregateId: bindingId,
      recorderId: recorderId,
      revision: root.read<int>('revision'),
      payload: {
        'recorderId': recorderId,
        'accountingBasis': root.read<String>('accounting_basis'),
        'recorderDefinitionRef': jsonDecode(
          root.read<String>('recorder_definition_ref_json'),
        ),
        'recorderDefinitionSha256': root.read<String>(
          'recorder_definition_sha256',
        ),
        'assignments': [
          for (final row in rows)
            {
              'assignmentId': row.read<String>('assignment_id'),
              'cameraId': row.read<String>('camera_id'),
              'encodedStreamId': row.read<String>('encoded_stream_id'),
              'licenseChannelId': row.read<String>('license_channel_id'),
              'storagePoolId': row.read<String>('storage_pool_id'),
            },
        ],
      },
    );
  }

  @override
  Future<void> replaceRecorder({
    required String projectId,
    required String designRevisionId,
    required String recorderId,
    required String bindingId,
    required int? expectedRootRevision,
    required Map<String, Object?> payload,
    required DateTime updatedAtUtc,
  }) async {
    final component = await database
        .customSelect(
          'SELECT definition_id, definition_version FROM component_instances '
          'WHERE id = ? AND deleted_at IS NULL',
          variables: [Variable.withString(recorderId)],
        )
        .getSingleOrNull();
    if (component == null) {
      throw StateError('ELV5_RECORDER_COMPONENT_NOT_FOUND');
    }
    final definitionRef = {
      'componentId': recorderId,
      'definitionId': component.read<String>('definition_id'),
      'definitionVersion': component.read<int>('definition_version'),
    };
    final definitionRefJson = _canonicalJson(definitionRef);
    final definitionSha = _encoder.sha256(definitionRef);

    if (expectedRootRevision == null) {
      await runRawStatement(
        database,
        'INSERT INTO recorder_capacity_bindings '
        '(project_id, design_revision_id, id, revision, created_at, updated_at, '
        'deleted_at, origin_device_id, recorder_id, accounting_basis, '
        'recorder_definition_ref_json, recorder_definition_sha256) '
        'VALUES (?, ?, ?, 1, ?, ?, NULL, ?, ?, ?, ?, ?)',
        [
          Variable.withString(projectId),
          Variable.withString(designRevisionId),
          Variable.withString(bindingId),
          Variable<DateTime>(updatedAtUtc.toUtc()),
          Variable<DateTime>(updatedAtUtc.toUtc()),
          Variable.withString(originDeviceId),
          Variable.withString(recorderId),
          Variable.withString(payload['accountingBasis']! as String),
          Variable.withString(definitionRefJson),
          Variable.withString(definitionSha),
        ],
      );
    } else {
      final changed = await database.customUpdate(
        'UPDATE recorder_capacity_bindings SET revision = revision + 1, '
        'updated_at = ?, origin_device_id = ?, accounting_basis = ?, '
        'recorder_definition_ref_json = ?, recorder_definition_sha256 = ? '
        'WHERE project_id = ? AND design_revision_id = ? AND id = ? '
        'AND recorder_id = ? AND revision = ? AND deleted_at IS NULL',
        variables: [
          Variable<DateTime>(updatedAtUtc.toUtc()),
          Variable.withString(originDeviceId),
          Variable.withString(payload['accountingBasis']! as String),
          Variable.withString(definitionRefJson),
          Variable.withString(definitionSha),
          Variable.withString(projectId),
          Variable.withString(designRevisionId),
          Variable.withString(bindingId),
          Variable.withString(recorderId),
          Variable<int>(expectedRootRevision),
        ],
      );
      if (changed != 1) throw StateError('ELV5_RECORDER_ROOT_CAS_CONFLICT');
    }

    await database.customUpdate(
      'DELETE FROM recorder_assignments WHERE project_id = ? '
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
      await runRawStatement(
        database,
        'INSERT INTO recorder_assignments '
        '(project_id, design_revision_id, binding_id, assignment_id, camera_id, '
        'encoded_stream_id, license_channel_id, storage_pool_id, ordinal) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          Variable.withString(projectId),
          Variable.withString(designRevisionId),
          Variable.withString(bindingId),
          Variable.withString(row['assignmentId']! as String),
          Variable.withString(row['cameraId']! as String),
          Variable.withString(row['encodedStreamId']! as String),
          Variable.withString(row['licenseChannelId']! as String),
          Variable.withString(row['storagePoolId']! as String),
          Variable<int>(i),
        ],
      );
    }
  }

  String _canonicalJson(Object? value) =>
      utf8.decode(_encoder.encode(value), allowMalformed: false);
}
