import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core_elv5.dart';

import '../../../application/elv5/persistence/elv5_replacement_persistence.dart';
import '../../../application/elv5/persistence/elv5_runtime_persistence.dart';
import '../../../application/elv5/policy/elv5_policy_persistence.dart';
import '../../../application/elv_write_unit_of_work.dart';
import '../../database/app_database.dart';
import '../../database/drift_raw_statement.dart';
import 'drift_elv5_replacement_write_unit_of_work.dart';

final class DriftElv5PolicyWriteUnitOfWork implements Elv5PolicyWriteUnitOfWork {
  const DriftElv5PolicyWriteUnitOfWork(
    this.database, {
    required this.originDeviceId,
  });

  final AppDatabase database;
  final String originDeviceId;

  @override
  Future<T> run<T>(Future<T> Function(Elv5PolicyWriteSession session) action) =>
      DriftElv5ReplacementWriteUnitOfWork(
        database,
        originDeviceId: originDeviceId,
      ).run((replacement) async {
        return action(
          _DriftElv5PolicyWriteSession(
            replacement,
            policies: _DriftElv5PolicyMutationStore(
              database,
              originDeviceId: originDeviceId,
            ),
          ),
        );
      });
}

final class _DriftElv5PolicyWriteSession implements Elv5PolicyWriteSession {
  const _DriftElv5PolicyWriteSession(
    this.replacement, {
    required this.policies,
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
  final Elv5PolicyMutationStore policies;
}

final class _DriftElv5PolicyMutationStore implements Elv5PolicyMutationStore {
  const _DriftElv5PolicyMutationStore(
    this.database, {
    required this.originDeviceId,
  });

  static const _encoder = Elv5CanonicalJsonV1();

  final AppDatabase database;
  final String originDeviceId;

  @override
  Future<Elv5PolicyBindingSnapshot?> loadByBindingId({
    required String projectId,
    required String designRevisionId,
    required String bindingId,
  }) => _load(
    projectId: projectId,
    designRevisionId: designRevisionId,
    whereSql: 'id = ?',
    whereVariables: [Variable.withString(bindingId)],
  );

  @override
  Future<Elv5PolicyBindingSnapshot?> loadActiveBySubject({
    required String projectId,
    required String designRevisionId,
    required String subjectKind,
    required String subjectId,
  }) => _load(
    projectId: projectId,
    designRevisionId: designRevisionId,
    whereSql: 'subject_kind = ? AND subject_id = ?',
    whereVariables: [
      Variable.withString(subjectKind),
      Variable.withString(subjectId),
    ],
  );

  Future<Elv5PolicyBindingSnapshot?> _load({
    required String projectId,
    required String designRevisionId,
    required String whereSql,
    required List<Variable> whereVariables,
  }) async {
    final row = await database
        .customSelect(
          'SELECT id, revision, subject_kind, subject_id, process_codes_json, '
          'definition_ref_json, applicability_json FROM discipline_policy_bindings '
          'WHERE project_id = ? AND design_revision_id = ? AND $whereSql '
          'AND deleted_at IS NULL',
          variables: [
            Variable.withString(projectId),
            Variable.withString(designRevisionId),
            ...whereVariables,
          ],
        )
        .getSingleOrNull();
    if (row == null) return null;
    return Elv5PolicyBindingSnapshot(
      bindingId: row.read<String>('id'),
      revision: row.read<int>('revision'),
      payload: {
        'bindingId': row.read<String>('id'),
        'subject': {
          'kind': row.read<String>('subject_kind'),
          'id': row.read<String>('subject_id'),
        },
        'processCodes': jsonDecode(row.read<String>('process_codes_json')),
        'definitionRef': jsonDecode(row.read<String>('definition_ref_json')),
        'applicability': jsonDecode(row.read<String>('applicability_json')),
      },
    );
  }

  @override
  Future<void> bind({
    required String projectId,
    required String designRevisionId,
    required Map<String, Object?> payload,
    required DateTime updatedAtUtc,
  }) async {
    final subject = Map<String, Object?>.from(payload['subject']! as Map);
    final definitionRef = Map<String, Object?>.from(
      payload['definitionRef']! as Map,
    );
    final applicability = payload['applicability'];
    await runRawStatement(
      database,
      'INSERT INTO discipline_policy_bindings '
      '(project_id, design_revision_id, id, revision, created_at, updated_at, '
      'deleted_at, origin_device_id, subject_kind, subject_id, process_codes_json, '
      'definition_ref_json, definition_sha256, applicability_json, applicability_sha256) '
      'VALUES (?, ?, ?, 1, ?, ?, NULL, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        Variable.withString(projectId),
        Variable.withString(designRevisionId),
        Variable.withString(payload['bindingId']! as String),
        Variable<DateTime>(updatedAtUtc.toUtc()),
        Variable<DateTime>(updatedAtUtc.toUtc()),
        Variable.withString(originDeviceId),
        Variable.withString(subject['kind']! as String),
        Variable.withString(subject['id']! as String),
        Variable.withString(_canonicalJson(payload['processCodes'])),
        Variable.withString(_canonicalJson(definitionRef)),
        Variable.withString(definitionRef['contentHash']! as String),
        Variable.withString(_canonicalJson(applicability)),
        Variable.withString(_encoder.sha256(applicability)),
      ],
    );
  }

  @override
  Future<void> adopt({
    required String projectId,
    required String designRevisionId,
    required String bindingId,
    required int expectedRootRevision,
    required Map<String, Object?> payload,
    required DateTime updatedAtUtc,
  }) async {
    final definitionRef = Map<String, Object?>.from(
      payload['newDefinitionRef']! as Map,
    );
    final applicability = payload['applicability'];
    final changed = await database.customUpdate(
      'UPDATE discipline_policy_bindings SET revision = revision + 1, '
      'updated_at = ?, origin_device_id = ?, definition_ref_json = ?, '
      'definition_sha256 = ?, applicability_json = ?, applicability_sha256 = ? '
      'WHERE project_id = ? AND design_revision_id = ? AND id = ? '
      'AND revision = ? AND deleted_at IS NULL',
      variables: [
        Variable<DateTime>(updatedAtUtc.toUtc()),
        Variable.withString(originDeviceId),
        Variable.withString(_canonicalJson(definitionRef)),
        Variable.withString(definitionRef['contentHash']! as String),
        Variable.withString(_canonicalJson(applicability)),
        Variable.withString(_encoder.sha256(applicability)),
        Variable.withString(projectId),
        Variable.withString(designRevisionId),
        Variable.withString(bindingId),
        Variable<int>(expectedRootRevision),
      ],
    );
    if (changed != 1) throw StateError('ELV5_POLICY_ROOT_CAS_CONFLICT');
  }

  @override
  Future<void> release({
    required String projectId,
    required String designRevisionId,
    required String bindingId,
    required int expectedRootRevision,
    required DateTime updatedAtUtc,
  }) async {
    final changed = await database.customUpdate(
      'UPDATE discipline_policy_bindings SET revision = revision + 1, '
      'deleted_at = ?, updated_at = ?, origin_device_id = ? '
      'WHERE project_id = ? AND design_revision_id = ? AND id = ? '
      'AND revision = ? AND deleted_at IS NULL',
      variables: [
        Variable<DateTime>(updatedAtUtc.toUtc()),
        Variable<DateTime>(updatedAtUtc.toUtc()),
        Variable.withString(originDeviceId),
        Variable.withString(projectId),
        Variable.withString(designRevisionId),
        Variable.withString(bindingId),
        Variable<int>(expectedRootRevision),
      ],
    );
    if (changed != 1) throw StateError('ELV5_POLICY_ROOT_CAS_CONFLICT');
  }

  String _canonicalJson(Object? value) => utf8.decode(
    _encoder.encode(value),
    allowMalformed: false,
  );
}
