import 'elv_command_result.dart';
import 'elv_physical_routing_workspace_state.dart';
import 'elv_physical_trace_service.dart';

abstract interface class ElvWorkspaceCommand {
  String get commandId;
  String get projectId;
}

/// Narrow public mutation boundary shared by ELV editor workspaces.
///
/// The complete physical-routing workspace remains available below. Consumers
/// that only commit already-reviewed commands do not need to depend on trace or
/// read-model capabilities they never call.
abstract interface class ElvWorkspaceCommandService {
  Future<ElvCommandResult<Object?>> execute(ElvWorkspaceCommand command);
}

abstract interface class ElvPhysicalRoutingWorkspaceService
    implements ElvWorkspaceCommandService {
  Future<PhysicalRoutingWorkspaceState> load({
    required String projectId,
    String? connectionId,
  });

  Stream<PhysicalRoutingWorkspaceState> watch(String projectId);

  Future<PhysicalTraceResult> traceConnection(
    String projectId,
    String connectionId,
  );

  Future<PhysicalTraceResult> traceCable(String projectId, String cableId);
}

enum ElvCommandUndoClass { reversible, irreversibleHistory }

abstract interface class ElvCommandHistoryService {
  Future<bool> canUndo(String projectId);
  Future<bool> canRedo(String projectId);
  Future<ElvCommandResult<Object?>> undo(String projectId);
  Future<ElvCommandResult<Object?>> redo(String projectId);
}
