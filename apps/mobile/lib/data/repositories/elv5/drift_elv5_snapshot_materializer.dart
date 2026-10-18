import 'dart:convert';
import 'package:engineering_core/engineering_core_elv5.dart';
import '../../database/app_database.dart';
import '../../database/drift_raw_statement.dart';
import 'drift_elv5_contract_identity.dart';
import 'drift_elv5_discipline_snapshot_store.dart';

/// Materializes mutable configuration only. Derived results, pointers, command
/// receipts and history keep their original immutable revision ownership.
final class DriftElv5SnapshotMaterializer {
  const DriftElv5SnapshotMaterializer(this.database);
  final AppDatabase database;
  static const _encoder = Elv5CanonicalJsonV1();
  static const _parents = <String, String>{
    'camera_stream_bindings': 'camera_stream_set_bindings',
    'camera_stream_subscriptions': 'camera_stream_set_bindings',
    'recording_assignments': 'recording_pool_bindings',
    'recording_schedule_segments': 'recording_pool_bindings',
    'recorder_assignments': 'recorder_capacity_bindings',
    'link_section_assignments': 'link_composition_bindings',
    'port_capacity_assignments': 'port_capacity_bindings',
    'optical_loss_events': 'optical_link_bindings',
    'rack_equipment_memberships': 'rack_capacity_bindings',
    'patch_panel_assignments': 'patch_panel_bindings',
    'door_role_assignments': 'door_calculation_bindings',
    'door_release_truth_rows': 'door_calculation_bindings',
    'controller_resource_assignments': 'controller_resource_bindings',
    'fire_loop_device_assignments': 'fire_loop_bindings',
    'fire_address_claims': 'fire_loop_bindings',
    'notification_circuit_assignments': 'notification_circuit_bindings',
  };

  Future<void> materialize({
    required String projectId,
    required String revisionId,
    required Map<String, Object?> captured,
    required Map<String, String> physicalIds,
    required DateTime now,
    required String originDeviceId,
  }) async {
    final facts = captured['facts'];
    if (facts is! Map || captured['schema'] != elv5DisciplineSectionSchema) {
      throw StateError('ELV5_MATERIALIZATION_CAPTURE_INVALID');
    }
    List<Map<String, Object?>> rows(String table) =>
        (facts[table] as List? ?? const [])
            .map((r) => Map<String, Object?>.from(r as Map))
            .toList();
    final roots = <String, Map<String, String>>{};
    for (final table in elv5DisciplineAspectTables.where(
      (t) => !_parents.containsKey(t),
    )) {
      roots[table] = {
        for (final row in rows(table))
          row['id']! as String: '$revisionId:elv5:$table:${row['id']}',
      };
    }
    const physicalFields = {
      'runId',
      'cableRunId',
      'traversalId',
      'traversalIds',
      'realizedSectionId',
      'sectionId',
      'routeSectionId',
      'realized_section_id',
      'cable_run_id',
      'traversal_id',
      'subject_id',
    };
    Object? remap(Object? value, [String? field]) {
      if (value is String) {
        if (physicalFields.contains(field)) return physicalIds[value] ?? value;
        if ((field == 'designRevisionId' || field == 'scopeId') &&
            value == captured['designRevisionId'])
          return revisionId;
        if (field == 'policyBindingId' || field == 'policy_binding_id')
          return roots['discipline_policy_bindings']?[value] ?? value;
        return value;
      }
      if (value is List) return value.map((v) => remap(v, field)).toList();
      if (value is Map) {
        return value.map(
          (k, v) => MapEntry(
            field == 'poweredSectionToDeliveryId'
                ? physicalIds[k.toString()] ?? k.toString()
                : k.toString(),
            remap(v, k.toString()),
          ),
        );
      }
      return value;
    }

    final editions = <String, Map<String, String>>{};
    final evidence = {
      for (final row in rows('elv_revision_aggregate_evidence_records'))
        row['evidence_ref']: row,
    };
    for (final binding in rows('discipline_policy_bindings')) {
      final definition =
          jsonDecode(binding['definition_ref_json']! as String) as Map;
      final oldRef = definition['editionId'];
      final original = evidence[oldRef];
      if (original == null || editions.containsKey(oldRef)) continue;
      final originalPayload = jsonDecode(
        original['canonical_payload_json']! as String,
      );
      if (_encoder.sha256(originalPayload) != original['payload_sha256'] ||
          original['payload_sha256'] != definition['contentHash']) {
        throw StateError('ELV5_MATERIALIZATION_CONTRACT_HASH_MISMATCH');
      }
      final payload = remap(originalPayload);
      final hash = _encoder.sha256(payload);
      final subjectId =
          physicalIds[original['aggregate_id']] ??
          original['aggregate_id']! as String;
      final ref = elv5ContractEvidenceRef(
        projectId: projectId,
        designRevisionId: revisionId,
        kind: (oldRef! as String).split(':').first,
        subjectId: subjectId,
        payloadSha256: hash,
      );
      final row = <String, Object?>{
        ...original,
        'evidence_ref': ref,
        'project_id': projectId,
        'design_revision_id': revisionId,
        'aggregate_id': subjectId,
        'canonical_payload_json': _json(payload),
        'payload_sha256': hash,
        'created_at': now.toUtc().millisecondsSinceEpoch ~/ 1000,
        'origin_device_id': originDeviceId,
      };
      await _insert('elv_revision_aggregate_evidence_records', row);
      editions[oldRef] = {'ref': ref, 'hash': hash};
    }
    for (final table in elv5DisciplineAspectTables) {
      for (final original in rows(table)) {
        final row = Map<String, Object?>.from(original);
        row['project_id'] = projectId;
        row['design_revision_id'] = revisionId;
        if (row.containsKey('id')) row['id'] = roots[table]![row['id']];
        if (_parents.containsKey(table))
          row['binding_id'] = roots[_parents[table]]![row['binding_id']];
        if (row.containsKey('revision')) row['revision'] = 1;
        for (final key in ['created_at', 'updated_at']) {
          if (row.containsKey(key))
            row[key] = now.toUtc().millisecondsSinceEpoch ~/ 1000;
        }
        if (row.containsKey('origin_device_id'))
          row['origin_device_id'] = originDeviceId;
        for (final key in row.keys.toList()) {
          final value = row[key];
          if (key.endsWith('_json') && value is String) {
            final decoded = remap(jsonDecode(value));
            if (table == 'discipline_policy_bindings' &&
                key == 'definition_ref_json' &&
                decoded is Map) {
              final edition = editions[decoded['editionId']];
              if (edition != null) {
                decoded['editionId'] = edition['ref'];
                decoded['contentHash'] = edition['hash'];
                row['definition_sha256'] = edition['hash'];
              }
            }
            row[key] = _json(decoded);
            // Only rehash actual changed payloads; definition-ref companion
            // hashes are content hashes of referenced immutable definitions.
            final hashKey = '${key.substring(0, key.length - 5)}_sha256';
            if (!key.endsWith('_ref_json') && row.containsKey(hashKey))
              row[hashKey] = _encoder.sha256(decoded);
          } else {
            row[key] = remap(value, key);
          }
        }
        await _insert(table, row);
      }
    }
  }

  String _json(Object? value) => utf8.decode(_encoder.encode(value));
  Future<void> _insert(
    String table,
    Map<String, Object?> row,
  ) => runRawStatement(
    database,
    'INSERT INTO $table (${row.keys.join(',')}) VALUES (${List.filled(row.length, '?').join(',')})',
    row.values.toList(),
  );
}
