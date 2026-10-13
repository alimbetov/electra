import 'engineering_reference_catalog.dart';
import 'engineering_reference_constraints.dart';
import 'engineering_topology.dart';

enum PlacementCompatibilityStatus {
  compatible,
  warning,
  forbidden,
  unresolved,
}

enum PlacementFindingSeverity { warning, error, unresolved }

enum PlacementFindingDimension { profile, mounting, environment, topology }

enum PlacementFindingCode {
  profileDeprecated,
  profileConstraintsInvalid,
  legacyConstraintsUnspecified,
  mountingContextIncomplete,
  mountingCombinationNotAllowed,
  enclosurePresenceUnresolved,
  enclosureRequired,
  clearanceUnresolved,
  clearanceInsufficient,
  environmentExposureUnresolved,
  environmentExposureNotAllowed,
  environmentMoistureUnresolved,
  environmentMoistureNotAllowed,
  environmentContaminationUnresolved,
  environmentContaminationNotAllowed,
  environmentClimateUnresolved,
  environmentClimateNotAllowed,
  ambientTemperatureUnresolved,
  ambientTemperatureInvalid,
  temperatureBelowMinimum,
  temperatureAboveMaximum,
  ipProtectionUnresolved,
  ipProtectionInsufficient,
  topologyShapeUnresolved,
  topologyShapeNotAllowed,
  topologyRoleUnresolved,
  topologyRoleNotAllowed,
}

class PlacementCandidateContext {
  const PlacementCandidateContext({
    required this.projectId,
    required this.roomId,
    required this.surfaceId,
    this.installationSurface,
    this.mountingMethod,
    this.environmentExposure,
    this.environmentMoisture,
    this.environmentContamination,
    this.environmentClimate,
    this.ambientTemperatureC,
    this.actualIpRating,
    this.hasEnclosure,
    this.availableClearanceMm,
    this.topologyShape,
    this.topologyRole,
  });

  final String projectId;
  final String roomId;
  final String surfaceId;
  final InstallationSurface? installationSurface;
  final MountingMethod? mountingMethod;
  final EnvironmentExposure? environmentExposure;
  final EnvironmentMoisture? environmentMoisture;
  final EnvironmentContamination? environmentContamination;
  final EnvironmentClimate? environmentClimate;
  final double? ambientTemperatureC;
  final IpProtectionClass? actualIpRating;
  final bool? hasEnclosure;
  final double? availableClearanceMm;
  final TopologyShape? topologyShape;
  final TopologyParticipation? topologyRole;
}

class PlacementFinding {
  const PlacementFinding({
    required this.code,
    required this.severity,
    required this.dimension,
    required this.explanation,
    this.expected,
    this.actual,
    this.remediationHint,
  });

  final PlacementFindingCode code;
  final PlacementFindingSeverity severity;
  final PlacementFindingDimension dimension;
  final String explanation;
  final String? expected;
  final String? actual;
  final String? remediationHint;
}

class PlacementCompatibilityResult {
  PlacementCompatibilityResult({
    required this.profileCode,
    required this.catalogId,
    required this.catalogVersion,
    required Iterable<PlacementFinding> findings,
  }) : findings = List.unmodifiable(findings);

  final String profileCode;
  final String catalogId;
  final String catalogVersion;
  final List<PlacementFinding> findings;

  PlacementCompatibilityStatus get status {
    if (findings.any(
      (finding) => finding.severity == PlacementFindingSeverity.error,
    )) {
      return PlacementCompatibilityStatus.forbidden;
    }
    if (findings.any(
      (finding) => finding.severity == PlacementFindingSeverity.unresolved,
    )) {
      return PlacementCompatibilityStatus.unresolved;
    }
    if (findings.any(
      (finding) => finding.severity == PlacementFindingSeverity.warning,
    )) {
      return PlacementCompatibilityStatus.warning;
    }
    return PlacementCompatibilityStatus.compatible;
  }

  bool get compatible => status == PlacementCompatibilityStatus.compatible;
}

class PlacementCompatibilityEngine {
  const PlacementCompatibilityEngine();

  PlacementCompatibilityResult evaluate({
    required ComponentEngineeringProfile profile,
    required String catalogId,
    required String catalogVersion,
    required PlacementCandidateContext context,
  }) {
    final findings = <PlacementFinding>[];

    if (profile.deprecated) {
      findings.add(
        const PlacementFinding(
          code: PlacementFindingCode.profileDeprecated,
          severity: PlacementFindingSeverity.error,
          dimension: PlacementFindingDimension.profile,
          explanation: 'Deprecated profiles cannot be used for new placement.',
          remediationHint: 'Choose an active canonical profile edition.',
        ),
      );
    }

    if (profile.constraintsState == ProfileConstraintsState.legacyUnspecified) {
      findings.add(
        const PlacementFinding(
          code: PlacementFindingCode.legacyConstraintsUnspecified,
          severity: PlacementFindingSeverity.unresolved,
          dimension: PlacementFindingDimension.profile,
          explanation:
              'This historical profile does not contain placement constraints.',
          remediationHint:
              'Normalize or adopt a complete canonical profile edition before new placement.',
        ),
      );
      return PlacementCompatibilityResult(
        profileCode: profile.code,
        catalogId: catalogId,
        catalogVersion: catalogVersion,
        findings: findings,
      );
    }

    final constraints = profile.constraints;
    if (constraints == null) {
      findings.add(
        const PlacementFinding(
          code: PlacementFindingCode.profileConstraintsInvalid,
          severity: PlacementFindingSeverity.unresolved,
          dimension: PlacementFindingDimension.profile,
          explanation:
              'Defined constraint state requires a constraints payload.',
          remediationHint: 'Repair the catalog edition before placement.',
        ),
      );
      return PlacementCompatibilityResult(
        profileCode: profile.code,
        catalogId: catalogId,
        catalogVersion: catalogVersion,
        findings: findings,
      );
    }

    final constraintErrors = constraints.validate();
    if (constraintErrors.isNotEmpty) {
      findings.add(
        PlacementFinding(
          code: PlacementFindingCode.profileConstraintsInvalid,
          severity: PlacementFindingSeverity.unresolved,
          dimension: PlacementFindingDimension.profile,
          explanation: constraintErrors.join(' '),
          remediationHint: 'Repair the catalog edition before placement.',
        ),
      );
      return PlacementCompatibilityResult(
        profileCode: profile.code,
        catalogId: catalogId,
        catalogVersion: catalogVersion,
        findings: findings,
      );
    }

    findings.addAll(_evaluateMounting(constraints.mounting, context));
    findings.addAll(_evaluateEnvironment(constraints.environment, context));
    findings.addAll(_evaluateTopology(constraints.topology, context));

    return PlacementCompatibilityResult(
      profileCode: profile.code,
      catalogId: catalogId,
      catalogVersion: catalogVersion,
      findings: findings,
    );
  }

  Iterable<PlacementFinding> _evaluateMounting(
    MountingConstraintProfile constraint,
    PlacementCandidateContext context,
  ) sync* {
    final surface = context.installationSurface;
    final method = context.mountingMethod;
    if (surface == null || method == null) {
      yield const PlacementFinding(
        code: PlacementFindingCode.mountingContextIncomplete,
        severity: PlacementFindingSeverity.unresolved,
        dimension: PlacementFindingDimension.mounting,
        explanation:
            'Installation surface and mounting method are required to prove compatibility.',
        remediationHint: 'Select both a host surface and mounting method.',
      );
    } else if (!constraint.allows(surface, method)) {
      yield PlacementFinding(
        code: PlacementFindingCode.mountingCombinationNotAllowed,
        severity: PlacementFindingSeverity.error,
        dimension: PlacementFindingDimension.mounting,
        explanation:
            'The selected surface and mounting method are not an allowed pair.',
        expected:
            constraint.options.map((option) => option.identity).join(', '),
        actual: '${surface.name}:${method.name}',
        remediationHint: 'Choose one of the canonical mounting combinations.',
      );
    }

    if (constraint.enclosureRequired) {
      if (context.hasEnclosure == null) {
        yield const PlacementFinding(
          code: PlacementFindingCode.enclosurePresenceUnresolved,
          severity: PlacementFindingSeverity.unresolved,
          dimension: PlacementFindingDimension.mounting,
          explanation:
              'The profile requires an enclosure but enclosure presence is unknown.',
          expected: 'enclosure present',
          remediationHint: 'Select or confirm the enclosing equipment context.',
        );
      } else if (!context.hasEnclosure!) {
        yield const PlacementFinding(
          code: PlacementFindingCode.enclosureRequired,
          severity: PlacementFindingSeverity.error,
          dimension: PlacementFindingDimension.mounting,
          explanation:
              'The profile requires placement inside or with an enclosure.',
          expected: 'enclosure present',
          actual: 'no enclosure',
          remediationHint: 'Place the component in a compatible enclosure.',
        );
      }
    }

    final requiredClearance = constraint.minimumClearanceMm;
    if (requiredClearance != null) {
      final actualClearance = context.availableClearanceMm;
      if (actualClearance == null) {
        yield PlacementFinding(
          code: PlacementFindingCode.clearanceUnresolved,
          severity: PlacementFindingSeverity.unresolved,
          dimension: PlacementFindingDimension.mounting,
          explanation:
              'Available clearance is required to prove compatibility.',
          expected: '>= $requiredClearance mm',
          remediationHint: 'Provide the available installation clearance.',
        );
      } else if (!actualClearance.isFinite ||
          actualClearance < requiredClearance) {
        yield PlacementFinding(
          code: PlacementFindingCode.clearanceInsufficient,
          severity: PlacementFindingSeverity.error,
          dimension: PlacementFindingDimension.mounting,
          explanation:
              'Available clearance does not satisfy the profile minimum.',
          expected: '>= $requiredClearance mm',
          actual: '$actualClearance mm',
          remediationHint:
              'Choose a location with sufficient installation clearance.',
        );
      }
    }
  }

  Iterable<PlacementFinding> _evaluateEnvironment(
    EnvironmentConstraintProfile constraint,
    PlacementCandidateContext context,
  ) sync* {
    final exposure = context.environmentExposure;
    if (exposure == null) {
      yield const PlacementFinding(
        code: PlacementFindingCode.environmentExposureUnresolved,
        severity: PlacementFindingSeverity.unresolved,
        dimension: PlacementFindingDimension.environment,
        explanation: 'Environment exposure is required to prove compatibility.',
      );
    } else if (!constraint.allowedExposure.contains(exposure)) {
      yield PlacementFinding(
        code: PlacementFindingCode.environmentExposureNotAllowed,
        severity: PlacementFindingSeverity.error,
        dimension: PlacementFindingDimension.environment,
        explanation:
            'The candidate exposure class is not allowed by the profile.',
        expected: _names(constraint.allowedExposure),
        actual: exposure.name,
      );
    }

    yield* _evaluateOptionalEnvironmentDimension<EnvironmentMoisture>(
      allowed: constraint.allowedMoisture,
      actual: context.environmentMoisture,
      unresolvedCode: PlacementFindingCode.environmentMoistureUnresolved,
      mismatchCode: PlacementFindingCode.environmentMoistureNotAllowed,
      label: 'moisture',
    );
    yield* _evaluateOptionalEnvironmentDimension<EnvironmentContamination>(
      allowed: constraint.allowedContamination,
      actual: context.environmentContamination,
      unresolvedCode: PlacementFindingCode.environmentContaminationUnresolved,
      mismatchCode: PlacementFindingCode.environmentContaminationNotAllowed,
      label: 'contamination',
    );
    yield* _evaluateOptionalEnvironmentDimension<EnvironmentClimate>(
      allowed: constraint.allowedClimate,
      actual: context.environmentClimate,
      unresolvedCode: PlacementFindingCode.environmentClimateUnresolved,
      mismatchCode: PlacementFindingCode.environmentClimateNotAllowed,
      label: 'climate',
    );

    final minTemperature = constraint.minimumTemperatureC;
    final maxTemperature = constraint.maximumTemperatureC;
    if (minTemperature != null && maxTemperature != null) {
      final actual = context.ambientTemperatureC;
      if (actual == null) {
        yield PlacementFinding(
          code: PlacementFindingCode.ambientTemperatureUnresolved,
          severity: PlacementFindingSeverity.unresolved,
          dimension: PlacementFindingDimension.environment,
          explanation:
              'Ambient temperature is required to prove compatibility.',
          expected: '$minTemperature..$maxTemperature C',
        );
      } else if (!actual.isFinite) {
        yield PlacementFinding(
          code: PlacementFindingCode.ambientTemperatureInvalid,
          severity: PlacementFindingSeverity.error,
          dimension: PlacementFindingDimension.environment,
          explanation:
              'Ambient temperature must be a finite engineering value.',
          actual: '$actual',
        );
      } else if (actual < minTemperature) {
        yield PlacementFinding(
          code: PlacementFindingCode.temperatureBelowMinimum,
          severity: PlacementFindingSeverity.error,
          dimension: PlacementFindingDimension.environment,
          explanation: 'Ambient temperature is below the profile minimum.',
          expected: '>= $minTemperature C',
          actual: '$actual C',
        );
      } else if (actual > maxTemperature) {
        yield PlacementFinding(
          code: PlacementFindingCode.temperatureAboveMaximum,
          severity: PlacementFindingSeverity.error,
          dimension: PlacementFindingDimension.environment,
          explanation: 'Ambient temperature is above the profile maximum.',
          expected: '<= $maxTemperature C',
          actual: '$actual C',
        );
      }
    }

    final requiredIp = constraint.minimumIpRating;
    if (requiredIp != null) {
      final actualIp = context.actualIpRating;
      if (actualIp == null) {
        yield PlacementFinding(
          code: PlacementFindingCode.ipProtectionUnresolved,
          severity: PlacementFindingSeverity.unresolved,
          dimension: PlacementFindingDimension.environment,
          explanation:
              'Actual IP protection is required to prove compatibility.',
          expected: '>= ${requiredIp.value}',
        );
      } else {
        final result = _compareIp(actualIp, requiredIp);
        if (result == _IpComparison.unresolved) {
          yield PlacementFinding(
            code: PlacementFindingCode.ipProtectionUnresolved,
            severity: PlacementFindingSeverity.unresolved,
            dimension: PlacementFindingDimension.environment,
            explanation:
                'Actual IP protection does not contain enough numeric evidence to prove the minimum.',
            expected: '>= ${requiredIp.value}',
            actual: actualIp.value,
          );
        } else if (result == _IpComparison.insufficient) {
          yield PlacementFinding(
            code: PlacementFindingCode.ipProtectionInsufficient,
            severity: PlacementFindingSeverity.error,
            dimension: PlacementFindingDimension.environment,
            explanation: 'Actual IP protection is below the profile minimum.',
            expected: '>= ${requiredIp.value}',
            actual: actualIp.value,
          );
        }
      }
    }
  }

  Iterable<PlacementFinding>
      _evaluateOptionalEnvironmentDimension<T extends Enum>({
    required List<T> allowed,
    required T? actual,
    required PlacementFindingCode unresolvedCode,
    required PlacementFindingCode mismatchCode,
    required String label,
  }) sync* {
    if (allowed.isEmpty) return;
    if (actual == null) {
      yield PlacementFinding(
        code: unresolvedCode,
        severity: PlacementFindingSeverity.unresolved,
        dimension: PlacementFindingDimension.environment,
        explanation: 'Environment $label is required to prove compatibility.',
        expected: _names(allowed),
      );
    } else if (!allowed.contains(actual)) {
      yield PlacementFinding(
        code: mismatchCode,
        severity: PlacementFindingSeverity.error,
        dimension: PlacementFindingDimension.environment,
        explanation:
            'The candidate $label class is not allowed by the profile.',
        expected: _names(allowed),
        actual: actual.name,
      );
    }
  }

  Iterable<PlacementFinding> _evaluateTopology(
    TopologyConstraintProfile constraint,
    PlacementCandidateContext context,
  ) sync* {
    final shape = context.topologyShape;
    if (shape == null) {
      yield PlacementFinding(
        code: PlacementFindingCode.topologyShapeUnresolved,
        severity: PlacementFindingSeverity.unresolved,
        dimension: PlacementFindingDimension.topology,
        explanation:
            'Selected system topology shape is required before placement.',
        expected: _names(constraint.allowedShapes),
      );
    } else if (!constraint.allowedShapes.contains(shape)) {
      yield PlacementFinding(
        code: PlacementFindingCode.topologyShapeNotAllowed,
        severity: PlacementFindingSeverity.error,
        dimension: PlacementFindingDimension.topology,
        explanation:
            'The selected topology shape is not allowed by the profile.',
        expected: _names(constraint.allowedShapes),
        actual: shape.name,
      );
    }

    final role = context.topologyRole;
    if (role == null) {
      yield PlacementFinding(
        code: PlacementFindingCode.topologyRoleUnresolved,
        severity: PlacementFindingSeverity.unresolved,
        dimension: PlacementFindingDimension.topology,
        explanation:
            'Intended topology participation role is required before placement.',
        expected: _names(constraint.allowedRoles),
      );
    } else if (!constraint.allowedRoles.contains(role)) {
      yield PlacementFinding(
        code: PlacementFindingCode.topologyRoleNotAllowed,
        severity: PlacementFindingSeverity.error,
        dimension: PlacementFindingDimension.topology,
        explanation:
            'The intended topology role is not allowed by the profile.',
        expected: _names(constraint.allowedRoles),
        actual: role.name,
      );
    }
  }
}

String _names<T extends Enum>(Iterable<T> values) =>
    values.map((value) => value.name).join(', ');

enum _IpComparison { sufficient, insufficient, unresolved }

_IpComparison _compareIp(
  IpProtectionClass actual,
  IpProtectionClass required,
) {
  final actualIngress = actual.value[2];
  final actualWater = actual.value[3];
  final requiredIngress = required.value[2];
  final requiredWater = required.value[3];

  final ingress = _compareIpDigit(actualIngress, requiredIngress);
  final water = _compareIpDigit(actualWater, requiredWater);
  if (ingress == _IpComparison.insufficient ||
      water == _IpComparison.insufficient) {
    return _IpComparison.insufficient;
  }
  if (ingress == _IpComparison.unresolved ||
      water == _IpComparison.unresolved) {
    return _IpComparison.unresolved;
  }
  return _IpComparison.sufficient;
}

_IpComparison _compareIpDigit(String actual, String required) {
  if (required == 'X') return _IpComparison.sufficient;
  if (actual == 'X') return _IpComparison.unresolved;
  return int.parse(actual) >= int.parse(required)
      ? _IpComparison.sufficient
      : _IpComparison.insufficient;
}
