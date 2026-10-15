import 'package:electra_mobile/application/power_workspace_state.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'P7 workspace keeps selection and card while scenario generation changes',
    () {
      var state = _state();
      state = state.select(componentId: 'camera-1', portId: 'power-in');
      final selectedGeneration = state.context.generation;
      state = state.nextCard().setDraft(
        draft: const {'route': 'draft-1'},
        previewFingerprint:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      );
      final card = state.currentCard;

      state = state.switchScenario(scenarioId: 'BACKUP', segmentId: 'ALARM');

      expect(state.context.generation, selectedGeneration + 1);
      expect(state.selectedComponentId, 'camera-1');
      expect(state.selectedPortId, 'power-in');
      expect(state.currentCard, card);
      expect(state.hasDraft, isTrue);
      expect(state.unsavedDraftWarning, isTrue);
    },
  );

  test(
    'P7 selecting a new component without a port clears stale port selection',
    () {
      var state = _state().select(componentId: 'camera-1', portId: 'power-in');
      state = state.select(componentId: 'camera-2');

      expect(state.selectedComponentId, 'camera-2');
      expect(state.selectedPortId, null);
    },
  );

  test('P7 workspace discards stale async query and technical responses', () {
    final initial = _state();
    final staleGeneration = initial.context.generation;
    final selected = initial.select(componentId: 'camera-1');

    final staleQuery = selected.applyQuerySnapshot(
      PowerWorkspaceQuerySnapshot(
        contextGeneration: staleGeneration,
        values: const {'demandW': '10'},
      ),
    );
    expect(identical(staleQuery, selected), isTrue);
    expect(staleQuery.querySnapshot, isNull);

    final staleTechnical = selected.applyTechnicalState(
      contextGeneration: staleGeneration,
      findings: [_finding('OLD')],
      pointerStates: const {},
    );
    expect(identical(staleTechnical, selected), isTrue);

    final current = selected.applyQuerySnapshot(
      PowerWorkspaceQuerySnapshot(
        contextGeneration: selected.context.generation,
        values: const {'demandW': '12'},
      ),
    );
    expect(current.querySnapshot!.values['demandW'], '12');
  });

  test('P7 card navigation never changes technical context or selection', () {
    final selected = _state().select(
      componentId: 'camera-1',
      portId: 'power-in',
    );
    final generation = selected.context.generation;
    final next = selected.nextCard().nextCard().previousCard();

    expect(next.context.generation, generation);
    expect(next.selectedComponentId, 'camera-1');
    expect(next.selectedPortId, 'power-in');
  });

  test(
    'P7 frozen workspace is read-only and revision switch clears drafts',
    () {
      final working = _state().setDraft(
        draft: const {'route': 'draft'},
        previewFingerprint:
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      );
      final frozen = working.switchRevision(
        designRevisionId: 'rev-frozen',
        lifecycleState: 'FROZEN',
        scenarioId: 'NORMAL',
        segmentId: 'SEG-1',
      );

      expect(frozen.mutationAllowed, isFalse);
      expect(frozen.hasDraft, isFalse);
      expect(frozen.unsavedDraftWarning, isTrue);
      expect(() => frozen.setDraft(draft: const {'x': 1}), throwsStateError);
      expect(frozen.startOperation, throwsStateError);
    },
  );

  test(
    'P7 operation state is transient and pointer state remains query data',
    () {
      final node = PowerNodeKeyV2(
        revisionId: 'rev-working',
        scenarioId: 'NORMAL',
        scopeKind: PowerEvaluationScopeKind.segment,
        scopeId: 'SEG-1',
        processCode: PowerProcessCode.pwr01,
        subjectKind: 'LOAD',
        subjectId: 'camera-1',
      );
      var state = _state().applyTechnicalState(
        contextGeneration: 1,
        findings: [_finding('PWR01')],
        pointerStates: {node.encode(): PowerPointerState.stale},
      );
      expect(state.pointerStates[node.encode()], PowerPointerState.stale);
      expect(state.findings.single.code, 'PWR01');

      state = state.startOperation();
      expect(state.operationState, PowerWorkspaceOperationState.running);
      state = state.cancelOperation();
      expect(state.operationState, PowerWorkspaceOperationState.cancelled);
      expect(state.pointerStates[node.encode()], PowerPointerState.stale);
    },
  );
}

PowerWorkspaceState _state() => PowerWorkspaceState(
  context: PowerWorkspaceReadContext(
    projectId: 'project',
    designRevisionId: 'rev-working',
    lifecycleState: 'WORKING',
    scenarioId: 'NORMAL',
    segmentId: 'SEG-1',
    generation: 1,
  ),
  cards: PowerWorkspaceCardCode.values,
);

PowerEvaluationFinding _finding(String code) =>
    PowerEvaluationFinding(code: code, severity: 'INFO', message: code);
