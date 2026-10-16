import 'dart:convert';

import 'package:engineering_core/engineering_core.dart';
import 'package:test/test.dart';

PowerRational r(String text) => PowerRational.parseDecimal(text);
PowerInterval interval(String lower, String upper) =>
    PowerInterval(r(lower), r(upper));

void main() {
  group('RM09 exact numeric policy', () {
    test('two decimal addition paths equal the rating exactly', () {
      expect(r('0.1') + r('0.2'), r('0.3'));
      expect(r('0.15') + r('0.15'), r('0.3'));
      expect(r('0.300000000001') > r('0.3'), isTrue);
      expect(interval('0.3', '0.3').assessAtMost(interval('0.3', '0.3')),
          PowerNumericAssessment.pass);
      expect(
          interval('0.300000000001', '0.300000000001')
              .assessAtMost(interval('0.3', '0.3')),
          PowerNumericAssessment.fail);
    });

    test('decimal limits retain all digits beyond double and integer precision',
        () {
      const largest = '999999999999999999999999999999.999999999999';
      expect(r(largest).toWireDecimal(), largest);
      expect(r(largest) + r('0.000000000001'),
          PowerRational(BigInt.from(10).pow(30), BigInt.one));
      expect(r('9007199254740993') - r('9007199254740992'), PowerRational.one);
    });

    test('sign, reduction and zero normalization', () {
      expect(PowerRational(BigInt.from(2), BigInt.from(-4)), r('-0.5'));
      expect(PowerRational(BigInt.from(-2), BigInt.from(-4)), r('0.5'));
      expect(r('-0.000').toMap(), {'numerator': '0', 'denominator': '1'});
      expect(r('1.500000000000').toWireDecimal(), '1.5');
      expect(r('-0.1') + r('0.2'), r('0.1'));
      expect(-r('-1'), PowerRational.one);
      expect({r('0.50'), r('0.5')}.length, 1);
    });

    for (final invalid in [
      '',
      '.1',
      '1.',
      '01',
      '+1',
      ' 1',
      '1 ',
      '1\n',
      'NaN',
      'Infinity',
      '-Infinity',
      '1e2',
      '1,2',
      '0.1234567890123',
      '1000000000000000000000000000000'
    ]) {
      test('rejects malformed decimal ${jsonEncode(invalid)}', () {
        expect(() => r(invalid), throwsFormatException);
      });
    }

    test('wire rejects numeric JSON, null, booleans and signed input', () {
      for (final value in [
        null,
        true,
        0,
        0.1,
        double.nan,
        double.infinity,
        '-0',
        '-1'
      ]) {
        expect(
            () => PowerRational.fromWireDecimal(value), throwsFormatException);
      }
      expect(PowerRational.fromWireDecimal('0.00'), PowerRational.zero);
    });

    test('division by zero is rejected without NaN or infinity', () {
      expect(() => r('1') / r('0'), throwsArgumentError);
      expect(
          () => PowerRational(BigInt.zero, BigInt.zero), throwsArgumentError);
    });

    test('multiple transfers conserve exact power without rounding', () {
      final output = r('0.1') + r('0.2');
      final firstInput = output / r('0.9') + r('0.05');
      final secondInput = firstInput / r('0.85') + r('0.1');
      final recovered =
          ((secondInput - r('0.1')) * r('0.85') - r('0.05')) * r('0.9');
      expect(recovered, output);
      expect((r('1') / r('3')).toMap(), {'numerator': '1', 'denominator': '3'});
    });

    test('integer millimetres convert exactly to metres', () {
      expect(PowerRational.integer(1234567) / PowerRational.integer(1000),
          r('1234.567'));
    });

    test('wire output refuses rounding or exceeding input limits', () {
      for (final value in [
        r('1') / r('3'),
        r('0.000000000001') / r('10'),
        r('-1'),
        r('999999999999999999999999999999') + r('1')
      ]) {
        expect(value.toWireDecimal, throwsStateError);
        expect(PowerRational.fromMap(value.toMap()), value);
      }
    });

    test(
        'canonical normalized evidence includes numeric policy and stable hash',
        () {
      String evidence(PowerRational value) => canonicalEngineeringJsonV1({
            'numericPolicyVersion': powerNumericPolicyVersion,
            'value': value.toMap(),
          });
      expect(evidence(r('0.300')), evidence(r('0.1') + r('0.2')));
      expect(sha256HexUtf8(evidence(r('0.300'))),
          sha256HexUtf8(evidence(r('0.15') + r('0.15'))));
      expect(evidence(r('0.3')), isNot(evidence(r('0.300000000001'))));
    });

    test('strict rational evidence rejects invalid fields and signs', () {
      for (final map in <Map<String, Object?>>[
        {},
        {'numerator': '1', 'denominator': '0'},
        {'numerator': '1', 'denominator': '-2'},
        {'numerator': '01', 'denominator': '2'},
        {'numerator': 1, 'denominator': '2'},
        {'numerator': '1.5', 'denominator': '2'},
        {'numerator': '1', 'denominator': '2', 'extra': true},
      ]) {
        expect(() => PowerRational.fromMap(map), throwsFormatException);
      }
    });
  });

  group('conservative interval decisions', () {
    test('straddling rating is unresolved even if midpoint would pass', () {
      expect(interval('0.29', '0.31').assessAtMost(interval('0.3', '0.3')),
          PowerNumericAssessment.unresolved);
      expect(interval('0.3', '0.3').assessAtMost(interval('0.29', '0.31')),
          PowerNumericAssessment.unresolved);
      expect(interval('0.28', '0.29').assessAtMost(interval('0.29', '0.31')),
          PowerNumericAssessment.pass);
      expect(interval('0.32', '0.33').assessAtMost(interval('0.29', '0.31')),
          PowerNumericAssessment.fail);
    });

    test('interval arithmetic preserves endpoints with negative operands', () {
      expect((interval('-2', '3') * interval('-4', '5')).toMap(),
          interval('-12', '15').toMap());
      expect((interval('1', '2') - interval('3', '4')).toMap(),
          interval('-3', '-1').toMap());
      expect((interval('1', '2') + interval('3', '4')).toMap(),
          interval('4', '6').toMap());
      expect((interval('2', '4') / interval('-4', '-2')).toMap(),
          interval('-2', '-0.5').toMap());
      expect((interval('2', '4') / interval('2', '4')).toMap(),
          interval('0.5', '2').toMap());
    });

    test('inverted and zero-divisor intervals reject', () {
      expect(() => interval('2', '1'), throwsArgumentError);
      for (final divisor in [
        interval('-1', '1'),
        interval('0', '1'),
        interval('-1', '0'),
        interval('0', '0')
      ]) {
        expect(() => interval('1', '2') / divisor, throwsArgumentError);
      }
    });

    test('interval evidence round-trip is exact', () {
      final input = PowerInterval(r('1') / r('3'), r('2') / r('3'));
      final restored = PowerInterval.fromMap(
          (jsonDecode(jsonEncode(input.toMap())) as Map)
              .cast<String, Object?>());
      expect(restored.toMap(), input.toMap());
      expect(restored.width, r('1') / r('3'));
      expect(restored.isExact, isFalse);
      expect(PowerInterval.exact(r('1')).isExact, isTrue);
      expect(
          () => PowerInterval.fromMap({
                'lower': input.lower.toMap(),
                'upper': input.upper.toMap(),
                'extra': 0
              }),
          throwsFormatException);
    });
  });
}
