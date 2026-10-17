import '../../numeric/interval.dart';
import '../../numeric/quantity.dart';
import '../../numeric/rational.dart';

enum Cctv06AssessmentStatus { pass, fail, unresolved, blocked, notApplicable }

enum Cctv06Medium { copper, fiber, other }

enum Cctv06PropertyCode { medium, interfaceKind, category, shielding }

final class Cctv06Section {
  Cctv06Section({
    required this.sectionId,
    required this.length,
    required this.medium,
    required this.interfaceKind,
    required this.categoryToken,
    required this.shieldContinuityKnown,
    required this.shieldContinuity,
  }) {
    if (sectionId.isEmpty || interfaceKind.isEmpty || categoryToken.isEmpty) {
      throw ArgumentError(
          'CCTV06 section identity/capability must not be empty.');
    }
    if (length.lower.value < Elv5Rational.zero) {
      throw ArgumentError('CCTV06 installed length must be nonnegative.');
    }
  }

  final String sectionId;
  final Elv5Interval<LengthDim> length;
  final Cctv06Medium medium;
  final String interfaceKind;
  final String categoryToken;
  final bool shieldContinuityKnown;
  final bool shieldContinuity;
}

final class Cctv06LinkPolicy {
  Cctv06LinkPolicy({
    required this.allowedMedia,
    required this.allowedInterfaceKinds,
    required this.allowedCategoryTokens,
    required this.shieldingRequired,
    this.maximumLength,
  });

  final Set<Cctv06Medium> allowedMedia;
  final Set<String> allowedInterfaceKinds;
  final Set<String> allowedCategoryTokens;
  final bool shieldingRequired;
  final Length? maximumLength;
}

final class Cctv06PowerEvidence {
  Cctv06PowerEvidence({
    required this.pathFingerprint,
    required this.globalMargin,
    required this.requiredSegmentIds,
    required this.evidencedSegmentIds,
  }) {
    if (pathFingerprint.isEmpty) {
      throw ArgumentError(
          'CCTV06 power evidence fingerprint must not be empty.');
    }
  }

  final String pathFingerprint;
  final Power globalMargin;
  final Set<String> requiredSegmentIds;
  final Set<String> evidencedSegmentIds;
}

final class Cctv06Input {
  Cctv06Input({
    required this.linkId,
    required this.pathFingerprint,
    required this.sections,
    required this.policy,
    required this.powered,
    required this.powerEvidence,
  }) {
    if (linkId.isEmpty || pathFingerprint.isEmpty) {
      throw ArgumentError(
          'CCTV06 link identity/fingerprint must not be empty.');
    }
    if (sections.isEmpty)
      throw ArgumentError('CCTV06 realized path must not be empty.');
    final seen = <String>{};
    for (final section in sections) {
      if (!seen.add(section.sectionId)) {
        throw ArgumentError('CCTV06 duplicate sectionId: ${section.sectionId}');
      }
    }
  }

  final String linkId;
  final String pathFingerprint;
  final List<Cctv06Section> sections;
  final Cctv06LinkPolicy policy;
  final bool powered;
  final Cctv06PowerEvidence? powerEvidence;
}

final class Cctv06SectionResult {
  const Cctv06SectionResult({
    required this.sectionId,
    required this.properties,
  });

  final String sectionId;
  final Map<Cctv06PropertyCode, Cctv06AssessmentStatus> properties;

  Cctv06AssessmentStatus get status {
    if (properties.values.contains(Cctv06AssessmentStatus.fail)) {
      return Cctv06AssessmentStatus.fail;
    }
    if (properties.values.contains(Cctv06AssessmentStatus.unresolved)) {
      return Cctv06AssessmentStatus.unresolved;
    }
    return Cctv06AssessmentStatus.pass;
  }
}

final class Cctv06Result {
  const Cctv06Result({
    required this.status,
    required this.realizedLength,
    required this.lengthMargin,
    required this.sectionResults,
    required this.powerStatus,
    required this.limitingSectionId,
    required this.limitingProperty,
    required this.blockingReason,
  });

  final Cctv06AssessmentStatus status;
  final Elv5Interval<LengthDim> realizedLength;
  final Length? lengthMargin;
  final List<Cctv06SectionResult> sectionResults;
  final Cctv06AssessmentStatus powerStatus;
  final String? limitingSectionId;
  final Cctv06PropertyCode? limitingProperty;
  final String? blockingReason;
}

final class Cctv06LinkBasisKernel {
  const Cctv06LinkBasisKernel();

  Cctv06Result evaluate(Cctv06Input input) {
    var length = Elv5Interval<LengthDim>.exact(Length(Elv5Rational.zero));
    final sectionResults = <Cctv06SectionResult>[];
    String? limitingSection;
    Cctv06PropertyCode? limitingProperty;

    for (final section in input.sections) {
      length = length + section.length;
      final properties = <Cctv06PropertyCode, Cctv06AssessmentStatus>{
        Cctv06PropertyCode.medium:
            input.policy.allowedMedia.contains(section.medium)
                ? Cctv06AssessmentStatus.pass
                : Cctv06AssessmentStatus.fail,
        Cctv06PropertyCode.interfaceKind:
            input.policy.allowedInterfaceKinds.contains(section.interfaceKind)
                ? Cctv06AssessmentStatus.pass
                : Cctv06AssessmentStatus.fail,
        Cctv06PropertyCode.category:
            input.policy.allowedCategoryTokens.contains(section.categoryToken)
                ? Cctv06AssessmentStatus.pass
                : Cctv06AssessmentStatus.fail,
        Cctv06PropertyCode.shielding: !input.policy.shieldingRequired
            ? Cctv06AssessmentStatus.pass
            : (!section.shieldContinuityKnown
                ? Cctv06AssessmentStatus.unresolved
                : (section.shieldContinuity
                    ? Cctv06AssessmentStatus.pass
                    : Cctv06AssessmentStatus.fail)),
      };
      if (limitingSection == null) {
        for (final code in Cctv06PropertyCode.values) {
          if (properties[code] != Cctv06AssessmentStatus.pass) {
            limitingSection = section.sectionId;
            limitingProperty = code;
            break;
          }
        }
      }
      sectionResults.add(Cctv06SectionResult(
        sectionId: section.sectionId,
        properties: Map.unmodifiable(properties),
      ));
    }

    Length? lengthMargin;
    var lengthStatus = Cctv06AssessmentStatus.pass;
    if (input.policy.maximumLength != null) {
      lengthMargin = input.policy.maximumLength! - length.upper;
      if (lengthMargin.value < Elv5Rational.zero) {
        lengthStatus = Cctv06AssessmentStatus.fail;
      }
    }

    var powerStatus = Cctv06AssessmentStatus.notApplicable;
    String? blockingReason;
    if (input.powered) {
      final evidence = input.powerEvidence;
      if (evidence == null) {
        powerStatus = Cctv06AssessmentStatus.blocked;
        blockingReason = 'CCTV06_PWR06_EVIDENCE_REQUIRED';
      } else if (evidence.pathFingerprint != input.pathFingerprint) {
        powerStatus = Cctv06AssessmentStatus.blocked;
        blockingReason = 'CCTV06_PWR06_PATH_FINGERPRINT_MISMATCH';
      } else if (!evidence.evidencedSegmentIds
          .containsAll(evidence.requiredSegmentIds)) {
        powerStatus = Cctv06AssessmentStatus.blocked;
        blockingReason = 'CCTV06_PWR06_SEGMENT_CLOSURE_INCOMPLETE';
      } else {
        powerStatus = evidence.globalMargin.value >= Elv5Rational.zero
            ? Cctv06AssessmentStatus.pass
            : Cctv06AssessmentStatus.fail;
      }
    }

    final sectionStatuses = sectionResults.map((e) => e.status);
    late Cctv06AssessmentStatus overall;
    if (powerStatus == Cctv06AssessmentStatus.blocked) {
      overall = Cctv06AssessmentStatus.blocked;
    } else if (sectionStatuses.contains(Cctv06AssessmentStatus.fail) ||
        lengthStatus == Cctv06AssessmentStatus.fail ||
        powerStatus == Cctv06AssessmentStatus.fail) {
      overall = Cctv06AssessmentStatus.fail;
    } else if (sectionStatuses.contains(Cctv06AssessmentStatus.unresolved)) {
      overall = Cctv06AssessmentStatus.unresolved;
    } else {
      overall = Cctv06AssessmentStatus.pass;
    }

    return Cctv06Result(
      status: overall,
      realizedLength: length,
      lengthMargin: lengthMargin,
      sectionResults: List.unmodifiable(sectionResults),
      powerStatus: powerStatus,
      limitingSectionId: limitingSection,
      limitingProperty: limitingProperty,
      blockingReason: blockingReason,
    );
  }
}
