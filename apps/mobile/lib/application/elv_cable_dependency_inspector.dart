abstract interface class ElvCableDependencyInspector {
  Future<bool> hasResourceSelectionHistory(String projectId, String cableId);
  Future<bool> hasConsumingAllocation(String projectId, String cableId);
  Future<bool> hasCanonicalRunHistory(String projectId, String cableId);
  Future<List<String>> blockingDependencyIds(String projectId, String cableId);
}
