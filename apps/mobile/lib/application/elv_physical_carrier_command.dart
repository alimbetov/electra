import 'package:engineering_core/engineering_core.dart';

final class CreatePhysicalCarrierCommand {
  const CreatePhysicalCarrierCommand({
    required this.commandId,
    required this.carrier,
  });
  final String commandId;
  final PhysicalCarrier carrier;
}

final class UpdatePhysicalCarrierCommand {
  const UpdatePhysicalCarrierCommand({
    required this.commandId,
    required this.carrier,
    required this.expectedRevision,
    required this.expectedImpactFingerprint,
  });
  final String commandId;
  final PhysicalCarrier carrier;
  final int expectedRevision;
  final String expectedImpactFingerprint;
}

final class ArchivePhysicalCarrierCommand {
  const ArchivePhysicalCarrierCommand({
    required this.commandId,
    required this.projectId,
    required this.carrierId,
    required this.expectedRevision,
  });
  final String commandId;
  final String projectId;
  final String carrierId;
  final int expectedRevision;
}

final class CreateCarrierCompartmentCommand {
  const CreateCarrierCompartmentCommand({
    required this.commandId,
    required this.projectId,
    required this.compartment,
  });
  final String commandId;
  final String projectId;
  final PhysicalCarrierCompartment compartment;
}

final class UpdateCarrierCompartmentCommand {
  const UpdateCarrierCompartmentCommand({
    required this.commandId,
    required this.projectId,
    required this.compartment,
    required this.expectedRevision,
    required this.expectedImpactFingerprint,
  });
  final String commandId;
  final String projectId;
  final PhysicalCarrierCompartment compartment;
  final int expectedRevision;
  final String expectedImpactFingerprint;
}

final class AttachTraversalToCarrierCommand {
  const AttachTraversalToCarrierCommand({
    required this.commandId,
    required this.projectId,
    required this.cableRunId,
    required this.traversalId,
    required this.carrierId,
    required this.expectedCableRunRevision,
    this.compartmentId,
  });
  final String commandId;
  final String projectId;
  final String cableRunId;
  final String traversalId;
  final String carrierId;
  final String? compartmentId;
  final int expectedCableRunRevision;
}
