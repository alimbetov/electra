import 'package:engineering_core/engineering_core.dart';

import 'elv_physical_compatibility_repository.dart';

final class ElvPhysicalCompatibilityService {
  const ElvPhysicalCompatibilityService(this.repository);

  final ElvPhysicalCompatibilityRepository repository;

  Future<List<PhysicalCompatibilityFinding>> evaluate({
    required String projectId,
    required PhysicalCompatibilityInput input,
  }) async {
    final activeSet = await repository.activeProfileSet(projectId);
    if (activeSet == null || !activeSet.active) {
      return [
        PhysicalCompatibilityFinding(
          status: PhysicalCompatibilityStatus.unresolved,
          code: 'ELV_PHYS_PROFILE_SET_MISSING',
          affectedEntityIds: List.unmodifiable(input.subjectIds),
          inputFingerprint: input.inputFingerprint,
          explanation: 'No active physical compatibility profile set is configured.',
          sourceProfileRefs: const [],
        ),
      ];
    }
    final profiles = await repository.resolveProfiles(projectId, activeSet.refs);
    final rules = <PhysicalCompatibilityRule>[
      for (final profile in profiles) ...profile.rules,
    ];
    final materialized = PhysicalCompatibilityInput(
      subjectIds: input.subjectIds,
      mediaCode: input.mediaCode,
      cableCategoryCode: input.cableCategoryCode,
      cableTechnicalClassCodes: input.cableTechnicalClassCodes,
      cableOuterDiameterMm: input.cableOuterDiameterMm,
      carrierKind: input.carrierKind,
      carrierUsableAreaMm2: input.carrierUsableAreaMm2,
      installationClassCode: input.installationClassCode,
      environmentCodes: input.environmentCodes,
      pathwayKind: input.pathwayKind,
      profileRefs: activeSet.refs,
      rules: rules,
      inputFingerprint: input.inputFingerprint,
    );
    return PhysicalCompatibilityEngine.evaluate(materialized);
  }
}
