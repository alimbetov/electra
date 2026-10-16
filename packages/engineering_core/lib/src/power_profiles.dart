import 'power_numeric.dart';

enum PowerCurrentKind { ac, dc }

/// Static envelope, independent from a selected operating scenario.
final class PowerVoltageEnvelope {
  PowerVoltageEnvelope({
    required this.currentKind,
    required this.minV,
    required this.nominalV,
    required this.maxV,
    this.frequencyMinHz,
    this.frequencyMaxHz,
  }) {
    for (final value in [minV, nominalV, maxV]) {
      _positive(value, 'voltage');
    }
    if (minV > nominalV || nominalV > maxV) {
      throw ArgumentError('Expected minV <= nominalV <= maxV.');
    }
    if (currentKind == PowerCurrentKind.ac) {
      if (frequencyMinHz == null || frequencyMaxHz == null) {
        throw ArgumentError('AC requires explicit frequency bounds.');
      }
      _positive(frequencyMinHz!, 'frequencyMinHz');
      _positive(frequencyMaxHz!, 'frequencyMaxHz');
      if (frequencyMinHz! > frequencyMaxHz!) {
        throw ArgumentError('Frequency bounds are reversed.');
      }
    } else if (frequencyMinHz != null || frequencyMaxHz != null) {
      throw ArgumentError('DC cannot declare AC frequency.');
    }
  }

  factory PowerVoltageEnvelope.fromMap(Map<String, Object?> map) {
    _keys(map, {
      'currentKind',
      'minV',
      'nominalV',
      'maxV',
      'frequencyMinHz',
      'frequencyMaxHz',
      'terminalConvention'
    });
    final kind = switch (map['currentKind']) {
      'AC' => PowerCurrentKind.ac,
      'DC' => PowerCurrentKind.dc,
      _ => throw const FormatException('Unknown current kind.'),
    };
    if (map['terminalConvention'] !=
        (kind == PowerCurrentKind.ac ? 'AC_LN' : 'PLUS_MINUS')) {
      throw const FormatException(
          'Terminal convention does not match current kind.');
    }
    return PowerVoltageEnvelope(
      currentKind: kind,
      minV: PowerRational.fromWireDecimal(map['minV']),
      nominalV: PowerRational.fromWireDecimal(map['nominalV']),
      maxV: PowerRational.fromWireDecimal(map['maxV']),
      frequencyMinHz: map['frequencyMinHz'] == null
          ? null
          : PowerRational.fromWireDecimal(map['frequencyMinHz']),
      frequencyMaxHz: map['frequencyMaxHz'] == null
          ? null
          : PowerRational.fromWireDecimal(map['frequencyMaxHz']),
    );
  }

  final PowerCurrentKind currentKind;
  final PowerRational minV;
  final PowerRational nominalV;
  final PowerRational maxV;
  final PowerRational? frequencyMinHz;
  final PowerRational? frequencyMaxHz;

  Map<String, Object?> toMap() => {
        'currentKind': currentKind == PowerCurrentKind.ac ? 'AC' : 'DC',
        'minV': minV.toWireDecimal(),
        'nominalV': nominalV.toWireDecimal(),
        'maxV': maxV.toWireDecimal(),
        'frequencyMinHz': frequencyMinHz?.toWireDecimal(),
        'frequencyMaxHz': frequencyMaxHz?.toWireDecimal(),
        'terminalConvention':
            currentKind == PowerCurrentKind.ac ? 'AC_LN' : 'PLUS_MINUS',
      };
}

/// Typed scenario demand. Missing demand is represented by an absent binding;
/// a present demand may explicitly be zero (RM02), never a nameplate fallback.
sealed class PowerDemand {
  const PowerDemand();

  factory PowerDemand.fromMap(Map<String, Object?> map) {
    switch (map['kind']) {
      case 'DC_CONSTANT_CURRENT':
        _keys(map, {'kind', 'currentA'});
        return DcConstantCurrentDemand(
            PowerRational.fromWireDecimal(map['currentA']));
      case 'DC_CONSTANT_POWER':
        _keys(map, {'kind', 'powerW'});
        return DcConstantPowerDemand(
            PowerRational.fromWireDecimal(map['powerW']));
      case 'AC_POWER':
        _keys(map, {'kind', 'powerW', 'apparentVa'});
        return AcPowerDemand.withApparentPower(
          powerW: PowerRational.fromWireDecimal(map['powerW']),
          apparentVa: PowerRational.fromWireDecimal(map['apparentVa']),
        );
      case 'AC_POWER_PF':
        _keys(map, {'kind', 'powerW', 'powerFactor'});
        return AcPowerDemand.withPowerFactor(
          powerW: PowerRational.fromWireDecimal(map['powerW']),
          powerFactor: PowerRational.fromWireDecimal(map['powerFactor']),
        );
      default:
        throw const FormatException('Unknown power demand kind.');
    }
  }

  Map<String, Object?> toMap();
}

final class DcConstantCurrentDemand extends PowerDemand {
  DcConstantCurrentDemand(this.currentA) {
    _nonnegative(currentA, 'currentA');
  }
  final PowerRational currentA;
  @override
  Map<String, Object?> toMap() =>
      {'kind': 'DC_CONSTANT_CURRENT', 'currentA': currentA.toWireDecimal()};
}

final class DcConstantPowerDemand extends PowerDemand {
  DcConstantPowerDemand(this.powerW) {
    _nonnegative(powerW, 'powerW');
  }
  final PowerRational powerW;
  @override
  Map<String, Object?> toMap() =>
      {'kind': 'DC_CONSTANT_POWER', 'powerW': powerW.toWireDecimal()};
}

enum AcPowerDemandBasis { apparentPower, powerFactor }

final class AcPowerDemand extends PowerDemand {
  AcPowerDemand.withApparentPower(
      {required this.powerW, required PowerRational apparentVa})
      : basis = AcPowerDemandBasis.apparentPower,
        declaredApparentVa = apparentVa,
        declaredPowerFactor = null {
    _nonnegative(powerW, 'powerW');
    _nonnegative(apparentVa, 'apparentVa');
    if (powerW > apparentVa)
      throw ArgumentError('Real power cannot exceed apparent power.');
  }

  AcPowerDemand.withPowerFactor(
      {required this.powerW, required PowerRational powerFactor})
      : basis = AcPowerDemandBasis.powerFactor,
        declaredPowerFactor = powerFactor,
        declaredApparentVa = null {
    _nonnegative(powerW, 'powerW');
    _unitFactor(powerFactor, 'powerFactor');
  }

  final AcPowerDemandBasis basis;
  final PowerRational powerW;
  final PowerRational? declaredApparentVa;
  final PowerRational? declaredPowerFactor;

  /// Exact derived value; never substitutes VA for W in the input contract.
  PowerRational get apparentVa =>
      declaredApparentVa ?? powerW / declaredPowerFactor!;

  @override
  Map<String, Object?> toMap() => switch (basis) {
        AcPowerDemandBasis.apparentPower => {
            'kind': 'AC_POWER',
            'powerW': powerW.toWireDecimal(),
            'apparentVa': declaredApparentVa!.toWireDecimal()
          },
        AcPowerDemandBasis.powerFactor => {
            'kind': 'AC_POWER_PF',
            'powerW': powerW.toWireDecimal(),
            'powerFactor': declaredPowerFactor!.toWireDecimal()
          },
      };
}

enum PowerIdleAccounting { excludesSeparateIdle, includesIdle }

/// Constant-efficiency definition. Graph evaluation and own-load uniqueness
/// remain the responsibility of the subsequent transfer/graph packages.
final class PowerLossDefinition {
  PowerLossDefinition(
      {required this.efficiency,
      required this.idleW,
      required this.idleAccounting}) {
    _unitFactor(efficiency, 'efficiency');
    _nonnegative(idleW, 'idleW');
    if (idleAccounting == PowerIdleAccounting.includesIdle && !idleW.isZero) {
      throw ArgumentError(
          'An inclusive efficiency cannot add separate idle power.');
    }
  }
  factory PowerLossDefinition.fromMap(Map<String, Object?> map) {
    _keys(map, {'efficiency', 'idleW', 'idleAccounting'});
    return PowerLossDefinition(
      efficiency: PowerRational.fromWireDecimal(map['efficiency']),
      idleW: PowerRational.fromWireDecimal(map['idleW']),
      idleAccounting: switch (map['idleAccounting']) {
        'EXCLUDES_SEPARATE_IDLE' => PowerIdleAccounting.excludesSeparateIdle,
        'INCLUDES_IDLE' => PowerIdleAccounting.includesIdle,
        _ => throw const FormatException('Unknown idle accounting basis.'),
      },
    );
  }

  final PowerRational efficiency;
  final PowerRational idleW;
  final PowerIdleAccounting idleAccounting;
  Map<String, Object?> toMap() => {
        'efficiency': efficiency.toWireDecimal(),
        'idleW': idleW.toWireDecimal(),
        'idleAccounting': idleAccounting == PowerIdleAccounting.includesIdle
            ? 'INCLUDES_IDLE'
            : 'EXCLUDES_SEPARATE_IDLE',
      };
}

void _keys(Map<String, Object?> map, Set<String> keys) {
  if (map.length != keys.length || !keys.every(map.containsKey)) {
    throw FormatException('Expected exactly: ${keys.join(', ')}.');
  }
}

void _nonnegative(PowerRational value, String field) {
  if (value.isNegative)
    throw ArgumentError.value(value, field, 'Must be nonnegative.');
}

void _positive(PowerRational value, String field) {
  if (value <= PowerRational.zero)
    throw ArgumentError.value(value, field, 'Must be positive.');
}

void _unitFactor(PowerRational value, String field) {
  _positive(value, field);
  if (value > PowerRational.one)
    throw ArgumentError.value(value, field, 'Must be <= 1.');
}
