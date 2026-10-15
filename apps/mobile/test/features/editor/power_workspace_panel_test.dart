import 'package:electra_mobile/application/power_workspace_projection.dart';
import 'package:electra_mobile/application/power_workspace_state.dart';
import 'package:electra_mobile/features/editor/power_workspace_panel.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('P7 panel renders exactly one active progressive card', (
    tester,
  ) async {
    var state = _state();
    await _pump(tester, state: state, projection: _projection());

    expect(find.text('Demand summary'), findsOneWidget);
    expect(find.text('Backup summary'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('power-card-next')));
    state = state.nextCard();
    await _pump(tester, state: state, projection: _projection());

    expect(find.text('Path summary'), findsOneWidget);
    expect(find.text('Demand summary'), findsNothing);
    expect(state.selectedComponentId, 'camera-1');
  });

  testWidgets('P7 panel shows STALE explicitly instead of hiding old values', (
    tester,
  ) async {
    final projection = _projection(
      currentness: PowerWorkspaceCurrentness.stale,
      demandCurrentness: PowerWorkspaceCurrentness.stale,
    );
    await _pump(tester, state: _state(), projection: projection);

    expect(
      find.byKey(const ValueKey('power-currentness-stale')),
      findsAtLeastNWidgets(1),
    );
    expect(find.text('24 W'), findsOneWidget);
  });

  testWidgets('P7 NOT_CAPTURED and captured-empty are distinct', (
    tester,
  ) async {
    await _pump(
      tester,
      state: _state(lifecycle: 'FROZEN'),
      projection: _projection(
        readKind: PowerWorkspaceReadKind.notCaptured,
        lifecycle: 'FROZEN',
        reasonCode: 'ELV4_POWER_NOT_CAPTURED',
      ),
    );
    expect(find.text('Power evidence not captured'), findsOneWidget);
    expect(find.text('Captured power section is empty'), findsNothing);

    await _pump(
      tester,
      state: _state(lifecycle: 'FROZEN'),
      projection: _projection(
        readKind: PowerWorkspaceReadKind.capturedEmpty,
        lifecycle: 'FROZEN',
      ),
    );
    expect(find.text('Captured power section is empty'), findsOneWidget);
    expect(find.text('Power evidence not captured'), findsNothing);
  });

  testWidgets(
    'P7 source card exposes global budgets and selected contribution',
    (tester) async {
      final state = _state().showCard(PowerWorkspaceCardCode.sourceCapacity);
      await _pump(tester, state: state, projection: _projection());

      expect(find.text('Shared-source / project budget'), findsOneWidget);
      expect(find.byKey(const ValueKey('power-budget-pse-a')), findsOneWidget);
      expect(find.byKey(const ValueKey('power-budget-pse-b')), findsOneWidget);
      expect(find.byIcon(Icons.my_location), findsOneWidget);
    },
  );

  testWidgets('P7 finding remediation returns exact entity reference', (
    tester,
  ) async {
    PowerWorkspaceFindingProjection? selected;
    final state = _state().showCard(PowerWorkspaceCardCode.findings);
    await _pump(
      tester,
      state: state,
      projection: _projection(),
      onFindingSelected: (value) => selected = value,
    );

    await tester.tap(find.byKey(const ValueKey('power-finding-0')));
    expect(selected?.entityRef, 'camera-1');
  });

  testWidgets('P7 compact panel has no horizontal overflow at 360 px', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pump(tester, state: _state(), projection: _projection());
    expect(tester.takeException(), isNull);
  });

  testWidgets('P7 frozen workspace disables reviewed route apply and undo', (
    tester,
  ) async {
    final state = _state(lifecycle: 'FROZEN').switchRevision(
      designRevisionId: 'rev-frozen',
      lifecycleState: 'FROZEN',
      scenarioId: 'NORMAL',
      segmentId: 'SEG-1',
    );
    await _pump(
      tester,
      state: state,
      projection: _projection(
        readKind: PowerWorkspaceReadKind.captured,
        lifecycle: 'FROZEN',
      ),
      canUndo: true,
    );

    final undo = tester.widget<IconButton>(
      find.byKey(const ValueKey('power-undo')),
    );
    expect(undo.onPressed, isNull);
  });

  testWidgets('P7 compact sheet restores focus to invoking control', (
    tester,
  ) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder:
              (context) => Scaffold(
                body: Focus(
                  focusNode: focus,
                  child: ElevatedButton(
                    key: const ValueKey('open-power-sheet'),
                    onPressed:
                        () => showPowerWorkspaceSheet(
                          context: context,
                          restoreFocusTo: focus,
                          child: const Center(child: Text('Power sheet body')),
                        ),
                    child: const Text('Power'),
                  ),
                ),
              ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('open-power-sheet')));
    await tester.pumpAndSettle();
    expect(find.text('Power sheet body'), findsOneWidget);

    Navigator.of(tester.element(find.text('Power sheet body'))).pop();
    await tester.pumpAndSettle();
    expect(focus.hasFocus, isTrue);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required PowerWorkspaceState state,
  required PowerWorkspaceProjection projection,
  ValueChanged<PowerWorkspaceFindingProjection>? onFindingSelected,
  bool canUndo = false,
}) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 360,
        height: 720,
        child: PowerWorkspacePanel(
          state: state,
          projection: projection,
          onScenarioChanged: (_) {},
          onOverlayChanged: (_) {},
          onPreviousCard: () {},
          onNextCard: () {},
          onFindingSelected: onFindingSelected,
          canUndo: canUndo,
          onUndo: () {},
        ),
      ),
    ),
  ),
);

PowerWorkspaceState _state({String lifecycle = 'WORKING'}) =>
    PowerWorkspaceState(
      context: PowerWorkspaceReadContext(
        projectId: 'project',
        designRevisionId: 'rev-1',
        lifecycleState: lifecycle,
        scenarioId: 'NORMAL',
        segmentId: 'SEG-1',
        generation: 1,
      ),
      cards: PowerWorkspaceCardCode.values,
      selectedComponentId: 'camera-1',
    );

PowerWorkspaceProjection _projection({
  PowerWorkspaceReadKind readKind = PowerWorkspaceReadKind.working,
  String lifecycle = 'WORKING',
  String? reasonCode,
  PowerWorkspaceCurrentness currentness = PowerWorkspaceCurrentness.current,
  PowerWorkspaceCurrentness demandCurrentness =
      PowerWorkspaceCurrentness.current,
}) => PowerWorkspaceProjection(
  contextGeneration: 1,
  readKind: readKind,
  lifecycleState: lifecycle,
  currentness: currentness,
  reasonCode: reasonCode,
  scenarios: [
    PowerWorkspaceScenarioOption(
      scenarioId: 'NORMAL',
      segmentId: 'SEG-1',
      label: 'Normal · SEG-1',
    ),
  ],
  cards: [
    PowerWorkspaceCardProjection(
      code: PowerWorkspaceCardCode.demand,
      title: 'Demand',
      summary: 'Demand summary',
      currentness: demandCurrentness,
      metrics: [
        PowerWorkspaceMetric(
          key: 'demand.w',
          label: 'Demand',
          value: '24',
          unit: 'W',
        ),
      ],
    ),
    PowerWorkspaceCardProjection(
      code: PowerWorkspaceCardCode.upstreamPath,
      title: 'Upstream path',
      summary: 'Path summary',
      currentness: currentness,
    ),
    for (final code in PowerWorkspaceCardCode.values.where(
      (value) =>
          value != PowerWorkspaceCardCode.demand &&
          value != PowerWorkspaceCardCode.upstreamPath &&
          value != PowerWorkspaceCardCode.findings,
    ))
      PowerWorkspaceCardProjection(
        code: code,
        title: code.name,
        summary:
            code == PowerWorkspaceCardCode.backup
                ? 'Backup summary'
                : '${code.name} summary',
        currentness: currentness,
      ),
    PowerWorkspaceCardProjection(
      code: PowerWorkspaceCardCode.findings,
      title: 'Findings',
      summary: '1 finding',
      currentness: currentness,
      findings: [
        PowerWorkspaceFindingProjection(
          finding: PowerEvaluationFinding(
            code: 'PWR_TEST',
            severity: 'WARNING',
            message: 'Review camera power path.',
            sourceRefs: const ['camera-1'],
          ),
          entityRef: 'camera-1',
        ),
      ],
    ),
  ],
  overlay: PowerWorkspaceOverlayProjection(
    highlightedComponentIds: const ['camera-1'],
    sourceComponentIds: const ['pse-1'],
    highlightedCableRunIds: const ['run-1'],
    capacityGroupIds: const ['pse-a'],
  ),
  budgets: [
    PowerWorkspaceBudgetProjection(
      groupId: 'pse-a',
      ownerComponentId: 'pse-1',
      currentness: currentness,
      selectedContribution: true,
      metrics: [
        PowerWorkspaceMetric(
          key: 'budget.a',
          label: 'Available',
          value: '60',
          unit: 'W',
        ),
      ],
    ),
    PowerWorkspaceBudgetProjection(
      groupId: 'pse-b',
      ownerComponentId: 'pse-2',
      currentness: currentness,
    ),
  ],
);
