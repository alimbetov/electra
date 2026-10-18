import 'package:engineering_core/engineering_core_elv5.dart'
    show
        Elv5Rational,
        Lan05DirectionInput,
        Lan05FiberSection,
        Lan05GoverningCase,
        Lan05Input,
        Lan05LengthInterval,
        Lan05LossEvent,
        Lan05LossEventKind,
        Lan05LossInterval,
        Lan05OpticalBudgetKernel,
        Length,
        LevelDbm,
        LossDb;
import 'package:test/test.dart';

Elv5Rational _r(String value) => Elv5Rational.parseDecimal(value);
Length _m(String value) => Length(_r(value));
LossDb _db(String value) => LossDb(_r(value));
LevelDbm _dbm(String value) => LevelDbm(_r(value));

Lan05DirectionInput _direction({
  required String txMin,
  required String txMax,
  required String sensitivity,
  required String overload,
  String requiredMargin = '0',
  List<Lan05FiberSection>? sections,
  List<Lan05LossEvent>? events,
}) =>
    Lan05DirectionInput(
      wavelengthNm: _r('1310'),
      txMin: _dbm(txMin),
      txMax: _dbm(txMax),
      rxSensitivity: _dbm(sensitivity),
      rxOverloadMax: _dbm(overload),
      requiredSensitivityMargin: _db(requiredMargin),
      sections: sections ??
          <Lan05FiberSection>[
            Lan05FiberSection(
              sectionId: 'fiber-1',
              wavelengthNm: _r('1310'),
              lengthMeters: Lan05LengthInterval.exact(_m('1000')),
              attenuationDbPerKm: Lan05LossInterval.exact(_db('2.5')),
            ),
          ],
      events: events ?? const <Lan05LossEvent>[],
    );

void main() {
  group('LAN-05 bidirectional optical budget', () {
    test('positive vector computes sensitivity and overload headroom', () {
      final direction = _direction(
        txMin: '-3',
        txMax: '-2',
        sensitivity: '-15',
        overload: '-1',
      );
      final result = const Lan05OpticalBudgetKernel().evaluate(
        Lan05Input(aToB: direction, bToA: direction),
      );

      expect(result.aToB.physicalLoss.lower, _db('2.5'));
      expect(result.aToB.rxLow, _dbm('-5.5'));
      expect(result.aToB.rxHigh, _dbm('-4.5'));
      expect(result.aToB.sensitivity.margin, _db('9.5'));
      expect(result.aToB.overload.margin, _db('3.5'));
      expect(result.passes, isTrue);
      expect(result.governingCase, Lan05GoverningCase.aToBOverload);
    });

    test('zero sensitivity margin is inclusive PASS', () {
      final direction = _direction(
        txMin: '-10',
        txMax: '-9',
        sensitivity: '-13',
        overload: '0',
        sections: <Lan05FiberSection>[
          Lan05FiberSection(
            sectionId: 'fiber-1',
            wavelengthNm: _r('1310'),
            lengthMeters: Lan05LengthInterval.exact(_m('1000')),
            attenuationDbPerKm: Lan05LossInterval.exact(_db('3')),
          ),
        ],
      );
      final result = const Lan05OpticalBudgetKernel().evaluate(
        Lan05Input(aToB: direction, bToA: direction),
      );

      expect(result.aToB.sensitivity.margin, _db('0'));
      expect(result.aToB.sensitivity.passes, isTrue);
    });

    test('overload can fail even with sensitivity headroom', () {
      final direction = _direction(
        txMin: '-2',
        txMax: '-1',
        sensitivity: '-20',
        overload: '-3',
        sections: <Lan05FiberSection>[
          Lan05FiberSection(
            sectionId: 'fiber-1',
            wavelengthNm: _r('1310'),
            lengthMeters: Lan05LengthInterval.exact(_m('1')),
            attenuationDbPerKm: Lan05LossInterval.exact(_db('0')),
          ),
        ],
      );
      final result = const Lan05OpticalBudgetKernel().evaluate(
        Lan05Input(aToB: direction, bToA: direction),
      );

      expect(result.aToB.overload.margin, _db('-2'));
      expect(result.aToB.overload.passes, isFalse);
      expect(result.passes, isFalse);
    });

    test('missing TxMax leaves overload unresolved but sensitivity assessable',
        () {
      final direction = Lan05DirectionInput(
        wavelengthNm: _r('1310'),
        txMin: _dbm('-3'),
        rxSensitivity: _dbm('-15'),
        rxOverloadMax: _dbm('-1'),
        requiredSensitivityMargin: _db('0'),
        sections: <Lan05FiberSection>[
          Lan05FiberSection(
            sectionId: 'fiber-1',
            wavelengthNm: _r('1310'),
            lengthMeters: Lan05LengthInterval.exact(_m('1000')),
            attenuationDbPerKm: Lan05LossInterval.exact(_db('2.5')),
          ),
        ],
        events: const <Lan05LossEvent>[],
      );
      final result = const Lan05OpticalBudgetKernel().evaluate(
        Lan05Input(aToB: direction, bToA: direction),
      );

      expect(result.aToB.sensitivity.margin, _db('9.5'));
      expect(result.aToB.overload.margin, isNull);
      expect(result.passes, isNull);
    });

    test('loss event order does not change physical loss', () {
      final connector = Lan05LossEvent(
        eventId: 'connector-pair-1',
        kind: Lan05LossEventKind.connectorPair,
        loss: Lan05LossInterval.exact(_db('0.5')),
      );
      final splice = Lan05LossEvent(
        eventId: 'splice-1',
        kind: Lan05LossEventKind.splice,
        loss: Lan05LossInterval.exact(_db('0.2')),
      );
      final first = _direction(
        txMin: '-3',
        txMax: '-2',
        sensitivity: '-15',
        overload: '-1',
        sections: <Lan05FiberSection>[],
        events: <Lan05LossEvent>[connector, splice],
      );
      final second = _direction(
        txMin: '-3',
        txMax: '-2',
        sensitivity: '-15',
        overload: '-1',
        sections: <Lan05FiberSection>[],
        events: <Lan05LossEvent>[splice, connector],
      );

      final kernel = const Lan05OpticalBudgetKernel();
      expect(
        kernel
            .evaluate(Lan05Input(aToB: first, bToA: first))
            .aToB
            .physicalLoss
            .upper,
        kernel
            .evaluate(Lan05Input(aToB: second, bToA: second))
            .aToB
            .physicalLoss
            .upper,
      );
    });

    test('rejects duplicate mated-pair event identity', () {
      final event = Lan05LossEvent(
        eventId: 'pair-1',
        kind: Lan05LossEventKind.connectorPair,
        loss: Lan05LossInterval.exact(_db('0.5')),
      );
      final direction = _direction(
        txMin: '-3',
        txMax: '-2',
        sensitivity: '-15',
        overload: '-1',
        sections: <Lan05FiberSection>[],
        events: <Lan05LossEvent>[event, event],
      );

      expect(
        () => const Lan05OpticalBudgetKernel().evaluate(
          Lan05Input(aToB: direction, bToA: direction),
        ),
        throwsStateError,
      );
    });

    test('rejects wavelength mismatch instead of extrapolating', () {
      final direction = _direction(
        txMin: '-3',
        txMax: '-2',
        sensitivity: '-15',
        overload: '-1',
        sections: <Lan05FiberSection>[
          Lan05FiberSection(
            sectionId: 'fiber-1',
            wavelengthNm: _r('1550'),
            lengthMeters: Lan05LengthInterval.exact(_m('1000')),
            attenuationDbPerKm: Lan05LossInterval.exact(_db('0.4')),
          ),
        ],
      );

      expect(
        () => const Lan05OpticalBudgetKernel().evaluate(
          Lan05Input(aToB: direction, bToA: direction),
        ),
        throwsStateError,
      );
    });
  });
}
