import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:test/test.dart';

void main() {
  Elv5Rational q(String value) => Elv5Rational.parseDecimal(value);

  Fa08RouteSection section({
    String? cableClass = 'TEST_CLASS_A',
    bool envComplete = true,
    Set<String> tags = const {'INDOOR'},
    List<Fa08NumericFact> facts = const [],
  }) =>
      Fa08RouteSection(
        sectionId: 'section-1',
        cableEditionId: 'cable-edition-1',
        cableClass: cableClass,
        environmentEvidenceComplete: envComplete,
        environmentTags: tags,
        numericFacts: facts,
      );

  test('technical policy passes while verified compliance remains not assessed', () {
    final result = const Fa08CablePolicyKernel().evaluate(Fa08Input(
      orderedSections: [section()],
      policy: Fa08Policy(
        policyId: 'policy-1',
        requirements: [
          Fa08Requirement.cableClass(code: 'CLASS', expectedClass: 'TEST_CLASS_A'),
          Fa08Requirement.environmentTag(code: 'ENV', requiredTag: 'INDOOR'),
        ],
      ),
      complianceEvidence: null,
    ));

    expect(result.technicalPolicyMatch, Fa08AssessmentStatus.pass);
    expect(result.verifiedCompliance, Fa08AssessmentStatus.notAssessed);
  });

  test('numeric limit equality is inclusive PASS with zero margin', () {
    final result = const Fa08CablePolicyKernel().evaluate(Fa08Input(
      orderedSections: [
        section(facts: [
          Fa08NumericFact(
            propertyCode: 'TEMP_MAX',
            unitCode: 'C',
            value: q('60'),
          ),
        ]),
      ],
      policy: Fa08Policy(
        policyId: 'policy-1',
        requirements: [
          Fa08Requirement.numeric(
            code: 'TEMP',
            kind: Fa08RequirementKind.numericMaximum,
            propertyCode: 'TEMP_MAX',
            unitCode: 'C',
            threshold: q('60'),
          ),
        ],
      ),
      complianceEvidence: null,
    ));

    expect(result.technicalPolicyMatch, Fa08AssessmentStatus.pass);
    expect(result.policyResults.single.numericMargin, q('0'));
  });

  test('explicit class mismatch fails technical policy', () {
    final result = const Fa08CablePolicyKernel().evaluate(Fa08Input(
      orderedSections: [section(cableClass: 'TEST_CLASS_B')],
      policy: Fa08Policy(
        policyId: 'policy-1',
        requirements: [
          Fa08Requirement.cableClass(code: 'CLASS', expectedClass: 'TEST_CLASS_A'),
        ],
      ),
      complianceEvidence: null,
    ));

    expect(result.technicalPolicyMatch, Fa08AssessmentStatus.fail);
    expect(result.limitingRequirementCode, 'CLASS');
  });

  test('missing immutable cable class blocks instead of parsing product name', () {
    final result = const Fa08CablePolicyKernel().evaluate(Fa08Input(
      orderedSections: [section(cableClass: null)],
      policy: Fa08Policy(
        policyId: 'policy-1',
        requirements: [
          Fa08Requirement.cableClass(code: 'CLASS', expectedClass: 'TEST_CLASS_A'),
        ],
      ),
      complianceEvidence: null,
    ));

    expect(result.technicalPolicyMatch, Fa08AssessmentStatus.blocked);
  });
}
