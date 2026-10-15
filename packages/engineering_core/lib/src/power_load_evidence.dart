import 'engineering_hash.dart';
import 'power_evaluation.dart';
import 'power_load_evaluation.dart';

const powerDemandEvidenceAlgorithmVersion = 'elv4-pwr01-demand-v1';
const powerCapabilityEvidenceAlgorithmVersion = 'elv4-pwr02-capability-v1';

PowerEvaluationEvidence buildPowerDemandEvidence({
  required String evaluationId,
  required String revisionId,
  required String scenarioId,
  required String segmentId,
  required String subjectKind,
  required String subjectId,
  required AggregatedPowerDemand demand,
}) {
  final contributionMaps = demand.contributions
      .map((value) => value.source.toMap())
      .toList(growable: false);
  final inputs = <String, Object?>{
    'schema': 'electra.elv4-pwr01-input.v1',
    'contributions': contributionMaps,
  };
  final output = <String, Object?>{
    'knownW': demand.knownW.toMap(),
    'knownA': demand.knownA.toMap(),
    'knownVa': demand.knownVa.toMap(),
    'completeW': demand.completeW,
    'completeA': demand.completeA,
    'completeVa': demand.completeVa,
    'unresolvedOriginIds': demand.unresolvedOriginIds,
  };

  return PowerEvaluationEvidence(
    evaluationId: evaluationId,
    nodeKey: PowerNodeKeyV2(
      revisionId: revisionId,
      scenarioId: scenarioId,
      scopeKind: PowerEvaluationScopeKind.segment,
      scopeId: segmentId,
      processCode: PowerProcessCode.pwr01,
      subjectKind: subjectKind,
      subjectId: subjectId,
    ),
    algorithmVersion: powerDemandEvidenceAlgorithmVersion,
    inputSchemaVersion: 'electra.elv4-pwr01-input.v1',
    outputSchemaVersion: 'electra.elv4-pwr01-output.v1',
    inputFingerprint: sha256HexUtf8(canonicalEngineeringJsonV1(inputs)),
    status: demand.unresolvedOriginIds.isEmpty
        ? PowerEvaluationStatus.pass
        : PowerEvaluationStatus.unresolved,
    applicability: PowerEvaluationApplicability.applicable,
    inputs: inputs,
    output: output,
    arithmeticSteps: demand.arithmeticSteps.map((value) => value.toMap()),
    findings: [
      if (demand.unresolvedOriginIds.isNotEmpty)
        PowerEvaluationFinding(
          code: 'ELV4_POWER_DEMAND_INCOMPLETE',
          severity: 'UNRESOLVED',
          message: 'Power demand retains unresolved contribution dimensions.',
          sourceRefs: demand.unresolvedOriginIds,
        ),
    ],
  );
}

PowerEvaluationEvidence buildPowerCapabilityEvidence({
  required String evaluationId,
  required String revisionId,
  required String scenarioId,
  required String segmentId,
  required String subjectKind,
  required String subjectId,
  required PowerCapabilityDimension input,
  required PowerCapabilityAssessment assessment,
}) {
  if (input.dimension != assessment.dimension ||
      input.demand != assessment.physicalDemand) {
    throw ArgumentError(
      'Capability evidence input must match the evaluated assessment.',
    );
  }

  final inputs = <String, Object?>{
    'schema': 'electra.elv4-pwr02-input.v1',
    'dimension': input.dimension.name.toUpperCase(),
    'demand': input.demand.toMap(),
    'nameplate': input.nameplate.toMap(),
    'reserveMultiplier': input.reserveMultiplier.toMap(),
    'deratingFactor': input.deratingFactor.toMap(),
  };
  final output = <String, Object?>{
    'required': assessment.required.toMap(),
    'available': assessment.available.toMap(),
    'margin': assessment.margin.toMap(),
    'utilization': assessment.utilization?.toMap(),
    'zeroCapacity': assessment.zeroCapacity,
    'dimensionStatus': assessment.status.name.toUpperCase(),
  };

  final status = switch (assessment.status) {
    PowerDimensionStatus.pass => PowerEvaluationStatus.pass,
    PowerDimensionStatus.fail => PowerEvaluationStatus.fail,
    PowerDimensionStatus.unresolved => PowerEvaluationStatus.unresolved,
  };

  return PowerEvaluationEvidence(
    evaluationId: evaluationId,
    nodeKey: PowerNodeKeyV2(
      revisionId: revisionId,
      scenarioId: scenarioId,
      scopeKind: PowerEvaluationScopeKind.segment,
      scopeId: segmentId,
      processCode: PowerProcessCode.pwr02,
      subjectKind: subjectKind,
      subjectId: subjectId,
    ),
    algorithmVersion: powerCapabilityEvidenceAlgorithmVersion,
    inputSchemaVersion: 'electra.elv4-pwr02-input.v1',
    outputSchemaVersion: 'electra.elv4-pwr02-output.v1',
    inputFingerprint: sha256HexUtf8(canonicalEngineeringJsonV1(inputs)),
    status: status,
    applicability: PowerEvaluationApplicability.applicable,
    inputs: inputs,
    output: output,
    findings: [
      if (assessment.zeroCapacity)
        PowerEvaluationFinding(
          code: 'ELV4_POWER_ZERO_AVAILABLE_CAPACITY',
          severity: 'ERROR',
          message: 'Available capability is zero; utilization is undefined.',
        ),
      if (assessment.status == PowerDimensionStatus.fail)
        PowerEvaluationFinding(
          code: 'ELV4_POWER_CAPABILITY_EXCEEDED',
          severity: 'ERROR',
          message: 'Required capability exceeds derated available capability.',
        ),
    ],
  );
}
