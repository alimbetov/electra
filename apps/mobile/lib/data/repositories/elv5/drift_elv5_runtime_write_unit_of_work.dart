import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core_elv5.dart';

import '../../../application/elv5/persistence/elv5_runtime_persistence.dart';
import '../../../application/elv_write_unit_of_work.dart';
import '../../database/app_database.dart';
import '../../database/drift_raw_statement.dart';

final class DriftElv5RuntimeWriteUnitOfWork
    implements Elv5RuntimeWriteUnitOfWork {
  const DriftElv5RuntimeWriteUnitOfWork(
    this.database, {
    required this.originDeviceId,
  });

  final AppDatabase database;
  final String originDeviceId;

  @override
  Future<T> run<T>(Future<T> Function(Elv5RuntimeWriteSession session) action) =>
      database.transaction(() async {
        final session = _DriftElv5RuntimeWriteSession(
          database,
          originDeviceId: originDeviceId,
        );
        return action(session);
      });
}

final class _DriftElv5RuntimeWriteSession implements Elv5RuntimeWriteSession {
  _DriftElv5RuntimeWriteSession(
    AppDatabase database, {
    required String originDeviceId,
  }) : commandLedger = _DriftElv5CommandLedgerStore(database),
       evaluations = _DriftElv5EvaluationStore(
         database,
         originDeviceId: originDeviceId,
       ),
       pointers = _DriftElv5PointerStore(
         database,
         originDeviceId: originDeviceId,
       ),
       dependencies = _DriftElv5DependencyStore(database);

  @override
  final ElvCommandLedgerStore commandLedger;

  @override
  final Elv5EvaluationStore evaluations;

  @override
  final Elv5PointerStore pointers;

  @override
  final Elv5DependencyStore dependencies;
}

final class _DriftElv5CommandLedgerStore implements ElvCommandLedgerStore {
  const _DriftElv5CommandLedgerStore(this.database);

  final AppDatabase database;

  @override
  Future<ElvCommandLedgerEntry?> find(
    String projectId,
    String commandId,
  ) async {
    final row = await database
        .customSelect(
          'SELECT project_id, command_id, command_type, payload_schema_version, '
          'normalized_payload_sha256, outcome_kind, logical_result_json, '
          'created_at, committed_at, origin_device_id '
          'FROM command_execution_records '
          'WHERE project_id = ? AND command_id = ?',
          variables: [
            Variable.withString(projectId),
            Variable.withString(commandId),
          ],
        )
        .getSingleOrNull();
    if (row == null) return null;
    return ElvCommandLedgerEntry(
      projectId: row.read<String>('project_id'),
      commandId: row.read<String>('command_id'),
      commandType: row.read<String>('command_type'),
      payloadSchemaVersion: row.read<int>('payload_schema_version'),
      normalizedPayloadSha256: row.read<String>('normalized_payload_sha256'),
      outcomeKind: row.read<String>('outcome_kind'),
      logicalResultJson: row.read<String>('logical_result_json'),
      createdAt: row.read<DateTime>('created_at'),
      committedAt: row.read<DateTime>('committed_at'),
      originDeviceId: row.read<String>('origin_device_id'),
    );
  }

  @override
  Future<void> save(ElvCommandLedgerEntry entry) async {
    final existing = await find(entry.projectId, entry.commandId);
    if (existing != null) {
      if (_sameLedgerEntry(existing, entry)) return;
      throw StateError('ELV command ledger conflict.');
    }
    await runRawStatement(
      database,
      'INSERT INTO command_execution_records '
      '(project_id, command_id, command_type, payload_schema_version, '
      'normalized_payload_sha256, outcome_kind, logical_result_json, created_at, '
      'committed_at, origin_device_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        Variable.withString(entry.projectId),
        Variable.withString(entry.commandId),
        Variable.withString(entry.commandType),
        Variable<int>(entry.payloadSchemaVersion),
        Variable.withString(entry.normalizedPayloadSha256),
        Variable.withString(entry.outcomeKind),
        Variable.withString(entry.logicalResultJson),
        Variable<DateTime>(entry.createdAt.toUtc()),
        Variable<DateTime>(entry.committedAt.toUtc()),
        Variable.withString(originDeviceId),
      ],
    );
  }

  bool _sameLedgerEntry(
    ElvCommandLedgerEntry left,
    ElvCommandLedgerEntry right,
  ) =>
      left.projectId == right.projectId &&
      left.commandId == right.commandId &&
      left.commandType == right.commandType &&
      left.payloadSchemaVersion == right.payloadSchemaVersion &&
      left.normalizedPayloadSha256 == right.normalizedPayloadSha256 &&
      left.outcomeKind == right.outcomeKind &&
      left.logicalResultJson == right.logicalResultJson;
}

final class _DriftElv5EvaluationStore implements Elv5EvaluationStore {
  const _DriftElv5EvaluationStore(
    this.database, {
    required this.originDeviceId,
  });

  final AppDatabase database;
  final String originDeviceId;

  @override
  Future<Map<String, Elv5EvaluationRecord>> loadEvaluationsByIdsBulk({
    required String projectId,
    required Set<String> evaluationIds,
  }) async {
    if (evaluationIds.isEmpty) return const {};
    final ids = evaluationIds.toList(growable: false)..sort();
    final placeholders = List.filled(ids.length, '?').join(',');
    final rows = await database.customSelect(
      'SELECT * FROM discipline_evaluation_records '
      'WHERE project_id = ? AND evaluation_id IN ($placeholders)',
      variables: [
        Variable.withString(projectId),
        ...ids.map(Variable.withString),
      ],
    ).get();
    return {
      for (final row in rows)
        row.read<String>('evaluation_id'): _evaluation(row),
    };
  }

  @override
  Future<void> appendEvaluation(Elv5EvaluationRecord record) async {
    final existing = await loadEvaluationsByIdsBulk(
      projectId: record.projectId,
      evaluationIds: {record.evaluationId},
    );
    final previous = existing[record.evaluationId];
    if (previous != null) {
      if (previous.logicalNodeKeySha256 == record.logicalNodeKeySha256 &&
          previous.outputSha256 == record.outputSha256 &&
          previous.evidenceSha256 == record.evidenceSha256) {
        return;
      }
      throw StateError('ELV5_EVALUATION_IDENTITY_CONFLICT');
    }
    await runRawStatement(
      database,
      'INSERT INTO discipline_evaluation_records '
      '(project_id, design_revision_id, logical_node_key_json, '
      'logical_node_key_sha256, evaluation_id, scope_kind, scope_id, '
      'scenario_key, process_code, subject_kind, subject_id, algorithm_version, '
      'input_schema_version, output_schema_version, numeric_backend_version, '
      'canonical_encoder_version, input_fingerprint, policy_fingerprint, '
      'execution, completion, assessment, output_json, output_sha256, '
      'evidence_json, evidence_sha256, completed_at_utc, origin_device_id) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, '
      '?, ?, ?, ?, ?, ?)',
      [
        Variable.withString(record.projectId),
        Variable.withString(record.designRevisionId),
        Variable.withString(record.logicalNodeKeyJson),
        Variable.withString(record.logicalNodeKeySha256),
        Variable.withString(record.evaluationId),
        Variable.withString(record.scopeKind),
        Variable.withString(record.scopeId),
        Variable.withString(record.scenarioKey),
        Variable.withString(record.processCode),
        Variable.withString(record.subjectKind),
        Variable.withString(record.subjectId),
        Variable.withString(record.algorithmVersion),
        Variable.withString(record.inputSchemaVersion),
        Variable.withString(record.outputSchemaVersion),
        Variable.withString(record.numericBackendVersion),
        Variable.withString(record.canonicalEncoderVersion),
        Variable.withString(record.inputFingerprint),
        Variable.withString(record.policyFingerprint),
        Variable.withString(record.execution),
        Variable.withString(record.completion),
        Variable.withString(record.assessment),
        Variable.withString(record.outputJson),
        Variable.withString(record.outputSha256),
        Variable.withString(record.evidenceJson),
        Variable.withString(record.evidenceSha256),
        Variable<DateTime>(record.completedAtUtc.toUtc()),
        Variable.withString(originDeviceId),
      ],
    );
  }

  Elv5EvaluationRecord _evaluation(QueryRow row) {
    final evidenceJson = row.read<String>('evidence_json');
    return Elv5EvaluationRecord(
      projectId: row.read<String>('project_id'),
      designRevisionId: row.read<String>('design_revision_id'),
      logicalNodeKeyJson: row.read<String>('logical_node_key_json'),
      logicalNodeKeySha256: row.read<String>('logical_node_key_sha256'),
      evaluationId: row.read<String>('evaluation_id'),
      scopeKind: row.read<String>('scope_kind'),
      scopeId: row.read<String>('scope_id'),
      scenarioKey: row.read<String>('scenario_key'),
      processCode: row.read<String>('process_code'),
      subjectKind: row.read<String>('subject_kind'),
      subjectId: row.read<String>('subject_id'),
      algorithmVersion: row.read<String>('algorithm_version'),
      inputSchemaVersion: row.read<String>('input_schema_version'),
      outputSchemaVersion: row.read<String>('output_schema_version'),
      numericBackendVersion: row.read<String>('numeric_backend_version'),
      canonicalEncoderVersion: row.read<String>('canonical_encoder_version'),
      inputFingerprint: row.read<String>('input_fingerprint'),
      policyFingerprint: row.read<String>('policy_fingerprint'),
      execution: row.read<String>('execution'),
      completion: row.read<String>('completion'),
      assessment: row.read<String>('assessment'),
      outputJson: row.read<String>('output_json'),
      outputSha256: row.read<String>('output_sha256'),
      evidenceJson: evidenceJson,
      evidenceSha256: row.read<String>('evidence_sha256'),
      completedAtUtc: row.read<DateTime>('completed_at_utc').toUtc(),
      qualificationIdentity: _qualificationIdentity(evidenceJson),
    );
  }
}

final class _DriftElv5PointerStore implements Elv5PointerStore {
  const _DriftElv5PointerStore(
    this.database, {
    required this.originDeviceId,
  });

  final AppDatabase database;
  final String originDeviceId;

  @override
  Future<Map<String, Elv5EvaluationPointer>> loadPointersBulk({
    required String projectId,
    required String designRevisionId,
    required Set<String> logicalNodeKeySha256s,
  }) async {
    if (logicalNodeKeySha256s.isEmpty) return const {};
    final keys = logicalNodeKeySha256s.toList(growable: false)..sort();
    final placeholders = List.filled(keys.length, '?').join(',');
    final rows = await database.customSelect(
      'SELECT * FROM discipline_evaluation_pointers '
      'WHERE project_id = ? AND design_revision_id = ? '
      'AND logical_node_key_sha256 IN ($placeholders)',
      variables: [
        Variable.withString(projectId),
        Variable.withString(designRevisionId),
        ...keys.map(Variable.withString),
      ],
    ).get();
    return {
      for (final row in rows)
        row.read<String>('logical_node_key_sha256'): _pointer(row),
    };
  }

  @override
  Future<bool> compareAndSet(Elv5PointerWrite write) async {
    if (write.expectedGeneration == 0) {
      final existing = await loadPointersBulk(
        projectId: write.projectId,
        designRevisionId: write.designRevisionId,
        logicalNodeKeySha256s: {write.logicalNodeKeySha256},
      );
      if (existing.isNotEmpty) return false;
      await runRawStatement(
        database,
        'INSERT INTO discipline_evaluation_pointers '
        '(project_id, design_revision_id, logical_node_key_json, '
        'logical_node_key_sha256, freshness, generation, evaluation_id, '
        'input_fingerprint, output_sha256, updated_at, origin_device_id) '
        'VALUES (?, ?, ?, ?, ?, 1, ?, ?, ?, ?, ?)',
        [
          Variable.withString(write.projectId),
          Variable.withString(write.designRevisionId),
          Variable.withString(write.logicalNodeKeyJson),
          Variable.withString(write.logicalNodeKeySha256),
          Variable.withString(write.freshness.name.toUpperCase()),
          Variable<String>(write.evaluationId),
          Variable<String>(write.inputFingerprint),
          Variable<String>(write.outputSha256),
          Variable<DateTime>(write.updatedAtUtc.toUtc()),
          Variable.withString(originDeviceId),
        ],
      );
      return true;
    }

    final updated = await database.customUpdate(
      'UPDATE discipline_evaluation_pointers '
      'SET logical_node_key_json = ?, freshness = ?, generation = generation + 1, '
      'evaluation_id = ?, input_fingerprint = ?, output_sha256 = ?, '
      'updated_at = ?, origin_device_id = ? '
      'WHERE project_id = ? AND design_revision_id = ? '
      'AND logical_node_key_sha256 = ? AND generation = ?',
      variables: [
        Variable.withString(write.logicalNodeKeyJson),
        Variable.withString(write.freshness.name.toUpperCase()),
        Variable<String>(write.evaluationId),
        Variable<String>(write.inputFingerprint),
        Variable<String>(write.outputSha256),
        Variable<DateTime>(write.updatedAtUtc.toUtc()),
        Variable.withString(originDeviceId),
        Variable.withString(write.projectId),
        Variable.withString(write.designRevisionId),
        Variable.withString(write.logicalNodeKeySha256),
        Variable<int>(write.expectedGeneration),
      ],
    );
    return updated == 1;
  }

  @override
  Future<int> markStaleBulk({
    required String projectId,
    required String designRevisionId,
    required Set<String> logicalNodeKeySha256s,
    required DateTime updatedAtUtc,
  }) async {
    if (logicalNodeKeySha256s.isEmpty) return 0;
    final keys = logicalNodeKeySha256s.toList(growable: false)..sort();
    final placeholders = List.filled(keys.length, '?').join(',');
    return database.customUpdate(
      'UPDATE discipline_evaluation_pointers '
      "SET freshness = 'STALE', generation = generation + 1, updated_at = ?, "
      'origin_device_id = ? '
      'WHERE project_id = ? AND design_revision_id = ? '
      'AND logical_node_key_sha256 IN ($placeholders) '
      "AND freshness <> 'STALE'",
      variables: [
        Variable<DateTime>(updatedAtUtc.toUtc()),
        Variable.withString(originDeviceId),
        Variable.withString(projectId),
        Variable.withString(designRevisionId),
        ...keys.map(Variable.withString),
      ],
    );
  }

  Elv5EvaluationPointer _pointer(QueryRow row) => Elv5EvaluationPointer(
    projectId: row.read<String>('project_id'),
    designRevisionId: row.read<String>('design_revision_id'),
    logicalNodeKeyJson: row.read<String>('logical_node_key_json'),
    logicalNodeKeySha256: row.read<String>('logical_node_key_sha256'),
    freshness: Elv5PointerFreshness.values.byName(
      row.read<String>('freshness').toLowerCase(),
    ),
    generation: row.read<int>('generation'),
    evaluationId: row.readNullable<String>('evaluation_id'),
    inputFingerprint: row.readNullable<String>('input_fingerprint'),
    outputSha256: row.readNullable<String>('output_sha256'),
    updatedAtUtc: row.read<DateTime>('updated_at').toUtc(),
  );
}

final class _DriftElv5DependencyStore implements Elv5DependencyStore {
  const _DriftElv5DependencyStore(this.database);

  final AppDatabase database;

  @override
  Future<Map<String, List<Elv5DependencyMarker>>> loadDependencyMarkersBulk({
    required String projectId,
    required String designRevisionId,
    required Set<String> dependencyKeySha256s,
  }) async {
    if (dependencyKeySha256s.isEmpty) return const {};
    final keys = dependencyKeySha256s.toList(growable: false)..sort();
    final placeholders = List.filled(keys.length, '?').join(',');
    final rows = await database.customSelect(
      'SELECT * FROM discipline_dependency_index '
      'WHERE project_id = ? AND design_revision_id = ? '
      'AND dependency_key_sha256 IN ($placeholders) '
      'ORDER BY dependency_key_sha256, logical_node_key_sha256',
      variables: [
        Variable.withString(projectId),
        Variable.withString(designRevisionId),
        ...keys.map(Variable.withString),
      ],
    ).get();
    final result = <String, List<Elv5DependencyMarker>>{};
    for (final row in rows) {
      final marker = _marker(row);
      result.putIfAbsent(marker.dependencyKeySha256, () => []).add(marker);
    }
    return {
      for (final entry in result.entries)
        entry.key: List.unmodifiable(entry.value),
    };
  }

  @override
  Future<Set<String>> loadDependentNodeHashesBulk({
    required String projectId,
    required String designRevisionId,
    required Set<String> dependencyKeySha256s,
  }) async {
    final markers = await loadDependencyMarkersBulk(
      projectId: projectId,
      designRevisionId: designRevisionId,
      dependencyKeySha256s: dependencyKeySha256s,
    );
    return {
      for (final values in markers.values)
        for (final marker in values) marker.logicalNodeKeySha256,
    };
  }

  @override
  Future<void> replaceNodeDependencies({
    required String projectId,
    required String designRevisionId,
    required String logicalNodeKeySha256,
    required Iterable<Elv5DependencyMarker> markers,
  }) async {
    final normalized = markers.toList(growable: false);
    for (final marker in normalized) {
      if (marker.projectId != projectId ||
          marker.designRevisionId != designRevisionId ||
          marker.logicalNodeKeySha256 != logicalNodeKeySha256) {
        throw ArgumentError('Dependency marker scope mismatch.');
      }
    }
    await database.customUpdate(
      'DELETE FROM discipline_dependency_index '
      'WHERE project_id = ? AND design_revision_id = ? '
      'AND logical_node_key_sha256 = ?',
      variables: [
        Variable.withString(projectId),
        Variable.withString(designRevisionId),
        Variable.withString(logicalNodeKeySha256),
      ],
    );
    for (final marker in normalized) {
      await runRawStatement(
        database,
        'INSERT INTO discipline_dependency_index '
        '(project_id, design_revision_id, dependency_key, dependency_key_sha256, '
        'logical_node_key_sha256, relation_kind, updated_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?)',
        [
          Variable.withString(marker.projectId),
          Variable.withString(marker.designRevisionId),
          Variable.withString(marker.dependencyKey),
          Variable.withString(marker.dependencyKeySha256),
          Variable.withString(marker.logicalNodeKeySha256),
          Variable.withString(marker.relationKind.trim().toUpperCase()),
          Variable<DateTime>(marker.updatedAtUtc.toUtc()),
        ],
      );
    }
  }

  Elv5DependencyMarker _marker(QueryRow row) => Elv5DependencyMarker(
    projectId: row.read<String>('project_id'),
    designRevisionId: row.read<String>('design_revision_id'),
    dependencyKey: row.read<String>('dependency_key'),
    dependencyKeySha256: row.read<String>('dependency_key_sha256'),
    logicalNodeKeySha256: row.read<String>('logical_node_key_sha256'),
    relationKind: row.read<String>('relation_kind'),
    updatedAtUtc: row.read<DateTime>('updated_at').toUtc(),
  );
}

Elv5QualificationIdentity? _qualificationIdentity(String evidenceJson) {
  final decoded = jsonDecode(evidenceJson);
  if (decoded is! Map) {
    throw const FormatException('ELV5 persisted evidence must be an object.');
  }
  final evidence = Map<String, Object?>.from(decoded);
  final rawIdentity = evidence['foundationQualificationIdentity'];
  final rawSha = evidence['foundationQualificationIdentitySha256'];
  if (rawIdentity == null && rawSha == null) return null;
  if (rawIdentity is! Map || rawSha is! String) {
    throw const FormatException(
      'ELV5 qualification evidence identity/hash must be present together.',
    );
  }
  final identity = Elv5QualificationIdentity.fromMap(
    Map<String, Object?>.from(rawIdentity),
  );
  if (identity.canonicalSha256() != rawSha) {
    throw StateError('ELV5_QUALIFICATION_EVIDENCE_HASH_MISMATCH');
  }
  return identity;
}
