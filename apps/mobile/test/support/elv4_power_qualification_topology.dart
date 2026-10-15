import 'package:electra_mobile/data/repositories/drift_engineering_system_repository.dart';
import 'package:engineering_core/engineering_core.dart';

import 'elv4_power_qualification_builder.dart';

extension Elv4QualificationTopology on Elv4QualificationBuilder {
  Future<String> ensureSystem(String familyCode) async {
    final code = familyCode.trim().toUpperCase();
    final family = bundledEngineeringSystemFamilies.singleWhere(
      (candidate) => candidate.code == code,
    );
    final systems = DriftEngineeringSystemRepository(
      database,
      originDeviceId: 'qualification',
    );
    await systems.saveFamily(family);
    final systemId = '$projectId-system-${code.toLowerCase()}';
    await systems.saveSystem(
      EngineeringSystem(
        id: systemId,
        projectId: projectId,
        code: code,
        name: '$code qualification',
        familyId: family.id,
        familyVersion: family.version,
      ),
    );
    return systemId;
  }

  Future<String> connectDataPower({
    required String familyCode,
    required String connectionId,
    required String fromPortId,
    required String toPortId,
  }) async {
    final systemId = await ensureSystem(familyCode);
    final profileId = '$projectId-profile-${familyCode.toLowerCase()}';
    await topology.saveConnectionProfile(
      ConnectionCompatibilityProfile(
        identity: ProfileIdentity(
          id: profileId,
          projectId: projectId,
          code: '${familyCode.toUpperCase()}_DATA_POWER',
          version: '1',
          source: 'ELV4 P8 qualification',
        ),
        familyCodes: [familyCode.toUpperCase()],
        media: const [ConnectionMedium.wired],
        semanticCode: 'DATA_POWER',
        layer: ConnectionLayer.dataPower,
        flow: CompatibilityFlow.directed,
        kindA: EngineeringPortKind.dataPower,
        kindB: EngineeringPortKind.dataPower,
        connectorA: 'RJ45',
        connectorB: 'RJ45',
        protocolA: const EngineeringProfileReference(id: 'POE', version: '1'),
        protocolB: const EngineeringProfileReference(id: 'POE', version: '1'),
      ),
    );
    await topology.saveConnection(
      projectId,
      EngineeringConnection(
        id: connectionId,
        systemId: systemId,
        fromPortId: fromPortId,
        toPortId: toPortId,
        profileId: profileId,
        medium: ConnectionMedium.wired,
      ),
    );
    return connectionId;
  }
}
