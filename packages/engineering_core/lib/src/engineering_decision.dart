enum EngineeringDecisionStatus {
  proposed,
  userConfirmed,
  manuallyModified,
  validated,
}

class ElectricalRulesetRef {
  const ElectricalRulesetRef({
    required this.id,
    required this.jurisdiction,
    required this.standardCode,
    required this.version,
    this.sourceReference,
  });

  final String id;
  final String jurisdiction;
  final String standardCode;
  final String version;
  final String? sourceReference;
}

class EngineeringDecision {
  const EngineeringDecision({
    required this.id,
    required this.decisionType,
    required this.subjectId,
    required this.result,
    required this.ruleset,
    required this.calculationVersion,
    this.status = EngineeringDecisionStatus.proposed,
    this.inputs = const {},
    this.reasons = const [],
    this.warnings = const [],
    this.overrideReason,
  });

  final String id;
  final String decisionType;
  final String subjectId;
  final String result;
  final ElectricalRulesetRef ruleset;
  final String calculationVersion;
  final EngineeringDecisionStatus status;
  final Map<String, Object?> inputs;
  final List<String> reasons;
  final List<String> warnings;
  final String? overrideReason;

  bool get isExplainable =>
      reasons.isNotEmpty &&
      ruleset.standardCode.isNotEmpty &&
      ruleset.version.isNotEmpty;
}
