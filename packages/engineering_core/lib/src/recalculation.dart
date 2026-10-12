enum EngineeringDerivedState {
  current,
  stale,
  recalculating,
  reviewRequired,
  validated,
  error,
}

enum EngineeringDependencyType {
  consumer,
  consumptionGroup,
  circuit,
  route,
  cable,
  protection,
  panel,
  ruleset,
  manufacturerCatalog,
}

class EngineeringDependencyRef {
  const EngineeringDependencyRef({
    required this.type,
    required this.entityId,
    required this.revision,
  });

  final EngineeringDependencyType type;
  final String entityId;
  final int revision;
}

class RecalculationImpact {
  const RecalculationImpact({
    required this.sourceEntityId,
    required this.affectedEntityIds,
    required this.reasonCodes,
  });

  final String sourceEntityId;
  final List<String> affectedEntityIds;
  final List<String> reasonCodes;

  bool affects(String entityId) => affectedEntityIds.contains(entityId);
}

class EngineeringDerivedRecord {
  const EngineeringDerivedRecord({
    required this.entityId,
    required this.state,
    required this.rulesetId,
    required this.rulesetVersion,
    required this.inputFingerprint,
    this.dependencies = const [],
    this.manualOverride = false,
  });

  final String entityId;
  final EngineeringDerivedState state;
  final String rulesetId;
  final String rulesetVersion;
  final String inputFingerprint;
  final List<EngineeringDependencyRef> dependencies;
  final bool manualOverride;

  bool dependsOn(String entityId) =>
      dependencies.any((dependency) => dependency.entityId == entityId);
}

class EngineeringChangeSummary {
  const EngineeringChangeSummary({
    required this.entityId,
    required this.reason,
    this.beforeValue,
    this.afterValue,
  });

  final String entityId;
  final String reason;
  final Object? beforeValue;
  final Object? afterValue;
}
