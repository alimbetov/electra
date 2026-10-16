import 'dart:convert';

import 'package:engineering_core/engineering_core_elv5.dart';

import '../calculation/elv5_calculation_runtime.dart';
import '../calculation/elv5_kernel_executor.dart';
import '../persistence/elv5_runtime_persistence.dart';
import 'elv5_cctv_persistence.dart';

/// Captures the persisted CCTV camera-stream aggregate and converts it into the
/// immutable typed input consumed by the pure CCTV-02 kernel.
///
/// Important: the v1 camera-stream aggregate does not persist recorder-role
/// evidence. The resolver therefore never infers recorder identity from
/// receiverId; recorder ingress stays absent until an explicit persisted fact
/// is introduced by the wire/domain contract.
final class Cctv02PersistedInputResolver
    implements Elv5ProcessInputResolver<Cctv02Input> {
  Cctv02PersistedInputResolver({required this.store, DateTime Function()? nowUtc})
    : _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final Elv5CctvMutationStore store;
  final DateTime Function() _nowUtc;

  static const _encoder = Elv5CanonicalJsonV1();

  @override
  Elv5ProcessCode get processCode => Elv5ProcessCode.cctv02;

  @override
  Future<Elv5CapturedInput<Cctv02Input>> capture(
    Elv5CalculationRequest request,
  ) async {
    if (request.processCode != processCode) {
      throw StateError(
        'CCTV02_RESOLVER_PROCESS_CODE_MISMATCH:${request.processCode.wireCode}',
      );
    }
    if (request.subject.kind != 'CAMERA') {
      throw StateError('CCTV02_SUBJECT_KIND_MUST_BE_CAMERA');
    }

    final snapshot = await store.loadCameraStreams(
      projectId: request.projectId,
      designRevisionId: request.designRevisionId,
      cameraId: request.subject.id,
    );
    if (snapshot == null) {
      throw StateError('CCTV02_CAMERA_STREAM_FACTS_MISSING:${request.subject.id}');
    }

    final payload = snapshot.payload;
    final cameraId = _requiredText(payload, 'cameraId');
    if (cameraId != request.subject.id) {
      throw StateError('CCTV02_CAMERA_ID_MISMATCH:$cameraId:${request.subject.id}');
    }

    final streams = <Cctv02Stream>[];
    for (final raw in _requiredList(payload, 'streams')) {
      final stream = Map<String, Object?>.from(raw as Map);
      streams.add(
        Cctv02Stream(
          streamId: _requiredText(stream, 'encodedStreamId'),
          expectedBitRate: BitRate(
            Elv5Rational.parseDecimal(
              _requiredDecimalText(stream, 'expectedBitrateBps'),
            ),
          ),
          peakBitRate: stream['peakBitrateBps'] == null
              ? null
              : BitRate(
                  Elv5Rational.parseDecimal(
                    _requiredDecimalText(stream, 'peakBitrateBps'),
                  ),
                ),
        ),
      );
    }

    final subscriptions = <Cctv02Subscription>[];
    final multicastTrees = <String, Cctv02MulticastTree>{};
    for (final raw in _requiredList(payload, 'subscriptions')) {
      final subscription = Map<String, Object?>.from(raw as Map);
      final streamId = _requiredText(subscription, 'encodedStreamId');
      final modeText = _requiredText(subscription, 'deliveryMode');
      final mode = switch (modeText) {
        'UNICAST' => Cctv02DeliveryMode.unicast,
        'MULTICAST' => Cctv02DeliveryMode.multicast,
        _ => throw FormatException('Unsupported CCTV-02 deliveryMode: $modeText'),
      };
      final groupId = subscription['multicastGroupId'] as String?;
      final path = _requiredStringList(subscription, 'orderedNetworkEdgeIds');
      subscriptions.add(
        Cctv02Subscription(
          subscriptionId: _requiredText(subscription, 'subscriptionId'),
          streamId: streamId,
          receiverId: _requiredText(subscription, 'receiverId'),
          deliveryMode: mode,
          directedEdgePath: path,
          multicastGroupId: groupId,
          recorderId: null,
        ),
      );

      if (mode == Cctv02DeliveryMode.multicast) {
        final treeRaw = subscription['multicastTree'];
        if (treeRaw is! Map || groupId == null) {
          throw StateError('CCTV02_MULTICAST_TREE_REQUIRED:$streamId:$groupId');
        }
        final tree = Map<String, Object?>.from(treeRaw);
        final key = '$streamId\u0000$groupId';
        final candidate = Cctv02MulticastTree(
          streamId: streamId,
          multicastGroupId: groupId,
          directedEdges: _requiredStringList(tree, 'edgeIds'),
        );
        final previous = multicastTrees[key];
        if (previous != null &&
            !_sameStringSet(previous.directedEdges, candidate.directedEdges)) {
          throw StateError('CCTV02_MULTICAST_TREE_CONFLICT:$key');
        }
        multicastTrees[key] = candidate;
      }
    }

    final inputBasis = <String, Object?>{
      'schema': 'electra.elv5-cctv02-captured-input.v1',
      'aggregateKind': snapshot.aggregateKind,
      'aggregateId': snapshot.aggregateId,
      'aggregateRevision': snapshot.revision,
      'payload': payload,
    };
    final policyBasis = <String, Object?>{
      'schema': 'electra.elv5-cctv02-policy-basis.v1',
      'transportOverheadModelRef': payload['transportOverheadModelRef'],
      'edgeCapacityPolicy': 'NOT_CAPTURED_V1',
    };

    final dependencies = <Elv5DependencyMarker>[
      _dependency(
        request,
        relationKind: 'SET',
        domain: 'CCTV_CAMERA_STREAMS',
        subjectId: cameraId,
      ),
      for (final stream in streams)
        _dependency(
          request,
          relationKind: 'FACT',
          domain: 'CCTV_STREAM',
          subjectId: cameraId,
          memberId: stream.streamId,
        ),
      for (final subscription in subscriptions)
        _dependency(
          request,
          relationKind: 'SET',
          domain: 'CCTV_SUBSCRIPTION',
          subjectId: cameraId,
          memberId: subscription.subscriptionId,
        ),
      for (final tree in multicastTrees.values)
        _dependency(
          request,
          relationKind: 'SET',
          domain: 'CCTV_MULTICAST_TREE',
          subjectId: tree.streamId,
          memberId: tree.multicastGroupId,
        ),
    ];

    return Elv5CapturedInput<Cctv02Input>(
      request: request,
      value: Cctv02Input(
        streams: streams,
        subscriptions: subscriptions,
        multicastTrees: multicastTrees.values,
      ),
      inputFingerprint: _encoder.sha256(inputBasis),
      policyFingerprint: _encoder.sha256(policyBasis),
      dependencies: dependencies,
      upstreamPointerGenerations: const <String, int>{},
      captureRevision: snapshot.revision,
    );
  }

  Elv5DependencyMarker _dependency(
    Elv5CalculationRequest request, {
    required String relationKind,
    required String domain,
    required String subjectId,
    String? memberId,
  }) {
    final value = <String, Object?>{
      'schema': 'electra.elv5-dependency-key.v1',
      'relationKind': relationKind,
      'domain': domain,
      'subjectId': subjectId,
      if (memberId != null) 'memberId': memberId,
    };
    final dependencyKey = utf8.decode(_encoder.encode(value));
    return Elv5DependencyMarker(
      projectId: request.projectId,
      designRevisionId: request.designRevisionId,
      dependencyKey: dependencyKey,
      dependencyKeySha256: _encoder.sha256(value),
      logicalNodeKeySha256: _encoder.sha256(request.nodeKey.toCanonicalValue()),
      relationKind: relationKind,
      updatedAtUtc: _nowUtc().toUtc(),
    );
  }
}

Elv5PureKernelExecutor<Cctv02Input, Cctv02Result> buildCctv02Executor({
  DateTime Function()? nowUtc,
}) => Elv5PureKernelExecutor<Cctv02Input, Cctv02Result>(
  processCode: Elv5ProcessCode.cctv02,
  calculate: const Cctv02BandwidthKernel().evaluate,
  encodeOutput: _encodeCctv02Output,
  encodeEvidence: (captured, output) => <String, Object?>{
    'schema': 'electra.elv5-cctv02-evidence.v1',
    'source': 'ELV5_PERSISTED_CAMERA_STREAMS',
    'captureRevision': captured.captureRevision,
    'dependencyKeySha256s': [
      for (final dependency in captured.dependencies)
        dependency.dependencyKeySha256,
    ]..sort(),
    'recorderRoleEvidence': 'NOT_CAPTURED_V1',
  },
  executionOf: (_) => Elv5Execution.succeeded,
  completionOf: (output) {
    final peakComplete = output.edges.values.every((edge) => edge.peak.complete) &&
        output.recorderIngress.values.every((value) => value.peak.complete);
    return peakComplete ? Elv5Completion.complete : Elv5Completion.incomplete;
  },
  assessmentOf: (_) => Elv5Assessment.notAssessed,
  nowUtc: nowUtc,
);

Map<String, Object?> _encodeCctv02Output(Cctv02Result output) =>
    <String, Object?>{
      'schema': 'electra.elv5-cctv02-output.v1',
      'edges': <String, Object?>{
        for (final edgeId in output.edges.keys.toList()..sort())
          edgeId: _encodeTraffic(output.edges[edgeId]!),
      },
      'recorderIngress': <String, Object?>{
        for (final recorderId in output.recorderIngress.keys.toList()..sort())
          recorderId: <String, Object?>{
            'expected': _encodeTrafficValue(
              output.recorderIngress[recorderId]!.expected,
            ),
            'peak': _encodeTrafficValue(
              output.recorderIngress[recorderId]!.peak,
            ),
          },
      },
    };

Map<String, Object?> _encodeTraffic(Cctv02EdgeTraffic traffic) =>
    <String, Object?>{
      'expected': _encodeTrafficValue(traffic.expected),
      'peak': _encodeTrafficValue(traffic.peak),
    };

Map<String, Object?> _encodeTrafficValue(Cctv02TrafficValue value) =>
    <String, Object?>{
      'loadBps': value.load.value.toMap(),
      'complete': value.complete,
      'capacityBps': value.capacity?.value.toMap(),
      'marginBps': value.margin?.value.toMap(),
      'withinCapacity': value.withinCapacity,
    };

String _requiredText(Map<String, Object?> value, String key) {
  final raw = value[key];
  if (raw is! String || raw.isEmpty) {
    throw FormatException('Expected non-empty $key.');
  }
  return raw;
}

String _requiredDecimalText(Map<String, Object?> value, String key) {
  final raw = value[key];
  if (raw is! String) throw FormatException('Expected decimal string $key.');
  Elv5Rational.parseDecimal(raw);
  return raw;
}

List<Object?> _requiredList(Map<String, Object?> value, String key) {
  final raw = value[key];
  if (raw is! List) throw FormatException('Expected list $key.');
  return List<Object?>.from(raw);
}

List<String> _requiredStringList(Map<String, Object?> value, String key) {
  final raw = _requiredList(value, key);
  if (raw.any((item) => item is! String || (item as String).isEmpty)) {
    throw FormatException('Expected non-empty string list $key.');
  }
  return raw.cast<String>();
}

bool _sameStringSet(Set<String> left, Set<String> right) =>
    left.length == right.length && left.containsAll(right);
