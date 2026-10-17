enum Lan04AssessmentStatus { pass, fail, unresolved, unsupported }

enum Lan04Medium { copper, fiber, other }

enum Lan04PropertyCode {
  medium,
  interfaceKind,
  speedMode,
  connector,
  shielding
}

final class Lan04RequiredMode {
  Lan04RequiredMode({
    required this.medium,
    required this.interfaceKind,
    required this.speedMode,
    required this.connectorKind,
    required this.shieldingRequired,
  }) {
    if (interfaceKind.isEmpty || speedMode.isEmpty || connectorKind.isEmpty) {
      throw ArgumentError('LAN04 required-mode tokens must not be empty.');
    }
  }

  final Lan04Medium medium;
  final String interfaceKind;
  final String speedMode;
  final String connectorKind;
  final bool shieldingRequired;
}

final class Lan04PathSection {
  Lan04PathSection({
    required this.sectionId,
    required this.medium,
    required this.supportedInterfaceKinds,
    required this.supportedSpeedModes,
    required this.supportedConnectorKinds,
    required this.shieldContinuityKnown,
    required this.shieldContinuity,
  }) {
    if (sectionId.isEmpty)
      throw ArgumentError('LAN04 sectionId must not be empty.');
  }

  final String sectionId;
  final Lan04Medium medium;
  final Set<String> supportedInterfaceKinds;
  final Set<String> supportedSpeedModes;
  final Set<String> supportedConnectorKinds;
  final bool shieldContinuityKnown;
  final bool shieldContinuity;
}

final class Lan04SectionResult {
  const Lan04SectionResult({
    required this.sectionId,
    required this.statusByProperty,
  });

  final String sectionId;
  final Map<Lan04PropertyCode, Lan04AssessmentStatus> statusByProperty;

  Lan04AssessmentStatus get status {
    if (statusByProperty.values.contains(Lan04AssessmentStatus.unsupported)) {
      return Lan04AssessmentStatus.unsupported;
    }
    if (statusByProperty.values.contains(Lan04AssessmentStatus.fail)) {
      return Lan04AssessmentStatus.fail;
    }
    if (statusByProperty.values.contains(Lan04AssessmentStatus.unresolved)) {
      return Lan04AssessmentStatus.unresolved;
    }
    return Lan04AssessmentStatus.pass;
  }
}

final class Lan04Input {
  Lan04Input({
    required this.linkId,
    required this.orderedSections,
    required this.requiredMode,
  }) {
    if (linkId.isEmpty) throw ArgumentError('LAN04 linkId must not be empty.');
    if (orderedSections.isEmpty)
      throw ArgumentError('LAN04 ordered path must not be empty.');
    final seen = <String>{};
    for (final section in orderedSections) {
      if (!seen.add(section.sectionId)) {
        throw ArgumentError('LAN04 duplicate sectionId: ${section.sectionId}');
      }
    }
  }

  final String linkId;
  final List<Lan04PathSection> orderedSections;
  final Lan04RequiredMode requiredMode;
}

final class Lan04Result {
  const Lan04Result({
    required this.status,
    required this.sections,
    required this.limitingSectionId,
    required this.limitingProperty,
  });

  final Lan04AssessmentStatus status;
  final List<Lan04SectionResult> sections;
  final String? limitingSectionId;
  final Lan04PropertyCode? limitingProperty;
}

final class Lan04PathCompatibilityKernel {
  const Lan04PathCompatibilityKernel();

  Lan04Result evaluate(Lan04Input input) {
    final results = <Lan04SectionResult>[];
    String? limitingSectionId;
    Lan04PropertyCode? limitingProperty;
    Lan04AssessmentStatus overall = Lan04AssessmentStatus.pass;

    for (final section in input.orderedSections) {
      final property = <Lan04PropertyCode, Lan04AssessmentStatus>{};
      property[Lan04PropertyCode.medium] =
          section.medium == input.requiredMode.medium
              ? Lan04AssessmentStatus.pass
              : Lan04AssessmentStatus.unsupported;
      property[Lan04PropertyCode.interfaceKind] = section
              .supportedInterfaceKinds
              .contains(input.requiredMode.interfaceKind)
          ? Lan04AssessmentStatus.pass
          : Lan04AssessmentStatus.fail;
      property[Lan04PropertyCode.speedMode] =
          section.supportedSpeedModes.contains(input.requiredMode.speedMode)
              ? Lan04AssessmentStatus.pass
              : Lan04AssessmentStatus.fail;
      property[Lan04PropertyCode.connector] = section.supportedConnectorKinds
              .contains(input.requiredMode.connectorKind)
          ? Lan04AssessmentStatus.pass
          : Lan04AssessmentStatus.fail;
      property[Lan04PropertyCode.shielding] =
          !input.requiredMode.shieldingRequired
              ? Lan04AssessmentStatus.pass
              : (!section.shieldContinuityKnown
                  ? Lan04AssessmentStatus.unresolved
                  : (section.shieldContinuity
                      ? Lan04AssessmentStatus.pass
                      : Lan04AssessmentStatus.fail));

      final result = Lan04SectionResult(
        sectionId: section.sectionId,
        statusByProperty: Map.unmodifiable(property),
      );
      results.add(result);

      if (limitingSectionId == null) {
        for (final code in Lan04PropertyCode.values) {
          final status = property[code]!;
          if (status != Lan04AssessmentStatus.pass) {
            limitingSectionId = section.sectionId;
            limitingProperty = code;
            break;
          }
        }
      }

      if (result.status == Lan04AssessmentStatus.unsupported) {
        overall = Lan04AssessmentStatus.unsupported;
      } else if (overall != Lan04AssessmentStatus.unsupported &&
          result.status == Lan04AssessmentStatus.fail) {
        overall = Lan04AssessmentStatus.fail;
      } else if (overall == Lan04AssessmentStatus.pass &&
          result.status == Lan04AssessmentStatus.unresolved) {
        overall = Lan04AssessmentStatus.unresolved;
      }
    }

    return Lan04Result(
      status: overall,
      sections: List.unmodifiable(results),
      limitingSectionId: limitingSectionId,
      limitingProperty: limitingProperty,
    );
  }
}
