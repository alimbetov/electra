import '../../numeric/quantity.dart';
import '../../numeric/rational.dart';

enum Cctv03SizingBasis { expectedEstimate, guaranteedUpperBound }

final class Cctv03TemporalPolicy {
  Cctv03TemporalPolicy({
    required this.zoneId,
    required this.rulesHash,
  }) {
    if (zoneId.isEmpty || rulesHash.isEmpty) {
      throw ArgumentError('CCTV03 temporal policy must pin zone and rules hash.');
    }
  }

  final String zoneId;
  final String rulesHash;
}

final class Cctv03UtcInterval {
  Cctv03UtcInterval({required this.startUtc, required this.endUtc}) {
    if (!startUtc.isUtc || !endUtc.isUtc) {
      throw ArgumentError('CCTV03 intervals must use UTC DateTime values.');
    }
    if (!startUtc.isBefore(endUtc)) {
      throw ArgumentError('CCTV03 interval must be non-empty and half-open.');
    }
  }

  final DateTime startUtc;
  final DateTime endUtc;
}

final class Cctv03StreamRate {
  Cctv03StreamRate({
    required this.streamId,
    required this.expectedBitRate,
    this.guaranteedUpperBoundBitRate,
  }) {
    if (streamId.isEmpty) {
      throw ArgumentError('CCTV03 stream id must be non-empty.');
    }
    if (expectedBitRate.value.isNegative ||
        (guaranteedUpperBoundBitRate?.value.isNegative ?? false)) {
      throw ArgumentError('CCTV03 bitrate must be non-negative.');
    }
  }

  final String streamId;
  final BitRate expectedBitRate;
  final BitRate? guaranteedUpperBoundBitRate;
}

final class Cctv03RecordingAssignment {
  Cctv03RecordingAssignment({
    required this.streamId,
    required this.poolId,
    required this.copyRole,
    required Iterable<Cctv03UtcInterval> intervals,
  }) : intervals = List.unmodifiable(intervals) {
    if (streamId.isEmpty || poolId.isEmpty || copyRole.isEmpty) {
      throw ArgumentError('CCTV03 assignment identifiers must be non-empty.');
    }
    if (this.intervals.isEmpty) {
      throw ArgumentError('CCTV03 assignment must contain schedule intervals.');
    }
  }

  final String streamId;
  final String poolId;
  final String copyRole;
  final List<Cctv03UtcInterval> intervals;

  String get identity => '$streamId|$poolId|$copyRole';
}

final class Cctv03RedundancyModel {
  Cctv03RedundancyModel({required this.usableFraction}) {
    if (usableFraction <= Elv5Rational.zero || usableFraction > Elv5Rational.one) {
      throw ArgumentError('CCTV03 usable fraction must be in (0, 1].');
    }
  }

  final Elv5Rational usableFraction;
}

final class Cctv03Input {
  Cctv03Input({
    required this.poolId,
    required this.horizonStartUtc,
    required this.horizonEndUtc,
    required this.temporalPolicy,
    required this.sizingBasis,
    required Iterable<Cctv03StreamRate> streamRates,
    required Iterable<Cctv03RecordingAssignment> assignments,
    required this.reserveMultiplier,
    this.redundancy,
    this.availableUsable,
    this.availableRaw,
  }) : streamRates = List.unmodifiable(streamRates),
       assignments = List.unmodifiable(assignments) {
    if (poolId.isEmpty) {
      throw ArgumentError('CCTV03 pool id must be non-empty.');
    }
    if (!horizonStartUtc.isUtc || !horizonEndUtc.isUtc) {
      throw ArgumentError('CCTV03 horizon must use UTC DateTime values.');
    }
    if (!horizonStartUtc.isBefore(horizonEndUtc)) {
      throw ArgumentError('CCTV03 horizon must be non-empty and half-open.');
    }
    if (reserveMultiplier < Elv5Rational.one) {
      throw ArgumentError('CCTV03 reserve multiplier must be >= 1.');
    }
    if (availableUsable?.value.isNegative ?? false) {
      throw ArgumentError('CCTV03 available usable capacity must be non-negative.');
    }
    if (availableRaw?.value.isNegative ?? false) {
      throw ArgumentError('CCTV03 available raw capacity must be non-negative.');
    }
  }

  final String poolId;
  final DateTime horizonStartUtc;
  final DateTime horizonEndUtc;
  final Cctv03TemporalPolicy temporalPolicy;
  final Cctv03SizingBasis sizingBasis;
  final List<Cctv03StreamRate> streamRates;
  final List<Cctv03RecordingAssignment> assignments;
  final Elv5Rational reserveMultiplier;
  final Cctv03RedundancyModel? redundancy;
  final ByteCapacity? availableUsable;
  final ByteCapacity? availableRaw;
}

final class Cctv03CapacityAssessment {
  const Cctv03CapacityAssessment({required this.required, this.available});

  final ByteCapacity required;
  final ByteCapacity? available;

  ByteCapacity? get margin => available == null ? null : available! - required;
  bool? get withinCapacity =>
      margin == null ? null : margin!.value >= Elv5Rational.zero;
}

final class Cctv03Result {
  const Cctv03Result({
    required this.poolId,
    required this.sizingBasis,
    required this.exactBaseBytes,
    required this.exactReservedBytes,
    required this.recordedMicroseconds,
    required this.usable,
    required this.raw,
  });

  final String poolId;
  final Cctv03SizingBasis sizingBasis;
  final Elv5Rational exactBaseBytes;
  final Elv5Rational exactReservedBytes;
  final BigInt recordedMicroseconds;
  final Cctv03CapacityAssessment usable;
  final Cctv03CapacityAssessment? raw;
}

/// Pure CCTV-03 storage integration kernel.
///
/// Recurrence expansion/timezone resolution belongs to the captured schedule
/// boundary. This kernel only accepts reproducible UTC half-open intervals and
/// a pinned temporal rules hash, then performs exact integration and one pool
/// level ceil as required by the ELV5 contract.
final class Cctv03StorageKernel {
  const Cctv03StorageKernel();

  Cctv03Result evaluate(Cctv03Input input) {
    final rates = _indexRates(input.streamRates);
    final identities = <String>{};
    var baseBytes = Elv5Rational.zero;
    var recordedMicros = BigInt.zero;

    for (final assignment in input.assignments) {
      if (assignment.poolId != input.poolId) {
        throw StateError(
          'CCTV03_ASSIGNMENT_POOL_MISMATCH:${assignment.identity}:${input.poolId}',
        );
      }
      if (!identities.add(assignment.identity)) {
        throw StateError('CCTV03_DUPLICATE_ASSIGNMENT:${assignment.identity}');
      }
      final rate = rates[assignment.streamId];
      if (rate == null) {
        throw StateError('CCTV03_UNKNOWN_STREAM:${assignment.streamId}');
      }
      final selectedRate = switch (input.sizingBasis) {
        Cctv03SizingBasis.expectedEstimate => rate.expectedBitRate,
        Cctv03SizingBasis.guaranteedUpperBound =>
          rate.guaranteedUpperBoundBitRate ??
              (throw StateError(
                'CCTV03_GUARANTEED_RATE_REQUIRED:${assignment.streamId}',
              )),
      };

      final intervals = _clipAndUnion(
        assignment.intervals,
        input.horizonStartUtc,
        input.horizonEndUtc,
      );
      for (final interval in intervals) {
        final micros = BigInt.from(
          interval.endUtc.difference(interval.startUtc).inMicroseconds,
        );
        recordedMicros += micros;
        final seconds = Elv5Rational(micros, BigInt.from(1000000));
        baseBytes += selectedRate.value * seconds / Elv5Rational.integer(8);
      }
    }

    final reservedBytes = baseBytes * input.reserveMultiplier;
    final usableInteger = reservedBytes.ceil();
    final requiredUsable = ByteCapacity(
      Elv5Rational(usableInteger, BigInt.one),
    );
    final usableAssessment = Cctv03CapacityAssessment(
      required: requiredUsable,
      available: input.availableUsable,
    );

    Cctv03CapacityAssessment? rawAssessment;
    final redundancy = input.redundancy;
    if (redundancy != null) {
      final exactRaw = requiredUsable.value / redundancy.usableFraction;
      final rawInteger = exactRaw.ceil();
      rawAssessment = Cctv03CapacityAssessment(
        required: ByteCapacity(Elv5Rational(rawInteger, BigInt.one)),
        available: input.availableRaw,
      );
    }

    return Cctv03Result(
      poolId: input.poolId,
      sizingBasis: input.sizingBasis,
      exactBaseBytes: baseBytes,
      exactReservedBytes: reservedBytes,
      recordedMicroseconds: recordedMicros,
      usable: usableAssessment,
      raw: rawAssessment,
    );
  }

  static Map<String, Cctv03StreamRate> _indexRates(
    List<Cctv03StreamRate> values,
  ) {
    final result = <String, Cctv03StreamRate>{};
    for (final value in values) {
      if (result.containsKey(value.streamId)) {
        throw StateError('CCTV03_DUPLICATE_STREAM:${value.streamId}');
      }
      result[value.streamId] = value;
    }
    return result;
  }

  static List<Cctv03UtcInterval> _clipAndUnion(
    List<Cctv03UtcInterval> source,
    DateTime horizonStartUtc,
    DateTime horizonEndUtc,
  ) {
    final clipped = <Cctv03UtcInterval>[];
    for (final interval in source) {
      final start = interval.startUtc.isBefore(horizonStartUtc)
          ? horizonStartUtc
          : interval.startUtc;
      final end = interval.endUtc.isAfter(horizonEndUtc)
          ? horizonEndUtc
          : interval.endUtc;
      if (start.isBefore(end)) {
        clipped.add(Cctv03UtcInterval(startUtc: start, endUtc: end));
      }
    }
    clipped.sort((a, b) {
      final startOrder = a.startUtc.compareTo(b.startUtc);
      return startOrder != 0 ? startOrder : a.endUtc.compareTo(b.endUtc);
    });
    if (clipped.isEmpty) return const <Cctv03UtcInterval>[];

    final result = <Cctv03UtcInterval>[];
    var currentStart = clipped.first.startUtc;
    var currentEnd = clipped.first.endUtc;
    for (var i = 1; i < clipped.length; i++) {
      final next = clipped[i];
      if (!next.startUtc.isAfter(currentEnd)) {
        if (next.endUtc.isAfter(currentEnd)) currentEnd = next.endUtc;
        continue;
      }
      result.add(Cctv03UtcInterval(startUtc: currentStart, endUtc: currentEnd));
      currentStart = next.startUtc;
      currentEnd = next.endUtc;
    }
    result.add(Cctv03UtcInterval(startUtc: currentStart, endUtc: currentEnd));
    return List.unmodifiable(result);
  }
}
