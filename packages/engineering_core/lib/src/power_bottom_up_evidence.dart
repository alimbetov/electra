import 'engineering_hash.dart';
import 'power_bottom_up_evaluation.dart';
import 'power_evaluation.dart';

const bottomUpDemandEvidenceAlgorithmVersion = 'elv4-pwr01-bottom-up-v1';

PowerEvaluationEvidence buildBottomUpPowerDemandEvidence({
  required String evaluationId,
  required String revisionId,
  required String scenarioId,
  required String segmentId,
  required String subjectKind,
  required String subjectId,
  required PowerBottomUpEvaluationInput input,
  required PowerBottomUpEvaluationResult result,
  Iterable<PowerEvaluationEvidence> childEvaluations = const [],
}) {
  if (input.boundaryRef != result.boundaryRef) {
    throw ArgumentError('Bottom-up evidence input/result boundary mismatch.');
  }

  final direct = input.directContributions.toList()
    ..sort((a, b) => a.originId.compareTo(b.originId));
  final children = input.childBoundaries.toList()
    ..sort((a, b) => a.originId.compareTo(b.originId));
  final dependencies = childEvaluations.toList()
    ..sort((a, b) => a.nodeKey.compareTo(b.nodeKey));

  final inputs = <String, Object?>{
    'schema': 'electra.elv4-pwr01-bottom-up-input.v1',
    'boundaryRef': input.boundaryRef,
    'directContributions':
        direct.map((value) => value.toMap()).toList(growable: false),
    'childBoundaries': children.map(_boundaryMap).toList(growable: false),
    'localTransfer': input.localTransfer == null
        ? null
        : {
            'transferId': input.localTransfer!.transferId,
            'accountingKey': input.localTransfer!.accountingKey,
            'loss': input.localTransfer!.loss.toMap(),
          },
    'consumedEvaluations': dependencies
        .map(
          (value) => {
            'logicalNodeKey': value.nodeKey.encode(),
            'evaluationId': value.evaluationId,
            'inputFingerprint': value.inputFingerprint,
          },
        )
        .toList(growable: false),
  };

  final completeW = result.upstreamInputW != null;
  final output = <String, Object?>{
    'knownBoundaryOutputW': result.outputDemandW.toMap(),
    'knownW': result.upstreamInputW?.toMap(),
    'completeW': completeW,
    'localLossW': result.localLossW?.toMap(),
    'accountingKeys': result.accountingKeys,
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
    algorithmVersion: bottomUpDemandEvidenceAlgorithmVersion,
    inputSchemaVersion: 'electra.elv4-pwr01-bottom-up-input.v1',
    outputSchemaVersion: 'electra.elv4-pwr01-bottom-up-output.v1',
    inputFingerprint: sha256HexUtf8(canonicalEngineeringJsonV1(inputs)),
    status: result.status,
    applicability: PowerEvaluationApplicability.applicable,
    inputs: inputs,
    output: output,
    dependencies: dependencies.map((value) => value.nodeKey),
    quantities: [
      {'code': 'BOUNDARY_OUTPUT_W', 'value': result.outputDemandW.toMap()},
      if (result.upstreamInputW != null)
        {'code': 'UPSTREAM_INPUT_W', 'value': result.upstreamInputW!.toMap()},
      if (result.localLossW != null)
        {'code': 'LOCAL_LOSS_W', 'value': result.localLossW!.toMap()},
    ],
    arithmeticSteps: result.arithmeticSteps.map((value) => value.toMap()),
    findings: result.findings,
  );
}

Map<String, Object?> _boundaryMap(PowerBoundaryDemand value) => {
      'originId': value.originId,
      'boundaryRef': value.boundaryRef,
      'sourceRef': value.sourceRef,
      'status': value.status.name.toUpperCase(),
      'demandW': value.demandW?.toMap(),
      'sourceOutputW': value.sourceOutputW?.toMap(),
      'accountedLossW': value.accountedLossW?.toMap(),
      'accountingKeys': value.accountingKeys,
      'findings': value.findings.map((finding) => finding.toMap()).toList(),
    };
