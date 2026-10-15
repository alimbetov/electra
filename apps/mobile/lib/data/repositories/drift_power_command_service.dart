import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core.dart';

import '../../application/power_mutation_command.dart';
import '../database/app_database.dart';
import '../database/drift_raw_statement.dart';
import 'drift_power_publication_runtime.dart';
import 'drift_power_runtime_store.dart';

final class PowerMutationReceipt {
  const PowerMutationReceipt({
    required this.operationId,
    required this.projectId,
    required this.designRevisionId,
    required this.previousRevision,
    required this.currentRevision,
    required this.affectedIds,
    required this.invalidatedNodeKeys,
    required this.replayed,
  });

  final String operationId;
  final String projectId;
  final String designRevisionId;
  final int previousRevision;
  final int currentRevision;
  final List<String> affectedIds;
  final List<PowerNodeKeyV2> invalidatedNodeKeys;
  final bool replayed;

  Map<String, Object?> toMap() => {
    'schema': 'electra.elv4-power-mutation-receipt.v1',
    'operationId': operationId,
    'projectId': projectId,
    'designRevisionId': designRevisionId,
    'previousRevision': previousRevision,
    'currentRevision': currentRevision,
    'affectedIds': affectedIds,
    'invalidatedNodeKeys': invalidatedNodeKeys
        .map((value) => value.encode())
        .toList(growable: false),
  };

  factory PowerMutationReceipt.fromMap(
    Map<String, Object?> map, {
    required bool replayed,
  }) => PowerMutationReceipt(
    operationId: map['operationId']! as String,
    projectId: map['projectId']! as String,
    designRevisionId: map['designRevisionId']! as String,
    previousRevision: map['previousRevision']! as int,
    currentRevision: map['currentRevision']! as int,
    affectedIds: (map['affectedIds'] as List<Object?>).cast<String>(),
    invalidatedNodeKeys: (map['invalidatedNodeKeys'] as List<Object?>)
        .cast<String>()
        .map(PowerNodeKeyV2.decode)
        .toList(growable: false),
    replayed: replayed,
  );
}

/// P2 public mutation boundary for revision-scoped ELV4 power facts.
///
/// All commands execute as one SQLite transaction: exact replay check, scope and
/// token validation, aspect mutation, design-token CAS, dependency invalidation
/// and committed receipt. A thrown error leaves no operation row or partial
/// aspect mutation.
final class DriftPowerCommandService {
  DriftPowerCommandService(
    this.database, {
    required this.originDeviceId,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now,
       publicationRuntime = DriftPowerPublicationRuntime(
         database,
         originDeviceId: originDeviceId,
         now: now,
       );

  final AppDatabase database;
  final String originDeviceId;
  final DateTime Function() now;
  final DriftPowerPublicationRuntime publicationRuntime;

  Future<PowerMutationReceipt> execute(PowerMutationCommand command) async {
    await publicationRuntime.ensureRuntimeSchema();
    final fingerprint = sha256HexUtf8(
      canonicalEngineeringJsonV1({
        'schema': command.payloadSchema,
        'commandType': command.commandType,
        'payload': command.canonicalPayload,
      }),
    );
    return database.transaction(() async {
      final replay = await _loadReplay(command, fingerprint);
      if (replay != null) return replay;

      final revision = await _requireWorkingRevision(command);
      if (revision != command.expectedRevision) {
        throw PowerRuntimeStorageException('ELV4_DESIGN_REVISION_CONFLICT', {
          'expectedRevision': command.expectedRevision,
          'actualRevision': revision,
        });
      }

      await _apply(command);
      final updated = await database.customUpdate(
        'UPDATE project_design_revisions '
        'SET revision = revision + 1, updated_at = ?, origin_device_id = ? '
        'WHERE project_id = ? AND id = ? AND state = ? AND deleted_at IS NULL '
        'AND revision = ?',
        variables: [
          Variable<DateTime>(now().toUtc()),
          Variable.withString(originDeviceId),
          Variable.withString(command.projectId),
          Variable.withString(command.designRevisionId),
          Variable.withString('WORKING'),
          Variable.withInt(command.expectedRevision),
        ],
      );
      if (updated != 1) {
        throw PowerRuntimeStorageException('ELV4_DESIGN_REVISION_CAS_FAILED', {
          'expectedRevision': command.expectedRevision,
        });
      }

      final invalidated = await _invalidateDependencyClosure(command);
      final receipt = PowerMutationReceipt(
        operationId: command.operationId,
        projectId: command.projectId,
        designRevisionId: command.designRevisionId,
        previousRevision: command.expectedRevision,
        currentRevision: command.expectedRevision + 1,
        affectedIds: _affectedIds(command),
        invalidatedNodeKeys: invalidated,
        replayed: false,
      );
      final instant = now().toUtc();
      await runRawStatement(
        database,
        'INSERT INTO power_operation_records '
        '(project_id, design_revision_id, operation_id, command_type, '
        'payload_schema, command_fingerprint, status, result_json, created_at, '
        'committed_at, origin_device_id) '
        "VALUES (?, ?, ?, ?, ?, ?, 'COMMITTED', ?, ?, ?, ?)",
        [
          Variable.withString(command.projectId),
          Variable.withString(command.designRevisionId),
          Variable.withString(command.operationId),
          Variable.withString(command.commandType),
          Variable.withString(command.payloadSchema),
          Variable.withString(fingerprint),
          Variable.withString(canonicalEngineeringJsonV1(receipt.toMap())),
          Variable<DateTime>(instant),
          Variable<DateTime>(instant),
          Variable.withString(originDeviceId),
        ],
      );
      return receipt;
    });
  }

  Future<PowerMutationReceipt?> _loadReplay(
    PowerMutationCommand command,
    String fingerprint,
  ) async {
    final row =
        await database
            .customSelect(
              'SELECT command_type, payload_schema, command_fingerprint, '
              'status, result_json FROM power_operation_records '
              'WHERE project_id = ? AND design_revision_id = ? '
              'AND operation_id = ?',
              variables: [
                Variable.withString(command.projectId),
                Variable.withString(command.designRevisionId),
                Variable.withString(command.operationId),
              ],
            )
            .getSingleOrNull();
    if (row == null) return null;
    if (row.read<String>('command_type') != command.commandType ||
        row.read<String>('payload_schema') != command.payloadSchema ||
        row.read<String>('command_fingerprint') != fingerprint) {
      throw PowerRuntimeStorageException(
        'ELV4_OPERATION_FINGERPRINT_CONFLICT',
        {'operationId': command.operationId},
      );
    }
    final resultJson = row.readNullable<String>('result_json');
    if (row.read<String>('status') != 'COMMITTED' || resultJson == null) {
      throw PowerRuntimeStorageException('ELV4_OPERATION_INCOMPLETE_REPLAY', {
        'operationId': command.operationId,
      });
    }
    return PowerMutationReceipt.fromMap(
      (jsonDecode(resultJson) as Map).cast<String, Object?>(),
      replayed: true,
    );
  }

  Future<int> _requireWorkingRevision(PowerMutationCommand command) async {
    final row =
        await database
            .customSelect(
              'SELECT revision, state FROM project_design_revisions '
              'WHERE project_id = ? AND id = ? AND deleted_at IS NULL',
              variables: [
                Variable.withString(command.projectId),
                Variable.withString(command.designRevisionId),
              ],
            )
            .getSingleOrNull();
    if (row == null) {
      throw const PowerRuntimeStorageException('ELV4_REVISION_NOT_FOUND');
    }
    final state = row.read<String>('state');
    if (state != 'WORKING') {
      throw PowerRuntimeStorageException('ELV4_REVISION_NOT_WORKING', {
        'state': state,
      });
    }
    return row.read<int>('revision');
  }

  Future<void> _apply(PowerMutationCommand command) => switch (command) {
    BindPowerPortCommand value => _bindPort(value),
    ReleasePowerPortCommand value => _releasePort(value),
    BindPowerComponentCommand value => _bindComponent(value),
    SetPowerLoadCommand value => _setLoad(value),
    ReplacePowerTransferCommand value => _replaceTransfer(value),
    ReplacePowerCapacityGroupCommand value => _replaceCapacityGroup(value),
    ReplacePowerSupplyRequirementCommand value => _replaceSupply(value),
    ReplacePowerScenarioCommand value => _replaceScenario(value),
    ArchivePowerScenarioCommand value => _archiveScenario(value),
    BindPoeDeliveryCommand value => _bindPoe(value),
    ConfigureBackupAssemblyCommand value => _configureBackup(value),
    ReplaceBatteryBankCommand value => _replaceBatteryBank(value),
    _ => Future<void>.error(
      const PowerRuntimeStorageException('ELV4_UNSUPPORTED_MUTATION_COMMAND'),
    ),
  };

  Future<void> _bindPort(BindPowerPortCommand command) async {
    await _requirePort(command.projectId, command.binding.portId);
    final payload = canonicalEngineeringJsonV1(command.binding.toMap());
    await runRawStatement(
      database,
      'INSERT INTO power_port_bindings '
      '(project_id, design_revision_id, id, revision, created_at, updated_at, '
      'deleted_at, origin_device_id, port_id, resolved_profile_json, '
      'profile_schema, profile_sha256) VALUES (?, ?, ?, 1, ?, ?, NULL, ?, ?, ?, ?, ?) '
      'ON CONFLICT(design_revision_id, id) DO UPDATE SET '
      'port_id = excluded.port_id, resolved_profile_json = excluded.resolved_profile_json, '
      'profile_schema = excluded.profile_schema, profile_sha256 = excluded.profile_sha256, '
      'revision = power_port_bindings.revision + 1, updated_at = excluded.updated_at, '
      'deleted_at = NULL, origin_device_id = excluded.origin_device_id',
      [
        Variable.withString(command.projectId),
        Variable.withString(command.designRevisionId),
        Variable.withString(command.bindingId),
        Variable<DateTime>(now().toUtc()),
        Variable<DateTime>(now().toUtc()),
        Variable.withString(originDeviceId),
        Variable.withString(command.binding.portId),
        Variable.withString(payload),
        Variable.withString('electra.power-port-binding.v1'),
        Variable.withString(sha256HexUtf8(payload)),
      ],
    );
  }

  Future<void> _releasePort(ReleasePowerPortCommand command) async {
    final changed = await database.customUpdate(
      'UPDATE power_port_bindings SET deleted_at = ?, updated_at = ?, '
      'revision = revision + 1, origin_device_id = ? '
      'WHERE project_id = ? AND design_revision_id = ? AND id = ? '
      'AND deleted_at IS NULL',
      variables: [
        Variable<DateTime>(now().toUtc()),
        Variable<DateTime>(now().toUtc()),
        Variable.withString(originDeviceId),
        Variable.withString(command.projectId),
        Variable.withString(command.designRevisionId),
        Variable.withString(command.bindingId),
      ],
    );
    if (changed != 1) {
      throw const PowerRuntimeStorageException('ELV4_POWER_BINDING_NOT_FOUND');
    }
  }

  Future<void> _bindComponent(BindPowerComponentCommand command) async {
    await _requireComponent(command.projectId, command.binding.componentId);
    final refs =
        command.binding.definitionRefs.map((value) => value.toMap()).toList();
    final refsJson = canonicalEngineeringJsonV1(refs);
    await runRawStatement(
      database,
      'INSERT INTO power_component_bindings '
      '(project_id, design_revision_id, id, revision, created_at, updated_at, '
      'deleted_at, origin_device_id, component_id, capabilities_json, '
      'definition_ref_json, definition_sha256) VALUES (?, ?, ?, 1, ?, ?, NULL, ?, ?, ?, ?, ?) '
      'ON CONFLICT(design_revision_id, id) DO UPDATE SET '
      'component_id = excluded.component_id, capabilities_json = excluded.capabilities_json, '
      'definition_ref_json = excluded.definition_ref_json, definition_sha256 = excluded.definition_sha256, '
      'revision = power_component_bindings.revision + 1, updated_at = excluded.updated_at, '
      'deleted_at = NULL, origin_device_id = excluded.origin_device_id',
      [
        Variable.withString(command.projectId),
        Variable.withString(command.designRevisionId),
        Variable.withString(command.bindingId),
        Variable<DateTime>(now().toUtc()),
        Variable<DateTime>(now().toUtc()),
        Variable.withString(originDeviceId),
        Variable.withString(command.binding.componentId),
        Variable.withString(
          canonicalEngineeringJsonV1(
            command.binding.capabilities
                .map((v) => v.name.toUpperCase())
                .toList(),
          ),
        ),
        Variable.withString(refsJson),
        Variable.withString(sha256HexUtf8(refsJson)),
      ],
    );
  }

  Future<void> _setLoad(SetPowerLoadCommand command) async {
    await _requireOwnedPort(
      command.projectId,
      command.contribution.inputPortId,
      command.contribution.componentId,
    );
    final demandJson = canonicalEngineeringJsonV1(
      command.contribution.demand.toMap(),
    );
    await runRawStatement(
      database,
      'INSERT INTO power_load_bindings '
      '(project_id, design_revision_id, id, revision, created_at, updated_at, '
      'deleted_at, origin_device_id, input_port_id, state_code, accounting_kind, '
      'origin_id, typed_demand_json) VALUES (?, ?, ?, 1, ?, ?, NULL, ?, ?, ?, ?, ?, ?) '
      'ON CONFLICT(design_revision_id, id) DO UPDATE SET '
      'input_port_id = excluded.input_port_id, state_code = excluded.state_code, '
      'accounting_kind = excluded.accounting_kind, origin_id = excluded.origin_id, '
      'typed_demand_json = excluded.typed_demand_json, revision = power_load_bindings.revision + 1, '
      'updated_at = excluded.updated_at, deleted_at = NULL, origin_device_id = excluded.origin_device_id',
      [
        Variable.withString(command.projectId),
        Variable.withString(command.designRevisionId),
        Variable.withString(command.contribution.id),
        Variable<DateTime>(now().toUtc()),
        Variable<DateTime>(now().toUtc()),
        Variable.withString(originDeviceId),
        Variable.withString(command.contribution.inputPortId),
        Variable.withString(command.contribution.stateCode),
        Variable.withString(
          command.contribution.accountingKind.name.toUpperCase(),
        ),
        Variable.withString(command.contribution.id),
        Variable.withString(demandJson),
      ],
    );
  }

  Future<void> _replaceTransfer(ReplacePowerTransferCommand command) async {
    final transfer = command.transfer;
    if (transfer.inputPortIds.length != 1) {
      throw const PowerRuntimeStorageException(
        'ELV4_TRANSFER_MULTI_INPUT_UNSUPPORTED',
      );
    }
    await _requireComponent(command.projectId, transfer.componentId);
    await _requireOwnedPort(
      command.projectId,
      transfer.inputPortIds.single,
      transfer.componentId,
    );
    for (final portId in transfer.outputPortIds) {
      await _requireOwnedPort(command.projectId, portId, transfer.componentId);
    }
    final payloadJson = canonicalEngineeringJsonV1(transfer.toMap());
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
      'updated_at = excluded.updated_at, deleted_at = NULL, origin_device_id = excluded.origin_device_id',
      [
        Variable.withString(command.projectId),
        Variable.withString(command.designRevisionId),
        Variable.withString(transfer.id),
        Variable<DateTime>(now().toUtc()),
        Variable<DateTime>(now().toUtc()),
        Variable.withString(originDeviceId),
        Variable.withString(transfer.componentId),
        Variable.withString(transfer.inputPortIds.single),
        Variable.withString(transfer.kind.name.toUpperCase()),
        Variable.withString(
          canonicalEngineeringJsonV1(transfer.definitionRef.toMap()),
        ),
        Variable.withString(payloadJson),
      ],
    );
    await database.customUpdate(
      'DELETE FROM power_transfer_outputs WHERE project_id = ? AND design_revision_id = ? AND transfer_id = ?',
      variables: [
        Variable.withString(command.projectId),
        Variable.withString(command.designRevisionId),
        Variable.withString(transfer.id),
      ],
    );
    for (var i = 0; i < transfer.outputPortIds.length; i++) {
      await runRawStatement(
        database,
        'INSERT INTO power_transfer_outputs '
        '(project_id, design_revision_id, transfer_id, output_port_id, ordinal) '
        'VALUES (?, ?, ?, ?, ?)',
        [
          Variable.withString(command.projectId),
          Variable.withString(command.designRevisionId),
          Variable.withString(transfer.id),
          Variable.withString(transfer.outputPortIds[i]),
          Variable.withInt(i + 1),
        ],
      );
    }
  }

  Future<void> _replaceCapacityGroup(
    ReplacePowerCapacityGroupCommand command,
  ) async {
    final group = command.group;
    await _requireComponent(command.projectId, group.ownerComponentId);
    for (final portId in group.memberOutputPortIds) {
      await _requireOwnedPort(
        command.projectId,
        portId,
        group.ownerComponentId,
      );
    }
    await runRawStatement(
      database,
      'INSERT INTO power_capacity_groups '
      '(project_id, design_revision_id, id, revision, created_at, updated_at, '
      'deleted_at, origin_device_id, owner_component_id, limits_json, applicability_json) '
      'VALUES (?, ?, ?, 1, ?, ?, NULL, ?, ?, ?, ?) '
      'ON CONFLICT(design_revision_id, id) DO UPDATE SET '
      'owner_component_id = excluded.owner_component_id, limits_json = excluded.limits_json, '
      'applicability_json = excluded.applicability_json, revision = power_capacity_groups.revision + 1, '
      'updated_at = excluded.updated_at, deleted_at = NULL, origin_device_id = excluded.origin_device_id',
      [
        Variable.withString(command.projectId),
        Variable.withString(command.designRevisionId),
        Variable.withString(group.id),
        Variable<DateTime>(now().toUtc()),
        Variable<DateTime>(now().toUtc()),
        Variable.withString(originDeviceId),
        Variable.withString(group.ownerComponentId),
        Variable.withString(
          canonicalEngineeringJsonV1(
            group.limits.map((v) => v.toMap()).toList(),
          ),
        ),
        Variable.withString(
          canonicalEngineeringJsonV1({
            'stateCodes': group.applicabilityStateCodes,
            'deratingFactor': group.deratingFactor.toWireDecimal(),
          }),
        ),
      ],
    );
    await database.customUpdate(
      'DELETE FROM power_capacity_group_members WHERE project_id = ? AND design_revision_id = ? AND group_id = ?',
      variables: [
        Variable.withString(command.projectId),
        Variable.withString(command.designRevisionId),
        Variable.withString(group.id),
      ],
    );
    for (var i = 0; i < group.memberOutputPortIds.length; i++) {
      await runRawStatement(
        database,
        'INSERT INTO power_capacity_group_members '
        '(project_id, design_revision_id, group_id, output_port_id, ordinal) VALUES (?, ?, ?, ?, ?)',
        [
          Variable.withString(command.projectId),
          Variable.withString(command.designRevisionId),
          Variable.withString(group.id),
          Variable.withString(group.memberOutputPortIds[i]),
          Variable.withInt(i + 1),
        ],
      );
    }
  }

  Future<void> _replaceSupply(
    ReplacePowerSupplyRequirementCommand command,
  ) async {
    final requirement = command.requirement;
    await _requireComponent(command.projectId, requirement.consumerComponentId);
    for (final portId in requirement.inputPortIds) {
      await _requireOwnedPort(
        command.projectId,
        portId,
        requirement.consumerComponentId,
      );
    }
    final payloadJson = canonicalEngineeringJsonV1(requirement.toMap());
    await runRawStatement(
      database,
      'INSERT INTO power_supply_requirements '
      '(project_id, design_revision_id, id, revision, created_at, updated_at, '
      'deleted_at, origin_device_id, consumer_component_id, selection_mode, payload_json) '
      'VALUES (?, ?, ?, 1, ?, ?, NULL, ?, ?, ?, ?) '
      'ON CONFLICT(design_revision_id, id) DO UPDATE SET '
      'consumer_component_id = excluded.consumer_component_id, selection_mode = excluded.selection_mode, '
      'payload_json = excluded.payload_json, revision = power_supply_requirements.revision + 1, '
      'updated_at = excluded.updated_at, deleted_at = NULL, origin_device_id = excluded.origin_device_id',
      [
        Variable.withString(command.projectId),
        Variable.withString(command.designRevisionId),
        Variable.withString(requirement.id),
        Variable<DateTime>(now().toUtc()),
        Variable<DateTime>(now().toUtc()),
        Variable.withString(originDeviceId),
        Variable.withString(requirement.consumerComponentId),
        Variable.withString(requirement.selectionMode.name.toUpperCase()),
        Variable.withString(payloadJson),
      ],
    );
    await database.customUpdate(
      'DELETE FROM power_supply_requirement_inputs '
      'WHERE project_id = ? AND design_revision_id = ? AND requirement_id = ?',
      variables: [
        Variable.withString(command.projectId),
        Variable.withString(command.designRevisionId),
        Variable.withString(requirement.id),
      ],
    );
    for (var i = 0; i < requirement.inputPortIds.length; i++) {
      await runRawStatement(
        database,
        'INSERT INTO power_supply_requirement_inputs '
        '(project_id, design_revision_id, requirement_id, input_port_id, allowed_sources_json, ordinal) '
        'VALUES (?, ?, ?, ?, ?, ?)',
        [
          Variable.withString(command.projectId),
          Variable.withString(command.designRevisionId),
          Variable.withString(requirement.id),
          Variable.withString(requirement.inputPortIds[i]),
          Variable.withString(
            canonicalEngineeringJsonV1(requirement.candidateSourceIds),
          ),
          Variable.withInt(i + 1),
        ],
      );
    }
  }

  Future<void> _replaceScenario(ReplacePowerScenarioCommand command) async {
    final scenario = command.scenario;
    await runRawStatement(
      database,
      'INSERT INTO power_operating_scenarios '
      '(project_id, design_revision_id, id, revision, created_at, updated_at, '
      'deleted_at, origin_device_id, role, policy_refs_json) '
      'VALUES (?, ?, ?, ?, ?, ?, NULL, ?, ?, ?) '
      'ON CONFLICT(design_revision_id, id) DO UPDATE SET '
      'revision = excluded.revision, role = excluded.role, policy_refs_json = excluded.policy_refs_json, '
      'updated_at = excluded.updated_at, deleted_at = NULL, origin_device_id = excluded.origin_device_id',
      [
        Variable.withString(command.projectId),
        Variable.withString(command.designRevisionId),
        Variable.withString(scenario.scenarioId),
        Variable.withInt(scenario.rowRevision),
        Variable<DateTime>(now().toUtc()),
        Variable<DateTime>(now().toUtc()),
        Variable.withString(originDeviceId),
        Variable.withString(scenario.role.name.toUpperCase()),
        Variable.withString(
          canonicalEngineeringJsonV1(
            scenario.policyRefs.map((v) => v.toMap()).toList(),
          ),
        ),
      ],
    );
    for (final table in [
      'power_scenario_source_selections',
      'power_scenario_unavailable_sources',
      'power_scenario_states',
      'power_scenario_segments',
    ]) {
      await database.customUpdate(
        'DELETE FROM $table WHERE project_id = ? AND design_revision_id = ? AND scenario_id = ?',
        variables: [
          Variable.withString(command.projectId),
          Variable.withString(command.designRevisionId),
          Variable.withString(scenario.scenarioId),
        ],
      );
    }
    for (final segment in scenario.segments) {
      await runRawStatement(
        database,
        'INSERT INTO power_scenario_segments '
        '(project_id, design_revision_id, scenario_id, segment_id, ordinal, duration_json) '
        'VALUES (?, ?, ?, ?, ?, ?)',
        [
          Variable.withString(command.projectId),
          Variable.withString(command.designRevisionId),
          Variable.withString(scenario.scenarioId),
          Variable.withString(segment.segmentId),
          Variable.withInt(segment.ordinal),
          segment.durationSeconds == null
              ? null
              : canonicalEngineeringJsonV1({
                'seconds': segment.durationSeconds!.toWireDecimal(),
              }),
        ],
      );
      final states = <String, String>{
        for (final entry in segment.componentStates.entries)
          entry.key: entry.value.name.toUpperCase(),
        for (final id in segment.chargingBankIds) id: 'CHARGING',
        for (final id in segment.dischargingBankIds) id: 'DISCHARGING',
      };
      for (final entry in states.entries) {
        await _requireComponent(command.projectId, entry.key);
        await runRawStatement(
          database,
          'INSERT INTO power_scenario_states '
          '(project_id, design_revision_id, scenario_id, segment_id, component_id, state_code) '
          'VALUES (?, ?, ?, ?, ?, ?)',
          [
            Variable.withString(command.projectId),
            Variable.withString(command.designRevisionId),
            Variable.withString(scenario.scenarioId),
            Variable.withString(segment.segmentId),
            Variable.withString(entry.key),
            Variable.withString(entry.value),
          ],
        );
      }
      for (final entry in segment.selectedSourceBySupplySet.entries) {
        await runRawStatement(
          database,
          'INSERT INTO power_scenario_source_selections '
          '(project_id, design_revision_id, scenario_id, segment_id, requirement_id, selected_source_id) '
          'VALUES (?, ?, ?, ?, ?, ?)',
          [
            Variable.withString(command.projectId),
            Variable.withString(command.designRevisionId),
            Variable.withString(scenario.scenarioId),
            Variable.withString(segment.segmentId),
            Variable.withString(entry.key),
            Variable.withString(entry.value),
          ],
        );
      }
      for (final sourceId in segment.unavailableSourceIds) {
        await runRawStatement(
          database,
          'INSERT INTO power_scenario_unavailable_sources '
          '(project_id, design_revision_id, scenario_id, segment_id, source_id) '
          'VALUES (?, ?, ?, ?, ?)',
          [
            Variable.withString(command.projectId),
            Variable.withString(command.designRevisionId),
            Variable.withString(scenario.scenarioId),
            Variable.withString(segment.segmentId),
            Variable.withString(sourceId),
          ],
        );
      }
    }
  }

  Future<void> _archiveScenario(ArchivePowerScenarioCommand command) async {
    final changed = await database.customUpdate(
      'UPDATE power_operating_scenarios SET deleted_at = ?, updated_at = ?, '
      'revision = revision + 1, origin_device_id = ? '
      'WHERE project_id = ? AND design_revision_id = ? AND id = ? AND deleted_at IS NULL',
      variables: [
        Variable<DateTime>(now().toUtc()),
        Variable<DateTime>(now().toUtc()),
        Variable.withString(originDeviceId),
        Variable.withString(command.projectId),
        Variable.withString(command.designRevisionId),
        Variable.withString(command.scenarioId),
      ],
    );
    if (changed != 1) {
      throw const PowerRuntimeStorageException('ELV4_SCENARIO_NOT_FOUND');
    }
  }

  Future<void> _bindPoe(BindPoeDeliveryCommand command) async {
    await _requirePort(command.projectId, command.psePortId);
    await _requirePort(command.projectId, command.pdPortId);
    await runRawStatement(
      database,
      'INSERT INTO poe_delivery_bindings '
      '(project_id, design_revision_id, id, revision, created_at, updated_at, '
      'deleted_at, origin_device_id, pse_port_id, pd_port_id, accounting_mode, '
      'definition_ref_json, payload_json) VALUES (?, ?, ?, 1, ?, ?, NULL, ?, ?, ?, ?, ?, ?) '
      'ON CONFLICT(design_revision_id, id) DO UPDATE SET '
      'pse_port_id = excluded.pse_port_id, pd_port_id = excluded.pd_port_id, '
      'accounting_mode = excluded.accounting_mode, definition_ref_json = excluded.definition_ref_json, '
      'payload_json = excluded.payload_json, revision = poe_delivery_bindings.revision + 1, '
      'updated_at = excluded.updated_at, deleted_at = NULL, origin_device_id = excluded.origin_device_id',
      [
        Variable.withString(command.projectId),
        Variable.withString(command.designRevisionId),
        Variable.withString(command.deliveryId),
        Variable<DateTime>(now().toUtc()),
        Variable<DateTime>(now().toUtc()),
        Variable.withString(originDeviceId),
        Variable.withString(command.psePortId),
        Variable.withString(command.pdPortId),
        Variable.withString(command.accountingMode),
        Variable.withString(
          canonicalEngineeringJsonV1(command.definition.definitionRef.toMap()),
        ),
        Variable.withString(
          canonicalEngineeringJsonV1(command.definition.toMap()),
        ),
      ],
    );
    await database.customUpdate(
      'DELETE FROM poe_delivery_path_members WHERE project_id = ? AND design_revision_id = ? AND delivery_id = ?',
      variables: [
        Variable.withString(command.projectId),
        Variable.withString(command.designRevisionId),
        Variable.withString(command.deliveryId),
      ],
    );
    for (var i = 0; i < command.path.length; i++) {
      final member = command.path[i];
      if (member.connectionId != null) {
        await _requireConnection(command.projectId, member.connectionId!);
      }
      if (member.allocationId != null) {
        await _requireAllocation(command.projectId, member.allocationId!);
      }
      await runRawStatement(
        database,
        'INSERT INTO poe_delivery_path_members '
        '(project_id, design_revision_id, delivery_id, ordinal, connection_id, allocation_id, evidence_json) '
        'VALUES (?, ?, ?, ?, ?, ?, ?)',
        [
          Variable.withString(command.projectId),
          Variable.withString(command.designRevisionId),
          Variable.withString(command.deliveryId),
          Variable.withInt(i + 1),
          member.connectionId,
          member.allocationId,
          Variable.withString(canonicalEngineeringJsonV1(member.evidence)),
        ],
      );
    }
  }

  Future<void> _configureBackup(ConfigureBackupAssemblyCommand command) async {
    for (final componentId in [
      command.upsComponentId,
      command.chargerComponentId,
      command.bankComponentId,
    ]) {
      if (componentId != null) {
        await _requireComponent(command.projectId, componentId);
      }
    }
    for (final portId in command.protectedOutputPortIds) {
      await _requirePort(command.projectId, portId);
    }
    await runRawStatement(
      database,
      'INSERT INTO backup_assemblies '
      '(project_id, design_revision_id, id, revision, created_at, updated_at, '
      'deleted_at, origin_device_id, ups_component_id, charger_component_id, bank_component_id, policy_json) '
      'VALUES (?, ?, ?, 1, ?, ?, NULL, ?, ?, ?, ?, ?) '
      'ON CONFLICT(design_revision_id, id) DO UPDATE SET '
      'ups_component_id = excluded.ups_component_id, charger_component_id = excluded.charger_component_id, '
      'bank_component_id = excluded.bank_component_id, policy_json = excluded.policy_json, '
      'revision = backup_assemblies.revision + 1, updated_at = excluded.updated_at, '
      'deleted_at = NULL, origin_device_id = excluded.origin_device_id',
      [
        Variable.withString(command.projectId),
        Variable.withString(command.designRevisionId),
        Variable.withString(command.assemblyId),
        Variable<DateTime>(now().toUtc()),
        Variable<DateTime>(now().toUtc()),
        Variable.withString(originDeviceId),
        command.upsComponentId,
        command.chargerComponentId,
        command.bankComponentId,
        Variable.withString(canonicalEngineeringJsonV1(command.policy)),
      ],
    );
    await database.customUpdate(
      'DELETE FROM backup_protected_outputs WHERE project_id = ? AND design_revision_id = ? AND assembly_id = ?',
      variables: [
        Variable.withString(command.projectId),
        Variable.withString(command.designRevisionId),
        Variable.withString(command.assemblyId),
      ],
    );
    for (final portId in command.protectedOutputPortIds) {
      await runRawStatement(
        database,
        'INSERT INTO backup_protected_outputs '
        '(project_id, design_revision_id, assembly_id, output_port_id) VALUES (?, ?, ?, ?)',
        [
          Variable.withString(command.projectId),
          Variable.withString(command.designRevisionId),
          Variable.withString(command.assemblyId),
          Variable.withString(portId),
        ],
      );
    }
  }

  Future<void> _replaceBatteryBank(ReplaceBatteryBankCommand command) async {
    final binding = command.binding;
    await _requireComponent(command.projectId, binding.componentId);
    await runRawStatement(
      database,
      'INSERT INTO battery_bank_bindings '
      '(project_id, design_revision_id, id, revision, created_at, updated_at, '
      'deleted_at, origin_device_id, bank_component_id, unit_ref_json, series_count, '
      'parallel_count, usable_model_json) VALUES (?, ?, ?, 1, ?, ?, NULL, ?, ?, ?, ?, ?, ?) '
      'ON CONFLICT(design_revision_id, id) DO UPDATE SET '
      'bank_component_id = excluded.bank_component_id, unit_ref_json = excluded.unit_ref_json, '
      'series_count = excluded.series_count, parallel_count = excluded.parallel_count, '
      'usable_model_json = excluded.usable_model_json, revision = battery_bank_bindings.revision + 1, '
      'updated_at = excluded.updated_at, deleted_at = NULL, origin_device_id = excluded.origin_device_id',
      [
        Variable.withString(command.projectId),
        Variable.withString(command.designRevisionId),
        Variable.withString(command.bindingId),
        Variable<DateTime>(now().toUtc()),
        Variable<DateTime>(now().toUtc()),
        Variable.withString(originDeviceId),
        Variable.withString(binding.componentId),
        Variable.withString(
          canonicalEngineeringJsonV1(
            binding.unitDefinition.definitionRef.toMap(),
          ),
        ),
        Variable.withInt(binding.seriesCount),
        Variable.withInt(binding.parallelCount),
        Variable.withString(canonicalEngineeringJsonV1(binding.toMap())),
      ],
    );
  }

  Future<List<PowerNodeKeyV2>> _invalidateDependencyClosure(
    PowerMutationCommand command,
  ) async {
    final affected = <String, PowerNodeKeyV2>{};
    final queue = <PowerNodeKeyV2>[];

    Future<void> discover(String type, String encodedRef) async {
      final sha = sha256HexUtf8(encodedRef);
      final rows =
          await database
              .customSelect(
                'SELECT logical_node_key_json FROM power_dependency_index_records '
                'WHERE project_id = ? AND design_revision_id = ? '
                'AND dependency_ref_type = ? AND dependency_ref_sha256 = ?',
                variables: [
                  Variable.withString(command.projectId),
                  Variable.withString(command.designRevisionId),
                  Variable.withString(type),
                  Variable.withString(sha),
                ],
              )
              .get();
      for (final row in rows) {
        final key = PowerNodeKeyV2.decode(
          row.read<String>('logical_node_key_json'),
        );
        if (affected.putIfAbsent(key.encode(), () => key) == key) {
          if (!queue.contains(key)) queue.add(key);
        }
      }
    }

    for (final dependency in command.changedDependencies) {
      await discover('FACT', dependency.encode());
    }
    var index = 0;
    while (index < queue.length) {
      await discover('EVALUATION', queue[index++].encode());
    }

    final keys = affected.values.toList()..sort();
    final invalidated = <PowerNodeKeyV2>[];
    for (final key in keys) {
      final changed = await database.customUpdate(
        'UPDATE power_evaluation_pointers '
        "SET state = 'STALE', generation = generation + 1, updated_at = ?, origin_device_id = ? "
        'WHERE project_id = ? AND design_revision_id = ? '
        "AND logical_node_key_sha256 = ? AND state = 'CURRENT'",
        variables: [
          Variable<DateTime>(now().toUtc()),
          Variable.withString(originDeviceId),
          Variable.withString(command.projectId),
          Variable.withString(command.designRevisionId),
          Variable.withString(key.sha256),
        ],
      );
      if (changed == 1) invalidated.add(key);
      await database.customUpdate(
        'DELETE FROM power_dependency_index_records '
        'WHERE project_id = ? AND design_revision_id = ? AND logical_node_key_sha256 = ?',
        variables: [
          Variable.withString(command.projectId),
          Variable.withString(command.designRevisionId),
          Variable.withString(key.sha256),
        ],
      );
    }
    return List.unmodifiable(invalidated);
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

  Future<void> _requirePort(String projectId, String portId) => _requireExists(
    'SELECT 1 FROM engineering_port_instances '
        'WHERE project_id = ? AND id = ? AND deleted_at IS NULL',
    [Variable.withString(projectId), Variable.withString(portId)],
    'ELV4_PORT_SCOPE_MISMATCH',
  );

  Future<void> _requireComponent(
    String projectId,
    String componentId,
  ) => _requireExists(
    'SELECT 1 FROM component_instances c '
        'JOIN rooms r ON r.id = c.room_id '
        'JOIN floors f ON f.id = r.floor_id '
        'WHERE f.project_id = ? AND c.id = ? '
        'AND c.deleted_at IS NULL AND r.deleted_at IS NULL AND f.deleted_at IS NULL',
    [Variable.withString(projectId), Variable.withString(componentId)],
    'ELV4_COMPONENT_SCOPE_MISMATCH',
  );

  Future<void> _requireConnection(String projectId, String connectionId) =>
      _requireExists(
        'SELECT 1 FROM engineering_port_connections '
            'WHERE project_id = ? AND id = ? AND deleted_at IS NULL',
        [Variable.withString(projectId), Variable.withString(connectionId)],
        'ELV4_CONNECTION_SCOPE_MISMATCH',
      );

  Future<void> _requireAllocation(String projectId, String allocationId) =>
      _requireExists(
        'SELECT 1 FROM cable_allocations '
            'WHERE project_id = ? AND id = ? AND deleted_at IS NULL',
        [Variable.withString(projectId), Variable.withString(allocationId)],
        'ELV4_ALLOCATION_SCOPE_MISMATCH',
      );

  Future<void> _requireExists(
    String sql,
    List<Variable<Object>> variables,
    String code,
  ) async {
    final row =
        await database
            .customSelect(sql, variables: variables)
            .getSingleOrNull();
    if (row == null) throw PowerRuntimeStorageException(code);
  }

  List<String> _affectedIds(PowerMutationCommand command) => switch (command) {
    BindPowerPortCommand value => [value.bindingId, value.binding.portId],
    ReleasePowerPortCommand value => [value.bindingId],
    BindPowerComponentCommand value => [
      value.bindingId,
      value.binding.componentId,
    ],
    SetPowerLoadCommand value => [value.contribution.id],
    ReplacePowerTransferCommand value => [value.transfer.id],
    ReplacePowerCapacityGroupCommand value => [value.group.id],
    ReplacePowerSupplyRequirementCommand value => [value.requirement.id],
    ReplacePowerScenarioCommand value => [value.scenario.scenarioId],
    ArchivePowerScenarioCommand value => [value.scenarioId],
    BindPoeDeliveryCommand value => [value.deliveryId],
    ConfigureBackupAssemblyCommand value => [value.assemblyId],
    ReplaceBatteryBankCommand value => [value.bindingId],
    _ =>
      throw const PowerRuntimeStorageException(
        'ELV4_UNSUPPORTED_MUTATION_COMMAND',
      ),
  };
}
