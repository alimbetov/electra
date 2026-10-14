import 'package:engineering_core/engineering_core.dart';

enum PhysicalRoutingStage {
  logicalConnection,
  cable,
  allocation,
  termination,
  route,
  carrier,
  findings,
}

final class PhysicalRoutingBlockingIssue {
  const PhysicalRoutingBlockingIssue({
    required this.code,
    required this.message,
    this.entityId,
  });

  final String code;
  final String message;
  final String? entityId;
}

final class PhysicalRoutingWorkspaceState {
  const PhysicalRoutingWorkspaceState({
    required this.projectId,
    required this.designContext,
    required this.activeStage,
    required this.canEdit,
    this.selectedConnectionId,
    this.selectedCableId,
    this.selectedAllocationId,
    this.selectedCableRunId,
    this.blockingIssues = const [],
  });

  final String projectId;
  final PhysicalDesignContext designContext;
  final String? selectedConnectionId;
  final String? selectedCableId;
  final String? selectedAllocationId;
  final String? selectedCableRunId;
  final PhysicalRoutingStage activeStage;
  final bool canEdit;
  final List<PhysicalRoutingBlockingIssue> blockingIssues;

  bool get isReadOnly => !canEdit;

  PhysicalRoutingWorkspaceState copyWith({
    PhysicalRoutingStage? activeStage,
    String? selectedConnectionId,
    String? selectedCableId,
    String? selectedAllocationId,
    String? selectedCableRunId,
    bool? canEdit,
    List<PhysicalRoutingBlockingIssue>? blockingIssues,
  }) => PhysicalRoutingWorkspaceState(
    projectId: projectId,
    designContext: designContext,
    activeStage: activeStage ?? this.activeStage,
    canEdit: canEdit ?? this.canEdit,
    selectedConnectionId: selectedConnectionId ?? this.selectedConnectionId,
    selectedCableId: selectedCableId ?? this.selectedCableId,
    selectedAllocationId: selectedAllocationId ?? this.selectedAllocationId,
    selectedCableRunId: selectedCableRunId ?? this.selectedCableRunId,
    blockingIssues: blockingIssues ?? this.blockingIssues,
  );
}
