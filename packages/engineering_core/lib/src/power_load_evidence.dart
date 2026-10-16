import 'engineering_hash.dart';
import 'power_evaluation.dart';
import 'power_load_evaluation.dart';
import 'power_numeric.dart';
import 'power_profiles.dart';

const powerDemandEvidenceAlgorithmVersion = 'elv4-pwr01-demand-v1';
const powerCapabilityEvidenceAlgorithmVersion = 'elv4-pwr02-capability-v1';
const powerUpsEvidenceAlgorithmVersion = 'elv4-pwr05-ups-v1';

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
  final unresolvedWOriginIds = demand.contributions
      .where((value) => value.watt == null)
      .map((value) => value.source.originId)
      .toList(growable: false)
    ..sort();
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
    'unresolvedWOriginIds': unresolvedWOriginIds,
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
    status: demand.completeW
        ? PowerEvaluationStatus.pass
        : PowerEvaluationStatus.unresolved,
    applicability: PowerEvaluationApplicability.applicable,
    inputs: inputs,
    output: output,
    arithmeticSteps: demand.arithmeticSteps.map((value) => value.toMap()),
    findings: [
      if (!demand.completeW)
        PowerEvaluationFinding(
          code: 'ELV4_POWER_DEMAND_INCOMPLETE',
          severity: 'UNRESOLVED',
          message: 'Power demand retains unresolved watt contributions.',
          sourceRefs: unresolvedWOriginIds,
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
  Iterable<PowerNodeKeyV2> dependencies = const [],
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
    dependencies: dependencies,
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

/// Evaluates and records the canonical PWR-05 UPS loading result.
///
/// The evidence is generated from [evaluateUpsLoading] itself so qualification
/// cannot supply independent W/VA/input-demand PASS values. Missing input power
/// factor remains an explicit UNRESOLVED result rather than being inferred.
PowerEvaluationEvidence buildUpsLoadingEvidence({
  required String evaluationId,
  required String revisionId,
  required String scenarioId,
  required String segmentId,
  required String upsId,
  required PowerRational protectedOutputW,
  required PowerRational protectedOutputVa,
  required PowerRational ratedOutputW,
  required PowerRational ratedOutputVa,
  required PowerLossDefinition transferLoss,
  PowerRational? reserveMultiplier,
  PowerRational? deratingFactor,
  required PowerRational inputPowerFactor,
  Iterable<PowerNodeKeyV2> dependencies = const [],
}) {
  final effectiveReserve = reserveMultiplier ?? PowerRational.one;
  final effectiveDerating = deratingFactor ?? PowerRational.one;
  final inputs = <String, Object?>{
    'schema': 'electra.elv4-pwr05-input.v1',
    'protectedOutputW': protectedOutputW.toMap(),
    'protectedOutputVa': protectedOutputVa.toMap(),
    'ratedOutputW': ratedOutputW.toMap(),
    'ratedOutputVa': ratedOutputVa.toMap(),
    'reserveMultiplier': effectiveReserve.toMap(),
    'deratingFactor': effectiveDerating.toMap(),
    'inputPowerFactor': inputPowerFactor.toMap(),
    'transferLoss': transferLoss.toMap(),
  };
  final result = evaluateUpsLoading(
    protectedOutputW: protectedOutputW,
    protectedOutputVa: protectedOutputVa,
    ratedOutputW: ratedOutputW,
    ratedOutputVa: ratedOutputVa,
    transferLoss: transferLoss,
    reserveMultiplier: effectiveReserve,
    deratingFactor: effectiveDerating,
    inputPowerFactor: inputPowerFactor,
  );
  final output = <String, Object?>{
    'outputW': _capabilityAssessmentMap(result.watt),
    'outputVa': _capabilityAssessmentMap(result.voltAmpere),
    'inputW': result.inputW.toMap(),
    'inputVa': result.inputVa?.toMap(),
  };

  return PowerEvaluationEvidence(
    evaluationId: evaluationId,
    nodeKey: PowerNodeKeyV2(
      revisionId: revisionId,
      scenarioId: scenarioId,
      scopeKind: PowerEvaluationScopeKind.segment,
      scopeId: segmentId,
      processCode: PowerProcessCode.pwr05,
      subjectKind: 'UPS',
      subjectId: upsId,
    ),
    algorithmVersion: powerUpsEvidenceAlgorithmVersion,
    inputSchemaVersion: 'electra.elv4-pwr05-input.v1',
    outputSchemaVersion: 'electra.elv4-pwr05-output.v1',
    inputFingerprint: sha256HexUtf8(canonicalEngineeringJsonV1(inputs)),
    status: result.status,
    applicability: PowerEvaluationApplicability.applicable,
    inputs: inputs,
    output: output,
    dependencies: dependencies,
    quantities: [
      {'code': 'PROTECTED_OUTPUT_W', 'value': protectedOutputW.toMap()},
      {'code': 'PROTECTED_OUTPUT_VA', 'value': protectedOutputVa.toMap()},
      {'code': 'UPS_INPUT_W', 'value': result.inputW.toMap()},
      if (result.inputVa != null)
        {'code': 'UPS_INPUT_VA', 'value': result.inputVa!.toMap()},
    ],
    arithmeticSteps: evaluateTransferInputDemand(
      transferId: 'UPS:$upsId',
      deliveredOutputW: protectedOutputW,
      loss: transferLoss,
    ).steps.map((value) => value.toMap()),
    findings: [
      if (result.watt.status == PowerDimensionStatus.fail)
        PowerEvaluationFinding(
          code: 'ELV4_UPS_OUTPUT_W_EXCEEDED',
          severity: 'ERROR',
          message: 'Protected watt demand exceeds derated UPS output.',
        ),
      if (result.voltAmpere.status == PowerDimensionStatus.fail)
        PowerEvaluationFinding(
          code: 'ELV4_UPS_OUTPUT_VA_EXCEEDED',
          severity: 'ERROR',
          message: 'Protected VA demand exceeds derated UPS output.',
        ),
    ],
  );
}

Map<String, Object?> _capabilityAssessmentMap(
  PowerCapabilityAssessment value,
) =>
    {
      'dimension': value.dimension.name.toUpperCase(),
      'status': value.status.name.toUpperCase(),
      'physicalDemand': value.physicalDemand.toMap(),
      'required': value.required.toMap(),
      'available': value.available.toMap(),
      'margin': value.margin.toMap(),
      'utilization': value.utilization?.toMap(),
      'zeroCapacity': value.zeroCapacity,
    };
