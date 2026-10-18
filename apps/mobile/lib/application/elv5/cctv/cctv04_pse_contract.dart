import '../power/pwr06_shared_projection.dart';

String cctv04Pwr06ClosureFingerprint({
  required String pseId,
  required Iterable<Map<String, Object?>> members,
}) => elv5Pwr06SharedClosureFingerprint(pseId: pseId, members: members);

final class Cctv04PseProjectionContract {
  Cctv04PseProjectionContract({
    required String pseId,
    required String scenarioId,
    required String segmentId,
    required String expectedClosureFingerprint,
    required Map<String, String> expectedInputFingerprintByDeliveryId,
    required Iterable<String> cctvLoadIds,
  }) : pseId = _text(pseId, 'pseId'),
       scenarioId = _text(scenarioId, 'scenarioId'),
       segmentId = _text(segmentId, 'segmentId'),
       expectedClosureFingerprint = _sha(
         expectedClosureFingerprint,
         'expectedClosureFingerprint',
       ),
       expectedInputFingerprintByDeliveryId = Map.unmodifiable(
         _fingerprints(expectedInputFingerprintByDeliveryId),
       ),
       cctvLoadIds = Set.unmodifiable(
         cctvLoadIds.map((value) => _text(value, 'cctvLoadId')),
       ) {
    if (this.cctvLoadIds.isEmpty) {
      throw ArgumentError('CCTV04 CCTV load membership must not be empty.');
    }
  }

  static const schema = 'electra.elv5-cctv04-pse-contract.v1';

  final String pseId;
  final String scenarioId;
  final String segmentId;
  final String expectedClosureFingerprint;
  final Map<String, String> expectedInputFingerprintByDeliveryId;
  final Set<String> cctvLoadIds;

  Map<String, Object?> toCanonicalValue() => <String, Object?>{
    'schema': schema,
    'pseId': pseId,
    'scenarioId': scenarioId,
    'segmentId': segmentId,
    'expectedClosureFingerprint': expectedClosureFingerprint,
    'expectedInputFingerprintByDeliveryId': <String, Object?>{
      for (final key
          in expectedInputFingerprintByDeliveryId.keys.toList()..sort())
        key: expectedInputFingerprintByDeliveryId[key],
    },
    'cctvLoadIds': cctvLoadIds.toList()..sort(),
  };

  factory Cctv04PseProjectionContract.fromMap(Map<String, Object?> map) {
    _exact(map, const <String>{
      'schema',
      'pseId',
      'scenarioId',
      'segmentId',
      'expectedClosureFingerprint',
      'expectedInputFingerprintByDeliveryId',
      'cctvLoadIds',
    }, 'CCTV04 contract');
    if (map['schema'] != schema) {
      throw const FormatException('Unsupported CCTV04 contract schema.');
    }
    final fingerprints = _map(
      map['expectedInputFingerprintByDeliveryId'],
      'expectedInputFingerprintByDeliveryId',
    );
    final loads = map['cctvLoadIds'];
    if (loads is! List) {
      throw const FormatException('cctvLoadIds must be array.');
    }
    return Cctv04PseProjectionContract(
      pseId: _mapText(map, 'pseId'),
      scenarioId: _mapText(map, 'scenarioId'),
      segmentId: _mapText(map, 'segmentId'),
      expectedClosureFingerprint: _mapText(map, 'expectedClosureFingerprint'),
      expectedInputFingerprintByDeliveryId: <String, String>{
        for (final entry in fingerprints.entries)
          _text(entry.key, 'deliveryId'): _sha(
            _string(entry.value, 'inputFingerprint'),
            'inputFingerprint',
          ),
      },
      cctvLoadIds: <String>[
        for (final raw in loads) _string(raw, 'cctvLoadId'),
      ],
    );
  }
}

final class Cctv04PseProjectionContractSnapshot {
  const Cctv04PseProjectionContractSnapshot({
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
  final Cctv04PseProjectionContract contract;
}

abstract interface class Cctv04PseProjectionContractSource {
  Future<Cctv04PseProjectionContractSnapshot?> loadActiveForPse({
    required String projectId,
    required String designRevisionId,
    required String pseId,
  });
}

final class ReplaceCctv04PseProjectionContractCommand {
  ReplaceCctv04PseProjectionContractCommand({
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
      throw ArgumentError('CCTV04 command identity is required.');
    }
    if (expectedDesignRevision < 1 ||
        (expectedBindingRevision != null && expectedBindingRevision! < 1)) {
      throw ArgumentError('CCTV04 expected revisions must be positive.');
    }
  }

  final String projectId;
  final String designRevisionId;
  final int expectedDesignRevision;
  final String bindingId;
  final int? expectedBindingRevision;
  final Cctv04PseProjectionContract contract;
}

abstract interface class Cctv04PseProjectionContractWriter {
  Future<void> replace(ReplaceCctv04PseProjectionContractCommand command);
}

Map<String, String> _fingerprints(Map<String, String> input) {
  if (input.isEmpty) {
    throw ArgumentError(
      'CCTV04 expected PWR06 delivery set must not be empty.',
    );
  }
  return <String, String>{
    for (final entry in input.entries)
      _text(entry.key, 'deliveryId'): _sha(entry.value, 'inputFingerprint'),
  };
}

Map<String, Object?> _map(Object? value, String field) {
  if (value is! Map) throw FormatException('$field must be object.');
  return Map<String, Object?>.from(value);
}

String _mapText(Map<String, Object?> map, String key) => _string(map[key], key);

String _string(Object? value, String field) {
  if (value is! String) throw FormatException('$field must be text.');
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
