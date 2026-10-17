import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core.dart';

import '../database/app_database.dart';
import '../database/drift_raw_statement.dart';

/// Ordered parents before children. Receipts, history and derived evaluations
/// are evidence of R1, never mutable configuration to clone into R2.
const powerAspectTables = <String>[
  'power_port_bindings',
  'power_component_bindings',
  'power_transfer_bindings',
  'power_transfer_outputs',
  'power_load_bindings',
  'power_capacity_groups',
  'power_capacity_group_members',
  'power_supply_requirements',
  'power_supply_requirement_inputs',
  'power_operating_scenarios',
  'power_scenario_segments',
  'power_scenario_states',
  'power_scenario_source_selections',
  'power_scenario_unavailable_sources',
  'poe_delivery_bindings',
  'poe_delivery_path_members',
  'backup_assemblies',
  'backup_protected_outputs',
  'battery_bank_bindings',
];

final class DriftPowerSnapshotFacts {
  const DriftPowerSnapshotFacts(this.database);
  final AppDatabase database;

  Future<List<Map<String, Object?>>> rows(String sql, String scope) async {
    final values = await database
        .customSelect(sql, variables: [Variable.withString(scope)])
        .get();
    final result = values
        .map((r) => Map<String, Object?>.from(r.data))
        .toList();
    result.sort(
      (a, b) =>
          canonicalEngineeringJsonV1(a)
              .compareTo(canonicalEngineeringJsonV1(b)),
    );
    return result;
  }

  Future<Map<String, Object?>> capture(
    String projectId,
    String revisionId,
  ) async {
    final facts = <String, Object?>{};
    for (final table in powerAspectTables) {
      facts[table] = await rows(
        'SELECT * FROM $table WHERE design_revision_id = ?',
        revisionId,
      );
    }
    for (final table in <String>[
      'engineering_port_instances',
      'engineering_port_connections',
      'engineering_internal_mappings',
      'engineering_topology_groups',
      'engineering_compatibility_profiles',
      'engineering_reference_catalogs',
      'project_engineering_systems',
      'elv_cables',
      'cable_allocations',
      'component_reference_bindings',
      'route_handoffs',
      'route_bend_evidence',
      'physical_carriers',
      'pathway_contexts',
    ]) {
      // All these canonical tables carry exact project scope.
      facts[table] = await rows(
        'SELECT * FROM $table WHERE project_id = ?',
        projectId,
      );
    }
    facts['physical_carrier_compartments'] = await rows(
      'SELECT c.* FROM physical_carrier_compartments c '
      'JOIN physical_carriers p ON p.id = c.carrier_id WHERE p.project_id = ?',
      projectId,
    );
    facts['component_engineering_memberships'] = await rows(
      'SELECT m.* FROM component_engineering_memberships m '
      'JOIN project_engineering_systems s ON s.id = m.system_id WHERE s.project_id = ?',
      projectId,
    );
    for (final table in [
      'cable_allocation_resource_selections',
      'cable_termination_mappings',
      'cable_resource_claims',
    ]) {
      facts[table] = await rows(
        'SELECT x.* FROM $table x JOIN cable_allocations a '
        'ON a.id = x.allocation_id WHERE a.project_id = ?',
        projectId,
      );
    }
    facts['component_locations'] = await rows(
      'SELECT ci.*, r.floor_id FROM component_instances ci '
      'JOIN rooms r ON r.id = ci.room_id JOIN floors f ON f.id = r.floor_id '
      'WHERE f.project_id = ?',
      projectId,
    );
    facts['traversal_carrier_assignments'] = await rows(
      'SELECT * FROM traversal_carrier_assignments WHERE design_revision_id = ?',
      revisionId,
    );
    facts['canonical_cable_runs'] = await rows(
      'SELECT * FROM canonical_cable_runs WHERE design_revision_id = ?',
      revisionId,
    );
    facts['cable_run_traversals'] = await rows(
      'SELECT t.* FROM cable_run_traversals t JOIN canonical_cable_runs r '
      'ON r.id = t.cable_run_id WHERE r.design_revision_id = ?',
      revisionId,
    );
    facts['overlay_geometry'] = await rows(
      'SELECT r.id AS run_id, t.route_segment_id AS segment_id, '
      's.surface_patch_id AS patch_id, '
      'CASE WHEN fn.patch_id = s.surface_patch_id THEN fn.local_xmm ELSE fn.other_local_xmm END AS from_x, '
      'CASE WHEN fn.patch_id = s.surface_patch_id THEN fn.local_ymm ELSE fn.other_local_ymm END AS from_y, '
      'CASE WHEN tn.patch_id = s.surface_patch_id THEN tn.local_xmm ELSE tn.other_local_xmm END AS to_x, '
      'CASE WHEN tn.patch_id = s.surface_patch_id THEN tn.local_ymm ELSE tn.other_local_ymm END AS to_y, '
      't.sequence AS traversal_sequence FROM cable_run_traversals t '
      'JOIN canonical_cable_runs r ON r.id = t.cable_run_id '
      'JOIN cable_route_segments s ON s.id = t.route_segment_id '
      'JOIN cable_route_nodes fn ON fn.id = s.from_node_id '
      'JOIN cable_route_nodes tn ON tn.id = s.to_node_id '
      'WHERE r.design_revision_id = ? AND r.deleted_at IS NULL '
      'AND t.deleted_at IS NULL AND s.deleted_at IS NULL',
      revisionId,
    );
    facts['evaluation_records'] = await rows(
      'SELECT * FROM power_evaluation_records WHERE design_revision_id = ?',
      revisionId,
    );
    return facts;
  }

  /// Restore only configuration; CURRENT evidence is intentionally not copied.
  /// Exact identities in JSON physical evidence follow the same explicit map as
  /// run/traversal materialization. Substrings and arbitrary labels never remap.
  Future<void> materialize({
    required String projectId,
    required String revisionId,
    required Map<String, Object?> captured,
    required Map<String, String> physicalIds,
    required DateTime now,
    required String originDeviceId,
  }) async {
    final facts = captured['facts'];
    if (facts is! Map)
      return; // v1 captured pointers never imply invented facts.
    const refFields = {
      'runId',
      'cableRunId',
      'traversalId',
      'traversalIds',
      'cable_run_id',
      'traversal_id',
    };
    Object? remap(Object? value, [String? field]) {
      if (value is String)
        return refFields.contains(field) ? physicalIds[value] ?? value : value;
      if (value is List) return value.map((v) => remap(v, field)).toList();
      if (value is Map)
        return value.map(
          (k, v) => MapEntry(k.toString(), remap(v, k.toString())),
        );
      return value;
    }

    for (final table in [
      ...powerAspectTables,
      'traversal_carrier_assignments',
    ]) {
      for (final original in capturedPowerRows(captured, table)) {
        final row = Map<String, Object?>.from(original);
        row['project_id'] = projectId;
        row['design_revision_id'] = revisionId;
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
            row[key] = canonicalEngineeringJsonV1(remap(jsonDecode(value)));
          } else if (refFields.contains(key) &&
              value is String &&
              physicalIds.containsKey(value)) {
            row[key] = physicalIds[value];
          }
        }
        if (row.containsKey('resolved_profile_json')) {
          row['profile_sha256'] = sha256HexUtf8(
            row['resolved_profile_json']! as String,
          );
        }
        final columns = row.keys.toList();
        await runRawStatement(
          database,
          'INSERT INTO $table (${columns.join(',')}) VALUES (${List.filled(columns.length, '?').join(',')})',
          columns.map((key) => row[key]).toList(),
        );
      }
    }
  }
}

List<Map<String, Object?>> capturedPowerRows(
  Map<String, Object?>? capture,
  String table,
) {
  final facts = capture?['facts'];
  final values = facts is Map ? facts[table] : null;
  if (values is! List) return const [];
  return values.map((row) => (row as Map).cast<String, Object?>()).toList();
}
