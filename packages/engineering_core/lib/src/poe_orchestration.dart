import 'poe_evaluation.dart';
import 'poe_evidence.dart';
import 'power_bottom_up_evaluation.dart';
import 'power_bottom_up_evidence.dart';
import 'power_evaluation.dart';
import 'power_load_evaluation.dart';
import 'power_load_evidence.dart';
import 'power_numeric.dart';

/// Pure-core P5 integration slice.
///
/// The dependency direction is intentionally acyclic:
/// leaf PWR-01 -> PWR-06 -> parent PWR-01 -> PWR-02.
/// PSE conversion/idle is owned by PWR-06. Reserve and derating are owned only
/// by PWR-02 and never mutate the physical parent demand.
final class PoePowerPipelineResult {
  const PoePowerPipelineResult({
    required this.poeResult,
    required this.poeEvidence,
    required this.parentDemand,
    required this.parentDemandEvidence,
    required this.capability,
    required this.capabilityEvidence,
  });

  final PoeEvaluationResult poeResult;
  final PoeEvaluationRecord poeEvidence;
  final PowerBottomUpEvaluationResult parentDemand;
  final PowerEvaluationEvidence parentDemandEvidence;
  final PowerCapabilityAssessment? capability;
  final PowerEvaluationEvidence? capabilityEvidence;

  bool get capabilityResolved => capability != null;
}

PoePowerPipelineResult evaluatePoeToCapabilityPipeline({
  required PoeEvidenceContext context,
  required PoeEvaluationInput poeInput,
  required PowerEvaluationEvidence pdDemandEvaluation,
  required Map<String, Object?> scenarioFacts,
  required String poeEvaluationId,
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
  final poeResult = evaluatePoeDelivery(poeInput);
  final poeEvidence = buildPoeEvaluationRecord(
    evaluationId: poeEvaluationId,
    context: context,
    input: poeInput,
    result: poeResult,
    pdDemandEvaluation: pdDemandEvaluation,
    scenarioFacts: scenarioFacts,
  );

  final groupBoundary = poeUpstreamBoundary(
    groupId: context.groupId,
    input: poeInput,
    result: poeResult,
  );
  final parentInput = PowerBottomUpEvaluationInput(
    boundaryRef: parentBoundaryRef,
    directContributions: directContributions,
    childBoundaries: [groupBoundary],
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
    childEvaluations: [poeEvidence.evaluation],
  );

  final physicalDemandW = parentDemand.upstreamInputW;
  if (physicalDemandW == null) {
    return PoePowerPipelineResult(
      poeResult: poeResult,
      poeEvidence: poeEvidence,
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

  return PoePowerPipelineResult(
    poeResult: poeResult,
    poeEvidence: poeEvidence,
    parentDemand: parentDemand,
    parentDemandEvidence: parentEvidence,
    capability: capability,
    capabilityEvidence: capabilityEvidence,
  );
}
