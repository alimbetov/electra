import '../numeric/rational.dart';

/// Exact ELV5 engineering contract for cable allowable continuous current Iz.
///
/// This contract deliberately does not own connected-load current (Ib),
/// protective-device selection (In), voltage drop, short-circuit withstand or
/// jurisdictional compliance. It only derives Iz from an immutable selected
/// reference row and explicit correction factors.
final class Elv5AmpacityReferenceRow {
  Elv5AmpacityReferenceRow({
    required this.conductorCrossSectionMm2,
    required String conductorMaterialCode,
    required String insulationSystemCode,
    required this.referenceAmbientTemperatureC,
    required String installationMethodCode,
    required this.loadedConductors,
    required this.baseAllowableCurrentA,
    required String evidenceRef,
    required String evidenceContentHash,
  })  : conductorMaterialCode = _code(
          conductorMaterialCode,
          'conductorMaterialCode',
        ),
        insulationSystemCode = _code(
          insulationSystemCode,
          'insulationSystemCode',
        ),
        installationMethodCode = _code(
          installationMethodCode,
          'installationMethodCode',
        ),
        evidenceRef = _text(evidenceRef, 'evidenceRef'),
        evidenceContentHash = _sha256(
          evidenceContentHash,
          'evidenceContentHash',
        ) {
    _positive(conductorCrossSectionMm2, 'conductorCrossSectionMm2');
    _positive(baseAllowableCurrentA, 'baseAllowableCurrentA');
    if (loadedConductors < 1) {
      throw ArgumentError.value(
        loadedConductors,
        'loadedConductors',
        'Must be >= 1.',
      );
    }
  }

  final Elv5Rational conductorCrossSectionMm2;
  final String conductorMaterialCode;
  final String insulationSystemCode;
  final Elv5Rational referenceAmbientTemperatureC;
  final String installationMethodCode;
  final int loadedConductors;
  final Elv5Rational baseAllowableCurrentA;
  final String evidenceRef;
  final String evidenceContentHash;

  Map<String, Object?> toCanonicalValue() => <String, Object?>{
        'conductorCrossSectionMm2': conductorCrossSectionMm2.toMap(),
        'conductorMaterialCode': conductorMaterialCode,
        'insulationSystemCode': insulationSystemCode,
        'referenceAmbientTemperatureC': referenceAmbientTemperatureC.toMap(),
        'installationMethodCode': installationMethodCode,
        'loadedConductors': loadedConductors,
        'baseAllowableCurrentA': baseAllowableCurrentA.toMap(),
        'evidenceRef': evidenceRef,
        'evidenceContentHash': evidenceContentHash,
      };
}

final class Elv5AmpacityTemperatureCorrection {
  Elv5AmpacityTemperatureCorrection({
    required this.actualAmbientTemperatureC,
    required this.factor,
    required String evidenceRef,
    required String evidenceContentHash,
  })  : evidenceRef = _text(evidenceRef, 'evidenceRef'),
        evidenceContentHash = _sha256(
          evidenceContentHash,
          'evidenceContentHash',
        ) {
    _positive(factor, 'temperatureFactor');
  }

  final Elv5Rational actualAmbientTemperatureC;
  final Elv5Rational factor;
  final String evidenceRef;
  final String evidenceContentHash;

  Map<String, Object?> toCanonicalValue() => <String, Object?>{
        'actualAmbientTemperatureC': actualAmbientTemperatureC.toMap(),
        'factor': factor.toMap(),
        'evidenceRef': evidenceRef,
        'evidenceContentHash': evidenceContentHash,
      };
}

final class Elv5AmpacityGroupingCorrection {
  Elv5AmpacityGroupingCorrection({
    required this.groupedCableOrCircuitCount,
    required String arrangementCode,
    required this.factor,
    required String evidenceRef,
    required String evidenceContentHash,
  })  : arrangementCode = _code(arrangementCode, 'arrangementCode'),
        evidenceRef = _text(evidenceRef, 'evidenceRef'),
        evidenceContentHash = _sha256(
          evidenceContentHash,
          'evidenceContentHash',
        ) {
    if (groupedCableOrCircuitCount < 1) {
      throw ArgumentError.value(
        groupedCableOrCircuitCount,
        'groupedCableOrCircuitCount',
        'Must be >= 1.',
      );
    }
    _positive(factor, 'groupingFactor');
  }

  final int groupedCableOrCircuitCount;
  final String arrangementCode;
  final Elv5Rational factor;
  final String evidenceRef;
  final String evidenceContentHash;

  Map<String, Object?> toCanonicalValue() => <String, Object?>{
        'groupedCableOrCircuitCount': groupedCableOrCircuitCount,
        'arrangementCode': arrangementCode,
        'factor': factor.toMap(),
        'evidenceRef': evidenceRef,
        'evidenceContentHash': evidenceContentHash,
      };
}

final class Elv5AmpacityAdditionalCorrection {
  Elv5AmpacityAdditionalCorrection({
    required String code,
    required this.factor,
    required String evidenceRef,
    required String evidenceContentHash,
  })  : code = _code(code, 'code'),
        evidenceRef = _text(evidenceRef, 'evidenceRef'),
        evidenceContentHash = _sha256(
          evidenceContentHash,
          'evidenceContentHash',
        ) {
    _positive(factor, 'additionalCorrectionFactor');
  }

  final String code;
  final Elv5Rational factor;
  final String evidenceRef;
  final String evidenceContentHash;

  Map<String, Object?> toCanonicalValue() => <String, Object?>{
        'code': code,
        'factor': factor.toMap(),
        'evidenceRef': evidenceRef,
        'evidenceContentHash': evidenceContentHash,
      };
}

final class Elv5AmpacityInput {
  Elv5AmpacityInput({
    required String cableOrSectionId,
    required this.referenceRow,
    required this.temperatureCorrection,
    required this.groupingCorrection,
    Iterable<Elv5AmpacityAdditionalCorrection> additionalCorrections = const [],
  })  : cableOrSectionId = _text(cableOrSectionId, 'cableOrSectionId'),
        additionalCorrections = List.unmodifiable(
          _normalizeAdditionalCorrections(additionalCorrections),
        );

  final String cableOrSectionId;
  final Elv5AmpacityReferenceRow referenceRow;
  final Elv5AmpacityTemperatureCorrection temperatureCorrection;
  final Elv5AmpacityGroupingCorrection groupingCorrection;
  final List<Elv5AmpacityAdditionalCorrection> additionalCorrections;

  Map<String, Object?> toCanonicalValue() => <String, Object?>{
        'schema': 'electra.elv5-ampacity-input.v1',
        'cableOrSectionId': cableOrSectionId,
        'referenceRow': referenceRow.toCanonicalValue(),
        'temperatureCorrection': temperatureCorrection.toCanonicalValue(),
        'groupingCorrection': groupingCorrection.toCanonicalValue(),
        'additionalCorrections': <Object?>[
          for (final item in additionalCorrections) item.toCanonicalValue(),
        ],
      };
}

final class Elv5AmpacityResult {
  const Elv5AmpacityResult({
    required this.baseAllowableCurrentA,
    required this.temperatureFactor,
    required this.groupingFactor,
    required this.additionalFactorProduct,
    required this.allowableCurrentIzA,
  });

  final Elv5Rational baseAllowableCurrentA;
  final Elv5Rational temperatureFactor;
  final Elv5Rational groupingFactor;
  final Elv5Rational additionalFactorProduct;
  final Elv5Rational allowableCurrentIzA;

  Map<String, Object?> toCanonicalValue() => <String, Object?>{
        'schema': 'electra.elv5-ampacity-result.v1',
        'baseAllowableCurrentA': baseAllowableCurrentA.toMap(),
        'temperatureFactor': temperatureFactor.toMap(),
        'groupingFactor': groupingFactor.toMap(),
        'additionalFactorProduct': additionalFactorProduct.toMap(),
        'allowableCurrentIzA': allowableCurrentIzA.toMap(),
      };
}

final class Elv5AmpacityKernel {
  const Elv5AmpacityKernel();

  Elv5AmpacityResult evaluate(Elv5AmpacityInput input) {
    var additionalProduct = Elv5Rational.one;
    for (final correction in input.additionalCorrections) {
      additionalProduct = additionalProduct * correction.factor;
    }

    final iz = input.referenceRow.baseAllowableCurrentA *
        input.temperatureCorrection.factor *
        input.groupingCorrection.factor *
        additionalProduct;

    return Elv5AmpacityResult(
      baseAllowableCurrentA: input.referenceRow.baseAllowableCurrentA,
      temperatureFactor: input.temperatureCorrection.factor,
      groupingFactor: input.groupingCorrection.factor,
      additionalFactorProduct: additionalProduct,
      allowableCurrentIzA: iz,
    );
  }
}

List<Elv5AmpacityAdditionalCorrection> _normalizeAdditionalCorrections(
  Iterable<Elv5AmpacityAdditionalCorrection> values,
) {
  final result = values.toList()..sort((a, b) => a.code.compareTo(b.code));
  final seen = <String>{};
  for (final item in result) {
    if (!seen.add(item.code)) {
      throw ArgumentError('Duplicate ampacity correction code: ${item.code}');
    }
  }
  return result;
}

void _positive(Elv5Rational value, String field) {
  if (value <= Elv5Rational.zero) {
    throw ArgumentError.value(value, field, 'Must be > 0.');
  }
}

String _text(String value, String field) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, field, 'Must not be empty.');
  }
  return normalized;
}

String _code(String value, String field) => _text(value, field).toUpperCase();

String _sha256(String value, String field) {
  final normalized = _text(value, field).toLowerCase();
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(normalized)) {
    throw ArgumentError.value(value, field, 'Expected lowercase SHA-256.');
  }
  return normalized;
}
