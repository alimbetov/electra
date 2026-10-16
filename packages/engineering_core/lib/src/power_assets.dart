import 'power_definition_ref.dart';
import 'power_numeric.dart';
import 'power_profiles.dart';

enum BatteryCapacityBasis { ampHour, wattHour }

final class BatteryUnitDefinition {
  BatteryUnitDefinition({
    required this.definitionRef,
    required String technology,
    required this.nominalV,
    required this.capacityBasis,
    required this.ratedCapacity,
    required this.usableFraction,
    required this.maxSeriesCount,
    required this.maxParallelCount,
    Iterable<String> arrangementCodes = const [],
  })  : technology = _code(technology, 'technology'),
        arrangementCodes = List.unmodifiable(_codes(
          arrangementCodes,
          field: 'arrangementCodes',
        )) {
    if (definitionRef.definitionKind != PowerDefinitionKind.battery) {
      throw ArgumentError('Battery unit requires a battery definition ref.');
    }
    _positive(nominalV, 'nominalV');
    _positive(ratedCapacity, 'ratedCapacity');
    _factor(usableFraction, 'usableFraction');
    if (maxSeriesCount < 1 || maxParallelCount < 1) {
      throw ArgumentError('Battery arrangement bounds must be positive.');
    }
  }

  final PowerDefinitionRef definitionRef;
  final String technology;
  final PowerRational nominalV;
  final BatteryCapacityBasis capacityBasis;
  final PowerRational ratedCapacity;
  final PowerRational usableFraction;
  final int maxSeriesCount;
  final int maxParallelCount;
  final List<String> arrangementCodes;

  Map<String, Object?> toMap() => {
        'definitionRef': definitionRef.toMap(),
        'technology': technology,
        'nominalV': nominalV.toWireDecimal(),
        'capacityBasis': capacityBasis.name.toUpperCase(),
        'ratedCapacity': ratedCapacity.toWireDecimal(),
        'usableFraction': usableFraction.toWireDecimal(),
        'maxSeriesCount': maxSeriesCount,
        'maxParallelCount': maxParallelCount,
        'arrangementCodes': arrangementCodes,
      };
}

final class BatteryBankBinding {
  BatteryBankBinding({
    required String componentId,
    required this.unitDefinition,
    required this.seriesCount,
    required this.parallelCount,
    required String arrangementCode,
    required this.socMin,
    required this.socMax,
    required this.endOfDischargeVoltagePerUnit,
  })  : componentId = _text(componentId, 'componentId'),
        arrangementCode = _code(arrangementCode, 'arrangementCode') {
    if (seriesCount < 1 ||
        seriesCount > unitDefinition.maxSeriesCount ||
        parallelCount < 1 ||
        parallelCount > unitDefinition.maxParallelCount) {
      throw ArgumentError('Battery bank arrangement exceeds unit bounds.');
    }
    if (unitDefinition.arrangementCodes.isNotEmpty &&
        !unitDefinition.arrangementCodes.contains(this.arrangementCode)) {
      throw ArgumentError(
          'Battery arrangement is not compatible with the unit.');
    }
    _factorInclusiveZero(socMin, 'socMin');
    _factorInclusiveZero(socMax, 'socMax');
    if (socMin >= socMax) {
      throw ArgumentError('Battery SOC limits must satisfy min < max.');
    }
    _positive(endOfDischargeVoltagePerUnit, 'endOfDischargeVoltagePerUnit');
    if (endOfDischargeVoltagePerUnit > unitDefinition.nominalV) {
      throw ArgumentError(
          'End-of-discharge voltage cannot exceed nominal voltage.');
    }
  }

  final String componentId;
  final BatteryUnitDefinition unitDefinition;
  final int seriesCount;
  final int parallelCount;
  final String arrangementCode;
  final PowerRational socMin;
  final PowerRational socMax;
  final PowerRational endOfDischargeVoltagePerUnit;

  PowerRational get nominalBankV =>
      unitDefinition.nominalV * PowerRational.integer(seriesCount);

  PowerRational get ratedBankCapacity => switch (unitDefinition.capacityBasis) {
        BatteryCapacityBasis.ampHour =>
          unitDefinition.ratedCapacity * PowerRational.integer(parallelCount),
        BatteryCapacityBasis.wattHour => unitDefinition.ratedCapacity *
            PowerRational.integer(seriesCount) *
            PowerRational.integer(parallelCount),
      };

  Map<String, Object?> toMap() => {
        'componentId': componentId,
        'unitDefinition': unitDefinition.toMap(),
        'seriesCount': seriesCount,
        'parallelCount': parallelCount,
        'arrangementCode': arrangementCode,
        'socMin': socMin.toWireDecimal(),
        'socMax': socMax.toWireDecimal(),
        'endOfDischargeVoltagePerUnit':
            endOfDischargeVoltagePerUnit.toWireDecimal(),
      };
}

final class PowerChargerDefinition {
  PowerChargerDefinition({
    required this.definitionRef,
    required this.outputVoltage,
    required this.maxChargeCurrentA,
    required this.lossDefinition,
    required Iterable<String> supportedBatteryTechnologies,
  }) : supportedBatteryTechnologies = List.unmodifiable(_codes(
          supportedBatteryTechnologies,
          field: 'supportedBatteryTechnologies',
        )) {
    if (definitionRef.definitionKind != PowerDefinitionKind.transfer) {
      throw ArgumentError('Charger requires a transfer definition ref.');
    }
    if (outputVoltage.currentKind != PowerCurrentKind.dc) {
      throw ArgumentError('Battery charger output must be DC.');
    }
    _positive(maxChargeCurrentA, 'maxChargeCurrentA');
    if (this.supportedBatteryTechnologies.isEmpty) {
      throw ArgumentError('Charger requires explicit battery technologies.');
    }
  }

  final PowerDefinitionRef definitionRef;
  final PowerVoltageEnvelope outputVoltage;
  final PowerRational maxChargeCurrentA;
  final PowerLossDefinition lossDefinition;
  final List<String> supportedBatteryTechnologies;

  bool supports(BatteryUnitDefinition unit) =>
      supportedBatteryTechnologies.contains(unit.technology);

  Map<String, Object?> toMap() => {
        'definitionRef': definitionRef.toMap(),
        'outputVoltage': outputVoltage.toMap(),
        'maxChargeCurrentA': maxChargeCurrentA.toWireDecimal(),
        'lossDefinition': lossDefinition.toMap(),
        'supportedBatteryTechnologies': supportedBatteryTechnologies,
      };
}

final class PoeDeliveryDefinition {
  PoeDeliveryDefinition({
    required this.definitionRef,
    required this.guaranteedPdPowerW,
    required this.psePortLimitW,
    required this.maxChannelLossW,
    required Iterable<String> compatibleResourceKinds,
    required this.supportsMidspan,
  }) : compatibleResourceKinds = List.unmodifiable(_codes(
          compatibleResourceKinds,
          field: 'compatibleResourceKinds',
        )) {
    if (definitionRef.definitionKind != PowerDefinitionKind.poe) {
      throw ArgumentError('PoE delivery requires a PoE definition ref.');
    }
    _positive(guaranteedPdPowerW, 'guaranteedPdPowerW');
    _positive(psePortLimitW, 'psePortLimitW');
    if (maxChannelLossW.isNegative) {
      throw ArgumentError('PoE channel loss cannot be negative.');
    }
    if (guaranteedPdPowerW + maxChannelLossW > psePortLimitW) {
      throw ArgumentError(
        'Guaranteed PD power plus declared channel loss exceeds PSE limit.',
      );
    }
    if (this.compatibleResourceKinds.isEmpty) {
      throw ArgumentError('PoE delivery requires explicit physical resources.');
    }
  }

  final PowerDefinitionRef definitionRef;
  final PowerRational guaranteedPdPowerW;
  final PowerRational psePortLimitW;
  final PowerRational maxChannelLossW;
  final List<String> compatibleResourceKinds;
  final bool supportsMidspan;

  Map<String, Object?> toMap() => {
        'definitionRef': definitionRef.toMap(),
        'guaranteedPdPowerW': guaranteedPdPowerW.toWireDecimal(),
        'psePortLimitW': psePortLimitW.toWireDecimal(),
        'maxChannelLossW': maxChannelLossW.toWireDecimal(),
        'compatibleResourceKinds': compatibleResourceKinds,
        'supportsMidspan': supportsMidspan,
      };
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

List<String> _codes(Iterable<String> values, {required String field}) {
  final result = values.map((value) => _code(value, field)).toList()..sort();
  if (result.toSet().length != result.length) {
    throw ArgumentError('$field must be unique.');
  }
  return result;
}

void _positive(PowerRational value, String field) {
  if (value <= PowerRational.zero) {
    throw ArgumentError.value(value, field, 'Must be positive.');
  }
}

void _factor(PowerRational value, String field) {
  _positive(value, field);
  if (value > PowerRational.one) {
    throw ArgumentError.value(value, field, 'Must be <= 1.');
  }
}

void _factorInclusiveZero(PowerRational value, String field) {
  if (value.isNegative || value > PowerRational.one) {
    throw ArgumentError.value(value, field, 'Must be in [0, 1].');
  }
}
