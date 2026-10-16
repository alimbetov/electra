import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core.dart';

import '../../application/elv4_wire_command_dispatcher.dart';
import '../../application/elv4_wire_power_payload.dart';
import '../database/app_database.dart';
import '../database/drift_raw_statement.dart';
import 'drift_power_command_service.dart';
import 'drift_power_publication_runtime.dart';
import 'drift_power_runtime_store.dart';

/// Durable public-wire aggregate mutations that cannot be represented by the
/// older singular internal commands without multiple design-token advances.
final class DriftElv4WireAggregateService {
  DriftElv4WireAggregateService(
    this.database, {
    required this.originDeviceId,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now,
       runtimeStore = DriftPowerRuntimeStore(
         database,
         originDeviceId: originDeviceId,
         now: now,
       ),
       publicationRuntime = DriftPowerPublicationRuntime(
         database,
         originDeviceId: originDeviceId,
         now: now,
       );

  final AppDatabase database;
  final String originDeviceId;
  final DateTime Function() now;
  final DriftPowerRuntimeStore runtimeStore;
  final DriftPowerPublicationRuntime publicationRuntime;

  Future<PowerMutationReceipt> replaceLoadProfile({
    required Elv4WireCommandEnvelope envelope,
    required Iterable<String> changedDependencyRefs,
    required String componentId,
    required Iterable<Elv4WireLoadEntry> loads,
  }) async {
    _requireOperation(envelope, 'SET_POWER_LOAD_PROFILE');
    final normalizedComponentId = _text(componentId, 'componentId');
    final values = List<Elv4WireLoadEntry>.unmodifiable(loads);
    _requireUnique(values.map((value) => value.loadId), 'loadId');
    final dependencies = _dependencies(envelope, changedDependencyRefs);
    await publicationRuntime.ensureRuntimeSchema();
    final replay = await runtimeStore.executeReplayable(
      projectId: envelope.projectId,
      designRevisionId: envelope.designRevisionId,
      operationId: envelope.commandId,
      commandType: envelope.operation,
      payloadSchema: _ledgerSchema(envelope),
      commandFingerprint: _fingerprint(envelope),
      execute: () async {
        final oldIds = await _activeLoadIds(envelope, normalizedComponentId);
        final invalidation = await publicationRuntime.mutateAndInvalidate(
          projectId: envelope.projectId,
          designRevisionId: envelope.designRevisionId,
          oldClosure: dependencies,
          applyMutation: () async {
            await _replaceLoads(envelope, normalizedComponentId, values);
            await _advanceDesignRevision(envelope);
          },
          captureNewClosure: () async => dependencies,
        );
        final affected = {...oldIds, ...values.map((value) => value.loadId)}.toList()
          ..sort();
        return canonicalEngineeringJsonV1(
          PowerMutationReceipt(
            operationId: envelope.commandId,
            projectId: envelope.projectId,
            designRevisionId: envelope.designRevisionId,
            previousRevision: invalidation.previousRevisionToken,
            currentRevision: invalidation.currentRevisionToken,
            affectedIds: affected,
            invalidatedNodeKeys: invalidation.invalidatedNodeKeys,
            replayed: false,
          ).toMap(),
        );
      },
    );
    return PowerMutationReceipt.fromMap(
      (jsonDecode(replay.resultJson) as Map).cast<String, Object?>(),
      replayed: replay.replayed,
    );
  }

  Future<PowerMutationReceipt> replaceTransfers({
    required Elv4WireCommandEnvelope envelope,
    required Iterable<String> changedDependencyRefs,
    required String componentId,
    required Iterable<Elv4WireTransferEntry> transfers,
  }) async {
    _requireOperation(envelope, 'REPLACE_POWER_TRANSFERS');
    final normalizedComponentId = _text(componentId, 'componentId');
    final values = List<Elv4WireTransferEntry>.unmodifiable(transfers);
    _requireUnique(values.map((value) => value.id), 'transferId');
    if (values.any((value) => value.componentId != normalizedComponentId)) {
      throw const PowerRuntimeStorageException(
        'ELV4_TRANSFER_COMPONENT_SCOPE_MISMATCH',
      );
    }
    final dependencies = _dependencies(envelope, changedDependencyRefs);
    await publicationRuntime.ensureRuntimeSchema();
    final replay = await runtimeStore.executeReplayable(
      projectId: envelope.projectId,
      designRevisionId: envelope.designRevisionId,
      operationId: envelope.commandId,
      commandType: envelope.operation,
      payloadSchema: _ledgerSchema(envelope),
      commandFingerprint: _fingerprint(envelope),
      execute: () async {
        final oldIds = await _activeTransferIds(envelope, normalizedComponentId);
        final invalidation = await publicationRuntime.mutateAndInvalidate(
          projectId: envelope.projectId,
          designRevisionId: envelope.designRevisionId,
          oldClosure: dependencies,
          applyMutation: () async {
            await _replaceTransfers(envelope, normalizedComponentId, values);
            await _advanceDesignRevision(envelope);
          },
          captureNewClosure: () async => dependencies,
        );
        final affected = {...oldIds, ...values.map((value) => value.id)}.toList()
          ..sort();
        return canonicalEngineeringJsonV1(
          PowerMutationReceipt(
            operationId: envelope.commandId,
            projectId: envelope.projectId,
            designRevisionId: envelope.designRevisionId,
            previousRevision: invalidation.previousRevisionToken,
            currentRevision: invalidation.currentRevisionToken,
            affectedIds: affected,
            invalidatedNodeKeys: invalidation.invalidatedNodeKeys,
            replayed: false,
          ).toMap(),
        );
      },
    );
    return PowerMutationReceipt.fromMap(
      (jsonDecode(replay.resultJson) as Map).cast<String, Object?>(),
      replayed: replay.replayed,
    );
  }

  Future<void> _replaceLoads(
    Elv4WireCommandEnvelope envelope,
    String componentId,
    List<Elv4WireLoadEntry> loads,
  ) async {
    await _requireComponent(envelope.projectId, componentId);
    for (final load in loads) {
      await _requireOwnedPort(
        envelope.projectId,
        load.inputPortId,
        componentId,
      );
      await _requireLoadIdScope(envelope, load.loadId, componentId);
    }
    final instant = now().toUtc();
    await database.customUpdate(
      'UPDATE power_load_bindings SET deleted_at = ?, updated_at = ?, '
      'revision = revision + 1, origin_device_id = ? '
      'WHERE project_id = ? AND design_revision_id = ? AND deleted_at IS NULL '
      'AND input_port_id IN (SELECT id FROM engineering_port_instances '
      'WHERE project_id = ? AND component_id = ?)',
      variables: [
        Variable<DateTime>(instant),
        Variable<DateTime>(instant),
        Variable.withString(originDeviceId),
        Variable.withString(envelope.projectId),
        Variable.withString(envelope.designRevisionId),
        Variable.withString(envelope.projectId),
        Variable.withString(componentId),
      ],
    );
    for (final load in loads) {
      await runRawStatement(
        database,
        'INSERT INTO power_load_bindings '
        '(project_id, design_revision_id, id, revision, created_at, updated_at, '
        'deleted_at, origin_device_id, input_port_id, state_code, accounting_kind, '
        'origin_id, typed_demand_json) VALUES (?, ?, ?, 1, ?, ?, NULL, ?, ?, ?, ?, ?, ?) '
        'ON CONFLICT(design_revision_id, id) DO UPDATE SET '
        'input_port_id = excluded.input_port_id, state_code = excluded.state_code, '
        'accounting_kind = excluded.accounting_kind, origin_id = excluded.origin_id, '
        'typed_demand_json = excluded.typed_demand_json, '
        'revision = power_load_bindings.revision + 1, updated_at = excluded.updated_at, '
        'deleted_at = NULL, origin_device_id = excluded.origin_device_id',
        [
          Variable.withString(envelope.projectId),
          Variable.withString(envelope.designRevisionId),
          Variable.withString(load.loadId),
          Variable<DateTime>(instant),
          Variable<DateTime>(instant),
          Variable.withString(originDeviceId),
          Variable.withString(load.inputPortId),
          Variable.withString(load.stateCode),
          Variable.withString(load.accountingKind),
          Variable.withString(load.originId),
          Variable.withString(canonicalEngineeringJsonV1(load.demand.toMap())),
        ],
      );
    }
  }

  Future<void> _replaceTransfers(
    Elv4WireCommandEnvelope envelope,
    String componentId,
    List<Elv4WireTransferEntry> transfers,
  ) async {
    await _requireComponent(envelope.projectId, componentId);
    for (final transfer in transfers) {
      await _requireTransferIdScope(envelope, transfer.id, componentId);
      await _requireOwnedPort(
        envelope.projectId,
        transfer.inputPortId,
        componentId,
      );
      for (final portId in transfer.outputPortIds) {
        await _requireOwnedPort(envelope.projectId, portId, componentId);
      }
      for (final groupId in transfer.capacityGroupIds) {
        await _requireCapacityGroup(envelope, groupId, componentId);
      }
    }
    final instant = now().toUtc();
    await database.customUpdate(
      'DELETE FROM power_transfer_outputs '
      'WHERE project_id = ? AND design_revision_id = ? AND transfer_id IN '
      '(SELECT id FROM power_transfer_bindings WHERE project_id = ? '
      'AND design_revision_id = ? AND component_id = ?)',
      variables: [
        Variable.withString(envelope.projectId),
        Variable.withString(envelope.designRevisionId),
        Variable.withString(envelope.projectId),
        Variable.withString(envelope.designRevisionId),
        Variable.withString(componentId),
      ],
    );
    await database.customUpdate(
      'UPDATE power_transfer_bindings SET deleted_at = ?, updated_at = ?, '
      'revision = revision + 1, origin_device_id = ? '
      'WHERE project_id = ? AND design_revision_id = ? AND component_id = ? '
      'AND deleted_at IS NULL',
      variables: [
        Variable<DateTime>(instant),
        Variable<DateTime>(instant),
        Variable.withString(originDeviceId),
        Variable.withString(envelope.projectId),
        Variable.withString(envelope.designRevisionId),
        Variable.withString(componentId),
      ],
    );
    for (final transfer in transfers) {
      final payloadJson = canonicalEngineeringJsonV1(transfer.toMap());
      final modelJson = canonicalEngineeringJsonV1({
        'schema': 'electra.elv4-wire-transfer-model.v1',
        'loss': transfer.loss.toMap(),
        'capacityGroupIds': transfer.capacityGroupIds,
      });
      await runRawStatement(
        database,
        'INSERT INTO power_transfer_bindings '
        '(project_id, design_revision_id, id, revision, created_at, updated_at, '
        'deleted_at, origin_device_id, component_id, input_port_id, transfer_kind, '
        'model_ref_json, payload_json) VALUES (?, ?, ?, 1, ?, ?, NULL, ?, ?, ?, ?, ?, ?) '
        'ON CONFLICT(design_revision_id, id) DO UPDATE SET '
        'component_id = excluded.component_id, input_port_id = excluded.input_port_id, '
        'transfer_kind = excluded.transfer_kind, model_ref_json = excluded.model_ref_json, '
        'payload_json = excluded.payload_json, revision = power_transfer_bindings.revision + 1, '
        'updated_at = excluded.updated_at, deleted_at = NULL, '
        'origin_device_id = excluded.origin_device_id',
        [
          Variable.withString(envelope.projectId),
          Variable.withString(envelope.designRevisionId),
          Variable.withString(transfer.id),
          Variable<DateTime>(instant),
          Variable<DateTime>(instant),
          Variable.withString(originDeviceId),
          Variable.withString(componentId),
          Variable.withString(transfer.inputPortId),
          Variable.withString(transfer.kind),
          Variable.withString(modelJson),
          Variable.withString(payloadJson),
        ],
      );
      for (var index = 0; index < transfer.outputPortIds.length; index++) {
        await runRawStatement(
          database,
          'INSERT INTO power_transfer_outputs '
          '(project_id, design_revision_id, transfer_id, output_port_id, ordinal) '
          'VALUES (?, ?, ?, ?, ?)',
          [
            Variable.withString(envelope.projectId),
            Variable.withString(envelope.designRevisionId),
            Variable.withString(transfer.id),
            Variable.withString(transfer.outputPortIds[index]),
            Variable.withInt(index + 1),
          ],
        );
      }
    }
  }

  Future<List<String>> _activeLoadIds(
    Elv4WireCommandEnvelope envelope,
    String componentId,
  ) async {
    final rows = await database.customSelect(
      'SELECT l.id FROM power_load_bindings l '
      'JOIN engineering_port_instances p ON p.project_id = l.project_id '
      'AND p.id = l.input_port_id '
      'WHERE l.project_id = ? AND l.design_revision_id = ? '
      'AND l.deleted_at IS NULL AND p.component_id = ? ORDER BY l.id',
      variables: [
        Variable.withString(envelope.projectId),
        Variable.withString(envelope.designRevisionId),
        Variable.withString(componentId),
      ],
    ).get();
    return rows.map((row) => row.read<String>('id')).toList(growable: false);
  }

  Future<List<String>> _activeTransferIds(
    Elv4WireCommandEnvelope envelope,
    String componentId,
  ) async {
    final rows = await database.customSelect(
      'SELECT id FROM power_transfer_bindings WHERE project_id = ? '
      'AND design_revision_id = ? AND component_id = ? AND deleted_at IS NULL '
      'ORDER BY id',
      variables: [
        Variable.withString(envelope.projectId),
        Variable.withString(envelope.designRevisionId),
        Variable.withString(componentId),
      ],
    ).get();
    return rows.map((row) => row.read<String>('id')).toList(growable: false);
  }

  Future<void> _requireLoadIdScope(
    Elv4WireCommandEnvelope envelope,
    String loadId,
    String componentId,
  ) async {
    final row = await database.customSelect(
      'SELECT p.component_id FROM power_load_bindings l '
      'JOIN engineering_port_instances p ON p.project_id = l.project_id '
      'AND p.id = l.input_port_id '
      'WHERE l.design_revision_id = ? AND l.id = ?',
      variables: [
        Variable.withString(envelope.designRevisionId),
        Variable.withString(loadId),
      ],
    ).getSingleOrNull();
    if (row != null && row.read<String>('component_id') != componentId) {
      throw const PowerRuntimeStorageException('ELV4_LOAD_ID_SCOPE_CONFLICT');
    }
  }

  Future<void> _requireTransferIdScope(
    Elv4WireCommandEnvelope envelope,
    String transferId,
    String componentId,
  ) async {
    final row = await database.customSelect(
      'SELECT component_id FROM power_transfer_bindings '
      'WHERE design_revision_id = ? AND id = ?',
      variables: [
        Variable.withString(envelope.designRevisionId),
        Variable.withString(transferId),
      ],
    ).getSingleOrNull();
    if (row != null && row.read<String>('component_id') != componentId) {
      throw const PowerRuntimeStorageException(
        'ELV4_TRANSFER_ID_SCOPE_CONFLICT',
      );
    }
  }

  Future<void> _requireCapacityGroup(
    Elv4WireCommandEnvelope envelope,
    String groupId,
    String componentId,
  ) => _requireExists(
    'SELECT 1 FROM power_capacity_groups WHERE project_id = ? '
    'AND design_revision_id = ? AND id = ? AND owner_component_id = ? '
    'AND deleted_at IS NULL',
    [
      Variable.withString(envelope.projectId),
      Variable.withString(envelope.designRevisionId),
      Variable.withString(groupId),
      Variable.withString(componentId),
    ],
    'ELV4_TRANSFER_CAPACITY_GROUP_SCOPE_MISMATCH',
  );

  Future<void> _advanceDesignRevision(Elv4WireCommandEnvelope envelope) async {
    final updated = await database.customUpdate(
      'UPDATE project_design_revisions SET revision = revision + 1, '
      'updated_at = ?, origin_device_id = ? WHERE project_id = ? AND id = ? '
      "AND state = 'WORKING' AND deleted_at IS NULL AND revision = ?",
      variables: [
        Variable<DateTime>(now().toUtc()),
        Variable.withString(originDeviceId),
        Variable.withString(envelope.projectId),
        Variable.withString(envelope.designRevisionId),
        Variable.withInt(envelope.expectedDesignRowRevision),
      ],
    );
    if (updated != 1) {
      throw const PowerRuntimeStorageException(
        'ELV4_DESIGN_REVISION_CAS_FAILED',
      );
    }
  }

  Future<void> _requireOwnedPort(
    String projectId,
    String portId,
    String componentId,
  ) async {
    await _requireComponent(projectId, componentId);
    await _requireExists(
      'SELECT 1 FROM engineering_port_instances '
      'WHERE project_id = ? AND id = ? AND component_id = ? '
      'AND deleted_at IS NULL',
      [
        Variable.withString(projectId),
        Variable.withString(portId),
        Variable.withString(componentId),
      ],
      'ELV4_PORT_OWNER_MISMATCH',
    );
  }

  Future<void> _requireComponent(String projectId, String componentId) =>
      _requireExists(
        'SELECT 1 FROM component_instances c '
        'JOIN rooms r ON r.id = c.room_id '
        'JOIN floors f ON f.id = r.floor_id '
        'WHERE f.project_id = ? AND c.id = ? AND c.deleted_at IS NULL '
        'AND r.deleted_at IS NULL AND f.deleted_at IS NULL',
        [Variable.withString(projectId), Variable.withString(componentId)],
        'ELV4_COMPONENT_SCOPE_MISMATCH',
      );

  Future<void> _requireExists(
    String sql,
    List<Variable<Object>> variables,
    String code,
  ) async {
    final row = await database.customSelect(sql, variables: variables).getSingleOrNull();
    if (row == null) throw PowerRuntimeStorageException(code);
  }

  List<PowerDependencyKey> _dependencies(
    Elv4WireCommandEnvelope envelope,
    Iterable<String> refs,
  ) {
    final values = refs.map(PowerDependencyKey.decode).toSet().toList()..sort();
    for (final value in values) {
      if (value.projectId != envelope.projectId ||
          value.revisionId != envelope.designRevisionId) {
        throw const PowerRuntimeStorageException(
          'ELV4_REVIEWED_DEPENDENCY_SCOPE_MISMATCH',
        );
      }
    }
    return List.unmodifiable(values);
  }

  void _requireOperation(Elv4WireCommandEnvelope envelope, String operation) {
    if (envelope.schema != Elv4WireCommandEnvelope.powerCommandSchema ||
        envelope.payloadSchemaVersion != 1 ||
        envelope.operation != operation) {
      throw const PowerRuntimeStorageException(
        'ELV4_WIRE_OPERATION_DISPATCH_MISMATCH',
      );
    }
  }

  String _ledgerSchema(Elv4WireCommandEnvelope envelope) =>
      '${envelope.schema}/${envelope.operation}@${envelope.payloadSchemaVersion}';

  String _fingerprint(Elv4WireCommandEnvelope envelope) =>
      sha256HexUtf8(canonicalEngineeringJsonV1(envelope.toMap()));
}

String _text(String value, String field) {
  final normalized = value.trim();
  if (normalized.isEmpty || normalized.length > 512) {
    throw ArgumentError.value(value, field, 'Must contain 1..512 characters.');
  }
  return normalized;
}

void _requireUnique(Iterable<String> values, String field) {
  final list = values.toList(growable: false);
  if (list.toSet().length != list.length) {
    throw ArgumentError('$field values must be unique.');
  }
}
