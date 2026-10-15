import 'poe_evaluation.dart';
import 'power_dc_backup.dart';
import 'power_evaluation.dart';
import 'power_load_evaluation.dart';
import 'power_numeric.dart';
import 'power_profiles.dart';

/// A resolved demand crossing an engineering-process boundary.
///
/// [demandW] is always the demand seen by the parent boundary. Any conversion,
/// idle consumption, feeder loss or other transformation represented by
/// [accountingKeys] has already been applied and must not be applied again by
/// the parent evaluator.
final class PowerBoundaryDemand {
  PowerBoundaryDemand({
    required String originId,
    required String boundaryRef,
    required String sourceRef,
    required this.status,
    required this.demandW,
    this.sourceOutputW,
    this.accountedLossW,
    Iterable<String> accountingKeys = const [],
    Iterable<PowerEvaluationFinding> findings = const [],
  })  : originId = _text(originId, 'originId'),
        boundaryRef = _text(boundaryRef, 'boundaryRef'),
        sourceRef = _text(sourceRef, 'sourceRef'),
        accountingKeys = List.unmodifiable(
          _sortedUnique(accountingKeys, 'accountingKeys'),
        ),
        findings = List.unmodifiable(findings) {
    for (final value in [demandW, sourceOutputW, accountedLossW]) {
      if (value != null && value.isNegative) {
        throw ArgumentError('Boundary power quantities cannot be negative.');
      }
    }
    if (demandW != null && sourceOutputW != null && accountedLossW != null) {
      if (sourceOutputW! + accountedLossW! != demandW!) {
        throw ArgumentError(
          'Boundary demand must equal source output plus accounted loss.',
        );
      }
    }
  }

  final String originId;
  final String boundaryRef;
  final String sourceRef;
  final PowerEvaluationStatus status;
  final PowerRational? demandW;
  final PowerRational? sourceOutputW;
  final PowerRational? accountedLossW;
  final List<String> accountingKeys;
  final List<PowerEvaluationFinding> findings;
}

/// Conversion owned by the current P4 aggregation boundary.
///
/// The accounting key is an architectural responsibility identity. Reusing a
/// key already present on a child boundary is rejected as double accounting.
final class PowerOwnedTransfer {
  PowerOwnedTransfer({
    required String transferId,
    required String accountingKey,
    required this.loss,
  })  : transferId = _text(transferId, 'transferId'),
        accountingKey = _code(accountingKey, 'accountingKey');

  final String transferId;
  final String accountingKey;
  final PowerLossDefinition loss;
}

final class PowerBottomUpEvaluationInput {
  PowerBottomUpEvaluationInput({
    required String boundaryRef,
    Iterable<PowerDemandContribution> directContributions = const [],
    Iterable<PowerBoundaryDemand> childBoundaries = const [],
    this.localTransfer,
  })  : boundaryRef = _text(boundaryRef, 'boundaryRef'),
        directContributions = List.unmodifiable(directContributions),
        childBoundaries = List.unmodifiable(childBoundaries);

  final String boundaryRef;
  final List<PowerDemandContribution> directContributions;
  final List<PowerBoundaryDemand> childBoundaries;
  final PowerOwnedTransfer? localTransfer;
}

final class PowerBottomUpEvaluationResult {
  const PowerBottomUpEvaluationResult({
    required this.status,
    required this.boundaryRef,
    required this.outputDemandW,
    required this.upstreamInputW,
    required this.localLossW,
    required this.accountingKeys,
    required this.findings,
    required this.arithmeticSteps,
  });

  final PowerEvaluationStatus status;
  final String boundaryRef;

  /// Physical demand at the current boundary before its locally owned transfer.
  final PowerRational outputDemandW;

  /// Parent-facing demand after the locally owned transfer, when resolvable.
  final PowerRational? upstreamInputW;

  /// Loss owned only by the local transfer. Child losses are already embedded
  /// in child boundary demand and are intentionally not added again here.
  final PowerRational? localLossW;
  final List<String> accountingKeys;
  final List<PowerEvaluationFinding> findings;
  final List<PowerArithmeticStep> arithmeticSteps;

  PowerBoundaryDemand asBoundaryDemand({
    required String originId,
    required String sourceRef,
  }) =>
      PowerBoundaryDemand(
        originId: originId,
        boundaryRef: boundaryRef,
        sourceRef: sourceRef,
        status: status,
        demandW: upstreamInputW,
        sourceOutputW: upstreamInputW == null ? null : outputDemandW,
        accountedLossW: upstreamInputW == null ? null : localLossW,
        accountingKeys: accountingKeys,
        findings: findings,
      );
}

/// Single P4 bottom-up aggregation boundary.
///
/// P5/P6 are evaluated before this function and contribute immutable boundary
/// demands. This keeps process execution acyclic while still allowing a parent
/// P4 node to consume child P5/P6 results.
PowerBottomUpEvaluationResult evaluateBottomUpPowerBoundary(
  PowerBottomUpEvaluationInput input,
) {
  final direct = aggregatePowerDemand(
    input.directContributions,
    boundaryRef: '${input.boundaryRef}:DIRECT',
  );

  final byOrigin = <String, PowerBoundaryDemand>{};
  for (final boundary in input.childBoundaries) {
    final existing = byOrigin[boundary.originId];
    if (existing == null) {
      byOrigin[boundary.originId] = boundary;
      continue;
    }
    if (!_sameBoundary(existing, boundary)) {
      throw ArgumentError(
        'One physical boundary origin cannot contribute contradictory demand.',
      );
    }
  }
  final childOrigins = byOrigin.keys.toList()..sort();
  final children = [for (final origin in childOrigins) byOrigin[origin]!];

  final findings = <PowerEvaluationFinding>[
    for (final child in children) ...child.findings,
  ];
  if (!direct.completeW) {
    findings.add(
      PowerEvaluationFinding(
        code: 'ELV4_BOTTOM_UP_DIRECT_W_UNRESOLVED',
        severity: 'UNRESOLVED',
        message: 'Direct physical demand is incomplete in the watt dimension.',
        sourceRefs: direct.unresolvedOriginIds,
      ),
    );
  }
  for (final child in children) {
    if (child.demandW == null) {
      findings.add(
        PowerEvaluationFinding(
          code: 'ELV4_BOTTOM_UP_BOUNDARY_W_UNRESOLVED',
          severity: 'UNRESOLVED',
          message:
              'Child boundary demand is unavailable at ${child.boundaryRef}.',
          sourceRefs: [child.sourceRef],
        ),
      );
    }
  }

  var outputW = direct.knownW;
  for (final child in children) {
    if (child.demandW != null) outputW += child.demandW!;
  }

  final accountingKeys = <String>{};
  for (final child in children) {
    accountingKeys.addAll(child.accountingKeys);
  }

  final steps = <PowerArithmeticStep>[
    ...direct.arithmeticSteps,
    PowerArithmeticStep(
      operation: 'BOUNDARY_SUM',
      inputRefs: [
        if (direct.directInputRefs.isNotEmpty) '${input.boundaryRef}:DIRECT:W',
        for (final child in children)
          if (child.demandW != null) '${child.boundaryRef}:UPSTREAM_W',
      ],
      outputRef: '${input.boundaryRef}:OUTPUT_W',
      dimension: PowerQuantityDimension.watt,
      value: outputW,
      boundaryRef: input.boundaryRef,
    ),
  ];

  final completeW =
      direct.completeW && children.every((child) => child.demandW != null);
  PowerRational? upstreamW;
  PowerRational? localLossW;
  final transfer = input.localTransfer;
  if (transfer == null) {
    if (completeW) {
      upstreamW = outputW;
      localLossW = PowerRational.zero;
    }
  } else {
    if (accountingKeys.contains(transfer.accountingKey)) {
      throw ArgumentError(
        'Accounting key ${transfer.accountingKey} is already applied by a child boundary.',
      );
    }
    if (completeW) {
      final evaluated = evaluateTransferInputDemand(
        transferId: transfer.transferId,
        deliveredOutputW: outputW,
        loss: transfer.loss,
      );
      upstreamW = evaluated.inputW;
      localLossW = evaluated.lossW;
      steps.addAll(evaluated.steps);
      accountingKeys.add(transfer.accountingKey);
    }
  }

  final status = _combineStatus(
    children.map((child) => child.status),
    unresolved: !completeW,
  );
  return PowerBottomUpEvaluationResult(
    status: status,
    boundaryRef: input.boundaryRef,
    outputDemandW: outputW,
    upstreamInputW: upstreamW,
    localLossW: localLossW,
    accountingKeys: List.unmodifiable(accountingKeys.toList()..sort()),
    findings: List.unmodifiable(findings),
    arithmeticSteps: List.unmodifiable(steps),
  );
}

/// P5 -> P4 adapter. PSE conversion/idle is owned by P5 and represented by the
/// shared PSE group identity, not by an individual PD delivery. The P5 result
/// is group-wide; binding it to [groupId] prevents the same shared PSE input
/// from being added once per delivery at the P4 parent boundary.
PowerBoundaryDemand poeUpstreamBoundary({
  required String groupId,
  required PoeEvaluationInput input,
  required PoeEvaluationResult result,
}) {
  final canonicalGroupId = _text(groupId, 'groupId');
  final outputBasis = switch (input.groupInputBasis) {
    PoeGroupInputBasis.conservativeReserved => result.groupReservedW,
    PoeGroupInputBasis.estimatedActual => input.estimatedActualGroupOutputW,
  };
  final upstream = result.upstreamInputW;
  return PowerBoundaryDemand(
    originId: canonicalGroupId,
    boundaryRef: 'POE_GROUP:$canonicalGroupId',
    sourceRef: 'PWR06:${input.deliveryId}',
    status: result.status,
    demandW: upstream,
    sourceOutputW: upstream == null ? null : outputBasis,
    accountedLossW:
        upstream == null || outputBasis == null ? null : upstream - outputBasis,
    accountingKeys: ['P5_PSE_GROUP_TRANSFER_${_keyToken(canonicalGroupId)}'],
    findings: result.findings,
  );
}

/// P6 DC feeder -> P4 adapter. I²R feeder loss is already included in
/// [DcTreeResult.sourceNominalW] and is therefore carried as an atomic parent
/// demand rather than added again by P4.
PowerBoundaryDemand dcTreeSourceBoundary({
  required String originId,
  required String domainId,
  required DcTreeResult result,
}) =>
    PowerBoundaryDemand(
      originId: originId,
      boundaryRef: 'DC:$domainId',
      sourceRef: 'PWR03:$domainId',
      status: result.status,
      demandW: result.sourceNominalW,
      sourceOutputW: result.deliveredNominalW,
      accountedLossW: result.totalLossW,
      accountingKeys: ['P6_DC_FEEDER_${_keyToken(domainId)}'],
    );

/// P6 charger -> P4 adapter. Charger efficiency and exclusive idle consumption
/// are already included in [ChargerEvaluationResult.upstreamInputW].
PowerBoundaryDemand chargerUpstreamBoundary({
  required String originId,
  required String chargerId,
  required ChargerEvaluationResult result,
}) =>
    PowerBoundaryDemand(
      originId: originId,
      boundaryRef: 'CHARGER:$chargerId',
      sourceRef: 'P6_CHARGER:$chargerId',
      status: result.status,
      demandW: result.upstreamInputW,
      sourceOutputW: result.combinedOutputW,
      accountedLossW: result.upstreamInputW - result.combinedOutputW,
      accountingKeys: ['P6_CHARGER_TRANSFER_${_keyToken(chargerId)}'],
    );

PowerEvaluationStatus _combineStatus(
  Iterable<PowerEvaluationStatus> statuses, {
  required bool unresolved,
}) {
  final values = statuses.toList();
  if (values.contains(PowerEvaluationStatus.blocked)) {
    return PowerEvaluationStatus.blocked;
  }
  if (values.contains(PowerEvaluationStatus.fail)) {
    return PowerEvaluationStatus.fail;
  }
  if (unresolved || values.contains(PowerEvaluationStatus.unresolved)) {
    return PowerEvaluationStatus.unresolved;
  }
  return PowerEvaluationStatus.pass;
}

bool _sameBoundary(PowerBoundaryDemand a, PowerBoundaryDemand b) =>
    a.boundaryRef == b.boundaryRef &&
    a.sourceRef == b.sourceRef &&
    a.status == b.status &&
    a.demandW == b.demandW &&
    a.sourceOutputW == b.sourceOutputW &&
    a.accountedLossW == b.accountedLossW &&
    _sameStrings(a.accountingKeys, b.accountingKeys);

bool _sameStrings(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

List<String> _sortedUnique(Iterable<String> values, String field) {
  final result = values.map((value) => _code(value, field)).toList()..sort();
  if (result.toSet().length != result.length) {
    throw ArgumentError('$field must be unique.');
  }
  return result;
}

String _keyToken(String value) =>
    value.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9_-]+'), '_');

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

extension on AggregatedPowerDemand {
  List<String> get directInputRefs => [
        for (final item in contributions)
          if (item.watt != null) '${item.source.originId}:W',
      ];
}
