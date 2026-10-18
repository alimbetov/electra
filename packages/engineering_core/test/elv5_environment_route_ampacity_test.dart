import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:test/test.dart';

void main() {
  String hash(String ch) => List<String>.filled(64, ch).join();

  Elv5EnvironmentProfile profile({
    required String id,
    required String edition,
    required String maxTemperature,
    required String minHumidity,
    required String maxHumidity,
  }) =>
      Elv5EnvironmentProfile(
        profileId: id,
        editionId: edition,
        profileCode: id,
        temperatureC: Elv5RationalRange(
          minimum: Elv5Rational.parseDecimal('-20'),
          maximum: Elv5Rational.parseDecimal(maxTemperature),
        ),
        relativeHumidityPercent: Elv5RationalRange(
          minimum: Elv5Rational.parseDecimal(minHumidity),
          maximum: Elv5Rational.parseDecimal(maxHumidity),
        ),
        condensationRisk: Elv5CondensationRisk.possible,
        exposure: Elv5EnvironmentExposure.indoor,
        moistureClassCode: 'M1',
        contaminationClassCode: 'C1',
        climateClassCode: 'CL1',
        evidenceRef: 'ENV:$id:$edition',
        evidenceContentHash: hash('a'),
      );

  Elv5AmpacityReferenceRow reference() => Elv5AmpacityReferenceRow(
        conductorCrossSectionMm2: Elv5Rational.parseDecimal('2.5'),
        conductorMaterialCode: 'CU',
        insulationSystemCode: 'PVC70',
        referenceAmbientTemperatureC: Elv5Rational.parseDecimal('30'),
        installationMethodCode: 'B2',
        loadedConductors: 3,
        baseAllowableCurrentA: Elv5Rational.parseDecimal('30'),
        evidenceRef: 'AMPACITY:ROW',
        evidenceContentHash: hash('b'),
      );

  Elv5RouteAmpacitySectionInput section({
    required String sectionId,
    required Elv5EnvironmentProfile env,
    required String temperatureFactor,
    required String groupingFactor,
  }) =>
      Elv5RouteAmpacitySectionInput(
        sectionId: sectionId,
        environmentBinding: Elv5EnvironmentScopeBinding(
          bindingId: 'binding-$sectionId',
          scopeKind: 'ROUTE_SECTION',
          scopeId: sectionId,
          profile: env,
          priority: 200,
        ),
        ampacityInput: Elv5AmpacityInput(
          cableOrSectionId: sectionId,
          referenceRow: reference(),
          temperatureCorrection: Elv5AmpacityTemperatureCorrection(
            actualAmbientTemperatureC: env.temperatureC.maximum,
            factor: Elv5Rational.parseDecimal(temperatureFactor),
            evidenceRef: 'TEMP:$sectionId',
            evidenceContentHash: hash('c'),
          ),
          groupingCorrection: Elv5AmpacityGroupingCorrection(
            groupedCableOrCircuitCount: 2,
            arrangementCode: 'BUNCHED',
            factor: Elv5Rational.parseDecimal(groupingFactor),
            evidenceRef: 'GROUP:$sectionId',
            evidenceContentHash: hash('d'),
          ),
        ),
      );

  test('environment profile round-trips canonically', () {
    final original = profile(
      id: 'SERVER_ROOM',
      edition: 'v1',
      maxTemperature: '32',
      minHumidity: '20',
      maxHumidity: '80',
    );

    final decoded = Elv5EnvironmentProfile.fromMap(original.toCanonicalValue());

    expect(decoded.profileId, original.profileId);
    expect(decoded.temperatureC.maximum, Elv5Rational.parseDecimal('32'));
    expect(decoded.relativeHumidityPercent.maximum,
        Elv5Rational.parseDecimal('80'));
    expect(decoded.condensationRisk, Elv5CondensationRisk.possible);
  });

  test('route ampacity is governed by worst section environment', () {
    final office = profile(
      id: 'OFFICE',
      edition: 'v1',
      maxTemperature: '30',
      minHumidity: '20',
      maxHumidity: '70',
    );
    final shaft = profile(
      id: 'SHAFT_HOT',
      edition: 'v2',
      maxTemperature: '45',
      minHumidity: '20',
      maxHumidity: '90',
    );

    final result = const Elv5RouteAmpacityKernel().evaluate(
      Elv5RouteAmpacityInput(
        cableRunId: 'run-1',
        orderedSections: <Elv5RouteAmpacitySectionInput>[
          section(
            sectionId: 'section-office',
            env: office,
            temperatureFactor: '1.0',
            groupingFactor: '0.9',
          ),
          section(
            sectionId: 'section-shaft',
            env: shaft,
            temperatureFactor: '0.8',
            groupingFactor: '0.8',
          ),
        ],
      ),
    );

    expect(result.governingSectionId, 'section-shaft');
    expect(result.allowableCurrentIzA, Elv5Rational.parseDecimal('19.2'));
  });

  test('route section must use conservative maximum profile temperature', () {
    final env = profile(
      id: 'ROOM',
      edition: 'v1',
      maxTemperature: '40',
      minHumidity: '20',
      maxHumidity: '70',
    );

    expect(
      () => Elv5RouteAmpacitySectionInput(
        sectionId: 'section-1',
        environmentBinding: Elv5EnvironmentScopeBinding(
          bindingId: 'binding-1',
          scopeKind: 'ROOM',
          scopeId: 'room-1',
          profile: env,
          priority: 100,
        ),
        ampacityInput: Elv5AmpacityInput(
          cableOrSectionId: 'section-1',
          referenceRow: reference(),
          temperatureCorrection: Elv5AmpacityTemperatureCorrection(
            actualAmbientTemperatureC: Elv5Rational.parseDecimal('30'),
            factor: Elv5Rational.one,
            evidenceRef: 'TEMP',
            evidenceContentHash: hash('c'),
          ),
          groupingCorrection: Elv5AmpacityGroupingCorrection(
            groupedCableOrCircuitCount: 1,
            arrangementCode: 'SINGLE',
            factor: Elv5Rational.one,
            evidenceRef: 'GROUP',
            evidenceContentHash: hash('d'),
          ),
        ),
      ),
      throwsArgumentError,
    );
  });
}
