import 'dart:convert';

/// Strict public ELV4 command envelope shared by power-command v1 and
/// revision-command v2.
///
/// This boundary deliberately validates only the registered envelope and
/// version dispatch. Operation payload codecs perform their own structural and
/// semantic validation before durable mutation.
final class Elv4WireCommandEnvelope {
  Elv4WireCommandEnvelope({
    required this.schema,
    required this.operation,
    required this.payloadSchemaVersion,
    required this.projectId,
    required this.designRevisionId,
    required this.commandId,
    required this.expectedDesignRowRevision,
    required Map<String, int> expectedRows,
    required this.reviewedImpactFingerprint,
    required Map<String, Object?> payload,
  }) : expectedRows = Map.unmodifiable(expectedRows),
       payload = Map.unmodifiable(payload) {
    _validateRegistration(schema, operation, payloadSchemaVersion);
    _wireText(projectId, 'projectId');
    _wireText(designRevisionId, 'designRevisionId');
    _wireText(commandId, 'commandId');
    if (expectedDesignRowRevision < 1) {
      throw const FormatException(
        'expectedDesignRowRevision must be a positive integer.',
      );
    }
    if (expectedRows.entries.any(
      (entry) => entry.key.isEmpty || entry.key.length > 512 || entry.value < 0,
    )) {
      throw const FormatException(
        'expectedRows requires non-empty keys and non-negative revisions.',
      );
    }
    final fingerprint = reviewedImpactFingerprint;
    if (fingerprint != null &&
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(fingerprint)) {
      throw const FormatException(
        'reviewedImpactFingerprint must be lowercase SHA-256 or null.',
      );
    }
  }

  static const powerCommandSchema = 'electra.elv4-command.v1';
  static const revisionCommandSchema = 'electra.elv4-revision-command.v2';

  static const powerV1Operations = <String>{
    'BIND_POWER_PROFILE',
    'ADOPT_POWER_PROFILE',
    'RELEASE_POWER_PROFILE',
    'SET_POWER_LOAD_PROFILE',
    'REPLACE_POWER_TRANSFERS',
    'REPLACE_POWER_CAPACITY_GROUP',
    'REPLACE_POWER_SUPPLY_REQUIREMENT',
    'CREATE_POWER_SCENARIO',
    'REPLACE_POWER_SCENARIO',
    'ARCHIVE_POWER_SCENARIO',
    'BIND_POE_DELIVERY',
    'REPLACE_POE_DELIVERY',
    'CONFIGURE_BACKUP_ASSEMBLY',
    'REPLACE_BATTERY_BANK',
    'CALCULATE_POWER_PROCESS',
  };

  static const revisionV2Operations = <String>{
    'FREEZE_DESIGN_REVISION',
    'CREATE_NEXT_WORKING_DESIGN_REVISION',
  };

  static const _topLevelKeys = <String>{
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
  final String? reviewedImpactFingerprint;
  final Map<String, Object?> payload;

  Elv4WireCommandKey get dispatchKey => Elv4WireCommandKey(
    schema: schema,
    operation: operation,
    payloadSchemaVersion: payloadSchemaVersion,
  );

  Map<String, Object?> toMap() => {
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

  String toJson() => jsonEncode(toMap());

  factory Elv4WireCommandEnvelope.fromJson(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      throw const FormatException('ELV4 command must be valid JSON.');
    }
    if (decoded is! Map) {
      throw const FormatException('ELV4 command root must be an object.');
    }
    return Elv4WireCommandEnvelope.fromMap(
      decoded.cast<String, Object?>(),
    );
  }

  factory Elv4WireCommandEnvelope.fromMap(Map<String, Object?> map) {
    if (map.keys.toSet().difference(_topLevelKeys).isNotEmpty ||
        _topLevelKeys.difference(map.keys.toSet()).isNotEmpty) {
      throw const FormatException(
        'ELV4 command envelope has missing or unknown fields.',
      );
    }
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

    if (schema is! String ||
        operation is! String ||
        payloadSchemaVersion is! int ||
        projectId is! String ||
        designRevisionId is! String ||
        commandId is! String ||
        expectedDesignRowRevision is! int ||
        expectedRowsValue is! Map ||
        payloadValue is! Map ||
        (reviewedImpactFingerprint != null &&
            reviewedImpactFingerprint is! String)) {
      throw const FormatException('ELV4 command envelope field type mismatch.');
    }

    final expectedRows = <String, int>{};
    for (final entry in expectedRowsValue.entries) {
      if (entry.key is! String || entry.value is! int) {
        throw const FormatException(
          'expectedRows must map string identities to integer revisions.',
        );
      }
      expectedRows[entry.key as String] = entry.value as int;
    }

    return Elv4WireCommandEnvelope(
      schema: schema,
      operation: operation,
      payloadSchemaVersion: payloadSchemaVersion,
      projectId: projectId,
      designRevisionId: designRevisionId,
      commandId: commandId,
      expectedDesignRowRevision: expectedDesignRowRevision,
      expectedRows: expectedRows,
      reviewedImpactFingerprint: reviewedImpactFingerprint as String?,
      payload: payloadValue.cast<String, Object?>(),
    );
  }

  static void _validateRegistration(
    String schema,
    String operation,
    int payloadSchemaVersion,
  ) {
    final valid = switch ((schema, payloadSchemaVersion)) {
      (powerCommandSchema, 1) => powerV1Operations.contains(operation),
      (revisionCommandSchema, 2) => revisionV2Operations.contains(operation),
      _ => false,
    };
    if (!valid) {
      throw FormatException(
        'Unsupported ELV4 command schema/operation/version: '
        '$schema / $operation / $payloadSchemaVersion.',
      );
    }
  }
}

final class Elv4WireCommandKey {
  const Elv4WireCommandKey({
    required this.schema,
    required this.operation,
    required this.payloadSchemaVersion,
  });

  final String schema;
  final String operation;
  final int payloadSchemaVersion;

  @override
  bool operator ==(Object other) =>
      other is Elv4WireCommandKey &&
      schema == other.schema &&
      operation == other.operation &&
      payloadSchemaVersion == other.payloadSchemaVersion;

  @override
  int get hashCode => Object.hash(schema, operation, payloadSchemaVersion);
}

typedef Elv4WireOperationHandler<T> =
    Future<T> Function(Elv4WireCommandEnvelope envelope);

/// Exact schema/operation/version dispatcher. A structurally registered command
/// with no installed operation codec fails closed instead of falling through to
/// a newest-version or label-based handler.
final class Elv4WireCommandDispatcher<T> {
  Elv4WireCommandDispatcher(
    Map<Elv4WireCommandKey, Elv4WireOperationHandler<T>> handlers,
  ) : _handlers = Map.unmodifiable(handlers);

  final Map<Elv4WireCommandKey, Elv4WireOperationHandler<T>> _handlers;

  Future<T> dispatchJson(String source) => dispatch(
    Elv4WireCommandEnvelope.fromJson(source),
  );

  Future<T> dispatchMap(Map<String, Object?> map) => dispatch(
    Elv4WireCommandEnvelope.fromMap(map),
  );

  Future<T> dispatch(Elv4WireCommandEnvelope envelope) {
    final handler = _handlers[envelope.dispatchKey];
    if (handler == null) {
      throw StateError(
        'No runtime codec registered for '
        '${envelope.schema}/${envelope.operation}/'
        '${envelope.payloadSchemaVersion}.',
      );
    }
    return handler(envelope);
  }
}

String _wireText(String value, String field) {
  if (value.isEmpty || value.length > 512) {
    throw FormatException('$field must contain 1..512 characters.');
  }
  return value;
}
