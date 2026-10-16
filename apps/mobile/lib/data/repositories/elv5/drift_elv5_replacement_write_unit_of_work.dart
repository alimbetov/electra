import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../application/elv5/persistence/elv5_replacement_persistence.dart';
import '../../../application/elv5/persistence/elv5_runtime_persistence.dart';
import '../../../application/elv_write_unit_of_work.dart';
import '../../database/app_database.dart';
import '../../database/drift_raw_statement.dart';
import 'drift_elv5_runtime_write_unit_of_work.dart';

final class DriftElv5ReplacementWriteUnitOfWork
    implements Elv5ReplacementWriteUnitOfWork {
  const DriftElv5ReplacementWriteUnitOfWork(
    this.database, {
    required this.originDeviceId,
  });

  final AppDatabase database;
  final String originDeviceId;

  @override
  Future<T> run<T>(
    Future<T> Function(Elv5ReplacementWriteSession session) action,
  ) => DriftElv5RuntimeWriteUnitOfWork(
    database,
    originDeviceId: originDeviceId,
  ).run((runtime) async {
    final session = _DriftElv5ReplacementWriteSession(
      runtime,
      revisions: _DriftElv5RevisionMutationStore(
        database,
        originDeviceId: originDeviceId,
      ),
      history: _DriftElv5RevisionHistoryStore(
        database,
        originDeviceId: originDeviceId,
      ),
    );
    return action(session);
  });
}

final class _DriftElv5ReplacementWriteSession
    implements Elv5ReplacementWriteSession {
  const _DriftElv5ReplacementWriteSession(
    this.runtime, {
    required this.revisions,
    required this.history,
  });

  final Elv5RuntimeWriteSession runtime;

  @override
  ElvCommandLedgerStore get commandLedger => runtime.commandLedger;

  @override
  Elv5EvaluationStore get evaluations => runtime.evaluations;

  @override
  Elv5PointerStore get pointers => runtime.pointers;

  @override
  Elv5DependencyStore get dependencies => runtime.dependencies;

  @override
  final Elv5RevisionMutationStore revisions;

  @override
  final Elv5RevisionHistoryStore history;
}

final class _DriftElv5RevisionMutationStore
    implements Elv5RevisionMutationStore {
  const _DriftElv5RevisionMutationStore(
    this.database, {
    required this.originDeviceId,
  });

  final AppDatabase database;
  final String originDeviceId;

  @override
  Future<Elv5RevisionSnapshot?> load({
    required String projectId,
    required String designRevisionId,
  }) async {
    final row = await database
        .customSelect(
          'SELECT project_id, id, state, revision FROM project_design_revisions '
          'WHERE project_id = ? AND id = ? AND deleted_at IS NULL',
          variables: [
            Variable.withString(projectId),
            Variable.withString(designRevisionId),
          ],
        )
        .getSingleOrNull();
    if (row == null) return null;
    return Elv5RevisionSnapshot(
      projectId: row.read<String>('project_id'),
      designRevisionId: row.read<String>('id'),
      state: row.read<String>('state'),
      rowRevision: row.read<int>('revision'),
    );
  }

  @override
  Future<bool> compareAndBump({
    required String projectId,
    required String designRevisionId,
    required int expectedRevision,
    required DateTime updatedAtUtc,
  }) async {
    final changed = await database.customUpdate(
      'UPDATE project_design_revisions '
      'SET revision = revision + 1, updated_at = ?, origin_device_id = ? '
      'WHERE project_id = ? AND id = ? AND state = ? AND revision = ? '
      'AND deleted_at IS NULL',
      variables: [
        Variable<DateTime>(updatedAtUtc.toUtc()),
        Variable.withString(originDeviceId),
        Variable.withString(projectId),
        Variable.withString(designRevisionId),
        Variable.withString('WORKING'),
        Variable<int>(expectedRevision),
      ],
    );
    return changed == 1;
  }
}

final class _DriftElv5RevisionHistoryStore
    implements Elv5RevisionHistoryStore {
  const _DriftElv5RevisionHistoryStore(
    this.database, {
    required this.originDeviceId,
  });

  final AppDatabase database;
  final String originDeviceId;

  @override
  Future<void> appendOriginal(Elv5HistoryAppend append) async {
    final cursor = await database
        .customSelect(
          'SELECT generation, head_sequence, branch_id '
          'FROM elv_revision_command_history_cursors '
          'WHERE project_id = ? AND design_revision_id = ?',
          variables: [
            Variable.withString(append.projectId),
            Variable.withString(append.designRevisionId),
          ],
        )
        .getSingleOrNull();
    final currentGeneration = cursor?.read<int>('generation') ?? 0;
    final currentHead = cursor?.read<int>('head_sequence') ?? 0;
    final branchId = append.originalCommandId;

    if (cursor != null) {
      await database.customUpdate(
        'UPDATE elv_revision_command_history_operations '
        "SET state = 'REDO_ABANDONED', updated_at = ?, origin_device_id = ? "
        'WHERE project_id = ? AND design_revision_id = ? AND sequence > ? '
        "AND state = 'UNDONE'",
        variables: [
          Variable<DateTime>(append.createdAtUtc.toUtc()),
          Variable.withString(originDeviceId),
          Variable.withString(append.projectId),
          Variable.withString(append.designRevisionId),
          Variable<int>(currentHead),
        ],
      );
    }

    final maxRow = await database.customSelect(
      'SELECT COALESCE(MAX(sequence), 0) AS max_sequence '
      'FROM elv_revision_command_history_operations '
      'WHERE project_id = ? AND design_revision_id = ?',
      variables: [
        Variable.withString(append.projectId),
        Variable.withString(append.designRevisionId),
      ],
    ).getSingle();
    final sequence = maxRow.read<int>('max_sequence') + 1;
    final nextGeneration = currentGeneration + 1;
    final beforeRef = _evidenceRef(append, 'BEFORE');
    final afterRef = _evidenceRef(append, 'AFTER');

    await _insertEvidence(beforeRef, append, append.before);
    await _insertEvidence(afterRef, append, append.after);

    await runRawStatement(
      database,
      'INSERT INTO elv_revision_command_history_operations '
      '(project_id, design_revision_id, sequence, original_command_id, state, '
      'forward_command_type, forward_command_schema, '
      'forward_canonical_payload_json, forward_payload_sha256, '
      'inverse_command_type, inverse_command_schema, '
      'inverse_canonical_payload_json, inverse_payload_sha256, '
      'before_aggregate_evidence_ref, before_aggregate_hash, '
      'after_aggregate_evidence_ref, after_aggregate_hash, cursor_generation, '
      'affected_ids_json, created_at, updated_at, origin_device_id) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        Variable.withString(append.projectId),
        Variable.withString(append.designRevisionId),
        Variable<int>(sequence),
        Variable.withString(append.originalCommandId),
        Variable.withString('APPLIED'),
        Variable.withString(append.forwardCommandType),
        Variable.withString(append.forwardCommandSchema),
        Variable.withString(append.forwardCanonicalPayloadJson),
        Variable.withString(append.forwardPayloadSha256),
        Variable.withString(append.inverseCommandType),
        Variable.withString(append.inverseCommandSchema),
        Variable.withString(append.inverseCanonicalPayloadJson),
        Variable.withString(append.inversePayloadSha256),
        Variable.withString(beforeRef),
        Variable.withString(append.before.payloadSha256),
        Variable.withString(afterRef),
        Variable.withString(append.after.payloadSha256),
        Variable<int>(nextGeneration),
        Variable.withString(jsonEncode(append.affectedIds)),
        Variable<DateTime>(append.createdAtUtc.toUtc()),
        Variable<DateTime>(append.createdAtUtc.toUtc()),
        Variable.withString(originDeviceId),
      ],
    );

    await runRawStatement(
      database,
      'INSERT INTO elv_revision_command_history_executions '
      '(project_id, design_revision_id, history_sequence, execution_command_id, '
      'execution_kind, command_type, command_schema, canonical_payload_json, '
      'payload_sha256, created_at, origin_device_id) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        Variable.withString(append.projectId),
        Variable.withString(append.designRevisionId),
        Variable<int>(sequence),
        Variable.withString(append.originalCommandId),
        Variable.withString('ORIGINAL'),
        Variable.withString(append.forwardCommandType),
        Variable.withString(append.forwardCommandSchema),
        Variable.withString(append.forwardCanonicalPayloadJson),
        Variable.withString(append.forwardPayloadSha256),
        Variable<DateTime>(append.createdAtUtc.toUtc()),
        Variable.withString(originDeviceId),
      ],
    );

    if (cursor == null) {
      await runRawStatement(
        database,
        'INSERT INTO elv_revision_command_history_cursors '
        '(project_id, design_revision_id, generation, head_sequence, branch_id, '
        'created_at, updated_at, origin_device_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [
          Variable.withString(append.projectId),
          Variable.withString(append.designRevisionId),
          Variable<int>(nextGeneration),
          Variable<int>(sequence),
          Variable.withString(branchId),
          Variable<DateTime>(append.createdAtUtc.toUtc()),
          Variable<DateTime>(append.createdAtUtc.toUtc()),
          Variable.withString(originDeviceId),
        ],
      );
      return;
    }

    final moved = await database.customUpdate(
      'UPDATE elv_revision_command_history_cursors '
      'SET generation = ?, head_sequence = ?, branch_id = ?, updated_at = ?, '
      'origin_device_id = ? WHERE project_id = ? AND design_revision_id = ? '
      'AND generation = ?',
      variables: [
        Variable<int>(nextGeneration),
        Variable<int>(sequence),
        Variable.withString(branchId),
        Variable<DateTime>(append.createdAtUtc.toUtc()),
        Variable.withString(originDeviceId),
        Variable.withString(append.projectId),
        Variable.withString(append.designRevisionId),
        Variable<int>(currentGeneration),
      ],
    );
    if (moved != 1) {
      throw StateError('ELV5_HISTORY_CURSOR_CAS_CONFLICT');
    }
  }

  Future<void> _insertEvidence(
    String evidenceRef,
    Elv5HistoryAppend append,
    Elv5AggregateEvidenceDraft evidence,
  ) => runRawStatement(
    database,
    'INSERT INTO elv_revision_aggregate_evidence_records '
    '(evidence_ref, project_id, design_revision_id, aggregate_kind, aggregate_id, '
    'canonical_payload_json, payload_sha256, created_at, origin_device_id) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
    [
      Variable.withString(evidenceRef),
      Variable.withString(append.projectId),
      Variable.withString(append.designRevisionId),
      Variable.withString(evidence.aggregateKind),
      Variable.withString(evidence.aggregateId),
      Variable.withString(evidence.canonicalPayloadJson),
      Variable.withString(evidence.payloadSha256),
      Variable<DateTime>(append.createdAtUtc.toUtc()),
      Variable.withString(originDeviceId),
    ],
  );

  String _evidenceRef(Elv5HistoryAppend append, String side) =>
      'ELV5:${append.projectId}:${append.designRevisionId}:'
      '${append.originalCommandId}:$side';
}
