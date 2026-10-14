import 'dart:convert';

import 'package:engineering_core/engineering_core.dart';

import 'elv_cable_command.dart';
import 'elv_command_result.dart';
import 'elv_write_unit_of_work.dart';

abstract interface class ElvCableCommandService {
  Future<ElvCommandResult<Cable>> create(CreateCableCommand command);
  Future<ElvCommandResult<Cable>> changeDefinition(
    ChangeCableDefinitionRefCommand command,
  );
  Future<ElvCommandResult<Cable>> archive(ArchiveCableCommand command);
}

final class DefaultElvCableCommandService implements ElvCableCommandService {
  DefaultElvCableCommandService({
    required this.unitOfWork,
    required this.originDeviceId,
    DateTime Function()? now,
  }) : _now = now ?? (() => DateTime.now().toUtc());

  final ElvWriteUnitOfWork<ElvCableWriteSession> unitOfWork;
  final String originDeviceId;
  final DateTime Function() _now;

  @override
  Future<ElvCommandResult<Cable>> create(CreateCableCommand command) =>
      unitOfWork.run((session) async {
        final common = _validateEnvelope(command.commandId, command.projectId);
        if (common != null) return common;
        final replay = await _replayCable(
          session.commandLedger,
          commandId: command.commandId,
          projectId: command.projectId,
          commandType: 'CREATE_CABLE',
          schema: 'electra.command.create-cable.v1',
          payload: command.normalizedPayload(),
        );
        if (replay != null) return replay;
        if (!await session.cables.projectExists(command.projectId)) {
          return _reject(
            session.commandLedger,
            commandId: command.commandId,
            projectId: command.projectId,
            commandType: 'CREATE_CABLE',
            schema: 'electra.command.create-cable.v1',
            payload: command.normalizedPayload(),
            failure: const ElvFailure(
              code: 'ELV_PROJECT_NOT_FOUND',
              category: ElvFailureCategory.notFound,
              entityType: 'Project',
            ),
          );
        }
        if (await session.cables.findCable(command.projectId, command.cableId) != null) {
          return _idConflict(session.commandLedger, command);
        }
        CableDefinition definition;
        try {
          definition = await session.cables.resolveDefinition(
            command.projectId,
            command.definitionRef,
          );
        } catch (_) {
          return _reject(
            session.commandLedger,
            commandId: command.commandId,
            projectId: command.projectId,
            commandType: 'CREATE_CABLE',
            schema: 'electra.command.create-cable.v1',
            payload: command.normalizedPayload(),
            failure: const ElvFailure(
              code: 'ELV_CABLE_DEFINITION_REF_INVALID',
              category: ElvFailureCategory.referenceIntegrity,
              entityType: 'CableDefinition',
            ),
          );
        }
        if (definition.deprecated) {
          return _reject(
            session.commandLedger,
            commandId: command.commandId,
            projectId: command.projectId,
            commandType: 'CREATE_CABLE',
            schema: 'electra.command.create-cable.v1',
            payload: command.normalizedPayload(),
            failure: const ElvFailure(
              code: 'ELV_CABLE_DEFINITION_DEPRECATED',
              category: ElvFailureCategory.referenceIntegrity,
            ),
          );
        }
        final cable = Cable(
          id: command.cableId.trim(),
          projectId: command.projectId.trim(),
          label: command.label.trim(),
          name: command.name.trim(),
          definitionRef: command.definitionRef.normalized(),
          lifecycleState: CableLifecycleState.active,
          revision: 1,
        );
        final validation = cable.validate();
        if (validation.isNotEmpty) {
          return _reject(
            session.commandLedger,
            commandId: command.commandId,
            projectId: command.projectId,
            commandType: 'CREATE_CABLE',
            schema: 'electra.command.create-cable.v1',
            payload: command.normalizedPayload(),
            failure: ElvFailure(
              code: 'ELV_CABLE_INVALID',
              category: ElvFailureCategory.validation,
              details: {'errors': validation},
            ),
          );
        }
        if (await session.cables.activeLabelExists(
          command.projectId,
          cable.normalizedLabel,
        )) {
          return _labelConflict(session.commandLedger, command);
        }
        final inserted = await session.cables.insertCable(cable);
        if (!inserted) {
          final sameId =
              await session.cables.findCable(command.projectId, command.cableId);
          return sameId == null
              ? _labelConflict(session.commandLedger, command)
              : _idConflict(session.commandLedger, command);
        }
        await _recordSuccess(
          session.commandLedger,
          commandId: command.commandId,
          projectId: command.projectId,
          commandType: 'CREATE_CABLE',
          schema: 'electra.command.create-cable.v1',
          payload: command.normalizedPayload(),
          cable: cable,
        );
        return ElvCommandSuccess(cable);
      });

  @override
  Future<ElvCommandResult<Cable>> changeDefinition(
    ChangeCableDefinitionRefCommand command,
  ) => unitOfWork.run((session) async {
    final common = _validateEnvelope(command.commandId, command.projectId);
    if (common != null) return common;
    final replay = await _replayCable(
      session.commandLedger,
      commandId: command.commandId,
      projectId: command.projectId,
      commandType: 'CHANGE_CABLE_DEFINITION',
      schema: 'electra.command.change-cable-definition.v1',
      payload: command.normalizedPayload(),
    );
    if (replay != null) return replay;
    final cable = await session.cables.findCable(command.projectId, command.cableId);
    if (cable == null) {
      return _reject(
        session.commandLedger,
        commandId: command.commandId,
        projectId: command.projectId,
        commandType: 'CHANGE_CABLE_DEFINITION',
        schema: 'electra.command.change-cable-definition.v1',
        payload: command.normalizedPayload(),
        failure: const ElvFailure(
          code: 'ELV_CABLE_NOT_FOUND',
          category: ElvFailureCategory.notFound,
          entityType: 'Cable',
        ),
      );
    }
    if (cable.lifecycleState != CableLifecycleState.active) {
      return _reject(
        session.commandLedger,
        commandId: command.commandId,
        projectId: command.projectId,
        commandType: 'CHANGE_CABLE_DEFINITION',
        schema: 'electra.command.change-cable-definition.v1',
        payload: command.normalizedPayload(),
        failure: const ElvFailure(
          code: 'ELV_CABLE_ARCHIVED',
          category: ElvFailureCategory.lifecycle,
        ),
      );
    }
    if (await session.cableDependencies.hasResourceSelectionHistory(
          command.projectId,
          command.cableId,
        ) ||
        await session.cableDependencies.hasCanonicalRunHistory(
          command.projectId,
          command.cableId,
        )) {
      return _reject(
        session.commandLedger,
        commandId: command.commandId,
        projectId: command.projectId,
        commandType: 'CHANGE_CABLE_DEFINITION',
        schema: 'electra.command.change-cable-definition.v1',
        payload: command.normalizedPayload(),
        failure: const ElvFailure(
          code: 'ELV_CABLE_DEFINITION_CHANGE_BLOCKED',
          category: ElvFailureCategory.dependencyImpact,
        ),
      );
    }
    try {
      final definition = await session.cables.resolveDefinition(
        command.projectId,
        command.definitionRef,
      );
      if (definition.deprecated) {
        return _reject(
          session.commandLedger,
          commandId: command.commandId,
          projectId: command.projectId,
          commandType: 'CHANGE_CABLE_DEFINITION',
          schema: 'electra.command.change-cable-definition.v1',
          payload: command.normalizedPayload(),
          failure: const ElvFailure(
            code: 'ELV_CABLE_DEFINITION_DEPRECATED',
            category: ElvFailureCategory.referenceIntegrity,
          ),
        );
      }
    } catch (_) {
      return _reject(
        session.commandLedger,
        commandId: command.commandId,
        projectId: command.projectId,
        commandType: 'CHANGE_CABLE_DEFINITION',
        schema: 'electra.command.change-cable-definition.v1',
        payload: command.normalizedPayload(),
        failure: const ElvFailure(
          code: 'ELV_CABLE_DEFINITION_REF_INVALID',
          category: ElvFailureCategory.referenceIntegrity,
        ),
      );
    }
    final updated = await session.cables.updateDefinition(
      projectId: command.projectId,
      cableId: command.cableId,
      expectedRevision: command.expectedRevision,
      definitionRef: command.definitionRef.normalized(),
    );
    if (!updated) {
      return _revisionConflict(
        session.commandLedger,
        commandId: command.commandId,
        projectId: command.projectId,
        commandType: 'CHANGE_CABLE_DEFINITION',
        schema: 'electra.command.change-cable-definition.v1',
        payload: command.normalizedPayload(),
        expectedRevision: command.expectedRevision,
        actualRevision: cable.revision,
      );
    }
    final result = Cable(
      id: cable.id,
      projectId: cable.projectId,
      label: cable.label,
      name: cable.name,
      definitionRef: command.definitionRef.normalized(),
      lifecycleState: cable.lifecycleState,
      revision: cable.revision + 1,
    );
    await _recordSuccess(
      session.commandLedger,
      commandId: command.commandId,
      projectId: command.projectId,
      commandType: 'CHANGE_CABLE_DEFINITION',
      schema: 'electra.command.change-cable-definition.v1',
      payload: command.normalizedPayload(),
      cable: result,
    );
    return ElvCommandSuccess(result);
  });

  @override
  Future<ElvCommandResult<Cable>> archive(ArchiveCableCommand command) =>
      unitOfWork.run((session) async {
        final common = _validateEnvelope(command.commandId, command.projectId);
        if (common != null) return common;
        final replay = await _replayCable(
          session.commandLedger,
          commandId: command.commandId,
          projectId: command.projectId,
          commandType: 'ARCHIVE_CABLE',
          schema: 'electra.command.archive-cable.v1',
          payload: command.normalizedPayload(),
        );
        if (replay != null) return replay;
        final cable = await session.cables.findCable(command.projectId, command.cableId);
        if (cable == null) {
          return _reject(
            session.commandLedger,
            commandId: command.commandId,
            projectId: command.projectId,
            commandType: 'ARCHIVE_CABLE',
            schema: 'electra.command.archive-cable.v1',
            payload: command.normalizedPayload(),
            failure: const ElvFailure(
              code: 'ELV_CABLE_NOT_FOUND',
              category: ElvFailureCategory.notFound,
            ),
          );
        }
        final blockers = await session.cableDependencies.blockingDependencyIds(
          command.projectId,
          command.cableId,
        );
        if (blockers.isNotEmpty) {
          return _reject(
            session.commandLedger,
            commandId: command.commandId,
            projectId: command.projectId,
            commandType: 'ARCHIVE_CABLE',
            schema: 'electra.command.archive-cable.v1',
            payload: command.normalizedPayload(),
            failure: ElvFailure(
              code: 'ELV_CABLE_ARCHIVE_BLOCKED',
              category: ElvFailureCategory.dependencyImpact,
              details: {'dependencyIds': blockers},
            ),
          );
        }
        final updated = await session.cables.archiveCable(
          projectId: command.projectId,
          cableId: command.cableId,
          expectedRevision: command.expectedRevision,
        );
        if (!updated) {
          return _revisionConflict(
            session.commandLedger,
            commandId: command.commandId,
            projectId: command.projectId,
            commandType: 'ARCHIVE_CABLE',
            schema: 'electra.command.archive-cable.v1',
            payload: command.normalizedPayload(),
            expectedRevision: command.expectedRevision,
            actualRevision: cable.revision,
          );
        }
        final result = Cable(
          id: cable.id,
          projectId: cable.projectId,
          label: cable.label,
          name: cable.name,
          definitionRef: cable.definitionRef,
          lifecycleState: CableLifecycleState.archived,
          revision: cable.revision + 1,
        );
        await _recordSuccess(
          session.commandLedger,
          commandId: command.commandId,
          projectId: command.projectId,
          commandType: 'ARCHIVE_CABLE',
          schema: 'electra.command.archive-cable.v1',
          payload: command.normalizedPayload(),
          cable: result,
        );
        return ElvCommandSuccess(result);
      });

  ElvCommandFailureResult<Cable>? _validateEnvelope(
    String commandId,
    String projectId,
  ) => commandId.trim().isEmpty || projectId.trim().isEmpty
      ? const ElvCommandFailureResult(
          ElvFailure(
            code: 'ELV_COMMAND_INVALID',
            category: ElvFailureCategory.commandEnvelope,
          ),
        )
      : null;

  Future<ElvCommandResult<Cable>?> _replayCable(
    ElvCommandLedgerStore ledger, {
    required String projectId,
    required String commandId,
    required String commandType,
    required String schema,
    required Map<String, Object?> payload,
  }) async {
    final existing = await ledger.find(projectId, commandId);
    if (existing == null) return null;
    if (existing.normalizedPayloadSha256 !=
        _payloadHash(schema, commandType, payload)) {
      return const ElvCommandFailureResult(
        ElvFailure(
          code: 'ELV_IDEMPOTENCY_CONFLICT',
          category: ElvFailureCategory.commandEnvelope,
        ),
      );
    }
    final map = jsonDecode(existing.logicalResultJson) as Map<String, dynamic>;
    if (existing.outcomeKind == 'SUCCESS') {
      return ElvCommandSuccess(
        Cable.fromMap(map['value'] as Map<String, dynamic>),
      );
    }
    return ElvCommandFailureResult(
      _failureFromMap(map['failure'] as Map<String, dynamic>),
    );
  }

  Future<ElvCommandFailureResult<Cable>> _idConflict(
    ElvCommandLedgerStore ledger,
    CreateCableCommand command,
  ) => _reject(
    ledger,
    commandId: command.commandId,
    projectId: command.projectId,
    commandType: 'CREATE_CABLE',
    schema: 'electra.command.create-cable.v1',
    payload: command.normalizedPayload(),
    failure: const ElvFailure(
      code: 'ELV_CABLE_ID_CONFLICT',
      category: ElvFailureCategory.validation,
      entityType: 'Cable',
    ),
  );

  Future<ElvCommandFailureResult<Cable>> _labelConflict(
    ElvCommandLedgerStore ledger,
    CreateCableCommand command,
  ) => _reject(
    ledger,
    commandId: command.commandId,
    projectId: command.projectId,
    commandType: 'CREATE_CABLE',
    schema: 'electra.command.create-cable.v1',
    payload: command.normalizedPayload(),
    failure: const ElvFailure(
      code: 'ELV_CABLE_LABEL_CONFLICT',
      category: ElvFailureCategory.validation,
    ),
  );

  Future<ElvCommandFailureResult<Cable>> _revisionConflict(
    ElvCommandLedgerStore ledger, {
    required String projectId,
    required String commandId,
    required String commandType,
    required String schema,
    required Map<String, Object?> payload,
    required int expectedRevision,
    required int actualRevision,
  }) => _reject(
    ledger,
    projectId: projectId,
    commandId: commandId,
    commandType: commandType,
    schema: schema,
    payload: payload,
    failure: ElvFailure(
      code: 'ELV_REVISION_CONFLICT',
      category: ElvFailureCategory.revisionConflict,
      expectedRevision: expectedRevision,
      actualRevision: actualRevision,
    ),
  );

  Future<ElvCommandFailureResult<Cable>> _reject(
    ElvCommandLedgerStore ledger, {
    required String projectId,
    required String commandId,
    required String commandType,
    required String schema,
    required Map<String, Object?> payload,
    required ElvFailure failure,
  }) async {
    final now = _now();
    await ledger.save(
      ElvCommandLedgerEntry(
        projectId: projectId,
        commandId: commandId,
        commandType: commandType,
        payloadSchemaVersion: 1,
        normalizedPayloadSha256: _payloadHash(schema, commandType, payload),
        outcomeKind: 'REJECTED',
        logicalResultJson: canonicalEngineeringJsonV1({
          'schema': 'electra.elv-command-result.v1',
          'failure': _failureToMap(failure),
        }),
        createdAt: now,
        committedAt: now,
        originDeviceId: originDeviceId,
      ),
    );
    return ElvCommandFailureResult(failure);
  }

  Future<void> _recordSuccess(
    ElvCommandLedgerStore ledger, {
    required String projectId,
    required String commandId,
    required String commandType,
    required String schema,
    required Map<String, Object?> payload,
    required Cable cable,
  }) async {
    final now = _now();
    await ledger.save(
      ElvCommandLedgerEntry(
        projectId: projectId,
        commandId: commandId,
        commandType: commandType,
        payloadSchemaVersion: 1,
        normalizedPayloadSha256: _payloadHash(schema, commandType, payload),
        outcomeKind: 'SUCCESS',
        logicalResultJson: canonicalEngineeringJsonV1({
          'schema': 'electra.elv-command-result.v1',
          'value': cable.toMap(),
        }),
        createdAt: now,
        committedAt: now,
        originDeviceId: originDeviceId,
      ),
    );
  }

  String _payloadHash(
    String schema,
    String commandType,
    Map<String, Object?> payload,
  ) => sha256HexUtf8(
    canonicalEngineeringJsonV1({
      'schema': schema,
      'commandType': commandType,
      'payload': payload,
    }),
  );

  Map<String, Object?> _failureToMap(ElvFailure failure) => {
    'code': failure.code,
    'category': failure.category.name,
    'entityType': failure.entityType,
    'entityId': failure.entityId,
    'field': failure.field,
    'expectedRevision': failure.expectedRevision,
    'actualRevision': failure.actualRevision,
    'details': failure.details,
  };

  ElvFailure _failureFromMap(Map<String, dynamic> map) => ElvFailure(
    code: map['code'] as String,
    category: ElvFailureCategory.values.byName(map['category'] as String),
    entityType: map['entityType'] as String?,
    entityId: map['entityId'] as String?,
    field: map['field'] as String?,
    expectedRevision: map['expectedRevision'] as int?,
    actualRevision: map['actualRevision'] as int?,
    details: (map['details'] as Map<String, dynamic>? ?? const {}),
  );
}
