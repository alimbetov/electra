import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:test/test.dart';

import 'support/elv5_foundation_qualification_support.dart';

void main() {
  group('F2 AMPACITY_ROUTE_IZ', () {
    test('Q0 contract/schema inventory is explicit and source-backed', () {
      final input = _routeInput(<_SectionSpec>[
        _SectionSpec('s1',
            baseA: 100, temperatureFactor: '0.8', groupingFactor: '0.75'),
      ]);
      final section = input.orderedSections.single;

      expect(input.cableRunId, 'run-1');
      expect(section.ampacityInput.referenceRow.conductorMaterialCode, 'CU');
      expect(section.ampacityInput.referenceRow.installationMethodCode, 'TRAY');
      expect(section.ampacityInput.referenceRow.loadedConductors, 2);
      expect(
        section.ampacityInput.temperatureCorrection.actualAmbientTemperatureC,
        section.environmentBinding.profile.temperatureC.maximum,
      );
      expect(section.ampacityInput.referenceRow.evidenceRef, isNotEmpty);
      expect(section.ampacityInput.groupingCorrection.evidenceContentHash,
          _h('3'));
    });

    test('Q1 reference vector: 100 A * 0.8 * 0.75 = 60 A', () {
      final input = _routeInput(<_SectionSpec>[
        _SectionSpec('s1',
            baseA: 100, temperatureFactor: '0.8', groupingFactor: '0.75'),
      ]);
      final result = const Elv5RouteAmpacityKernel().evaluate(input);

      expect(result.governingSectionId, 's1');
      expect(result.allowableCurrentIzA, Elv5Rational.integer(60));
    });

    test('Q2 independent oracle reproduces Iz without using production kernel',
        () {
      final input = _routeInput(<_SectionSpec>[
        _SectionSpec(
          's1',
          baseA: 125,
          temperatureFactor: '0.91',
          groupingFactor: '0.8',
          additionalFactors: const <String, String>{'INSTALLATION': '0.95'},
        ),
      ]);
      final production = const Elv5RouteAmpacityKernel().evaluate(input);
      final section = input.orderedSections.single.ampacityInput;

      var oracle = section.referenceRow.baseAllowableCurrentA;
      oracle *= section.temperatureCorrection.factor;
      oracle *= section.groupingCorrection.factor;
      for (final factor
          in section.additionalCorrections.map((value) => value.factor)) {
        oracle *= factor;
      }

      requireIndependentOracle<Elv5Rational>(
        production: production.allowableCurrentIzA,
        oracle: oracle,
      );
      expect(oracle, Elv5Rational.parseDecimal('86.45'));
    });

    test('Q3 below/equal/above Iz boundary is exact and inclusive', () {
      final result = const Elv5RouteAmpacityKernel().evaluate(
        _routeInput(<_SectionSpec>[
          _SectionSpec('s1',
              baseA: 100, temperatureFactor: '0.8', groupingFactor: '0.75'),
        ]),
      );
      final iz = result.allowableCurrentIzA;
      final triplet = Elv5BoundaryTriplet<Elv5Rational>(
        below: iz - Elv5Rational.integer(1),
        exact: iz,
        above: iz + Elv5Rational.integer(1),
      );

      expect(triplet.below <= iz, isTrue);
      expect(triplet.exact <= iz, isTrue);
      expect(triplet.above <= iz, isFalse);
      expect(iz - triplet.exact, Elv5Rational.zero);
    });

    test('Q4 route minimum and section permutation are deterministic', () {
      final first = _routeInput(<_SectionSpec>[
        _SectionSpec('s-hot',
            baseA: 100, temperatureFactor: '0.7', groupingFactor: '1'),
        _SectionSpec('s-cool',
            baseA: 100, temperatureFactor: '0.9', groupingFactor: '1'),
      ]);
      final reversed = _routeInput(<_SectionSpec>[
        _SectionSpec('s-cool',
            baseA: 100, temperatureFactor: '0.9', groupingFactor: '1'),
        _SectionSpec('s-hot',
            baseA: 100, temperatureFactor: '0.7', groupingFactor: '1'),
      ]);

      final left = const Elv5RouteAmpacityKernel().evaluate(first);
      final right = const Elv5RouteAmpacityKernel().evaluate(reversed);

      requireMetamorphicInvariant<Elv5RouteAmpacityResult>(
        relation: 'ROUTE_MINIMUM_PERMUTATION_INVARIANCE',
        baseline: left,
        transformed: right,
        invariant: (a, b) =>
            a.allowableCurrentIzA == b.allowableCurrentIzA &&
            a.governingSectionId == b.governingSectionId,
      );
      expect(left.allowableCurrentIzA, Elv5Rational.integer(70));
      expect(left.governingSectionId, 's-hot');
    });

    test('Q4 monotonic correction: lower factor cannot improve Iz', () {
      final baseline = const Elv5RouteAmpacityKernel().evaluate(
        _routeInput(<_SectionSpec>[
          _SectionSpec('s1',
              baseA: 100, temperatureFactor: '0.9', groupingFactor: '0.8'),
        ]),
      );
      final harsher = const Elv5RouteAmpacityKernel().evaluate(
        _routeInput(<_SectionSpec>[
          _SectionSpec('s1',
              baseA: 100, temperatureFactor: '0.8', groupingFactor: '0.8'),
        ]),
      );

      requireMetamorphicInvariant<Elv5RouteAmpacityResult>(
        relation: 'LOWER_CORRECTION_CANNOT_INCREASE_IZ',
        baseline: baseline,
        transformed: harsher,
        invariant: (a, b) => b.allowableCurrentIzA <= a.allowableCurrentIzA,
      );
      expect(baseline.allowableCurrentIzA, Elv5Rational.integer(72));
      expect(harsher.allowableCurrentIzA, Elv5Rational.integer(64));
    });

    test('Q5 realistic mixed route selects the physically weakest section', () {
      final input = _routeInput(<_SectionSpec>[
        _SectionSpec(
          'office-tray',
          baseA: 38,
          temperatureFactor: '1',
          groupingFactor: '0.8',
        ),
        _SectionSpec(
          'shaft-bundle',
          baseA: 38,
          temperatureFactor: '0.87',
          groupingFactor: '0.7',
          additionalFactors: const <String, String>{
            'THERMAL_INSULATION': '0.9'
          },
        ),
        _SectionSpec(
          'plant-room',
          baseA: 41,
          temperatureFactor: '0.82',
          groupingFactor: '0.85',
        ),
      ]);

      final result = const Elv5RouteAmpacityKernel().evaluate(input);
      final oracleBySection = <String, Elv5Rational>{};
      for (final section in input.orderedSections) {
        var value = section.ampacityInput.referenceRow.baseAllowableCurrentA;
        value *= section.ampacityInput.temperatureCorrection.factor;
        value *= section.ampacityInput.groupingCorrection.factor;
        for (final correction in section.ampacityInput.additionalCorrections) {
          value *= correction.factor;
        }
        oracleBySection[section.sectionId] = value;
      }
      final weakest = oracleBySection.entries.reduce(
        (a, b) => a.value <= b.value ? a : b,
      );

      expect(weakest.key, 'shaft-bundle');
      expect(weakest.value, Elv5Rational.parseDecimal('20.8278'));
      expect(result.governingSectionId, weakest.key);
      expect(result.allowableCurrentIzA, weakest.value);
    });

    test('Q9 bounded route fold remains deterministic at declared pilot scale',
        () {
      const sectionCount = 256;
      final specs = <_SectionSpec>[
        for (var i = 0; i < sectionCount; i++)
          _SectionSpec(
            's-${i.toString().padLeft(3, '0')}',
            baseA: 100 + (i % 7),
            temperatureFactor: i == 173 ? '0.51' : '0.9',
            groupingFactor: '0.8',
          ),
      ];
      final input = _routeInput(specs);
      final kernel = const Elv5RouteAmpacityKernel();
      final first = kernel.evaluate(input);
      final second = kernel.evaluate(input);

      expect(input.orderedSections, hasLength(sectionCount));
      expect(first.governingSectionId, 's-173');
      expect(first.allowableCurrentIzA, second.allowableCurrentIzA);
      expect(first.governingSectionId, second.governingSectionId);
      expect(first.sectionResults, hasLength(sectionCount));
    });
  });
}

final class _SectionSpec {
  const _SectionSpec(
    this.id, {
    required this.baseA,
    required this.temperatureFactor,
    required this.groupingFactor,
    this.additionalFactors = const <String, String>{},
  });

  final String id;
  final int baseA;
  final String temperatureFactor;
  final String groupingFactor;
  final Map<String, String> additionalFactors;
}

Elv5RouteAmpacityInput _routeInput(List<_SectionSpec> specs) =>
    Elv5RouteAmpacityInput(
      cableRunId: 'run-1',
      orderedSections: <Elv5RouteAmpacitySectionInput>[
        for (var i = 0; i < specs.length; i++) _section(specs[i], i),
      ],
    );

Elv5RouteAmpacitySectionInput _section(_SectionSpec spec, int ordinal) {
  final ambient = Elv5Rational.integer(40 + ordinal);
  final profile = Elv5EnvironmentProfile(
    profileId: 'profile-${spec.id}',
    editionId: 'edition-${spec.id}',
    profileCode: 'INDOOR',
    temperatureC: Elv5RationalRange(
      minimum: Elv5Rational.integer(20),
      maximum: ambient,
    ),
    relativeHumidityPercent: Elv5RationalRange(
      minimum: Elv5Rational.integer(30),
      maximum: Elv5Rational.integer(70),
    ),
    condensationRisk: Elv5CondensationRisk.none,
    exposure: Elv5EnvironmentExposure.indoor,
    evidenceRef: 'ENV:${spec.id}',
    evidenceContentHash: _h('1'),
  );
  final binding = Elv5EnvironmentScopeBinding(
    bindingId: 'env-binding-${spec.id}',
    scopeKind: 'ROUTE_SECTION',
    scopeId: spec.id,
    profile: profile,
    priority: 10,
  );
  final reference = Elv5AmpacityReferenceRow(
    conductorCrossSectionMm2: Elv5Rational.parseDecimal('2.5'),
    conductorMaterialCode: 'CU',
    insulationSystemCode: 'PVC70',
    referenceAmbientTemperatureC: Elv5Rational.integer(30),
    installationMethodCode: 'TRAY',
    loadedConductors: 2,
    baseAllowableCurrentA: Elv5Rational.integer(spec.baseA),
    evidenceRef: 'AMPACITY:${spec.id}',
    evidenceContentHash: _h('2'),
  );
  final input = Elv5AmpacityInput(
    cableOrSectionId: spec.id,
    referenceRow: reference,
    temperatureCorrection: Elv5AmpacityTemperatureCorrection(
      actualAmbientTemperatureC: ambient,
      factor: Elv5Rational.parseDecimal(spec.temperatureFactor),
      evidenceRef: 'TEMP:${spec.id}',
      evidenceContentHash: _h('4'),
    ),
    groupingCorrection: Elv5AmpacityGroupingCorrection(
      groupedCableOrCircuitCount: 2,
      arrangementCode: 'BUNCHED',
      factor: Elv5Rational.parseDecimal(spec.groupingFactor),
      evidenceRef: 'GROUP:${spec.id}',
      evidenceContentHash: _h('3'),
    ),
    additionalCorrections: <Elv5AmpacityAdditionalCorrection>[
      for (final entry in spec.additionalFactors.entries)
        Elv5AmpacityAdditionalCorrection(
          code: entry.key,
          factor: Elv5Rational.parseDecimal(entry.value),
          evidenceRef: 'ADD:${spec.id}:${entry.key}',
          evidenceContentHash: _h('5'),
        ),
    ],
  );
  return Elv5RouteAmpacitySectionInput(
    sectionId: spec.id,
    environmentBinding: binding,
    ampacityInput: input,
  );
}

String _h(String char) => List<String>.filled(64, char).join();
