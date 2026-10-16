import '../../numeric/quantity.dart';
import '../../numeric/rational.dart';

enum Cctv02DeliveryMode { unicast, multicast }

enum Cctv02TrafficCase { expected, peak }

final class Cctv02Stream {
  const Cctv02Stream({
    required this.streamId,
    required this.expectedBitRate,
    this.peakBitRate,
  });

  final String streamId;
  final BitRate expectedBitRate;
  final BitRate? peakBitRate;
}

final class Cctv02Subscription {
  Cctv02Subscription({
    required this.subscriptionId,
    required this.streamId,
    required this.receiverId,
    required this.deliveryMode,
    required Iterable<String> directedEdgePath,
    this.multicastGroupId,
    this.recorderId,
  }) : directedEdgePath = List.unmodifiable(directedEdgePath) {
    if (subscriptionId.isEmpty || streamId.isEmpty || receiverId.isEmpty) {
      throw ArgumentError('CCTV02 identifiers must be non-empty.');
    }
    if (this.directedEdgePath.isEmpty) {
      throw ArgumentError('CCTV02 subscription path must not be empty.');
    }
    if (this.directedEdgePath.toSet().length != this.directedEdgePath.length) {
      throw ArgumentError('CCTV02 subscription path contains duplicate edges.');
    }
    if (deliveryMode == Cctv02DeliveryMode.multicast &&
        (multicastGroupId == null || multicastGroupId!.isEmpty)) {
      throw ArgumentError('CCTV02 multicast subscription requires group id.');
    }
  }

  final String subscriptionId;
  final String streamId;
  final String receiverId;
  final Cctv02DeliveryMode deliveryMode;
  final List<String> directedEdgePath;
  final String? multicastGroupId;
  final String? recorderId;
}

final class Cctv02MulticastTree {
  Cctv02MulticastTree({
    required this.streamId,
    required this.multicastGroupId,
    required Iterable<String> directedEdges,
  }) : directedEdges = Set.unmodifiable(directedEdges) {
    if (streamId.isEmpty || multicastGroupId.isEmpty) {
      throw ArgumentError('CCTV02 multicast tree identifiers must be non-empty.');
    }
    if (this.directedEdges.isEmpty) {
      throw ArgumentError('CCTV02 multicast tree must contain edges.');
    }
  }

  final String streamId;
  final String multicastGroupId;
  final Set<String> directedEdges;
}

final class Cctv02Input {
  Cctv02Input({
    required Iterable<Cctv02Stream> streams,
    required Iterable<Cctv02Subscription> subscriptions,
    Iterable<Cctv02MulticastTree> multicastTrees = const [],
    Map<String, BitRate> capacities = const {},
  }) : streams = List.unmodifiable(streams),
       subscriptions = List.unmodifiable(subscriptions),
       multicastTrees = List.unmodifiable(multicastTrees),
       capacities = Map.unmodifiable(capacities);

  final List<Cctv02Stream> streams;
  final List<Cctv02Subscription> subscriptions;
  final List<Cctv02MulticastTree> multicastTrees;
  final Map<String, BitRate> capacities;
}

final class Cctv02TrafficValue {
  const Cctv02TrafficValue({
    required this.load,
    required this.complete,
    this.capacity,
  });

  final BitRate load;
  final bool complete;
  final BitRate? capacity;

  BitRate? get margin => capacity == null ? null : capacity! - load;
  bool? get withinCapacity => margin == null ? null : margin!.value >= Elv5Rational.zero;
}

final class Cctv02EdgeTraffic {
  const Cctv02EdgeTraffic({required this.expected, required this.peak});

  final Cctv02TrafficValue expected;
  final Cctv02TrafficValue peak;
}

final class Cctv02IngressTraffic {
  const Cctv02IngressTraffic({required this.expected, required this.peak});

  final Cctv02TrafficValue expected;
  final Cctv02TrafficValue peak;
}

final class Cctv02Result {
  Cctv02Result({
    required Map<String, Cctv02EdgeTraffic> edges,
    required Map<String, Cctv02IngressTraffic> recorderIngress,
  }) : edges = Map.unmodifiable(edges),
       recorderIngress = Map.unmodifiable(recorderIngress);

  final Map<String, Cctv02EdgeTraffic> edges;
  final Map<String, Cctv02IngressTraffic> recorderIngress;
}

/// Pure CCTV-02 kernel.
///
/// The kernel owns no repositories, topology mutation or inferred bitrate
/// model. Inputs must already contain realized directed paths and explicit
/// engineering bitrates captured by the application-layer resolver.
final class Cctv02BandwidthKernel {
  const Cctv02BandwidthKernel();

  Cctv02Result evaluate(Cctv02Input input) {
    final streams = _indexStreams(input.streams);
    final trees = _indexTrees(input.multicastTrees);
    _validateSubscriptions(input.subscriptions, streams, trees);

    final expectedEdges = <String, BitRate>{};
    final peakEdges = <String, BitRate>{};
    final peakIncompleteEdges = <String>{};
    final expectedIngress = <String, BitRate>{};
    final peakIngress = <String, BitRate>{};
    final peakIncompleteIngress = <String>{};

    final multicastEdgeCopies = <String>{};
    final recorderFlowCopies = <String>{};

    for (final subscription in input.subscriptions) {
      final stream = streams[subscription.streamId]!;
      for (final edgeId in subscription.directedEdgePath) {
        final copyIdentity = switch (subscription.deliveryMode) {
          Cctv02DeliveryMode.unicast =>
            'U|${stream.streamId}|${subscription.subscriptionId}|$edgeId',
          Cctv02DeliveryMode.multicast =>
            'M|${stream.streamId}|${subscription.multicastGroupId}|$edgeId',
        };
        if (subscription.deliveryMode == Cctv02DeliveryMode.multicast &&
            !multicastEdgeCopies.add(copyIdentity)) {
          continue;
        }
        _add(expectedEdges, edgeId, stream.expectedBitRate);
        final peak = stream.peakBitRate;
        if (peak == null) {
          peakIncompleteEdges.add(edgeId);
        } else {
          _add(peakEdges, edgeId, peak);
        }
      }

      final recorderId = subscription.recorderId;
      if (recorderId != null) {
        final flowIdentity =
            '${stream.streamId}|$recorderId|${subscription.deliveryMode == Cctv02DeliveryMode.multicast ? subscription.multicastGroupId : subscription.subscriptionId}';
        if (recorderFlowCopies.add(flowIdentity)) {
          _add(expectedIngress, recorderId, stream.expectedBitRate);
          final peak = stream.peakBitRate;
          if (peak == null) {
            peakIncompleteIngress.add(recorderId);
          } else {
            _add(peakIngress, recorderId, peak);
          }
        }
      }
    }

    final edgeIds = <String>{
      ...expectedEdges.keys,
      ...peakEdges.keys,
      ...peakIncompleteEdges,
      ...input.capacities.keys,
    }.toList()..sort();
    final edges = <String, Cctv02EdgeTraffic>{};
    for (final edgeId in edgeIds) {
      edges[edgeId] = Cctv02EdgeTraffic(
        expected: Cctv02TrafficValue(
          load: expectedEdges[edgeId] ?? _zeroRate,
          complete: true,
          capacity: input.capacities[edgeId],
        ),
        peak: Cctv02TrafficValue(
          load: peakEdges[edgeId] ?? _zeroRate,
          complete: !peakIncompleteEdges.contains(edgeId),
          capacity: input.capacities[edgeId],
        ),
      );
    }

    final recorderIds = <String>{
      ...expectedIngress.keys,
      ...peakIngress.keys,
      ...peakIncompleteIngress,
    }.toList()..sort();
    final ingress = <String, Cctv02IngressTraffic>{};
    for (final recorderId in recorderIds) {
      ingress[recorderId] = Cctv02IngressTraffic(
        expected: Cctv02TrafficValue(
          load: expectedIngress[recorderId] ?? _zeroRate,
          complete: true,
        ),
        peak: Cctv02TrafficValue(
          load: peakIngress[recorderId] ?? _zeroRate,
          complete: !peakIncompleteIngress.contains(recorderId),
        ),
      );
    }

    return Cctv02Result(edges: edges, recorderIngress: ingress);
  }

  static Map<String, Cctv02Stream> _indexStreams(List<Cctv02Stream> values) {
    final result = <String, Cctv02Stream>{};
    for (final stream in values) {
      if (stream.streamId.isEmpty) {
        throw ArgumentError('CCTV02 stream id must be non-empty.');
      }
      if (stream.expectedBitRate.value.isNegative ||
          (stream.peakBitRate?.value.isNegative ?? false)) {
        throw ArgumentError('CCTV02 bitrate must be non-negative.');
      }
      if (result.putIfAbsent(stream.streamId, () => stream) != stream) {
        throw ArgumentError('CCTV02 duplicate stream id: ${stream.streamId}.');
      }
    }
    return result;
  }

  static Map<String, Cctv02MulticastTree> _indexTrees(
    List<Cctv02MulticastTree> values,
  ) {
    final result = <String, Cctv02MulticastTree>{};
    for (final tree in values) {
      final key = '${tree.streamId}|${tree.multicastGroupId}';
      if (result.containsKey(key)) {
        throw ArgumentError('CCTV02 duplicate multicast tree: $key.');
      }
      result[key] = tree;
    }
    return result;
  }

  static void _validateSubscriptions(
    List<Cctv02Subscription> subscriptions,
    Map<String, Cctv02Stream> streams,
    Map<String, Cctv02MulticastTree> trees,
  ) {
    final ids = <String>{};
    for (final subscription in subscriptions) {
      if (!ids.add(subscription.subscriptionId)) {
        throw ArgumentError(
          'CCTV02 duplicate subscription id: ${subscription.subscriptionId}.',
        );
      }
      if (!streams.containsKey(subscription.streamId)) {
        throw StateError('CCTV02_UNKNOWN_STREAM:${subscription.streamId}');
      }
      if (subscription.deliveryMode == Cctv02DeliveryMode.multicast) {
        final key = '${subscription.streamId}|${subscription.multicastGroupId}';
        final tree = trees[key];
        if (tree == null) {
          throw StateError('CCTV02_MULTICAST_TREE_REQUIRED:$key');
        }
        for (final edgeId in subscription.directedEdgePath) {
          if (!tree.directedEdges.contains(edgeId)) {
            throw StateError('CCTV02_PATH_OUTSIDE_MULTICAST_TREE:$key:$edgeId');
          }
        }
      }
    }
  }

  static void _add(Map<String, BitRate> target, String key, BitRate value) {
    target[key] = (target[key] ?? _zeroRate) + value;
  }

  static final BitRate _zeroRate = BitRate(Elv5Rational.zero);
}
