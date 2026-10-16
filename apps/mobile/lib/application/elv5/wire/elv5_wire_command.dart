import 'dart:convert';

import 'package:engineering_core/engineering_core_elv5.dart';

import 'elv5_wire_command_registry.dart';

/// Strict ELV5 public command envelope. No version or operation inference is
/// permitted at this boundary.
final class Elv5WireCommandEnvelope {
  Elv5WireCommandEnvelope({
    required this.operation,
    required this.projectId,
    required this.designRevisionId,
    required this.commandId,
    required this.expectedDesignRowRevision,
    required Map<String, int> expectedRows,
    required this.reviewedImpactFingerprint,
    required Map<String, Object?> payload,
  })  : schema = Elv5RuntimeContract.wireSchema,
        payloadSchemaVersion = Elv5RuntimeContract.wirePayloadSchemaVersion,
        expectedRows = Map.unmodifiable(expectedRows),
        payload = Map.unmodifiable(payload) {
    Elv5WireCommandRegistry.requireOperation(operation);
    _wireText(projectId, 'projectId');
    _wireText(designRevisionId, 'designRevisionId');
    _wireText(commandId, 'commandId');
    if (expectedDesignRowRevision < 1) {
      throw const FormatException(
        'expectedDesignRowRevision must be a positive integer.',
      );
    }
    for (final entry in expectedRows.entries) {
      _wireText(entry.key, 'expectedRows key');
      if (entry.value < 0) {
        throw const FormatException(
          'expectedRows revisions must be non-negative integers.',
        );
      }
    }
    if (!_sha256.hasMatch(reviewedImpactFingerprint)) {
      throw const FormatException(
        'reviewedImpactFingerprint must be lowercase SHA-256.',
      );
    }
    Elv5WireCommandRegistry.validatePayload(operation, payload);
  }

  static final _sha256 = RegExp(r'^[0-9a-f]{64}$');

  static const topLevelKeys = <String>{
    'schema',
    'operation',
    'payloadSchemaVersion',
    'projectId',
    'designRevisionId',
    'commandId',
    'expectedDesignRowRevision',
    'expectedRows',
    'reviewedImpactFingerprint',
    'payload',
  };

  final String schema;
  final String operation;
  final int payloadSchemaVersion;
  final String projectId;
  final String designRevisionId;
  final String commandId;
  final int expectedDesignRowRevision;
  final Map<String, int> expectedRows;
  final String reviewedImpactFingerprint;
  final Map<String, Object?> payload;

  Map<String, Object?> toMap() => <String, Object?>{
        'schema': schema,
        'operation': operation,
        'payloadSchemaVersion': payloadSchemaVersion,
        'projectId': projectId,
        'designRevisionId': designRevisionId,
        'commandId': commandId,
        'expectedDesignRowRevision': expectedDesignRowRevision,
        'expectedRows': expectedRows,
        'reviewedImpactFingerprint': reviewedImpactFingerprint,
        'payload': payload,
      };

  /// Hash used by the shared durable command ledger for replay/conflict checks.
  String get normalizedRequestSha256 =>
      const Elv5CanonicalJsonV1().sha256(toMap());

  String toJson() => jsonEncode(toMap());

  factory Elv5WireCommandEnvelope.fromJson(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      throw const FormatException('ELV5 command must be valid JSON.');
    }
    if (decoded is! Map) {
      throw const FormatException('ELV5 command root must be an object.');
    }
    return Elv5WireCommandEnvelope.fromMap(_stringObjectMap(decoded, 'root'));
  }

  factory Elv5WireCommandEnvelope.fromMap(Map<String, Object?> map) {
    _exactKeys(map, topLevelKeys, 'ELV5 command envelope');
    final schema = map['schema'];
    final operation = map['operation'];
    final payloadSchemaVersion = map['payloadSchemaVersion'];
    final projectId = map['projectId'];
    final designRevisionId = map['designRevisionId'];
    final commandId = map['commandId'];
    final expectedDesignRowRevision = map['expectedDesignRowRevision'];
    final expectedRowsValue = map['expectedRows'];
    final reviewedImpactFingerprint = map['reviewedImpactFingerprint'];
    final payloadValue = map['payload'];

    if (schema != Elv5RuntimeContract.wireSchema ||
        payloadSchemaVersion != Elv5RuntimeContract.wirePayloadSchemaVersion) {
      throw const FormatException('Unsupported ELV5 wire schema/version.');
    }
    if (operation is! String ||
        projectId is! String ||
        designRevisionId is! String ||
        commandId is! String ||
        expectedDesignRowRevision is! int ||
        reviewedImpactFingerprint is! String ||
        expectedRowsValue is! Map ||
        payloadValue is! Map) {
      throw const FormatException('ELV5 command envelope field type mismatch.');
    }

    final expectedRowsRaw = _stringObjectMap(expectedRowsValue, 'expectedRows');
    final expectedRows = <String, int>{};
    for (final entry in expectedRowsRaw.entries) {
      if (entry.value is! int) {
        throw const FormatException(
          'expectedRows must map string identities to integer revisions.',
        );
      }
      expectedRows[entry.key] = entry.value! as int;
    }

    return Elv5WireCommandEnvelope(
      operation: operation,
      projectId: projectId,
      designRevisionId: designRevisionId,
      commandId: commandId,
      expectedDesignRowRevision: expectedDesignRowRevision,
      expectedRows: expectedRows,
      reviewedImpactFingerprint: reviewedImpactFingerprint,
      payload: _stringObjectMap(payloadValue, 'payload'),
    );
  }
}

Map<String, Object?> _stringObjectMap(Map value, String field) {
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) {
      throw FormatException('$field keys must be strings.');
    }
    result[entry.key as String] = entry.value;
  }
  return result;
}

void _exactKeys(Map<String, Object?> value, Set<String> keys, String field) {
  final actual = value.keys.toSet();
  if (actual.length != keys.length ||
      actual.difference(keys).isNotEmpty ||
      keys.difference(actual).isNotEmpty) {
    throw FormatException('$field has missing or unknown fields.');
  }
}

String _wireText(String value, String field) {
  if (value.isEmpty || value.length > 512) {
    throw FormatException('$field must contain 1..512 characters.');
  }
  return value;
}
