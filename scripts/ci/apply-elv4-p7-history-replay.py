from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected one anchor, got {count}: {old[:160]!r}')
    path.write_text(text.replace(old, new, 1))


tables = ROOT / 'apps/mobile/lib/data/database/elv_history_database_tables.dart'
if 'TextColumn get canonicalPayloadJson => text()();' not in tables.read_text().split(
    "class ElvRevisionCommandHistoryExecutions extends Table"
)[1]:
    replace_once(
        tables,
        """  TextColumn get executionCommandId => text()();
  TextColumn get executionKind => text()();
  DateTimeColumn get createdAt => dateTime()();
""",
        """  TextColumn get executionCommandId => text()();
  TextColumn get executionKind => text()();
  TextColumn get commandType => text()();
  TextColumn get commandSchema => text()();
  TextColumn get canonicalPayloadJson => text()();
  TextColumn get payloadSha256 => text()();
  DateTimeColumn get createdAt => dateTime()();
""",
    )

runtime = ROOT / 'apps/mobile/lib/data/repositories/drift_elv_reviewed_routing_runtime.dart'
if '_replayHistoryExecution({' not in runtime.read_text():
    replace_once(
        runtime,
        """  Future<ElvCommandResult<Object?>> undo({
    required String projectId,
    required String designRevisionId,
  }) => database.transaction(() async {
    final lifecycleFailure = await _workingRevisionFailure(
      projectId,
      designRevisionId,
    );
""",
        """  Future<ElvCommandResult<Object?>> undo({
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
""",
    )
    replace_once(
        runtime,
        """    final executionCommandId = idGenerator.next();
    final mutation = await _runs.reroute(
      RerouteCableRunCommand(
        commandId: executionCommandId,
        projectId: projectId,
        cableRunId: cableRunId,
        expectedRevision: current.run.revision,
        traversals: _decodeTraversals(inversePayload, cableRunId),
      ),
    );
""",
        """    final effectivePayload = _storedReroutePayload(
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
""",
    )
    replace_once(
        runtime,
        """    await _insertExecution(
      projectId: projectId,
      designRevisionId: designRevisionId,
      historySequence: operation.sequence,
      commandId: executionCommandId,
      kind: 'UNDO',
    );
""",
        """    await _insertExecution(
      projectId: projectId,
      designRevisionId: designRevisionId,
      historySequence: operation.sequence,
      commandId: executionCommandId,
      kind: 'UNDO',
      payload: effectivePayload,
    );
""",
    )
    replace_once(
        runtime,
        """  Future<ElvCommandResult<Object?>> redo({
    required String projectId,
    required String designRevisionId,
  }) => database.transaction(() async {
    final lifecycleFailure = await _workingRevisionFailure(
      projectId,
      designRevisionId,
    );
""",
        """  Future<ElvCommandResult<Object?>> redo({
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
""",
    )
    replace_once(
        runtime,
        """    final executionCommandId = idGenerator.next();
    final mutation = await _runs.reroute(
      RerouteCableRunCommand(
        commandId: executionCommandId,
        projectId: projectId,
        cableRunId: cableRunId,
        expectedRevision: current.run.revision,
        traversals: _decodeTraversals(forwardPayload, cableRunId),
      ),
    );
""",
        """    final effectivePayload = _storedReroutePayload(
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
""",
    )
    replace_once(
        runtime,
        """    await _insertExecution(
      projectId: projectId,
      designRevisionId: designRevisionId,
      historySequence: operation.sequence,
      commandId: executionCommandId,
      kind: 'REDO',
    );
""",
        """    await _insertExecution(
      projectId: projectId,
      designRevisionId: designRevisionId,
      historySequence: operation.sequence,
      commandId: executionCommandId,
      kind: 'REDO',
      payload: effectivePayload,
    );
""",
    )
    replace_once(
        runtime,
        """    await _insertExecution(
      projectId: command.projectId,
      designRevisionId: command.designRevisionId,
      historySequence: sequence,
      commandId: command.commandId,
      kind: 'ORIGINAL',
    );
""",
        """    await _insertExecution(
      projectId: command.projectId,
      designRevisionId: command.designRevisionId,
      historySequence: sequence,
      commandId: command.commandId,
      kind: 'ORIGINAL',
      payload: forward,
    );
""",
    )
    replace_once(
        runtime,
        """  Future<void> _insertExecution({
    required String projectId,
    required String designRevisionId,
    required int historySequence,
    required String commandId,
    required String kind,
  }) async {
""",
        """  Future<void> _insertExecution({
    required String projectId,
    required String designRevisionId,
    required int historySequence,
    required String commandId,
    required String kind,
    required _StoredPayload payload,
  }) async {
""",
    )
    replace_once(
        runtime,
        """            historySequence: historySequence,
            executionCommandId: commandId,
            executionKind: kind,
            createdAt: _now(),
""",
        """            historySequence: historySequence,
            executionCommandId: commandId,
            executionKind: kind,
            commandType: 'REROUTE_CABLE_RUN',
            commandSchema: ReviewedRerouteCableRunWorkspaceCommand.payloadSchema,
            canonicalPayloadJson: payload.json,
            payloadSha256: payload.sha256,
            createdAt: _now(),
""",
    )
    insert_anchor = """  Future<void> _moveCursor(
    ElvRevisionCommandHistoryCursorRow cursor, {
"""
    replay_helpers = """  Future<ElvCommandResult<Object?>?> _replayHistoryExecution({
    required String projectId,
    required String designRevisionId,
    required String executionCommandId,
    required String expectedKind,
  }) async {
    final execution = await _executionByCommandId(projectId, executionCommandId);
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
  ) => (database.select(database.elvRevisionCommandHistoryExecutions)..where(
    (row) =>
        row.projectId.equals(projectId) &
        row.executionCommandId.equals(executionCommandId),
  )).getSingleOrNull();

"""
    replace_once(runtime, insert_anchor, replay_helpers + insert_anchor)
    helper_anchor = """Map<String, Object?> _decodePayload(String canonicalJson) =>
    (jsonDecode(canonicalJson) as Map).cast<String, Object?>();

"""
    helper_replacement = helper_anchor + """RerouteCableRunCommand _rerouteFromStoredPayload(String canonicalJson) {
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

"""
    replace_once(runtime, helper_anchor, helper_replacement)

controller_test = ROOT / 'apps/mobile/test/application/power_workspace_controller_test.dart'
text = controller_test.read_text()
if "application/id_generator.dart" not in text:
    text = text.replace(
        "import 'package:electra_mobile/application/elv_revision_command_history_service.dart';\n",
        "import 'package:electra_mobile/application/elv_revision_command_history_service.dart';\n"
        "import 'package:electra_mobile/application/id_generator.dart';\n",
        1,
    )
if "historyCommandIds: FixedSequenceIdGenerator" not in text:
    text = text.replace(
        """    final controller = PowerWorkspaceController(
      repository: _Repository(),
      historyService: history,
    );
    await controller.open('project');

    expect(await controller.canUndo(), isTrue);
""",
        """    final controller = PowerWorkspaceController(
      repository: _Repository(),
      historyService: history,
      historyCommandIds: FixedSequenceIdGenerator(
        const ['undo-command-1', 'redo-command-1'],
      ),
    );
    await controller.open('project');

    expect(await controller.canUndo(), isTrue);
""",
        1,
    )
    text = text.replace(
        """    expect(history.undoCalls, 1);
    expect(history.redoCalls, 1);
    expect(history.scopes, everyElement(('project', 'rev-1')));
""",
        """    expect(history.undoCalls, 1);
    expect(history.redoCalls, 1);
    expect(history.scopes, everyElement(('project', 'rev-1')));
    expect(history.executionCommandIds, ['undo-command-1', 'redo-command-1']);
""",
        1,
    )
if 'final executionCommandIds = <String>[];' not in text:
    text = text.replace(
        """  int redoCalls = 0;
  final scopes = <(String, String)>[];
""",
        """  int redoCalls = 0;
  final scopes = <(String, String)>[];
  final executionCommandIds = <String>[];
""",
        1,
    )
    text = text.replace(
        """  Future<ElvCommandResult<Object?>> redo({
    required String projectId,
    required String designRevisionId,
  }) async {
    scopes.add((projectId, designRevisionId));
    redoCalls += 1;
""",
        """  Future<ElvCommandResult<Object?>> redo({
    required String projectId,
    required String designRevisionId,
    required String executionCommandId,
  }) async {
    scopes.add((projectId, designRevisionId));
    executionCommandIds.add(executionCommandId);
    redoCalls += 1;
""",
        1,
    )
    text = text.replace(
        """  Future<ElvCommandResult<Object?>> undo({
    required String projectId,
    required String designRevisionId,
  }) async {
    scopes.add((projectId, designRevisionId));
    undoCalls += 1;
""",
        """  Future<ElvCommandResult<Object?>> undo({
    required String projectId,
    required String designRevisionId,
    required String executionCommandId,
  }) async {
    scopes.add((projectId, designRevisionId));
    executionCommandIds.add(executionCommandId);
    undoCalls += 1;
""",
        1,
    )
controller_test.write_text(text)

vertical = ROOT / 'apps/mobile/test/data/elv4_p7_t06_history_test.dart'
text = vertical.read_text()
if "executionCommandId: 'undo-execution-1'" not in text:
    text = text.replace(
        "idGenerator: FixedSequenceIdGenerator(const ['undo-execution-1']),",
        "idGenerator: FixedSequenceIdGenerator(const []),",
        1,
    )
    text = text.replace(
        """      final undone = await undoRuntime.undo(
        projectId: 'project',
        designRevisionId: 'rev-1',
      );
""",
        """      final undone = await undoRuntime.undo(
        projectId: 'project',
        designRevisionId: 'rev-1',
        executionCommandId: 'undo-execution-1',
      );
""",
        1,
    )
    undo_history = """      await _expectHistory(
        db,
        state: 'UNDONE',
        headSequence: 0,
        generation: 2,
        executionKinds: const {'ORIGINAL', 'UNDO'},
      );

"""
    undo_replay = undo_history + """      db = await harness.reopen(db);
      final undoReplayRuntime = DriftElvReviewedRoutingRuntime(
        db,
        originDeviceId: 'test-reopen-undo-replay',
        idGenerator: FixedSequenceIdGenerator(const []),
        now: _clock,
      );
      final undoReplay = await undoReplayRuntime.undo(
        projectId: 'project',
        designRevisionId: 'rev-1',
        executionCommandId: 'undo-execution-1',
      );
      expect(undoReplay, isA<ElvCommandSuccess<Object?>>());
      await _expectRoute(db, 'seg-old', revision: 3);
      await _expectHistory(
        db,
        state: 'UNDONE',
        headSequence: 0,
        generation: 2,
        executionKinds: const {'ORIGINAL', 'UNDO'},
      );

"""
    text = text.replace(undo_history, undo_replay, 1)
    text = text.replace(
        "idGenerator: FixedSequenceIdGenerator(const ['redo-execution-1']),",
        "idGenerator: FixedSequenceIdGenerator(const []),",
        1,
    )
    text = text.replace(
        """      final redone = await redoRuntime.redo(
        projectId: 'project',
        designRevisionId: 'rev-1',
      );
""",
        """      final redone = await redoRuntime.redo(
        projectId: 'project',
        designRevisionId: 'rev-1',
        executionCommandId: 'redo-execution-1',
      );
""",
        1,
    )
    redo_history = """      await _expectHistory(
        db,
        state: 'APPLIED',
        headSequence: 1,
        generation: 3,
        executionKinds: const {'ORIGINAL', 'UNDO', 'REDO'},
      );

"""
    redo_replay = redo_history + """      db = await harness.reopen(db);
      final redoReplayRuntime = DriftElvReviewedRoutingRuntime(
        db,
        originDeviceId: 'test-reopen-redo-replay',
        idGenerator: FixedSequenceIdGenerator(const []),
        now: _clock,
      );
      final redoReplay = await redoReplayRuntime.redo(
        projectId: 'project',
        designRevisionId: 'rev-1',
        executionCommandId: 'redo-execution-1',
      );
      expect(redoReplay, isA<ElvCommandSuccess<Object?>>());
      await _expectRoute(db, 'seg-new', revision: 4);
      await _expectHistory(
        db,
        state: 'APPLIED',
        headSequence: 1,
        generation: 3,
        executionKinds: const {'ORIGINAL', 'UNDO', 'REDO'},
      );

"""
    text = text.replace(redo_history, redo_replay, 1)
vertical.write_text(text)
