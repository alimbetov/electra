/// Exact arithmetic for new ELV4 facts. Never used to rewrite legacy numbers.
const powerNumericPolicyVersion = 'elv4.exact-rational.v2';

/// An immutable, reduced rational. Doubles are deliberately not accepted.
final class PowerRational implements Comparable<PowerRational> {
  factory PowerRational(BigInt numerator, BigInt denominator) {
    if (denominator == BigInt.zero) {
      throw ArgumentError.value(denominator, 'denominator', 'Must be nonzero.');
    }
    final sign = denominator.isNegative ? -BigInt.one : BigInt.one;
    final gcd = numerator.gcd(denominator);
    return PowerRational._(numerator ~/ gcd * sign, denominator ~/ gcd * sign);
  }

  const PowerRational._(this.numerator, this.denominator);

  factory PowerRational.integer(int value) =>
      PowerRational(BigInt.from(value), BigInt.one);

  /// Signed decimal domain input, including normalization of negative zero.
  /// Wire quantities are nonnegative and must use [fromWireDecimal].
  factory PowerRational.parseDecimal(String text) {
    if (!_decimal.hasMatch(text)) {
      throw FormatException(
          'Expected decimal: <=30 integer/12 fraction digits.', text);
    }
    final parts = text.split('.');
    final fraction = parts.length == 2 ? parts[1] : '';
    return PowerRational(
      BigInt.parse('${parts[0]}$fraction'),
      BigInt.from(10).pow(fraction.length),
    );
  }

  factory PowerRational.fromWireDecimal(Object? value) {
    if (value is! String || value.startsWith('-')) {
      throw FormatException(
          'Power wire quantity must be a nonnegative decimal string.', value);
    }
    return PowerRational.parseDecimal(value);
  }

  /// Persisted evaluation fractions have no decimal-input precision limit.
  factory PowerRational.fromMap(Map<String, Object?> map) {
    if (map.length != 2 ||
        !map.containsKey('numerator') ||
        !map.containsKey('denominator')) {
      throw const FormatException('Expected numerator and denominator only.');
    }
    final numerator = map['numerator'];
    final denominator = map['denominator'];
    if (numerator is! String ||
        denominator is! String ||
        !_integer.hasMatch(numerator) ||
        !_positiveInteger.hasMatch(denominator)) {
      throw const FormatException('Invalid persisted rational.');
    }
    return PowerRational(BigInt.parse(numerator), BigInt.parse(denominator));
  }

  static final _decimal = RegExp(r'^-?(0|[1-9][0-9]{0,29})(\.[0-9]{1,12})?$');
  static final _integer = RegExp(r'^-?(0|[1-9][0-9]*)$');
  static final _positiveInteger = RegExp(r'^[1-9][0-9]*$');
  static final zero = PowerRational.integer(0);
  static final one = PowerRational.integer(1);

  final BigInt numerator;
  final BigInt denominator;

  bool get isZero => numerator == BigInt.zero;
  bool get isNegative => numerator.isNegative;

  PowerRational operator +(PowerRational other) => PowerRational(
        numerator * other.denominator + other.numerator * denominator,
        denominator * other.denominator,
      );
  PowerRational operator -(PowerRational other) => this + -other;
  PowerRational operator -() => PowerRational(-numerator, denominator);
  PowerRational operator *(PowerRational other) => PowerRational(
        numerator * other.numerator,
        denominator * other.denominator,
      );
  PowerRational operator /(PowerRational other) => PowerRational(
        numerator * other.denominator,
        denominator * other.numerator,
      );

  @override
  int compareTo(PowerRational other) =>
      (numerator * other.denominator).compareTo(other.numerator * denominator);
  bool operator <(PowerRational other) => compareTo(other) < 0;
  bool operator <=(PowerRational other) => compareTo(other) <= 0;
  bool operator >(PowerRational other) => compareTo(other) > 0;
  bool operator >=(PowerRational other) => compareTo(other) >= 0;

  Map<String, Object?> toMap() => {
        'numerator': numerator.toString(),
        'denominator': denominator.toString(),
      };

  /// Exact wire output only. Nonterminating or out-of-schema results must use
  /// [toMap] for evidence, never a rounded decimal masquerading as input.
  String toWireDecimal() {
    if (isNegative) throw StateError('Wire quantities must be nonnegative.');
    final whole = numerator ~/ denominator;
    if (whole.toString().length > 30)
      throw StateError('Wire integer limit exceeded.');
    var remainder = numerator.remainder(denominator);
    final digits = StringBuffer();
    for (var i = 0; remainder != BigInt.zero && i < 12; i++) {
      remainder *= BigInt.from(10);
      digits.write(remainder ~/ denominator);
      remainder = remainder.remainder(denominator);
    }
    if (remainder != BigInt.zero)
      throw StateError('Not an exact wire decimal.');
    return digits.isEmpty ? '$whole' : '$whole.$digits';
  }

  @override
  bool operator ==(Object other) =>
      other is PowerRational &&
      numerator == other.numerator &&
      denominator == other.denominator;
  @override
  int get hashCode => Object.hash(numerator, denominator);
  @override
  String toString() => '$numerator/$denominator';
}

enum PowerNumericAssessment { pass, fail, unresolved }

/// Closed conservative bounds. All operations preserve enclosure of the truth.
final class PowerInterval {
  PowerInterval(this.lower, this.upper) {
    if (lower > upper) throw ArgumentError('Interval bounds are reversed.');
  }
  factory PowerInterval.exact(PowerRational value) =>
      PowerInterval(value, value);
  factory PowerInterval.fromMap(Map<String, Object?> map) {
    if (map.length != 2 || map['lower'] is! Map || map['upper'] is! Map) {
      throw const FormatException('Expected lower and upper rational bounds.');
    }
    return PowerInterval(
      PowerRational.fromMap((map['lower'] as Map).cast<String, Object?>()),
      PowerRational.fromMap((map['upper'] as Map).cast<String, Object?>()),
    );
  }

  final PowerRational lower;
  final PowerRational upper;
  bool get isExact => lower == upper;
  PowerRational get width => upper - lower;

  PowerInterval operator +(PowerInterval other) =>
      PowerInterval(lower + other.lower, upper + other.upper);
  PowerInterval operator -(PowerInterval other) =>
      PowerInterval(lower - other.upper, upper - other.lower);
  PowerInterval operator *(PowerInterval other) {
    final products = [
      lower * other.lower,
      lower * other.upper,
      upper * other.lower,
      upper * other.upper
    ]..sort();
    return PowerInterval(products.first, products.last);
  }

  PowerInterval operator /(PowerInterval other) {
    if (other.lower <= PowerRational.zero &&
        other.upper >= PowerRational.zero) {
      throw ArgumentError('Divisor interval contains zero.');
    }
    return this *
        PowerInterval(
            PowerRational.one / other.upper, PowerRational.one / other.lower);
  }

  /// Demand <= available. Equality passes; overlapping uncertainty never does.
  PowerNumericAssessment assessAtMost(PowerInterval available) {
    if (upper <= available.lower) return PowerNumericAssessment.pass;
    if (lower > available.upper) return PowerNumericAssessment.fail;
    return PowerNumericAssessment.unresolved;
  }

  Map<String, Object?> toMap() =>
      {'lower': lower.toMap(), 'upper': upper.toMap()};
}
