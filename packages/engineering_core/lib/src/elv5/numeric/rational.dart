/// Exact, normalized rational used by ELV5 engineering calculations.
///
/// Floating-point input is deliberately not accepted at the engineering
/// boundary. Decimal wire values are parsed from strings.
final class Elv5Rational implements Comparable<Elv5Rational> {
  factory Elv5Rational(BigInt numerator, BigInt denominator) {
    if (denominator == BigInt.zero) {
      throw ArgumentError.value(denominator, 'denominator', 'Must be nonzero.');
    }
    final sign = denominator.isNegative ? -BigInt.one : BigInt.one;
    final gcd = numerator.gcd(denominator);
    return Elv5Rational._(numerator ~/ gcd * sign, denominator ~/ gcd * sign);
  }

  const Elv5Rational._(this.numerator, this.denominator);

  factory Elv5Rational.integer(int value) =>
      Elv5Rational(BigInt.from(value), BigInt.one);

  factory Elv5Rational.parseDecimal(String text) {
    if (!_decimal.hasMatch(text)) {
      throw FormatException('Expected canonical decimal string.', text);
    }
    final parts = text.split('.');
    final fraction = parts.length == 2 ? parts[1] : '';
    return Elv5Rational(
      BigInt.parse('${parts[0]}$fraction'),
      BigInt.from(10).pow(fraction.length),
    );
  }

  factory Elv5Rational.fromMap(Map<String, Object?> map) {
    if (map.length != 2 ||
        map['numerator'] is! String ||
        map['denominator'] is! String) {
      throw const FormatException('Expected numerator/denominator strings.');
    }
    return Elv5Rational(
      BigInt.parse(map['numerator']! as String),
      BigInt.parse(map['denominator']! as String),
    );
  }

  static final _decimal = RegExp(r'^-?(0|[1-9][0-9]{0,29})(\.[0-9]{1,12})?$');
  static final zero = Elv5Rational.integer(0);
  static final one = Elv5Rational.integer(1);

  final BigInt numerator;
  final BigInt denominator;

  bool get isZero => numerator == BigInt.zero;
  bool get isNegative => numerator.isNegative;
  bool get isInteger => numerator.remainder(denominator) == BigInt.zero;

  Elv5Rational operator +(Elv5Rational other) => Elv5Rational(
    numerator * other.denominator + other.numerator * denominator,
    denominator * other.denominator,
  );
  Elv5Rational operator -(Elv5Rational other) => this + -other;
  Elv5Rational operator -() => Elv5Rational(-numerator, denominator);
  Elv5Rational operator *(Elv5Rational other) => Elv5Rational(
    numerator * other.numerator,
    denominator * other.denominator,
  );
  Elv5Rational operator /(Elv5Rational other) {
    if (other.isZero) throw ArgumentError('Cannot divide by zero.');
    return Elv5Rational(
      numerator * other.denominator,
      denominator * other.numerator,
    );
  }

  BigInt ceil() {
    final quotient = numerator ~/ denominator;
    final remainder = numerator.remainder(denominator);
    if (remainder == BigInt.zero || numerator.isNegative) return quotient;
    return quotient + BigInt.one;
  }

  @override
  int compareTo(Elv5Rational other) =>
      (numerator * other.denominator).compareTo(other.numerator * denominator);

  bool operator <(Elv5Rational other) => compareTo(other) < 0;
  bool operator <=(Elv5Rational other) => compareTo(other) <= 0;
  bool operator >(Elv5Rational other) => compareTo(other) > 0;
  bool operator >=(Elv5Rational other) => compareTo(other) >= 0;

  Map<String, Object?> toMap() => <String, Object?>{
    'numerator': numerator.toString(),
    'denominator': denominator.toString(),
  };

  @override
  bool operator ==(Object other) =>
      other is Elv5Rational &&
      numerator == other.numerator &&
      denominator == other.denominator;

  @override
  int get hashCode => Object.hash(numerator, denominator);

  @override
  String toString() => '$numerator/$denominator';
}
