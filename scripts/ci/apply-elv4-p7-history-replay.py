from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected one anchor, got {count}: {old[:160]!r}')
    path.write_text(text.replace(old, new, 1))


tables = ROOT / 'apps/mobile/lib/data/database/elv_history_database_tables.dart'
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
