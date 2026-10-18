import 'package:engineering_core/engineering_core_elv5.dart';

final class Elv5AmpacitySectionContract {
  Elv5AmpacitySectionContract({
    required String routeSectionId,
    required String cableRunId,
    required String cableId,
    required String expectedEnvironmentProfileId,
    required String expectedEnvironmentEditionId,
    required String expectedEnvironmentContentHash,
    required this.referenceRow,
    required this.temperatureCorrection,
    required this.groupingCorrection,
    Iterable<Elv5AmpacityAdditionalCorrection> additionalCorrections = const [],
  }) : routeSectionId = _text(routeSectionId, 'routeSectionId'),
       cableRunId = _text(cableRunId, 'cableRunId'),
       cableId = _text(cableId, 'cableId'),
       expectedEnvironmentProfileId = _text(
         expectedEnvironmentProfileId,
         'expectedEnvironmentProfileId',
       ),
       expectedEnvironmentEditionId = _text(
         expectedEnvironmentEditionId,
         'expectedEnvironmentEditionId',
       ),
       expectedEnvironmentContentHash = _sha(
         expectedEnvironmentContentHash,
         'expectedEnvironmentContentHash',
       ),
       additionalCorrections = List.unmodifiable(
         _sortedAdditional(additionalCorrections),
       );

  static const schema = 'electra.elv5-ampacity-section-contract.v1';

  final String routeSectionId;
  final String cableRunId;
  final String cableId;
  final String expectedEnvironmentProfileId;
  final String expectedEnvironmentEditionId;
  final String expectedEnvironmentContentHash;
  final Elv5AmpacityReferenceRow referenceRow;
  final Elv5AmpacityTemperatureCorrection temperatureCorrection;
  final Elv5AmpacityGroupingCorrection groupingCorrection;
  final List<Elv5AmpacityAdditionalCorrection> additionalCorrections;

  Map<String, Object?> toCanonicalValue() => <String, Object?>{
    'schema': schema,
    'routeSectionId': routeSectionId,
    'cableRunId': cableRunId,
    'cableId': cableId,
    'expectedEnvironmentProfileId': expectedEnvironmentProfileId,
    'expectedEnvironmentEditionId': expectedEnvironmentEditionId,
    'expectedEnvironmentContentHash': expectedEnvironmentContentHash,
    'referenceRow': referenceRow.toCanonicalValue(),
    'temperatureCorrection': temperatureCorrection.toCanonicalValue(),
    'groupingCorrection': groupingCorrection.toCanonicalValue(),
    'additionalCorrections': <Object?>[
      for (final correction in additionalCorrections)
        correction.toCanonicalValue(),
    ],
  };

  factory Elv5AmpacitySectionContract.fromMap(Map<String, Object?> map) {
    _exact(map, const <String>{
      'schema',
      'routeSectionId',
      'cableRunId',
      'cableId',
      'expectedEnvironmentProfileId',
      'expectedEnvironmentEditionId',
      'expectedEnvironmentContentHash',
      'referenceRow',
      'temperatureCorrection',
      'groupingCorrection',
      'additionalCorrections',
    }, 'ampacity section contract');
    if (map['schema'] != schema) {
      throw const FormatException(
        'Unsupported ampacity section contract schema.',
      );
    }
    final additional = map['additionalCorrections'];
    if (additional is! List) {
      throw const FormatException('additionalCorrections must be array.');
    }
    return Elv5AmpacitySectionContract(
      routeSectionId: _mapText(map, 'routeSectionId'),
      cableRunId: _mapText(map, 'cableRunId'),
      cableId: _mapText(map, 'cableId'),
      expectedEnvironmentProfileId: _mapText(
        map,
        'expectedEnvironmentProfileId',
      ),
      expectedEnvironmentEditionId: _mapText(
        map,
        'expectedEnvironmentEditionId',
      ),
      expectedEnvironmentContentHash: _mapText(
        map,
        'expectedEnvironmentContentHash',
      ),
      referenceRow: _referenceRow(_map(map['referenceRow'], 'referenceRow')),
      temperatureCorrection: _temperature(
        _map(map['temperatureCorrection'], 'temperatureCorrection'),
      ),
      groupingCorrection: _grouping(
        _map(map['groupingCorrection'], 'groupingCorrection'),
      ),
      additionalCorrections: <Elv5AmpacityAdditionalCorrection>[
        for (final raw in additional)
          _additional(_map(raw, 'additionalCorrection')),
      ],
    );
  }
}

final class Elv5AmpacitySectionContractSnapshot {
  const Elv5AmpacitySectionContractSnapshot({
    required this.bindingId,
    required this.bindingRevision,
    required this.evidenceRef,
    required this.contentHash,
    required this.contract,
  });

  final String bindingId;
  final int bindingRevision;
  final String evidenceRef;
  final String contentHash;
  final Elv5AmpacitySectionContract contract;
}

abstract interface class Elv5AmpacitySectionContractSource {
  Future<Elv5AmpacitySectionContractSnapshot?> loadActiveForSection({
    required String projectId,
    required String designRevisionId,
    required String routeSectionId,
  });
}

final class ReplaceElv5AmpacitySectionContractCommand {
  ReplaceElv5AmpacitySectionContractCommand({
    required this.projectId,
    required this.designRevisionId,
    required this.expectedDesignRevision,
    required this.bindingId,
    required this.expectedBindingRevision,
    required this.contract,
  }) {
    if (projectId.trim().isEmpty ||
        designRevisionId.trim().isEmpty ||
        bindingId.trim().isEmpty) {
      throw ArgumentError('Ampacity contract command identity is required.');
    }
    if (expectedDesignRevision < 1) {
      throw ArgumentError('expectedDesignRevision must be >= 1.');
    }
    if (expectedBindingRevision != null && expectedBindingRevision! < 1) {
      throw ArgumentError(
        'expectedBindingRevision must be >= 1 when supplied.',
      );
    }
  }

  final String projectId;
  final String designRevisionId;
  final int expectedDesignRevision;
  final String bindingId;
  final int? expectedBindingRevision;
  final Elv5AmpacitySectionContract contract;
}

abstract interface class Elv5AmpacitySectionContractWriter {
  Future<void> replace(ReplaceElv5AmpacitySectionContractCommand command);
}

Elv5AmpacityReferenceRow _referenceRow(Map<String, Object?> map) {
  _exact(map, const <String>{
    'conductorCrossSectionMm2',
    'conductorMaterialCode',
    'insulationSystemCode',
    'referenceAmbientTemperatureC',
    'installationMethodCode',
    'loadedConductors',
    'baseAllowableCurrentA',
    'evidenceRef',
    'evidenceContentHash',
  }, 'ampacity reference row');
  final loaded = map['loadedConductors'];
  if (loaded is! int)
    throw const FormatException('loadedConductors must be integer.');
  return Elv5AmpacityReferenceRow(
    conductorCrossSectionMm2: Elv5Rational.fromMap(
      _map(map['conductorCrossSectionMm2'], 'conductorCrossSectionMm2'),
    ),
    conductorMaterialCode: _mapText(map, 'conductorMaterialCode'),
    insulationSystemCode: _mapText(map, 'insulationSystemCode'),
    referenceAmbientTemperatureC: Elv5Rational.fromMap(
      _map(map['referenceAmbientTemperatureC'], 'referenceAmbientTemperatureC'),
    ),
    installationMethodCode: _mapText(map, 'installationMethodCode'),
    loadedConductors: loaded,
    baseAllowableCurrentA: Elv5Rational.fromMap(
      _map(map['baseAllowableCurrentA'], 'baseAllowableCurrentA'),
    ),
    evidenceRef: _mapText(map, 'evidenceRef'),
    evidenceContentHash: _mapText(map, 'evidenceContentHash'),
  );
}

Elv5AmpacityTemperatureCorrection _temperature(Map<String, Object?> map) {
  _exact(map, const <String>{
    'actualAmbientTemperatureC',
    'factor',
    'evidenceRef',
    'evidenceContentHash',
  }, 'temperature correction');
  return Elv5AmpacityTemperatureCorrection(
    actualAmbientTemperatureC: Elv5Rational.fromMap(
      _map(map['actualAmbientTemperatureC'], 'actualAmbientTemperatureC'),
    ),
    factor: Elv5Rational.fromMap(_map(map['factor'], 'factor')),
    evidenceRef: _mapText(map, 'evidenceRef'),
    evidenceContentHash: _mapText(map, 'evidenceContentHash'),
  );
}

Elv5AmpacityGroupingCorrection _grouping(Map<String, Object?> map) {
  _exact(map, const <String>{
    'groupedCableOrCircuitCount',
    'arrangementCode',
    'factor',
    'evidenceRef',
    'evidenceContentHash',
  }, 'grouping correction');
  final count = map['groupedCableOrCircuitCount'];
  if (count is! int) {
    throw const FormatException('groupedCableOrCircuitCount must be integer.');
  }
  return Elv5AmpacityGroupingCorrection(
    groupedCableOrCircuitCount: count,
    arrangementCode: _mapText(map, 'arrangementCode'),
    factor: Elv5Rational.fromMap(_map(map['factor'], 'factor')),
    evidenceRef: _mapText(map, 'evidenceRef'),
    evidenceContentHash: _mapText(map, 'evidenceContentHash'),
  );
}

Elv5AmpacityAdditionalCorrection _additional(Map<String, Object?> map) {
  _exact(map, const <String>{
    'code',
    'factor',
    'evidenceRef',
    'evidenceContentHash',
  }, 'additional correction');
  return Elv5AmpacityAdditionalCorrection(
    code: _mapText(map, 'code'),
    factor: Elv5Rational.fromMap(_map(map['factor'], 'factor')),
    evidenceRef: _mapText(map, 'evidenceRef'),
    evidenceContentHash: _mapText(map, 'evidenceContentHash'),
  );
}

List<Elv5AmpacityAdditionalCorrection> _sortedAdditional(
  Iterable<Elv5AmpacityAdditionalCorrection> values,
) {
  final result = values.toList()..sort((a, b) => a.code.compareTo(b.code));
  final seen = <String>{};
  for (final item in result) {
    if (!seen.add(item.code)) {
      throw ArgumentError(
        'Duplicate ampacity additional correction: ${item.code}',
      );
    }
  }
  return result;
}

Map<String, Object?> _map(Object? value, String field) {
  if (value is! Map) throw FormatException('$field must be object.');
  return Map<String, Object?>.from(value);
}

String _mapText(Map<String, Object?> map, String field) {
  final value = map[field];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$field must be non-empty text.');
  }
  return value.trim();
}

String _text(String value, String field) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, field, 'Must not be empty.');
  }
  return normalized;
}

String _sha(String value, String field) {
  final normalized = _text(value, field).toLowerCase();
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(normalized)) {
    throw ArgumentError.value(value, field, 'Expected lowercase SHA-256.');
  }
  return normalized;
}

void _exact(Map<String, Object?> map, Set<String> expected, String field) {
  final actual = map.keys.toSet();
  if (actual.length != expected.length ||
      actual.difference(expected).isNotEmpty ||
      expected.difference(actual).isNotEmpty) {
    throw FormatException('$field has missing or unknown fields.');
  }
}
