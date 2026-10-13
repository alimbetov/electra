import 'engineering_placement_command.dart';

enum EngineeringPlacementOperationStatus { completed, undone }

final class EngineeringPlacementOperationRecord {
  const EngineeringPlacementOperationRecord({
    required this.operationId,
    required this.projectId,
    required this.fingerprintVersion,
    required this.commandFingerprint,
    required this.status,
    required this.componentId,
    required this.result,
    required this.createdAt,
    required this.updatedAt,
    required this.originDeviceId,
  });

  final String operationId;
  final String projectId;
  final int fingerprintVersion;
  final String commandFingerprint;
  final EngineeringPlacementOperationStatus status;
  final String componentId;
  final EngineeringPlacementResult result;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String originDeviceId;
}

abstract interface class EngineeringPlacementRepository {
  Future<EngineeringPlacementResult> place(
    PlaceEngineeringProfileCommand command,
  );

  Future<EngineeringPlacementOperationRecord?> findOperation(
    String operationId,
  );
}
