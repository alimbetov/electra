import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import '../../database/app_database.dart';
import '../../database/drift_raw_statement.dart';

const elv5DisciplineSectionSchema = 'electra.elv5-discipline-freeze-section.v1';
const elv5SnapshotManifestSchema = 'electra.elv-snapshot-manifest.v2';
const elv5DisciplineAspectTables = <String>[
  'discipline_policy_bindings',
  'camera_stream_set_bindings',
  'camera_stream_bindings',
  'camera_stream_subscriptions',
  'recording_pool_bindings',
  'recording_assignments',
  'recording_schedule_segments',
  'recorder_capacity_bindings',
  'recorder_assignments',
  'link_composition_bindings',
  'link_section_assignments',
  'port_capacity_bindings',
  'port_capacity_assignments',
  'optical_link_bindings',
  'optical_loss_events',
  'rack_capacity_bindings',
  'rack_equipment_memberships',
  'patch_panel_bindings',
  'patch_panel_assignments',
  'door_calculation_bindings',
  'door_role_assignments',
  'door_release_truth_rows',
  'controller_resource_bindings',
  'controller_resource_assignments',
  'fire_loop_bindings',
  'fire_loop_device_assignments',
  'fire_address_claims',
  'notification_circuit_bindings',
  'notification_circuit_assignments',
];
const _roots = <String>{
  'discipline_policy_bindings',
  'camera_stream_set_bindings',
  'recording_pool_bindings',
  'recorder_capacity_bindings',
  'link_composition_bindings',
  'port_capacity_bindings',
  'optical_link_bindings',
  'rack_capacity_bindings',
  'patch_panel_bindings',
  'door_calculation_bindings',
  'controller_resource_bindings',
  'fire_loop_bindings',
  'notification_circuit_bindings',
};

/// Explicit dispatch preserves the exact legacy ELV4 manifest payload/hash.
String elvSnapshotManifestHash(Map<String, Object?> row) {
  final schema = row['manifest_schema'];
  final payload = <String, Object?>{
    'schema': schema,
    'physicalSha256': row['physical_sha256'],
    'powerSha256': row['power_sha256'],
  };
  if (schema == 'electra.elv4-snapshot-manifest.v1') {
    if (row['discipline_section_schema'] != null ||
        row['discipline_sha256'] != null)
      throw StateError('ELV5_MANIFEST_VERSION_MISMATCH');
  } else if (schema == elv5SnapshotManifestSchema) {
    if (row['discipline_section_schema'] != elv5DisciplineSectionSchema ||
        row['discipline_sha256'] is! String ||
        !RegExp(
          r'^[0-9a-f]{64}$',
        ).hasMatch(row['discipline_sha256']! as String))
      throw StateError('ELV5_MANIFEST_DISCIPLINE_HASH_REQUIRED');
    payload['disciplineSectionSchema'] = row['discipline_section_schema'];
    payload['disciplineSha256'] = row['discipline_sha256'];
  } else {
    throw StateError('ELV5_UNSUPPORTED_SNAPSHOT_MANIFEST');
  }
  return const Elv5CanonicalJsonV1().sha256(payload);
}

enum Elv5FrozenDisciplineReadKind { notCaptured, capturedEmpty, captured }

final class Elv5FrozenDisciplineRead {
  const Elv5FrozenDisciplineRead(this.kind, this.payload);
  final Elv5FrozenDisciplineReadKind kind;
  final Map<String, Object?>? payload;
  String? get reasonCode =>
      kind == Elv5FrozenDisciplineReadKind.notCaptured
          ? 'ELV5_NOT_CAPTURED'
          : null;
}

/// Captures source facts and immutable result identities before the existing
/// revision CAS. Frozen reads consult captured sections only, never live roots.
final class DriftElv5DisciplineSnapshotStore {
  const DriftElv5DisciplineSnapshotStore(
    this.database, {
    required this.originDeviceId,
    required this.nowUtc,
  });
  final AppDatabase database;
  final String originDeviceId;
  final DateTime Function() nowUtc;
  static const _encoder = Elv5CanonicalJsonV1();
  Future<List<Map<String, Object?>>> _rows(
    String sql,
    List<Variable> variables,
  ) async {
    final rows =
        (await database.customSelect(sql, variables: variables).get())
            .map((r) => Map<String, Object?>.from(r.data))
            .toList();
    rows.sort(
      (a, b) => utf8
          .decode(_encoder.encode(a))
          .compareTo(utf8.decode(_encoder.encode(b))),
    );
    return rows;
  }

  Future<String> capture({
    required String projectId,
    required String designRevisionId,
    required int expectedRevision,
    required String physicalSha256,
    required String powerSha256,
  }) => database.transaction(() async {
    final scope = [
      Variable.withString(projectId),
      Variable.withString(designRevisionId),
    ];
    final revision =
        await database
            .customSelect(
              'SELECT state,revision FROM project_design_revisions WHERE project_id=? AND id=? AND deleted_at IS NULL',
              variables: scope,
            )
            .getSingle();
    if (revision.read<String>('state') != 'WORKING')
      throw StateError('ELV5_DESIGN_REVISION_READ_ONLY');
    if (revision.read<int>('revision') != expectedRevision)
      throw StateError('ELV5_DESIGN_REVISION_CONFLICT');
    final facts = <String, Object?>{};
    var activeRoots = 0;
    for (final table in elv5DisciplineAspectTables) {
      final rows = await _rows(
        'SELECT * FROM $table WHERE project_id=? AND design_revision_id=?',
        scope,
      );
      facts[table] = rows;
      if (_roots.contains(table))
        activeRoots += rows.where((r) => r['deleted_at'] == null).length;
    }
    for (final table in [
      'elv_revision_aggregate_evidence_records',
      'discipline_evaluation_records',
      'discipline_evaluation_pointers',
      'discipline_dependency_index',
    ]) {
      facts[table] = await _rows(
        'SELECT * FROM $table WHERE project_id=? AND design_revision_id=?',
        scope,
      );
    }
    final evaluations = {
      for (final r
          in facts['discipline_evaluation_records']!
              as List<Map<String, Object?>>)
        r['evaluation_id']: r,
    };
    for (final row in evaluations.values) {
      if (_encoder.sha256(jsonDecode(row['output_json']! as String)) !=
              row['output_sha256'] ||
          _encoder.sha256(jsonDecode(row['evidence_json']! as String)) !=
              row['evidence_sha256'])
        throw StateError('ELV5_FREEZE_EVALUATION_HASH_MISMATCH');
    }
    for (final pointer
        in facts['discipline_evaluation_pointers']!
            as List<Map<String, Object?>>) {
      final id = pointer['evaluation_id'];
      final e = evaluations[id];
      if (id != null &&
          (e == null ||
              e['logical_node_key_sha256'] !=
                  pointer['logical_node_key_sha256'] ||
              e['input_fingerprint'] != pointer['input_fingerprint'] ||
              e['output_sha256'] != pointer['output_sha256']))
        throw StateError('ELV5_FREEZE_POINTER_EVIDENCE_MISMATCH');
    }
    for (final dependency
        in facts['discipline_dependency_index']!
            as List<Map<String, Object?>>) {
      if (_encoder.sha256(
            jsonDecode(dependency['dependency_key']! as String),
          ) !=
          dependency['dependency_key_sha256'])
        throw StateError('ELV5_DEPENDENCY_INDEX_HASH_MISMATCH');
    }
    // Canonical component/catalog/route facts are already captured by the power
    // section. ELV5 additionally owns exact room/surface geometry and contracts.
    final project = [Variable.withString(projectId)];
    facts['rooms'] = await _rows(
      'SELECT r.* FROM rooms r JOIN floors f ON f.id=r.floor_id WHERE f.project_id=?',
      project,
    );
    facts['surface_patches'] = await _rows(
      'SELECT p.* FROM surface_patches p JOIN rooms r ON r.id=p.room_id JOIN floors f ON f.id=r.floor_id WHERE f.project_id=?',
      project,
    );
    for (final item in [
      ('surface_edges', 'patch_id'),
      ('surface_adjacencies', 'from_patch_id'),
      ('openings', 'host_surface_patch_id'),
      ('spatial_features', 'host_surface_patch_id'),
    ]) {
      facts[item.$1] = await _rows(
        'SELECT x.* FROM ${item.$1} x JOIN surface_patches p ON p.id=x.${item.$2} JOIN rooms r ON r.id=p.room_id JOIN floors f ON f.id=r.floor_id WHERE f.project_id=?',
        project,
      );
    }
    final payload = <String, Object?>{
      'schema': elv5DisciplineSectionSchema,
      'projectId': projectId,
      'designRevisionId': designRevisionId,
      'revisionToken': expectedRevision,
      'physicalSha256': physicalSha256,
      'powerSha256': powerSha256,
      'activeRootCount': activeRoots,
      'facts': facts,
    };
    final json = utf8.decode(_encoder.encode(payload));
    final hash = _encoder.sha256(payload);
    final instant = nowUtc().toUtc();
    final manifest =
        await database
            .customSelect(
              'SELECT * FROM design_revision_snapshot_manifests WHERE project_id=? AND design_revision_id=?',
              variables: scope,
            )
            .getSingle();
    if (manifest.read<String>('manifest_schema') !=
            'electra.elv4-snapshot-manifest.v1' ||
        manifest.read<String>('manifest_sha256') !=
            elvSnapshotManifestHash(manifest.data) ||
        manifest.read<String>('physical_sha256') != physicalSha256 ||
        manifest.read<String>('power_sha256') != powerSha256)
      throw StateError('ELV5_FREEZE_SOURCE_MANIFEST_MISMATCH');
    await runRawStatement(
      database,
      'INSERT INTO design_revision_discipline_snapshots (design_revision_id,project_id,section_schema,capture_kind,payload_json,discipline_sha256,physical_sha256,power_sha256,created_at,origin_device_id) VALUES (?,?,?,?,?,?,?,?,?,?)',
      [
        Variable.withString(designRevisionId),
        Variable.withString(projectId),
        Variable.withString(elv5DisciplineSectionSchema),
        Variable.withString('FREEZE'),
        Variable.withString(json),
        Variable.withString(hash),
        Variable.withString(physicalSha256),
        Variable.withString(powerSha256),
        Variable<DateTime>(instant),
        Variable.withString(originDeviceId),
      ],
    );
    final extended = <String, Object?>{
      ...manifest.data,
      'manifest_schema': elv5SnapshotManifestSchema,
      'discipline_section_schema': elv5DisciplineSectionSchema,
      'discipline_sha256': hash,
    };
    final changed = await database.customUpdate(
      'UPDATE design_revision_snapshot_manifests SET manifest_schema=?,manifest_sha256=?,discipline_section_schema=?,discipline_sha256=? WHERE project_id=? AND design_revision_id=? AND manifest_schema=?',
      variables: [
        Variable.withString(elv5SnapshotManifestSchema),
        Variable.withString(elvSnapshotManifestHash(extended)),
        Variable.withString(elv5DisciplineSectionSchema),
        Variable.withString(hash),
        ...scope,
        Variable.withString('electra.elv4-snapshot-manifest.v1'),
      ],
    );
    if (changed != 1) throw StateError('ELV5_FREEZE_MANIFEST_CAS_FAILED');
    return hash;
  });
  Future<Elv5FrozenDisciplineRead> read({
    required String projectId,
    required String designRevisionId,
  }) async {
    final scope = [
      Variable.withString(projectId),
      Variable.withString(designRevisionId),
    ];
    final manifest =
        await database
            .customSelect(
              'SELECT * FROM design_revision_snapshot_manifests WHERE project_id=? AND design_revision_id=?',
              variables: scope,
            )
            .getSingleOrNull();
    if (manifest == null ||
        manifest.read<String>('manifest_schema') ==
            'electra.elv4-snapshot-manifest.v1') {
      if (manifest != null &&
          manifest.read<String>('manifest_sha256') !=
              elvSnapshotManifestHash(manifest.data))
        throw StateError('ELV5_FROZEN_MANIFEST_HASH_MISMATCH');
      return const Elv5FrozenDisciplineRead(
        Elv5FrozenDisciplineReadKind.notCaptured,
        null,
      );
    }
    if (manifest.read<String>('manifest_sha256') !=
        elvSnapshotManifestHash(manifest.data))
      throw StateError('ELV5_FROZEN_MANIFEST_HASH_MISMATCH');
    final row =
        await database
            .customSelect(
              'SELECT * FROM design_revision_discipline_snapshots WHERE project_id=? AND design_revision_id=?',
              variables: scope,
            )
            .getSingleOrNull();
    if (row == null) throw StateError('ELV5_FROZEN_SECTION_MISSING');
    final value = jsonDecode(row.read<String>('payload_json'));
    if (value is! Map) throw StateError('ELV5_FROZEN_SECTION_INVALID');
    final payload = Map<String, Object?>.from(value);
    if (row.read<String>('section_schema') != elv5DisciplineSectionSchema ||
        payload['schema'] != elv5DisciplineSectionSchema ||
        payload['projectId'] != projectId ||
        payload['designRevisionId'] != designRevisionId ||
        row.read<String>('discipline_sha256') != _encoder.sha256(payload) ||
        row.read<String>('discipline_sha256') !=
            manifest.read<String>('discipline_sha256') ||
        payload['physicalSha256'] != manifest.read<String>('physical_sha256') ||
        payload['powerSha256'] != manifest.read<String>('power_sha256') ||
        row.read<String>('physical_sha256') != payload['physicalSha256'] ||
        row.read<String>('power_sha256') != payload['powerSha256'])
      throw StateError('ELV5_FROZEN_SECTION_HASH_MISMATCH');
    final physical =
        await database
            .customSelect(
              'SELECT * FROM design_revision_physical_snapshots WHERE project_id=? AND design_revision_id=?',
              variables: scope,
            )
            .getSingle();
    if (DesignRevisionPhysicalSnapshot(
          designRevisionId: designRevisionId,
          projectId: projectId,
          schemaVersion: physical.read<int>('schema_version'),
          payload: Map<String, dynamic>.from(
            jsonDecode(physical.read<String>('payload_json')) as Map,
          ),
        ).contentSha256 !=
        payload['physicalSha256'])
      throw StateError('ELV5_FROZEN_PHYSICAL_HASH_MISMATCH');
    final power =
        await database
            .customSelect(
              'SELECT payload_json,power_sha256,physical_sha256 FROM design_revision_power_snapshots WHERE project_id=? AND design_revision_id=?',
              variables: scope,
            )
            .getSingle();
    if (physical.read<String>('payload_sha256') != payload['physicalSha256'] ||
        power.read<String>('physical_sha256') != payload['physicalSha256'] ||
        sha256HexUtf8(power.read<String>('payload_json')) !=
            payload['powerSha256'] ||
        power.read<String>('power_sha256') != payload['powerSha256'])
      throw StateError('ELV5_FROZEN_POWER_HASH_MISMATCH');
    final count = payload['activeRootCount'];
    if (count is! int || count < 0 || payload['facts'] is! Map)
      throw StateError('ELV5_FROZEN_SECTION_INVALID');
    return Elv5FrozenDisciplineRead(
      count == 0
          ? Elv5FrozenDisciplineReadKind.capturedEmpty
          : Elv5FrozenDisciplineReadKind.captured,
      Map.unmodifiable(payload),
    );
  }
}
