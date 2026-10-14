import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:electra_mobile/application/engineering_placement_command.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/drift_engineering_placement_repository.dart';
import 'package:engineering_core/engineering_core.dart';

Future<void> seedPlacementParents(AppDatabase database) async {
  final now = DateTime.utc(2026, 10, 13, 19);
  await database
      .into(database.projects)
      .insert(
        ProjectsCompanion.insert(
          id: 'project-1',
          name: 'P4 Project',
          measurementSystem: 'metric',
          defaultStructuralHeightMm: 3200,
          defaultFinishedCeilingHeightMm: 3000,
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'p4-test-device',
        ),
      );
  await database
      .into(database.floors)
      .insert(
        FloorsCompanion.insert(
          id: 'floor-1',
          projectId: 'project-1',
          name: 'Floor 1',
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'p4-test-device',
        ),
      );
  await database
      .into(database.rooms)
      .insert(
        RoomsCompanion.insert(
          id: 'room-1',
          floorId: 'floor-1',
          name: 'Room 1',
          roomType: 'technical',
          roomCategory: 'technical',
          widthMm: 6000,
          depthMm: 5000,
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'p4-test-device',
        ),
      );
  await database
      .into(database.surfacePatches)
      .insert(
        SurfacePatchesCompanion.insert(
          id: 'patch-1',
          roomId: 'room-1',
          surfaceId: 'Wall A',
          originXmm: 0,
          originYmm: 0,
          originZmm: 0,
          uAxisX: 1,
          uAxisY: 0,
          uAxisZ: 0,
          vAxisX: 0,
          vAxisY: 0,
          vAxisZ: 1,
          orientation: 'vertical',
          boundaryJson: '[[0,0],[6000,0],[6000,3000],[0,3000]]',
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'p4-test-device',
        ),
      );
  await database
      .into(database.componentInstances)
      .insert(
        ComponentInstancesCompanion.insert(
          id: 'component-1',
          definitionId: canonicalElvComponentDefinitionId,
          definitionVersion: canonicalElvComponentDefinitionVersion,
          roomId: 'room-1',
          hostSurfacePatchId: 'patch-1',
          localXmm: 120,
          localYmm: 80,
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'p4-test-device',
        ),
      );
}

Future<void> seedPlacementSystemAndCatalog(AppDatabase database) async {
  await seedEngineeringSystem(
    database,
    id: 'system-1',
    code: 'CCTV-01',
    familyCode: 'CCTV',
  );
  final now = DateTime.utc(2026, 10, 13, 19, 2);
  final source =
      jsonDecode(
            File(
              '../../docs/examples/elv2-interface-catalog.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final catalog = EngineeringReferenceCatalog.fromMap({
    ...source,
    'id': 'catalog-1',
    'version': '1.0.0',
  });
  await database
      .into(database.engineeringReferenceCatalogs)
      .insert(
        EngineeringReferenceCatalogsCompanion.insert(
          id: catalog.id,
          projectId: 'project-1',
          code: catalog.code,
          catalogVersion: catalog.version,
          payloadJson: canonicalEngineeringJson(catalog.toMap()),
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'p4-test-device',
        ),
      );
}

Future<void> seedEngineeringSystem(
  AppDatabase database, {
  required String id,
  required String code,
  required String familyCode,
}) async {
  final family =
      await (database.select(database.engineeringFamilyDefinitions)..where(
        (row) => row.code.equals(familyCode) & row.deletedAt.isNull(),
      )).getSingle();
  final system = EngineeringSystem(
    id: id,
    projectId: 'project-1',
    code: code,
    name: code,
    familyId: family.id,
    familyVersion: family.familyVersion,
  );
  final now = DateTime.utc(2026, 10, 13, 19, 1);
  await database
      .into(database.projectEngineeringSystems)
      .insert(
        ProjectEngineeringSystemsCompanion.insert(
          id: system.id,
          projectId: system.projectId,
          code: system.code,
          familyId: system.familyId,
          payloadJson: canonicalEngineeringJson(system.toMap()),
          revision: const Value(1),
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'p4-test-device',
        ),
      );
}

Future<void> seedPlacementOperation(
  AppDatabase database, {
  required PlaceEngineeringProfileCommand command,
  required EngineeringPlacementResult result,
  required String status,
}) async {
  final now = DateTime.utc(2026, 10, 13, 19, 5);
  await database
      .into(database.engineeringPlacementOperations)
      .insert(
        EngineeringPlacementOperationsCompanion.insert(
          operationId: command.operationId,
          projectId: command.projectId,
          fingerprintVersion: engineeringPlacementFingerprintVersion,
          commandFingerprint: engineeringPlacementFingerprintV1(command),
          status: status,
          componentId: result.componentId,
          resultJson: engineeringPlacementResultJson(result),
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'p4-test-device',
        ),
      );
}

PlaceEngineeringProfileCommand placementCommand({
  String operationId = 'op-1',
  String projectId = 'project-1',
  String systemId = 'system-1',
  String profileCode = 'CAMERA',
  String catalogId = 'catalog-1',
  String catalogVersion = '1.0.0',
  PlacementCandidateContext? context,
  Point2Mm localPosition = const Point2Mm(120, 80),
  String? displayNameOverride = 'Camera A',
}) => PlaceEngineeringProfileCommand(
  operationId: operationId,
  projectId: projectId,
  roomId: 'room-1',
  systemId: systemId,
  membershipRole: canonicalElvMembershipRole,
  catalogId: catalogId,
  catalogVersion: catalogVersion,
  profileCode: profileCode,
  hostSurfacePatchId: 'patch-1',
  localPosition: localPosition,
  rotationRadians: 0.25,
  placementContext:
      context ??
      PlacementCandidateContext(
        projectId: projectId,
        roomId: 'room-1',
        surfaceId: 'patch-1',
        installationSurface: InstallationSurface.wall,
        mountingMethod: MountingMethod.bracket,
        environmentExposure: EnvironmentExposure.indoor,
        environmentMoisture: EnvironmentMoisture.dry,
        environmentContamination: EnvironmentContamination.normal,
        environmentClimate: EnvironmentClimate.conditioned,
        ambientTemperatureC: 20,
        actualIpRating: IpProtectionClass.parse('IP54'),
        hasEnclosure: false,
        availableClearanceMm: 50,
        topologyShape: TopologyShape.star,
        topologyRole: TopologyParticipation.endpoint,
      ),
  displayNameOverride: displayNameOverride,
);

EngineeringPlacementResult placementResult() => EngineeringPlacementResult(
  operationId: 'op-1',
  componentId: 'component-1',
  systemId: 'system-1',
  membershipRole: canonicalElvMembershipRole,
  catalogId: 'catalog-1',
  catalogVersion: '1.0.0',
  profileCode: 'CAMERA',
  bindingComponentId: 'component-1',
  portIds: const ['port-1'],
  placementStatus: PlacementCompatibilityStatus.compatible,
  committedAt: DateTime.utc(2026, 10, 13, 19, 5),
);
