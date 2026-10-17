import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core_elv5.dart';

import '../../../application/elv5/lan/elv5_lan_rack_persistence.dart';
import '../../../application/elv5/persistence/elv5_replacement_persistence.dart';
import '../../../application/elv5/persistence/elv5_runtime_persistence.dart';
import '../../../application/elv_write_unit_of_work.dart';
import '../../database/app_database.dart';
import '../../database/drift_raw_statement.dart';
import 'drift_elv5_replacement_write_unit_of_work.dart';

final class DriftElv5LanRackWriteUnitOfWork
    implements Elv5LanRackWriteUnitOfWork {
  const DriftElv5LanRackWriteUnitOfWork(
    this.database, {
    required this.originDeviceId,
  });

  final AppDatabase database;
  final String originDeviceId;

  @override
  Future<T> run<T>(
    Future<T> Function(Elv5LanRackWriteSession session) action,
  ) =>
      DriftElv5ReplacementWriteUnitOfWork(
        database,
        originDeviceId: originDeviceId,
      ).run(
        (replacement) => action(
          _Session(
            replacement,
            racks: _Store(database, originDeviceId: originDeviceId),
          ),
        ),
      );
}

final class _Session implements Elv5LanRackWriteSession {
  const _Session(this.replacement, {required this.racks});
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
  final Elv5LanRackMutationStore racks;
}

final class _Store implements Elv5LanRackMutationStore {
  const _Store(this.database, {required this.originDeviceId});
  static const _encoder = Elv5CanonicalJsonV1();
  final AppDatabase database;
  final String originDeviceId;

  @override
  Future<Elv5LanRackSnapshot?> loadRack({
    required String projectId,
    required String designRevisionId,
    required String rackId,
  }) async {
    final root = await database
        .customSelect(
          'SELECT id, revision, capacity_basis, capacity_json, excluded_capacity_json, '
          'exclusion_provenance_json, policy_ref_json FROM rack_capacity_bindings '
          'WHERE project_id = ? AND design_revision_id = ? AND rack_id = ? '
          'AND deleted_at IS NULL',
          variables: [
            Variable.withString(projectId),
            Variable.withString(designRevisionId),
            Variable.withString(rackId),
          ],
        )
        .getSingleOrNull();
    if (root == null) return null;
    final bindingId = root.read<String>('id');
    final members = await database
        .customSelect(
          'SELECT equipment_id FROM rack_equipment_memberships WHERE project_id = ? '
          'AND design_revision_id = ? AND binding_id = ? ORDER BY ordinal, equipment_id',
          variables: [
            Variable.withString(projectId),
            Variable.withString(designRevisionId),
            Variable.withString(bindingId),
          ],
        )
        .get();
    final excluded = _object(root.read<String>('excluded_capacity_json'));
    final provenance = _object(root.read<String>('exclusion_provenance_json'));
    final policyJson = root.readNullable<String>('policy_ref_json');
    return Elv5LanRackSnapshot(
      aggregateId: bindingId,
      rackId: rackId,
      revision: root.read<int>('revision'),
      payload: {
        'rackId': rackId,
        'capacityBasis': root.read<String>('capacity_basis'),
        'equipmentIds': [
          for (final row in members) row.read<String>('equipment_id'),
        ],
        'excludedCapacity': {
          ...excluded,
          'provenance': provenance['provenance'],
        },
        'policyRef': policyJson == null ? null : jsonDecode(policyJson),
      },
      capturedRackProfile: _object(root.read<String>('capacity_json')),
    );
  }

  @override
  Future<void> replaceRack({
    required String projectId,
    required String designRevisionId,
    required String rackId,
    required String bindingId,
    required int? expectedRootRevision,
    required Map<String, Object?> payload,
    required DateTime updatedAtUtc,
  }) async {
    final rackProfile = await _componentReferenceSnapshot(projectId, rackId);
    final equipmentIds = (payload['equipmentIds']! as List).cast<String>();
    for (final equipmentId in equipmentIds) {
      await _componentReferenceSnapshot(projectId, equipmentId);
    }
    final excluded = Map<String, Object?>.from(
      payload['excludedCapacity']! as Map,
    );
    final excludedJson = _canonical({
      'reservedRu': excluded['reservedRu'],
      'unavailableRu': excluded['unavailableRu'],
    });
    final provenanceJson = _canonical({'provenance': excluded['provenance']});
    final policy = payload['policyRef'];
    final capacityJson = _canonical(rackProfile);

    if (expectedRootRevision == null) {
      await runRawStatement(
        database,
        'INSERT INTO rack_capacity_bindings '
        '(project_id, design_revision_id, id, revision, created_at, updated_at, '
        'deleted_at, origin_device_id, rack_id, capacity_basis, capacity_json, '
        'excluded_capacity_json, exclusion_provenance_json, policy_ref_json) '
        'VALUES (?, ?, ?, 1, ?, ?, NULL, ?, ?, ?, ?, ?, ?, ?)',
        [
          Variable.withString(projectId),
          Variable.withString(designRevisionId),
          Variable.withString(bindingId),
          Variable<DateTime>(updatedAtUtc.toUtc()),
          Variable<DateTime>(updatedAtUtc.toUtc()),
          Variable.withString(originDeviceId),
          Variable.withString(rackId),
          Variable.withString(payload['capacityBasis']! as String),
          Variable.withString(capacityJson),
          Variable.withString(excludedJson),
          Variable.withString(provenanceJson),
          Variable<String>(policy == null ? null : _canonical(policy)),
        ],
      );
    } else {
      final changed = await database.customUpdate(
        'UPDATE rack_capacity_bindings SET revision = revision + 1, updated_at = ?, '
        'origin_device_id = ?, capacity_basis = ?, capacity_json = ?, '
        'excluded_capacity_json = ?, exclusion_provenance_json = ?, policy_ref_json = ? '
        'WHERE project_id = ? AND design_revision_id = ? AND id = ? AND rack_id = ? '
        'AND revision = ? AND deleted_at IS NULL',
        variables: [
          Variable<DateTime>(updatedAtUtc.toUtc()),
          Variable.withString(originDeviceId),
          Variable.withString(payload['capacityBasis']! as String),
          Variable.withString(capacityJson),
          Variable.withString(excludedJson),
          Variable.withString(provenanceJson),
          Variable<String>(policy == null ? null : _canonical(policy)),
          Variable.withString(projectId),
          Variable.withString(designRevisionId),
          Variable.withString(bindingId),
          Variable.withString(rackId),
          Variable<int>(expectedRootRevision),
        ],
      );
      if (changed != 1) throw StateError('ELV5_LAN_RACK_ROOT_CAS_CONFLICT');
    }

    await database.customUpdate(
      'DELETE FROM rack_equipment_memberships WHERE project_id = ? '
      'AND design_revision_id = ? AND binding_id = ?',
      variables: [
        Variable.withString(projectId),
        Variable.withString(designRevisionId),
        Variable.withString(bindingId),
      ],
    );
    for (var i = 0; i < equipmentIds.length; i++) {
      await runRawStatement(
        database,
        'INSERT INTO rack_equipment_memberships '
        '(project_id, design_revision_id, binding_id, equipment_id, ordinal) '
        'VALUES (?, ?, ?, ?, ?)',
        [
          Variable.withString(projectId),
          Variable.withString(designRevisionId),
          Variable.withString(bindingId),
          Variable.withString(equipmentIds[i]),
          Variable<int>(i),
        ],
      );
    }
  }

  Future<Map<String, Object?>> _componentReferenceSnapshot(
    String projectId,
    String componentId,
  ) async {
    final row = await database
        .customSelect(
          'SELECT b.catalog_id, b.profile_code, b.payload_json, c.catalog_version '
          'FROM component_reference_bindings b '
          'JOIN engineering_reference_catalogs c ON c.id = b.catalog_id '
          'WHERE b.project_id = ? AND b.component_id = ? AND b.deleted_at IS NULL '
          'AND c.deleted_at IS NULL',
          variables: [
            Variable.withString(projectId),
            Variable.withString(componentId),
          ],
        )
        .getSingleOrNull();
    if (row == null) {
      throw StateError(
        'ELV5_COMPONENT_REFERENCE_BINDING_NOT_FOUND:$componentId',
      );
    }
    final payload = jsonDecode(row.read<String>('payload_json'));
    return {
      'componentId': componentId,
      'catalogId': row.read<String>('catalog_id'),
      'catalogVersion': row.read<String>('catalog_version'),
      'profileCode': row.read<String>('profile_code'),
      'profileSnapshot': payload,
      'profileSnapshotSha256': _encoder.sha256(payload),
    };
  }

  Map<String, Object?> _object(String value) =>
      Map<String, Object?>.from(jsonDecode(value) as Map);
  String _canonical(Object? value) =>
      utf8.decode(_encoder.encode(value), allowMalformed: false);
}
