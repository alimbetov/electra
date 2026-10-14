import 'package:engineering_core/engineering_core.dart';

abstract interface class ElvCableAllocationRepository {
  Future<CableAllocation?> findAllocation(String projectId, String allocationId);
  Future<List<CableAllocation>> loadCableAllocations(String projectId, String cableId);
  Future<CableAllocationResourceSelectionEvidence?> loadSelectionEvidence(
    String projectId,
    String allocationId,
  );
  Future<List<CableTerminationMapping>> loadTerminationMappings(
    String projectId,
    String allocationId,
  );
}

final class ElvConnectionEndpoints {
  const ElvConnectionEndpoints({
    required this.connectionId,
    required this.projectId,
    required this.fromPortId,
    required this.toPortId,
    required this.wired,
  });

  final String connectionId;
  final String projectId;
  final String fromPortId;
  final String toPortId;
  final bool wired;
}
