import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core.dart';

import '../database/app_database.dart';

final class PowerRuntimeStorageException implements Exception {
  const PowerRuntimeStorageException(this.code, [this.details = const {}]);

  final String code;
  final Map<String, Object?> details;

  @override
  String toString() => 'PowerRuntimeStorageException($code, $details)';
}

final class PowerReplayResult {
  const PowerReplayResult({required this.resultJson, required this.replayed});

  final String resultJson;
  final bool replayed;
}

final class PowerPointerSnapshot {
  const PowerPointerSnapshot({
    required this.nodeKey,
    required this.state,
    required this.generation,
    required this.evaluationId,
    required this.evidenceSha256,
  });

  final PowerNodeKeyV2 nodeKey;
  final PowerPointerState state;
  final int generation;
  final String? evaluationId;
  final String? evidenceSha256;
}

final class DriftPowerRuntimeStore {
  DriftPowerRuntimeStore(
    this.database, {
    required this.originDeviceId,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  final AppDatabase database;
  final String originDeviceId;
  final DateTime Function() now;

  Future<PowerReplayResult> executeReplayable({
    required String projectId,
    required String designRevisionId,
    required String operationId,
    required String commandType,
    required String payloadSchema,
    required String commandFingerprint,
    required Future<String> Function() execute,
  }) =>
      database.transaction(() async {
        await _requireRevision(
          projectId: projectId,
          designRevisionId: designRevisionId,
          requireWorking: true,
        );
        final fingerprint = _sha256(commandFingerprint, 'commandFingerprint');
        final existing = await database.customSelect(
          'SELECT command_fingerprint, status, result_json '
          'FROM power_operation_records '
          'WHERE project_id = ? AND design_revision_id = ? AND operation_id = ?',
          variables: [
            Variable.withString(projectId),
            Variable.withString(designRevisionId),
            Variable.withString(operationId),
          ],
        ).getSingleOrNull();
        if (existing != null) {
          final storedFingerprint = existing.read<String>('command_fingerprint');
          if (storedFingerprint != fingerprint) {
            throw PowerRuntimeStorageException(
              'ELV4_OPERATION_FINGERPRINT_CONFLICT',
              {'operationId': operationId},
            );
          }
          final status = existing.read<String>('status');
          final resultJson = existing.readNullable<String>('result_json');
          if (status != 'COMMITTED' || resultJson == null) {
            throw PowerRuntimeStorageException(
              'ELV4_OPERATION_INCOMPLETE_REPLAY',
              {'operationId': operationId, 'status': status},
            );
          }
          return PowerReplayResult(resultJson: resultJson, replayed: true);
        }

        final timestamp = now().toUtc();
        await database.customStatement(
          'INSERT INTO power_operation_records '
          '(project_id, design_revision_id, operation_id, command_type, '
          'payload_schema, command_fingerprint, status, result_json, created_at, '
          'committed_at, origin_device_id) '
          "VALUES (?, ?, ?, ?, ?, ?, 'PENDING', NULL, ?, NULL, ?)",
          [
            Variable.withString(projectId),
            Variable.withString(designRevisionId),
            Variable.withString(operationId),
            Variable.withString(commandType.trim()),
            Variable.withString(payloadSchema.trim()),
            Variable.withString(fingerprint),
            Variable<DateTime>(timestamp),
            Variable.withString(originDeviceId),
          ],
        );
        final resultJson = await execute();
        final updated = await database.customUpdate(
          'UPDATE power_operation_records '
          "SET status = 'COMMITTED', result_json = ?, committed_at = ? "
          'WHERE project_id = ? AND design_revision_id = ? AND operation_id = ? '
          "AND status = 'PENDING' AND command_fingerprint = ?",
          variables: [
            Variable.withString(resultJson),
            Variable<DateTime>(now().toUtc()),
            Variable.withString(projectId),
            Variable.withString(designRevisionId),
            Variable.withString(operationId),
            Variable.withString(fingerprint),
          ],
        );
        if (updated != 1) {
          throw PowerRuntimeStorageException(
            'ELV4_OPERATION_COMMIT_CAS_FAILED',
            {'operationId': operationId},
          );
        }
        return PowerReplayResult(resultJson: resultJson, replayed: false);
      });

  Future<void> appendEvaluation({
    required String projectId,
    required String designRevisionId,
    required PowerEvaluationEvidence evidence,
  }) =>
      database.transaction(() async {
        await _requireRevision(
          projectId: projectId,
          designRevisionId: designRevisionId,
          requireWorking: true,
        );
        if (evidence.nodeKey.revisionId != designRevisionId) {
          throw PowerRuntimeStorageException(
            'ELV4_EVALUATION_REVISION_MISMATCH',
            {
              'expectedRevisionId': designRevisionId,
              'nodeRevisionId': evidence.nodeKey.revisionId,
            },
          );
        }
        final nodeSha = evidence.nodeKey.sha256;
        final existing = await database.customSelect(
          'SELECT evidence_sha256 FROM power_evaluation_records '
          'WHERE design_revision_id = ? AND logical_node_key_sha256 = ? '
          'AND evaluation_id = ?',
          variables: [
            Variable.withString(designRevisionId),
            Variable.withString(nodeSha),
            Variable.withString(evidence.evaluationId),
          ],
        ).getSingleOrNull();
        if (existing != null) {
          if (existing.read<String>('evidence_sha256') == evidence.evidenceSha256) {
            return;
          }
          throw PowerRuntimeStorageException(
            'ELV4_EVALUATION_IDENTITY_CONFLICT',
            {'evaluationId': evidence.evaluationId},
          );
        }
        await database.customStatement(
          'INSERT INTO power_evaluation_records '
          '(project_id, design_revision_id, logical_node_key_json, '
          'logical_node_key_sha256, evaluation_id, scope_kind, scope_id, '
          'process_code, subject_kind, subject_id, input_fingerprint, status, '
          'applicability, evidence_json, evidence_sha256, created_at, origin_device_id) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            Variable.withString(projectId),
            Variable.withString(designRevisionId),
            Variable.withString(evidence.nodeKey.encode()),
            Variable.withString(nodeSha),
            Variable.withString(evidence.evaluationId),
            Variable.withString(evidence.nodeKey.scopeKind.name.toUpperCase()),
            Variable.withString(evidence.nodeKey.scopeId),
            Variable.withString(_processCode(evidence.nodeKey.processCode)),
            Variable.withString(evidence.nodeKey.subjectKind),
            Variable.withString(evidence.nodeKey.subjectId),
            Variable.withString(evidence.inputFingerprint),
            Variable.withString(evidence.status.name.toUpperCase()),
            Variable.withString(evidence.applicability.name.toUpperCase()),
            Variable.withString(evidence.canonicalJson),
            Variable.withString(evidence.evidenceSha256),
            Variable<DateTime>(now().toUtc()),
            Variable.withString(originDeviceId),
          ],
        );
      });

  Future<PowerPointerSnapshot> publishFirstCurrent({
    required String projectId,
    required String designRevisionId,
    required PowerEvaluationEvidence evidence,
  }) =>
      database.transaction(() async {
        await _requireRevision(
          projectId: projectId,
          designRevisionId: designRevisionId,
          requireWorking: true,
        );
        await _requireStoredEvaluation(
          projectId: projectId,
          designRevisionId: designRevisionId,
          evidence: evidence,
        );
        await database.customStatement(
          'INSERT OR IGNORE INTO power_evaluation_pointers '
          '(project_id, design_revision_id, logical_node_key_json, '
          'logical_node_key_sha256, state, generation, evaluation_id, '
          'evidence_sha256, updated_at, origin_device_id) '
          "VALUES (?, ?, ?, ?, 'CURRENT', 1, ?, ?, ?, ?)",
          [
            Variable.withString(projectId),
            Variable.withString(designRevisionId),
            Variable.withString(evidence.nodeKey.encode()),
            Variable.withString(evidence.nodeKey.sha256),
            Variable.withString(evidence.evaluationId),
            Variable.withString(evidence.evidenceSha256),
            Variable<DateTime>(now().toUtc()),
            Variable.withString(originDeviceId),
          ],
        );
        final pointer = await loadPointer(
          designRevisionId: designRevisionId,
          nodeKey: evidence.nodeKey,
        );
        if (pointer == null ||
            pointer.state != PowerPointerState.current ||
            pointer.generation != 1 ||
            pointer.evaluationId != evidence.evaluationId ||
            pointer.evidenceSha256 != evidence.evidenceSha256) {
          throw PowerRuntimeStorageException(
            'ELV4_POINTER_FIRST_PUBLICATION_CONFLICT',
            {'nodeKeySha256': evidence.nodeKey.sha256},
          );
        }
        return pointer;
      });

  Future<PowerPointerSnapshot> markStale({
    required String projectId,
    required String designRevisionId,
    required PowerNodeKeyV2 nodeKey,
    required int expectedGeneration,
  }) =>
      database.transaction(() async {
        await _requireRevision(
          projectId: projectId,
          designRevisionId: designRevisionId,
          requireWorking: true,
        );
        if (nodeKey.revisionId != designRevisionId) {
          throw const PowerRuntimeStorageException(
            'ELV4_POINTER_REVISION_MISMATCH',
          );
        }
        final updated = await database.customUpdate(
          'UPDATE power_evaluation_pointers '
          "SET state = 'STALE', generation = generation + 1, updated_at = ?, "
          'origin_device_id = ? '
          'WHERE project_id = ? AND design_revision_id = ? '
          'AND logical_node_key_sha256 = ? AND generation = ? '
          "AND state = 'CURRENT'",
          variables: [
            Variable<DateTime>(now().toUtc()),
            Variable.withString(originDeviceId),
            Variable.withString(projectId),
            Variable.withString(designRevisionId),
            Variable.withString(nodeKey.sha256),
            Variable.withInt(expectedGeneration),
          ],
        );
        if (updated != 1) {
          throw PowerRuntimeStorageException(
            'ELV4_POINTER_STALE_CAS_FAILED',
            {
              'nodeKeySha256': nodeKey.sha256,
              'expectedGeneration': expectedGeneration,
            },
          );
        }
        return (await loadPointer(
          designRevisionId: designRevisionId,
          nodeKey: nodeKey,
        ))!;
      });

  Future<PowerPointerSnapshot> publishCurrent({
    required String projectId,
    required String designRevisionId,
    required PowerEvaluationEvidence evidence,
    required int expectedStaleGeneration,
  }) =>
      database.transaction(() async {
        await _requireRevision(
          projectId: projectId,
          designRevisionId: designRevisionId,
          requireWorking: true,
        );
        await _requireStoredEvaluation(
          projectId: projectId,
          designRevisionId: designRevisionId,
          evidence: evidence,
        );
        final updated = await database.customUpdate(
          'UPDATE power_evaluation_pointers '
          "SET state = 'CURRENT', generation = generation + 1, evaluation_id = ?, "
          'evidence_sha256 = ?, updated_at = ?, origin_device_id = ? '
          'WHERE project_id = ? AND design_revision_id = ? '
          'AND logical_node_key_sha256 = ? AND generation = ? '
          "AND state = 'STALE'",
          variables: [
            Variable.withString(evidence.evaluationId),
            Variable.withString(evidence.evidenceSha256),
            Variable<DateTime>(now().toUtc()),
            Variable.withString(originDeviceId),
            Variable.withString(projectId),
            Variable.withString(designRevisionId),
            Variable.withString(evidence.nodeKey.sha256),
            Variable.withInt(expectedStaleGeneration),
          ],
        );
        if (updated != 1) {
          throw PowerRuntimeStorageException(
            'ELV4_POINTER_PUBLISH_CAS_FAILED',
            {
              'nodeKeySha256': evidence.nodeKey.sha256,
              'expectedGeneration': expectedStaleGeneration,
            },
          );
        }
        return (await loadPointer(
          designRevisionId: designRevisionId,
          nodeKey: evidence.nodeKey,
        ))!;
      });

  Future<PowerPointerSnapshot?> loadPointer({
    required String designRevisionId,
    required PowerNodeKeyV2 nodeKey,
  }) async {
    final row = await database.customSelect(
      'SELECT logical_node_key_json, state, generation, evaluation_id, '
      'evidence_sha256 FROM power_evaluation_pointers '
      'WHERE design_revision_id = ? AND logical_node_key_sha256 = ?',
      variables: [
        Variable.withString(designRevisionId),
        Variable.withString(nodeKey.sha256),
      ],
    ).getSingleOrNull();
    if (row == null) return null;
    final storedNodeKey = PowerNodeKeyV2.decode(
      row.read<String>('logical_node_key_json'),
    );
    if (storedNodeKey != nodeKey) {
      throw const PowerRuntimeStorageException('ELV4_POINTER_HASH_COLLISION');
    }
    return PowerPointerSnapshot(
      nodeKey: storedNodeKey,
      state: switch (row.read<String>('state')) {
        'CURRENT' => PowerPointerState.current,
        'STALE' => PowerPointerState.stale,
        _ => throw const PowerRuntimeStorageException(
            'ELV4_POINTER_STATE_CORRUPT',
          ),
      },
      generation: row.read<int>('generation'),
      evaluationId: row.readNullable<String>('evaluation_id'),
      evidenceSha256: row.readNullable<String>('evidence_sha256'),
    );
  }

  Future<void> _requireStoredEvaluation({
    required String projectId,
    required String designRevisionId,
    required PowerEvaluationEvidence evidence,
  }) async {
    final row = await database.customSelect(
      'SELECT project_id, evidence_sha256 FROM power_evaluation_records '
      'WHERE design_revision_id = ? AND logical_node_key_sha256 = ? '
      'AND evaluation_id = ?',
      variables: [
        Variable.withString(designRevisionId),
        Variable.withString(evidence.nodeKey.sha256),
        Variable.withString(evidence.evaluationId),
      ],
    ).getSingleOrNull();
    if (row == null ||
        row.read<String>('project_id') != projectId ||
        row.read<String>('evidence_sha256') != evidence.evidenceSha256) {
      throw const PowerRuntimeStorageException(
        'ELV4_POINTER_EVALUATION_NOT_STORED',
      );
    }
  }

  Future<void> _requireRevision({
    required String projectId,
    required String designRevisionId,
    required bool requireWorking,
  }) async {
    final row = await database.customSelect(
      'SELECT state FROM project_design_revisions '
      'WHERE id = ? AND project_id = ? AND deleted_at IS NULL',
      variables: [
        Variable.withString(designRevisionId),
        Variable.withString(projectId),
      ],
    ).getSingleOrNull();
    if (row == null) {
      throw const PowerRuntimeStorageException('ELV4_REVISION_NOT_FOUND');
    }
    final state = row.read<String>('state');
    if (requireWorking && state != 'WORKING') {
      throw PowerRuntimeStorageException(
        'ELV4_REVISION_NOT_WORKING',
        {'state': state},
      );
    }
  }
}

String _sha256(String value, String field) {
  final normalized = value.trim().toLowerCase();
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(normalized)) {
    throw ArgumentError.value(value, field, 'Expected lowercase SHA-256.');
  }
  return normalized;
}

String _processCode(PowerProcessCode value) => switch (value) {
      PowerProcessCode.pwr01 => 'ELV-PWR-01',
      PowerProcessCode.pwr02 => 'ELV-PWR-02',
      PowerProcessCode.pwr03 => 'ELV-PWR-03',
      PowerProcessCode.pwr04 => 'ELV-PWR-04',
      PowerProcessCode.pwr05 => 'ELV-PWR-05',
      PowerProcessCode.pwr06 => 'ELV-PWR-06',
    };
