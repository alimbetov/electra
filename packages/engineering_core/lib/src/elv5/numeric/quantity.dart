import 'rational.dart';

abstract class Elv5Dimension {
  const Elv5Dimension();
}

final class LengthDim extends Elv5Dimension {
  const LengthDim();
}

final class DurationDim extends Elv5Dimension {
  const DurationDim();
}

final class VoltageDim extends Elv5Dimension {
  const VoltageDim();
}

final class CurrentDim extends Elv5Dimension {
  const CurrentDim();
}

final class ResistanceDim extends Elv5Dimension {
  const ResistanceDim();
}

final class PowerDim extends Elv5Dimension {
  const PowerDim();
}

final class EnergyDim extends Elv5Dimension {
  const EnergyDim();
}

final class BitRateDim extends Elv5Dimension {
  const BitRateDim();
}

final class ByteCapacityDim extends Elv5Dimension {
  const ByteCapacityDim();
}

final class RatioDim extends Elv5Dimension {
  const RatioDim();
}

final class AttenuationDbDim extends Elv5Dimension {
  const AttenuationDbDim();
}

final class OpticalLevelDbmDim extends Elv5Dimension {
  const OpticalLevelDbmDim();
}

final class AngleRadDim extends Elv5Dimension {
  const AngleRadDim();
}

final class MassDim extends Elv5Dimension {
  const MassDim();
}

/// Exact value in the canonical base unit of dimension [D].
final class Elv5Quantity<D extends Elv5Dimension>
    implements Comparable<Elv5Quantity<D>> {
  const Elv5Quantity(this.value);

  final Elv5Rational value;

  Elv5Quantity<D> operator +(Elv5Quantity<D> other) =>
      Elv5Quantity<D>(value + other.value);
  Elv5Quantity<D> operator -(Elv5Quantity<D> other) =>
      Elv5Quantity<D>(value - other.value);
  Elv5Quantity<D> operator -() => Elv5Quantity<D>(-value);

  Elv5Quantity<D> scale(Elv5Rational factor) => Elv5Quantity<D>(value * factor);

  @override
  int compareTo(Elv5Quantity<D> other) => value.compareTo(other.value);

  bool operator <(Elv5Quantity<D> other) => compareTo(other) < 0;
  bool operator <=(Elv5Quantity<D> other) => compareTo(other) <= 0;
  bool operator >(Elv5Quantity<D> other) => compareTo(other) > 0;
  bool operator >=(Elv5Quantity<D> other) => compareTo(other) >= 0;

  Map<String, Object?> toMap() => value.toMap();

  @override
  bool operator ==(Object other) =>
      other is Elv5Quantity<D> && value == other.value;

  @override
  int get hashCode => Object.hash(runtimeType, value);

  @override
  String toString() => value.toString();
}

typedef Length = Elv5Quantity<LengthDim>;
typedef Duration = Elv5Quantity<DurationDim>;
typedef Voltage = Elv5Quantity<VoltageDim>;
typedef Current = Elv5Quantity<CurrentDim>;
typedef Resistance = Elv5Quantity<ResistanceDim>;
typedef Power = Elv5Quantity<PowerDim>;
typedef Energy = Elv5Quantity<EnergyDim>;
typedef BitRate = Elv5Quantity<BitRateDim>;
typedef ByteCapacity = Elv5Quantity<ByteCapacityDim>;
typedef Ratio = Elv5Quantity<RatioDim>;
typedef LossDb = Elv5Quantity<AttenuationDbDim>;
typedef LevelDbm = Elv5Quantity<OpticalLevelDbmDim>;
typedef AngleRad = Elv5Quantity<AngleRadDim>;
typedef Mass = Elv5Quantity<MassDim>;
