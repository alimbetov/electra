import 'elv_command_result.dart';
import 'elv_physical_routing_workspace_state.dart';
import 'elv_physical_trace_service.dart';

abstract interface class ElvWorkspaceCommand {
  String get commandId;
  String get projectId;
}

abstract interface class ElvPhysicalRoutingWorkspaceService {
  Future<PhysicalRoutingWorkspaceState> load({
    required String projectId,
    String? connectionId,
  });

  Stream<PhysicalRoutingWorkspaceState> watch(String projectId);

  Future<ElvCommandResult<Object?>> execute(ElvWorkspaceCommand command);

  Future<PhysicalTraceResult> traceConnection(
    String projectId,
    String connectionId,
  );

  Future<PhysicalTraceResult> traceCable(
    String projectId,
    String cableId,
  );
}

enum ElvCommandUndoClass { reversible, irreversibleHistory }

abstract interface class ElvCommandHistoryService {
  Future<bool> canUndo(String projectId);
  Future<bool> canRedo(String projectId);
  Future<ElvCommandResult<Object?>> undo(String projectId);
  Future<ElvCommandResult<Object?>> redo(String projectId);
}
