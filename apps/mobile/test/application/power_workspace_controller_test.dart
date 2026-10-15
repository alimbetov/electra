import 'dart:async';

import 'package:electra_mobile/application/elv_command_result.dart';
import 'package:electra_mobile/application/elv_physical_routing_workspace_service.dart';
import 'package:electra_mobile/application/elv_physical_routing_workspace_state.dart';
import 'package:electra_mobile/application/elv_physical_trace_service.dart';
import 'package:electra_mobile/application/power_workspace_controller.dart';
import 'package:electra_mobile/application/power_workspace_projection.dart';
import 'package:electra_mobile/application/power_workspace_state.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('P7 controller keeps reviewed draft on command failure', () async {
    final repository = _Repository();
    final routing = _RoutingService(
      result: const ElvCommandFailureResult<Object?>(
        ElvFailure(
          code: 'ELV_ROUTE_CONFLICT',
          category: ElvFailureCategory.revisionConflict,
        ),
      ),
    );
    final controller = PowerWorkspaceController(
      repository: repository,
      routingService: routing,
    );
    await controller.open('project');
    controller.stageReviewedDraft(
      draft: const {'routeId': 'run-1'},
      previewFingerprint: _hash('a'),
    );

    final result = await controller.commitReviewedRoute(
      const _Command(commandId: 'cmd-1', projectId: 'project'),
    );

    expect(result, isA<ElvCommandFailureResult<Object?>>());
    expect(controller.state.hasDraft, isTrue);
    expect(controller.state.previewFingerprint, _hash('a'));
    expect(controller.state.operationState, PowerWorkspaceOperationState.failed);
    expect(controller.state.operationErrorCode, 'ELV_ROUTE_CONFLICT');
    expect(routing.calls, 1);
  });

  test('P7 controller clears draft only after public command success', () async {
    final repository = _Repository();
    final routing = _RoutingService(
      result: const ElvCommandSuccess<Object?>('ok'),
    );
    final controller = PowerWorkspaceController(
      repository: repository,
      routingService: routing,
    );
    await controller.open('project');
    controller.stageReviewedDraft(
      draft: const {'routeId': 'run-1'},
      previewFingerprint: _hash('b'),
    );

    final result = await controller.commitReviewedRoute(
      const _Command(commandId: 'cmd-1', projectId: 'project'),
    );

    expect(result, isA<ElvCommandSuccess<Object?>>());
    expect(controller.state.hasDraft, isFalse);
    expect(controller.state.previewFingerprint, isNull);
    expect(controller.state.operationState, PowerWorkspaceOperationState.idle);
    expect(repository.loads, 1);
  });

  test('P7 controller blocks mutation in frozen workspace', () async {
    final repository = _Repository(lifecycleState: 'FROZEN');
    final routing = _RoutingService(
      result: const ElvCommandSuccess<Object?>('unexpected'),
    );
    final controller = PowerWorkspaceController(
      repository: repository,
      routingService: routing,
    );
    await controller.open('project');

    final result = await controller.commitReviewedRoute(
      const _Command(commandId: 'cmd-1', projectId: 'project'),
    );

    final failure = result as ElvCommandFailureResult<Object?>;
    expect(failure.failure.code, 'ELV4_POWER_WORKSPACE_READ_ONLY');
    expect(routing.calls, 0);
  });

  test('P7 controller routes undo and redo through durable history boundary', () async {
    final history = _HistoryService();
    final controller = PowerWorkspaceController(
      repository: _Repository(),
      historyService: history,
    );
    await controller.open('project');

    expect(await controller.canUndo(), isTrue);
    expect(await controller.canRedo(), isTrue);
    expect(await controller.undo(), isA<ElvCommandSuccess<Object?>>());
    expect(await controller.redo(), isA<ElvCommandSuccess<Object?>>());
    expect(history.undoCalls, 1);
    expect(history.redoCalls, 1);
  });

  test('P7 controller discards projection returned for obsolete generation', () async {
    final repository = _DeferredRepository();
    final controller = PowerWorkspaceController(repository: repository);
    await controller.open('project');

    final first = controller.switchScenario(
      scenarioId: 'BACKUP',
      segmentId: 'SEG-2',
    );
    await Future<void>.delayed(Duration.zero);
    final second = controller.switchScenario(
      scenarioId: 'ALARM',
      segmentId: 'SEG-3',
    );
    await Future<void>.delayed(Duration.zero);

    repository.complete(
      2,
      _projection(
        generation: 2,
        lifecycleState: 'WORKING',
        scenarioId: 'BACKUP',
        segmentId: 'SEG-2',
      ),
    );
    await first;
    expect(controller.state.context.scenarioId, 'ALARM');

    repository.complete(
      3,
      _projection(
        generation: 3,
        lifecycleState: 'WORKING',
        scenarioId: 'ALARM',
        segmentId: 'SEG-3',
      ),
    );
    await second;
    expect(controller.projection.contextGeneration, 3);
    expect(controller.state.context.scenarioId, 'ALARM');
  });
}

final class _Repository implements PowerWorkspaceRepository {
  _Repository({this.lifecycleState = 'WORKING'});

  final String lifecycleState;
  int loads = 0;

  @override
  Future<PowerWorkspaceOpenResult?> open(String projectId) async {
    final state = _state(lifecycleState: lifecycleState);
    return PowerWorkspaceOpenResult(
      state: state,
      projection: _projection(
        generation: 1,
        lifecycleState: lifecycleState,
      ),
    );
  }

  @override
  Future<PowerWorkspaceProjection> load(PowerWorkspaceState state) async {
    loads += 1;
    return _projection(
      generation: state.context.generation,
      lifecycleState: state.context.lifecycleState,
      scenarioId: state.context.scenarioId,
      segmentId: state.context.segmentId,
    );
  }
}

final class _DeferredRepository implements PowerWorkspaceRepository {
  final completions = <int, Completer<PowerWorkspaceProjection>>{};

  @override
  Future<PowerWorkspaceOpenResult?> open(String projectId) async {
    final state = _state();
    return PowerWorkspaceOpenResult(
      state: state,
      projection: _projection(generation: 1),
    );
  }

  @override
  Future<PowerWorkspaceProjection> load(PowerWorkspaceState state) {
    final completer = Completer<PowerWorkspaceProjection>();
    completions[state.context.generation] = completer;
    return completer.future;
  }

  void complete(int generation, PowerWorkspaceProjection projection) =>
      completions[generation]!.complete(projection);
}

final class _RoutingService implements ElvPhysicalRoutingWorkspaceService {
  _RoutingService({required this.result});

  final ElvCommandResult<Object?> result;
  int calls = 0;

  @override
  Future<ElvCommandResult<Object?>> execute(ElvWorkspaceCommand command) async {
    calls += 1;
    return result;
  }

  @override
  Future<PhysicalRoutingWorkspaceState> load({
    required String projectId,
    String? connectionId,
  }) => throw UnimplementedError();

  @override
  Future<PhysicalTraceResult> traceCable(String projectId, String cableId) =>
      throw UnimplementedError();

  @override
  Future<PhysicalTraceResult> traceConnection(
    String projectId,
    String connectionId,
  ) => throw UnimplementedError();

  @override
  Stream<PhysicalRoutingWorkspaceState> watch(String projectId) =>
      const Stream.empty();
}

final class _HistoryService implements ElvCommandHistoryService {
  int undoCalls = 0;
  int redoCalls = 0;

  @override
  Future<bool> canRedo(String projectId) async => true;

  @override
  Future<bool> canUndo(String projectId) async => true;

  @override
  Future<ElvCommandResult<Object?>> redo(String projectId) async {
    redoCalls += 1;
    return const ElvCommandSuccess<Object?>('redo');
  }

  @override
  Future<ElvCommandResult<Object?>> undo(String projectId) async {
    undoCalls += 1;
    return const ElvCommandSuccess<Object?>('undo');
  }
}

final class _Command implements ElvWorkspaceCommand {
  const _Command({required this.commandId, required this.projectId});

  @override
  final String commandId;
  @override
  final String projectId;
}

PowerWorkspaceState _state({String lifecycleState = 'WORKING'}) =>
    PowerWorkspaceState(
      context: PowerWorkspaceReadContext(
        projectId: 'project',
        designRevisionId: 'rev-1',
        lifecycleState: lifecycleState,
        scenarioId: 'NORMAL',
        segmentId: 'SEG-1',
        generation: 1,
      ),
      cards: PowerWorkspaceCardCode.values,
    );

PowerWorkspaceProjection _projection({
  required int generation,
  String lifecycleState = 'WORKING',
  String scenarioId = 'NORMAL',
  String segmentId = 'SEG-1',
}) => PowerWorkspaceProjection(
  contextGeneration: generation,
  readKind: lifecycleState == 'WORKING'
      ? PowerWorkspaceReadKind.working
      : PowerWorkspaceReadKind.capturedEmpty,
  lifecycleState: lifecycleState,
  currentness: PowerWorkspaceCurrentness.empty,
  scenarios: [
    PowerWorkspaceScenarioOption(
      scenarioId: scenarioId,
      segmentId: segmentId,
      label: '$scenarioId · $segmentId',
    ),
  ],
  cards: [
    for (final code in PowerWorkspaceCardCode.values)
      PowerWorkspaceCardProjection(
        code: code,
        title: code.name,
        summary: code.name,
        currentness: PowerWorkspaceCurrentness.empty,
      ),
  ],
  overlay: PowerWorkspaceOverlayProjection(),
);

String _hash(String char) => List.filled(64, char).join();
