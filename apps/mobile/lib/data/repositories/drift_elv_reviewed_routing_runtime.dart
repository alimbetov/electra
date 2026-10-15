import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core.dart';

import '../../application/elv_cable_run_command.dart';
import '../../application/elv_command_result.dart';
import '../../application/elv_physical_routing_workspace_service.dart';
import '../../application/elv_reviewed_reroute_command.dart';
import '../../application/elv_revision_command_history_service.dart';
import '../../application/id_generator.dart';
import '../database/app_database.dart';
import 'drift_elv_cable_run_repository.dart';

/// Production P7/T06 runtime for reviewed canonical reroutes and RM08 history.
///
/// The original reroute, immutable before/after aggregate evidence, history
/// operation, cursor movement and execution link share one outer Drift
/// transaction. [DriftElvCableRunRepository] remains the canonical mutator and
/// continues to own command-ledger replay plus row-level revision validation.
final class DriftElvReviewedRoutingRuntime
    implements ElvWorkspaceCommandService, ElvRevisionCommandHistoryService {
  DriftElvReviewedRoutingRuntime(
    this.database, {
    required this.originDeviceId,
    required this.idGenerator,
    DateTime Function()? now,
  }) : _now = now ?? (() => DateTime.now().toUtc());

  final AppDatabase database;
  final String originDeviceId;
  final IdGenerator idGenerator;
  final DateTime Function() _now;

  DriftElvCableRunRepository get _runs => DriftElvCableRunRepository(
    database,
    originDeviceId: originDeviceId,
    now: _now,
  );

  @override
  Future<ElvCommandResult<Object?>> execute(ElvWorkspaceCommand command) {
    if (command is! ReviewedRerouteCableRunWorkspaceCommand) {
      return Future.value(
        const ElvCommandFailureResult<Object?>(
          ElvFailure(
            code: 'ELV4_REVIEWED_COMMAND_UNSUPPORTED',
            category: ElvFailureCategory.validation,
          ),
        ),
      );
    }
    return _executeReviewedReroute(command);
  }

  Future<ElvCommandResult<Object?>> _executeReviewedReroute(
    ReviewedRerouteCableRunWorkspaceCommand command,
  ) => database.transaction(() async {
    final lifecycleFailure = await _workingRevisionFailure(
      command.projectId,
      command.designRevisionId,
    );
    if (lifecycleFailure != null) return lifecycleFailure;

    final replay = await _historyByOriginalCommand(
      command.projectId,
      command.designRevisionId,
      command.commandId,
    );
    if (replay != null) {
      final rerouteReplay = await _runs.reroute(_rerouteCommand(command));
      return _objectResult(rerouteReplay);
    }

    final before = await _captureAggregate(
      projectId: command.projectId,
      designRevisionId: command.designRevisionId,
      cableRunId: command.cableRunId,
    );
    if (before == null) {
      return const ElvCommandFailureResult<Object?>(
        ElvFailure(
          code: 'ELV_RUN_NOT_FOUND',
          category: ElvFailureCategory.notFound,
        ),
      );
    }
    if (before.run.revision != command.expectedRevision) {
      return ElvCommandFailureResult<Object?>(
        ElvFailure(
          code: 'ELV_RUN_REVISION_CONFLICT',
          category: ElvFailureCategory.revisionConflict,
          expectedRevision: command.expectedRevision,
          actualRevision: before.run.revision,
        ),
      );
    }

    final mutation = await _runs.reroute(_rerouteCommand(command));
    if (mutation is ElvCommandFailureResult<CanonicalCableRun>) {
      return ElvCommandFailureResult<Object?>(mutation.failure);
    }

    final after = await _captureAggregate(
      projectId: command.projectId,
      designRevisionId: command.designRevisionId,
      cableRunId: command.cableRunId,
    );
    if (after == null) {
      throw StateError(
        'Committed reroute aggregate disappeared before history capture.',
      );
    }

    await _appendRerouteHistory(command: command, before: before, after: after);
    return ElvCommandSuccess<Object?>((mutation as ElvCommandSuccess).value);
  });

  @override
  Future<bool> canUndo({
    required String projectId,
    required String designRevisionId,
  }) async {
    if (!await _isWorking(projectId, designRevisionId)) return false;
    final cursor = await _cursor(projectId, designRevisionId);
    if (cursor == null || cursor.headSequence < 1) return false;
    final candidate = await _operation(
      projectId,
      designRevisionId,
      cursor.headSequence,
    );
    return candidate?.state == 'APPLIED';
  }

  @override
  Future<bool> canRedo({
    required String projectId,
    required String designRevisionId,
  }) async {
    if (!await _isWorking(projectId, designRevisionId)) return false;
    final cursor = await _cursor(projectId, designRevisionId);
    if (cursor == null) return false;
    return await _redoCandidate(
          projectId,
          designRevisionId,
          cursor.headSequence,
        ) !=
        null;
  }

  @override
  Future<ElvCommandResult<Object?>> undo({
    required String projectId,
    required String designRevisionId,
    required String executionCommandId,
  }) => database.transaction(() async {
    final replay = await _replayHistoryExecution(
      projectId: projectId,
      designRevisionId: designRevisionId,
      executionCommandId: executionCommandId,
      expectedKind: 'UNDO',
    );
    if (replay != null) return replay;
    final lifecycleFailure = await _workingRevisionFailure(
      projectId,
      designRevisionId,
    );
    if (lifecycleFailure != null) return lifecycleFailure;
    final cursor = await _cursor(projectId, designRevisionId);
    if (cursor == null || cursor.headSequence < 1) {
      return _historyFailure('ELV4_HISTORY_UNDO_NOT_AVAILABLE');
    }
    final operation = await _operation(
      projectId,
      designRevisionId,
      cursor.headSequence,
    );
    if (operation == null || operation.state != 'APPLIED') {
      return _historyFailure('ELV4_HISTORY_UNDO_NOT_AVAILABLE');
    }
    if (operation.inverseCommandType != 'REROUTE_CABLE_RUN') {
      return _historyFailure('ELV4_HISTORY_COMMAND_UNSUPPORTED');
    }

    final inversePayload = _decodePayload(
      operation.inverseCanonicalPayloadJson,
    );
    final cableRunId = _requiredString(inversePayload, 'cableRunId');
    final current = await _captureAggregate(
      projectId: projectId,
      designRevisionId: designRevisionId,
      cableRunId: cableRunId,
    );
    if (current == null || current.sha256 != operation.afterAggregateHash) {
      return _historyFailure('ELV4_HISTORY_AGGREGATE_CHANGED');
    }

    final effectivePayload = _storedReroutePayload(
      commandId: executionCommandId,
      projectId: projectId,
      designRevisionId: designRevisionId,
      cableRunId: cableRunId,
      expectedRevision: current.run.revision,
      traversals: _decodeTraversals(inversePayload, cableRunId),
    );
    final mutation = await _runs.reroute(
      _rerouteFromStoredPayload(effectivePayload.json),
    );
    if (mutation is ElvCommandFailureResult<CanonicalCableRun>) {
      return ElvCommandFailureResult<Object?>(mutation.failure);
    }

    final restored = await _captureAggregate(
      projectId: projectId,
      designRevisionId: designRevisionId,
      cableRunId: cableRunId,
    );
    if (restored == null || restored.sha256 != operation.beforeAggregateHash) {
      throw StateError(
        'Undo postcondition does not match durable before evidence.',
      );
    }

    final previousHead = await _previousAppliedSequence(
      projectId,
      designRevisionId,
      operation.sequence,
    );
    final nextGeneration = cursor.generation + 1;
    final changed = await (database.update(
      database.elvRevisionCommandHistoryOperations,
    )..where(
      (row) =>
          row.projectId.equals(projectId) &
          row.designRevisionId.equals(designRevisionId) &
          row.sequence.equals(operation.sequence) &
          row.state.equals('APPLIED') &
          row.cursorGeneration.equals(operation.cursorGeneration),
    )).write(
      ElvRevisionCommandHistoryOperationsCompanion(
        state: const Value('UNDONE'),
        cursorGeneration: Value(nextGeneration),
        updatedAt: Value(_now()),
        originDeviceId: Value(originDeviceId),
      ),
    );
    if (changed != 1) {
      throw StateError('Undo history CAS failed after canonical mutation.');
    }
    await _moveCursor(
      cursor,
      generation: nextGeneration,
      headSequence: previousHead,
      branchId: cursor.branchId,
    );
    await _insertExecution(
      projectId: projectId,
      designRevisionId: designRevisionId,
      historySequence: operation.sequence,
      commandId: executionCommandId,
      kind: 'UNDO',
      payload: effectivePayload,
    );
    return ElvCommandSuccess<Object?>((mutation as ElvCommandSuccess).value);
  });

  @override
  Future<ElvCommandResult<Object?>> redo({
    required String projectId,
    required String designRevisionId,
    required String executionCommandId,
  }) => database.transaction(() async {
    final replay = await _replayHistoryExecution(
      projectId: projectId,
      designRevisionId: designRevisionId,
      executionCommandId: executionCommandId,
      expectedKind: 'REDO',
    );
    if (replay != null) return replay;
    final lifecycleFailure = await _workingRevisionFailure(
      projectId,
      designRevisionId,
    );
    if (lifecycleFailure != null) return lifecycleFailure;
    final cursor = await _cursor(projectId, designRevisionId);
    if (cursor == null)
      return _historyFailure('ELV4_HISTORY_REDO_NOT_AVAILABLE');
    final operation = await _redoCandidate(
      projectId,
      designRevisionId,
      cursor.headSequence,
    );
    if (operation == null) {
      return _historyFailure('ELV4_HISTORY_REDO_NOT_AVAILABLE');
    }
    if (operation.forwardCommandType != 'REROUTE_CABLE_RUN') {
      return _historyFailure('ELV4_HISTORY_COMMAND_UNSUPPORTED');
    }

    final forwardPayload = _decodePayload(
      operation.forwardCanonicalPayloadJson,
    );
    final cableRunId = _requiredString(forwardPayload, 'cableRunId');
    final current = await _captureAggregate(
      projectId: projectId,
      designRevisionId: designRevisionId,
      cableRunId: cableRunId,
    );
    if (current == null || current.sha256 != operation.beforeAggregateHash) {
      return _historyFailure('ELV4_HISTORY_AGGREGATE_CHANGED');
    }

    final effectivePayload = _storedReroutePayload(
      commandId: executionCommandId,
      projectId: projectId,
      designRevisionId: designRevisionId,
      cableRunId: cableRunId,
      expectedRevision: current.run.revision,
      traversals: _decodeTraversals(forwardPayload, cableRunId),
    );
    final mutation = await _runs.reroute(
      _rerouteFromStoredPayload(effectivePayload.json),
    );
    if (mutation is ElvCommandFailureResult<CanonicalCableRun>) {
      return ElvCommandFailureResult<Object?>(mutation.failure);
    }

    final restored = await _captureAggregate(
      projectId: projectId,
      designRevisionId: designRevisionId,
      cableRunId: cableRunId,
    );
    if (restored == null || restored.sha256 != operation.afterAggregateHash) {
      throw StateError(
        'Redo postcondition does not match durable after evidence.',
      );
    }

    final nextGeneration = cursor.generation + 1;
    final changed = await (database.update(
      database.elvRevisionCommandHistoryOperations,
    )..where(
      (row) =>
          row.projectId.equals(projectId) &
          row.designRevisionId.equals(designRevisionId) &
          row.sequence.equals(operation.sequence) &
          row.state.equals('UNDONE'),
    )).write(
      ElvRevisionCommandHistoryOperationsCompanion(
        state: const Value('APPLIED'),
        cursorGeneration: Value(nextGeneration),
        updatedAt: Value(_now()),
        originDeviceId: Value(originDeviceId),
      ),
    );
    if (changed != 1) {
      throw StateError('Redo history CAS failed after canonical mutation.');
    }
    await _moveCursor(
      cursor,
      generation: nextGeneration,
      headSequence: operation.sequence,
      branchId: cursor.branchId,
    );
    await _insertExecution(
      projectId: projectId,
      designRevisionId: designRevisionId,
      historySequence: operation.sequence,
      commandId: executionCommandId,
      kind: 'REDO',
      payload: effectivePayload,
    );
    return ElvCommandSuccess<Object?>((mutation as ElvCommandSuccess).value);
  });

  Future<void> _appendRerouteHistory({
    required ReviewedRerouteCableRunWorkspaceCommand command,
    required _RunAggregate before,
    required _RunAggregate after,
  }) async {
    final cursor = await _cursor(command.projectId, command.designRevisionId);
    final maxSequence = await _maxSequence(
      command.projectId,
      command.designRevisionId,
    );
    final sequence = maxSequence + 1;
    final nextGeneration = (cursor?.generation ?? 0) + 1;
    final priorHead = cursor?.headSequence ?? 0;

    final abandoned = await (database.update(
      database.elvRevisionCommandHistoryOperations,
    )..where(
      (row) =>
          row.projectId.equals(command.projectId) &
          row.designRevisionId.equals(command.designRevisionId) &
          row.sequence.isBiggerThanValue(priorHead) &
          row.state.equals('UNDONE'),
    )).write(
      ElvRevisionCommandHistoryOperationsCompanion(
        state: const Value('REDO_ABANDONED'),
        updatedAt: Value(_now()),
        originDeviceId: Value(originDeviceId),
      ),
    );

    final branchId =
        cursor == null || abandoned > 0 ? idGenerator.next() : cursor.branchId;
    final beforeRef = idGenerator.next();
    final afterRef = idGenerator.next();
    await _insertEvidence(beforeRef, before);
    await _insertEvidence(afterRef, after);

    final forward = _storedReroutePayload(
      commandId: command.commandId,
      projectId: command.projectId,
      designRevisionId: command.designRevisionId,
      cableRunId: command.cableRunId,
      expectedRevision: command.expectedRevision,
      traversals: command.traversals,
    );
    final inverseTemplateId = idGenerator.next();
    final inverse = _storedReroutePayload(
      commandId: inverseTemplateId,
      projectId: command.projectId,
      designRevisionId: command.designRevisionId,
      cableRunId: command.cableRunId,
      expectedRevision: after.run.revision,
      traversals: before.traversals,
    );
    final now = _now();
    await database
        .into(database.elvRevisionCommandHistoryOperations)
        .insert(
          ElvRevisionCommandHistoryOperationsCompanion.insert(
            projectId: command.projectId,
            designRevisionId: command.designRevisionId,
            sequence: sequence,
            originalCommandId: command.commandId,
            state: 'APPLIED',
            forwardCommandType: 'REROUTE_CABLE_RUN',
            forwardCommandSchema:
                ReviewedRerouteCableRunWorkspaceCommand.payloadSchema,
            forwardCanonicalPayloadJson: forward.json,
            forwardPayloadSha256: forward.sha256,
            inverseCommandType: 'REROUTE_CABLE_RUN',
            inverseCommandSchema:
                ReviewedRerouteCableRunWorkspaceCommand.payloadSchema,
            inverseCanonicalPayloadJson: inverse.json,
            inversePayloadSha256: inverse.sha256,
            beforeAggregateEvidenceRef: beforeRef,
            beforeAggregateHash: before.sha256,
            afterAggregateEvidenceRef: afterRef,
            afterAggregateHash: after.sha256,
            cursorGeneration: nextGeneration,
            affectedIdsJson: jsonEncode([command.cableRunId]),
            createdAt: now,
            updatedAt: now,
            originDeviceId: originDeviceId,
          ),
        );
    await _insertExecution(
      projectId: command.projectId,
      designRevisionId: command.designRevisionId,
      historySequence: sequence,
      commandId: command.commandId,
      kind: 'ORIGINAL',
      payload: forward,
    );

    if (cursor == null) {
      await database
          .into(database.elvRevisionCommandHistoryCursors)
          .insert(
            ElvRevisionCommandHistoryCursorsCompanion.insert(
              projectId: command.projectId,
              designRevisionId: command.designRevisionId,
              generation: nextGeneration,
              headSequence: sequence,
              branchId: branchId,
              createdAt: now,
              updatedAt: now,
              originDeviceId: originDeviceId,
            ),
          );
    } else {
      await _moveCursor(
        cursor,
        generation: nextGeneration,
        headSequence: sequence,
        branchId: branchId,
      );
    }
  }

  Future<_RunAggregate?> _captureAggregate({
    required String projectId,
    required String designRevisionId,
    required String cableRunId,
  }) async {
    final run = await _runs.findRun(projectId, designRevisionId, cableRunId);
    if (run == null) return null;
    final traversals = await _runs.loadTraversals(cableRunId);
    final payload = <String, Object?>{
      'schema': 'electra.elv3-cable-run-business.v1',
      'projectId': run.projectId,
      'designRevisionId': run.designRevisionId,
      'cableRunId': run.id,
      'cableId': run.cableId,
      'basedOnCableRunId': run.basedOnCableRunId,
      'state': run.state.name.toUpperCase(),
      'reservePercent': run.reservePercent,
      'terminationAllowanceMm': run.terminationAllowanceMm,
      'traversals': [for (final value in traversals) _traversalMap(value)],
    };
    final canonical = canonicalEngineeringJsonV1(payload);
    return _RunAggregate(
      run: run,
      traversals: traversals,
      canonicalJson: canonical,
      sha256: sha256HexUtf8(canonical),
    );
  }

  Future<void> _insertEvidence(String evidenceRef, _RunAggregate value) async {
    await database
        .into(database.elvRevisionAggregateEvidenceRecords)
        .insert(
          ElvRevisionAggregateEvidenceRecordsCompanion.insert(
            evidenceRef: evidenceRef,
            projectId: value.run.projectId,
            designRevisionId: value.run.designRevisionId,
            aggregateKind: 'CABLE_RUN',
            aggregateId: value.run.id,
            canonicalPayloadJson: value.canonicalJson,
            payloadSha256: value.sha256,
            createdAt: _now(),
            originDeviceId: originDeviceId,
          ),
        );
  }

  Future<void> _insertExecution({
    required String projectId,
    required String designRevisionId,
    required int historySequence,
    required String commandId,
    required String kind,
    required _StoredPayload payload,
  }) async {
    await database
        .into(database.elvRevisionCommandHistoryExecutions)
        .insert(
          ElvRevisionCommandHistoryExecutionsCompanion.insert(
            projectId: projectId,
            designRevisionId: designRevisionId,
            historySequence: historySequence,
            executionCommandId: commandId,
            executionKind: kind,
            commandType: 'REROUTE_CABLE_RUN',
            commandSchema:
                ReviewedRerouteCableRunWorkspaceCommand.payloadSchema,
            canonicalPayloadJson: payload.json,
            payloadSha256: payload.sha256,
            createdAt: _now(),
            originDeviceId: originDeviceId,
          ),
        );
  }

  Future<ElvCommandResult<Object?>?> _replayHistoryExecution({
    required String projectId,
    required String designRevisionId,
    required String executionCommandId,
    required String expectedKind,
  }) async {
    final execution = await _executionByCommandId(
      projectId,
      executionCommandId,
    );
    if (execution == null) return null;
    if (execution.designRevisionId != designRevisionId ||
        execution.executionKind != expectedKind ||
        execution.commandType != 'REROUTE_CABLE_RUN' ||
        execution.commandSchema !=
            ReviewedRerouteCableRunWorkspaceCommand.payloadSchema ||
        sha256HexUtf8(execution.canonicalPayloadJson) !=
            execution.payloadSha256) {
      return _historyFailure('ELV4_HISTORY_EXECUTION_ID_CONFLICT');
    }
    final result = await _runs.reroute(
      _rerouteFromStoredPayload(execution.canonicalPayloadJson),
    );
    return _objectResult(result);
  }

  Future<ElvRevisionCommandHistoryExecutionRow?> _executionByCommandId(
    String projectId,
    String executionCommandId,
  ) =>
      (database.select(database.elvRevisionCommandHistoryExecutions)..where(
        (row) =>
            row.projectId.equals(projectId) &
            row.executionCommandId.equals(executionCommandId),
      )).getSingleOrNull();

  Future<void> _moveCursor(
    ElvRevisionCommandHistoryCursorRow cursor, {
    required int generation,
    required int headSequence,
    required String branchId,
  }) async {
    final changed = await (database.update(
      database.elvRevisionCommandHistoryCursors,
    )..where(
      (row) =>
          row.projectId.equals(cursor.projectId) &
          row.designRevisionId.equals(cursor.designRevisionId) &
          row.generation.equals(cursor.generation),
    )).write(
      ElvRevisionCommandHistoryCursorsCompanion(
        generation: Value(generation),
        headSequence: Value(headSequence),
        branchId: Value(branchId),
        updatedAt: Value(_now()),
        originDeviceId: Value(originDeviceId),
      ),
    );
    if (changed != 1) throw StateError('History cursor CAS conflict.');
  }

  Future<bool> _isWorking(String projectId, String designRevisionId) async {
    final row =
        await (database.select(database.projectDesignRevisions)..where(
          (candidate) =>
              candidate.projectId.equals(projectId) &
              candidate.id.equals(designRevisionId) &
              candidate.state.equals('WORKING') &
              candidate.deletedAt.isNull(),
        )).getSingleOrNull();
    return row != null;
  }

  Future<ElvCommandFailureResult<Object?>?> _workingRevisionFailure(
    String projectId,
    String designRevisionId,
  ) async {
    if (await _isWorking(projectId, designRevisionId)) return null;
    return _historyFailure('ELV4_POWER_WORKSPACE_READ_ONLY');
  }

  Future<ElvRevisionCommandHistoryCursorRow?> _cursor(
    String projectId,
    String designRevisionId,
  ) =>
      (database.select(database.elvRevisionCommandHistoryCursors)..where(
        (row) =>
            row.projectId.equals(projectId) &
            row.designRevisionId.equals(designRevisionId),
      )).getSingleOrNull();

  Future<ElvRevisionCommandHistoryOperationRow?> _operation(
    String projectId,
    String designRevisionId,
    int sequence,
  ) =>
      (database.select(database.elvRevisionCommandHistoryOperations)..where(
        (row) =>
            row.projectId.equals(projectId) &
            row.designRevisionId.equals(designRevisionId) &
            row.sequence.equals(sequence),
      )).getSingleOrNull();

  Future<ElvRevisionCommandHistoryOperationRow?> _historyByOriginalCommand(
    String projectId,
    String designRevisionId,
    String commandId,
  ) =>
      (database.select(database.elvRevisionCommandHistoryOperations)
            ..where(
              (row) =>
                  row.projectId.equals(projectId) &
                  row.designRevisionId.equals(designRevisionId) &
                  row.originalCommandId.equals(commandId),
            )
            ..limit(1))
          .getSingleOrNull();

  Future<ElvRevisionCommandHistoryOperationRow?> _redoCandidate(
    String projectId,
    String designRevisionId,
    int headSequence,
  ) =>
      (database.select(database.elvRevisionCommandHistoryOperations)
            ..where(
              (row) =>
                  row.projectId.equals(projectId) &
                  row.designRevisionId.equals(designRevisionId) &
                  row.sequence.isBiggerThanValue(headSequence) &
                  row.state.equals('UNDONE'),
            )
            ..orderBy([(row) => OrderingTerm.asc(row.sequence)])
            ..limit(1))
          .getSingleOrNull();

  Future<int> _maxSequence(String projectId, String designRevisionId) async {
    final row =
        await database
            .customSelect(
              'SELECT MAX(sequence) AS value FROM elv_revision_command_history_operations '
              'WHERE project_id = ? AND design_revision_id = ?',
              variables: [
                Variable.withString(projectId),
                Variable.withString(designRevisionId),
              ],
              readsFrom: {database.elvRevisionCommandHistoryOperations},
            )
            .getSingle();
    return row.readNullable<int>('value') ?? 0;
  }

  Future<int> _previousAppliedSequence(
    String projectId,
    String designRevisionId,
    int beforeSequence,
  ) async {
    final row =
        await database
            .customSelect(
              'SELECT MAX(sequence) AS value FROM elv_revision_command_history_operations '
              "WHERE project_id = ? AND design_revision_id = ? AND sequence < ? AND state = 'APPLIED'",
              variables: [
                Variable.withString(projectId),
                Variable.withString(designRevisionId),
                Variable.withInt(beforeSequence),
              ],
              readsFrom: {database.elvRevisionCommandHistoryOperations},
            )
            .getSingle();
    return row.readNullable<int>('value') ?? 0;
  }
}

final class _RunAggregate {
  const _RunAggregate({
    required this.run,
    required this.traversals,
    required this.canonicalJson,
    required this.sha256,
  });

  final CanonicalCableRun run;
  final List<CableRunTraversal> traversals;
  final String canonicalJson;
  final String sha256;
}

final class _StoredPayload {
  const _StoredPayload(this.json, this.sha256);
  final String json;
  final String sha256;
}

RerouteCableRunCommand _rerouteCommand(
  ReviewedRerouteCableRunWorkspaceCommand command,
) => RerouteCableRunCommand(
  commandId: command.commandId,
  projectId: command.projectId,
  cableRunId: command.cableRunId,
  expectedRevision: command.expectedRevision,
  traversals: command.traversals,
);

_StoredPayload _storedReroutePayload({
  required String commandId,
  required String projectId,
  required String designRevisionId,
  required String cableRunId,
  required int expectedRevision,
  required Iterable<CableRunTraversal> traversals,
}) {
  final sorted = [...traversals]
    ..sort((a, b) => a.sequence.compareTo(b.sequence));
  final value = <String, Object?>{
    'schema': ReviewedRerouteCableRunWorkspaceCommand.payloadSchema,
    'commandId': commandId,
    'projectId': projectId,
    'designRevisionId': designRevisionId,
    'cableRunId': cableRunId,
    'expectedRevision': expectedRevision,
    'traversals': [for (final item in sorted) _traversalMap(item)],
  };
  final canonical = canonicalEngineeringJsonV1(value);
  return _StoredPayload(canonical, sha256HexUtf8(canonical));
}

Map<String, Object?> _traversalMap(CableRunTraversal value) =>
    <String, Object?>{
      'id': value.id,
      'cableRunId': value.cableRunId,
      'sequence': value.sequence,
      'routeSegmentId': value.routeSegmentId,
      'direction': value.direction.name.toUpperCase(),
      'physicalCarrierId': value.physicalCarrierId,
      'carrierCompartmentId': value.carrierCompartmentId,
    };

Map<String, Object?> _decodePayload(String canonicalJson) =>
    (jsonDecode(canonicalJson) as Map).cast<String, Object?>();

RerouteCableRunCommand _rerouteFromStoredPayload(String canonicalJson) {
  final payload = _decodePayload(canonicalJson);
  final cableRunId = _requiredString(payload, 'cableRunId');
  return RerouteCableRunCommand(
    commandId: _requiredString(payload, 'commandId'),
    projectId: _requiredString(payload, 'projectId'),
    cableRunId: cableRunId,
    expectedRevision: payload['expectedRevision'] as int,
    traversals: _decodeTraversals(payload, cableRunId),
  );
}

String _requiredString(Map<String, Object?> payload, String key) {
  final value = payload[key];
  if (value is! String || value.trim().isEmpty) {
    throw StateError('History payload is missing $key.');
  }
  return value;
}

List<CableRunTraversal> _decodeTraversals(
  Map<String, Object?> payload,
  String cableRunId,
) {
  final raw = payload['traversals'];
  if (raw is! List) throw StateError('History payload has no traversals.');
  final result = <CableRunTraversal>[];
  for (final item in raw) {
    if (item is! Map) throw StateError('Invalid history traversal payload.');
    final map = item.cast<String, Object?>();
    result.add(
      CableRunTraversal(
        id: _requiredString(map, 'id'),
        cableRunId: cableRunId,
        sequence: map['sequence'] as int,
        routeSegmentId: _requiredString(map, 'routeSegmentId'),
        direction: CableTraversalDirection.values.byName(
          _requiredString(map, 'direction').toLowerCase(),
        ),
        physicalCarrierId: map['physicalCarrierId'] as String?,
        carrierCompartmentId: map['carrierCompartmentId'] as String?,
      ),
    );
  }
  result.sort((a, b) => a.sequence.compareTo(b.sequence));
  return result;
}

ElvCommandFailureResult<Object?> _historyFailure(String code) =>
    ElvCommandFailureResult<Object?>(
      ElvFailure(code: code, category: ElvFailureCategory.revisionConflict),
    );

ElvCommandResult<Object?> _objectResult(
  ElvCommandResult<CanonicalCableRun> result,
) => switch (result) {
  ElvCommandSuccess<CanonicalCableRun>() => ElvCommandSuccess<Object?>(
    result.value,
  ),
  ElvCommandFailureResult<CanonicalCableRun>() =>
    ElvCommandFailureResult<Object?>(result.failure),
};
