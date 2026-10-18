import 'package:electra_mobile/application/elv5/cctv/cctv06_link_contract.dart';
import 'package:electra_mobile/application/elv5/lan/lan04_compatibility_contract.dart';
import 'package:electra_mobile/application/elv5/policy/elv5_physical_link_capability.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final sha = List<String>.filled(64, 'a').join();

  test('CCTV-06 and LAN-04 share canonical physical tokens', () {
    final cctv = Cctv06SectionEvidenceContract(
      sectionId: 'section-cctv',
      mediumCode: ' copper ',
      interfaceKind: ' ethernet ',
      categoryToken: ' cat6a ',
      shieldContinuityKnown: true,
      shieldContinuity: true,
      evidenceRef: 'evidence-cctv',
      evidenceContentHash: sha,
    );
    final lan = Lan04SectionCapabilityContract(
      sectionId: 'section-lan',
      mediumCode: ' Copper ',
      supportedInterfaceKinds: const <String>[' ethernet '],
      supportedSpeedModes: const <String>[' 10gbase-t '],
      supportedConnectorKinds: const <String>[' rj45 '],
      shieldContinuityKnown: true,
      shieldContinuity: true,
      evidenceRef: 'evidence-lan',
      evidenceContentHash: sha,
    );

    expect(cctv.mediumCode, Elv5PhysicalMedium.copper.code);
    expect(lan.mediumCode, Elv5PhysicalMedium.copper.code);
    expect(cctv.interfaceKind, 'ETHERNET');
    expect(lan.supportedInterfaceKinds, contains('ETHERNET'));
  });

  test('unsupported medium fails closed in both contracts', () {
    expect(
      () => Cctv06SectionEvidenceContract(
        sectionId: 'section-cctv',
        mediumCode: 'wireless',
        interfaceKind: 'ethernet',
        categoryToken: 'cat6a',
        shieldContinuityKnown: true,
        shieldContinuity: true,
        evidenceRef: 'evidence-cctv',
        evidenceContentHash: sha,
      ),
      throwsArgumentError,
    );
    expect(
      () => Lan04SectionCapabilityContract(
        sectionId: 'section-lan',
        mediumCode: 'wireless',
        supportedInterfaceKinds: const <String>['ethernet'],
        supportedSpeedModes: const <String>['10gbase-t'],
        supportedConnectorKinds: const <String>['rj45'],
        shieldContinuityKnown: true,
        shieldContinuity: true,
        evidenceRef: 'evidence-lan',
        evidenceContentHash: sha,
      ),
      throwsArgumentError,
    );
  });

  test('unknown shield continuity cannot claim continuity', () {
    expect(
      () => validateElv5ShieldContinuity(known: false, continuous: true),
      throwsArgumentError,
    );
    expect(
      () => Cctv06SectionEvidenceContract(
        sectionId: 'section-cctv',
        mediumCode: 'copper',
        interfaceKind: 'ethernet',
        categoryToken: 'cat6a',
        shieldContinuityKnown: false,
        shieldContinuity: true,
        evidenceRef: 'evidence-cctv',
        evidenceContentHash: sha,
      ),
      throwsArgumentError,
    );
    expect(
      () => Lan04SectionCapabilityContract(
        sectionId: 'section-lan',
        mediumCode: 'copper',
        supportedInterfaceKinds: const <String>['ethernet'],
        supportedSpeedModes: const <String>['10gbase-t'],
        supportedConnectorKinds: const <String>['rj45'],
        shieldContinuityKnown: false,
        shieldContinuity: true,
        evidenceRef: 'evidence-lan',
        evidenceContentHash: sha,
      ),
      throwsArgumentError,
    );
  });
}
