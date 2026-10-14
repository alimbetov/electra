import 'elv_physical_compatibility_profile.dart';

const String physicalCompatibilityEngineVersion =
    'elv.physical-compatibility.v1';

enum PhysicalCompatibilityStatus { ok, warning, forbidden, unresolved }

final class PhysicalCompatibilityInput {
  const PhysicalCompatibilityInput({
    required this.subjectIds,
    required this.mediaCode,
    required this.cableCategoryCode,
    required this.cableTechnicalClassCodes,
    required this.cableOuterDiameterMm,
    required this.carrierKind,
    required this.carrierUsableAreaMm2,
    required this.installationClassCode,
    required this.environmentCodes,
    required this.pathwayKind,
    required this.profileRefs,
    required this.rules,
    required this.inputFingerprint,
  });

  final List<String> subjectIds;
  final String mediaCode;
  final String? cableCategoryCode;
  final List<String> cableTechnicalClassCodes;
  final double? cableOuterDiameterMm;
  final String carrierKind;
  final double? carrierUsableAreaMm2;
  final String? installationClassCode;
  final Map<String, String?> environmentCodes;
  final String pathwayKind;
  final List<PhysicalCompatibilityProfileRef> profileRefs;
  final List<PhysicalCompatibilityRule> rules;
  final String inputFingerprint;
}

final class PhysicalCompatibilityFinding {
  const PhysicalCompatibilityFinding({
    required this.status,
    required this.code,
    required this.affectedEntityIds,
    required this.inputFingerprint,
    required this.explanation,
    required this.sourceProfileRefs,
  });

  final PhysicalCompatibilityStatus status;
  final String code;
  final List<String> affectedEntityIds;
  final String inputFingerprint;
  final String explanation;
  final List<PhysicalCompatibilityProfileRef> sourceProfileRefs;
}

abstract final class PhysicalCompatibilityEngine {
  static List<PhysicalCompatibilityFinding> evaluate(
    PhysicalCompatibilityInput input,
  ) {
    final findings = <PhysicalCompatibilityFinding>[];
    for (final rule in input.rules) {
      if (!rule.selector.matches(
        mediaCode: input.mediaCode,
        cableCategoryCode: input.cableCategoryCode,
        cableTechnicalClassCodes: input.cableTechnicalClassCodes,
        carrierKind: input.carrierKind,
        pathwayKind: input.pathwayKind,
      )) {
        continue;
      }

      switch (rule) {
        case AllowedCarrierKindRule(:final allowedKinds):
          if (!allowedKinds.contains(input.carrierKind.toUpperCase())) {
            findings.add(_finding(
                input,
                PhysicalCompatibilityStatus.forbidden,
                'ELV_PHYS_CARRIER_KIND_FORBIDDEN',
                'Carrier kind is not allowed by the active technical profile.'));
          }
        case AllowedInstallationClassRule(:final allowedCodes):
          final actual = input.installationClassCode?.toUpperCase();
          if (actual == null) {
            findings.add(_finding(
                input,
                PhysicalCompatibilityStatus.unresolved,
                'ELV_PHYS_INSTALLATION_CLASS_MISSING',
                'Installation class evidence is missing.'));
          } else if (!allowedCodes.contains(actual)) {
            findings.add(_finding(
                input,
                PhysicalCompatibilityStatus.forbidden,
                'ELV_PHYS_INSTALLATION_CLASS_FORBIDDEN',
                'Installation class is not allowed by the active technical profile.'));
          }
        case AllowedEnvironmentClassRule(:final dimension, :final allowedCodes):
          final actual =
              input.environmentCodes[dimension.toUpperCase()]?.toUpperCase();
          if (actual == null) {
            findings.add(_finding(
                input,
                PhysicalCompatibilityStatus.unresolved,
                'ELV_PHYS_ENVIRONMENT_FACT_MISSING',
                'Required environment evidence is missing.'));
          } else if (!allowedCodes.contains(actual)) {
            findings.add(_finding(
                input,
                PhysicalCompatibilityStatus.forbidden,
                'ELV_PHYS_ENVIRONMENT_FORBIDDEN',
                'Environment class is not allowed by the active technical profile.'));
          }
        case MaximumCableDiameterRule(:final maximumDiameterMm):
          final actual = input.cableOuterDiameterMm;
          if (actual == null) {
            findings.add(_finding(
                input,
                PhysicalCompatibilityStatus.unresolved,
                'ELV_PHYS_CABLE_DIAMETER_MISSING',
                'Cable outer diameter evidence is missing.'));
          } else if (actual > maximumDiameterMm) {
            findings.add(_finding(
                input,
                PhysicalCompatibilityStatus.forbidden,
                'ELV_PHYS_CABLE_DIAMETER_EXCEEDED',
                'Cable outer diameter exceeds the technical profile limit.'));
          }
        case MinimumCarrierUsableAreaRule(:final minimumAreaMm2):
          final actual = input.carrierUsableAreaMm2;
          if (actual == null) {
            findings.add(_finding(
                input,
                PhysicalCompatibilityStatus.unresolved,
                'ELV_PHYS_CARRIER_AREA_MISSING',
                'Carrier usable-area evidence is missing.'));
          } else if (actual < minimumAreaMm2) {
            findings.add(_finding(
                input,
                PhysicalCompatibilityStatus.forbidden,
                'ELV_PHYS_CARRIER_AREA_INSUFFICIENT',
                'Carrier usable area is below the technical profile requirement.'));
          }
        case DirectIntrinsicProhibitionRule(:final code):
          findings.add(_finding(input, PhysicalCompatibilityStatus.forbidden,
              code, 'An intrinsic technical prohibition applies.'));
      }
    }

    if (findings.isEmpty) {
      findings.add(_finding(input, PhysicalCompatibilityStatus.ok,
          'ELV_PHYS_OK', 'No technical physical incompatibility was found.'));
    }
    findings.sort((a, b) => _rank(a.status).compareTo(_rank(b.status)));
    return List.unmodifiable(findings);
  }

  static PhysicalCompatibilityFinding _finding(
    PhysicalCompatibilityInput input,
    PhysicalCompatibilityStatus status,
    String code,
    String explanation,
  ) =>
      PhysicalCompatibilityFinding(
        status: status,
        code: code,
        affectedEntityIds: List.unmodifiable(input.subjectIds),
        inputFingerprint: input.inputFingerprint,
        explanation: explanation,
        sourceProfileRefs: List.unmodifiable(input.profileRefs),
      );

  static int _rank(PhysicalCompatibilityStatus status) => switch (status) {
        PhysicalCompatibilityStatus.forbidden => 0,
        PhysicalCompatibilityStatus.unresolved => 1,
        PhysicalCompatibilityStatus.warning => 2,
        PhysicalCompatibilityStatus.ok => 3,
      };
}
