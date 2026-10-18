import 'package:engineering_core/engineering_core_elv5.dart';

enum Fa03ContractModel { radialDc, declaredOneControlPointDc, unsupported }

final class Fa03CaseContract {
  Fa03CaseContract({
    required String caseId,
    required String scenarioId,
    required String segmentId,
    required String pwr03SubjectKind,
    required String pwr03SubjectId,
    required String expectedPwr03InputFingerprint,
    required Map<String, String> terminalLoadIdByTerminalId,
  }) : caseId = _text(caseId, 'caseId'),
       scenarioId = _text(scenarioId, 'scenarioId'),
       segmentId = _text(segmentId, 'segmentId'),
       pwr03SubjectKind = _text(pwr03SubjectKind, 'pwr03SubjectKind'),
       pwr03SubjectId = _text(pwr03SubjectId, 'pwr03SubjectId'),
       expectedPwr03InputFingerprint = _sha(
         expectedPwr03InputFingerprint,
         'expectedPwr03InputFingerprint',
       ),
       terminalLoadIdByTerminalId = Map.unmodifiable(
         _terminalMap(terminalLoadIdByTerminalId),
       );

  final String caseId;
  final String scenarioId;
  final String segmentId;
  final String pwr03SubjectKind;
  final String pwr03SubjectId;
  final String expectedPwr03InputFingerprint;
  final Map<String, String> terminalLoadIdByTerminalId;

  Map<String, Object?> toCanonicalValue() => <String, Object?>{
    'caseId': caseId,
    'scenarioId': scenarioId,
    'segmentId': segmentId,
    'pwr03SubjectKind': pwr03SubjectKind,
    'pwr03SubjectId': pwr03SubjectId,
    'expectedPwr03InputFingerprint': expectedPwr03InputFingerprint,
    'terminalLoadIdByTerminalId': <String, Object?>{
      for (final key in (terminalLoadIdByTerminalId.keys.toList()..sort()))
        key: terminalLoadIdByTerminalId[key],
    },
  };

  factory Fa03CaseContract.fromMap(Map<String, Object?> map) {
    _exact(map, const <String>{
      'caseId',
      'scenarioId',
      'segmentId',
      'pwr03SubjectKind',
      'pwr03SubjectId',
      'expectedPwr03InputFingerprint',
      'terminalLoadIdByTerminalId',
    }, 'FA03 case');
    final rawTerminals = _object(
      map['terminalLoadIdByTerminalId'],
      'terminalLoadIdByTerminalId',
    );
    final terminals = <String, String>{};
    for (final entry in rawTerminals.entries) {
      if (entry.value is! String) {
        throw const FormatException(
          'FA03 terminalLoadIdByTerminalId values must be text.',
        );
      }
      terminals[_text(entry.key, 'terminalId')] = _text(
        entry.value! as String,
        'terminalLoadId',
      );
    }
    return Fa03CaseContract(
      caseId: _mapText(map, 'caseId'),
      scenarioId: _mapText(map, 'scenarioId'),
      segmentId: _mapText(map, 'segmentId'),
      pwr03SubjectKind: _mapText(map, 'pwr03SubjectKind'),
      pwr03SubjectId: _mapText(map, 'pwr03SubjectId'),
      expectedPwr03InputFingerprint: _mapText(
        map,
        'expectedPwr03InputFingerprint',
      ),
      terminalLoadIdByTerminalId: terminals,
    );
  }
}

final class Fa03TerminalVoltageContract {
  Fa03TerminalVoltageContract({
    required String circuitId,
    required this.model,
    required this.minimumTerminalVoltageV,
    required this.maximumTerminalVoltageV,
    required Iterable<Fa03CaseContract> cases,
  }) : circuitId = _text(circuitId, 'circuitId'),
       cases = List.unmodifiable(_cases(cases)) {
    if (minimumTerminalVoltageV < Elv5Rational.zero ||
        maximumTerminalVoltageV < minimumTerminalVoltageV) {
      throw ArgumentError('FA03 voltage limits are invalid.');
    }
    if (this.cases.isEmpty) {
      throw ArgumentError('FA03 requires at least one operating case.');
    }
  }

  static const schema = 'electra.elv5-fa03-terminal-voltage-contract.v1';
  static const _encoder = Elv5CanonicalJsonV1();

  final String circuitId;
  final Fa03ContractModel model;
  final Elv5Rational minimumTerminalVoltageV;
  final Elv5Rational maximumTerminalVoltageV;
  final List<Fa03CaseContract> cases;

  /// Versioned scope identity deliberately excludes scenario-specific PWR-03
  /// input fingerprints. The runtime verifies those fingerprints separately
  /// and also requires the same physical membership closure for every case.
  String get scopeFingerprint => _encoder.sha256(<String, Object?>{
    'schema': 'electra.elv5-fa03-scope.v1',
    'circuitId': circuitId,
    'model': model.name,
    'cases': <Object?>[
      for (final c in cases)
        <String, Object?>{
          'caseId': c.caseId,
          'scenarioId': c.scenarioId,
          'segmentId': c.segmentId,
          'pwr03SubjectKind': c.pwr03SubjectKind,
          'pwr03SubjectId': c.pwr03SubjectId,
          'terminalLoadIdByTerminalId':
              c.toCanonicalValue()['terminalLoadIdByTerminalId'],
        },
    ],
  });

  Map<String, Object?> toCanonicalValue() => <String, Object?>{
    'schema': schema,
    'circuitId': circuitId,
    'model': model.name,
    'minimumTerminalVoltageV': minimumTerminalVoltageV.toMap(),
    'maximumTerminalVoltageV': maximumTerminalVoltageV.toMap(),
    'cases': <Object?>[for (final c in cases) c.toCanonicalValue()],
  };

  factory Fa03TerminalVoltageContract.fromMap(Map<String, Object?> map) {
    _exact(map, const <String>{
      'schema',
      'circuitId',
      'model',
      'minimumTerminalVoltageV',
      'maximumTerminalVoltageV',
      'cases',
    }, 'FA03 terminal voltage contract');
    if (map['schema'] != schema) {
      throw const FormatException('Unsupported FA03 contract schema.');
    }
    final rawCases = map['cases'];
    if (rawCases is! List) {
      throw const FormatException('FA03 cases must be an array.');
    }
    final model = switch (_mapText(map, 'model')) {
      'radialDc' => Fa03ContractModel.radialDc,
      'declaredOneControlPointDc' =>
        Fa03ContractModel.declaredOneControlPointDc,
      'unsupported' => Fa03ContractModel.unsupported,
      final value => throw FormatException('Unsupported FA03 model: $value'),
    };
    return Fa03TerminalVoltageContract(
      circuitId: _mapText(map, 'circuitId'),
      model: model,
      minimumTerminalVoltageV: _rational(
        map['minimumTerminalVoltageV'],
        'minimumTerminalVoltageV',
      ),
      maximumTerminalVoltageV: _rational(
        map['maximumTerminalVoltageV'],
        'maximumTerminalVoltageV',
      ),
      cases: <Fa03CaseContract>[
        for (final raw in rawCases)
          Fa03CaseContract.fromMap(_object(raw, 'FA03 case')),
      ],
    );
  }
}

final class Fa03TerminalVoltageContractSnapshot {
  const Fa03TerminalVoltageContractSnapshot({
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
  final Fa03TerminalVoltageContract contract;
}

abstract interface class Fa03TerminalVoltageContractSource {
  Future<Fa03TerminalVoltageContractSnapshot?> loadActiveForCircuit({
    required String projectId,
    required String designRevisionId,
    required String circuitId,
  });
}

List<Fa03CaseContract> _cases(Iterable<Fa03CaseContract> values) {
  final result = values.toList()..sort((a, b) => a.caseId.compareTo(b.caseId));
  final ids = <String>{};
  for (final value in result) {
    if (!ids.add(value.caseId)) {
      throw ArgumentError('FA03 duplicate caseId: ${value.caseId}');
    }
  }
  return result;
}

Map<String, String> _terminalMap(Map<String, String> input) {
  final result = <String, String>{};
  final loadIds = <String>{};
  for (final entry in input.entries) {
    final terminalId = _text(entry.key, 'terminalId');
    final loadId = _text(entry.value, 'loadId');
    if (!loadIds.add(loadId)) {
      throw ArgumentError('FA03 duplicate physical terminal loadId: $loadId');
    }
    result[terminalId] = loadId;
  }
  if (result.isEmpty) {
    throw ArgumentError('FA03 terminal mapping must not be empty.');
  }
  return result;
}

Map<String, Object?> _object(Object? value, String field) {
  if (value is! Map) throw FormatException('$field must be an object.');
  return Map<String, Object?>.from(value);
}

String _mapText(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! String) throw FormatException('$key must be text.');
  return _text(value, key);
}

String _text(String value, String field) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, field, 'Must not be empty.');
  }
  return normalized;
}

String _sha(String value, String field) {
  final normalized = _text(value, field);
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(normalized)) {
    throw ArgumentError.value(value, field, 'Must be lowercase SHA-256.');
  }
  return normalized;
}

Elv5Rational _rational(Object? value, String field) {
  if (value is! Map) throw FormatException('$field must be a rational map.');
  return Elv5Rational.fromMap(Map<String, Object?>.from(value));
}

void _exact(Map<String, Object?> value, Set<String> expected, String field) {
  final actual = value.keys.toSet();
  if (actual.length != expected.length ||
      actual.difference(expected).isNotEmpty ||
      expected.difference(actual).isNotEmpty) {
    throw FormatException('$field has missing or unknown fields.');
  }
}
