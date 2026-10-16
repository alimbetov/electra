import 'package:engineering_core/engineering_core.dart';

enum PowerWorkspaceOverlayMode {
  none,
  sources,
  paths,
  capacity,
  backup,
  findings,
}

enum PowerWorkspaceScopeKind { building, floor }

enum PowerWorkspaceLoadMode { all, selectedComponent }

final class PowerWorkspaceScope {
  PowerWorkspaceScope.building()
    : kind = PowerWorkspaceScopeKind.building,
      floorId = null;

  PowerWorkspaceScope.floor(String floorId)
    : kind = PowerWorkspaceScopeKind.floor,
      floorId = _text(floorId, 'floorId');

  final PowerWorkspaceScopeKind kind;
  final String? floorId;

  bool sameAs(PowerWorkspaceScope other) =>
      kind == other.kind && floorId == other.floorId;
}

enum PowerWorkspaceOperationState { idle, running, cancelled, failed }

enum PowerWorkspaceCardCode {
  demand,
  upstreamPath,
  profileScenario,
  realization,
  sourceCapacity,
  backup,
  findings,
}

final class PowerWorkspaceReadContext {
  PowerWorkspaceReadContext({
    required String projectId,
    required String designRevisionId,
    required String lifecycleState,
    required String scenarioId,
    required String segmentId,
    required this.generation,
  }) : projectId = _text(projectId, 'projectId'),
       designRevisionId = _text(designRevisionId, 'designRevisionId'),
       lifecycleState = _text(lifecycleState, 'lifecycleState').toUpperCase(),
       scenarioId = _text(scenarioId, 'scenarioId'),
       segmentId = _text(segmentId, 'segmentId') {
    if (generation < 1) {
      throw ArgumentError.value(generation, 'generation', 'Must be positive.');
    }
  }

  final String projectId;
  final String designRevisionId;
  final String lifecycleState;
  final String scenarioId;
  final String segmentId;
  final int generation;

  bool get mutationAllowed => lifecycleState == 'WORKING';

  PowerWorkspaceReadContext nextGeneration({
    String? designRevisionId,
    String? lifecycleState,
    String? scenarioId,
    String? segmentId,
  }) => PowerWorkspaceReadContext(
    projectId: projectId,
    designRevisionId: designRevisionId ?? this.designRevisionId,
    lifecycleState: lifecycleState ?? this.lifecycleState,
    scenarioId: scenarioId ?? this.scenarioId,
    segmentId: segmentId ?? this.segmentId,
    generation: generation + 1,
  );
}

final class PowerWorkspaceQuerySnapshot {
  PowerWorkspaceQuerySnapshot({
    required this.contextGeneration,
    required Map<String, Object?> values,
  }) : values = Map.unmodifiable(values) {
    if (contextGeneration < 1) {
      throw ArgumentError.value(
        contextGeneration,
        'contextGeneration',
        'Must be positive.',
      );
    }
  }

  final int contextGeneration;
  final Map<String, Object?> values;
}

final class PowerWorkspaceState {
  PowerWorkspaceState({
    required this.context,
    required Iterable<PowerWorkspaceCardCode> cards,
    PowerWorkspaceScope? scope,
    this.loadMode = PowerWorkspaceLoadMode.all,
    this.cardIndex = 0,
    this.selectedComponentId,
    this.selectedPortId,
    this.overlayMode = PowerWorkspaceOverlayMode.none,
    this.querySnapshot,
    Map<String, Object?>? draft,
    this.previewFingerprint,
    this.operationState = PowerWorkspaceOperationState.idle,
    this.operationErrorCode,
    Iterable<PowerEvaluationFinding> findings = const [],
    Map<String, PowerPointerState> pointerStates = const {},
    this.unsavedDraftWarning = false,
  }) : scope = scope ?? PowerWorkspaceScope.building(),
       cards = List.unmodifiable(cards),
       draft = Map.unmodifiable(draft ?? const <String, Object?>{}),
       findings = List.unmodifiable(findings),
       pointerStates = Map.unmodifiable(pointerStates) {
    if (this.cards.isEmpty) {
      throw ArgumentError('Power workspace requires at least one card.');
    }
    if (cardIndex < 0 || cardIndex >= this.cards.length) {
      throw ArgumentError.value(cardIndex, 'cardIndex', 'Out of range.');
    }
    if (selectedPortId != null && selectedComponentId == null) {
      throw ArgumentError('Port selection requires a component selection.');
    }
    if (previewFingerprint != null) {
      _sha256(previewFingerprint!, 'previewFingerprint');
    }
  }

  final PowerWorkspaceReadContext context;
  final PowerWorkspaceScope scope;
  final PowerWorkspaceLoadMode loadMode;
  final List<PowerWorkspaceCardCode> cards;
  final int cardIndex;
  final String? selectedComponentId;
  final String? selectedPortId;
  final PowerWorkspaceOverlayMode overlayMode;
  final PowerWorkspaceQuerySnapshot? querySnapshot;
  final Map<String, Object?> draft;
  final String? previewFingerprint;
  final PowerWorkspaceOperationState operationState;
  final String? operationErrorCode;
  final List<PowerEvaluationFinding> findings;
  final Map<String, PowerPointerState> pointerStates;
  final bool unsavedDraftWarning;

  PowerWorkspaceCardCode get currentCard => cards[cardIndex];
  bool get mutationAllowed => context.mutationAllowed;
  bool get hasDraft => draft.isNotEmpty;
  PowerWorkspaceLoadMode get effectiveLoadMode =>
      loadMode == PowerWorkspaceLoadMode.selectedComponent &&
              selectedComponentId == null
          ? PowerWorkspaceLoadMode.all
          : loadMode;

  PowerWorkspaceState select({String? componentId, String? portId}) {
    final normalizedComponent = _nullableText(componentId, 'componentId');
    final normalizedPort = _nullableText(portId, 'portId');
    if (normalizedPort != null && normalizedComponent == null) {
      throw ArgumentError('Port selection requires a component selection.');
    }
    return _copy(
      context: context.nextGeneration(),
      selectedComponentId: normalizedComponent,
      selectedPortId: normalizedPort,
      clearSelection: normalizedComponent == null,
      clearPortSelection: normalizedComponent != null && normalizedPort == null,
      clearQuerySnapshot: true,
    );
  }

  PowerWorkspaceState switchScope(PowerWorkspaceScope nextScope) {
    if (scope.sameAs(nextScope)) return this;
    return _copy(
      context: context.nextGeneration(),
      scope: nextScope,
      clearQuerySnapshot: true,
      unsavedDraftWarning: hasDraft,
    );
  }

  PowerWorkspaceState setLoadMode(PowerWorkspaceLoadMode mode) {
    if (loadMode == mode) return this;
    return _copy(
      context: context.nextGeneration(),
      loadMode: mode,
      clearQuerySnapshot: true,
    );
  }

  PowerWorkspaceState switchScenario({
    required String scenarioId,
    required String segmentId,
  }) => _copy(
    context: context.nextGeneration(
      scenarioId: _text(scenarioId, 'scenarioId'),
      segmentId: _text(segmentId, 'segmentId'),
    ),
    clearQuerySnapshot: true,
    unsavedDraftWarning: hasDraft,
  );

  PowerWorkspaceState switchRevision({
    required String designRevisionId,
    required String lifecycleState,
    required String scenarioId,
    required String segmentId,
  }) => PowerWorkspaceState(
    context: context.nextGeneration(
      designRevisionId: _text(designRevisionId, 'designRevisionId'),
      lifecycleState: _text(lifecycleState, 'lifecycleState'),
      scenarioId: _text(scenarioId, 'scenarioId'),
      segmentId: _text(segmentId, 'segmentId'),
    ),
    cards: cards,
    scope: scope,
    loadMode: loadMode,
    cardIndex: cardIndex,
    selectedComponentId: selectedComponentId,
    selectedPortId: selectedPortId,
    overlayMode: overlayMode,
    draft: const {},
    operationState: PowerWorkspaceOperationState.idle,
    findings: const [],
    pointerStates: const {},
    unsavedDraftWarning: hasDraft,
  );

  PowerWorkspaceState nextCard() =>
      _copy(cardIndex: (cardIndex + 1) % cards.length);

  PowerWorkspaceState previousCard() =>
      _copy(cardIndex: (cardIndex - 1 + cards.length) % cards.length);

  PowerWorkspaceState showCard(PowerWorkspaceCardCode card) {
    final index = cards.indexOf(card);
    if (index < 0) {
      throw ArgumentError.value(card, 'card', 'Card is not enabled.');
    }
    return _copy(cardIndex: index);
  }

  PowerWorkspaceState setOverlay(PowerWorkspaceOverlayMode mode) =>
      _copy(overlayMode: mode);

  PowerWorkspaceState setDraft({
    required Map<String, Object?> draft,
    String? previewFingerprint,
  }) {
    _requireMutationAllowed();
    return _copy(
      draft: draft,
      previewFingerprint: previewFingerprint,
      clearPreviewFingerprint: previewFingerprint == null,
      unsavedDraftWarning: false,
    );
  }

  PowerWorkspaceState clearDraft() => _copy(
    draft: const {},
    clearPreviewFingerprint: true,
    unsavedDraftWarning: false,
  );

  /// Applies only responses captured for the current read context. Obsolete
  /// async responses are deliberately discarded without changing selection,
  /// draft, navigation or pointer state.
  PowerWorkspaceState applyQuerySnapshot(PowerWorkspaceQuerySnapshot response) {
    if (response.contextGeneration != context.generation) return this;
    return _copy(querySnapshot: response);
  }

  PowerWorkspaceState applyTechnicalState({
    required int contextGeneration,
    required Iterable<PowerEvaluationFinding> findings,
    required Map<String, PowerPointerState> pointerStates,
  }) {
    if (contextGeneration != context.generation) return this;
    return _copy(findings: findings, pointerStates: pointerStates);
  }

  PowerWorkspaceState startOperation() {
    _requireMutationAllowed();
    return _copy(
      operationState: PowerWorkspaceOperationState.running,
      clearOperationErrorCode: true,
    );
  }

  PowerWorkspaceState finishOperation() => _copy(
    operationState: PowerWorkspaceOperationState.idle,
    clearOperationErrorCode: true,
  );

  PowerWorkspaceState cancelOperation() => _copy(
    operationState: PowerWorkspaceOperationState.cancelled,
    clearOperationErrorCode: true,
  );

  PowerWorkspaceState failOperation(String code) => _copy(
    operationState: PowerWorkspaceOperationState.failed,
    operationErrorCode: _text(code, 'operationErrorCode').toUpperCase(),
  );

  void _requireMutationAllowed() {
    if (!mutationAllowed) {
      throw StateError('Frozen/historical power workspace is read-only.');
    }
  }

  PowerWorkspaceState _copy({
    PowerWorkspaceReadContext? context,
    PowerWorkspaceScope? scope,
    PowerWorkspaceLoadMode? loadMode,
    int? cardIndex,
    String? selectedComponentId,
    String? selectedPortId,
    bool clearSelection = false,
    bool clearPortSelection = false,
    PowerWorkspaceOverlayMode? overlayMode,
    PowerWorkspaceQuerySnapshot? querySnapshot,
    bool clearQuerySnapshot = false,
    Map<String, Object?>? draft,
    String? previewFingerprint,
    bool clearPreviewFingerprint = false,
    PowerWorkspaceOperationState? operationState,
    String? operationErrorCode,
    bool clearOperationErrorCode = false,
    Iterable<PowerEvaluationFinding>? findings,
    Map<String, PowerPointerState>? pointerStates,
    bool? unsavedDraftWarning,
  }) => PowerWorkspaceState(
    context: context ?? this.context,
    cards: cards,
    scope: scope ?? this.scope,
    loadMode: loadMode ?? this.loadMode,
    cardIndex: cardIndex ?? this.cardIndex,
    selectedComponentId:
        clearSelection ? null : selectedComponentId ?? this.selectedComponentId,
    selectedPortId:
        clearSelection || clearPortSelection
            ? null
            : selectedPortId ?? this.selectedPortId,
    overlayMode: overlayMode ?? this.overlayMode,
    querySnapshot:
        clearQuerySnapshot ? null : querySnapshot ?? this.querySnapshot,
    draft: draft ?? this.draft,
    previewFingerprint:
        clearPreviewFingerprint
            ? null
            : previewFingerprint ?? this.previewFingerprint,
    operationState: operationState ?? this.operationState,
    operationErrorCode:
        clearOperationErrorCode
            ? null
            : operationErrorCode ?? this.operationErrorCode,
    findings: findings ?? this.findings,
    pointerStates: pointerStates ?? this.pointerStates,
    unsavedDraftWarning: unsavedDraftWarning ?? this.unsavedDraftWarning,
  );
}

String _text(String value, String field) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, field, 'Must not be empty.');
  }
  return normalized;
}

String? _nullableText(String? value, String field) {
  if (value == null) return null;
  return _text(value, field);
}

String _sha256(String value, String field) {
  final normalized = _text(value, field).toLowerCase();
  if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(normalized)) {
    throw ArgumentError.value(value, field, 'Expected lowercase SHA-256.');
  }
  return normalized;
}
