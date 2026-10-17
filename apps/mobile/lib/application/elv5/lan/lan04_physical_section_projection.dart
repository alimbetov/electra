import 'package:engineering_core/engineering_core_elv5.dart';

import 'lan04_compatibility_contract.dart';

extension Lan04PhysicalSectionProjection on Lan04SectionCapabilityContract {
  /// Discipline-neutral subset of LAN-04 section evidence.
  ///
  /// Speed/connector/interface capability sets remain LAN-owned.
  Elv5PhysicalSectionEvidence get physicalSectionEvidence =>
      Elv5PhysicalSectionEvidence(
        sectionId: sectionId,
        mediumCode: mediumCode,
        shieldContinuityKnown: shieldContinuityKnown,
        shieldContinuity: shieldContinuity,
        evidenceRef: evidenceRef,
        evidenceContentHash: evidenceContentHash,
      );
}
