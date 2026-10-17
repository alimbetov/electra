import 'dart:convert';

import 'package:engineering_core/engineering_core.dart';

import 'elv_cable_allocation_command.dart';
import 'elv_command_result.dart';
import 'elv_write_unit_of_work.dart';

abstract interface class ElvCableAllocationService {
  Future<ElvCommandResult<CableAllocation>> createDraft(
    CreateCableAllocationDraftCommand command,
  );
  Future<ElvCommandResult<CableAllocation>> reserve(
    ReserveCableResourcesCommand command,
  );
  Future<ElvCommandResult<CableAllocation>> replaceTerminations(
    ReplaceCableTerminationSetCommand command,
  );
  Future<ElvCommandResult<CableAllocation>> activate(
    ActivateCableAllocationCommand command,
  );
  Future<ElvCommandResult<CableAllocation>> release(
    ReleaseCableResourcesCommand command,
  );
  Future<ElvCommandResult<CableAllocation>> archive(
    ArchiveCableAllocationCommand command,
  );
}

final class DefaultElvCableAllocationService
    implements ElvCableAllocationService {
  DefaultElvCableAllocationService({
    required this.unitOfWork,
    required this.originDeviceId,
    DateTime Function()? now,
  }) : _now = now ?? (() => DateTime.now().toUtc());

  final ElvWriteUnitOfWork<ElvAllocationWriteSession> unitOfWork;
  final String originDeviceId;
  final DateTime Function() _now;

  @override
  Future<ElvCommandResult<CableAllocation>> createDraft(
    CreateCableAllocationDraftCommand command,
  ) => unitOfWork.run((session) async {
    final envelope = _validateEnvelope(command.commandId, command.projectId);
    if (envelope != null) return envelope;
    final replay = await _replay(
      session.commandLedger,
      commandId: command.commandId,
      projectId: command.projectId,
      commandType: 'CREATE_CABLE_ALLOCATION_DRAFT',
      payload: command.normalizedPayload(),
    );
    if (replay != null) return replay;

    final connection = await session.allocations.findConnection(
      command.projectId,
      command.engineeringConnectionId,
    );
    if (connection == null) {
      return _reject(
        session.commandLedger,
        commandId: command.commandId,
        projectId: command.projectId,
        commandType: 'CREATE_CABLE_ALLOCATION_DRAFT',
        payload: command.normalizedPayload(),
        failure: const ElvFailure(
          code: 'ELV_ALLOC_CONNECTION_NOT_FOUND',
          category: ElvFailureCategory.notFound,
        ),
      );
    }
    if (!connection.wired) {
      return _reject(
        session.commandLedger,
        commandId: command.commandId,
        projectId: command.projectId,
        commandType: 'CREATE_CABLE_ALLOCATION_DRAFT',
        payload: command.normalizedPayload(),
        failure: const ElvFailure(
          code: 'ELV_ALLOC_CONNECTION_NOT_WIRED',
          category: ElvFailureCategory.validation,
        ),
      );
    }
    final cable = await session.allocations.findCable(
      command.projectId,
      command.cableId,
    );
    if (cable == null || cable.lifecycleState != CableLifecycleState.active) {
      return _reject(
        session.commandLedger,
        commandId: command.commandId,
        projectId: command.projectId,
        commandType: 'CREATE_CABLE_ALLOCATION_DRAFT',
        payload: command.normalizedPayload(),
        failure: const ElvFailure(
          code: 'ELV_ALLOC_CABLE_NOT_FOUND',
          category: ElvFailureCategory.notFound,
        ),
      );
    }
    if (await session.allocations.findAllocation(
          command.projectId,
          command.allocationId,
        ) !=
        null) {
      return _reject(
        session.commandLedger,
        commandId: command.commandId,
        projectId: command.projectId,
        commandType: 'CREATE_CABLE_ALLOCATION_DRAFT',
        payload: command.normalizedPayload(),
        failure: const ElvFailure(
          code: 'ELV_ALLOC_ID_CONFLICT',
          category: ElvFailureCategory.validation,
        ),
      );
    }

    final allocation = CableAllocation(
      id: command.allocationId.trim(),
      projectId: command.projectId.trim(),
      engineeringConnectionId: command.engineeringConnectionId.trim(),
      cableId: command.cableId.trim(),
      state: CableAllocationState.draft,
      revision: 1,
      transitionRef: _nullable(command.transitionRef),
    );
    if (allocation.validate().isNotEmpty ||
        !await session.allocations.insertDraft(allocation)) {
      return _reject(
        session.commandLedger,
        commandId: command.commandId,
        projectId: command.projectId,
        commandType: 'CREATE_CABLE_ALLOCATION_DRAFT',
        payload: command.normalizedPayload(),
        failure: const ElvFailure(
          code: 'ELV_ALLOC_CREATE_CONFLICT',
          category: ElvFailureCategory.validation,
        ),
      );
    }
    await _recordSuccess(
      session.commandLedger,
      commandId: command.commandId,
      projectId: command.projectId,
      commandType: 'CREATE_CABLE_ALLOCATION_DRAFT',
      payload: command.normalizedPayload(),
      allocation: allocation,
    );
    return ElvCommandSuccess(allocation);
  });

  @override
  Future<ElvCommandResult<CableAllocation>> reserve(
    ReserveCableResourcesCommand command,
  ) => unitOfWork.run((session) async {
    final replay = await _preflight(
      session,
      command.commandId,
      command.projectId,
      'RESERVE_CABLE_RESOURCES',
      command.normalizedPayload(),
    );
    if (replay != null) return replay;
    final loaded = await _loadExpected(
      session,
      command.projectId,
      command.allocationId,
      command.expectedRevision,
      {CableAllocationState.draft},
    );
    if (loaded.result != null) return loaded.result!;
    final allocation = loaded.allocation!;
    final cable = await session.allocations.findCable(
      command.projectId,
      allocation.cableId,
    );
    if (cable == null || cable.lifecycleState != CableLifecycleState.active) {
      return _failure('ELV_ALLOC_CABLE_NOT_FOUND', ElvFailureCategory.notFound);
    }
    if (await session.allocations.connectionHasConsumingAllocation(
      command.projectId,
      allocation.engineeringConnectionId,
      excludingAllocationId: allocation.id,
    )) {
      return _failure(
        'ELV_ALLOC_CONNECTION_ALREADY_CONSUMING',
        ElvFailureCategory.dependencyImpact,
      );
    }
    final definition = await session.references.resolveCableDefinition(
      command.projectId,
      cable.definitionRef,
    );
    ResolvedCableResourceSelection resolved;
    try {
      resolved = CableResourceResolver.resolve(
        definition: definition,
        selection: command.selection,
      );
    } on CableResourceResolutionException catch (error) {
      return _failure(error.code, ElvFailureCategory.validation, error.details);
    }
    final evidence = CableAllocationResourceSelectionEvidence(
      allocationId: allocation.id,
      cableDefinitionRef: cable.definitionRef,
      selection: resolved.selection,
      resolvedAtoms: resolved.atomicResourceIdentities,
      selectionSha256: resolved.selectionSha256,
    );
    final updated = allocation.copyWith(
      state: CableAllocationState.reserved,
      revision: allocation.revision + 1,
    );
    final outcome = await session.allocations.reserve(
      allocation: updated,
      expectedRevision: command.expectedRevision,
      evidence: evidence,
    );
    if (outcome != ElvAllocationMutationOutcome.success) {
      return _mutationFailure(outcome);
    }
    await _recordSuccess(
      session.commandLedger,
      commandId: command.commandId,
      projectId: command.projectId,
      commandType: 'RESERVE_CABLE_RESOURCES',
      payload: command.normalizedPayload(),
      allocation: updated,
    );
    return ElvCommandSuccess(updated);
  });

  @override
  Future<ElvCommandResult<CableAllocation>> replaceTerminations(
    ReplaceCableTerminationSetCommand command,
  ) => unitOfWork.run((session) async {
    final replay = await _preflight(
      session,
      command.commandId,
      command.projectId,
      'REPLACE_CABLE_TERMINATIONS',
      command.normalizedPayload(),
    );
    if (replay != null) return replay;
    final loaded = await _loadExpected(
      session,
      command.projectId,
      command.allocationId,
      command.expectedRevision,
      {CableAllocationState.reserved, CableAllocationState.active},
    );
    if (loaded.result != null) return loaded.result!;
    final allocation = loaded.allocation!;
    final context = await _terminationContext(session, allocation);
    if (context.failure != null)
      return ElvCommandFailureResult(context.failure!);
    final errors = _validateMappings(
      allocation: allocation,
      connection: context.connection!,
      definition: context.definition!,
      evidence: context.evidence!,
      mappings: command.completeMappings,
      requireComplete: false,
    );
    if (errors.isNotEmpty) {
      return _failure(
        'ELV_TERMINATION_SET_INVALID',
        ElvFailureCategory.validation,
        {'errors': errors},
      );
    }
    final updated = allocation.copyWith(revision: allocation.revision + 1);
    final outcome = await session.allocations.replaceTerminations(
      allocation: updated,
      expectedRevision: command.expectedRevision,
      mappings: command.completeMappings,
    );
    if (outcome != ElvAllocationMutationOutcome.success) {
      return _mutationFailure(outcome);
    }
    await _recordSuccess(
      session.commandLedger,
      commandId: command.commandId,
      projectId: command.projectId,
      commandType: 'REPLACE_CABLE_TERMINATIONS',
      payload: command.normalizedPayload(),
      allocation: updated,
    );
    return ElvCommandSuccess(updated);
  });

  @override
  Future<ElvCommandResult<CableAllocation>> activate(
    ActivateCableAllocationCommand command,
  ) => unitOfWork.run((session) async {
    final replay = await _preflight(
      session,
      command.commandId,
      command.projectId,
      'ACTIVATE_CABLE_ALLOCATION',
      command.normalizedPayload(),
    );
    if (replay != null) return replay;
    final loaded = await _loadExpected(
      session,
      command.projectId,
      command.allocationId,
      command.expectedRevision,
      {CableAllocationState.reserved},
    );
    if (loaded.result != null) return loaded.result!;
    final allocation = loaded.allocation!;
    final context = await _terminationContext(session, allocation);
    if (context.failure != null)
      return ElvCommandFailureResult(context.failure!);
    final mappings = await session.allocations.loadTerminationMappings(
      command.projectId,
      allocation.id,
    );
    final errors = _validateMappings(
      allocation: allocation,
      connection: context.connection!,
      definition: context.definition!,
      evidence: context.evidence!,
      mappings: mappings,
      requireComplete: true,
    );
    if (errors.isNotEmpty) {
      return _failure(
        'ELV_TERMINATION_INCOMPLETE',
        ElvFailureCategory.validation,
        {'errors': errors},
      );
    }
    final updated = allocation.copyWith(
      state: CableAllocationState.active,
      revision: allocation.revision + 1,
    );
    final outcome = await session.allocations.activate(
      allocation: updated,
      expectedRevision: command.expectedRevision,
    );
    if (outcome != ElvAllocationMutationOutcome.success) {
      return _mutationFailure(outcome);
    }
    await _recordSuccess(
      session.commandLedger,
      commandId: command.commandId,
      projectId: command.projectId,
      commandType: 'ACTIVATE_CABLE_ALLOCATION',
      payload: command.normalizedPayload(),
      allocation: updated,
    );
    return ElvCommandSuccess(updated);
  });

  @override
  Future<ElvCommandResult<CableAllocation>> release(
    ReleaseCableResourcesCommand command,
  ) => unitOfWork.run((session) async {
    final replay = await _preflight(
      session,
      command.commandId,
      command.projectId,
      'RELEASE_CABLE_RESOURCES',
      command.normalizedPayload(),
    );
    if (replay != null) return replay;
    final loaded = await _loadExpected(
      session,
      command.projectId,
      command.allocationId,
      command.expectedRevision,
      {CableAllocationState.reserved, CableAllocationState.active},
    );
    if (loaded.result != null) return loaded.result!;
    final allocation = loaded.allocation!;
    final count = await session.allocations.consumingAllocationCount(
      command.projectId,
      allocation.cableId,
    );
    if (count <= 1 &&
        await session.allocations.hasActiveCanonicalRun(
          command.projectId,
          allocation.cableId,
        )) {
      return _failure(
        'ELV_ALLOC_RELEASE_BLOCKED_BY_ACTIVE_RUN',
        ElvFailureCategory.dependencyImpact,
      );
    }
    final updated = allocation.copyWith(
      state: CableAllocationState.released,
      revision: allocation.revision + 1,
    );
    final outcome = await session.allocations.release(
      allocation: updated,
      expectedRevision: command.expectedRevision,
    );
    if (outcome != ElvAllocationMutationOutcome.success) {
      return _mutationFailure(outcome);
    }
    await _recordSuccess(
      session.commandLedger,
      commandId: command.commandId,
      projectId: command.projectId,
      commandType: 'RELEASE_CABLE_RESOURCES',
      payload: command.normalizedPayload(),
      allocation: updated,
    );
    return ElvCommandSuccess(updated);
  });

  @override
  Future<ElvCommandResult<CableAllocation>> archive(
    ArchiveCableAllocationCommand command,
  ) => unitOfWork.run((session) async {
    final replay = await _preflight(
      session,
      command.commandId,
      command.projectId,
      'ARCHIVE_CABLE_ALLOCATION',
      command.normalizedPayload(),
    );
    if (replay != null) return replay;
    final loaded = await _loadExpected(
      session,
      command.projectId,
      command.allocationId,
      command.expectedRevision,
      {CableAllocationState.draft, CableAllocationState.released},
    );
    if (loaded.result != null) return loaded.result!;
    final allocation = loaded.allocation!;
    final updated = allocation.copyWith(
      state: CableAllocationState.archived,
      revision: allocation.revision + 1,
    );
    final outcome = await session.allocations.archive(
      allocation: updated,
      expectedRevision: command.expectedRevision,
    );
    if (outcome != ElvAllocationMutationOutcome.success) {
      return _mutationFailure(outcome);
    }
    await _recordSuccess(
      session.commandLedger,
      commandId: command.commandId,
      projectId: command.projectId,
      commandType: 'ARCHIVE_CABLE_ALLOCATION',
      payload: command.normalizedPayload(),
      allocation: updated,
    );
    return ElvCommandSuccess(updated);
  });

  ElvCommandFailureResult<CableAllocation>? _validateEnvelope(
    String commandId,
    String projectId,
  ) {
    if (commandId.trim().isEmpty || projectId.trim().isEmpty) {
      return _failure(
        'ELV_COMMAND_ENVELOPE_INVALID',
        ElvFailureCategory.commandEnvelope,
      );
    }
    return null;
  }

  Future<ElvCommandResult<CableAllocation>?> _preflight(
    ElvAllocationWriteSession session,
    String commandId,
    String projectId,
    String commandType,
    Map<String, Object?> payload,
  ) async {
    final envelope = _validateEnvelope(commandId, projectId);
    if (envelope != null) return envelope;
    return _replay(
      session.commandLedger,
      commandId: commandId,
      projectId: projectId,
      commandType: commandType,
      payload: payload,
    );
  }

  Future<_LoadedAllocation> _loadExpected(
    ElvAllocationWriteSession session,
    String projectId,
    String allocationId,
    int expectedRevision,
    Set<CableAllocationState> allowedStates,
  ) async {
    final allocation = await session.allocations.findAllocation(
      projectId,
      allocationId,
    );
    if (allocation == null) {
      return _LoadedAllocation(
        result: _failure('ELV_ALLOC_NOT_FOUND', ElvFailureCategory.notFound),
      );
    }
    if (allocation.revision != expectedRevision) {
      return _LoadedAllocation(
        result: ElvCommandFailureResult(
          ElvFailure(
            code: 'ELV_REVISION_CONFLICT',
            category: ElvFailureCategory.revisionConflict,
            expectedRevision: expectedRevision,
            actualRevision: allocation.revision,
          ),
        ),
      );
    }
    if (!allowedStates.contains(allocation.state)) {
      return _LoadedAllocation(
        result: _failure(
          'ELV_ALLOC_INVALID_STATE',
          ElvFailureCategory.lifecycle,
          {'state': allocation.state.name},
        ),
      );
    }
    return _LoadedAllocation(allocation: allocation);
  }

  Future<_TerminationContext> _terminationContext(
    ElvAllocationWriteSession session,
    CableAllocation allocation,
  ) async {
    final connection = await session.allocations.findConnection(
      allocation.projectId,
      allocation.engineeringConnectionId,
    );
    final cable = await session.allocations.findCable(
      allocation.projectId,
      allocation.cableId,
    );
    final evidence = await session.allocations.loadSelectionEvidence(
      allocation.projectId,
      allocation.id,
    );
    if (connection == null || cable == null || evidence == null) {
      return const _TerminationContext(
        failure: ElvFailure(
          code: 'ELV_TERMINATION_CONTEXT_MISSING',
          category: ElvFailureCategory.referenceIntegrity,
        ),
      );
    }
    final definition = await session.references.resolveCableDefinition(
      allocation.projectId,
      evidence.cableDefinitionRef,
    );
    return _TerminationContext(
      connection: connection,
      definition: definition,
      evidence: evidence,
    );
  }

  List<String> _validateMappings({
    required CableAllocation allocation,
    required dynamic connection,
    required CableDefinition definition,
    required CableAllocationResourceSelectionEvidence evidence,
    required List<CableTerminationMapping> mappings,
    required bool requireComplete,
  }) {
    final errors = validateTerminationSet(mappings);
    final obligations = _obligationResources(definition, evidence.selection);
    final byId = {
      for (final resource in definition.resourceDefinitions)
        resource.identity: resource,
    };
    for (final mapping in mappings) {
      if (mapping.allocationId != allocation.id) {
        errors.add('Termination mapping belongs to another allocation.');
        continue;
      }
      final resource = byId[mapping.resourceIdentity];
      if (resource == null || !obligations.contains(mapping.resourceIdentity)) {
        errors.add(
          'Termination resource ${mapping.resourceIdentity} is not selected.',
        );
        continue;
      }
      final expectedPort = mapping.end == CableTerminationEnd.a
          ? connection.fromPortId as String
          : connection.toPortId as String;
      if (mapping.endpointPortId != expectedPort) {
        errors.add(
          'Termination endpoint does not match connection ${mapping.end.name} end.',
        );
      }
      final policy = resource.terminationPolicy;
      if (policy.terminalRequired && mapping.endpointTerminalRef == null) {
        errors.add('Terminal reference is required for ${resource.identity}.');
      }
      if (policy.allowedRoles.isNotEmpty &&
          (mapping.terminationRole == null ||
              !policy.allowedRoles.contains(
                mapping.terminationRole!.toUpperCase(),
              ))) {
        errors.add('Termination role is invalid for ${resource.identity}.');
      }
    }
    if (requireComplete) {
      final keys = mappings
          .map((mapping) => '${mapping.resourceIdentity}|${mapping.end.name}')
          .toSet();
      for (final identity in obligations) {
        final resource = byId[identity]!;
        final policy = resource.terminationPolicy.mode;
        final requiredEnds = switch (policy) {
          TerminationPolicyMode.bothEnds || TerminationPolicyMode.groupLevel =>
            const {CableTerminationEnd.a, CableTerminationEnd.b},
          TerminationPolicyMode.aEndOnly => const {CableTerminationEnd.a},
          TerminationPolicyMode.bEndOnly => const {CableTerminationEnd.b},
          TerminationPolicyMode.optional => const <CableTerminationEnd>{},
        };
        for (final end in requiredEnds) {
          if (!keys.contains('$identity|${end.name}')) {
            errors.add(
              'Missing ${end.name.toUpperCase()} termination for $identity.',
            );
          }
        }
      }
    }
    return errors;
  }

  Set<String> _obligationResources(
    CableDefinition definition,
    CableResourceSelection selection,
  ) {
    return switch (selection) {
      WholeCableSelection() => {'__WHOLE_CABLE__'},
      ResourceSetSelection(:final resourceIdentities) =>
        resourceIdentities.toSet(),
      DefinitionGroupSelection(:final groupIdentity) =>
        definition.resourceDefinitions
            .where(
              (resource) =>
                  resource.allocatable &&
                  resource.groupMembership.contains(groupIdentity),
            )
            .map((resource) => resource.identity)
            .toSet(),
    };
  }

  ElvCommandFailureResult<CableAllocation> _mutationFailure(
    ElvAllocationMutationOutcome outcome,
  ) => switch (outcome) {
    ElvAllocationMutationOutcome.revisionConflict => _failure(
      'ELV_REVISION_CONFLICT',
      ElvFailureCategory.revisionConflict,
    ),
    ElvAllocationMutationOutcome.resourceOverlap => _failure(
      'ELV_ALLOC_RESOURCE_OVERLAP',
      ElvFailureCategory.dependencyImpact,
    ),
    ElvAllocationMutationOutcome.immutableEvidenceConflict => _failure(
      'ELV_ALLOC_SELECTION_EVIDENCE_IMMUTABLE',
      ElvFailureCategory.referenceIntegrity,
    ),
    ElvAllocationMutationOutcome.storageConflict => _failure(
      'ELV_ALLOC_STORAGE_CONFLICT',
      ElvFailureCategory.storage,
    ),
    ElvAllocationMutationOutcome.success => throw StateError(
      'Unexpected success',
    ),
  };

  ElvCommandFailureResult<CableAllocation> _failure(
    String code,
    ElvFailureCategory category, [
    Map<String, Object?> details = const {},
  ]) => ElvCommandFailureResult(
    ElvFailure(code: code, category: category, details: details),
  );

  Future<ElvCommandResult<CableAllocation>?> _replay(
    ElvCommandLedgerStore ledger, {
    required String commandId,
    required String projectId,
    required String commandType,
    required Map<String, Object?> payload,
  }) async {
    final existing = await ledger.find(projectId, commandId);
    if (existing == null) return null;
    final hash = _payloadHash(commandType, payload);
    if (existing.commandType != commandType ||
        existing.normalizedPayloadSha256 != hash) {
      return _failure(
        'ELV_IDEMPOTENCY_CONFLICT',
        ElvFailureCategory.commandEnvelope,
      );
    }
    final decoded =
        jsonDecode(existing.logicalResultJson) as Map<String, dynamic>;
    if (existing.outcomeKind == 'SUCCESS') {
      return ElvCommandSuccess(
        CableAllocation.fromMap(decoded['allocation'] as Map<String, dynamic>),
      );
    }
    return ElvCommandFailureResult(
      ElvFailure(
        code: decoded['code'] as String,
        category: ElvFailureCategory.values.byName(
          decoded['category'] as String,
        ),
        details: (decoded['details'] as Map<String, dynamic>? ?? const {})
            .cast<String, Object?>(),
      ),
    );
  }

  Future<ElvCommandFailureResult<CableAllocation>> _reject(
    ElvCommandLedgerStore ledger, {
    required String commandId,
    required String projectId,
    required String commandType,
    required Map<String, Object?> payload,
    required ElvFailure failure,
  }) async {
    await ledger.save(
      ElvCommandLedgerEntry(
        projectId: projectId,
        commandId: commandId,
        commandType: commandType,
        payloadSchemaVersion: 1,
        normalizedPayloadSha256: _payloadHash(commandType, payload),
        outcomeKind: 'FAILURE',
        logicalResultJson: jsonEncode({
          'code': failure.code,
          'category': failure.category.name,
          'details': failure.details,
        }),
        createdAt: _now(),
        committedAt: _now(),
        originDeviceId: originDeviceId,
      ),
    );
    return ElvCommandFailureResult(failure);
  }

  Future<void> _recordSuccess(
    ElvCommandLedgerStore ledger, {
    required String commandId,
    required String projectId,
    required String commandType,
    required Map<String, Object?> payload,
    required CableAllocation allocation,
  }) => ledger.save(
    ElvCommandLedgerEntry(
      projectId: projectId,
      commandId: commandId,
      commandType: commandType,
      payloadSchemaVersion: 1,
      normalizedPayloadSha256: _payloadHash(commandType, payload),
      outcomeKind: 'SUCCESS',
      logicalResultJson: jsonEncode({'allocation': allocation.toMap()}),
      createdAt: _now(),
      committedAt: _now(),
      originDeviceId: originDeviceId,
    ),
  );

  String _payloadHash(String commandType, Map<String, Object?> payload) =>
      sha256HexUtf8(
        canonicalEngineeringJsonV1({
          'schema': 'electra.elv-p2-command.v1',
          'commandType': commandType,
          'payload': payload,
        }),
      );
}

final class _LoadedAllocation {
  const _LoadedAllocation({this.allocation, this.result});
  final CableAllocation? allocation;
  final ElvCommandResult<CableAllocation>? result;
}

final class _TerminationContext {
  const _TerminationContext({
    this.connection,
    this.definition,
    this.evidence,
    this.failure,
  });
  final dynamic connection;
  final CableDefinition? definition;
  final CableAllocationResourceSelectionEvidence? evidence;
  final ElvFailure? failure;
}

String? _nullable(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}
