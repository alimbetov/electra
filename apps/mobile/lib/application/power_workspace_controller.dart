import 'elv_command_result.dart';
import 'elv_physical_routing_workspace_service.dart';
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
/// [PowerWorkspaceRepository], physical-route mutations through
/// [ElvPhysicalRoutingWorkspaceService], and undo/redo through the durable ELV
/// command-history boundary.
final class PowerWorkspaceController {
  PowerWorkspaceController({
    required this.repository,
    this.routingService,
    this.historyService,
  });

  final PowerWorkspaceRepository repository;
  final ElvPhysicalRoutingWorkspaceService? routingService;
  final ElvCommandHistoryService? historyService;

  PowerWorkspaceState? _state;
  PowerWorkspaceProjection? _projection;

  PowerWorkspaceState get state =>
      _state ?? (throw StateError('Power workspace is not open.'));
  PowerWorkspaceProjection get projection =>
      _projection ?? (throw StateError('Power workspace is not open.'));
  bool get isOpen => _state != null && _projection != null;

  PowerWorkspaceSessionSnapshot get snapshot => PowerWorkspaceSessionSnapshot(
    state: state,
    projection: projection,
  );

  Future<PowerWorkspaceSessionSnapshot?> open(String projectId) async {
    final result = await repository.open(projectId);
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

  Future<PowerWorkspaceSessionSnapshot> switchScenario({
    required String scenarioId,
    required String segmentId,
  }) => _reload(
    state.switchScenario(scenarioId: scenarioId, segmentId: segmentId),
  );

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

  PowerWorkspaceSessionSnapshot stageReviewedDraft({
    required Map<String, Object?> draft,
    required String previewFingerprint,
  }) {
    _state = state.setDraft(
      draft: draft,
      previewFingerprint: previewFingerprint,
    );
    return snapshot;
  }

  /// Commits the exact reviewed physical-routing command through the public
  /// ELV workspace service. A command failure deliberately retains the draft
  /// and reviewed fingerprint so the engineer can correct and retry it.
  Future<ElvCommandResult<Object?>> commitReviewedRoute(
    ElvWorkspaceCommand command,
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
    if (!state.hasDraft || state.previewFingerprint == null) {
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

    _state = state.startOperation();
    final result = await service.execute(command);
    switch (result) {
      case ElvCommandSuccess<Object?>():
        _state = state.clearDraft().finishOperation();
        await _reload(state);
      case ElvCommandFailureResult<Object?>():
        _state = state.failOperation(result.failure.code);
    }
    return result;
  }

  Future<bool> canUndo() async =>
      await historyService?.canUndo(state.context.projectId) ?? false;

  Future<bool> canRedo() async =>
      await historyService?.canRedo(state.context.projectId) ?? false;

  Future<ElvCommandResult<Object?>> undo() => _historyMutation(undo: true);

  Future<ElvCommandResult<Object?>> redo() => _historyMutation(undo: false);

  Future<ElvCommandResult<Object?>> _historyMutation({required bool undo}) async {
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
    _state = state.startOperation();
    final result =
        undo
            ? await history.undo(state.context.projectId)
            : await history.redo(state.context.projectId);
    switch (result) {
      case ElvCommandSuccess<Object?>():
        _state = state.finishOperation();
        await _reload(state);
      case ElvCommandFailureResult<Object?>():
        _state = state.failOperation(result.failure.code);
    }
    return result;
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
