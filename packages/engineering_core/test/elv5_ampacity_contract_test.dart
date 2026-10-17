import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:test/test.dart';

void main() {
  test('derives Iz from immutable reference row and exact correction factors', () {
    final input = Elv5AmpacityInput(
      cableOrSectionId: 'section-1',
      referenceRow: Elv5AmpacityReferenceRow(
        conductorCrossSectionMm2: Elv5Rational.parseDecimal('2.5'),
        conductorMaterialCode: 'CU',
        insulationSystemCode: 'PVC_70C',
        referenceAmbientTemperatureC: Elv5Rational.integer(30),
        installationMethodCode: 'B2',
        loadedConductors: 3,
        baseAllowableCurrentA: Elv5Rational.integer(40),
        evidenceRef: 'ampacity-table:fictional:v1:row-17',
        evidenceContentHash: _hash('a'),
      ),
      temperatureCorrection: Elv5AmpacityTemperatureCorrection(
        actualAmbientTemperatureC: Elv5Rational.integer(40),
        factor: Elv5Rational.parseDecimal('0.91'),
        evidenceRef: 'temperature-factor:fictional:v1:40C',
        evidenceContentHash: _hash('b'),
      ),
      groupingCorrection: Elv5AmpacityGroupingCorrection(
        groupedCableOrCircuitCount: 4,
        arrangementCode: 'BUNCHED_ON_TRAY',
        factor: Elv5Rational.parseDecimal('0.8'),
        evidenceRef: 'grouping-factor:fictional:v1:4',
        evidenceContentHash: _hash('c'),
      ),
    );

    final result = const Elv5AmpacityKernel().evaluate(input);

    expect(result.baseAllowableCurrentA, Elv5Rational.integer(40));
    expect(result.temperatureFactor, Elv5Rational.parseDecimal('0.91'));
    expect(result.groupingFactor, Elv5Rational.parseDecimal('0.8'));
    expect(result.allowableCurrentIzA, Elv5Rational.parseDecimal('29.12'));

    final canonical = input.toCanonicalValue();
    final reference = canonical['referenceRow']! as Map<String, Object?>;
    expect(reference['conductorMaterialCode'], 'CU');
    expect(reference['installationMethodCode'], 'B2');
    expect(reference['loadedConductors'], 3);
    expect(reference['conductorCrossSectionMm2'], Elv5Rational.parseDecimal('2.5').toMap());
  });

  test('applies additional corrections deterministically by code', () {
    final input = Elv5AmpacityInput(
      cableOrSectionId: 'section-2',
      referenceRow: Elv5AmpacityReferenceRow(
        conductorCrossSectionMm2: Elv5Rational.integer(4),
        conductorMaterialCode: 'AL',
        insulationSystemCode: 'XLPE_90C',
        referenceAmbientTemperatureC: Elv5Rational.integer(30),
        installationMethodCode: 'E',
        loadedConductors: 2,
        baseAllowableCurrentA: Elv5Rational.integer(50),
        evidenceRef: 'table-row',
        evidenceContentHash: _hash('d'),
      ),
      temperatureCorrection: Elv5AmpacityTemperatureCorrection(
        actualAmbientTemperatureC: Elv5Rational.integer(35),
        factor: Elv5Rational.parseDecimal('0.96'),
        evidenceRef: 'temperature-factor',
        evidenceContentHash: _hash('e'),
      ),
      groupingCorrection: Elv5AmpacityGroupingCorrection(
        groupedCableOrCircuitCount: 2,
        arrangementCode: 'SPACED',
        factor: Elv5Rational.parseDecimal('0.9'),
        evidenceRef: 'grouping-factor',
        evidenceContentHash: _hash('f'),
      ),
      additionalCorrections: <Elv5AmpacityAdditionalCorrection>[
        Elv5AmpacityAdditionalCorrection(
          code: 'THERMAL_INSULATION',
          factor: Elv5Rational.parseDecimal('0.95'),
          evidenceRef: 'additional-2',
          evidenceContentHash: _hash('1'),
        ),
        Elv5AmpacityAdditionalCorrection(
          code: 'ALTITUDE',
          factor: Elv5Rational.parseDecimal('0.98'),
          evidenceRef: 'additional-1',
          evidenceContentHash: _hash('2'),
        ),
      ],
    );

    final result = const Elv5AmpacityKernel().evaluate(input);

    expect(
      result.allowableCurrentIzA,
      Elv5Rational.parseDecimal('40.2192'),
    );
    expect(
      input.additionalCorrections.map((item) => item.code).toList(),
      <String>['ALTITUDE', 'THERMAL_INSULATION'],
    );
  });

  test('rejects missing physical basis instead of defaulting engineering facts', () {
    expect(
      () => Elv5AmpacityReferenceRow(
        conductorCrossSectionMm2: Elv5Rational.zero,
        conductorMaterialCode: 'CU',
        insulationSystemCode: 'PVC_70C',
        referenceAmbientTemperatureC: Elv5Rational.integer(30),
        installationMethodCode: 'B2',
        loadedConductors: 3,
        baseAllowableCurrentA: Elv5Rational.integer(40),
        evidenceRef: 'row',
        evidenceContentHash: _hash('3'),
      ),
      throwsArgumentError,
    );

    expect(
      () => Elv5AmpacityGroupingCorrection(
        groupedCableOrCircuitCount: 0,
        arrangementCode: 'BUNCHED',
        factor: Elv5Rational.one,
        evidenceRef: 'group',
        evidenceContentHash: _hash('4'),
      ),
      throwsArgumentError,
    );
  });
}

String _hash(String char) => List<String>.filled(64, char).join();
