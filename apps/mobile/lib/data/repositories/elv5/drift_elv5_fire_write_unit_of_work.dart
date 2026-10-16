import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core_elv5.dart';

import '../../../application/elv5/fire/elv5_fire_persistence.dart';
import '../../../application/elv5/persistence/elv5_replacement_persistence.dart';
import '../../../application/elv5/persistence/elv5_runtime_persistence.dart';
import '../../../application/elv_write_unit_of_work.dart';
import '../../database/app_database.dart';
import '../../database/drift_raw_statement.dart';
import 'drift_elv5_replacement_write_unit_of_work.dart';

final class DriftElv5FireWriteUnitOfWork implements Elv5FireWriteUnitOfWork {
  const DriftElv5FireWriteUnitOfWork(this.database, {required this.originDeviceId});
  final AppDatabase database;
  final String originDeviceId;
  @override
  Future<T> run<T>(Future<T> Function(Elv5FireWriteSession session) action) =>
      DriftElv5ReplacementWriteUnitOfWork(database, originDeviceId: originDeviceId)
          .run((replacement) => action(_Session(replacement,
                fire: _Store(database, originDeviceId: originDeviceId))));
}

final class _Session implements Elv5FireWriteSession {
  const _Session(this.replacement, {required this.fire});
  final Elv5ReplacementWriteSession replacement;
  @override ElvCommandLedgerStore get commandLedger => replacement.commandLedger;
  @override Elv5EvaluationStore get evaluations => replacement.evaluations;
  @override Elv5PointerStore get pointers => replacement.pointers;
  @override Elv5DependencyStore get dependencies => replacement.dependencies;
  @override Elv5RevisionMutationStore get revisions => replacement.revisions;
  @override Elv5RevisionHistoryStore get history => replacement.history;
  @override final Elv5FireMutationStore fire;
}

final class _Store implements Elv5FireMutationStore {
  const _Store(this.database, {required this.originDeviceId});
  static const _encoder = Elv5CanonicalJsonV1();
  final AppDatabase database;
  final String originDeviceId;

  @override
  Future<Elv5FireAggregateSnapshot?> load({
    required String projectId, required String designRevisionId,
    required String operation, required String subjectId,
  }) => operation == 'REPLACE_FIRE_LOOP_ASSIGNMENTS'
      ? _loadLoop(projectId, designRevisionId, subjectId)
      : _loadCircuit(projectId, designRevisionId, subjectId);

  @override
  Future<void> replace({
    required String projectId, required String designRevisionId,
    required String operation, required String subjectId, required String bindingId,
    required int? expectedRootRevision, required Map<String,Object?> payload,
    required DateTime updatedAtUtc,
  }) => operation == 'REPLACE_FIRE_LOOP_ASSIGNMENTS'
      ? _replaceLoop(projectId, designRevisionId, subjectId, bindingId, expectedRootRevision, payload, updatedAtUtc)
      : _replaceCircuit(projectId, designRevisionId, subjectId, bindingId, expectedRootRevision, payload, updatedAtUtc);

  Future<Elv5FireAggregateSnapshot?> _loadLoop(String p, String r, String id) async {
    final root = await database.customSelect(
      'SELECT id, revision, address_domain_json, topology_profile_ref_json '
      'FROM fire_loop_bindings WHERE project_id = ? AND design_revision_id = ? '
      'AND loop_id = ? AND deleted_at IS NULL',
      variables: [Variable.withString(p), Variable.withString(r), Variable.withString(id)],
    ).getSingleOrNull();
    if (root == null) return null;
    final b = root.read<String>('id');
    final devices = await database.customSelect(
      'SELECT device_id, expansion_profile_ref_json FROM fire_loop_device_assignments '
      'WHERE project_id = ? AND design_revision_id = ? AND binding_id = ? ORDER BY ordinal, device_id',
      variables: [Variable.withString(p), Variable.withString(r), Variable.withString(b)],
    ).get();
    final claims = await database.customSelect(
      'SELECT device_id, address FROM fire_address_claims WHERE project_id = ? '
      'AND design_revision_id = ? AND binding_id = ? ORDER BY device_id, address',
      variables: [Variable.withString(p), Variable.withString(r), Variable.withString(b)],
    ).get();
    final byDevice = <String,List<int>>{};
    for (final row in claims) {
      byDevice.putIfAbsent(row.read<String>('device_id'), () => []).add(row.read<int>('address'));
    }
    return Elv5FireAggregateSnapshot(
      aggregateKind: 'FIRE_LOOP', aggregateId: b, subjectId: id,
      revision: root.read<int>('revision'), payload: {
        'loopId': id,
        'deviceAssignments': [for (final row in devices) {
          'deviceId': row.read<String>('device_id'),
          'profileRef': _object(row.read<String>('expansion_profile_ref_json'))['profileRef'],
          'expandedAddresses': byDevice[row.read<String>('device_id')] ?? const <int>[],
        }],
        'addressDomain': jsonDecode(root.read<String>('address_domain_json')),
        'topologyProfileRef': jsonDecode(root.read<String>('topology_profile_ref_json')),
      },
    );
  }

  Future<Elv5FireAggregateSnapshot?> _loadCircuit(String p, String r, String id) async {
    final root = await database.customSelect(
      'SELECT id, revision, output_ref_json, policy_ref_json FROM notification_circuit_bindings '
      'WHERE project_id = ? AND design_revision_id = ? AND circuit_id = ? AND deleted_at IS NULL',
      variables: [Variable.withString(p), Variable.withString(r), Variable.withString(id)],
    ).getSingleOrNull();
    if (root == null) return null;
    final b = root.read<String>('id');
    final rows = await database.customSelect(
      'SELECT device_id, state_load_json FROM notification_circuit_assignments '
      'WHERE project_id = ? AND design_revision_id = ? AND binding_id = ? ORDER BY device_id',
      variables: [Variable.withString(p), Variable.withString(r), Variable.withString(b)],
    ).get();
    return Elv5FireAggregateSnapshot(
      aggregateKind: 'FIRE_NOTIFICATION_CIRCUIT', aggregateId: b, subjectId: id,
      revision: root.read<int>('revision'), payload: {
        'circuitId': id,
        'deviceAssignments': [for (final row in rows) {
          'deviceId': row.read<String>('device_id'),
          'stateCurrentMa': jsonDecode(row.read<String>('state_load_json')),
        }],
        'outputRef': jsonDecode(root.read<String>('output_ref_json')),
        'policyRef': jsonDecode(root.read<String>('policy_ref_json')),
      },
    );
  }

  Future<void> _replaceLoop(String p, String r, String id, String b, int? rev, Map<String,Object?> payload, DateTime now) async {
    final domain = Map<String,Object?>.from(payload['addressDomain']! as Map);
    final domainId = _encoder.sha256({
      'schema': 'electra.elv5-fire-address-domain-id.v1',
      'panelId': domain['panelId'], 'loopId': domain['loopId'],
    });
    for (final raw in payload['deviceAssignments']! as List) {
      await _requireComponentReference(p, Map<String,Object?>.from(raw as Map)['deviceId']! as String);
    }
    await _upsertRoot(
      table: 'fire_loop_bindings', subjectColumn: 'loop_id', p: p, r: r, subjectId: id,
      bindingId: b, expectedRevision: rev, now: now,
      columns: 'address_domain_json, address_domain, topology_profile_ref_json, policy_ref_json',
      values: [Variable.withString(_canonical(domain)), Variable.withString(domainId),
        Variable.withString(_canonical(payload['topologyProfileRef'])), Variable<String>(null)]);
    await _delete('fire_address_claims', p, r, b);
    await _delete('fire_loop_device_assignments', p, r, b);
    var ordinal = 0;
    for (final raw in payload['deviceAssignments']! as List) {
      final row = Map<String,Object?>.from(raw as Map);
      final deviceId = row['deviceId']! as String;
      await runRawStatement(database,
        'INSERT INTO fire_loop_device_assignments (project_id, design_revision_id, binding_id, device_id, expansion_profile_ref_json, ordinal) VALUES (?, ?, ?, ?, ?, ?)', [
        Variable.withString(p), Variable.withString(r), Variable.withString(b), Variable.withString(deviceId),
        Variable.withString(_canonical({'profileRef': row['profileRef']})), Variable<int>(ordinal++)]);
      for (final address in (row['expandedAddresses']! as List).cast<int>()) {
        await runRawStatement(database,
          'INSERT INTO fire_address_claims (project_id, design_revision_id, binding_id, device_id, address_domain, address) VALUES (?, ?, ?, ?, ?, ?)', [
          Variable.withString(p), Variable.withString(r), Variable.withString(b), Variable.withString(deviceId),
          Variable.withString(domainId), Variable<int>(address)]);
      }
    }
  }

  Future<void> _replaceCircuit(String p, String r, String id, String b, int? rev, Map<String,Object?> payload, DateTime now) async {
    final output = Map<String,Object?>.from(payload['outputRef']! as Map);
    await _requireOutputPort(p, output['componentId']! as String, output['portId']! as String);
    for (final raw in payload['deviceAssignments']! as List) {
      await _requireComponentReference(p, Map<String,Object?>.from(raw as Map)['deviceId']! as String);
    }
    await _upsertRoot(
      table: 'notification_circuit_bindings', subjectColumn: 'circuit_id', p: p, r: r, subjectId: id,
      bindingId: b, expectedRevision: rev, now: now,
      columns: 'output_ref_json, policy_ref_json',
      values: [Variable.withString(_canonical(output)), Variable.withString(_canonical(payload['policyRef']))]);
    await _delete('notification_circuit_assignments', p, r, b);
    for (final raw in payload['deviceAssignments']! as List) {
      final row = Map<String,Object?>.from(raw as Map);
      await runRawStatement(database,
        'INSERT INTO notification_circuit_assignments (project_id, design_revision_id, binding_id, device_id, output_id, state_load_json) VALUES (?, ?, ?, ?, ?, ?)', [
        Variable.withString(p), Variable.withString(r), Variable.withString(b), Variable.withString(row['deviceId']! as String),
        Variable.withString(output['portId']! as String), Variable.withString(_canonical(row['stateCurrentMa']))]);
    }
  }

  Future<void> _upsertRoot({
    required String table, required String subjectColumn, required String p, required String r,
    required String subjectId, required String bindingId, required int? expectedRevision,
    required DateTime now, required String columns, required List<Variable> values,
  }) async {
    if (expectedRevision == null) {
      final placeholders = List.filled(values.length, '?').join(', ');
      await runRawStatement(database,
        'INSERT INTO $table (project_id, design_revision_id, id, revision, created_at, updated_at, deleted_at, origin_device_id, $subjectColumn, $columns) '
        'VALUES (?, ?, ?, 1, ?, ?, NULL, ?, ?, $placeholders)', [
        Variable.withString(p), Variable.withString(r), Variable.withString(bindingId), Variable<DateTime>(now.toUtc()),
        Variable<DateTime>(now.toUtc()), Variable.withString(originDeviceId), Variable.withString(subjectId), ...values]);
      return;
    }
    final assignments = columns.split(',').map((e) => '${e.trim()} = ?').join(', ');
    final changed = await database.customUpdate(
      'UPDATE $table SET revision = revision + 1, updated_at = ?, origin_device_id = ?, $assignments '
      'WHERE project_id = ? AND design_revision_id = ? AND id = ? AND $subjectColumn = ? '
      'AND revision = ? AND deleted_at IS NULL',
      variables: [Variable<DateTime>(now.toUtc()), Variable.withString(originDeviceId), ...values,
        Variable.withString(p), Variable.withString(r), Variable.withString(bindingId), Variable.withString(subjectId), Variable<int>(expectedRevision)]);
    if (changed != 1) throw StateError('ELV5_FIRE_ROOT_CAS_CONFLICT');
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

  Future<void> _requireOutputPort(String projectId, String componentId, String portId) async {
    final row = await database.customSelect(
      'SELECT 1 AS found FROM engineering_port_instances WHERE project_id = ? '
      'AND component_id = ? AND id = ? AND deleted_at IS NULL',
      variables: [Variable.withString(projectId), Variable.withString(componentId), Variable.withString(portId)],
    ).getSingleOrNull();
    if (row == null) throw StateError('ELV5_NOTIFICATION_OUTPUT_PORT_NOT_FOUND:$portId');
  }

  Map<String,Object?> _object(String value) => Map<String,Object?>.from(jsonDecode(value) as Map);
  String _canonical(Object? value) => utf8.decode(_encoder.encode(value), allowMalformed: false);
}
