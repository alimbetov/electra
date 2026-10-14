import 'package:engineering_core/engineering_core.dart';

import 'elv_command_result.dart';
import 'elv_physical_carrier_command.dart';

final class CarrierImpactPreview {
  const CarrierImpactPreview({
    required this.affectedCableRunIds,
    required this.impactFingerprint,
  });

  final List<String> affectedCableRunIds;
  final String impactFingerprint;
}

abstract interface class ElvPhysicalCarrierRepository {
  Future<List<PhysicalCarrier>> loadCarriers(String projectId);
  Future<List<PhysicalCarrierCompartment>> loadCompartments(String carrierId);
  Future<CarrierImpactPreview> previewCarrierImpact(
    String projectId,
    String carrierId,
  );

  Future<ElvCommandResult<PhysicalCarrier>> create(
    CreatePhysicalCarrierCommand command,
  );

  Future<ElvCommandResult<PhysicalCarrier>> update(
    UpdatePhysicalCarrierCommand command,
  );

  Future<ElvCommandResult<void>> archive(ArchivePhysicalCarrierCommand command);

  Future<ElvCommandResult<PhysicalCarrierCompartment>> createCompartment(
    CreateCarrierCompartmentCommand command,
  );

  Future<ElvCommandResult<PhysicalCarrierCompartment>> updateCompartment(
    UpdateCarrierCompartmentCommand command,
  );

  Future<ElvCommandResult<CanonicalCableRun>> attachTraversal(
    AttachTraversalToCarrierCommand command,
  );
}
