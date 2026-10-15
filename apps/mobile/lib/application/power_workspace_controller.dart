import 'elv_command_result.dart';
import 'elv_physical_routing_workspace_service.dart';
import 'elv_reviewed_workspace_command.dart';
import 'elv_revision_command_history_service.dart';
import 'id_generator.dart';
import 'power_workspace_projection.dart';
import 'power_workspace_state.dart';

final class PowerWorkspaceSessionSnapshot {
  const PowerWorkspaceSessionSnapshot({
    required this.state,
    required this.projection,
  });

  final PowerWorkspaceState state;
  final PowerWorkspaceProjection projection;
}

/// Application coordinator for the P7 power workspace.
///
/// Widgets never call persistence repositories directly. Queries come through
/// [PowerWorkspaceRepository], reviewed physical-route mutations through
/// [ElvWorkspaceCommandService], and undo/redo through the explicit
/// revision-scoped durable history boundary.
final class PowerWorkspaceController {
  PowerWorkspaceController({
    required this.repository,
    this.routingService,
    this.historyService,
    IdGenerator? historyCommandIds,
  }) : historyCommandIds = historyCommandIds ?? UuidV7IdGenerator();

  final PowerWorkspaceRepository repository;
  final ElvWorkspaceCommandService? routingService;
  final ElvRevisionCommandHistoryService? historyService;
  final IdGenerator historyCommandIds;

  PowerWorkspaceState? _state;
  PowerWorkspaceProjection? _projection;
  ElvReviewedWorkspaceCommand? _reviewedRouteCommand;
  String? _pendingUndoCommandId;
  String? _pendingRedoCommandId;

  PowerWorkspaceState get state =>
      _state ?? (throw StateError('Power workspace is not open.'));
  PowerWorkspaceProjection get projection =>
      _projection ?? (throw StateError('Power workspace is not open.'));
  bool get isOpen => _state != null && _projection != null;
  bool get hasReviewedRouteCommand => _reviewedRouteCommand != null;

  PowerWorkspaceSessionSnapshot get snapshot =>
      PowerWorkspaceSessionSnapshot(state: state, projection: projection);

  Future<PowerWorkspaceSessionSnapshot?> open(String projectId) async {
    final result = await repository.open(projectId);
    _reviewedRouteCommand = null;
    _clearPendingHistoryCommands();
    if (result == null) {
      _state = null;
      _projection = null;
      return null;
    }
    _state = result.state.applyTechnicalState(
      contextGeneration: result.state.context.generation,
      findings: [
        for (final card in result.projection.cards.values)
          for (final finding in card.findings) finding.finding,
      ],
      pointerStates: result.projection.pointerStates,
    );
    _projection = result.projection;
    return snapshot;
  }

  Future<PowerWorkspaceSessionSnapshot> refresh() => _reload(state);

  Future<PowerWorkspaceSessionSnapshot> select({
    String? componentId,
    String? portId,
  }) => _reload(state.select(componentId: componentId, portId: portId));

  Future<PowerWorkspaceSessionSnapshot> switchScope(
    PowerWorkspaceScope scope,
  ) => _reload(state.switchScope(scope));

  Future<PowerWorkspaceSessionSnapshot> setLoadMode(
    PowerWorkspaceLoadMode mode,
  ) => _reload(state.setLoadMode(mode));

  Future<PowerWorkspaceSessionSnapshot> switchScenario({
    required String scenarioId,
    required String segmentId,
  }) {
    _clearPendingHistoryCommands();
    return _reload(
      state.switchScenario(scenarioId: scenarioId, segmentId: segmentId),
    );
  }

  PowerWorkspaceSessionSnapshot setOverlay(PowerWorkspaceOverlayMode mode) {
    _state = state.setOverlay(mode);
    return snapshot;
  }

  PowerWorkspaceSessionSnapshot nextCard() {
    _state = state.nextCard();
    return snapshot;
  }

  PowerWorkspaceSessionSnapshot previousCard() {
    _state = state.previousCard();
    return snapshot;
  }

  PowerWorkspaceSessionSnapshot showCard(PowerWorkspaceCardCode card) {
    _state = state.showCard(card);
    return snapshot;
  }

  PowerWorkspaceSessionSnapshot stageReviewedRoute({
    required ElvReviewedWorkspaceCommand command,
    required Map<String, Object?> draft,
  }) {
    if (command.projectId != state.context.projectId) {
      throw ArgumentError('Reviewed route project does not match workspace.');
    }
    if (command.designRevisionId != state.context.designRevisionId) {
      throw ArgumentError('Reviewed route revision does not match workspace.');
    }
    _reviewedRouteCommand = command;
    _state = state.setDraft(
      draft: draft,
      previewFingerprint: command.reviewedFingerprint,
    );
    return snapshot;
  }

  PowerWorkspaceSessionSnapshot discardReviewedRoute() {
    _reviewedRouteCommand = null;
    _state = state.clearDraft();
    return snapshot;
  }

  Future<ElvCommandResult<Object?>> commitStagedReviewedRoute() async {
    final command = _reviewedRouteCommand;
    if (command == null) {
      return const ElvCommandFailureResult<Object?>(
        ElvFailure(
          code: 'ELV4_ROUTE_PREVIEW_REQUIRED',
          category: ElvFailureCategory.validation,
        ),
      );
    }
    return commitReviewedRoute(command);
  }

  Future<ElvCommandResult<Object?>> commitReviewedRoute(
    ElvReviewedWorkspaceCommand command,
  ) async {
    final service = routingService;
    if (service == null) {
      return const ElvCommandFailureResult<Object?>(
        ElvFailure(
          code: 'ELV4_ROUTE_SERVICE_UNAVAILABLE',
          category: ElvFailureCategory.storage,
        ),
      );
    }
    if (!state.mutationAllowed) {
      return const ElvCommandFailureResult<Object?>(
        ElvFailure(
          code: 'ELV4_POWER_WORKSPACE_READ_ONLY',
          category: ElvFailureCategory.lifecycle,
        ),
      );
    }
    final reviewedFingerprint = state.previewFingerprint;
    if (!state.hasDraft || reviewedFingerprint == null) {
      return const ElvCommandFailureResult<Object?>(
        ElvFailure(
          code: 'ELV4_ROUTE_PREVIEW_REQUIRED',
          category: ElvFailureCategory.validation,
        ),
      );
    }
    if (command.projectId != state.context.projectId) {
      return const ElvCommandFailureResult<Object?>(
        ElvFailure(
          code: 'ELV4_ROUTE_PROJECT_MISMATCH',
          category: ElvFailureCategory.projectIsolation,
        ),
      );
    }
    if (command.designRevisionId != state.context.designRevisionId) {
      return const ElvCommandFailureResult<Object?>(
        ElvFailure(
          code: 'ELV4_ROUTE_REVISION_MISMATCH',
          category: ElvFailureCategory.revisionConflict,
        ),
      );
    }
    if (command.reviewedFingerprint.toLowerCase() !=
        reviewedFingerprint.toLowerCase()) {
      return const ElvCommandFailureResult<Object?>(
        ElvFailure(
          code: 'ELV4_ROUTE_REVIEW_MISMATCH',
          category: ElvFailureCategory.revisionConflict,
        ),
      );
    }
    if (!identical(command, _reviewedRouteCommand)) {
      return const ElvCommandFailureResult<Object?>(
        ElvFailure(
          code: 'ELV4_ROUTE_REVIEW_COMMAND_CHANGED',
          category: ElvFailureCategory.revisionConflict,
        ),
      );
    }

    _state = state.startOperation();
    final result = await service.execute(command);
    switch (result) {
      case ElvCommandSuccess<Object?>():
        _reviewedRouteCommand = null;
        _clearPendingHistoryCommands();
        _state = state.clearDraft().finishOperation();
        await _reload(state);
      case ElvCommandFailureResult<Object?>():
        _state = state.failOperation(result.failure.code);
    }
    return result;
  }

  Future<bool> canUndo() async {
    if (!state.mutationAllowed) return false;
    return await historyService?.canUndo(
          projectId: state.context.projectId,
          designRevisionId: state.context.designRevisionId,
        ) ??
        false;
  }

  Future<bool> canRedo() async {
    if (!state.mutationAllowed) return false;
    return await historyService?.canRedo(
          projectId: state.context.projectId,
          designRevisionId: state.context.designRevisionId,
        ) ??
        false;
  }

  Future<ElvCommandResult<Object?>> undo() => _historyMutation(undo: true);

  Future<ElvCommandResult<Object?>> redo() => _historyMutation(undo: false);

  Future<ElvCommandResult<Object?>> _historyMutation({
    required bool undo,
  }) async {
    final history = historyService;
    if (history == null) {
      return const ElvCommandFailureResult<Object?>(
        ElvFailure(
          code: 'ELV4_HISTORY_SERVICE_UNAVAILABLE',
          category: ElvFailureCategory.storage,
        ),
      );
    }
    if (!state.mutationAllowed) {
      return const ElvCommandFailureResult<Object?>(
        ElvFailure(
          code: 'ELV4_POWER_WORKSPACE_READ_ONLY',
          category: ElvFailureCategory.lifecycle,
        ),
      );
    }

    final executionCommandId =
        undo
            ? (_pendingUndoCommandId ??= historyCommandIds.next())
            : (_pendingRedoCommandId ??= historyCommandIds.next());
    _state = state.startOperation();
    final context = state.context;
    final result =
        undo
            ? await history.undo(
              projectId: context.projectId,
              designRevisionId: context.designRevisionId,
              executionCommandId: executionCommandId,
            )
            : await history.redo(
              projectId: context.projectId,
              designRevisionId: context.designRevisionId,
              executionCommandId: executionCommandId,
            );
    switch (result) {
      case ElvCommandSuccess<Object?>():
        _clearPendingHistoryCommands();
        _state = state.finishOperation();
        await _reload(state);
      case ElvCommandFailureResult<Object?>():
        _state = state.failOperation(result.failure.code);
    }
    return result;
  }

  void _clearPendingHistoryCommands() {
    _pendingUndoCommandId = null;
    _pendingRedoCommandId = null;
  }

  Future<PowerWorkspaceSessionSnapshot> _reload(
    PowerWorkspaceState candidate,
  ) async {
    _state = candidate;
    final generation = candidate.context.generation;
    final loaded = await repository.load(candidate);
    final current = state;
    if (current.context.generation == generation &&
        loaded.contextGeneration == generation) {
      _projection = loaded;
      _state = current.applyTechnicalState(
        contextGeneration: generation,
        findings: [
          for (final card in loaded.cards.values)
            for (final finding in card.findings) finding.finding,
        ],
        pointerStates: loaded.pointerStates,
      );
    }
    return snapshot;
  }
}
