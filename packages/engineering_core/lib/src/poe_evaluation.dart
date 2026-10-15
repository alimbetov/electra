import 'power_assets.dart';
import 'power_evaluation.dart';
import 'power_load_evaluation.dart';
import 'power_numeric.dart';
import 'power_profiles.dart';

enum PoeAccountingMode { guaranteedPd, explicitPathLoss }

enum PoeGroupInputBasis { conservativeReserved, estimatedActual }

enum PoePathStageKind { copperCable, passiveMapping, fiber }

final class PoePathStage {
  PoePathStage({
    required String stageId,
    required this.kind,
    required String resourceKind,
    required this.physicalRealized,
    required this.powerPass,
    required this.pairMappingResolved,
    String? allocationId,
    String? cableRunId,
  })  : stageId = _text(stageId, 'stageId'),
        resourceKind = _code(resourceKind, 'resourceKind'),
        allocationId =
            allocationId == null ? null : _text(allocationId, 'allocationId'),
        cableRunId = cableRunId == null ? null : _text(cableRunId, 'cableRunId');

  final String stageId;
  final PoePathStageKind kind;
  final String resourceKind;
  final bool physicalRealized;
  final bool powerPass;
  final bool pairMappingResolved;
  final String? allocationId;
  final String? cableRunId;
}

final class PoeReservedAllocation {
  PoeReservedAllocation({
    required String originId,
    required String portId,
    required this.reservedW,
  })  : originId = _text(originId, 'originId'),
        portId = _text(portId, 'portId') {
    if (reservedW.isNegative) {
      throw ArgumentError('PoE reservation cannot be negative.');
    }
  }

  final String originId;
  final String portId;
  final PowerRational reservedW;
}

final class PoeMidspanContext {
  PoeMidspanContext({
    required String injectorComponentId,
    required String dataInputPortId,
    required String combinedOutputPortId,
    required String supplyInputPortId,
  })  : injectorComponentId = _text(injectorComponentId, 'injectorComponentId'),
        dataInputPortId = _text(dataInputPortId, 'dataInputPortId'),
        combinedOutputPortId =
            _text(combinedOutputPortId, 'combinedOutputPortId'),
        supplyInputPortId = _text(supplyInputPortId, 'supplyInputPortId') {
    if (this.dataInputPortId == this.supplyInputPortId ||
        this.combinedOutputPortId == this.supplyInputPortId) {
      throw ArgumentError('Midspan data and supply boundaries must be explicit.');
    }
  }

  final String injectorComponentId;
  final String dataInputPortId;
  final String combinedOutputPortId;
  final String supplyInputPortId;
}

final class PoeEvaluationInput {
  PoeEvaluationInput({
    required String deliveryId,
    required this.definition,
    required this.accountingMode,
    required this.groupInputBasis,
    required this.pdDemandW,
    required this.reservedPseW,
    required this.portAllocationLimitW,
    required this.sharedGroupBudgetW,
    required Iterable<PoeReservedAllocation> existingGroupReservations,
    required Iterable<PoePathStage> pathStages,
    required this.pseRoleConfirmed,
    required this.pdRoleConfirmed,
    required this.pseTransferLoss,
    this.estimatedActualGroupOutputW,
    this.midspan,
  })  : deliveryId = _text(deliveryId, 'deliveryId'),
        existingGroupReservations =
            List.unmodifiable(existingGroupReservations),
        pathStages = List.unmodifiable(pathStages) {
    for (final value in [
      pdDemandW,
      reservedPseW,
      portAllocationLimitW,
      sharedGroupBudgetW,
    ]) {
      if (value.isNegative) {
        throw ArgumentError('PoE quantities cannot be negative.');
      }
    }
    if (estimatedActualGroupOutputW != null &&
        estimatedActualGroupOutputW!.isNegative) {
      throw ArgumentError('Estimated actual PoE output cannot be negative.');
    }
  }

  final String deliveryId;
  final PoeDeliveryDefinition definition;
  final PoeAccountingMode accountingMode;
  final PoeGroupInputBasis groupInputBasis;
  final PowerRational pdDemandW;
  final PowerRational reservedPseW;
  final PowerRational portAllocationLimitW;
  final PowerRational sharedGroupBudgetW;
  final List<PoeReservedAllocation> existingGroupReservations;
  final List<PoePathStage> pathStages;
  final bool pseRoleConfirmed;
  final bool pdRoleConfirmed;
  final PowerLossDefinition pseTransferLoss;
  final PowerRational? estimatedActualGroupOutputW;
  final PoeMidspanContext? midspan;
}

final class PoeEvaluationResult {
  const PoeEvaluationResult({
    required this.status,
    required this.findings,
    required this.pdDemandW,
    required this.guaranteedPdW,
    required this.reservedPseW,
    required this.pdMarginW,
    required this.portMarginW,
    required this.groupReservedW,
    required this.groupMarginW,
    required this.upstreamInputW,
  });

  final PowerEvaluationStatus status;
  final List<PowerEvaluationFinding> findings;
  final PowerRational pdDemandW;
  final PowerRational guaranteedPdW;
  final PowerRational reservedPseW;
  final PowerRational pdMarginW;
  final PowerRational portMarginW;
  final PowerRational groupReservedW;
  final PowerRational groupMarginW;
  final PowerRational? upstreamInputW;
}

PoeEvaluationResult evaluatePoeDelivery(PoeEvaluationInput input) {
  final findings = <PowerEvaluationFinding>[];
  if (!input.pseRoleConfirmed || !input.pdRoleConfirmed) {
    findings.add(_finding(
      'ELV4_POE_ROLE_MISMATCH',
      'BLOCKED',
      'Exact PSE and PD roles must be declared by the selected definitions.',
    ));
  }
  if (input.accountingMode == PoeAccountingMode.explicitPathLoss) {
    findings.add(_finding(
      'ELV4_POE_EXPLICIT_PATH_LOSS_UNSUPPORTED',
      'BLOCKED',
      'Balanced-pair explicit path-loss model is not implemented in v1.',
    ));
  }
  if (input.midspan != null && !input.definition.supportsMidspan) {
    findings.add(_finding(
      'ELV4_POE_MIDSPAN_UNSUPPORTED',
      'BLOCKED',
      'Selected delivery definition does not support a powered midspan.',
    ));
  }
  if (input.pathStages.isEmpty) {
    findings.add(_finding(
      'ELV4_POE_PATH_MISSING',
      'UNRESOLVED',
      'PoE delivery requires an existing physical path.',
    ));
  }
  for (final stage in input.pathStages) {
    if (!stage.physicalRealized) {
      findings.add(_finding(
        'ELV4_POE_PATH_REALIZATION_MISSING',
        'UNRESOLVED',
        'Path stage ${stage.stageId} lacks installed realization evidence.',
      ));
      continue;
    }
    if (stage.kind == PoePathStageKind.fiber) {
      findings.add(_finding(
        'ELV4_POE_FIBER_NONCONDUCTIVE',
        'BLOCKED',
        'Fiber stage ${stage.stageId} cannot conduct PoE.',
      ));
    }
    if (!stage.powerPass) {
      findings.add(_finding(
        'ELV4_POE_POWER_PASS_BLOCKED',
        'BLOCKED',
        'Path stage ${stage.stageId} is not declared power-pass.',
      ));
    }
    if (!stage.pairMappingResolved) {
      findings.add(_finding(
        'ELV4_POE_PAIR_MAPPING_UNRESOLVED',
        'UNRESOLVED',
        'Path stage ${stage.stageId} has unresolved pair/terminal mapping.',
      ));
    }
    if (!input.definition.compatibleResourceKinds.contains(stage.resourceKind)) {
      findings.add(_finding(
        'ELV4_POE_RESOURCE_UNSUPPORTED',
        'BLOCKED',
        'Path stage ${stage.stageId} uses an unsupported physical resource.',
      ));
    }
  }

  final pdMargin = input.definition.guaranteedPdPowerW - input.pdDemandW;
  if (pdMargin.isNegative) {
    findings.add(_finding(
      'ELV4_POE_PD_GUARANTEE_EXCEEDED',
      'FAIL',
      'PD demand exceeds the guaranteed delivered power.',
    ));
  }
  final effectivePortLimit = input.portAllocationLimitW <
          input.definition.psePortLimitW
      ? input.portAllocationLimitW
      : input.definition.psePortLimitW;
  final portMargin = effectivePortLimit - input.reservedPseW;
  if (portMargin.isNegative) {
    findings.add(_finding(
      'ELV4_POE_PORT_ALLOCATION_EXCEEDED',
      'FAIL',
      'Reserved PSE allocation exceeds the effective per-port limit.',
    ));
  }

  final reservations = <String, PoeReservedAllocation>{};
  for (final reservation in [
    ...input.existingGroupReservations,
    PoeReservedAllocation(
      originId: input.deliveryId,
      portId: input.deliveryId,
      reservedW: input.reservedPseW,
    ),
  ]) {
    final existing = reservations[reservation.originId];
    if (existing != null && existing.reservedW != reservation.reservedW) {
      throw ArgumentError('PoE reservation origin has contradictory evidence.');
    }
    reservations[reservation.originId] = reservation;
  }
  var groupReserved = PowerRational.zero;
  for (final origin in reservations.keys.toList()..sort()) {
    groupReserved += reservations[origin]!.reservedW;
  }
  final groupMargin = input.sharedGroupBudgetW - groupReserved;
  if (groupMargin.isNegative) {
    findings.add(_finding(
      'ELV4_POE_GROUP_BUDGET_EXCEEDED',
      'FAIL',
      'Distinct reserved PSE allocations exceed the shared group budget.',
    ));
  }

  PowerRational? upstreamInputW;
  final hasStructuralBlock = findings.any(
    (finding) => finding.severity == 'BLOCKED',
  );
  final hasUnresolved = findings.any(
    (finding) => finding.severity == 'UNRESOLVED',
  );
  if (!hasStructuralBlock && !hasUnresolved) {
    final outputBasis = switch (input.groupInputBasis) {
      PoeGroupInputBasis.conservativeReserved => groupReserved,
      PoeGroupInputBasis.estimatedActual => input.estimatedActualGroupOutputW,
    };
    if (outputBasis == null) {
      findings.add(_finding(
        'ELV4_POE_ACTUAL_GROUP_OUTPUT_MISSING',
        'UNRESOLVED',
        'Actual group input basis was selected without an estimate.',
      ));
    } else {
      upstreamInputW = evaluateTransferInputDemand(
        transferId: 'PSE:${input.deliveryId}',
        deliveredOutputW: outputBasis,
        loss: input.pseTransferLoss,
      ).inputW;
    }
  }

  final status = findings.any((finding) => finding.severity == 'BLOCKED')
      ? PowerEvaluationStatus.blocked
      : findings.any((finding) => finding.severity == 'FAIL')
          ? PowerEvaluationStatus.fail
          : findings.any((finding) => finding.severity == 'UNRESOLVED')
              ? PowerEvaluationStatus.unresolved
              : PowerEvaluationStatus.pass;
  return PoeEvaluationResult(
    status: status,
    findings: List.unmodifiable(findings),
    pdDemandW: input.pdDemandW,
    guaranteedPdW: input.definition.guaranteedPdPowerW,
    reservedPseW: input.reservedPseW,
    pdMarginW: pdMargin,
    portMarginW: portMargin,
    groupReservedW: groupReserved,
    groupMarginW: groupMargin,
    upstreamInputW: upstreamInputW,
  );
}

PowerEvaluationFinding _finding(String code, String severity, String message) =>
    PowerEvaluationFinding(
      code: code,
      severity: severity,
      message: message,
    );

String _text(String value, String field) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, field, 'Must not be empty.');
  }
  return normalized;
}

String _code(String value, String field) {
  final normalized = _text(value, field).toUpperCase();
  if (!RegExp(r'^[A-Z][A-Z0-9_-]{0,127}$').hasMatch(normalized)) {
    throw ArgumentError.value(value, field, 'Invalid canonical code.');
  }
  return normalized;
}
