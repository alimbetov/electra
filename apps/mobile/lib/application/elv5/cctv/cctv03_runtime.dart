import 'dart:convert';

import 'package:engineering_core/engineering_core_elv5.dart';

import '../calculation/elv5_blocked_capture.dart';
import '../calculation/elv5_calculation_runtime.dart';
import '../calculation/elv5_kernel_executor.dart';
import '../persistence/elv5_runtime_persistence.dart';
import 'elv5_cctv_persistence.dart';

/// Persisted-fact resolver for CCTV-03.
///
/// V1 supports already captured absolute UTC schedule segments. Recurrence is
/// deliberately blocked until the application owns a pinned tzdb recurrence
/// expander; host timezone/tzdb state is never used implicitly.
final class Cctv03PersistedInputResolver
    implements Elv5ProcessInputResolver<Cctv03Input> {
  Cctv03PersistedInputResolver({
    required this.store,
    DateTime Function()? nowUtc,
  }) : _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final Elv5CctvMutationStore store;
  final DateTime Function() _nowUtc;
  static const _encoder = Elv5CanonicalJsonV1();

  @override
  Elv5ProcessCode get processCode => Elv5ProcessCode.cctv03;

  @override
  Future<Elv5CapturedInput<Cctv03Input>> capture(
    Elv5CalculationRequest request,
  ) async {
    if (request.processCode != processCode) {
      throw StateError('CCTV03_RESOLVER_PROCESS_CODE_MISMATCH');
    }
    if (request.subject.kind != 'RECORDING_POOL') {
      throw StateError('CCTV03_SUBJECT_KIND_MUST_BE_RECORDING_POOL');
    }
    final snapshot = await store.loadRecordingPool(
      projectId: request.projectId,
      designRevisionId: request.designRevisionId,
      poolId: request.subject.id,
    );
    if (snapshot == null) {
      throw StateError(
        'CCTV03_RECORDING_POOL_FACTS_MISSING:${request.subject.id}',
      );
    }
    final payload = snapshot.payload;
    final poolId = _text(payload, 'poolId');
    if (poolId != request.subject.id) {
      throw StateError('CCTV03_POOL_ID_MISMATCH:$poolId:${request.subject.id}');
    }

    final horizon = _map(payload['horizon'], 'horizon');
    final temporal = _map(payload['temporalPolicy'], 'temporalPolicy');
    final temporalHash = _encoder.sha256(<String, Object?>{
      'schema': 'electra.elv5-cctv03-temporal-rules.v1',
      'temporalPolicy': temporal,
    });
    final inputFingerprint = _encoder.sha256(<String, Object?>{
      'schema': 'electra.elv5-cctv03-captured-input.v1',
      'aggregateId': snapshot.aggregateId,
      'aggregateRevision': snapshot.revision,
      'payload': payload,
    });
    final policyFingerprint = _encoder.sha256(<String, Object?>{
      'schema': 'electra.elv5-cctv03-policy-basis.v1',
      'temporalPolicy': temporal,
      'sizingBasis': payload['sizingBasis'],
      'reserveMultiplier': payload['reserveMultiplier'],
      'redundancyModel': payload['redundancyModel'],
      'policyRef': payload['policyRef'],
    });

    final intervalsByProfile = <String, List<Cctv03UtcInterval>>{};
    final scheduleSegments = _objectList(
      payload['scheduleSegments'],
      'scheduleSegments',
    );
    for (final segment in scheduleSegments) {
      final profileId = _text(segment, 'scheduleProfileId');
      if (segment['recurrence'] != null) {
        final dependencies = <Elv5DependencyMarker>[
          _dependency(request, 'SET', 'CCTV_RECORDING_POOL', poolId),
          _dependency(
            request,
            'SET',
            'CCTV_RECORDING_SCHEDULE',
            poolId,
            memberId: profileId,
          ),
          if (payload['policyRef'] != null)
            _dependency(request, 'POLICY', 'CCTV_RECORDING_POLICY', poolId),
        ];
        throw Elv5CaptureBlockedException(
          request: request,
          reasonCode: 'CCTV03_RECURRENCE_EXPANDER_REQUIRED',
          inputFingerprint: inputFingerprint,
          policyFingerprint: policyFingerprint,
          dependencies: dependencies,
          evidence: <String, Object?>{
            'source': 'ELV5_PERSISTED_RECORDING_POOL',
            'aggregateId': snapshot.aggregateId,
            'aggregateRevision': snapshot.revision,
            'scheduleProfileId': profileId,
            'timeZoneId': _text(temporal, 'timeZoneId'),
            'tzdbVersion': _text(temporal, 'tzdbVersion'),
            'temporalRulesHash': temporalHash,
            'requiredCapability': 'PINNED_TZDB_RECURRENCE_EXPANDER',
          },
        );
      }
      final absolute = _map(segment['absoluteWindow'], 'absoluteWindow');
      (intervalsByProfile[profileId] ??= <Cctv03UtcInterval>[]).add(
        Cctv03UtcInterval(
          startUtc: _utc(absolute, 'startUtc'),
          endUtc: _utc(absolute, 'endUtc'),
        ),
      );
    }

    final rates = <String, Cctv03StreamRate>{};
    final assignments = <Cctv03RecordingAssignment>[];
    for (final assignment in _objectList(
      payload['assignments'],
      'assignments',
    )) {
      final streamId = _text(assignment, 'encodedStreamId');
      final expected = BitRate(
        Elv5Rational.parseDecimal(_decimal(assignment, 'expectedBitrateBps')),
      );
      final upperText = assignment['upperBoundBitrateBps'];
      final upper =
          upperText == null
              ? null
              : BitRate(
                Elv5Rational.parseDecimal(
                  _decimal(assignment, 'upperBoundBitrateBps'),
                ),
              );
      final candidate = Cctv03StreamRate(
        streamId: streamId,
        expectedBitRate: expected,
        guaranteedUpperBoundBitRate: upper,
      );
      final previous = rates[streamId];
      if (previous != null &&
          (previous.expectedBitRate.value != candidate.expectedBitRate.value ||
              previous.guaranteedUpperBoundBitRate?.value !=
                  candidate.guaranteedUpperBoundBitRate?.value)) {
        throw StateError('CCTV03_STREAM_RATE_CONFLICT:$streamId');
      }
      rates[streamId] = candidate;
      final profileId = _text(assignment, 'scheduleProfileId');
      final intervals = intervalsByProfile[profileId];
      if (intervals == null || intervals.isEmpty) {
        throw StateError('CCTV03_SCHEDULE_PROFILE_EMPTY:$profileId');
      }
      assignments.add(
        Cctv03RecordingAssignment(
          streamId: streamId,
          poolId: poolId,
          copyRole: _text(assignment, 'copyRole'),
          intervals: intervals,
        ),
      );
    }

    final redundancyRaw = payload['redundancyModel'];
    final redundancy =
        redundancyRaw == null
            ? null
            : Cctv03RedundancyModel(
              usableFraction: Elv5Rational.parseDecimal(
                _decimal(
                  _map(redundancyRaw, 'redundancyModel'),
                  'usableFraction',
                ),
              ),
            );
    final sizingBasis = switch (_text(payload, 'sizingBasis')) {
      'EXPECTED_ESTIMATE' => Cctv03SizingBasis.expectedEstimate,
      'GUARANTEED_UPPER_BOUND' => Cctv03SizingBasis.guaranteedUpperBound,
      final value =>
        throw FormatException('Unsupported CCTV03 sizingBasis: $value'),
    };

    final input = Cctv03Input(
      poolId: poolId,
      horizonStartUtc: _utc(horizon, 'startUtc'),
      horizonEndUtc: _utc(horizon, 'endUtc'),
      temporalPolicy: Cctv03TemporalPolicy(
        zoneId: _text(temporal, 'timeZoneId'),
        rulesHash: temporalHash,
      ),
      sizingBasis: sizingBasis,
      streamRates: rates.values,
      assignments: assignments,
      reserveMultiplier: Elv5Rational.parseDecimal(
        _decimal(payload, 'reserveMultiplier'),
      ),
      redundancy: redundancy,
    );

    final dependencies = <Elv5DependencyMarker>[
      _dependency(request, 'SET', 'CCTV_RECORDING_POOL', poolId),
      for (final assignment in assignments)
        _dependency(
          request,
          'FACT',
          'CCTV_RECORDING_STREAM',
          assignment.streamId,
          memberId: assignment.copyRole,
        ),
      for (final profileId in intervalsByProfile.keys)
        _dependency(
          request,
          'SET',
          'CCTV_RECORDING_SCHEDULE',
          poolId,
          memberId: profileId,
        ),
      if (payload['policyRef'] != null)
        _dependency(request, 'POLICY', 'CCTV_RECORDING_POLICY', poolId),
    ];

    return Elv5CapturedInput<Cctv03Input>(
      request: request,
      value: input,
      inputFingerprint: inputFingerprint,
      policyFingerprint: policyFingerprint,
      dependencies: dependencies,
      upstreamPointerGenerations: const <String, int>{},
      captureRevision: snapshot.revision,
    );
  }

  Elv5DependencyMarker _dependency(
    Elv5CalculationRequest request,
    String relationKind,
    String domain,
    String subjectId, {
    String? memberId,
  }) {
    final value = <String, Object?>{
      'schema': 'electra.elv5-dependency-key.v1',
      'relationKind': relationKind,
      'domain': domain,
      'subjectId': subjectId,
      if (memberId != null) 'memberId': memberId,
    };
    return Elv5DependencyMarker(
      projectId: request.projectId,
      designRevisionId: request.designRevisionId,
      dependencyKey: utf8.decode(_encoder.encode(value)),
      dependencyKeySha256: _encoder.sha256(value),
      logicalNodeKeySha256: _encoder.sha256(request.nodeKey.toCanonicalValue()),
      relationKind: relationKind,
      updatedAtUtc: _nowUtc().toUtc(),
    );
  }
}

Elv5PureKernelExecutor<Cctv03Input, Cctv03Result> buildCctv03Executor({
  DateTime Function()? nowUtc,
}) => Elv5PureKernelExecutor<Cctv03Input, Cctv03Result>(
  processCode: Elv5ProcessCode.cctv03,
  calculate: const Cctv03StorageKernel().evaluate,
  encodeOutput:
      (result) => <String, Object?>{
        'schema': 'electra.elv5-cctv03-output.v1',
        'poolId': result.poolId,
        'sizingBasis': result.sizingBasis.name,
        'exactBaseBytes': result.exactBaseBytes.toMap(),
        'exactReservedBytes': result.exactReservedBytes.toMap(),
        'recordedMicroseconds': result.recordedMicroseconds.toString(),
        'usable': _capacity(result.usable),
        'raw': result.raw == null ? null : _capacity(result.raw!),
      },
  encodeEvidence:
      (captured, _) => <String, Object?>{
        'schema': 'electra.elv5-cctv03-evidence.v1',
        'source': 'ELV5_PERSISTED_RECORDING_POOL',
        'captureRevision': captured.captureRevision,
        'temporalRulesHash': captured.value.temporalPolicy.rulesHash,
        'recurrenceExpansion': 'ABSOLUTE_UTC_ONLY_V1',
      },
  executionOf: (_) => Elv5Execution.succeeded,
  completionOf: (_) => Elv5Completion.complete,
  assessmentOf: (result) {
    final checks = <bool?>[
      result.usable.withinCapacity,
      result.raw?.withinCapacity,
    ];
    if (checks.any((value) => value == false)) return Elv5Assessment.fail;
    if (checks.any((value) => value == null)) return Elv5Assessment.notAssessed;
    return Elv5Assessment.pass;
  },
  nowUtc: nowUtc,
);

Map<String, Object?> _capacity(Cctv03CapacityAssessment value) =>
    <String, Object?>{
      'requiredBytes': value.required.value.toMap(),
      'availableBytes': value.available?.value.toMap(),
      'marginBytes': value.margin?.value.toMap(),
      'withinCapacity': value.withinCapacity,
    };

Map<String, Object?> _map(Object? value, String field) {
  if (value is! Map) throw FormatException('$field must be an object.');
  return Map<String, Object?>.from(value);
}

List<Map<String, Object?>> _objectList(Object? value, String field) {
  if (value is! List) throw FormatException('$field must be a list.');
  return [for (final item in value) _map(item, field)];
}

String _text(Map<String, Object?> value, String key) {
  final raw = value[key];
  if (raw is! String || raw.isEmpty)
    throw FormatException('$key must be text.');
  return raw;
}

String _decimal(Map<String, Object?> value, String key) {
  final raw = value[key];
  if (raw is! String) throw FormatException('$key must be decimal text.');
  Elv5Rational.parseDecimal(raw);
  return raw;
}

DateTime _utc(Map<String, Object?> value, String key) {
  final text = _text(value, key);
  final parsed = DateTime.tryParse(text);
  if (parsed == null || !parsed.isUtc || !text.endsWith('Z')) {
    throw FormatException('$key must be explicit UTC.');
  }
  return parsed;
}
