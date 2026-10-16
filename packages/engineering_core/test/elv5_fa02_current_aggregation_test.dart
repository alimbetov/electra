import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:test/test.dart';

Current _a(String v) => Current(Elv5Rational.parseDecimal(v));
Elv5Interval<CurrentDim> _i(String v) => Elv5Interval.exact(_a(v));

void main() {
  test('FA02 aggregates distinct origins per case and preserves missing state', () {
    final input = Fa02Input(
      segmentId: 'loop-1',
      origins: [
        Fa02LoadOrigin(originId: 'd1', currents: {Fa02OperatingCase.standby: _i('0.01'), Fa02OperatingCase.alarm: _i('0.03')}),
        Fa02LoadOrigin(originId: 'd2', currents: {Fa02OperatingCase.standby: _i('0.01'), Fa02OperatingCase.alarm: _i('0.03')}),
        Fa02LoadOrigin(originId: 'module', currents: {Fa02OperatingCase.standby: _i('0.02'), Fa02OperatingCase.alarm: _i('0.02')}),
      ],
      cases: [
        Fa02CasePolicy(operatingCase: Fa02OperatingCase.standby, selectedOriginIds: {'d1','d2','module'}),
        Fa02CasePolicy(operatingCase: Fa02OperatingCase.alarm, selectedOriginIds: {'d1','d2','module'}, explicitCurrentLimit: _a('0.50')),
      ],
    );
    final result = const Fa02CurrentAggregationKernel().evaluate(input);
    expect(result.cases[Fa02OperatingCase.standby]!.knownSubtotal.upper, _a('0.04'));
    expect(result.cases[Fa02OperatingCase.alarm]!.knownSubtotal.upper, _a('0.08'));
    expect(result.status, Fa02AssessmentStatus.complete);
  });

  test('FA02 does not substitute missing alarm current with standby', () {
    final result = const Fa02CurrentAggregationKernel().evaluate(Fa02Input(
      segmentId: 'loop-1',
      origins: [Fa02LoadOrigin(originId: 'd1', currents: {Fa02OperatingCase.standby: _i('0.01')})],
      cases: [Fa02CasePolicy(operatingCase: Fa02OperatingCase.alarm, selectedOriginIds: {'d1'})],
    ));
    expect(result.status, Fa02AssessmentStatus.unresolved);
    expect(result.cases[Fa02OperatingCase.alarm]!.missingOriginIds, ['d1']);
  });
}
