import 'package:engineering_core/engineering_core.dart';

import 'elv_command_result.dart';
import 'elv_physical_routing_workspace_service.dart';
import 'elv_physical_routing_workspace_state.dart';
import 'elv_physical_trace_service.dart';

final class PhysicalRoutingSelectionSnapshot {
  const PhysicalRoutingSelectionSnapshot({
    this.connectionId,
    this.cableId,
    this.allocationId,
    this.cableRunId,
    this.terminationSetComplete = false,
    this.carrierAssignmentComplete = false,
    this.commandMutationsAllowed = true,
    this.blockingIssues = const [],
  });

  final String? connectionId;
  final String? cableId;
  final String? allocationId;
  final String? cableRunId;
  final bool terminationSetComplete;
  final bool carrierAssignmentComplete;
  final bool commandMutationsAllowed;
  final List<PhysicalRoutingBlockingIssue> blockingIssues;
}

abstract interface class ElvPhysicalRoutingWorkspaceDataSource {
  Future<PhysicalDesignContext> loadDesignContext(String projectId);

  Future<PhysicalRoutingSelectionSnapshot> loadSelection({
    required String projectId,
    String? connectionId,
  });

  Stream<void> watchChanges(String projectId);
}

abstract interface class ElvWorkspaceCommandExecutor {
  Future<ElvCommandResult<Object?>> execute(ElvWorkspaceCommand command);
}

abstract interface class ElvWorkspaceCommandAuthorizer {
  Future<bool> canExecute(ElvWorkspaceCommand command);
}

final class AllowAllElvWorkspaceCommandAuthorizer
    implements ElvWorkspaceCommandAuthorizer {
  const AllowAllElvWorkspaceCommandAuthorizer();

  @override
  Future<bool> canExecute(ElvWorkspaceCommand command) async => true;
}

final class DefaultElvPhysicalRoutingWorkspaceService
    implements ElvPhysicalRoutingWorkspaceService {
  const DefaultElvPhysicalRoutingWorkspaceService({
    required this.dataSource,
    required this.executor,
    required this.traceService,
    this.authorizer = const AllowAllElvWorkspaceCommandAuthorizer(),
  });

  final ElvPhysicalRoutingWorkspaceDataSource dataSource;
  final ElvWorkspaceCommandExecutor executor;
  final ElvPhysicalTraceService traceService;
  final ElvWorkspaceCommandAuthorizer authorizer;

  @override
  Future<PhysicalRoutingWorkspaceState> load({
    required String projectId,
    String? connectionId,
  }) async {
    final context = await dataSource.loadDesignContext(projectId);
    final selection = await dataSource.loadSelection(
      projectId: projectId,
      connectionId: connectionId,
    );
    return _state(projectId, context, selection);
  }

  @override
  Stream<PhysicalRoutingWorkspaceState> watch(String projectId) async* {
    yield await load(projectId: projectId);
    await for (final _ in dataSource.watchChanges(projectId)) {
      yield await load(projectId: projectId);
    }
  }

  @override
  Future<ElvCommandResult<Object?>> execute(ElvWorkspaceCommand command) async {
    final context = await dataSource.loadDesignContext(command.projectId);
    if (!context.editingAllowed || context.workingDesignRevisionId == null) {
      return const ElvCommandFailureResult<Object?>(
        ElvFailure(
          code: 'ELV_WORKSPACE_READ_ONLY',
          category: ElvFailureCategory.lifecycle,
        ),
      );
    }
    if (!await authorizer.canExecute(command)) {
      return const ElvCommandFailureResult<Object?>(
        ElvFailure(
          code: 'ELV_WORKSPACE_COMMAND_FORBIDDEN',
          category: ElvFailureCategory.validation,
        ),
      );
    }
    return executor.execute(command);
  }

  @override
  Future<PhysicalTraceResult> traceConnection(
    String projectId,
    String connectionId,
  ) =>
      traceService.traceConnection(projectId, connectionId);

  @override
  Future<PhysicalTraceResult> traceCable(
    String projectId,
    String cableId,
  ) =>
      traceService.traceCable(projectId, cableId);

  PhysicalRoutingWorkspaceState _state(
    String projectId,
    PhysicalDesignContext context,
    PhysicalRoutingSelectionSnapshot selection,
  ) {
    final stage = switch ((
      selection.connectionId,
      selection.cableId,
      selection.allocationId,
      selection.terminationSetComplete,
      selection.cableRunId,
      selection.carrierAssignmentComplete,
    )) {
      (null, _, _, _, _, _) => PhysicalRoutingStage.logicalConnection,
      (_, null, _, _, _, _) => PhysicalRoutingStage.cable,
      (_, _, null, _, _, _) => PhysicalRoutingStage.allocation,
      (_, _, _, false, _, _) => PhysicalRoutingStage.termination,
      (_, _, _, true, null, _) => PhysicalRoutingStage.route,
      (_, _, _, true, _, false) => PhysicalRoutingStage.carrier,
      _ => PhysicalRoutingStage.findings,
    };
    return PhysicalRoutingWorkspaceState(
      projectId: projectId,
      designContext: context,
      selectedConnectionId: selection.connectionId,
      selectedCableId: selection.cableId,
      selectedAllocationId: selection.allocationId,
      selectedCableRunId: selection.cableRunId,
      activeStage: stage,
      canEdit: context.editingAllowed &&
          context.workingDesignRevisionId != null &&
          selection.commandMutationsAllowed,
      blockingIssues: selection.blockingIssues,
    );
  }
}
