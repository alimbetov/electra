import 'package:electra_mobile/application/elv5/calculation/elv5_calculation_runtime.dart';
import 'package:electra_mobile/application/elv5/cctv/cctv02_runtime.dart';
import 'package:electra_mobile/application/elv5/cctv/elv5_cctv_persistence.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'captures persisted camera streams and evaluates directed edge load',
    () async {
      final store = _FakeCctvStore(
        camera: Elv5CctvAggregateSnapshot(
          aggregateKind: 'CCTV_CAMERA_STREAMS',
          aggregateId: 'ELV5:CCTV:CAMERA_STREAMS:cam-1',
          subjectId: 'cam-1',
          revision: 7,
          payload: <String, Object?>{
            'cameraId': 'cam-1',
            'streams': <Object?>[
              <String, Object?>{
                'encodedStreamId': 'main',
                'codecProfileRef': 'codec:v1',
                'expectedBitrateBps': '8000000',
                'peakBitrateBps': '12000000',
                'expectedRateEvidence': <String, Object?>{},
                'peakRateEvidence': <String, Object?>{},
              },
            ],
            'subscriptions': <Object?>[
              <String, Object?>{
                'subscriptionId': 'sub-1',
                'encodedStreamId': 'main',
                'receiverId': 'viewer-1',
                'deliveryMode': 'UNICAST',
                'orderedNetworkEdgeIds': <String>['edge-a', 'edge-b'],
                'multicastGroupId': null,
                'multicastTree': null,
              },
            ],
            'transportOverheadModelRef': null,
          },
        ),
      );
      final request = Elv5CalculationRequest(
        projectId: 'project-1',
        designRevisionId: 'design-1',
        scope: Elv5ScopeRef(
          kind: Elv5ScopeKind.design,
          scopeId: 'design-1',
          scenarioKey: 'NONE',
        ),
        processCode: Elv5ProcessCode.cctv02,
        subject: Elv5SubjectRef(kind: 'CAMERA', id: 'cam-1'),
        expectedPointerGeneration: 0,
      );

      final captured = await Cctv02PersistedInputResolver(
        store: store,
      ).capture(request);
      final candidate = await buildCctv02Executor(
        nowUtc: () => DateTime.utc(2026, 10, 16),
      ).execute(captured);

      expect(captured.captureRevision, 7);
      expect(captured.dependencies, hasLength(3));
      expect(candidate.completion, Elv5Completion.complete);
      expect(candidate.assessment, Elv5Assessment.notAssessed);
      expect(candidate.output['schema'], 'electra.elv5-cctv02-output.v1');
      final output = const Cctv02BandwidthKernel().evaluate(captured.value);
      expect(
        output.edges['edge-a']!.expected.load.value,
        Elv5Rational.integer(8000000),
      );
      expect(output.recorderIngress, isEmpty);
    },
  );

  test('never infers recorder identity from receiver id', () async {
    final store = _FakeCctvStore(
      camera: Elv5CctvAggregateSnapshot(
        aggregateKind: 'CCTV_CAMERA_STREAMS',
        aggregateId: 'a',
        subjectId: 'cam-1',
        revision: 1,
        payload: <String, Object?>{
          'cameraId': 'cam-1',
          'streams': <Object?>[
            <String, Object?>{
              'encodedStreamId': 'main',
              'codecProfileRef': 'codec:v1',
              'expectedBitrateBps': '1',
              'peakBitrateBps': null,
              'expectedRateEvidence': <String, Object?>{},
              'peakRateEvidence': null,
            },
          ],
          'subscriptions': <Object?>[
            <String, Object?>{
              'subscriptionId': 'sub-1',
              'encodedStreamId': 'main',
              'receiverId': 'recorder-looking-id',
              'deliveryMode': 'UNICAST',
              'orderedNetworkEdgeIds': <String>['edge-a'],
              'multicastGroupId': null,
              'multicastTree': null,
            },
          ],
          'transportOverheadModelRef': null,
        },
      ),
    );
    final captured = await Cctv02PersistedInputResolver(store: store).capture(
      Elv5CalculationRequest(
        projectId: 'p',
        designRevisionId: 'd',
        scope: Elv5ScopeRef(
          kind: Elv5ScopeKind.design,
          scopeId: 'd',
          scenarioKey: 'NONE',
        ),
        processCode: Elv5ProcessCode.cctv02,
        subject: Elv5SubjectRef(kind: 'CAMERA', id: 'cam-1'),
        expectedPointerGeneration: 0,
      ),
    );

    expect(
      const Cctv02BandwidthKernel().evaluate(captured.value).recorderIngress,
      isEmpty,
    );
  });
}

final class _FakeCctvStore implements Elv5CctvMutationStore {
  _FakeCctvStore({this.camera, this.pool});

  final Elv5CctvAggregateSnapshot? camera;
  final Elv5CctvAggregateSnapshot? pool;

  @override
  Future<Elv5CctvAggregateSnapshot?> loadCameraStreams({
    required String projectId,
    required String designRevisionId,
    required String cameraId,
  }) async => camera;

  @override
  Future<Elv5CctvAggregateSnapshot?> loadRecordingPool({
    required String projectId,
    required String designRevisionId,
    required String poolId,
  }) async => pool;

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
