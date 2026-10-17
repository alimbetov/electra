import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:test/test.dart';

BitRate _mbps(int value) => BitRate(Elv5Rational.integer(value * 1000000));
BitRate _bps(int value) => BitRate(Elv5Rational.integer(value));

void main() {
  group('ELV5 CCTV-02 bandwidth kernel', () {
    test('counts unicast copies on shared edge and recorder ingress', () {
      final input = Cctv02Input(
        streams: <Cctv02Stream>[
          Cctv02Stream(
            streamId: 'stream-1',
            expectedBitRate: _mbps(4),
            peakBitRate: _mbps(6),
          ),
        ],
        subscriptions: <Cctv02Subscription>[
          Cctv02Subscription(
            subscriptionId: 'sub-a',
            streamId: 'stream-1',
            receiverId: 'viewer-a',
            deliveryMode: Cctv02DeliveryMode.unicast,
            directedEdgePath: <String>['E1', 'E2'],
            recorderId: 'recorder-1',
          ),
          Cctv02Subscription(
            subscriptionId: 'sub-b',
            streamId: 'stream-1',
            receiverId: 'viewer-b',
            deliveryMode: Cctv02DeliveryMode.unicast,
            directedEdgePath: <String>['E1', 'E3'],
          ),
        ],
      );

      final result = const Cctv02BandwidthKernel().evaluate(input);

      expect(result.edges['E1']!.expected.load, _mbps(8));
      expect(result.edges['E1']!.peak.load, _mbps(12));
      expect(result.edges['E2']!.peak.load, _mbps(6));
      expect(result.recorderIngress['recorder-1']!.expected.load, _mbps(4));
      expect(result.recorderIngress['recorder-1']!.peak.load, _mbps(6));
    });

    test('deduplicates multicast shared tree edge', () {
      final input = Cctv02Input(
        streams: <Cctv02Stream>[
          Cctv02Stream(
            streamId: 'stream-1',
            expectedBitRate: _mbps(4),
            peakBitRate: _mbps(6),
          ),
        ],
        multicastTrees: <Cctv02MulticastTree>[
          Cctv02MulticastTree(
            streamId: 'stream-1',
            multicastGroupId: 'group-a',
            directedEdges: <String>['E1', 'E2', 'E3'],
          ),
        ],
        subscriptions: <Cctv02Subscription>[
          Cctv02Subscription(
            subscriptionId: 'sub-a',
            streamId: 'stream-1',
            receiverId: 'viewer-a',
            deliveryMode: Cctv02DeliveryMode.multicast,
            multicastGroupId: 'group-a',
            directedEdgePath: <String>['E1', 'E2'],
          ),
          Cctv02Subscription(
            subscriptionId: 'sub-b',
            streamId: 'stream-1',
            receiverId: 'viewer-b',
            deliveryMode: Cctv02DeliveryMode.multicast,
            multicastGroupId: 'group-a',
            directedEdgePath: <String>['E1', 'E3'],
          ),
        ],
      );

      final result = const Cctv02BandwidthKernel().evaluate(input);

      expect(result.edges['E1']!.expected.load, _mbps(4));
      expect(result.edges['E1']!.peak.load, _mbps(6));
      expect(result.edges['E2']!.peak.load, _mbps(6));
      expect(result.edges['E3']!.peak.load, _mbps(6));
    });

    test('uses exact capacity headroom at equality and one-bit failure', () {
      final boundary = Cctv02Input(
        streams: <Cctv02Stream>[
          Cctv02Stream(
            streamId: 'stream-1',
            expectedBitRate: _mbps(4),
            peakBitRate: _mbps(6),
          ),
        ],
        subscriptions: <Cctv02Subscription>[
          Cctv02Subscription(
            subscriptionId: 'sub-a',
            streamId: 'stream-1',
            receiverId: 'a',
            deliveryMode: Cctv02DeliveryMode.unicast,
            directedEdgePath: <String>['E1'],
          ),
          Cctv02Subscription(
            subscriptionId: 'sub-b',
            streamId: 'stream-1',
            receiverId: 'b',
            deliveryMode: Cctv02DeliveryMode.unicast,
            directedEdgePath: <String>['E1'],
          ),
        ],
        capacities: <String, BitRate>{'E1': _mbps(12)},
      );

      final exact = const Cctv02BandwidthKernel().evaluate(boundary);
      expect(exact.edges['E1']!.peak.margin, _bps(0));
      expect(exact.edges['E1']!.peak.withinCapacity, isTrue);

      final over = Cctv02Input(
        streams: <Cctv02Stream>[
          ...boundary.streams,
          Cctv02Stream(
            streamId: 'stream-extra',
            expectedBitRate: _bps(1),
            peakBitRate: _bps(1),
          ),
        ],
        subscriptions: <Cctv02Subscription>[
          ...boundary.subscriptions,
          Cctv02Subscription(
            subscriptionId: 'sub-extra',
            streamId: 'stream-extra',
            receiverId: 'c',
            deliveryMode: Cctv02DeliveryMode.unicast,
            directedEdgePath: <String>['E1'],
          ),
        ],
        capacities: boundary.capacities,
      );
      final failed = const Cctv02BandwidthKernel().evaluate(over);
      expect(failed.edges['E1']!.peak.margin, _bps(-1));
      expect(failed.edges['E1']!.peak.withinCapacity, isFalse);
    });

    test(
        'keeps expected complete but peak unresolved when peak bitrate is missing',
        () {
      final input = Cctv02Input(
        streams: <Cctv02Stream>[
          Cctv02Stream(streamId: 'stream-1', expectedBitRate: _mbps(4)),
        ],
        subscriptions: <Cctv02Subscription>[
          Cctv02Subscription(
            subscriptionId: 'sub-a',
            streamId: 'stream-1',
            receiverId: 'a',
            deliveryMode: Cctv02DeliveryMode.unicast,
            directedEdgePath: <String>['E1'],
          ),
        ],
      );

      final result = const Cctv02BandwidthKernel().evaluate(input);
      expect(result.edges['E1']!.expected.complete, isTrue);
      expect(result.edges['E1']!.expected.load, _mbps(4));
      expect(result.edges['E1']!.peak.complete, isFalse);
    });

    test('fails closed for multicast without declared tree', () {
      final input = Cctv02Input(
        streams: <Cctv02Stream>[
          Cctv02Stream(streamId: 'stream-1', expectedBitRate: _mbps(4)),
        ],
        subscriptions: <Cctv02Subscription>[
          Cctv02Subscription(
            subscriptionId: 'sub-a',
            streamId: 'stream-1',
            receiverId: 'a',
            deliveryMode: Cctv02DeliveryMode.multicast,
            multicastGroupId: 'group-a',
            directedEdgePath: <String>['E1'],
          ),
        ],
      );

      expect(
        () => const Cctv02BandwidthKernel().evaluate(input),
        throwsStateError,
      );
    });
  });
}
