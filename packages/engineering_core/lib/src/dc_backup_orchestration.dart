import 'battery_backup_evaluation.dart';
import 'battery_backup_evidence.dart';
import 'dc_domain_evaluation.dart';
import 'dc_domain_evidence.dart';
import 'power_assets.dart';
import 'power_bottom_up_evaluation.dart';
import 'power_bottom_up_evidence.dart';
import 'power_catalog.dart';
import 'power_dc_backup.dart';
import 'power_evaluation.dart';
import 'power_interval_capability.dart';
import 'power_load_evaluation.dart';
import 'power_load_evidence.dart';
import 'power_numeric.dart';

final class DcTreePowerPipelineResult {
  const DcTreePowerPipelineResult({
    required this.domain,
    required this.domainEvidence,
    required this.parentDemand,
    required this.parentDemandEvidence,
    required this.capability,
    required this.capabilityEvidence,
  });

  final DcDomainEvaluationResult domain;
  final DcDomainEvaluationRecord domainEvidence;
  final PowerBottomUpEvaluationResult parentDemand;
  final PowerEvaluationEvidence parentDemandEvidence;
  final PowerCapabilityAssessment? capability;
  final PowerEvaluationEvidence? capabilityEvidence;
}

DcTreePowerPipelineResult evaluateDcTreeToCapabilityPipeline({
  required DcEvidenceContext context,
  required DcConstantCurrentDomainInput domainInput,
  required Iterable<DcSectionPhysicalEvidence> physicalEvidence,
  required Iterable<PowerEvaluationEvidence> loadDemandEvaluations,
  required Map<String, Object?> scenarioFacts,
  required String domainEvaluationId,
  required String parentDemandEvaluationId,
  required String capabilityEvaluationId,
  required String parentBoundaryRef,
  required String parentSubjectKind,
  required String parentSubjectId,
  required String capabilitySubjectKind,
  required String capabilitySubjectId,
  required PowerRational sourceNameplateW,
  PowerRational? reserveMultiplier,
  PowerRational? deratingFactor,
  Iterable<PowerDemandContribution> directContributions = const [],
  PowerOwnedTransfer? parentTransfer,
}) {
  final domain = evaluateDcDomain(domainInput);
  final domainEvidence = buildDcTreeEvaluationRecord(
    evaluationId: domainEvaluationId,
    context: context,
    input: domainInput,
    result: domain,
    physicalEvidence: physicalEvidence,
    loadDemandEvaluations: loadDemandEvaluations,
    scenarioFacts: scenarioFacts,
  );
  final tree = domain.treeResult!;
  final childBoundary = PowerBoundaryDemand(
    originId: context.domainId,
    boundaryRef: 'DC:${context.domainId}',
    sourceRef: 'PWR03:${domainEvidence.evaluation.evaluationId}',
    status: domainEvidence.evaluation.status,
    demandW: tree.sourceNominalW,
    sourceOutputW: tree.deliveredNominalW,
    accountedLossW: tree.totalLossW,
    accountingKeys: ['P6_DC_FEEDER_${_keyToken(context.domainId)}'],
    findings: domainEvidence.evaluation.findings,
  );
  final parentInput = PowerBottomUpEvaluationInput(
    boundaryRef: parentBoundaryRef,
    directContributions: directContributions,
    childBoundaries: [childBoundary],
    localTransfer: parentTransfer,
  );
  final parentDemand = evaluateBottomUpPowerBoundary(parentInput);
  final parentEvidence = buildBottomUpPowerDemandEvidence(
    evaluationId: parentDemandEvaluationId,
    revisionId: context.revisionId,
    scenarioId: context.scenarioId,
    segmentId: context.segmentId,
    subjectKind: parentSubjectKind,
    subjectId: parentSubjectId,
    input: parentInput,
    result: parentDemand,
    childEvaluations: [domainEvidence.evaluation],
  );

  final physicalDemandW = parentDemand.upstreamInputW;
  if (physicalDemandW == null) {
    return DcTreePowerPipelineResult(
      domain: domain,
      domainEvidence: domainEvidence,
      parentDemand: parentDemand,
      parentDemandEvidence: parentEvidence,
      capability: null,
      capabilityEvidence: null,
    );
  }
  final capabilityInput = PowerCapabilityDimension(
    dimension: PowerQuantityDimension.watt,
    demand: physicalDemandW,
    nameplate: sourceNameplateW,
    reserveMultiplier: reserveMultiplier ?? PowerRational.one,
    deratingFactor: deratingFactor ?? PowerRational.one,
  );
  final capability = evaluateSupplyCapability(capabilityInput);
  final capabilityEvidence = buildPowerCapabilityEvidence(
    evaluationId: capabilityEvaluationId,
    revisionId: context.revisionId,
    scenarioId: context.scenarioId,
    segmentId: context.segmentId,
    subjectKind: capabilitySubjectKind,
    subjectId: capabilitySubjectId,
    input: capabilityInput,
    assessment: capability,
    dependencies: [parentEvidence.nodeKey],
  );
  return DcTreePowerPipelineResult(
    domain: domain,
    domainEvidence: domainEvidence,
    parentDemand: parentDemand,
    parentDemandEvidence: parentEvidence,
    capability: capability,
    capabilityEvidence: capabilityEvidence,
  );
}

final class ConstantPowerCapabilityPipelineResult {
  const ConstantPowerCapabilityPipelineResult({
    required this.domain,
    required this.domainEvidence,
    required this.capability,
    required this.capabilityEvidence,
  });

  final DcDomainEvaluationResult domain;
  final DcDomainEvaluationRecord domainEvidence;
  final PowerIntervalCapabilityAssessment? capability;
  final PowerEvaluationEvidence? capabilityEvidence;
}

/// The CP source demand remains an interval. It deliberately bypasses the exact
/// PowerBoundaryDemand/PWR-01 aggregator instead of coercing an interval to a
/// false scalar. PWR-02 evaluates the preserved conservative bounds directly.
ConstantPowerCapabilityPipelineResult
    evaluateConstantPowerFeederToCapabilityPipeline({
  required DcEvidenceContext context,
  required DcSingleConstantPowerDomainInput domainInput,
  required DcSectionPhysicalEvidence physicalEvidence,
  required PowerEvaluationEvidence loadDemandEvaluation,
  required Map<String, Object?> scenarioFacts,
  required String domainEvaluationId,
  required String capabilityEvaluationId,
  required String capabilitySubjectKind,
  required String capabilitySubjectId,
  required PowerRational sourceNameplateW,
  PowerRational? reserveMultiplier,
  PowerRational? deratingFactor,
}) {
  final domain = evaluateDcDomain(domainInput);
  final domainEvidence = buildDcConstantPowerEvaluationRecord(
    evaluationId: domainEvaluationId,
    context: context,
    input: domainInput,
    result: domain,
    physicalEvidence: physicalEvidence,
    loadDemandEvaluation: loadDemandEvaluation,
    scenarioFacts: scenarioFacts,
  );
  final demand = domain.sourceDemandIntervalW;
  if (demand == null) {
    return ConstantPowerCapabilityPipelineResult(
      domain: domain,
      domainEvidence: domainEvidence,
      capability: null,
      capabilityEvidence: null,
    );
  }
  final input = PowerIntervalCapabilityInput(
    demandW: demand,
    nameplateW: sourceNameplateW,
    reserveMultiplier: reserveMultiplier,
    deratingFactor: deratingFactor,
  );
  final capability = evaluateIntervalPowerCapability(input);
  final capabilityEvidence = buildPowerIntervalCapabilityEvidence(
    evaluationId: capabilityEvaluationId,
    revisionId: context.revisionId,
    scenarioId: context.scenarioId,
    segmentId: context.segmentId,
    subjectKind: capabilitySubjectKind,
    subjectId: capabilitySubjectId,
    input: input,
    assessment: capability,
    dependencies: [domainEvidence.evaluation.nodeKey],
  );
  return ConstantPowerCapabilityPipelineResult(
    domain: domain,
    domainEvidence: domainEvidence,
    capability: capability,
    capabilityEvidence: capabilityEvidence,
  );
}

BatterySequenceEvaluationRecord evaluateBatterySequencePipeline({
  required String evaluationId,
  required BackupEvidenceContext context,
  required BatteryBankBinding bank,
  required BatteryWhAvailabilityModel availability,
  required Iterable<BackupEnergySegment> segments,
  required PowerExtensionPolicy extensionPolicy,
  required Iterable<PowerEvaluationEvidence> segmentDemandEvaluations,
}) {
  final sequence = segments.toList();
  final result = evaluateBatterySequenceForBank(
    bank: bank,
    segments: sequence,
    availability: availability,
    extensionPolicy: extensionPolicy,
  );
  return buildBatterySequenceEvaluationRecord(
    evaluationId: evaluationId,
    context: context,
    bank: bank,
    availability: availability,
    segments: sequence,
    extensionPolicy: extensionPolicy,
    result: result,
    segmentDemandEvaluations: segmentDemandEvaluations,
  );
}

final class ChargerPowerPipelineResult {
  const ChargerPowerPipelineResult({
    required this.charger,
    required this.chargerEvidence,
    required this.parentDemand,
    required this.parentDemandEvidence,
    required this.capability,
    required this.capabilityEvidence,
  });

  final ChargerBankEvaluation charger;
  final ChargerBoundaryEvaluationRecord chargerEvidence;
  final PowerBottomUpEvaluationResult parentDemand;
  final PowerEvaluationEvidence parentDemandEvidence;
  final PowerCapabilityAssessment capability;
  final PowerEvaluationEvidence capabilityEvidence;
}

ChargerPowerPipelineResult evaluateChargerToCapabilityPipeline({
  required ChargerEvidenceContext context,
  required PowerChargerDefinition charger,
  required BatteryBankBinding bank,
  required ChargerBankCompatibilityEvidence bankCompatibility,
  required PowerRational operatingOutputW,
  required PowerRational chargeVoltageV,
  required PowerRational selectedChargeCurrentA,
  required bool chargingSelected,
  required bool dischargingSelected,
  required PowerEvaluationEvidence operatingDemandEvaluation,
  required Map<String, Object?> scenarioFacts,
  required String chargerEvaluationId,
  required String parentDemandEvaluationId,
  required String capabilityEvaluationId,
  required String parentBoundaryRef,
  required String parentSubjectKind,
  required String parentSubjectId,
  required String capabilitySubjectKind,
  required String capabilitySubjectId,
  required PowerRational sourceNameplateW,
  PowerRational? reserveMultiplier,
  PowerRational? deratingFactor,
  Iterable<PowerDemandContribution> directContributions = const [],
}) {
  final chargerResult = evaluateChargerForBank(
    charger: charger,
    bank: bank,
    bankCompatibility: bankCompatibility,
    operatingOutputW: operatingOutputW,
    chargeVoltageV: chargeVoltageV,
    selectedChargeCurrentA: selectedChargeCurrentA,
    chargingSelected: chargingSelected,
    dischargingSelected: dischargingSelected,
  );
  final chargerEvidence = buildChargerBoundaryEvaluationRecord(
    evaluationId: chargerEvaluationId,
    context: context,
    charger: charger,
    bank: bank,
    bankCompatibility: bankCompatibility,
    operatingOutputW: operatingOutputW,
    chargeVoltageV: chargeVoltageV,
    selectedChargeCurrentA: selectedChargeCurrentA,
    chargingSelected: chargingSelected,
    dischargingSelected: dischargingSelected,
    result: chargerResult,
    operatingDemandEvaluation: operatingDemandEvaluation,
    scenarioFacts: scenarioFacts,
  );
  final raw = chargerResult.charger;
  final childBoundary = PowerBoundaryDemand(
    originId: context.chargerId,
    boundaryRef: 'CHARGER:${context.chargerId}',
    sourceRef: 'P6_CHARGER:${chargerEvidence.evaluation.evaluationId}',
    status: chargerEvidence.evaluation.status,
    demandW: raw.upstreamInputW,
    sourceOutputW: raw.combinedOutputW,
    accountedLossW: raw.upstreamInputW - raw.combinedOutputW,
    accountingKeys: ['P6_CHARGER_TRANSFER_${_keyToken(context.chargerId)}'],
    findings: chargerEvidence.evaluation.findings,
  );
  final parentInput = PowerBottomUpEvaluationInput(
    boundaryRef: parentBoundaryRef,
    directContributions: directContributions,
    childBoundaries: [childBoundary],
  );
  final parentDemand = evaluateBottomUpPowerBoundary(parentInput);
  final parentEvidence = buildBottomUpPowerDemandEvidence(
    evaluationId: parentDemandEvaluationId,
    revisionId: context.revisionId,
    scenarioId: context.scenarioId,
    segmentId: context.segmentId,
    subjectKind: parentSubjectKind,
    subjectId: parentSubjectId,
    input: parentInput,
    result: parentDemand,
    childEvaluations: [chargerEvidence.evaluation],
  );
  final capabilityInput = PowerCapabilityDimension(
    dimension: PowerQuantityDimension.watt,
    demand: parentDemand.upstreamInputW!,
    nameplate: sourceNameplateW,
    reserveMultiplier: reserveMultiplier ?? PowerRational.one,
    deratingFactor: deratingFactor ?? PowerRational.one,
  );
  final capability = evaluateSupplyCapability(capabilityInput);
  final capabilityEvidence = buildPowerCapabilityEvidence(
    evaluationId: capabilityEvaluationId,
    revisionId: context.revisionId,
    scenarioId: context.scenarioId,
    segmentId: context.segmentId,
    subjectKind: capabilitySubjectKind,
    subjectId: capabilitySubjectId,
    input: capabilityInput,
    assessment: capability,
    dependencies: [parentEvidence.nodeKey],
  );
  return ChargerPowerPipelineResult(
    charger: chargerResult,
    chargerEvidence: chargerEvidence,
    parentDemand: parentDemand,
    parentDemandEvidence: parentEvidence,
    capability: capability,
    capabilityEvidence: capabilityEvidence,
  );
}

String _keyToken(String value) =>
    value.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9_-]+'), '_');
