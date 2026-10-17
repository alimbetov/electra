import 'package:engineering_core/engineering_core_elv5.dart';

enum Fa06ContractCase { activeNotification, startupInrush }

final class Fa06CaseContract {
  Fa06CaseContract({
    required this.operatingCase,
    required String stateCode,
    required String scenarioId,
    required String segmentId,
    required String pwr01SubjectKind,
    required String pwr01SubjectId,
    required String pwr03SubjectKind,
    required String pwr03SubjectId,
  })  : stateCode = _text(stateCode, 'stateCode'),
        scenarioId = _text(scenarioId, 'scenarioId'),
        segmentId = _text(segmentId, 'segmentId'),
        pwr01SubjectKind = _text(pwr01SubjectKind, 'pwr01SubjectKind'),
        pwr01SubjectId = _text(pwr01SubjectId, 'pwr01SubjectId'),
        pwr03SubjectKind = _text(pwr03SubjectKind, 'pwr03SubjectKind'),
        pwr03SubjectId = _text(pwr03SubjectId, 'pwr03SubjectId');

  final Fa06ContractCase operatingCase;
  final String stateCode;
  final String scenarioId;
  final String segmentId;
  final String pwr01SubjectKind;
  final String pwr01SubjectId;
  final String pwr03SubjectKind;
  final String pwr03SubjectId;

  Map<String, Object?> toCanonicalValue() => <String, Object?>{
        'operatingCase': switch (operatingCase) {
          Fa06ContractCase.activeNotification => 'ACTIVE_NOTIFICATION',
          Fa06ContractCase.startupInrush => 'STARTUP_INRUSH',
        },
        'stateCode': stateCode,
        'scenarioId': scenarioId,
        'segmentId': segmentId,
        'pwr01SubjectKind': pwr01SubjectKind,
        'pwr01SubjectId': pwr01SubjectId,
        'pwr03SubjectKind': pwr03SubjectKind,
        'pwr03SubjectId': pwr03SubjectId,
      };

  factory Fa06CaseContract.fromMap(Map<String, Object?> map) {
    _exact(map, const <String>{
      'operatingCase',
      'stateCode',
      'scenarioId',
      'segmentId',
      'pwr01SubjectKind',
      'pwr01SubjectId',
      'pwr03SubjectKind',
      'pwr03SubjectId',
    }, 'FA06 case');
    final operatingCase = switch (_mapText(map, 'operatingCase')) {
      'ACTIVE_NOTIFICATION' => Fa06ContractCase.activeNotification,
      'STARTUP_INRUSH' => Fa06ContractCase.startupInrush,
      final value => throw FormatException('Unsupported FA06 operatingCase: $value'),
    };
    return Fa06CaseContract(
      operatingCase: operatingCase,
      stateCode: _mapText(map, 'stateCode'),
      scenarioId: _mapText(map, 'scenarioId'),
      segmentId: _mapText(map, 'segmentId'),
      pwr01SubjectKind: _mapText(map, 'pwr01SubjectKind'),
      pwr01SubjectId: _mapText(map, 'pwr01SubjectId'),
      pwr03SubjectKind: _mapText(map, 'pwr03SubjectKind'),
      pwr03SubjectId: _mapText(map, 'pwr03SubjectId'),
    );
  }
}

final class Fa06SupervisionFaultResult {
  Fa06SupervisionFaultResult({
    required String faultCode,
    required this.passed,
  }) : faultCode = _text(faultCode, 'faultCode');

  final String faultCode;
  final bool passed;

  Map<String, Object?> toCanonicalValue() => <String, Object?>{
        'faultCode': faultCode,
        'passed': passed,
      };

  factory Fa06SupervisionFaultResult.fromMap(Map<String, Object?> map) {
    _exact(map, const <String>{'faultCode', 'passed'}, 'FA06 supervision fault');
    final passed = map['passed'];
    if (passed is! bool) {
      throw const FormatException('FA06 supervision fault passed must be boolean.');
    }
    return Fa06SupervisionFaultResult(
      faultCode: _mapText(map, 'faultCode'),
      passed: passed,
    );
  }
}

final class Fa06SupervisionContract {
  Fa06SupervisionContract({
    required this.required,
    required this.modelSupported,
    Iterable<Fa06SupervisionFaultResult> faultResults = const [],
    this.modelCode,
    this.evidenceRef,
    this.evidenceContentHash,
  }) : faultResults = List.unmodifiable(_faultResults(faultResults)) {
    if (required && modelCode == null) {
      throw ArgumentError('FA06 required supervision needs modelCode.');
    }
    if (required && modelSupported && evidenceRef == null) {
      throw ArgumentError('FA06 supported supervision needs evidenceRef.');
    }
    if (required && modelSupported && this.faultResults.isEmpty) {
      throw ArgumentError('FA06 supported supervision needs explicit fault results.');
    }
    if (evidenceContentHash != null) {
      _sha(evidenceContentHash!, 'evidenceContentHash');
    }
  }

  final bool required;
  final bool modelSupported;
  final List<Fa06SupervisionFaultResult> faultResults;
  final String? modelCode;
  final String? evidenceRef;
  final String? evidenceContentHash;

  bool get passed =>
      !required ||
      (modelSupported &&
          faultResults.isNotEmpty &&
          faultResults.every((value) => value.passed));

  Map<String, Object?> toCanonicalValue() => <String, Object?>{
        'required': required,
        'modelSupported': modelSupported,
        'modelCode': modelCode,
        'evidenceRef': evidenceRef,
        'evidenceContentHash': evidenceContentHash,
        'faultResults': [
          for (final value in faultResults) value.toCanonicalValue(),
        ],
      };

  factory Fa06SupervisionContract.fromMap(Map<String, Object?> map) {
    _exact(map, const <String>{
      'required',
      'modelSupported',
      'modelCode',
      'evidenceRef',
      'evidenceContentHash',
      'faultResults',
    }, 'FA06 supervision');
    final required = map['required'];
    final supported = map['modelSupported'];
    final rawFaults = map['faultResults'];
    if (required is! bool || supported is! bool || rawFaults is! List) {
      throw const FormatException('FA06 supervision field type mismatch.');
    }
    return Fa06SupervisionContract(
      required: required,
      modelSupported: supported,
      modelCode: _nullableText(map['modelCode'], 'modelCode'),
      evidenceRef: _nullableText(map['evidenceRef'], 'evidenceRef'),
      evidenceContentHash:
          _nullableText(map['evidenceContentHash'], 'evidenceContentHash'),
      faultResults: <Fa06SupervisionFaultResult>[
        for (final raw in rawFaults)
          Fa06SupervisionFaultResult.fromMap(_object(raw, 'FA06 supervision fault')),
      ],
    );
  }
}

final class Fa06NotificationContract {
  Fa06NotificationContract({
    required String circuitId,
    required this.deviceLimit,
    required this.outputCurrentLimitA,
    required this.minimumTerminalVoltageV,
    required this.maximumTerminalVoltageV,
    required Iterable<Fa06CaseContract> cases,
    required Map<String, String> terminalLoadIdByDeviceId,
    required this.supervision,
  })  : circuitId = _text(circuitId, 'circuitId'),
        cases = List.unmodifiable(_cases(cases)),
        terminalLoadIdByDeviceId = Map.unmodifiable(
          _terminalMap(terminalLoadIdByDeviceId),
        ) {
    if (deviceLimit < 0) {
      throw ArgumentError('FA06 deviceLimit must be nonnegative.');
    }
    if (outputCurrentLimitA < Elv5Rational.zero ||
        minimumTerminalVoltageV < Elv5Rational.zero ||
        maximumTerminalVoltageV < minimumTerminalVoltageV) {
      throw ArgumentError('FA06 electrical limits are invalid.');
    }
    if (this.cases.isEmpty ||
        !this.cases.any(
          (value) => value.operatingCase == Fa06ContractCase.activeNotification,
        )) {
      throw ArgumentError('FA06 ACTIVE_NOTIFICATION case is mandatory.');
    }
    if (this.terminalLoadIdByDeviceId.isEmpty) {
      throw ArgumentError('FA06 terminal mapping must not be empty.');
    }
  }

  static const schema = 'electra.elv5-fa06-notification-contract.v1';
  static const _encoder = Elv5CanonicalJsonV1();

  final String circuitId;
  final int deviceLimit;
  final Elv5Rational outputCurrentLimitA;
  final Elv5Rational minimumTerminalVoltageV;
  final Elv5Rational maximumTerminalVoltageV;
  final List<Fa06CaseContract> cases;
  final Map<String, String> terminalLoadIdByDeviceId;
  final Fa06SupervisionContract supervision;

  String membershipFingerprint(Iterable<String> deviceIds) =>
      _encoder.sha256(<String, Object?>{
        'schema': 'electra.elv5-fa06-membership.v1',
        'circuitId': circuitId,
        'deviceIds': deviceIds.toList()..sort(),
        'terminalLoadIdByDeviceId': <String, Object?>{
          for (final key in (terminalLoadIdByDeviceId.keys.toList()..sort()))
            key: terminalLoadIdByDeviceId[key],
        },
      });

  Map<String, Object?> toCanonicalValue() => <String, Object?>{
        'schema': schema,
        'circuitId': circuitId,
        'deviceLimit': deviceLimit,
        'outputCurrentLimitA': outputCurrentLimitA.toMap(),
        'minimumTerminalVoltageV': minimumTerminalVoltageV.toMap(),
        'maximumTerminalVoltageV': maximumTerminalVoltageV.toMap(),
        'cases': [for (final value in cases) value.toCanonicalValue()],
        'terminalLoadIdByDeviceId': <String, Object?>{
          for (final key in (terminalLoadIdByDeviceId.keys.toList()..sort()))
            key: terminalLoadIdByDeviceId[key],
        },
        'supervision': supervision.toCanonicalValue(),
      };

  factory Fa06NotificationContract.fromMap(Map<String, Object?> map) {
    _exact(map, const <String>{
      'schema',
      'circuitId',
      'deviceLimit',
      'outputCurrentLimitA',
      'minimumTerminalVoltageV',
      'maximumTerminalVoltageV',
      'cases',
      'terminalLoadIdByDeviceId',
      'supervision',
    }, 'FA06 notification contract');
    if (map['schema'] != schema) {
      throw const FormatException('Unsupported FA06 contract schema.');
    }
    final deviceLimit = map['deviceLimit'];
    final rawCases = map['cases'];
    final terminalMap = map['terminalLoadIdByDeviceId'];
    if (deviceLimit is! int || rawCases is! List || terminalMap is! Map) {
      throw const FormatException('FA06 contract field type mismatch.');
    }
    final terminals = <String, String>{};
    for (final entry in terminalMap.entries) {
      if (entry.key is! String || entry.value is! String) {
        throw const FormatException('FA06 terminal map must contain text pairs.');
      }
      terminals[_text(entry.key as String, 'deviceId')] =
          _text(entry.value as String, 'terminalLoadId');
    }
    return Fa06NotificationContract(
      circuitId: _mapText(map, 'circuitId'),
      deviceLimit: deviceLimit,
      outputCurrentLimitA: _rational(map['outputCurrentLimitA'], 'outputCurrentLimitA'),
      minimumTerminalVoltageV:
          _rational(map['minimumTerminalVoltageV'], 'minimumTerminalVoltageV'),
      maximumTerminalVoltageV:
          _rational(map['maximumTerminalVoltageV'], 'maximumTerminalVoltageV'),
      cases: <Fa06CaseContract>[
        for (final raw in rawCases)
          Fa06CaseContract.fromMap(_object(raw, 'FA06 case')),
      ],
      terminalLoadIdByDeviceId: terminals,
      supervision: Fa06SupervisionContract.fromMap(
        _object(map['supervision'], 'supervision'),
      ),
    );
  }
}

final class Fa06NotificationContractSnapshot {
  const Fa06NotificationContractSnapshot({
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
  final Fa06NotificationContract contract;
}

abstract interface class Fa06NotificationContractSource {
  Future<Fa06NotificationContractSnapshot?> loadActiveForCircuit({
    required String projectId,
    required String designRevisionId,
    required String circuitId,
  });
}

List<Fa06CaseContract> _cases(Iterable<Fa06CaseContract> values) {
  final result = values.toList()
    ..sort((a, b) => a.operatingCase.index.compareTo(b.operatingCase.index));
  final seen = <Fa06ContractCase>{};
  for (final value in result) {
    if (!seen.add(value.operatingCase)) {
      throw ArgumentError('FA06 duplicate operating case: ${value.operatingCase}');
    }
  }
  return result;
}

List<Fa06SupervisionFaultResult> _faultResults(
  Iterable<Fa06SupervisionFaultResult> values,
) {
  final result = values.toList()..sort((a, b) => a.faultCode.compareTo(b.faultCode));
  final codes = <String>{};
  for (final value in result) {
    if (!codes.add(value.faultCode)) {
      throw ArgumentError('FA06 duplicate supervision fault: ${value.faultCode}');
    }
  }
  return result;
}

Map<String, String> _terminalMap(Map<String, String> value) {
  final result = <String, String>{};
  final terminalIds = <String>{};
  for (final entry in value.entries) {
    final deviceId = _text(entry.key, 'deviceId');
    final terminalId = _text(entry.value, 'terminalLoadId');
    if (!terminalIds.add(terminalId)) {
      throw ArgumentError('FA06 duplicate terminalLoadId: $terminalId');
    }
    result[deviceId] = terminalId;
  }
  return result;
}

Elv5Rational _rational(Object? raw, String field) {
  if (raw is! Map) throw FormatException('$field must be a rational map.');
  return Elv5Rational.fromMap(Map<String, Object?>.from(raw));
}

Map<String, Object?> _object(Object? value, String field) {
  if (value is! Map) throw FormatException('$field must be an object.');
  return Map<String, Object?>.from(value);
}

String _mapText(Map<String, Object?> map, String field) {
  final value = map[field];
  if (value is! String) throw FormatException('$field must be text.');
  return _text(value, field);
}

String? _nullableText(Object? value, String field) {
  if (value == null) return null;
  if (value is! String) throw FormatException('$field must be text or null.');
  return _text(value, field);
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

void _exact(Map<String, Object?> value, Set<String> expected, String field) {
  final actual = value.keys.toSet();
  if (actual.length != expected.length ||
      actual.difference(expected).isNotEmpty ||
      expected.difference(actual).isNotEmpty) {
    throw FormatException('$field has missing or unknown fields.');
  }
}
