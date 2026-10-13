import 'dart:convert';
import 'package:engineering_core/engineering_core.dart';
import 'package:test/test.dart';

void main() {
  test(
      'project system pins extensible family, topology and normative editions across serialization',
      () {
    const family = EngineeringSystemFamily(
        id: 'custom-network-v2',
        code: 'CUSTOM_VENDOR_BUS',
        name: 'Project bus',
        version: '2',
        source: 'Authored profile reference',
        routingClass: 'SIGNAL');
    final copy = EngineeringSystemFamily.fromMap(
        jsonDecode(jsonEncode(family.toMap())) as Map<String, dynamic>);
    expect(copy.toMap(), family.toMap());
    final system = EngineeringSystem(
        id: 'bus',
        projectId: 'project',
        code: 'BUS-01',
        name: 'Bus',
        familyId: copy.id,
        familyVersion: copy.version,
        normativeProfile: const EngineeringProfileReference(
            id: 'KZ-project-profile', version: 'reviewed-1'),
        topologyProfile: const EngineeringProfileReference(
            id: 'point-to-point', version: '1'));
    final restored = EngineeringSystem.fromMap(
        jsonDecode(jsonEncode(system.toMap())) as Map<String, dynamic>);
    expect(restored.toMap(), system.toMap());
    expect(restored.validate(), isEmpty);
    expect(restored.normativeProfile!.version, 'reviewed-1');
    expect(bundledEngineeringSystemFamilies.map((f) => f.code).toSet(),
        containsAll(['POWER', 'CCTV', 'LAN', 'ACS', 'FIRE']));
  });
}
