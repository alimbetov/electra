import '../../evidence/ampacity_contract.dart';
import '../../numeric/rational.dart';

enum Fa08AssessmentStatus { pass, fail, blocked, notAssessed }

enum Fa08RequirementKind {
  cableClassEquals,
  environmentTagPresent,
  numericMinimum,
  numericMaximum
}

final class Fa08NumericFact {
  Fa08NumericFact({
    required this.propertyCode,
    required this.unitCode,
    required this.value,
  }) {
    if (propertyCode.isEmpty || unitCode.isEmpty) {
      throw ArgumentError('FA08 numeric fact identity must not be empty.');
    }
  }

  final String propertyCode;
  final String unitCode;
  final Elv5Rational value;
}

final class Fa08RouteSection {
  Fa08RouteSection({
    required this.sectionId,
    required this.cableEditionId,
    required this.cableClass,
    required this.environmentEvidenceComplete,
    required this.environmentTags,
    required this.numericFacts,
    this.ampacityInput,
  }) {
    if (sectionId.isEmpty || cableEditionId.isEmpty) {
      throw ArgumentError(
          'FA08 section/cable edition identity must not be empty.');
    }
    final seen = <String>{};
    for (final fact in numericFacts) {
      if (!seen.add(fact.propertyCode)) {
        throw ArgumentError(
            'FA08 duplicate numeric property: ${fact.propertyCode}');
      }
      if (fact.propertyCode == ampacityIzPropertyCode) {
        throw ArgumentError(
          'FA08 $ampacityIzPropertyCode is reserved for the shared ampacity contract.',
        );
      }
    }
    if (ampacityInput != null && ampacityInput!.cableOrSectionId != sectionId) {
      throw ArgumentError(
        'FA08 ampacity input must reference the same route section.',
      );
    }
  }

  static const ampacityIzPropertyCode = 'AMPACITY_IZ_A';

  final String sectionId;
  final String cableEditionId;
  final String? cableClass;
  final bool environmentEvidenceComplete;
  final Set<String> environmentTags;
  final List<Fa08NumericFact> numericFacts;
  final Elv5AmpacityInput? ampacityInput;
}

final class Fa08Requirement {
  Fa08Requirement.cableClass(
      {required this.code, required String expectedClass})
      : kind = Fa08RequirementKind.cableClassEquals,
        expectedToken = expectedClass,
        propertyCode = null,
        unitCode = null,
        threshold = null {
    _validateCode(code);
    if (expectedClass.isEmpty)
      throw ArgumentError('FA08 expected class must not be empty.');
  }

  Fa08Requirement.environmentTag(
      {required this.code, required String requiredTag})
      : kind = Fa08RequirementKind.environmentTagPresent,
        expectedToken = requiredTag,
        propertyCode = null,
        unitCode = null,
        threshold = null {
    _validateCode(code);
    if (requiredTag.isEmpty)
      throw ArgumentError('FA08 environment tag must not be empty.');
  }

  Fa08Requirement.numeric({
    required this.code,
    required this.kind,
    required this.propertyCode,
    required this.unitCode,
    required this.threshold,
  }) : expectedToken = null {
    _validateCode(code);
    if (kind != Fa08RequirementKind.numericMinimum &&
        kind != Fa08RequirementKind.numericMaximum) {
      throw ArgumentError('FA08 numeric requirement kind is invalid.');
    }
    if (propertyCode == null ||
        propertyCode!.isEmpty ||
        unitCode == null ||
        unitCode!.isEmpty) {
      throw ArgumentError('FA08 numeric requirement property/unit is invalid.');
    }
    if (propertyCode == Fa08RouteSection.ampacityIzPropertyCode &&
        unitCode != 'A') {
      throw ArgumentError('FA08 ampacity Iz requirement must use unit A.');
    }
  }

  final String code;
  final Fa08RequirementKind kind;
  final String? expectedToken;
  final String? propertyCode;
  final String? unitCode;
  final Elv5Rational? threshold;

  static void _validateCode(String code) {
    if (code.isEmpty)
      throw ArgumentError('FA08 requirement code must not be empty.');
  }
}

final class Fa08Policy {
  Fa08Policy({required this.policyId, required this.requirements}) {
    if (policyId.isEmpty)
      throw ArgumentError('FA08 policyId must not be empty.');
    final seen = <String>{};
    for (final req in requirements) {
      if (!seen.add(req.code)) {
        throw ArgumentError('FA08 duplicate requirement code: ${req.code}');
      }
    }
  }

  final String policyId;
  final List<Fa08Requirement> requirements;
}

final class Fa08Elv7ComplianceEvidence {
  const Fa08Elv7ComplianceEvidence({required this.verifiedCompliant});
  final bool verifiedCompliant;
}

final class Fa08Input {
  Fa08Input({
    required this.orderedSections,
    required this.policy,
    required this.complianceEvidence,
  }) {
    if (orderedSections.isEmpty)
      throw ArgumentError('FA08 route must not be empty.');
    final seen = <String>{};
    for (final section in orderedSections) {
      if (!seen.add(section.sectionId)) {
        throw ArgumentError('FA08 duplicate sectionId: ${section.sectionId}');
      }
    }
  }

  final List<Fa08RouteSection> orderedSections;
  final Fa08Policy policy;
  final Fa08Elv7ComplianceEvidence? complianceEvidence;
}

final class Fa08PolicyResult {
  const Fa08PolicyResult({
    required this.sectionId,
    required this.requirementCode,
    required this.status,
    required this.numericMargin,
  });

  final String sectionId;
  final String requirementCode;
  final Fa08AssessmentStatus status;
  final Elv5Rational? numericMargin;
}

final class Fa08Result {
  const Fa08Result({
    required this.technicalPolicyMatch,
    required this.verifiedCompliance,
    required this.policyResults,
    required this.limitingSectionId,
    required this.limitingRequirementCode,
  });

  final Fa08AssessmentStatus technicalPolicyMatch;
  final Fa08AssessmentStatus verifiedCompliance;
  final List<Fa08PolicyResult> policyResults;
  final String? limitingSectionId;
  final String? limitingRequirementCode;
}

final class Fa08CablePolicyKernel {
  const Fa08CablePolicyKernel();

  Fa08Result evaluate(Fa08Input input) {
    final requirements = [...input.policy.requirements]
      ..sort((a, b) => a.code.compareTo(b.code));
    final results = <Fa08PolicyResult>[];
    String? limitingSection;
    String? limitingRequirement;

    for (final section in input.orderedSections) {
      final facts = <String, Fa08NumericFact>{
        for (final fact in section.numericFacts) fact.propertyCode: fact,
      };
      final ampacityInput = section.ampacityInput;
      if (ampacityInput != null) {
        final ampacity = const Elv5AmpacityKernel().evaluate(ampacityInput);
        facts[Fa08RouteSection.ampacityIzPropertyCode] = Fa08NumericFact(
          propertyCode: Fa08RouteSection.ampacityIzPropertyCode,
          unitCode: 'A',
          value: ampacity.allowableCurrentIzA,
        );
      }

      for (final req in requirements) {
        late Fa08AssessmentStatus status;
        Elv5Rational? margin;
        if (req.kind == Fa08RequirementKind.cableClassEquals) {
          status = section.cableClass == null
              ? Fa08AssessmentStatus.blocked
              : (section.cableClass == req.expectedToken
                  ? Fa08AssessmentStatus.pass
                  : Fa08AssessmentStatus.fail);
        } else if (req.kind == Fa08RequirementKind.environmentTagPresent) {
          status = !section.environmentEvidenceComplete
              ? Fa08AssessmentStatus.blocked
              : (section.environmentTags.contains(req.expectedToken)
                  ? Fa08AssessmentStatus.pass
                  : Fa08AssessmentStatus.fail);
        } else {
          final fact = facts[req.propertyCode];
          final isAmpacity =
              req.propertyCode == Fa08RouteSection.ampacityIzPropertyCode;
          if ((!isAmpacity && !section.environmentEvidenceComplete) ||
              fact == null ||
              fact.unitCode != req.unitCode) {
            status = Fa08AssessmentStatus.blocked;
          } else if (req.kind == Fa08RequirementKind.numericMinimum) {
            margin = fact.value - req.threshold!;
            status = margin >= Elv5Rational.zero
                ? Fa08AssessmentStatus.pass
                : Fa08AssessmentStatus.fail;
          } else if (req.kind == Fa08RequirementKind.numericMaximum) {
            margin = req.threshold! - fact.value;
            status = margin >= Elv5Rational.zero
                ? Fa08AssessmentStatus.pass
                : Fa08AssessmentStatus.fail;
          } else {
            throw StateError('FA08 unreachable requirement kind.');
          }
        }
        if (limitingSection == null && status != Fa08AssessmentStatus.pass) {
          limitingSection = section.sectionId;
          limitingRequirement = req.code;
        }
        results.add(Fa08PolicyResult(
          sectionId: section.sectionId,
          requirementCode: req.code,
          status: status,
          numericMargin: margin,
        ));
      }
    }

    final technical =
        results.any((e) => e.status == Fa08AssessmentStatus.blocked)
            ? Fa08AssessmentStatus.blocked
            : (results.any((e) => e.status == Fa08AssessmentStatus.fail)
                ? Fa08AssessmentStatus.fail
                : Fa08AssessmentStatus.pass);
    final compliance = input.complianceEvidence == null
        ? Fa08AssessmentStatus.notAssessed
        : (input.complianceEvidence!.verifiedCompliant
            ? Fa08AssessmentStatus.pass
            : Fa08AssessmentStatus.fail);

    return Fa08Result(
      technicalPolicyMatch: technical,
      verifiedCompliance: compliance,
      policyResults: List.unmodifiable(results),
      limitingSectionId: limitingSection,
      limitingRequirementCode: limitingRequirement,
    );
  }
}
