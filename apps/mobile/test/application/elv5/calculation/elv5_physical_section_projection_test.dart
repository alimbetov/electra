import 'package:electra_mobile/application/elv5/cctv/cctv06_link_contract.dart';
import 'package:electra_mobile/application/elv5/cctv/cctv06_physical_section_projection.dart';
import 'package:electra_mobile/application/elv5/lan/lan04_compatibility_contract.dart';
import 'package:electra_mobile/application/elv5/lan/lan04_physical_section_projection.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'LAN-04 and CCTV-06 map identical physical facts to one canonical projection',
    () {
      final contentHash = List<String>.filled(64, 'a').join();
      final lan = Lan04SectionCapabilityContract(
        sectionId: 'section-1',
        mediumCode: 'COPPER',
        supportedInterfaceKinds: const <String>['1000BASE-T'],
        supportedSpeedModes: const <String>['1G'],
        supportedConnectorKinds: const <String>['RJ45'],
        shieldContinuityKnown: true,
        shieldContinuity: true,
        evidenceRef: 'SECTION:section-1:v1',
        evidenceContentHash: contentHash,
      );
      final cctv = Cctv06SectionEvidenceContract(
        sectionId: 'section-1',
        mediumCode: 'COPPER',
        interfaceKind: '1000BASE-T',
        categoryToken: 'CAT6A',
        shieldContinuityKnown: true,
        shieldContinuity: true,
        evidenceRef: 'SECTION:section-1:v1',
        evidenceContentHash: contentHash,
      );

      final lanProjection = lan.physicalSectionEvidence;
      final cctvProjection = cctv.physicalSectionEvidence;
      const encoder = Elv5CanonicalJsonV1();

      expect(
        encoder.sha256(lanProjection.toCanonicalValue()),
        encoder.sha256(cctvProjection.toCanonicalValue()),
      );
      expect(lanProjection.mediumCode, 'COPPER');
      expect(lanProjection.shieldContinuity, isTrue);
    },
  );

  test(
    'process-specific interface semantics do not leak into shared projection',
    () {
      final contentHash = List<String>.filled(64, 'b').join();
      final lan = Lan04SectionCapabilityContract(
        sectionId: 'section-1',
        mediumCode: 'FIBER',
        supportedInterfaceKinds: const <String>['1000BASE-LX', '10GBASE-LR'],
        supportedSpeedModes: const <String>['1G', '10G'],
        supportedConnectorKinds: const <String>['LC'],
        shieldContinuityKnown: false,
        shieldContinuity: false,
        evidenceRef: 'SECTION:section-1:v2',
        evidenceContentHash: contentHash,
      );

      final projection = lan.physicalSectionEvidence.toCanonicalValue();
      expect(projection.containsKey('supportedInterfaceKinds'), isFalse);
      expect(projection.containsKey('supportedSpeedModes'), isFalse);
      expect(projection.containsKey('categoryToken'), isFalse);
    },
  );
}
