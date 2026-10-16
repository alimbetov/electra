import 'engineering_hash.dart';
import 'poe_evaluation.dart';
import 'power_dependency.dart';
import 'power_evaluation.dart';
import 'power_load_evaluation.dart';
import 'power_numeric.dart';

const poeEvidenceAlgorithmVersion = 'elv4-pwr06-poe-v1';
const poeEvidenceInputSchemaVersion = 'electra.elv4-pwr06-input.v1';
const poeEvidenceOutputSchemaVersion = 'electra.elv4-pwr06-output.v1';

final class PoeEvidenceContext {
  PoeEvidenceContext({
    required String projectId,
    required String revisionId,
    required String scenarioId,
    required String segmentId,
    required String groupId,
  })  : projectId = _text(projectId, 'projectId'),
        revisionId = _text(revisionId, 'revisionId'),
        scenarioId = _text(scenarioId, 'scenarioId'),
        segmentId = _text(segmentId, 'segmentId'),
        groupId = _text(groupId, 'groupId');

  final String projectId;
  final String revisionId;
  final String scenarioId;
  final String segmentId;
  final String groupId;
}

/// Complete persisted-facing PWR-06 record.
///
/// [evaluation] remains the shared process evidence shape. Typed dependency
/// keys and exact consumed facts are carried beside it so RM13/P5-T08 can be
/// reopened and invalidated without reconstructing dependencies from UI labels.
final class PoeEvaluationRecord {
  PoeEvaluationRecord({
    required this.evaluation,
    required this.consumedInput,
  }) {
    if (evaluation.nodeKey.processCode != PowerProcessCode.pwr06) {
      throw ArgumentError('PoE evidence record requires a PWR-06 evaluation.');
    }
    if (evaluation.inputFingerprint != consumedInput.inputFingerprint) {
      throw ArgumentError(
        'PoE evaluation fingerprint must equal its consumed-input fingerprint.',
      );
    }
  }

  final PowerEvaluationEvidence evaluation;
  final PowerConsumedInput consumedInput;

  Map<String, Object?> toMap() => {
        ...evaluation.toMap(),
        'dependencyKeys': consumedInput.dependencyKeys,
        'consumedFacts':
            consumedInput.facts.map((value) => value.toMap()).toList(),
        'consumedEvaluations':
            consumedInput.evaluations.map((value) => value.toMap()).toList(),
      };

  String get canonicalJson => canonicalEngineeringJsonV1(toMap());
  String get evidenceSha256 => sha256HexUtf8(canonicalJson);

  PowerConsumedInputDiff diff(PoeEvaluationRecord previous) =>
      consumedInput.diff(previous.consumedInput);
}

PowerConsumedInput buildPoeConsumedInput({
  required PoeEvidenceContext context,
  required PoeEvaluationInput input,
  required PowerEvaluationEvidence pdDemandEvaluation,
  required Map<String, Object?> scenarioFacts,
}) {
  _validatePdDemandDependency(
    context: context,
    input: input,
    pdDemandEvaluation: pdDemandEvaluation,
  );

  final facts = <PowerConsumedFact>[
    PowerConsumedFact.present(
      key: _key(
        context,
        kind: PowerDependencyKind.definition,
        entityId: input.definition.definitionRef.definitionCode,
        purpose: 'POE_PROFILE',
      ),
      valueSchema: 'electra.elv4.poe-definition.v1',
      value: input.definition.toMap(),
    ),
    PowerConsumedFact.present(
      key: _key(
        context,
        kind: PowerDependencyKind.poeDelivery,
        entityId: input.deliveryId,
        purpose: 'POE_BINDING',
      ),
      valueSchema: 'electra.elv4.poe-binding.v1',
      value: {
        'deliveryId': input.deliveryId,
        'groupId': context.groupId,
        'accountingMode': input.accountingMode.name.toUpperCase(),
        'groupInputBasis': input.groupInputBasis.name.toUpperCase(),
        'pdDemandW': input.pdDemandW.toMap(),
        'reservedPseW': input.reservedPseW.toMap(),
        'portAllocationLimitW': input.portAllocationLimitW.toMap(),
        'pseRoleConfirmed': input.pseRoleConfirmed,
        'pdRoleConfirmed': input.pdRoleConfirmed,
        'midspan': _midspanMap(input.midspan),
      },
    ),
    PowerConsumedFact.present(
      key: _key(
        context,
        kind: PowerDependencyKind.capacityGroup,
        entityId: context.groupId,
        purpose: 'POE_CAPACITY',
      ),
      valueSchema: 'electra.elv4.poe-capacity.v1',
      value: {
        'sharedGroupBudgetW': input.sharedGroupBudgetW.toMap(),
        'groupInputBasis': input.groupInputBasis.name.toUpperCase(),
      },
    ),
    PowerConsumedFact.present(
      key: _key(
        context,
        kind: PowerDependencyKind.groupMembership,
        entityId: context.groupId,
        purpose: 'POE_MEMBERSHIP',
      ),
      valueSchema: 'electra.elv4.poe-membership.v1',
      value: _canonicalReservations(input),
    ),
    PowerConsumedFact.present(
      key: _key(
        context,
        kind: PowerDependencyKind.transferLoss,
        entityId: context.groupId,
        purpose: 'PSE_TRANSFER_LOSS',
      ),
      valueSchema: 'electra.elv4.power-loss.v1',
      value: input.pseTransferLoss.toMap(),
    ),
    PowerConsumedFact.present(
      key: _key(
        context,
        kind: PowerDependencyKind.segment,
        entityId: context.segmentId,
        purpose: 'POE_SCENARIO_STATE',
        scenarioScoped: true,
      ),
      valueSchema: 'electra.elv4.poe-scenario-facts.v1',
      value: scenarioFacts,
    ),
    ..._pathFacts(context, input),
    if (input.groupInputBasis == PoeGroupInputBasis.estimatedActual)
      _actualGroupOutputFact(context, input),
  ];

  return PowerConsumedInput(
    algorithmVersion: poeEvidenceAlgorithmVersion,
    inputSchemaVersion: poeEvidenceInputSchemaVersion,
    numericPolicyVersion: powerNumericPolicyVersion,
    facts: facts,
    evaluations: [
      PowerConsumedEvaluationRef(
        logicalNodeKey: pdDemandEvaluation.nodeKey.encode(),
        evaluationId: pdDemandEvaluation.evaluationId,
        inputFingerprint: pdDemandEvaluation.inputFingerprint,
      ),
    ],
  );
}

PoeEvaluationRecord buildPoeEvaluationRecord({
  required String evaluationId,
  required PoeEvidenceContext context,
  required PoeEvaluationInput input,
  required PoeEvaluationResult result,
  required PowerEvaluationEvidence pdDemandEvaluation,
  required Map<String, Object?> scenarioFacts,
}) {
  final consumedInput = buildPoeConsumedInput(
    context: context,
    input: input,
    pdDemandEvaluation: pdDemandEvaluation,
    scenarioFacts: scenarioFacts,
  );

  final outputBasis = switch (input.groupInputBasis) {
    PoeGroupInputBasis.conservativeReserved => result.groupReservedW,
    PoeGroupInputBasis.estimatedActual => input.estimatedActualGroupOutputW,
  };
  TransferInputDemand? transfer;
  if (result.upstreamInputW != null && outputBasis != null) {
    transfer = evaluateTransferInputDemand(
      transferId: 'POE_GROUP:${context.groupId}',
      deliveredOutputW: outputBasis,
      loss: input.pseTransferLoss,
    );
    if (transfer.inputW != result.upstreamInputW) {
      throw ArgumentError(
        'P5 result upstream demand does not match the canonical group transfer.',
      );
    }
  }

  final output = <String, Object?>{
    'deliveryId': input.deliveryId,
    'groupId': context.groupId,
    'pdDemandW': result.pdDemandW.toMap(),
    'guaranteedPdW': result.guaranteedPdW.toMap(),
    'reservedPseW': result.reservedPseW.toMap(),
    'pdMarginW': result.pdMarginW.toMap(),
    'portMarginW': result.portMarginW.toMap(),
    'groupReservedW': result.groupReservedW.toMap(),
    'groupMarginW': result.groupMarginW.toMap(),
    'upstreamOutputBasisW': outputBasis?.toMap(),
    'upstreamInputW': result.upstreamInputW?.toMap(),
    'upstreamLossW': transfer?.lossW.toMap(),
  };

  final evaluation = PowerEvaluationEvidence(
    evaluationId: evaluationId,
    nodeKey: PowerNodeKeyV2(
      revisionId: context.revisionId,
      scenarioId: context.scenarioId,
      scopeKind: PowerEvaluationScopeKind.segment,
      scopeId: context.segmentId,
      processCode: PowerProcessCode.pwr06,
      subjectKind: 'POE_DELIVERY',
      subjectId: input.deliveryId,
    ),
    algorithmVersion: poeEvidenceAlgorithmVersion,
    inputSchemaVersion: poeEvidenceInputSchemaVersion,
    outputSchemaVersion: poeEvidenceOutputSchemaVersion,
    inputFingerprint: consumedInput.inputFingerprint,
    status: result.status,
    applicability: PowerEvaluationApplicability.applicable,
    inputs: {
      'deliveryId': input.deliveryId,
      'groupId': context.groupId,
      'dependencyKeys': consumedInput.dependencyKeys,
    },
    output: output,
    dependencies: [pdDemandEvaluation.nodeKey],
    quantities: [
      {'code': 'PD_DEMAND_W', 'value': result.pdDemandW.toMap()},
      {'code': 'GROUP_RESERVED_W', 'value': result.groupReservedW.toMap()},
      if (result.upstreamInputW != null)
        {'code': 'UPSTREAM_INPUT_W', 'value': result.upstreamInputW!.toMap()},
    ],
    arithmeticSteps: transfer?.steps.map((value) => value.toMap()) ?? const [],
    findings: result.findings,
    assumptions: [
      'POE_ACCOUNTING_${input.accountingMode.name.toUpperCase()}',
      'POE_GROUP_BASIS_${input.groupInputBasis.name.toUpperCase()}',
    ],
  );

  return PoeEvaluationRecord(
    evaluation: evaluation,
    consumedInput: consumedInput,
  );
}

void _validatePdDemandDependency({
  required PoeEvidenceContext context,
  required PoeEvaluationInput input,
  required PowerEvaluationEvidence pdDemandEvaluation,
}) {
  final key = pdDemandEvaluation.nodeKey;
  if (key.processCode != PowerProcessCode.pwr01 ||
      key.scopeKind != PowerEvaluationScopeKind.segment ||
      key.revisionId != context.revisionId ||
      key.scenarioId != context.scenarioId ||
      key.scopeId != context.segmentId) {
    throw ArgumentError(
      'P5 PWR-06 requires a PWR-01 evaluation from the same revision/segment.',
    );
  }
  if (pdDemandEvaluation.output['completeW'] != true) {
    throw ArgumentError('P5 PWR-06 requires complete PWR-01 watt demand.');
  }
  final knownWValue = pdDemandEvaluation.output['knownW'];
  if (knownWValue is! Map) {
    throw ArgumentError('PWR-01 evidence does not contain knownW evidence.');
  }
  final knownW = PowerRational.fromMap(
    knownWValue.cast<String, Object?>(),
  );
  if (knownW != input.pdDemandW) {
    throw ArgumentError(
      'P5 PD demand must equal the consumed PWR-01 watt result.',
    );
  }
}

Iterable<PowerConsumedFact> _pathFacts(
  PoeEvidenceContext context,
  PoeEvaluationInput input,
) sync* {
  for (final stage in input.pathStages) {
    yield PowerConsumedFact.present(
      key: _key(
        context,
        kind: PowerDependencyKind.pathStage,
        entityId: stage.stageId,
        purpose: 'POE_PATH_STAGE',
      ),
      valueSchema: 'electra.elv4.poe-path-stage.v1',
      value: {
        'stageId': stage.stageId,
        'kind': stage.kind.name.toUpperCase(),
        'resourceKind': stage.resourceKind,
        'physicalRealized': stage.physicalRealized,
        'powerPass': stage.powerPass,
        'pairMappingResolved': stage.pairMappingResolved,
      },
    );

    final allocationKey = _key(
      context,
      kind: PowerDependencyKind.allocation,
      entityId: stage.stageId,
      purpose: 'REQUIRED_ALLOCATION',
    );
    if (stage.allocationId == null) {
      yield PowerConsumedFact.missing(
        key: allocationKey,
        valueSchema: 'electra.elv3.allocation-ref.v1',
      );
    } else {
      yield PowerConsumedFact.present(
        key: allocationKey,
        valueSchema: 'electra.elv3.allocation-ref.v1',
        value: {'allocationId': stage.allocationId},
      );
    }

    final runKey = _key(
      context,
      kind: PowerDependencyKind.cableRun,
      entityId: stage.stageId,
      purpose: 'REQUIRED_CABLE_RUN',
    );
    if (stage.cableRunId == null) {
      yield PowerConsumedFact.missing(
        key: runKey,
        valueSchema: 'electra.elv3.cable-run-ref.v1',
      );
    } else {
      yield PowerConsumedFact.present(
        key: runKey,
        valueSchema: 'electra.elv3.cable-run-ref.v1',
        value: {'cableRunId': stage.cableRunId},
      );
    }
  }
}

PowerConsumedFact _actualGroupOutputFact(
  PoeEvidenceContext context,
  PoeEvaluationInput input,
) {
  final key = _key(
    context,
    kind: PowerDependencyKind.capacityGroup,
    entityId: context.groupId,
    purpose: 'ACTUAL_GROUP_OUTPUT',
  );
  final value = input.estimatedActualGroupOutputW;
  return value == null
      ? PowerConsumedFact.missing(
          key: key,
          valueSchema: 'electra.elv4.power-rational.v1',
        )
      : PowerConsumedFact.present(
          key: key,
          valueSchema: 'electra.elv4.power-rational.v1',
          value: value.toMap(),
        );
}

List<Map<String, Object?>> _canonicalReservations(PoeEvaluationInput input) {
  final byOrigin = <String, PoeReservedAllocation>{};
  for (final reservation in [
    ...input.existingGroupReservations,
    PoeReservedAllocation(
      originId: input.deliveryId,
      portId: input.deliveryId,
      reservedW: input.reservedPseW,
    ),
  ]) {
    final existing = byOrigin[reservation.originId];
    if (existing != null &&
        (existing.portId != reservation.portId ||
            existing.reservedW != reservation.reservedW)) {
      throw ArgumentError(
        'PoE reservation origin has contradictory membership evidence.',
      );
    }
    byOrigin[reservation.originId] = reservation;
  }
  final origins = byOrigin.keys.toList()..sort();
  return [
    for (final origin in origins)
      {
        'originId': byOrigin[origin]!.originId,
        'portId': byOrigin[origin]!.portId,
        'reservedW': byOrigin[origin]!.reservedW.toMap(),
      },
  ];
}

Map<String, Object?>? _midspanMap(PoeMidspanContext? value) => value == null
    ? null
    : {
        'injectorComponentId': value.injectorComponentId,
        'dataInputPortId': value.dataInputPortId,
        'combinedOutputPortId': value.combinedOutputPortId,
        'supplyInputPortId': value.supplyInputPortId,
      };

PowerDependencyKey _key(
  PoeEvidenceContext context, {
  required PowerDependencyKind kind,
  required String entityId,
  required String purpose,
  bool scenarioScoped = false,
}) =>
    PowerDependencyKey(
      projectId: context.projectId,
      revisionId: context.revisionId,
      kind: kind,
      entityId: entityId,
      purpose: purpose,
      scenarioId: scenarioScoped ? context.scenarioId : null,
      segmentId: scenarioScoped ? context.segmentId : null,
    );

String _text(String value, String field) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, field, 'Must not be empty.');
  }
  return normalized;
}
