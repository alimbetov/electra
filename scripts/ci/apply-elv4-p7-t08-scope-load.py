from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected one anchor, got {count}: {old[:120]!r}')
    path.write_text(text.replace(old, new, 1))


state = ROOT / 'apps/mobile/lib/application/power_workspace_state.dart'
text = state.read_text()
if 'enum PowerWorkspaceScopeKind' not in text:
    anchor = "enum PowerWorkspaceOperationState { idle, running, cancelled, failed }\n"
    addition = '''enum PowerWorkspaceScopeKind { building, floor }\n\nenum PowerWorkspaceLoadMode { all, selectedComponent }\n\nfinal class PowerWorkspaceScope {\n  PowerWorkspaceScope.building() : kind = PowerWorkspaceScopeKind.building, floorId = null;\n\n  PowerWorkspaceScope.floor(String floorId)\n      : kind = PowerWorkspaceScopeKind.floor,\n        floorId = _text(floorId, 'floorId');\n\n  final PowerWorkspaceScopeKind kind;\n  final String? floorId;\n\n  bool sameAs(PowerWorkspaceScope other) =>\n      kind == other.kind && floorId == other.floorId;\n}\n\n'''
    if anchor not in text:
        raise SystemExit('scope enum anchor missing')
    text = text.replace(anchor, addition + anchor, 1)

if 'PowerWorkspaceScope? scope,' not in text:
    text = text.replace(
        "    required Iterable<PowerWorkspaceCardCode> cards,\n    this.cardIndex = 0,\n",
        "    required Iterable<PowerWorkspaceCardCode> cards,\n    PowerWorkspaceScope? scope,\n    this.loadMode = PowerWorkspaceLoadMode.all,\n    this.cardIndex = 0,\n",
        1,
    )
    text = text.replace(
        "  }) : cards = List.unmodifiable(cards),\n",
        "  }) : scope = scope ?? PowerWorkspaceScope.building(),\n       cards = List.unmodifiable(cards),\n",
        1,
    )
    text = text.replace(
        "  final PowerWorkspaceReadContext context;\n  final List<PowerWorkspaceCardCode> cards;\n",
        "  final PowerWorkspaceReadContext context;\n  final PowerWorkspaceScope scope;\n  final PowerWorkspaceLoadMode loadMode;\n  final List<PowerWorkspaceCardCode> cards;\n",
        1,
    )
    text = text.replace(
        "  bool get mutationAllowed => context.mutationAllowed;\n  bool get hasDraft => draft.isNotEmpty;\n",
        "  bool get mutationAllowed => context.mutationAllowed;\n  bool get hasDraft => draft.isNotEmpty;\n  PowerWorkspaceLoadMode get effectiveLoadMode =>\n      loadMode == PowerWorkspaceLoadMode.selectedComponent &&\n              selectedComponentId == null\n          ? PowerWorkspaceLoadMode.all\n          : loadMode;\n",
        1,
    )

if 'PowerWorkspaceState switchScope(' not in text:
    anchor = "  PowerWorkspaceState switchScenario({\n"
    addition = '''  PowerWorkspaceState switchScope(PowerWorkspaceScope nextScope) {\n    if (scope.sameAs(nextScope)) return this;\n    return _copy(\n      context: context.nextGeneration(),\n      scope: nextScope,\n      clearQuerySnapshot: true,\n      unsavedDraftWarning: hasDraft,\n    );\n  }\n\n  PowerWorkspaceState setLoadMode(PowerWorkspaceLoadMode mode) {\n    if (loadMode == mode) return this;\n    return _copy(\n      context: context.nextGeneration(),\n      loadMode: mode,\n      clearQuerySnapshot: true,\n    );\n  }\n\n'''
    if anchor not in text:
        raise SystemExit('switch scope anchor missing')
    text = text.replace(anchor, addition + anchor, 1)

if 'scope: scope,' not in text.split('PowerWorkspaceState switchRevision',1)[1].split(');',1)[0]:
    text = text.replace(
        "    cards: cards,\n    cardIndex: cardIndex,\n",
        "    cards: cards,\n    scope: scope,\n    loadMode: loadMode,\n    cardIndex: cardIndex,\n",
        1,
    )

if 'PowerWorkspaceScope? scope,' not in text.split('PowerWorkspaceState _copy',1)[1]:
    text = text.replace(
        "  PowerWorkspaceState _copy({\n    PowerWorkspaceReadContext? context,\n    int? cardIndex,\n",
        "  PowerWorkspaceState _copy({\n    PowerWorkspaceReadContext? context,\n    PowerWorkspaceScope? scope,\n    PowerWorkspaceLoadMode? loadMode,\n    int? cardIndex,\n",
        1,
    )
    text = text.replace(
        "    context: context ?? this.context,\n    cards: cards,\n",
        "    context: context ?? this.context,\n    cards: cards,\n    scope: scope ?? this.scope,\n    loadMode: loadMode ?? this.loadMode,\n",
        1,
    )
state.write_text(text)

controller = ROOT / 'apps/mobile/lib/application/power_workspace_controller.dart'
text = controller.read_text()
if 'switchScope(PowerWorkspaceScope scope)' not in text:
    anchor = "  Future<PowerWorkspaceSessionSnapshot> switchScenario({\n"
    addition = '''  Future<PowerWorkspaceSessionSnapshot> switchScope(\n    PowerWorkspaceScope scope,\n  ) => _reload(state.switchScope(scope));\n\n  Future<PowerWorkspaceSessionSnapshot> setLoadMode(\n    PowerWorkspaceLoadMode mode,\n  ) => _reload(state.setLoadMode(mode));\n\n'''
    if anchor not in text:
        raise SystemExit('controller scope anchor missing')
    text = text.replace(anchor, addition + anchor, 1)
controller.write_text(text)

repository = ROOT / 'apps/mobile/lib/data/repositories/drift_power_workspace_repository.dart'
text = repository.read_text()
if 'final scopeRecords = await _scopeRecords' not in text:
    old = '''    final scoped = records\n        .where(\n          (row) =>\n              row.nodeKey.scenarioId == context.scenarioId &&\n              (row.nodeKey.scopeKind == PowerEvaluationScopeKind.sequence ||\n                  row.nodeKey.scopeId == context.segmentId),\n        )\n        .toList(growable: false);\n    final pointerStates = <String, PowerPointerState>{\n      for (final row in scoped) row.nodeKey.encode(): row.pointerState,\n    };\n    final relevant = _relevant(scoped, state.selectedComponentId);\n    final overlay = await _overlay(\n      context: context,\n      selectedComponentId: state.selectedComponentId,\n      evidence: relevant,\n    );\n    final budgets = await _budgets(\n      context: context,\n      evidence: scoped,\n      relevant: relevant,\n      selectedGroupIds: overlay.capacityGroupIds.toSet(),\n    );\n'''
    new = '''    final scenarioRecords = records\n        .where(\n          (row) =>\n              row.nodeKey.scenarioId == context.scenarioId &&\n              (row.nodeKey.scopeKind == PowerEvaluationScopeKind.sequence ||\n                  row.nodeKey.scopeId == context.segmentId),\n        )\n        .toList(growable: false);\n    final scopeRecords = await _scopeRecords(\n      context: context,\n      scope: state.scope,\n      values: scenarioRecords,\n    );\n    final pointerStates = <String, PowerPointerState>{\n      for (final row in scopeRecords) row.nodeKey.encode(): row.pointerState,\n    };\n    final selectedEvidence = _relevant(\n      scopeRecords,\n      state.selectedComponentId,\n    );\n    final loadedEvidence =\n        state.effectiveLoadMode == PowerWorkspaceLoadMode.selectedComponent\n            ? selectedEvidence\n            : scopeRecords;\n    final overlayEvidence =\n        state.selectedComponentId == null ? loadedEvidence : selectedEvidence;\n    final overlay = await _overlay(\n      context: context,\n      selectedComponentId: state.selectedComponentId,\n      evidence: overlayEvidence,\n    );\n    final budgets = await _budgets(\n      context: context,\n      evidence: scopeRecords,\n      relevant: selectedEvidence,\n      selectedGroupIds: overlay.capacityGroupIds.toSet(),\n    );\n'''
    if old not in text:
        raise SystemExit('repository scoped block anchor missing')
    text = text.replace(old, new, 1)
    text = text.replace(
        "      currentness: _currentness(scoped),\n",
        "      currentness: _currentness(scopeRecords),\n",
        1,
    )
    text = text.replace(
        "    final cardRows = relevant.isEmpty ? scoped : relevant;\n",
        "    final cardRows = loadedEvidence;\n",
        1,
    )
    text = text.replace(
        "cards: _cards(context: context, evidence: cardRows, allEvidence: scoped),",
        "cards: _cards(\n        context: context,\n        evidence: cardRows,\n        allEvidence: scopeRecords,\n      ),",
        1,
    )

if 'Future<List<_WorkspaceEvidence>> _scopeRecords' not in text:
    anchor = "  List<_WorkspaceEvidence> _relevant(\n"
    addition = '''  Future<List<_WorkspaceEvidence>> _scopeRecords({\n    required PowerWorkspaceReadContext context,\n    required PowerWorkspaceScope scope,\n    required List<_WorkspaceEvidence> values,\n  }) async {\n    if (scope.kind == PowerWorkspaceScopeKind.building) {\n      return values;\n    }\n    final floorId = scope.floorId;\n    if (floorId == null) {\n      throw StateError('Floor scope requires floorId.');\n    }\n    final rows = await database\n        .customSelect(\n          'SELECT ci.id FROM component_instances ci '\n          'JOIN rooms r ON r.id = ci.room_id '\n          'JOIN floors f ON f.id = r.floor_id '\n          'WHERE f.project_id = ? AND f.id = ? '\n          'AND f.deleted_at IS NULL AND r.deleted_at IS NULL '\n          'AND ci.deleted_at IS NULL ORDER BY ci.id',\n          variables: [\n            Variable.withString(context.projectId),\n            Variable.withString(floorId),\n          ],\n        )\n        .get();\n    final componentIds = {for (final row in rows) row.read<String>('id')};\n    if (componentIds.isEmpty) return const <_WorkspaceEvidence>[];\n    return values\n        .where(\n          (row) => componentIds.any(row.referencesEntity),\n        )\n        .toList(growable: false);\n  }\n\n'''
    if anchor not in text:
        raise SystemExit('repository scope helper anchor missing')
    text = text.replace(anchor, addition + anchor, 1)
repository.write_text(text)

state_test = ROOT / 'apps/mobile/test/application/power_workspace_state_test.dart'
text = state_test.read_text()
if 'building scope never retains a floor filter' not in text:
    anchor = "  test('P7 workspace discards stale async query and technical responses', () {\n"
    tests = '''  test('P7 T08 building scope never retains a floor filter', () {\n    final floor = _state().switchScope(PowerWorkspaceScope.floor('floor-2'));\n    expect(floor.scope.kind, PowerWorkspaceScopeKind.floor);\n    expect(floor.scope.floorId, 'floor-2');\n\n    final building = floor.switchScope(PowerWorkspaceScope.building());\n\n    expect(building.scope.kind, PowerWorkspaceScopeKind.building);\n    expect(building.scope.floorId, isNull);\n    expect(building.context.generation, floor.context.generation + 1);\n  });\n\n  test('P7 T08 preferred load mode survives temporary ineffectiveness', () {\n    var state = _state().setLoadMode(PowerWorkspaceLoadMode.selectedComponent);\n\n    expect(state.loadMode, PowerWorkspaceLoadMode.selectedComponent);\n    expect(state.effectiveLoadMode, PowerWorkspaceLoadMode.all);\n\n    state = state.select(componentId: 'camera-1');\n    expect(state.loadMode, PowerWorkspaceLoadMode.selectedComponent);\n    expect(\n      state.effectiveLoadMode,\n      PowerWorkspaceLoadMode.selectedComponent,\n    );\n\n    state = state.select();\n    expect(state.loadMode, PowerWorkspaceLoadMode.selectedComponent);\n    expect(state.effectiveLoadMode, PowerWorkspaceLoadMode.all);\n  });\n\n'''
    if anchor not in text:
        raise SystemExit('state test anchor missing')
    text = text.replace(anchor, tests + anchor, 1)
state_test.write_text(text)

controller_test = ROOT / 'apps/mobile/test/application/power_workspace_controller_test.dart'
text = controller_test.read_text()
if 'scope change reloads the requested dataset' not in text:
    anchor = "  test(\n    'P7 controller discards projection returned for obsolete generation',\n"
    tests = '''  test('P7 T08 scope change reloads the requested dataset', () async {\n    final repository = _Repository();\n    final controller = PowerWorkspaceController(repository: repository);\n    await controller.open('project');\n\n    await controller.switchScope(PowerWorkspaceScope.floor('floor-7'));\n    expect(repository.loadedScopes.single.kind, PowerWorkspaceScopeKind.floor);\n    expect(repository.loadedScopes.single.floorId, 'floor-7');\n\n    await controller.switchScope(PowerWorkspaceScope.building());\n    expect(repository.loadedScopes.last.kind, PowerWorkspaceScopeKind.building);\n    expect(repository.loadedScopes.last.floorId, isNull);\n  });\n\n  test('P7 T08 controller preserves preferred load mode across selection', () async {\n    final repository = _Repository();\n    final controller = PowerWorkspaceController(repository: repository);\n    await controller.open('project');\n\n    await controller.setLoadMode(PowerWorkspaceLoadMode.selectedComponent);\n    expect(controller.state.loadMode, PowerWorkspaceLoadMode.selectedComponent);\n    expect(controller.state.effectiveLoadMode, PowerWorkspaceLoadMode.all);\n\n    await controller.select(componentId: 'camera-9');\n    expect(controller.state.loadMode, PowerWorkspaceLoadMode.selectedComponent);\n    expect(\n      controller.state.effectiveLoadMode,\n      PowerWorkspaceLoadMode.selectedComponent,\n    );\n    expect(repository.loadedModes.last, PowerWorkspaceLoadMode.selectedComponent);\n  });\n\n'''
    if anchor not in text:
        raise SystemExit('controller test insertion anchor missing')
    text = text.replace(anchor, tests + anchor, 1)

if 'final loadedScopes = <PowerWorkspaceScope>[];' not in text:
    text = text.replace(
        "  int loads = 0;\n",
        "  int loads = 0;\n  final loadedScopes = <PowerWorkspaceScope>[];\n  final loadedModes = <PowerWorkspaceLoadMode>[];\n",
        1,
    )
    text = text.replace(
        "  Future<PowerWorkspaceProjection> load(PowerWorkspaceState state) async {\n    loads += 1;\n",
        "  Future<PowerWorkspaceProjection> load(PowerWorkspaceState state) async {\n    loads += 1;\n    loadedScopes.add(state.scope);\n    loadedModes.add(state.effectiveLoadMode);\n",
        1,
    )
controller_test.write_text(text)
