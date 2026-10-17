import 'package:engineering_core/engineering_core_elv5.dart';

final class Cctv05CapabilityContract {
  Cctv05CapabilityContract({
    required String recorderId,
    required String expectedDefinitionId,
    required this.expectedDefinitionVersion,
    required this.channelLimit,
    required this.peakIngressCapacityBps,
    required this.usableStorageCapacityBytes,
    required Iterable<String> supportedCodecProfiles,
    required this.requireGuaranteedStorage,
    required Map<String, String> expectedCctv02InputFingerprintByCamera,
    required Map<String, String> expectedCctv03InputFingerprintByPool,
  }) : recorderId = _text(recorderId, 'recorderId'),
       expectedDefinitionId = _text(
         expectedDefinitionId,
         'expectedDefinitionId',
       ),
       supportedCodecProfiles = Set.unmodifiable(
         supportedCodecProfiles.map((e) => _text(e, 'supportedCodecProfile')),
       ),
       expectedCctv02InputFingerprintByCamera = Map.unmodifiable(
         _fingerprints(expectedCctv02InputFingerprintByCamera, 'cameraId'),
       ),
       expectedCctv03InputFingerprintByPool = Map.unmodifiable(
         _fingerprints(expectedCctv03InputFingerprintByPool, 'poolId'),
       ) {
    if (expectedDefinitionVersion < 1)
      throw ArgumentError('CCTV05 definition version must be >= 1.');
    if (channelLimit < 0)
      throw ArgumentError('CCTV05 channel limit must be nonnegative.');
    if (peakIngressCapacityBps < Elv5Rational.zero ||
        usableStorageCapacityBytes < Elv5Rational.zero) {
      throw ArgumentError('CCTV05 capacities must be nonnegative.');
    }
    if (this.expectedCctv02InputFingerprintByCamera.isEmpty) {
      throw ArgumentError(
        'CCTV05 expected CCTV02 camera set must not be empty.',
      );
    }
    if (this.expectedCctv03InputFingerprintByPool.isEmpty) {
      throw ArgumentError('CCTV05 expected CCTV03 pool set must not be empty.');
    }
  }

  static const schema = 'electra.elv5-cctv05-capability-contract.v1';

  final String recorderId;
  final String expectedDefinitionId;
  final int expectedDefinitionVersion;
  final int channelLimit;
  final Elv5Rational peakIngressCapacityBps;
  final Elv5Rational usableStorageCapacityBytes;
  final Set<String> supportedCodecProfiles;
  final bool requireGuaranteedStorage;
  final Map<String, String> expectedCctv02InputFingerprintByCamera;
  final Map<String, String> expectedCctv03InputFingerprintByPool;

  Map<String, Object?> toCanonicalValue() => <String, Object?>{
    'schema': schema,
    'recorderId': recorderId,
    'expectedDefinitionId': expectedDefinitionId,
    'expectedDefinitionVersion': expectedDefinitionVersion,
    'channelLimit': channelLimit,
    'peakIngressCapacityBps': peakIngressCapacityBps.toMap(),
    'usableStorageCapacityBytes': usableStorageCapacityBytes.toMap(),
    'supportedCodecProfiles': supportedCodecProfiles.toList()..sort(),
    'requireGuaranteedStorage': requireGuaranteedStorage,
    'expectedCctv02InputFingerprintByCamera': <String, Object?>{
      for (final key
          in expectedCctv02InputFingerprintByCamera.keys.toList()..sort())
        key: expectedCctv02InputFingerprintByCamera[key],
    },
    'expectedCctv03InputFingerprintByPool': <String, Object?>{
      for (final key
          in expectedCctv03InputFingerprintByPool.keys.toList()..sort())
        key: expectedCctv03InputFingerprintByPool[key],
    },
  };

  factory Cctv05CapabilityContract.fromMap(Map<String, Object?> map) {
    _exact(map, const {
      'schema',
      'recorderId',
      'expectedDefinitionId',
      'expectedDefinitionVersion',
      'channelLimit',
      'peakIngressCapacityBps',
      'usableStorageCapacityBytes',
      'supportedCodecProfiles',
      'requireGuaranteedStorage',
      'expectedCctv02InputFingerprintByCamera',
      'expectedCctv03InputFingerprintByPool',
    }, 'CCTV05 capability contract');
    if (map['schema'] != schema)
      throw const FormatException('Unsupported CCTV05 capability schema.');
    final version = map['expectedDefinitionVersion'];
    final limit = map['channelLimit'];
    final guarantee = map['requireGuaranteedStorage'];
    final codecs = map['supportedCodecProfiles'];
    if (version is! int ||
        limit is! int ||
        guarantee is! bool ||
        codecs is! List) {
      throw const FormatException('CCTV05 capability field type mismatch.');
    }
    return Cctv05CapabilityContract(
      recorderId: _mapText(map, 'recorderId'),
      expectedDefinitionId: _mapText(map, 'expectedDefinitionId'),
      expectedDefinitionVersion: version,
      channelLimit: limit,
      peakIngressCapacityBps: Elv5Rational.fromMap(
        _map(map['peakIngressCapacityBps'], 'peakIngressCapacityBps'),
      ),
      usableStorageCapacityBytes: Elv5Rational.fromMap(
        _map(map['usableStorageCapacityBytes'], 'usableStorageCapacityBytes'),
      ),
      supportedCodecProfiles: <String>[
        for (final value in codecs) _string(value, 'supportedCodecProfile'),
      ],
      requireGuaranteedStorage: guarantee,
      expectedCctv02InputFingerprintByCamera: _fingerprintsFromMap(
        _map(
          map['expectedCctv02InputFingerprintByCamera'],
          'expectedCctv02InputFingerprintByCamera',
        ),
        'cameraId',
      ),
      expectedCctv03InputFingerprintByPool: _fingerprintsFromMap(
        _map(
          map['expectedCctv03InputFingerprintByPool'],
          'expectedCctv03InputFingerprintByPool',
        ),
        'poolId',
      ),
    );
  }
}

final class Cctv05CapabilityContractSnapshot {
  const Cctv05CapabilityContractSnapshot({
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
  final Cctv05CapabilityContract contract;
}

abstract interface class Cctv05CapabilityContractSource {
  Future<Cctv05CapabilityContractSnapshot?> loadActiveForRecorder({
    required String projectId,
    required String designRevisionId,
    required String recorderId,
  });
}

final class ReplaceCctv05CapabilityContractCommand {
  ReplaceCctv05CapabilityContractCommand({
    required this.projectId,
    required this.designRevisionId,
    required this.expectedDesignRevision,
    required this.bindingId,
    required this.expectedBindingRevision,
    required this.contract,
  }) {
    _text(projectId, 'projectId');
    _text(designRevisionId, 'designRevisionId');
    _text(bindingId, 'bindingId');
    if (expectedDesignRevision < 1 ||
        (expectedBindingRevision != null && expectedBindingRevision! < 1))
      throw ArgumentError('CCTV05 expected revisions must be positive.');
  }
  final String projectId;
  final String designRevisionId;
  final int expectedDesignRevision;
  final String bindingId;
  final int? expectedBindingRevision;
  final Cctv05CapabilityContract contract;
}

abstract interface class Cctv05CapabilityContractWriter {
  Future<void> replace(ReplaceCctv05CapabilityContractCommand command);
}

Map<String, String> _fingerprints(Map<String, String> input, String keyName) =>
    {
      for (final entry in input.entries)
        _text(entry.key, keyName): _sha(entry.value, 'inputFingerprint'),
    };
Map<String, String> _fingerprintsFromMap(
  Map<String, Object?> input,
  String keyName,
) => {
  for (final entry in input.entries)
    _text(entry.key, keyName): _sha(
      _string(entry.value, 'inputFingerprint'),
      'inputFingerprint',
    ),
};
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
  final v = value.trim();
  if (v.isEmpty) throw ArgumentError.value(value, field, 'Must not be empty.');
  return v;
}

String _sha(String value, String field) {
  final v = _text(value, field).toLowerCase();
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(v))
    throw ArgumentError.value(value, field, 'Expected lowercase SHA-256.');
  return v;
}

void _exact(Map<String, Object?> map, Set<String> expected, String field) {
  final actual = map.keys.toSet();
  if (actual.length != expected.length ||
      actual.difference(expected).isNotEmpty ||
      expected.difference(actual).isNotEmpty)
    throw FormatException('$field has missing or unknown fields.');
}
