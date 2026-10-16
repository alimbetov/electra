import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core_elv5.dart';

import '../../../application/elv5/acs/elv5_acs_persistence.dart';
import '../../../application/elv5/persistence/elv5_replacement_persistence.dart';
import '../../../application/elv5/persistence/elv5_runtime_persistence.dart';
import '../../../application/elv_write_unit_of_work.dart';
import '../../database/app_database.dart';
import '../../database/drift_raw_statement.dart';
import 'drift_elv5_replacement_write_unit_of_work.dart';

final class DriftElv5AcsWriteUnitOfWork implements Elv5AcsWriteUnitOfWork {
  const DriftElv5AcsWriteUnitOfWork(this.database, {required this.originDeviceId});
  final AppDatabase database;
  final String originDeviceId;
  @override
  Future<T> run<T>(Future<T> Function(Elv5AcsWriteSession session) action) =>
      DriftElv5ReplacementWriteUnitOfWork(database, originDeviceId: originDeviceId)
          .run((replacement) => action(_Session(replacement,
                acs: _Store(database, originDeviceId: originDeviceId))));
}

final class _Session implements Elv5AcsWriteSession {
  const _Session(this.replacement, {required this.acs});
  final Elv5ReplacementWriteSession replacement;
  @override ElvCommandLedgerStore get commandLedger => replacement.commandLedger;
  @override Elv5EvaluationStore get evaluations => replacement.evaluations;
  @override Elv5PointerStore get pointers => replacement.pointers;
  @override Elv5DependencyStore get dependencies => replacement.dependencies;
  @override Elv5RevisionMutationStore get revisions => replacement.revisions;
  @override Elv5RevisionHistoryStore get history => replacement.history;
  @override final Elv5AcsMutationStore acs;
}

final class _Store implements Elv5AcsMutationStore {
  const _Store(this.database, {required this.originDeviceId});
  static const _encoder = Elv5CanonicalJsonV1();
  final AppDatabase database;
  final String originDeviceId;

  @override
  Future<Elv5AcsAggregateSnapshot?> load({
    required String projectId, required String designRevisionId,
    required String operation, required String subjectId,
  }) => operation == 'REPLACE_DOOR_ROLE_ASSIGNMENTS'
      ? _loadDoor(projectId, designRevisionId, subjectId)
      : _loadController(projectId, designRevisionId, subjectId);

  @override
  Future<void> replace({
    required String projectId, required String designRevisionId,
    required String operation, required String subjectId, required String bindingId,
    required int? expectedRootRevision, required Map<String,Object?> payload,
    required DateTime updatedAtUtc,
  }) => operation == 'REPLACE_DOOR_ROLE_ASSIGNMENTS'
      ? _replaceDoor(projectId, designRevisionId, subjectId, bindingId, expectedRootRevision, payload, updatedAtUtc)
      : _replaceController(projectId, designRevisionId, subjectId, bindingId, expectedRootRevision, payload, updatedAtUtc);

  Future<Elv5AcsAggregateSnapshot?> _loadDoor(String p, String r, String id) async {
    final root = await database.customSelect(
      'SELECT id, revision, topology_profile_ref_json, safety_mode FROM door_calculation_bindings '
      'WHERE project_id = ? AND design_revision_id = ? AND door_assembly_id = ? AND deleted_at IS NULL',
      variables: [Variable.withString(p), Variable.withString(r), Variable.withString(id)],
    ).getSingleOrNull();
    if (root == null) return null;
    final b = root.read<String>('id');
    final roles = await database.customSelect(
      'SELECT role_code, slot, component_id FROM door_role_assignments WHERE project_id = ? '
      'AND design_revision_id = ? AND binding_id = ? ORDER BY role_code, slot',
      variables: [Variable.withString(p), Variable.withString(r), Variable.withString(b)],
    ).get();
    final truth = await database.customSelect(
      'SELECT cause_code, expected_outcome_code, required_evidence_roles_json '
      'FROM door_release_truth_rows WHERE project_id = ? AND design_revision_id = ? '
      'AND binding_id = ? ORDER BY cause_code',
      variables: [Variable.withString(p), Variable.withString(r), Variable.withString(b)],
    ).get();
    return Elv5AcsAggregateSnapshot(
      aggregateKind: 'ACS_DOOR_CALCULATION', aggregateId: b, subjectId: id,
      revision: root.read<int>('revision'), payload: {
        'doorAssemblyId': id,
        'topologyProfileRef': jsonDecode(root.read<String>('topology_profile_ref_json')),
        'safetyMode': root.read<String>('safety_mode'),
        'roleAssignments': [for (final row in roles) {
          'roleCode': row.read<String>('role_code'), 'slot': row.read<int>('slot'),
          'componentId': row.read<String>('component_id'),
        }],
        'releaseTruthTable': [for (final row in truth) {
          'causeCode': row.read<String>('cause_code'),
          'expectedOutcomeCode': row.read<String>('expected_outcome_code'),
          'requiredEvidenceRoles': jsonDecode(row.read<String>('required_evidence_roles_json')),
        }],
      },
    );
  }

  Future<Elv5AcsAggregateSnapshot?> _loadController(String p, String r, String id) async {
    final root = await database.customSelect(
      'SELECT id, revision, reserve_policy_ref_json FROM controller_resource_bindings '
      'WHERE project_id = ? AND design_revision_id = ? AND controller_id = ? AND deleted_at IS NULL',
      variables: [Variable.withString(p), Variable.withString(r), Variable.withString(id)],
    ).getSingleOrNull();
    if (root == null) return null;
    final b = root.read<String>('id');
    final rows = await database.customSelect(
      'SELECT resource_id, resource_kind, role_code, subject_id FROM controller_resource_assignments '
      'WHERE project_id = ? AND design_revision_id = ? AND binding_id = ? ORDER BY resource_id, role_code',
      variables: [Variable.withString(p), Variable.withString(r), Variable.withString(b)],
    ).get();
    return Elv5AcsAggregateSnapshot(
      aggregateKind: 'ACS_CONTROLLER_RESOURCES', aggregateId: b, subjectId: id,
      revision: root.read<int>('revision'), payload: {
        'controllerId': id,
        'resourceAssignments': [for (final row in rows) {
          'resourceId': row.read<String>('resource_id'),
          'resourceKind': row.read<String>('resource_kind'),
          'assignmentRole': row.read<String>('role_code'),
          'subjectId': row.read<String>('subject_id'),
        }],
        'reservePolicyRef': jsonDecode(root.read<String>('reserve_policy_ref_json')),
      },
    );
  }

  Future<void> _replaceDoor(String p, String r, String id, String b, int? rev, Map<String,Object?> payload, DateTime now) async {
    for (final raw in payload['roleAssignments']! as List) {
      await _requireComponentReference(p, Map<String,Object?>.from(raw as Map)['componentId']! as String);
    }
    await _upsertRoot(
      table: 'door_calculation_bindings', subjectColumn: 'door_assembly_id', p: p, r: r,
      subjectId: id, bindingId: b, expectedRevision: rev, now: now,
      insertColumns: 'topology_profile_ref_json, safety_mode',
      values: [Variable.withString(_canonical(payload['topologyProfileRef'])), Variable.withString(payload['safetyMode']! as String)]);
    await _delete('door_role_assignments', p, r, b);
    await _delete('door_release_truth_rows', p, r, b);
    for (final raw in payload['roleAssignments']! as List) {
      final row = Map<String,Object?>.from(raw as Map);
      await runRawStatement(database,
        'INSERT INTO door_role_assignments (project_id, design_revision_id, binding_id, component_id, role_code, slot) VALUES (?, ?, ?, ?, ?, ?)', [
        Variable.withString(p), Variable.withString(r), Variable.withString(b), Variable.withString(row['componentId']! as String),
        Variable.withString(row['roleCode']! as String), Variable<int>(row['slot']! as int)]);
    }
    for (final raw in payload['releaseTruthTable']! as List) {
      final row = Map<String,Object?>.from(raw as Map);
      await runRawStatement(database,
        'INSERT INTO door_release_truth_rows (project_id, design_revision_id, binding_id, cause_code, expected_outcome_code, required_evidence_roles_json) VALUES (?, ?, ?, ?, ?, ?)', [
        Variable.withString(p), Variable.withString(r), Variable.withString(b), Variable.withString(row['causeCode']! as String),
        Variable.withString(row['expectedOutcomeCode']! as String), Variable.withString(_canonical(row['requiredEvidenceRoles']))]);
    }
  }

  Future<void> _replaceController(String p, String r, String id, String b, int? rev, Map<String,Object?> payload, DateTime now) async {
    await _requireComponentReference(p, id);
    await _upsertRoot(
      table: 'controller_resource_bindings', subjectColumn: 'controller_id', p: p, r: r,
      subjectId: id, bindingId: b, expectedRevision: rev, now: now,
      insertColumns: 'reserve_policy_ref_json', values: [Variable.withString(_canonical(payload['reservePolicyRef']))]);
    await _delete('controller_resource_assignments', p, r, b);
    for (final raw in payload['resourceAssignments']! as List) {
      final row = Map<String,Object?>.from(raw as Map);
      await runRawStatement(database,
        'INSERT INTO controller_resource_assignments (project_id, design_revision_id, binding_id, resource_id, resource_kind, subject_id, role_code) VALUES (?, ?, ?, ?, ?, ?, ?)', [
        Variable.withString(p), Variable.withString(r), Variable.withString(b), Variable.withString(row['resourceId']! as String),
        Variable.withString(row['resourceKind']! as String), Variable.withString(row['subjectId']! as String),
        Variable.withString(row['assignmentRole']! as String)]);
    }
  }

  Future<void> _upsertRoot({
    required String table, required String subjectColumn, required String p, required String r,
    required String subjectId, required String bindingId, required int? expectedRevision,
    required DateTime now, required String insertColumns, required List<Variable> values,
  }) async {
    if (expectedRevision == null) {
      final placeholders = List.filled(values.length, '?').join(', ');
      await runRawStatement(database,
        'INSERT INTO $table (project_id, design_revision_id, id, revision, created_at, updated_at, deleted_at, origin_device_id, $subjectColumn, $insertColumns) '
        'VALUES (?, ?, ?, 1, ?, ?, NULL, ?, ?, $placeholders)', [
        Variable.withString(p), Variable.withString(r), Variable.withString(bindingId), Variable<DateTime>(now.toUtc()),
        Variable<DateTime>(now.toUtc()), Variable.withString(originDeviceId), Variable.withString(subjectId), ...values]);
      return;
    }
    final assignments = insertColumns.split(',').map((e) => '${e.trim()} = ?').join(', ');
    final changed = await database.customUpdate(
      'UPDATE $table SET revision = revision + 1, updated_at = ?, origin_device_id = ?, $assignments '
      'WHERE project_id = ? AND design_revision_id = ? AND id = ? AND $subjectColumn = ? '
      'AND revision = ? AND deleted_at IS NULL',
      variables: [Variable<DateTime>(now.toUtc()), Variable.withString(originDeviceId), ...values,
        Variable.withString(p), Variable.withString(r), Variable.withString(bindingId), Variable.withString(subjectId), Variable<int>(expectedRevision)]);
    if (changed != 1) throw StateError('ELV5_ACS_ROOT_CAS_CONFLICT');
  }

  Future<void> _delete(String table, String p, String r, String b) => database.customUpdate(
    'DELETE FROM $table WHERE project_id = ? AND design_revision_id = ? AND binding_id = ?',
    variables: [Variable.withString(p), Variable.withString(r), Variable.withString(b)]).then((_) {});

  Future<void> _requireComponentReference(String projectId, String componentId) async {
    final row = await database.customSelect(
      'SELECT 1 AS found FROM component_reference_bindings WHERE project_id = ? '
      'AND component_id = ? AND deleted_at IS NULL',
      variables: [Variable.withString(projectId), Variable.withString(componentId)],
    ).getSingleOrNull();
    if (row == null) throw StateError('ELV5_COMPONENT_REFERENCE_BINDING_NOT_FOUND:$componentId');
  }

  String _canonical(Object? value) => utf8.decode(_encoder.encode(value), allowMalformed: false);
}
