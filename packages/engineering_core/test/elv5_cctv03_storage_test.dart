import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:test/test.dart';

BitRate _bps(int value) => BitRate(Elv5Rational.integer(value));
ByteCapacity _bytes(int value) => ByteCapacity(Elv5Rational.integer(value));

void main() {
  group('ELV5 CCTV-03 storage kernel', () {
    test('integrates continuous 8 Mbps for 30 days with reserve and mirror', () {
      final start = DateTime.utc(2026, 1, 1);
      final end = start.add(const Duration(days: 30));
      final input = Cctv03Input(
        poolId: 'pool-a',
        horizonStartUtc: start,
        horizonEndUtc: end,
        temporalPolicy: const Cctv03TemporalPolicy(
          zoneId: 'UTC',
          rulesHash: 'tz-rules-v1',
        ),
        sizingBasis: Cctv03SizingBasis.guaranteedUpperBound,
        streamRates: <Cctv03StreamRate>[
          Cctv03StreamRate(
            streamId: 'stream-1',
            expectedBitRate: _bps(8000000),
            guaranteedUpperBoundBitRate: _bps(8000000),
          ),
        ],
        assignments: <Cctv03RecordingAssignment>[
          Cctv03RecordingAssignment(
            streamId: 'stream-1',
            poolId: 'pool-a',
            copyRole: 'PRIMARY',
            intervals: <Cctv03UtcInterval>[
              Cctv03UtcInterval(startUtc: start, endUtc: end),
            ],
          ),
        ],
        reserveMultiplier: Elv5Rational.parseDecimal('1.1'),
        redundancy: Cctv03RedundancyModel(
          usableFraction: Elv5Rational.parseDecimal('0.5'),
        ),
      );

      final result = const Cctv03StorageKernel().evaluate(input);

      expect(
        result.exactBaseBytes,
        Elv5Rational.integer(2592000000000),
      );
      expect(
        result.usable.required,
        _bytes(2851200000000),
      );
      expect(
        result.raw!.required,
        _bytes(5702400000000),
      );
      expect(result.recordedTime, const Duration(days: 30));
    });

    test('ceils once at pool boundary and preserves zero capacity margin', () {
      final start = DateTime.utc(2026, 1, 1);
      final end = start.add(const Duration(seconds: 1));
      final result = const Cctv03StorageKernel().evaluate(
        Cctv03Input(
          poolId: 'pool-a',
          horizonStartUtc: start,
          horizonEndUtc: end,
          temporalPolicy: const Cctv03TemporalPolicy(
            zoneId: 'UTC',
            rulesHash: 'tz-rules-v1',
          ),
          sizingBasis: Cctv03SizingBasis.expectedEstimate,
          streamRates: <Cctv03StreamRate>[
            Cctv03StreamRate(
              streamId: 'stream-1',
              expectedBitRate: _bps(1),
            ),
          ],
          assignments: <Cctv03RecordingAssignment>[
            Cctv03RecordingAssignment(
              streamId: 'stream-1',
              poolId: 'pool-a',
              copyRole: 'PRIMARY',
              intervals: <Cctv03UtcInterval>[
                Cctv03UtcInterval(startUtc: start, endUtc: end),
              ],
            ),
          ],
          reserveMultiplier: Elv5Rational.one,
          availableUsable: _bytes(1),
        ),
      );

      expect(result.exactBaseBytes, Elv5Rational(BigInt.one, BigInt.from(8)));
      expect(result.usable.required, _bytes(1));
      expect(result.usable.margin, _bytes(0));
      expect(result.usable.withinCapacity, isTrue);
    });

    test('unions overlapping schedule intervals for one recording identity', () {
      final start = DateTime.utc(2026, 1, 1);
      final result = const Cctv03StorageKernel().evaluate(
        Cctv03Input(
          poolId: 'pool-a',
          horizonStartUtc: start,
          horizonEndUtc: start.add(const Duration(seconds: 20)),
          temporalPolicy: const Cctv03TemporalPolicy(
            zoneId: 'UTC',
            rulesHash: 'tz-rules-v1',
          ),
          sizingBasis: Cctv03SizingBasis.expectedEstimate,
          streamRates: <Cctv03StreamRate>[
            Cctv03StreamRate(
              streamId: 'stream-1',
              expectedBitRate: _bps(8),
            ),
          ],
          assignments: <Cctv03RecordingAssignment>[
            Cctv03RecordingAssignment(
              streamId: 'stream-1',
              poolId: 'pool-a',
              copyRole: 'PRIMARY',
              intervals: <Cctv03UtcInterval>[
                Cctv03UtcInterval(
                  startUtc: start,
                  endUtc: start.add(const Duration(seconds: 10)),
                ),
                Cctv03UtcInterval(
                  startUtc: start.add(const Duration(seconds: 5)),
                  endUtc: start.add(const Duration(seconds: 15)),
                ),
              ],
            ),
          ],
          reserveMultiplier: Elv5Rational.one,
        ),
      );

      expect(result.recordedTime, const Duration(seconds: 15));
      expect(result.usable.required, _bytes(15));
    });

    test('clips intervals to requested horizon', () {
      final start = DateTime.utc(2026, 1, 10);
      final result = const Cctv03StorageKernel().evaluate(
        Cctv03Input(
          poolId: 'pool-a',
          horizonStartUtc: start,
          horizonEndUtc: start.add(const Duration(seconds: 10)),
          temporalPolicy: const Cctv03TemporalPolicy(
            zoneId: 'UTC',
            rulesHash: 'tz-rules-v1',
          ),
          sizingBasis: Cctv03SizingBasis.expectedEstimate,
          streamRates: <Cctv03StreamRate>[
            Cctv03StreamRate(
              streamId: 'stream-1',
              expectedBitRate: _bps(8),
            ),
          ],
          assignments: <Cctv03RecordingAssignment>[
            Cctv03RecordingAssignment(
              streamId: 'stream-1',
              poolId: 'pool-a',
              copyRole: 'PRIMARY',
              intervals: <Cctv03UtcInterval>[
                Cctv03UtcInterval(
                  startUtc: start.subtract(const Duration(seconds: 5)),
                  endUtc: start.add(const Duration(seconds: 5)),
                ),
              ],
            ),
          ],
          reserveMultiplier: Elv5Rational.one,
        ),
      );

      expect(result.recordedTime, const Duration(seconds: 5));
      expect(result.usable.required, _bytes(5));
    });

    test('fails closed when guaranteed upper-bound bitrate is missing', () {
      final start = DateTime.utc(2026, 1, 1);
      final input = Cctv03Input(
        poolId: 'pool-a',
        horizonStartUtc: start,
        horizonEndUtc: start.add(const Duration(seconds: 1)),
        temporalPolicy: const Cctv03TemporalPolicy(
          zoneId: 'UTC',
          rulesHash: 'tz-rules-v1',
        ),
        sizingBasis: Cctv03SizingBasis.guaranteedUpperBound,
        streamRates: <Cctv03StreamRate>[
          Cctv03StreamRate(
            streamId: 'stream-1',
            expectedBitRate: _bps(8),
          ),
        ],
        assignments: <Cctv03RecordingAssignment>[
          Cctv03RecordingAssignment(
            streamId: 'stream-1',
            poolId: 'pool-a',
            copyRole: 'PRIMARY',
            intervals: <Cctv03UtcInterval>[
              Cctv03UtcInterval(
                startUtc: start,
                endUtc: start.add(const Duration(seconds: 1)),
              ),
            ],
          ),
        ],
        reserveMultiplier: Elv5Rational.one,
      );

      expect(
        () => const Cctv03StorageKernel().evaluate(input),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('CCTV03_GUARANTEED_RATE_REQUIRED'),
          ),
        ),
      );
    });

    test('rejects duplicate stream-pool-copy recording identity', () {
      final start = DateTime.utc(2026, 1, 1);
      Cctv03RecordingAssignment assignment() => Cctv03RecordingAssignment(
        streamId: 'stream-1',
        poolId: 'pool-a',
        copyRole: 'PRIMARY',
        intervals: <Cctv03UtcInterval>[
          Cctv03UtcInterval(
            startUtc: start,
            endUtc: start.add(const Duration(seconds: 1)),
          ),
        ],
      );
      final input = Cctv03Input(
        poolId: 'pool-a',
        horizonStartUtc: start,
        horizonEndUtc: start.add(const Duration(seconds: 1)),
        temporalPolicy: const Cctv03TemporalPolicy(
          zoneId: 'UTC',
          rulesHash: 'tz-rules-v1',
        ),
        sizingBasis: Cctv03SizingBasis.expectedEstimate,
        streamRates: <Cctv03StreamRate>[
          Cctv03StreamRate(
            streamId: 'stream-1',
            expectedBitRate: _bps(8),
          ),
        ],
        assignments: <Cctv03RecordingAssignment>[assignment(), assignment()],
        reserveMultiplier: Elv5Rational.one,
      );

      expect(
        () => const Cctv03StorageKernel().evaluate(input),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('CCTV03_DUPLICATE_ASSIGNMENT'),
          ),
        ),
      );
    });
  });
}
