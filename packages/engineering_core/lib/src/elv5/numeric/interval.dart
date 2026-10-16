import 'quantity.dart';

/// Closed conservative interval. Overlap with a threshold is unresolved rather
/// than an optimistic pass.
final class Elv5Interval<D extends Elv5Dimension> {
  Elv5Interval(this.lower, this.upper) {
    if (lower > upper) {
      throw ArgumentError('Interval bounds are reversed.');
    }
  }

  factory Elv5Interval.exact(Elv5Quantity<D> value) =>
      Elv5Interval<D>(value, value);

  final Elv5Quantity<D> lower;
  final Elv5Quantity<D> upper;

  bool get isExact => lower == upper;

  Elv5Interval<D> operator +(Elv5Interval<D> other) => Elv5Interval<D>(
        lower + other.lower,
        upper + other.upper,
      );

  Elv5Interval<D> operator -(Elv5Interval<D> other) => Elv5Interval<D>(
        lower - other.upper,
        upper - other.lower,
      );

  Map<String, Object?> toMap() => <String, Object?>{
        'lower': lower.toMap(),
        'upper': upper.toMap(),
      };
}
