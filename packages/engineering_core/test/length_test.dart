import 'package:engineering_core/engineering_core.dart';
import 'package:test/test.dart';

void main() {
  group('Length', () {
    test('keeps canonical millimetres', () {
      const value = Length.mm(4200);
      expect(value.millimetres, 4200);
      expect(value.metres, closeTo(4.2, 0.000001));
    });

    test('formats metric without changing canonical value', () {
      const value = Length.mm(4200);
      expect(value.format(MeasurementSystem.metric), '4.20 m');
      expect(value.millimetres, 4200);
    });

    test('formats imperial feet and inches', () {
      const value = Length.mm(4200);
      expect(value.format(MeasurementSystem.imperial), '13 ft 9 3/8 in');
    });
  });
}
