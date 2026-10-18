import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:test/test.dart';

void main() {
  test('FA-08 consumes shared Iz and compares it against technical minimum',
      () {
    final section = Fa08RouteSection(
      sectionId: 'section-1',
      cableEditionId: 'cable-edition-1',
      cableClass: 'TEST_CLASS_A',
      environmentEvidenceComplete: true,
      environmentTags: <String>{'INDOOR'},
      numericFacts: const <Fa08NumericFact>[],
      ampacityInput: _ampacityInput(sectionId: 'section-1'),
    );

    final result = const Fa08CablePolicyKernel().evaluate(
      Fa08Input(
        orderedSections: <Fa08RouteSection>[section],
        policy: Fa08Policy(
          policyId: 'fire-cable-policy-1',
          requirements: <Fa08Requirement>[
            Fa08Requirement.numeric(
              code: 'MIN_IZ',
              kind: Fa08RequirementKind.numericMinimum,
              propertyCode: Fa08RouteSection.ampacityIzPropertyCode,
              unitCode: 'A',
              threshold: Elv5Rational.integer(29),
            ),
          ],
        ),
        complianceEvidence: null,
      ),
    );

    expect(result.technicalPolicyMatch, Fa08AssessmentStatus.pass);
    expect(result.verifiedCompliance, Fa08AssessmentStatus.notAssessed);
    expect(
      result.policyResults.single.numericMargin,
      Elv5Rational.parseDecimal('0.12'),
    );
  });

  test('FA-08 blocks ampacity dimension when exact Iz contract is absent', () {
    final result = const Fa08CablePolicyKernel().evaluate(
      Fa08Input(
        orderedSections: <Fa08RouteSection>[
          Fa08RouteSection(
            sectionId: 'section-1',
            cableEditionId: 'cable-edition-1',
            cableClass: 'TEST_CLASS_A',
            environmentEvidenceComplete: true,
            environmentTags: <String>{'INDOOR'},
            numericFacts: const <Fa08NumericFact>[],
          ),
        ],
        policy: Fa08Policy(
          policyId: 'fire-cable-policy-1',
          requirements: <Fa08Requirement>[
            Fa08Requirement.numeric(
              code: 'MIN_IZ',
              kind: Fa08RequirementKind.numericMinimum,
              propertyCode: Fa08RouteSection.ampacityIzPropertyCode,
              unitCode: 'A',
              threshold: Elv5Rational.integer(20),
            ),
          ],
        ),
        complianceEvidence: null,
      ),
    );

    expect(result.technicalPolicyMatch, Fa08AssessmentStatus.blocked);
  });

  test('raw AMPACITY_IZ_A fact cannot bypass the shared ampacity contract', () {
    expect(
      () => Fa08RouteSection(
        sectionId: 'section-1',
        cableEditionId: 'cable-edition-1',
        cableClass: 'TEST_CLASS_A',
        environmentEvidenceComplete: true,
        environmentTags: <String>{'INDOOR'},
        numericFacts: <Fa08NumericFact>[
          Fa08NumericFact(
            propertyCode: Fa08RouteSection.ampacityIzPropertyCode,
            unitCode: 'A',
            value: Elv5Rational.integer(999),
          ),
        ],
      ),
      throwsArgumentError,
    );
  });
}

Elv5AmpacityInput _ampacityInput({required String sectionId}) =>
    Elv5AmpacityInput(
      cableOrSectionId: sectionId,
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

String _hash(String char) => List<String>.filled(64, char).join();
