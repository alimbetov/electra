import 'dart:async';

import 'package:electra_mobile/application/default_elv_physical_routing_workspace_service.dart';
import 'package:electra_mobile/application/elv_command_result.dart';
import 'package:electra_mobile/application/elv_physical_routing_workspace_service.dart';
import 'package:electra_mobile/application/elv_physical_routing_workspace_state.dart';
import 'package:electra_mobile/application/elv_physical_trace_service.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ELV3 P7 workspace foundation', () {
    late _FakeDataSource dataSource;
    late _FakeExecutor executor;
    late _FakeAuthorizer authorizer;
    late DefaultElvPhysicalRoutingWorkspaceService service;

    setUp(() {
      dataSource = _FakeDataSource();
      executor = _FakeExecutor();
      authorizer = _FakeAuthorizer();
      service = DefaultElvPhysicalRoutingWorkspaceService(
        dataSource: dataSource,
        executor: executor,
        traceService: _FakeTraceService(),
        authorizer: authorizer,
      );
    });

    test('progresses through all seven canonical stages', () async {
      final cases = <(PhysicalRoutingSelectionSnapshot, PhysicalRoutingStage)>[
        (
          const PhysicalRoutingSelectionSnapshot(),
          PhysicalRoutingStage.logicalConnection,
        ),
        (
          const PhysicalRoutingSelectionSnapshot(connectionId: 'CONN-001'),
          PhysicalRoutingStage.cable,
        ),
        (
          const PhysicalRoutingSelectionSnapshot(
            connectionId: 'CONN-001',
            cableId: 'CABLE-001',
          ),
          PhysicalRoutingStage.allocation,
        ),
        (
          const PhysicalRoutingSelectionSnapshot(
            connectionId: 'CONN-001',
            cableId: 'CABLE-001',
            allocationId: 'ALLOC-001',
          ),
          PhysicalRoutingStage.termination,
        ),
        (
          const PhysicalRoutingSelectionSnapshot(
            connectionId: 'CONN-001',
            cableId: 'CABLE-001',
            allocationId: 'ALLOC-001',
            terminationSetComplete: true,
          ),
          PhysicalRoutingStage.route,
        ),
        (
          const PhysicalRoutingSelectionSnapshot(
            connectionId: 'CONN-001',
            cableId: 'CABLE-001',
            allocationId: 'ALLOC-001',
            terminationSetComplete: true,
            cableRunId: 'RUN-001',
          ),
          PhysicalRoutingStage.carrier,
        ),
        (
          const PhysicalRoutingSelectionSnapshot(
            connectionId: 'CONN-001',
            cableId: 'CABLE-001',
            allocationId: 'ALLOC-001',
            terminationSetComplete: true,
            cableRunId: 'RUN-001',
            carrierAssignmentComplete: true,
          ),
          PhysicalRoutingStage.findings,
        ),
      ];

      for (final (selection, expectedStage) in cases) {
        dataSource.selection = selection;
        final state = await service.load(projectId: 'PRJ-001');
        expect(state.activeStage, expectedStage);
      }
    });

    test(
      'derives canEdit from design context and command permission',
      () async {
        dataSource.selection = const PhysicalRoutingSelectionSnapshot(
          connectionId: 'CONN-001',
          commandMutationsAllowed: false,
        );

        final state = await service.load(projectId: 'PRJ-001');

        expect(state.canEdit, isFalse);
        expect(state.isReadOnly, isTrue);
      },
    );

    test('rejects command when project has no WORKING revision', () async {
      dataSource.context = const PhysicalDesignContext(
        projectId: 'PRJ-001',
        workingDesignRevisionId: null,
        latestFrozenRevisionId: 'REV-001',
        editingAllowed: false,
      );

      final result = await service.execute(const _TestCommand());

      expect(result, isA<ElvCommandFailureResult<Object?>>());
      final failure = result as ElvCommandFailureResult<Object?>;
      expect(failure.failure.code, 'ELV_WORKSPACE_READ_ONLY');
      expect(executor.calls, 0);
    });

    test('rejects command denied by command authorizer', () async {
      authorizer.allowed = false;

      final result = await service.execute(const _TestCommand());

      expect(result, isA<ElvCommandFailureResult<Object?>>());
      final failure = result as ElvCommandFailureResult<Object?>;
      expect(failure.failure.code, 'ELV_WORKSPACE_COMMAND_FORBIDDEN');
      expect(executor.calls, 0);
    });

    test('delegates authorized command exactly once', () async {
      final result = await service.execute(const _TestCommand());

      expect(result, isA<ElvCommandSuccess<Object?>>());
      expect(executor.calls, 1);
    });
  });
}

final class _FakeDataSource implements ElvPhysicalRoutingWorkspaceDataSource {
  PhysicalDesignContext context = const PhysicalDesignContext(
    projectId: 'PRJ-001',
    workingDesignRevisionId: 'REV-001',
    latestFrozenRevisionId: null,
    editingAllowed: true,
  );

  PhysicalRoutingSelectionSnapshot selection =
      const PhysicalRoutingSelectionSnapshot();

  final StreamController<void> changes = StreamController<void>.broadcast();

  @override
  Future<PhysicalDesignContext> loadDesignContext(String projectId) async =>
      context;

  @override
  Future<PhysicalRoutingSelectionSnapshot> loadSelection({
    required String projectId,
    String? connectionId,
  }) async => selection;

  @override
  Stream<void> watchChanges(String projectId) => changes.stream;
}

final class _FakeExecutor implements ElvWorkspaceCommandExecutor {
  int calls = 0;

  @override
  Future<ElvCommandResult<Object?>> execute(ElvWorkspaceCommand command) async {
    calls += 1;
    return const ElvCommandSuccess<Object?>('OK');
  }
}

final class _FakeAuthorizer implements ElvWorkspaceCommandAuthorizer {
  bool allowed = true;

  @override
  Future<bool> canExecute(ElvWorkspaceCommand command) async => allowed;
}

final class _FakeTraceService implements ElvPhysicalTraceService {
  @override
  Future<PhysicalTraceResult> traceCable(String projectId, String cableId) =>
      Future<PhysicalTraceResult>.error(UnimplementedError());

  @override
  Future<PhysicalTraceResult> traceConnection(
    String projectId,
    String connectionId,
  ) => Future<PhysicalTraceResult>.error(UnimplementedError());
}

final class _TestCommand implements ElvWorkspaceCommand {
  const _TestCommand();

  @override
  String get commandId => 'CMD-001';

  @override
  String get projectId => 'PRJ-001';
}
