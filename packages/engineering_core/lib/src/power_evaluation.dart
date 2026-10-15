import 'dart:convert';

import 'engineering_hash.dart';
import 'power_numeric.dart';

enum PowerEvaluationScopeKind { segment, sequence }

enum PowerProcessCode { pwr01, pwr02, pwr03, pwr04, pwr05, pwr06 }

enum PowerEvaluationStatus { pass, fail, unresolved, blocked }

enum PowerEvaluationApplicability { applicable, notApplicable }

enum PowerPointerState { current, stale }

final class PowerNodeKeyV2 implements Comparable<PowerNodeKeyV2> {
  PowerNodeKeyV2({
    required String revisionId,
    required String scenarioId,
    required this.scopeKind,
    required String scopeId,
    required this.processCode,
    required String subjectKind,
    required String subjectId,
  })  : revisionId = _text(revisionId, 'revisionId'),
        scenarioId = _text(scenarioId, 'scenarioId'),
        scopeId = _text(scopeId, 'scopeId'),
        subjectKind = _code(subjectKind, 'subjectKind'),
        subjectId = _text(subjectId, 'subjectId');

  final String revisionId;
  final String scenarioId;
  final PowerEvaluationScopeKind scopeKind;
  final String scopeId;
  final PowerProcessCode processCode;
  final String subjectKind;
  final String subjectId;

  List<Object?> toTuple() => [
        'elv4-node-v2',
        revisionId,
        scenarioId,
        scopeKind.name.toUpperCase(),
        scopeId,
        _processWire(processCode),
        subjectKind,
        subjectId,
      ];

  String encode() => canonicalEngineeringJsonV1(toTuple());

  String get sha256 => sha256HexUtf8(encode());

  factory PowerNodeKeyV2.decode(String encoded) {
    final decoded = _decodeCanonicalList(encoded);
    if (decoded.length != 8 || decoded[0] != 'elv4-node-v2') {
      throw const FormatException('Invalid ELV4 logical node key v2.');
    }
    return PowerNodeKeyV2(
      revisionId: decoded[1] as String,
      scenarioId: decoded[2] as String,
      scopeKind: PowerEvaluationScopeKind.values.singleWhere(
        (value) => value.name.toUpperCase() == decoded[3],
      ),
      scopeId: decoded[4] as String,
      processCode: _processFromWire(decoded[5] as String),
      subjectKind: decoded[6] as String,
      subjectId: decoded[7] as String,
    );
  }

  @override
  int compareTo(PowerNodeKeyV2 other) => encode().compareTo(other.encode());

  @override
  bool operator ==(Object other) =>
      other is PowerNodeKeyV2 && encode() == other.encode();

  @override
  int get hashCode => encode().hashCode;
}

final class PowerEvaluationKeyV2 {
  PowerEvaluationKeyV2({
    required this.nodeKey,
    required String evaluationId,
  }) : evaluationId = _text(evaluationId, 'evaluationId');

  final PowerNodeKeyV2 nodeKey;
  final String evaluationId;

  List<Object?> toTuple() => [
        'elv4-evaluation-v2',
        nodeKey.toTuple(),
        evaluationId,
      ];

  String encode() => canonicalEngineeringJsonV1(toTuple());

  factory PowerEvaluationKeyV2.decode(String encoded) {
    final decoded = _decodeCanonicalList(encoded);
    if (decoded.length != 3 || decoded[0] != 'elv4-evaluation-v2') {
      throw const FormatException('Invalid ELV4 evaluation key v2.');
    }
    final nodeTuple = decoded[1];
    if (nodeTuple is! List) {
      throw const FormatException('Evaluation key must embed a logical node tuple.');
    }
    return PowerEvaluationKeyV2(
      nodeKey: PowerNodeKeyV2.decode(canonicalEngineeringJsonV1(nodeTuple)),
      evaluationId: decoded[2] as String,
    );
  }
}

final class PowerEvaluationFinding {
  PowerEvaluationFinding({
    required String code,
    required String severity,
    required String message,
    Iterable<String> sourceRefs = const [],
  })  : code = _code(code, 'code'),
        severity = _code(severity, 'severity'),
        message = _text(message, 'message'),
        sourceRefs = List.unmodifiable(_sortedUniqueTexts(
          sourceRefs,
          field: 'sourceRefs',
        ));

  final String code;
  final String severity;
  final String message;
  final List<String> sourceRefs;

  Map<String, Object?> toMap() => {
        'code': code,
        'severity': severity,
        'message': message,
        'sourceRefs': sourceRefs,
      };
}

final class PowerEvaluationEvidence {
  PowerEvaluationEvidence({
    required String evaluationId,
    required this.nodeKey,
    required String algorithmVersion,
    required String inputSchemaVersion,
    required String outputSchemaVersion,
    String numericPolicyVersion = powerNumericPolicyVersion,
    required String inputFingerprint,
    required this.status,
    required this.applicability,
    required Map<String, Object?> inputs,
    required Map<String, Object?> output,
    Iterable<PowerNodeKeyV2> dependencies = const [],
    Iterable<Map<String, Object?>> quantities = const [],
    Iterable<Map<String, Object?>> arithmeticSteps = const [],
    Iterable<PowerEvaluationFinding> findings = const [],
    Iterable<String> assumptions = const [],
  })  : evaluationId = _text(evaluationId, 'evaluationId'),
        algorithmVersion = _text(algorithmVersion, 'algorithmVersion'),
        inputSchemaVersion = _text(inputSchemaVersion, 'inputSchemaVersion'),
        outputSchemaVersion = _text(outputSchemaVersion, 'outputSchemaVersion'),
        numericPolicyVersion = _text(numericPolicyVersion, 'numericPolicyVersion'),
        inputFingerprint = _sha256(inputFingerprint, 'inputFingerprint'),
        inputs = Map.unmodifiable(inputs),
        output = Map.unmodifiable(output),
        dependencies = List.unmodifiable(_sortedDependencies(dependencies)),
        quantities = List.unmodifiable(
          quantities.map((value) => Map<String, Object?>.unmodifiable(value)),
        ),
        arithmeticSteps = List.unmodifiable(
          arithmeticSteps.map(
            (value) => Map<String, Object?>.unmodifiable(value),
          ),
        ),
        findings = List.unmodifiable(findings),
        assumptions = List.unmodifiable(_sortedUniqueTexts(
          assumptions,
          field: 'assumptions',
        ));

  final String evaluationId;
  final PowerNodeKeyV2 nodeKey;
  final String algorithmVersion;
  final String inputSchemaVersion;
  final String outputSchemaVersion;
  final String numericPolicyVersion;
  final String inputFingerprint;
  final PowerEvaluationStatus status;
  final PowerEvaluationApplicability applicability;
  final Map<String, Object?> inputs;
  final Map<String, Object?> output;
  final List<PowerNodeKeyV2> dependencies;
  final List<Map<String, Object?>> quantities;
  final List<Map<String, Object?>> arithmeticSteps;
  final List<PowerEvaluationFinding> findings;
  final List<String> assumptions;

  PowerEvaluationKeyV2 get key => PowerEvaluationKeyV2(
        nodeKey: nodeKey,
        evaluationId: evaluationId,
      );

  Map<String, Object?> toMap() => {
        'schema': 'electra.elv4-evaluation-evidence.v2',
        'evaluationId': evaluationId,
        'logicalNodeKey': nodeKey.toTuple(),
        'algorithmVersion': algorithmVersion,
        'inputSchemaVersion': inputSchemaVersion,
        'outputSchemaVersion': outputSchemaVersion,
        'numericPolicyVersion': numericPolicyVersion,
        'inputFingerprint': inputFingerprint,
        'status': status.name.toUpperCase(),
        'applicability': applicability.name.toUpperCase(),
        'inputs': inputs,
        'output': output,
        'dependencies': dependencies.map((value) => value.toTuple()).toList(),
        'quantities': quantities,
        'arithmeticSteps': arithmeticSteps,
        'findings': findings.map((value) => value.toMap()).toList(),
        'assumptions': assumptions,
      };

  String get canonicalJson => canonicalEngineeringJsonV1(toMap());
  String get evidenceSha256 => sha256HexUtf8(canonicalJson);
}

final class PowerEvaluationPointer {
  PowerEvaluationPointer({
    required this.nodeKey,
    required this.state,
    required this.generation,
    String? evaluationId,
  }) : evaluationId =
            evaluationId == null ? null : _text(evaluationId, 'evaluationId') {
    if (generation < 1) {
      throw ArgumentError.value(generation, 'generation', 'Must be positive.');
    }
    if (state == PowerPointerState.current && this.evaluationId == null) {
      throw ArgumentError('CURRENT pointer requires an evaluation id.');
    }
  }

  final PowerNodeKeyV2 nodeKey;
  final PowerPointerState state;
  final int generation;
  final String? evaluationId;

  PowerEvaluationPointer markStale() {
    if (state != PowerPointerState.current) {
      throw StateError('Only CURRENT pointer can transition to STALE.');
    }
    return PowerEvaluationPointer(
      nodeKey: nodeKey,
      state: PowerPointerState.stale,
      generation: generation + 1,
      evaluationId: evaluationId,
    );
  }

  PowerEvaluationPointer publish(PowerEvaluationEvidence evidence) {
    if (state != PowerPointerState.stale || evidence.nodeKey != nodeKey) {
      throw StateError('Only matching STALE pointer can publish a new result.');
    }
    return PowerEvaluationPointer(
      nodeKey: nodeKey,
      state: PowerPointerState.current,
      generation: generation + 1,
      evaluationId: evidence.evaluationId,
    );
  }

  static PowerEvaluationPointer firstPublication(PowerEvaluationEvidence evidence) =>
      PowerEvaluationPointer(
        nodeKey: evidence.nodeKey,
        state: PowerPointerState.current,
        generation: 1,
        evaluationId: evidence.evaluationId,
      );
}

String _processWire(PowerProcessCode value) => switch (value) {
      PowerProcessCode.pwr01 => 'ELV-PWR-01',
      PowerProcessCode.pwr02 => 'ELV-PWR-02',
      PowerProcessCode.pwr03 => 'ELV-PWR-03',
      PowerProcessCode.pwr04 => 'ELV-PWR-04',
      PowerProcessCode.pwr05 => 'ELV-PWR-05',
      PowerProcessCode.pwr06 => 'ELV-PWR-06',
    };

PowerProcessCode _processFromWire(String value) => switch (value) {
      'ELV-PWR-01' => PowerProcessCode.pwr01,
      'ELV-PWR-02' => PowerProcessCode.pwr02,
      'ELV-PWR-03' => PowerProcessCode.pwr03,
      'ELV-PWR-04' => PowerProcessCode.pwr04,
      'ELV-PWR-05' => PowerProcessCode.pwr05,
      'ELV-PWR-06' => PowerProcessCode.pwr06,
      _ => throw const FormatException('Unknown ELV4 power process code.'),
    };

List<PowerNodeKeyV2> _sortedDependencies(Iterable<PowerNodeKeyV2> input) {
  final byEncoded = <String, PowerNodeKeyV2>{};
  for (final value in input) {
    final encoded = value.encode();
    if (byEncoded.containsKey(encoded)) {
      throw ArgumentError('Evaluation dependencies must be unique.');
    }
    byEncoded[encoded] = value;
  }
  final result = byEncoded.values.toList()..sort();
  return result;
}

List<String> _sortedUniqueTexts(
  Iterable<String> input, {
  required String field,
}) {
  final result = input.map((value) => _text(value, field)).toList()..sort();
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

String _sha256(String value, String field) {
  final normalized = value.trim().toLowerCase();
  if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(normalized)) {
    throw ArgumentError.value(value, field, 'Expected lowercase SHA-256.');
  }
  return normalized;
}

List<Object?> _decodeCanonicalList(String encoded) {
  final decoded = jsonDecode(encoded);
  if (decoded is! List) {
    throw const FormatException('Expected canonical JSON array.');
  }
  return decoded.cast<Object?>();
}
