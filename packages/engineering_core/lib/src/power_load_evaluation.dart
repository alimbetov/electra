import 'engineering_hash.dart';
import 'power_evaluation.dart';
import 'power_numeric.dart';
import 'power_profiles.dart';

enum PowerQuantityDimension { watt, ampere, voltAmpere }

enum PowerDimensionStatus { pass, fail, unresolved }

final class PowerArithmeticStep {
  PowerArithmeticStep({
    required String operation,
    required Iterable<String> inputRefs,
    required String outputRef,
    required this.dimension,
    required this.value,
    required String boundaryRef,
  })  : operation = _code(operation, 'operation'),
        inputRefs = List.unmodifiable(_sortedUnique(inputRefs, 'inputRefs')),
        outputRef = _text(outputRef, 'outputRef'),
        boundaryRef = _text(boundaryRef, 'boundaryRef');

  final String operation;
  final List<String> inputRefs;
  final String outputRef;
  final PowerQuantityDimension dimension;
  final PowerRational value;
  final String boundaryRef;

  Map<String, Object?> toMap() => {
        'operation': operation,
        'inputRefs': inputRefs,
        'outputRef': outputRef,
        'dimension': dimension.name.toUpperCase(),
        'value': value.toMap(),
        'boundaryRef': boundaryRef,
      };
}

final class PowerDemandContribution {
  PowerDemandContribution({
    required String originId,
    required String componentId,
    required String inputPortId,
    required String stateCode,
    required this.demand,
    this.solvedTerminalVoltageV,
  })  : originId = _text(originId, 'originId'),
        componentId = _text(componentId, 'componentId'),
        inputPortId = _text(inputPortId, 'inputPortId'),
        stateCode = _code(stateCode, 'stateCode') {
    if (solvedTerminalVoltageV != null &&
        solvedTerminalVoltageV! <= PowerRational.zero) {
      throw ArgumentError('Solved terminal voltage must be positive.');
    }
  }

  final String originId;
  final String componentId;
  final String inputPortId;
  final String stateCode;
  final PowerDemand? demand;
  final PowerRational? solvedTerminalVoltageV;

  Map<String, Object?> toMap() => {
        'originId': originId,
        'componentId': componentId,
        'inputPortId': inputPortId,
        'stateCode': stateCode,
        'demand': demand?.toMap(),
        'solvedTerminalVoltageV': solvedTerminalVoltageV?.toMap(),
      };
}

final class ResolvedPowerContribution {
  const ResolvedPowerContribution({
    required this.source,
    required this.watt,
    required this.ampere,
    required this.voltAmpere,
    required this.unresolvedDimensions,
  });

  final PowerDemandContribution source;
  final PowerRational? watt;
  final PowerRational? ampere;
  final PowerRational? voltAmpere;
  final Set<PowerQuantityDimension> unresolvedDimensions;

  bool get complete => unresolvedDimensions.isEmpty;
}

ResolvedPowerContribution resolvePowerContribution(
    PowerDemandContribution input) {
  final demand = input.demand;
  if (demand == null) {
    return ResolvedPowerContribution(
      source: input,
      watt: null,
      ampere: null,
      voltAmpere: null,
      unresolvedDimensions: const {
        PowerQuantityDimension.watt,
        PowerQuantityDimension.ampere,
        PowerQuantityDimension.voltAmpere,
      },
    );
  }
  return switch (demand) {
    DcConstantCurrentDemand(:final currentA) => ResolvedPowerContribution(
        source: input,
        watt: input.solvedTerminalVoltageV == null
            ? null
            : currentA * input.solvedTerminalVoltageV!,
        ampere: currentA,
        voltAmpere: null,
        unresolvedDimensions: {
          if (input.solvedTerminalVoltageV == null) PowerQuantityDimension.watt,
          PowerQuantityDimension.voltAmpere,
        },
      ),
    DcConstantPowerDemand(:final powerW) => ResolvedPowerContribution(
        source: input,
        watt: powerW,
        ampere: null,
        voltAmpere: null,
        unresolvedDimensions: const {
          PowerQuantityDimension.ampere,
          PowerQuantityDimension.voltAmpere,
        },
      ),
    AcPowerDemand() => ResolvedPowerContribution(
        source: input,
        watt: demand.powerW,
        ampere: null,
        voltAmpere: demand.apparentVa,
        unresolvedDimensions: const {PowerQuantityDimension.ampere},
      ),
  };
}

final class AggregatedPowerDemand {
  const AggregatedPowerDemand({
    required this.contributions,
    required this.knownW,
    required this.knownA,
    required this.knownVa,
    required this.unresolvedOriginIds,
    required this.arithmeticSteps,
  });

  final List<ResolvedPowerContribution> contributions;
  final PowerRational knownW;
  final PowerRational knownA;
  final PowerRational knownVa;
  final List<String> unresolvedOriginIds;
  final List<PowerArithmeticStep> arithmeticSteps;

  bool get completeW => contributions.every(
        (item) =>
            !item.unresolvedDimensions.contains(PowerQuantityDimension.watt),
      );
  bool get completeA => contributions.every(
        (item) =>
            !item.unresolvedDimensions.contains(PowerQuantityDimension.ampere),
      );
  bool get completeVa => contributions.every(
        (item) => !item.unresolvedDimensions.contains(
          PowerQuantityDimension.voltAmpere,
        ),
      );
}

AggregatedPowerDemand aggregatePowerDemand(
  Iterable<PowerDemandContribution> input, {
  String boundaryRef = 'POWER_AGGREGATE',
}) {
  final byOrigin = <String, PowerDemandContribution>{};
  for (final contribution in input) {
    final existing = byOrigin[contribution.originId];
    if (existing == null) {
      byOrigin[contribution.originId] = contribution;
      continue;
    }
    if (_contributionFingerprint(existing) !=
        _contributionFingerprint(contribution)) {
      throw ArgumentError(
        'One physical origin cannot contribute contradictory power facts.',
      );
    }
  }

  final origins = byOrigin.keys.toList()..sort();
  final resolved = [
    for (final origin in origins) resolvePowerContribution(byOrigin[origin]!),
  ];
  var watts = PowerRational.zero;
  var amps = PowerRational.zero;
  var va = PowerRational.zero;
  final unresolved = <String>[];
  for (final item in resolved) {
    if (item.watt != null) watts += item.watt!;
    if (item.ampere != null) amps += item.ampere!;
    if (item.voltAmpere != null) va += item.voltAmpere!;
    if (!item.complete) unresolved.add(item.source.originId);
  }

  final steps = <PowerArithmeticStep>[
    PowerArithmeticStep(
      operation: 'SUM',
      inputRefs: [
        for (final item in resolved)
          if (item.watt != null) '${item.source.originId}:W',
      ],
      outputRef: '$boundaryRef:W',
      dimension: PowerQuantityDimension.watt,
      value: watts,
      boundaryRef: boundaryRef,
    ),
    PowerArithmeticStep(
      operation: 'SUM',
      inputRefs: [
        for (final item in resolved)
          if (item.ampere != null) '${item.source.originId}:A',
      ],
      outputRef: '$boundaryRef:A',
      dimension: PowerQuantityDimension.ampere,
      value: amps,
      boundaryRef: boundaryRef,
    ),
    PowerArithmeticStep(
      operation: 'SUM',
      inputRefs: [
        for (final item in resolved)
          if (item.voltAmpere != null) '${item.source.originId}:VA',
      ],
      outputRef: '$boundaryRef:VA',
      dimension: PowerQuantityDimension.voltAmpere,
      value: va,
      boundaryRef: boundaryRef,
    ),
  ];

  return AggregatedPowerDemand(
    contributions: List.unmodifiable(resolved),
    knownW: watts,
    knownA: amps,
    knownVa: va,
    unresolvedOriginIds: List.unmodifiable(unresolved),
    arithmeticSteps: List.unmodifiable(steps),
  );
}

final class TransferInputDemand {
  const TransferInputDemand({
    required this.outputW,
    required this.inputW,
    required this.lossW,
    required this.steps,
  });

  final PowerRational outputW;
  final PowerRational inputW;
  final PowerRational lossW;
  final List<PowerArithmeticStep> steps;
}

TransferInputDemand evaluateTransferInputDemand({
  required String transferId,
  required PowerRational deliveredOutputW,
  required PowerLossDefinition loss,
}) {
  if (deliveredOutputW.isNegative) {
    throw ArgumentError('Delivered output cannot be negative.');
  }
  var inputW = deliveredOutputW / loss.efficiency;
  if (loss.idleAccounting == PowerIdleAccounting.excludesSeparateIdle) {
    inputW += loss.idleW;
  }
  final lossW = inputW - deliveredOutputW;
  return TransferInputDemand(
    outputW: deliveredOutputW,
    inputW: inputW,
    lossW: lossW,
    steps: List.unmodifiable([
      PowerArithmeticStep(
        operation: 'TRANSFER_INPUT',
        inputRefs: ['$transferId:OUTPUT_W', '$transferId:EFFICIENCY'],
        outputRef: '$transferId:INPUT_W',
        dimension: PowerQuantityDimension.watt,
        value: inputW,
        boundaryRef: transferId,
      ),
      PowerArithmeticStep(
        operation: 'TRANSFER_LOSS',
        inputRefs: ['$transferId:INPUT_W', '$transferId:OUTPUT_W'],
        outputRef: '$transferId:LOSS_W',
        dimension: PowerQuantityDimension.watt,
        value: lossW,
        boundaryRef: transferId,
      ),
    ]),
  );
}

final class PowerCapabilityDimension {
  PowerCapabilityDimension({
    required this.dimension,
    required this.demand,
    required this.nameplate,
    required this.reserveMultiplier,
    required this.deratingFactor,
  }) {
    if (demand.isNegative || nameplate.isNegative) {
      throw ArgumentError('Demand and nameplate cannot be negative.');
    }
    if (reserveMultiplier < PowerRational.one) {
      throw ArgumentError('Reserve multiplier must be >= 1.');
    }
    if (deratingFactor <= PowerRational.zero ||
        deratingFactor > PowerRational.one) {
      throw ArgumentError('Derating must be in (0, 1].');
    }
  }

  final PowerQuantityDimension dimension;
  final PowerRational demand;
  final PowerRational nameplate;
  final PowerRational reserveMultiplier;
  final PowerRational deratingFactor;
}

final class PowerCapabilityAssessment {
  const PowerCapabilityAssessment({
    required this.dimension,
    required this.status,
    required this.physicalDemand,
    required this.required,
    required this.available,
    required this.margin,
    required this.utilization,
    required this.zeroCapacity,
  });

  final PowerQuantityDimension dimension;
  final PowerDimensionStatus status;
  final PowerRational physicalDemand;
  final PowerRational required;
  final PowerRational available;
  final PowerRational margin;
  final PowerRational? utilization;
  final bool zeroCapacity;
}

PowerCapabilityAssessment evaluateSupplyCapability(
  PowerCapabilityDimension input,
) {
  final required = input.demand * input.reserveMultiplier;
  final available = input.nameplate * input.deratingFactor;
  final margin = available - required;
  return PowerCapabilityAssessment(
    dimension: input.dimension,
    status: required <= available
        ? PowerDimensionStatus.pass
        : PowerDimensionStatus.fail,
    physicalDemand: input.demand,
    required: required,
    available: available,
    margin: margin,
    utilization: available.isZero ? null : required / available,
    zeroCapacity: available.isZero,
  );
}

final class UpsLoadingResult {
  const UpsLoadingResult({
    required this.watt,
    required this.voltAmpere,
    required this.inputW,
    required this.inputVa,
    required this.status,
  });

  final PowerCapabilityAssessment watt;
  final PowerCapabilityAssessment voltAmpere;
  final PowerRational inputW;
  final PowerRational? inputVa;
  final PowerEvaluationStatus status;
}

UpsLoadingResult evaluateUpsLoading({
  required PowerRational protectedOutputW,
  required PowerRational protectedOutputVa,
  required PowerRational ratedOutputW,
  required PowerRational ratedOutputVa,
  required PowerLossDefinition transferLoss,
  PowerRational? reserveMultiplier,
  PowerRational? deratingFactor,
  PowerRational? inputPowerFactor,
}) {
  final effectiveReserveMultiplier = reserveMultiplier ?? PowerRational.one;
  final effectiveDeratingFactor = deratingFactor ?? PowerRational.one;
  final watt = evaluateSupplyCapability(
    PowerCapabilityDimension(
      dimension: PowerQuantityDimension.watt,
      demand: protectedOutputW,
      nameplate: ratedOutputW,
      reserveMultiplier: effectiveReserveMultiplier,
      deratingFactor: effectiveDeratingFactor,
    ),
  );
  final va = evaluateSupplyCapability(
    PowerCapabilityDimension(
      dimension: PowerQuantityDimension.voltAmpere,
      demand: protectedOutputVa,
      nameplate: ratedOutputVa,
      reserveMultiplier: effectiveReserveMultiplier,
      deratingFactor: effectiveDeratingFactor,
    ),
  );
  final transfer = evaluateTransferInputDemand(
    transferId: 'UPS',
    deliveredOutputW: protectedOutputW,
    loss: transferLoss,
  );
  if (inputPowerFactor != null &&
      (inputPowerFactor <= PowerRational.zero ||
          inputPowerFactor > PowerRational.one)) {
    throw ArgumentError('UPS input PF must be in (0,1].');
  }
  final inputVa =
      inputPowerFactor == null ? null : transfer.inputW / inputPowerFactor;
  final status = watt.status == PowerDimensionStatus.fail ||
          va.status == PowerDimensionStatus.fail
      ? PowerEvaluationStatus.fail
      : inputVa == null
          ? PowerEvaluationStatus.unresolved
          : PowerEvaluationStatus.pass;
  return UpsLoadingResult(
    watt: watt,
    voltAmpere: va,
    inputW: transfer.inputW,
    inputVa: inputVa,
    status: status,
  );
}

final class PowerPeakPulse {
  PowerPeakPulse({
    required String originId,
    required this.incrementW,
    required this.durationSeconds,
  }) : originId = _text(originId, 'originId') {
    if (incrementW.isNegative || durationSeconds <= PowerRational.zero) {
      throw ArgumentError(
        'Peak pulse requires nonnegative W and positive duration.',
      );
    }
  }

  final String originId;
  final PowerRational incrementW;
  final PowerRational durationSeconds;
}

final class PowerPeakAssessment {
  const PowerPeakAssessment({
    required this.status,
    required this.maximumW,
    required this.requiredDurationSeconds,
    required this.marginW,
  });

  final PowerDimensionStatus status;
  final PowerRational maximumW;
  final PowerRational requiredDurationSeconds;
  final PowerRational marginW;
}

PowerPeakAssessment evaluateAllSimultaneousPeak({
  required PowerRational steadyW,
  required Iterable<PowerPeakPulse> pulses,
  required PowerRational peakRatingW,
  required PowerRational ratingDurationSeconds,
}) {
  if (steadyW.isNegative ||
      peakRatingW.isNegative ||
      ratingDurationSeconds <= PowerRational.zero) {
    throw ArgumentError('Invalid peak assessment quantities.');
  }
  final unique = <String, PowerPeakPulse>{};
  for (final pulse in pulses) {
    final existing = unique[pulse.originId];
    if (existing != null &&
        (existing.incrementW != pulse.incrementW ||
            existing.durationSeconds != pulse.durationSeconds)) {
      throw ArgumentError('Peak origin has contradictory pulse evidence.');
    }
    unique[pulse.originId] = pulse;
  }
  var maximumW = steadyW;
  var requiredDuration = PowerRational.zero;
  for (final pulse in unique.values) {
    maximumW += pulse.incrementW;
    if (pulse.durationSeconds > requiredDuration) {
      requiredDuration = pulse.durationSeconds;
    }
  }
  final durationSupported = requiredDuration <= ratingDurationSeconds;
  final wattSupported = maximumW <= peakRatingW;
  return PowerPeakAssessment(
    status: durationSupported && wattSupported
        ? PowerDimensionStatus.pass
        : PowerDimensionStatus.fail,
    maximumW: maximumW,
    requiredDurationSeconds: requiredDuration,
    marginW: peakRatingW - maximumW,
  );
}

String _contributionFingerprint(PowerDemandContribution input) =>
    canonicalEngineeringJsonV1(input.toMap());

List<String> _sortedUnique(Iterable<String> values, String field) {
  final result = values.map((value) => _text(value, field)).toList()..sort();
  if (result.toSet().length != result.length) {
    throw ArgumentError('$field must be unique.');
  }
  return result;
}

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
