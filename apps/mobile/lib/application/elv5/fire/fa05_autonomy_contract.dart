import 'package:engineering_core/engineering_core_elv5.dart';

final class Fa05SequenceSegmentContract {
  Fa05SequenceSegmentContract({
    required String segmentId,
    required this.durationMicroseconds,
  }) : segmentId = _text(segmentId, 'segmentId') {
    if (durationMicroseconds <= BigInt.zero) {
      throw ArgumentError('FA05 segment duration must be positive.');
    }
  }

  final String segmentId;
  final BigInt durationMicroseconds;

  Map<String, Object?> toCanonicalValue() => <String, Object?>{
        'segmentId': segmentId,
        'durationMicroseconds': durationMicroseconds.toString(),
      };

  factory Fa05SequenceSegmentContract.fromMap(Map<String, Object?> map) {
    _exact(map, const <String>{'segmentId', 'durationMicroseconds'}, 'FA05 segment');
    final duration = map['durationMicroseconds'];
    if (duration is! String) {
      throw const FormatException('FA05 durationMicroseconds must be text.');
    }
    return Fa05SequenceSegmentContract(
      segmentId: _mapText(map, 'segmentId'),
      durationMicroseconds: BigInt.parse(duration),
    );
  }
}

final class Fa05AutonomyContract {
  Fa05AutonomyContract({
    required String bankId,
    required String scenarioId,
    required String sequenceId,
    required String expectedPwr04InputFingerprint,
    required Iterable<Fa05SequenceSegmentContract> segments,
    required Iterable<String> globalProtectedLoadIds,
    required Iterable<String> fireProtectedLoadIds,
    this.requirePeakCurrentEvidence = false,
    this.requireEndOfDischargeEvidence = false,
  })  : bankId = _text(bankId, 'bankId'),
        scenarioId = _text(scenarioId, 'scenarioId'),
        sequenceId = _text(sequenceId, 'sequenceId'),
        expectedPwr04InputFingerprint =
            _sha(expectedPwr04InputFingerprint, 'expectedPwr04InputFingerprint'),
        segments = List.unmodifiable(_segments(segments)),
        globalProtectedLoadIds =
            Set.unmodifiable(_ids(globalProtectedLoadIds, 'globalProtectedLoadIds')),
        fireProtectedLoadIds =
            Set.unmodifiable(_ids(fireProtectedLoadIds, 'fireProtectedLoadIds')) {
    if (this.segments.isEmpty) {
      throw ArgumentError('FA05 requires at least one protected sequence segment.');
    }
    if (this.globalProtectedLoadIds.isEmpty) {
      throw ArgumentError('FA05 global protected-load set must not be empty.');
    }
    if (this.fireProtectedLoadIds.isEmpty) {
      throw ArgumentError('FA05 Fire protected-load set must not be empty.');
    }
    if (!this.globalProtectedLoadIds.containsAll(this.fireProtectedLoadIds)) {
      throw ArgumentError('FA05 Fire protected loads must be a subset of global protected loads.');
    }
  }

  static const schema = 'electra.elv5-fa05-autonomy-contract.v1';
  static const _encoder = Elv5CanonicalJsonV1();

  final String bankId;
  final String scenarioId;
  final String sequenceId;
  final String expectedPwr04InputFingerprint;
  final List<Fa05SequenceSegmentContract> segments;
  final Set<String> globalProtectedLoadIds;
  final Set<String> fireProtectedLoadIds;
  final bool requirePeakCurrentEvidence;
  final bool requireEndOfDischargeEvidence;

  String get sequenceFingerprint => _encoder.sha256(<String, Object?>{
        'schema': 'electra.elv5-protected-sequence-fingerprint.v1',
        'scenarioId': scenarioId,
        'sequenceId': sequenceId,
        'segments': [for (final value in segments) value.toCanonicalValue()],
      });

  String get protectedLoadSetFingerprint => _encoder.sha256(<String, Object?>{
        'schema': 'electra.elv5-protected-load-set-fingerprint.v1',
        'loadIds': globalProtectedLoadIds.toList()..sort(),
      });

  Map<String, Object?> toCanonicalValue() => <String, Object?>{
        'schema': schema,
        'bankId': bankId,
        'scenarioId': scenarioId,
        'sequenceId': sequenceId,
        'expectedPwr04InputFingerprint': expectedPwr04InputFingerprint,
        'segments': [for (final value in segments) value.toCanonicalValue()],
        'globalProtectedLoadIds': globalProtectedLoadIds.toList()..sort(),
        'fireProtectedLoadIds': fireProtectedLoadIds.toList()..sort(),
        'requirePeakCurrentEvidence': requirePeakCurrentEvidence,
        'requireEndOfDischargeEvidence': requireEndOfDischargeEvidence,
      };

  factory Fa05AutonomyContract.fromMap(Map<String, Object?> map) {
    _exact(map, const <String>{
      'schema',
      'bankId',
      'scenarioId',
      'sequenceId',
      'expectedPwr04InputFingerprint',
      'segments',
      'globalProtectedLoadIds',
      'fireProtectedLoadIds',
      'requirePeakCurrentEvidence',
      'requireEndOfDischargeEvidence',
    }, 'FA05 autonomy contract');
    if (map['schema'] != schema) {
      throw const FormatException('Unsupported FA05 autonomy contract schema.');
    }
    final rawSegments = map['segments'];
    final global = map['globalProtectedLoadIds'];
    final fire = map['fireProtectedLoadIds'];
    final peak = map['requirePeakCurrentEvidence'];
    final eod = map['requireEndOfDischargeEvidence'];
    if (rawSegments is! List || global is! List || fire is! List ||
        peak is! bool || eod is! bool) {
      throw const FormatException('FA05 contract field type mismatch.');
    }
    return Fa05AutonomyContract(
      bankId: _mapText(map, 'bankId'),
      scenarioId: _mapText(map, 'scenarioId'),
      sequenceId: _mapText(map, 'sequenceId'),
      expectedPwr04InputFingerprint: _mapText(map, 'expectedPwr04InputFingerprint'),
      segments: <Fa05SequenceSegmentContract>[
        for (final raw in rawSegments)
          Fa05SequenceSegmentContract.fromMap(_object(raw, 'FA05 segment')),
      ],
      globalProtectedLoadIds: _strings(global, 'globalProtectedLoadIds'),
      fireProtectedLoadIds: _strings(fire, 'fireProtectedLoadIds'),
      requirePeakCurrentEvidence: peak,
      requireEndOfDischargeEvidence: eod,
    );
  }
}

final class Fa05AutonomyContractSnapshot {
  const Fa05AutonomyContractSnapshot({
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
  final Fa05AutonomyContract contract;
}

abstract interface class Fa05AutonomyContractSource {
  Future<Fa05AutonomyContractSnapshot?> loadActiveForBank({
    required String projectId,
    required String designRevisionId,
    required String bankId,
  });
}

List<Fa05SequenceSegmentContract> _segments(
  Iterable<Fa05SequenceSegmentContract> values,
) {
  final result = values.toList();
  final ids = <String>{};
  for (final value in result) {
    if (!ids.add(value.segmentId)) {
      throw ArgumentError('FA05 duplicate segmentId: ${value.segmentId}');
    }
  }
  return result;
}

Set<String> _ids(Iterable<String> values, String field) {
  final result = <String>{};
  for (final value in values) {
    final normalized = _text(value, field);
    if (!result.add(normalized)) {
      throw ArgumentError('$field contains duplicate identity: $normalized');
    }
  }
  return result;
}

List<String> _strings(List raw, String field) => <String>[
      for (final value in raw)
        if (value is String)
          _text(value, field)
        else
          throw FormatException('$field must contain text entries.'),
    ];

Map<String, Object?> _object(Object? value, String field) {
  if (value is! Map) throw FormatException('$field must be an object.');
  return Map<String, Object?>.from(value);
}

String _mapText(Map<String, Object?> map, String field) {
  final value = map[field];
  if (value is! String) throw FormatException('$field must be text.');
  return _text(value, field);
}

String _text(String value, String field) {
  final normalized = value.trim();
  if (normalized.isEmpty) throw ArgumentError.value(value, field, 'Must not be empty.');
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
