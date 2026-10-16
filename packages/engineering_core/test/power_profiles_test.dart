import 'dart:convert';
import 'dart:io';

import 'package:engineering_core/engineering_core.dart';
import 'package:test/test.dart';

PowerRational r(String text) => PowerRational.parseDecimal(text);

void main() {
  test('explicit zero in every demand union remains distinct from absent input',
      () {
    for (final map in <Map<String, Object?>>[
      {'kind': 'DC_CONSTANT_CURRENT', 'currentA': '0.000'},
      {'kind': 'DC_CONSTANT_POWER', 'powerW': '0'},
      {'kind': 'AC_POWER', 'powerW': '0', 'apparentVa': '0'},
      {'kind': 'AC_POWER_PF', 'powerW': '0', 'powerFactor': '0.8'},
    ]) {
      final demand = PowerDemand.fromMap(map);
      expect(PowerDemand.fromMap(demand.toMap()).toMap(), demand.toMap());
    }
    expect(() => PowerDemand.fromMap({'kind': 'DC_CONSTANT_POWER'}),
        throwsFormatException);
  });

  test('AC exact PF basis retains provenance and nonterminating VA', () {
    final pf =
        AcPowerDemand.withPowerFactor(powerW: r('1'), powerFactor: r('0.3'));
    expect(pf.apparentVa, r('10') / r('3'));
    expect(pf.toMap(),
        {'kind': 'AC_POWER_PF', 'powerW': '1', 'powerFactor': '0.3'});
    final va =
        AcPowerDemand.withApparentPower(powerW: r('0'), apparentVa: r('10'));
    expect(va.apparentVa, r('10'));
    expect(va.basis, AcPowerDemandBasis.apparentPower);
  });

  test('invalid negative demand, VA and PF reject at construction', () {
    expect(() => DcConstantCurrentDemand(r('-1')), throwsArgumentError);
    expect(() => DcConstantPowerDemand(r('-1')), throwsArgumentError);
    expect(
        () =>
            AcPowerDemand.withApparentPower(powerW: r('2'), apparentVa: r('1')),
        throwsArgumentError);
    expect(
        () => AcPowerDemand.withApparentPower(
            powerW: r('-1'), apparentVa: r('1')),
        throwsArgumentError);
    for (final factor in ['0', '-0.1', '1.000000000001']) {
      expect(
          () => AcPowerDemand.withPowerFactor(
              powerW: r('1'), powerFactor: r(factor)),
          throwsArgumentError);
    }
    expect(
        AcPowerDemand.withPowerFactor(powerW: r('1'), powerFactor: r('1'))
            .apparentVa,
        r('1'));
  });

  test('strict demand union rejects unknown fields, tag, doubles and null', () {
    for (final map in <Map<String, Object?>>[
      {'kind': 'DC_CONSTANT_POWER', 'powerW': '1', 'currentA': '1'},
      {'kind': 'DC_CONSTANT_POWER', 'powerW': 1},
      {'kind': 'DC_CONSTANT_POWER', 'powerW': null},
      {'kind': 'DC_RESISTANCE', 'ohm': '1'},
      {'kind': 'AC_POWER', 'powerW': '1', 'powerFactor': '1'},
    ]) {
      expect(() => PowerDemand.fromMap(map), throwsFormatException);
    }
  });

  group('static voltage envelope', () {
    test('DC and AC exact round-trip', () {
      for (final envelope in [
        PowerVoltageEnvelope(
            currentKind: PowerCurrentKind.dc,
            minV: r('21.6'),
            nominalV: r('24'),
            maxV: r('28.8')),
        PowerVoltageEnvelope(
            currentKind: PowerCurrentKind.ac,
            minV: r('207'),
            nominalV: r('230'),
            maxV: r('253'),
            frequencyMinHz: r('49'),
            frequencyMaxHz: r('51')),
      ]) {
        expect(PowerVoltageEnvelope.fromMap(envelope.toMap()).toMap(),
            envelope.toMap());
      }
    });

    test('positive ordering and AC/DC frequency constraints', () {
      for (final values in [
        ['0', '24', '28'],
        ['25', '24', '28'],
        ['21', '29', '28']
      ]) {
        expect(
            () => PowerVoltageEnvelope(
                currentKind: PowerCurrentKind.dc,
                minV: r(values[0]),
                nominalV: r(values[1]),
                maxV: r(values[2])),
            throwsArgumentError);
      }
      expect(
          () => PowerVoltageEnvelope(
              currentKind: PowerCurrentKind.ac,
              minV: r('230'),
              nominalV: r('230'),
              maxV: r('230')),
          throwsArgumentError);
      expect(
          () => PowerVoltageEnvelope(
              currentKind: PowerCurrentKind.dc,
              minV: r('24'),
              nominalV: r('24'),
              maxV: r('24'),
              frequencyMinHz: r('50')),
          throwsArgumentError);
      for (final bounds in [
        ['0', '50'],
        ['51', '50']
      ]) {
        expect(
            () => PowerVoltageEnvelope(
                currentKind: PowerCurrentKind.ac,
                minV: r('230'),
                nominalV: r('230'),
                maxV: r('230'),
                frequencyMinHz: r(bounds[0]),
                frequencyMaxHz: r(bounds[1])),
            throwsArgumentError);
      }
    });

    test('wrong terminal convention and absent fields reject', () {
      final dc = PowerVoltageEnvelope(
              currentKind: PowerCurrentKind.dc,
              minV: r('24'),
              nominalV: r('24'),
              maxV: r('24'))
          .toMap();
      expect(
          () => PowerVoltageEnvelope.fromMap(
              {...dc, 'terminalConvention': 'AC_LN'}),
          throwsFormatException);
      expect(
          () => PowerVoltageEnvelope.fromMap({...dc}..remove('frequencyMinHz')),
          throwsFormatException);
      expect(
          () => PowerVoltageEnvelope.fromMap({...dc, 'currentKind': 'UNKNOWN'}),
          throwsFormatException);
    });
  });

  test('efficiency and idle cannot introduce energy or double accounting', () {
    final loss = PowerLossDefinition(
        efficiency: r('0.90'),
        idleW: r('2'),
        idleAccounting: PowerIdleAccounting.excludesSeparateIdle);
    expect(PowerLossDefinition.fromMap(loss.toMap()).toMap(), loss.toMap());
    expect(
        () => PowerLossDefinition(
            efficiency: r('1'),
            idleW: r('2'),
            idleAccounting: PowerIdleAccounting.includesIdle),
        throwsArgumentError);
    for (final efficiency in ['0', '-1', '1.000000000001']) {
      expect(
          () => PowerLossDefinition(
              efficiency: r(efficiency),
              idleW: r('0'),
              idleAccounting: PowerIdleAccounting.includesIdle),
          throwsArgumentError);
    }
    expect(
        () => PowerLossDefinition(
            efficiency: r('1'),
            idleW: r('-1'),
            idleAccounting: PowerIdleAccounting.excludesSeparateIdle),
        throwsArgumentError);
  });

  group('exact power provenance', () {
    final map = <String, Object?>{
      'catalogId': 'catalog',
      'catalogVersion': 'v1',
      'definitionKind': 'PORT',
      'definitionCode': 'PORT_24V',
      'definitionVersion': 'v1',
      'definitionSchema': 'electra.elv4-power-definitions.v1',
      'contentSha256': List.filled(64, 'a').join(),
      'sourceRef': 'fictional-test',
    };
    test('strict edition reference round-trip', () {
      expect(PowerDefinitionRef.fromMap(map).toMap(), map);
    });
    test(
        'rejects missing source, mismatched edition, unknown kind and bad hash',
        () {
      expect(() => PowerDefinitionRef.fromMap({...map, 'sourceRef': ''}),
          throwsArgumentError);
      expect(
          () => PowerDefinitionRef.fromMap({...map, 'definitionVersion': 'v2'}),
          throwsArgumentError);
      expect(
          () =>
              PowerDefinitionRef.fromMap({...map, 'definitionKind': 'UNKNOWN'}),
          throwsFormatException);
      expect(() => PowerDefinitionRef.fromMap({...map, 'contentSha256': 'abc'}),
          throwsFormatException);
      expect(
          () => PowerDefinitionRef.fromMap(
              {...map, 'definitionCode': 'port_24v'}),
          throwsFormatException);
      expect(() => PowerDefinitionRef.fromMap({...map, 'extra': 'ignored'}),
          throwsFormatException);
    });
  });

  test(
      'approved minimal catalog voltage and loss bodies decode without invented defaults',
      () {
    final fixture = jsonDecode(File(
            '../../docs/product/elv4-implementation/examples/minimal-power-catalog.json')
        .readAsStringSync()) as Map;
    final power = fixture['power'] as Map;
    final ports = power['portDefinitions'] as List;
    expect(ports, isNotEmpty);
    for (final port in ports.cast<Map>()) {
      final voltage = (port['voltage'] as Map).cast<String, Object?>();
      expect(PowerVoltageEnvelope.fromMap(voltage).toMap(), voltage);
    }
    for (final transfer in (power['transferDefinitions'] as List).cast<Map>()) {
      final loss = (transfer['loss'] as Map).cast<String, Object?>();
      expect(PowerLossDefinition.fromMap(loss).toMap(), loss);
    }
  });
}
