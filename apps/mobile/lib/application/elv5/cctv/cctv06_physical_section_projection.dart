import 'package:engineering_core/engineering_core_elv5.dart';

import 'cctv06_link_contract.dart';

extension Cctv06PhysicalSectionProjection on Cctv06SectionEvidenceContract {
  /// Discipline-neutral subset of CCTV-06 section evidence.
  ///
  /// Realized interface/category semantics remain CCTV-owned.
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
