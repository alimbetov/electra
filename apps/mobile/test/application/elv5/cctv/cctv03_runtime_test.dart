import 'package:electra_mobile/application/elv5/calculation/elv5_blocked_capture.dart';
import 'package:electra_mobile/application/elv5/calculation/elv5_calculation_runtime.dart';
import 'package:electra_mobile/application/elv5/cctv/cctv03_runtime.dart';
import 'package:electra_mobile/application/elv5/cctv/elv5_cctv_persistence.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'captures absolute UTC recording facts and sizes storage exactly',
    () async {
      final store = _FakeCctvStore(pool: _pool(recurrence: false));
      final captured = await Cctv03PersistedInputResolver(store: store)
          .capture(_request());
      final result = const Cctv03StorageKernel().evaluate(captured.value);

      expect(captured.captureRevision, 3);
      expect(result.exactBaseBytes, Elv5Rational.integer(3600000000));
      expect(result.usable.required.value, Elv5Rational.integer(3960000000));
      expect(captured.dependencies.length, 3);
    },
  );

  test(
    'recurrence becomes durable blocked capture until pinned tzdb exists',
    () async {
      final resolver = Cctv03PersistedInputResolver(
        store: _FakeCctvStore(pool: _pool(recurrence: true)),
      );

      await expectLater(
        resolver.capture(_request()),
        throwsA(
          isA<Elv5CaptureBlockedException>()
              .having(
                (e) => e.reasonCode,
                'reasonCode',
                'CCTV03_RECURRENCE_EXPANDER_REQUIRED',
              )
              .having(
                (e) => e.evidence['tzdbVersion'],
                'tzdbVersion',
                'fixture-1',
              ),
        ),
      );
    },
  );
}

Elv5CalculationRequest _request() => Elv5CalculationRequest(
  projectId: 'p',
  designRevisionId: 'd',
  scope: Elv5ScopeRef(
    kind: Elv5ScopeKind.design,
    scopeId: 'd',
    scenarioKey: 'NONE',
  ),
  processCode: Elv5ProcessCode.cctv03,
  subject: Elv5SubjectRef(kind: 'RECORDING_POOL', id: 'pool-1'),
  expectedPointerGeneration: 0,
);

Elv5CctvAggregateSnapshot _pool({required bool recurrence}) =>
    Elv5CctvAggregateSnapshot(
      aggregateKind: 'CCTV_RECORDING_POOL',
      aggregateId: 'ELV5:CCTV:RECORDING_POOL:pool-1',
      subjectId: 'pool-1',
      revision: 3,
      payload: <String, Object?>{
        'poolId': 'pool-1',
        'horizon': <String, Object?>{
          'startUtc': '2026-01-01T00:00:00.000Z',
          'endUtc': '2026-01-01T01:00:00.000Z',
        },
        'temporalPolicy': <String, Object?>{
          'timeZoneId': 'UTC',
          'tzdbVersion': 'fixture-1',
          'gapRule': 'REJECT',
          'overlapRule': 'EARLIER_OFFSET',
        },
        'assignments': <Object?>[
          <String, Object?>{
            'encodedStreamId': 'main',
            'copyRole': 'PRIMARY',
            'scheduleProfileId': 'always',
            'expectedBitrateBps': '8000000',
            'upperBoundBitrateBps': '10000000',
            'evidenceBasis': 'PROJECT_SPECIFIED',
          },
        ],
        'scheduleSegments': <Object?>[
          <String, Object?>{
            'scheduleProfileId': 'always',
            'segmentId': 's1',
            'absoluteWindow': recurrence
                ? null
                : <String, Object?>{
                    'startUtc': '2026-01-01T00:00:00.000Z',
                    'endUtc': '2026-01-01T01:00:00.000Z',
                  },
            'recurrence': recurrence
                ? <String, Object?>{'rule': 'FREQ=DAILY', 'timeZoneLocal': true}
                : null,
          },
        ],
        'sizingBasis': 'EXPECTED_ESTIMATE',
        'reserveMultiplier': '1.1',
        'redundancyModel': null,
        'policyRef': null,
      },
    );

final class _FakeCctvStore implements Elv5CctvMutationStore {
  _FakeCctvStore({this.pool});
  final Elv5CctvAggregateSnapshot? pool;

  @override
  Future<Elv5CctvAggregateSnapshot?> loadRecordingPool({
    required String projectId,
    required String designRevisionId,
    required String poolId,
  }) async => pool;

  @override
  Future<Elv5CctvAggregateSnapshot?> loadCameraStreams({
    required String projectId,
    required String designRevisionId,
    required String cameraId,
  }) async => null;

  @override
  Future<void> replaceCameraStreams({
    required String projectId,
    required String designRevisionId,
    required String cameraId,
    required String bindingId,
    required int? expectedRootRevision,
    required Map<String, Object?> payload,
    required DateTime updatedAtUtc,
  }) => throw UnimplementedError();

  @override
  Future<void> replaceRecordingPool({
    required String projectId,
    required String designRevisionId,
    required String poolId,
    required String bindingId,
    required int? expectedRootRevision,
    required Map<String, Object?> payload,
    required DateTime updatedAtUtc,
  }) => throw UnimplementedError();
}
