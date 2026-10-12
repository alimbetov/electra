import 'core_enums.dart';

/// Canonical length value used by the engineering domain.
///
/// Persistence is always integer millimetres. Display-system conversion belongs
/// at input/output boundaries and never changes the stored value.
final class Length {
  const Length.mm(this.millimetres) : assert(millimetres >= 0);

  final int millimetres;

  double get metres => millimetres / 1000.0;
  double get inches => millimetres / 25.4;
  double get feet => inches / 12.0;

  String format(
    MeasurementSystem system, {
    int metricDecimals = 2,
    int imperialFractionDenominator = 16,
  }) {
    return switch (system) {
      MeasurementSystem.metric => '${metres.toStringAsFixed(metricDecimals)} m',
      MeasurementSystem.imperial =>
        _formatFeetAndInches(imperialFractionDenominator),
    };
  }

  String _formatFeetAndInches(int denominator) {
    assert(denominator > 0);
    final totalInches = inches;
    var wholeFeet = totalInches ~/ 12;
    final remaining = totalInches - wholeFeet * 12;
    var wholeInches = remaining.floor();
    var fraction = ((remaining - wholeInches) * denominator).round();

    if (fraction == denominator) {
      wholeInches += 1;
      fraction = 0;
    }
    if (wholeInches == 12) {
      wholeFeet += 1;
      wholeInches = 0;
    }

    if (fraction == 0) return '$wholeFeet ft $wholeInches in';

    final divisor = _greatestCommonDivisor(fraction, denominator);
    return '$wholeFeet ft $wholeInches ${fraction ~/ divisor}/${denominator ~/ divisor} in';
  }

  static int _greatestCommonDivisor(int a, int b) {
    var x = a.abs();
    var y = b.abs();
    while (y != 0) {
      final temp = y;
      y = x % y;
      x = temp;
    }
    return x == 0 ? 1 : x;
  }
}
