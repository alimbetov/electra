import 'package:engineering_core/engineering_core.dart';

final class CreateCableAllocationDraftCommand {
  const CreateCableAllocationDraftCommand({
    required this.commandId,
    required this.projectId,
    required this.allocationId,
    required this.engineeringConnectionId,
    required this.cableId,
    this.transitionRef,
  });

  final String commandId;
  final String projectId;
  final String allocationId;
  final String engineeringConnectionId;
  final String cableId;
  final String? transitionRef;

  Map<String, Object?> normalizedPayload() => {
    'projectId': projectId.trim(),
    'allocationId': allocationId.trim(),
    'engineeringConnectionId': engineeringConnectionId.trim(),
    'cableId': cableId.trim(),
    'transitionRef': transitionRef?.trim(),
  };
}

final class ReserveCableResourcesCommand {
  const ReserveCableResourcesCommand({
    required this.commandId,
    required this.projectId,
    required this.allocationId,
    required this.expectedRevision,
    required this.selection,
  });

  final String commandId;
  final String projectId;
  final String allocationId;
  final int expectedRevision;
  final CableResourceSelection selection;

  Map<String, Object?> normalizedPayload() => {
    'projectId': projectId.trim(),
    'allocationId': allocationId.trim(),
    'expectedRevision': expectedRevision,
    'selection': selection.toMap(),
  };
}

final class ReplaceCableTerminationSetCommand {
  const ReplaceCableTerminationSetCommand({
    required this.commandId,
    required this.projectId,
    required this.allocationId,
    required this.expectedRevision,
    required this.completeMappings,
  });

  final String commandId;
  final String projectId;
  final String allocationId;
  final int expectedRevision;
  final List<CableTerminationMapping> completeMappings;

  Map<String, Object?> normalizedPayload() => {
    'projectId': projectId.trim(),
    'allocationId': allocationId.trim(),
    'expectedRevision': expectedRevision,
    'completeMappings': completeMappings
        .map(
          (mapping) => {
            'id': mapping.id.trim(),
            'resourceIdentity': mapping.resourceIdentity,
            'end': mapping.end.name,
            'endpointPortId': mapping.endpointPortId.trim(),
            'endpointTerminalRef': mapping.endpointTerminalRef,
            'terminationRole': mapping.terminationRole,
          },
        )
        .toList(growable: false),
  };
}

final class ActivateCableAllocationCommand {
  const ActivateCableAllocationCommand({
    required this.commandId,
    required this.projectId,
    required this.allocationId,
    required this.expectedRevision,
  });

  final String commandId;
  final String projectId;
  final String allocationId;
  final int expectedRevision;

  Map<String, Object?> normalizedPayload() => {
    'projectId': projectId.trim(),
    'allocationId': allocationId.trim(),
    'expectedRevision': expectedRevision,
  };
}

final class ReleaseCableResourcesCommand {
  const ReleaseCableResourcesCommand({
    required this.commandId,
    required this.projectId,
    required this.allocationId,
    required this.expectedRevision,
  });

  final String commandId;
  final String projectId;
  final String allocationId;
  final int expectedRevision;

  Map<String, Object?> normalizedPayload() => {
    'projectId': projectId.trim(),
    'allocationId': allocationId.trim(),
    'expectedRevision': expectedRevision,
  };
}

final class ArchiveCableAllocationCommand {
  const ArchiveCableAllocationCommand({
    required this.commandId,
    required this.projectId,
    required this.allocationId,
    required this.expectedRevision,
  });

  final String commandId;
  final String projectId;
  final String allocationId;
  final int expectedRevision;

  Map<String, Object?> normalizedPayload() => {
    'projectId': projectId.trim(),
    'allocationId': allocationId.trim(),
    'expectedRevision': expectedRevision,
  };
}
