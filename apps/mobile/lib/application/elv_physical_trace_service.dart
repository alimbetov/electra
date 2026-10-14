import 'package:engineering_core/engineering_core.dart';

final class PhysicalTraceResult {
  const PhysicalTraceResult({
    required this.projectId,
    required this.designRevisionId,
    required this.connection,
    required this.terminations,
    required this.traversals,
    required this.carriers,
    required this.pathwayContexts,
    required this.findings,
    required this.calculations,
    this.cable,
    this.allocation,
    this.resourceSelection,
    this.run,
  });

  final String projectId;
  final String designRevisionId;
  final EngineeringConnection connection;
  final Cable? cable;
  final CableAllocation? allocation;
  final CableAllocationResourceSelectionEvidence? resourceSelection;
  final List<CableTerminationMapping> terminations;
  final CanonicalCableRun? run;
  final List<CableRunTraversal> traversals;
  final List<PhysicalCarrier> carriers;
  final List<PathwayContext> pathwayContexts;
  final List<PhysicalCompatibilityFinding> findings;
  final List<ElvPhysicalCalculationResult<Object?>> calculations;
}

abstract interface class ElvPhysicalTraceService {
  Future<PhysicalTraceResult> traceConnection(
    String projectId,
    String connectionId,
  );

  Future<PhysicalTraceResult> traceCable(String projectId, String cableId);
}
