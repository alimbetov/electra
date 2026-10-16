import 'elv4_wire_command_dispatcher.dart';

final class Elv4ResolvedWireImpact {
  Elv4ResolvedWireImpact({
    required Map<String, int> verifiedRows,
    required Iterable<String> changedDependencyRefs,
    required String reviewedImpactFingerprint,
  }) : verifiedRows = Map.unmodifiable(verifiedRows),
       changedDependencyRefs = List.unmodifiable(
         changedDependencyRefs.toSet().toList()..sort(),
       ),
       reviewedImpactFingerprint = _sha256Text(
         reviewedImpactFingerprint,
         'reviewedImpactFingerprint',
       );

  final Map<String, int> verifiedRows;
  final List<String> changedDependencyRefs;
  final String reviewedImpactFingerprint;
}

typedef Elv4WireImpactResolver =
    Future<Elv4ResolvedWireImpact> Function(Elv4WireCommandEnvelope envelope);

typedef Elv4WirePayloadDecoder<T> = T Function(Map<String, Object?> payload);

typedef Elv4WireSemanticHandler<TPayload, TResult> =
    Future<TResult> Function(
      Elv4WireCommandEnvelope envelope,
      TPayload payload,
      Elv4ResolvedWireImpact impact,
    );

abstract interface class Elv4WireSemanticCodec<TResult> {
  Elv4WireCommandKey get key;

  Future<TResult> execute(
    Elv4WireCommandEnvelope envelope,
    Elv4ResolvedWireImpact impact,
  );
}

final class Elv4WireTypedSemanticCodec<TPayload, TResult>
    implements Elv4WireSemanticCodec<TResult> {
  Elv4WireTypedSemanticCodec({
    required this.key,
    required this.decodePayload,
    required this.handler,
  });

  @override
  final Elv4WireCommandKey key;
  final Elv4WirePayloadDecoder<TPayload> decodePayload;
  final Elv4WireSemanticHandler<TPayload, TResult> handler;

  @override
  Future<TResult> execute(
    Elv4WireCommandEnvelope envelope,
    Elv4ResolvedWireImpact impact,
  ) async {
    final payload = decodePayload(envelope.payload);
    return handler(envelope, payload, impact);
  }
}

/// Public semantic boundary for ELV4 command envelopes.
///
/// Structural registration is enforced by [Elv4WireCommandEnvelope]. This
/// layer additionally requires an exact runtime codec for every registered
/// schema/operation/version tuple. Impact/dependency data is never accepted
/// from the wire payload: a server-side resolver must reload and verify it
/// before the operation codec executes.
final class Elv4WireSemanticAdapter<TResult> {
  Elv4WireSemanticAdapter({
    required Iterable<Elv4WireSemanticCodec<TResult>> codecs,
    required Elv4WireImpactResolver resolveImpact,
  }) : _resolveImpact = resolveImpact,
       _codecs = _validatedCodecs(codecs);

  final Map<Elv4WireCommandKey, Elv4WireSemanticCodec<TResult>> _codecs;
  final Elv4WireImpactResolver _resolveImpact;

  Future<TResult> dispatchJson(String source) =>
      dispatch(Elv4WireCommandEnvelope.fromJson(source));

  Future<TResult> dispatchMap(Map<String, Object?> source) =>
      dispatch(Elv4WireCommandEnvelope.fromMap(source));

  Future<TResult> dispatch(Elv4WireCommandEnvelope envelope) async {
    final codec = _codecs[envelope.dispatchKey];
    if (codec == null) {
      throw StateError(
        'No semantic codec registered for '
        '${envelope.schema}/${envelope.operation}/'
        '${envelope.payloadSchemaVersion}.',
      );
    }
    final impact = await _resolveImpact(envelope);
    if (envelope.reviewedImpactFingerprint == null) {
      throw const FormatException(
        'Semantic ELV4 mutation requires reviewedImpactFingerprint.',
      );
    }
    if (impact.reviewedImpactFingerprint !=
        envelope.reviewedImpactFingerprint) {
      throw StateError('ELV4_STALE_REVIEWED_IMPACT');
    }
    if (!_sameRows(impact.verifiedRows, envelope.expectedRows)) {
      throw StateError('ELV4_EXPECTED_ROWS_CONFLICT');
    }
    return codec.execute(envelope, impact);
  }

  static Map<Elv4WireCommandKey, Elv4WireSemanticCodec<TResult>>
  _validatedCodecs<TResult>(Iterable<Elv4WireSemanticCodec<TResult>> codecs) {
    final result = <Elv4WireCommandKey, Elv4WireSemanticCodec<TResult>>{};
    for (final codec in codecs) {
      if (result.putIfAbsent(codec.key, () => codec) != codec) {
        throw ArgumentError('Duplicate ELV4 semantic codec: ${codec.key}.');
      }
    }
    final expected = <Elv4WireCommandKey>{
      for (final operation in Elv4WireCommandEnvelope.powerV1Operations)
        Elv4WireCommandKey(
          schema: Elv4WireCommandEnvelope.powerCommandSchema,
          operation: operation,
          payloadSchemaVersion: 1,
        ),
      for (final operation in Elv4WireCommandEnvelope.revisionV2Operations)
        Elv4WireCommandKey(
          schema: Elv4WireCommandEnvelope.revisionCommandSchema,
          operation: operation,
          payloadSchemaVersion: 2,
        ),
    };
    final actual = result.keys.toSet();
    if (actual.length != expected.length ||
        !actual.containsAll(expected) ||
        !expected.containsAll(actual)) {
      final missing =
          expected.difference(actual).toList()
            ..sort((a, b) => _keyText(a).compareTo(_keyText(b)));
      final extra =
          actual.difference(expected).toList()
            ..sort((a, b) => _keyText(a).compareTo(_keyText(b)));
      throw ArgumentError(
        'ELV4 semantic codec registry mismatch. '
        'missing=${missing.map(_keyText).toList()} '
        'extra=${extra.map(_keyText).toList()}',
      );
    }
    return Map.unmodifiable(result);
  }
}

final class Elv4WireAggregatePayload {
  Elv4WireAggregatePayload({
    required String ownerId,
    required String memberField,
    required Map<String, Object?> payload,
  }) : ownerId = _wireText(ownerId, 'ownerId'),
       memberField = _wireText(memberField, 'memberField'),
       payload = Map.unmodifiable(payload) {
    final members = payload[memberField];
    if (members is! List) {
      throw FormatException('$memberField must be an array.');
    }
    this.members = List.unmodifiable(
      members.map((value) {
        if (value is! Map) {
          throw FormatException('$memberField members must be objects.');
        }
        return Map<String, Object?>.unmodifiable(value.cast<String, Object?>());
      }),
    );
  }

  final String ownerId;
  final String memberField;
  final Map<String, Object?> payload;
  late final List<Map<String, Object?>> members;
}

Elv4WireAggregatePayload decodeElv4AggregatePayload(
  Map<String, Object?> payload, {
  required String ownerField,
  required String memberField,
  required Set<String> exactKeys,
}) {
  _requireExactKeys(payload, exactKeys);
  final owner = payload[ownerField];
  if (owner is! String) {
    throw FormatException('$ownerField must be a string.');
  }
  return Elv4WireAggregatePayload(
    ownerId: owner,
    memberField: memberField,
    payload: payload,
  );
}

void _requireExactKeys(Map<String, Object?> value, Set<String> expected) {
  final actual = value.keys.toSet();
  if (actual.length != expected.length ||
      !actual.containsAll(expected) ||
      !expected.containsAll(actual)) {
    throw const FormatException('ELV4 operation payload fields do not match.');
  }
}

bool _sameRows(Map<String, int> a, Map<String, int> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (b[entry.key] != entry.value) return false;
  }
  return true;
}

String _keyText(Elv4WireCommandKey key) =>
    '${key.schema}/${key.operation}/${key.payloadSchemaVersion}';

String _wireText(String value, String field) {
  final normalized = value.trim();
  if (normalized.isEmpty || normalized.length > 512) {
    throw FormatException('$field must contain 1..512 characters.');
  }
  return normalized;
}

String _sha256Text(String value, String field) {
  final normalized = value.trim().toLowerCase();
  if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(normalized)) {
    throw FormatException('$field must be lowercase SHA-256.');
  }
  return normalized;
}
