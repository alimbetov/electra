final class Lan03PoeProjectionContract {
  Lan03PoeProjectionContract({
    required String pseId,
    required String scenarioId,
    required String segmentId,
    required String expectedClosureFingerprint,
    required Map<String, String> expectedInputFingerprintByDeliveryId,
    required Iterable<String> lanLoadIds,
  })  : pseId = _text(pseId, 'pseId'),
        scenarioId = _text(scenarioId, 'scenarioId'),
        segmentId = _text(segmentId, 'segmentId'),
        expectedClosureFingerprint = _sha(
          expectedClosureFingerprint,
          'expectedClosureFingerprint',
        ),
        expectedInputFingerprintByDeliveryId = Map.unmodifiable(
          _fingerprints(expectedInputFingerprintByDeliveryId),
        ),
        lanLoadIds = Set.unmodifiable(
          lanLoadIds.map((e) => _text(e, 'lanLoadId')),
        ) {
    if (this.lanLoadIds.isEmpty) {
      throw ArgumentError('LAN03 LAN load membership must not be empty.');
    }
  }

  static const schema = 'electra.elv5-lan03-poe-contract.v1';

  final String pseId;
  final String scenarioId;
  final String segmentId;
  final String expectedClosureFingerprint;
  final Map<String, String> expectedInputFingerprintByDeliveryId;
  final Set<String> lanLoadIds;

  Map<String, Object?> toCanonicalValue() => <String, Object?>{
        'schema': schema,
        'pseId': pseId,
        'scenarioId': scenarioId,
        'segmentId': segmentId,
        'expectedClosureFingerprint': expectedClosureFingerprint,
        'expectedInputFingerprintByDeliveryId': <String, Object?>{
          for (final key in expectedInputFingerprintByDeliveryId.keys.toList()..sort())
            key: expectedInputFingerprintByDeliveryId[key],
        },
        'lanLoadIds': lanLoadIds.toList()..sort(),
      };

  factory Lan03PoeProjectionContract.fromMap(Map<String, Object?> map) {
    _exact(
      map,
      const {
        'schema',
        'pseId',
        'scenarioId',
        'segmentId',
        'expectedClosureFingerprint',
        'expectedInputFingerprintByDeliveryId',
        'lanLoadIds',
      },
      'LAN03 contract',
    );
    if (map['schema'] != schema) {
      throw const FormatException('Unsupported LAN03 contract schema.');
    }
    final fingerprints = _map(
      map['expectedInputFingerprintByDeliveryId'],
      'expectedInputFingerprintByDeliveryId',
    );
    final loads = map['lanLoadIds'];
    if (loads is! List) throw const FormatException('lanLoadIds must be array.');
    return Lan03PoeProjectionContract(
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
      lanLoadIds: <String>[
        for (final raw in loads) _string(raw, 'lanLoadId'),
      ],
    );
  }
}

final class Lan03PoeProjectionContractSnapshot {
  const Lan03PoeProjectionContractSnapshot({
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
  final Lan03PoeProjectionContract contract;
}

abstract interface class Lan03PoeProjectionContractSource {
  Future<Lan03PoeProjectionContractSnapshot?> loadActiveForPse({
    required String projectId,
    required String designRevisionId,
    required String pseId,
  });
}

final class ReplaceLan03PoeProjectionContractCommand {
  ReplaceLan03PoeProjectionContractCommand({
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
      throw ArgumentError('LAN03 command identity is required.');
    }
    if (expectedDesignRevision < 1 ||
        (expectedBindingRevision != null && expectedBindingRevision! < 1)) {
      throw ArgumentError('LAN03 expected revisions must be positive.');
    }
  }
  final String projectId;
  final String designRevisionId;
  final int expectedDesignRevision;
  final String bindingId;
  final int? expectedBindingRevision;
  final Lan03PoeProjectionContract contract;
}

abstract interface class Lan03PoeProjectionContractWriter {
  Future<void> replace(ReplaceLan03PoeProjectionContractCommand command);
}

Map<String, String> _fingerprints(Map<String, String> input) {
  if (input.isEmpty) {
    throw ArgumentError('LAN03 expected PWR06 delivery set must not be empty.');
  }
  final out = <String, String>{};
  for (final entry in input.entries) {
    out[_text(entry.key, 'deliveryId')] = _sha(entry.value, 'inputFingerprint');
  }
  return out;
}
Map<String,Object?> _map(Object? value,String field){if(value is! Map)throw FormatException('$field must be object.');return Map<String,Object?>.from(value);}
String _mapText(Map<String,Object?> map,String key)=>_string(map[key],key);
String _string(Object? value,String field){if(value is! String)throw FormatException('$field must be text.');return _text(value,field);}
String _text(String value,String field){final v=value.trim();if(v.isEmpty)throw ArgumentError.value(value,field,'Must not be empty.');return v;}
String _sha(String value,String field){final v=_text(value,field).toLowerCase();if(!RegExp(r'^[0-9a-f]{64}$').hasMatch(v))throw ArgumentError.value(value,field,'Expected lowercase SHA-256.');return v;}
void _exact(Map<String,Object?> map,Set<String> expected,String field){final actual=map.keys.toSet();if(actual.length!=expected.length||actual.difference(expected).isNotEmpty||expected.difference(actual).isNotEmpty)throw FormatException('$field has missing or unknown fields.');}
