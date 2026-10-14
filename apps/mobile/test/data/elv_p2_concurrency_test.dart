import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:electra_mobile/application/elv_cable_allocation_command.dart';
import 'package:electra_mobile/application/elv_cable_allocation_service.dart';
import 'package:electra_mobile/application/elv_command_result.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/drift_elv_cable_allocation_write_unit_of_work.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter_test/flutter_test.dart';

const _projectId = 'race-project';

CableDefinition _definition() => CableDefinition(
  code: 'RACE-CABLE',
  label: 'Race cable',
  mediaCode: 'COPPER',
  resourceDefinitions: [
    CableResourceDefinition(
      identity: '__WHOLE_CABLE__',
      kind: CableResourceKind.wholeCable,
      allocatable: true,
      atomic: false,
      childResourceIds: const ['COND-1', 'COND-2'],
      terminationPolicy: TerminationPolicy(
        mode: TerminationPolicyMode.bothEnds,
        terminalRequired: false,
      ),
    ),
    for (final id in ['COND-1', 'COND-2'])
      CableResourceDefinition(
        identity: id,
        kind: CableResourceKind.conductor,
        allocatable: true,
        atomic: true,
        parentResourceId: '__WHOLE_CABLE__',
        terminationPolicy: TerminationPolicy(
          mode: TerminationPolicyMode.bothEnds,
          terminalRequired: false,
        ),
      ),
  ],
);

EngineeringReferenceCatalog _catalog() => EngineeringReferenceCatalog(
  id: 'race-catalog',
  code: 'RACE',
  version: '1',
  source: 'test',
  cableDefinitions: [_definition()],
);

NativeDatabase _native(File file) => NativeDatabase(
  file,
  setup: (raw) {
    raw.execute('PRAGMA journal_mode=WAL');
    raw.execute('PRAGMA busy_timeout=5000');
  },
);

Future<void> _seed(AppDatabase db) async {
  final now = DateTime.utc(2026, 10, 14, 9);
  await db
      .into(db.projects)
      .insert(
        ProjectsCompanion.insert(
          id: _projectId,
          name: 'Race project',
          measurementSystem: 'metric',
          defaultStructuralHeightMm: 3000,
          defaultFinishedCeilingHeightMm: 2700,
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'test',
        ),
      );
  await db
      .into(db.floors)
      .insert(
        FloorsCompanion.insert(
          id: 'floor',
          projectId: _projectId,
          name: 'L1',
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'test',
        ),
      );
  await db
      .into(db.rooms)
      .insert(
        RoomsCompanion.insert(
          id: 'room',
          floorId: 'floor',
          name: 'Room',
          roomType: 'TEST',
          roomCategory: 'TEST',
          widthMm: 1000,
          depthMm: 1000,
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'test',
        ),
      );
  await db
      .into(db.surfacePatches)
      .insert(
        SurfacePatchesCompanion.insert(
          id: 'patch',
          roomId: 'room',
          surfaceId: 'surface',
          originXmm: 0,
          originYmm: 0,
          originZmm: 0,
          uAxisX: 1,
          uAxisY: 0,
          uAxisZ: 0,
          vAxisX: 0,
          vAxisY: 1,
          vAxisZ: 0,
          orientation: 'floor',
          boundaryJson: '[]',
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'test',
        ),
      );
  await db
      .into(db.engineeringFamilyDefinitions)
      .insert(
        EngineeringFamilyDefinitionsCompanion.insert(
          id: 'family',
          code: 'RACE',
          familyVersion: '1',
          payloadJson: '{}',
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'test',
        ),
        mode: InsertMode.insertOrIgnore,
      );
  await db
      .into(db.projectEngineeringSystems)
      .insert(
        ProjectEngineeringSystemsCompanion.insert(
          id: 'system',
          projectId: _projectId,
          code: 'RACE',
          familyId: 'family',
          payloadJson: '{}',
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'test',
        ),
      );
  await db
      .into(db.engineeringCompatibilityProfiles)
      .insert(
        EngineeringCompatibilityProfilesCompanion.insert(
          id: 'profile',
          projectId: _projectId,
          code: 'WIRED',
          profileVersion: '1',
          payloadJson: '{}',
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'test',
        ),
      );
  for (final connectionId in ['conn-a', 'conn-b']) {
    for (final end in ['a', 'b']) {
      final componentId = '$connectionId-component-$end';
      final portId = '$connectionId-port-$end';
      await db
          .into(db.componentInstances)
          .insert(
            ComponentInstancesCompanion.insert(
              id: componentId,
              definitionId: 'fixture',
              definitionVersion: 1,
              roomId: 'room',
              hostSurfacePatchId: 'patch',
              localXmm: end == 'a' ? 100 : 200,
              localYmm: 100,
              createdAt: now,
              updatedAt: now,
              originDeviceId: 'test',
            ),
          );
      await db
          .into(db.engineeringPortInstances)
          .insert(
            EngineeringPortInstancesCompanion.insert(
              id: portId,
              projectId: _projectId,
              componentId: componentId,
              code: end.toUpperCase(),
              payloadJson: '{}',
              createdAt: now,
              updatedAt: now,
              originDeviceId: 'test',
            ),
          );
    }
    final connection = EngineeringConnection(
      id: connectionId,
      systemId: 'system',
      fromPortId: '$connectionId-port-a',
      toPortId: '$connectionId-port-b',
      profileId: 'profile',
      medium: ConnectionMedium.wired,
    );
    await db
        .into(db.engineeringPortConnections)
        .insert(
          EngineeringPortConnectionsCompanion.insert(
            id: connectionId,
            projectId: _projectId,
            systemId: 'system',
            fromPortId: connection.fromPortId,
            toPortId: connection.toPortId,
            profileId: 'profile',
            payloadJson: canonicalEngineeringJsonV1(connection.toMap()),
            createdAt: now,
            updatedAt: now,
            originDeviceId: 'test',
          ),
        );
  }
  final catalog = _catalog();
  await db
      .into(db.engineeringReferenceCatalogs)
      .insert(
        EngineeringReferenceCatalogsCompanion.insert(
          id: catalog.id,
          projectId: _projectId,
          code: catalog.code,
          catalogVersion: catalog.version,
          payloadJson: canonicalEngineeringJsonV1(catalog.toMap()),
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'test',
        ),
      );
  final ref = catalog.cableDefinitionRef('RACE-CABLE');
  await db
      .into(db.elvCables)
      .insert(
        ElvCablesCompanion.insert(
          id: 'cable',
          projectId: _projectId,
          label: 'CABLE',
          normalizedLabel: 'CABLE',
          name: 'Cable',
          definitionCatalogId: ref.catalogId,
          definitionCatalogVersion: ref.catalogVersion,
          definitionCode: ref.definitionCode,
          definitionContentHash: ref.definitionContentHash,
          lifecycleState: 'ACTIVE',
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'test',
        ),
      );
}

DefaultElvCableAllocationService _service(AppDatabase db, String device) =>
    DefaultElvCableAllocationService(
      unitOfWork: DriftElvCableAllocationWriteUnitOfWork(
        db,
        originDeviceId: device,
      ),
      originDeviceId: device,
    );

void main() {
  test('two sqlite connections cannot reserve the same cable atom', () async {
    final dir = await Directory.systemTemp.createTemp('electra-elv3-p2-race-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/race.sqlite');

    final seedDb = AppDatabase(_native(file));
    await _seed(seedDb);
    final seedService = _service(seedDb, 'seed');
    await seedService.createDraft(
      const CreateCableAllocationDraftCommand(
        commandId: 'create-a',
        projectId: _projectId,
        allocationId: 'alloc-a',
        engineeringConnectionId: 'conn-a',
        cableId: 'cable',
      ),
    );
    await seedService.createDraft(
      const CreateCableAllocationDraftCommand(
        commandId: 'create-b',
        projectId: _projectId,
        allocationId: 'alloc-b',
        engineeringConnectionId: 'conn-b',
        cableId: 'cable',
      ),
    );
    await seedDb.close();

    final dbA = AppDatabase(_native(file));
    final dbB = AppDatabase(_native(file));
    addTearDown(dbA.close);
    addTearDown(dbB.close);
    final serviceA = _service(dbA, 'device-a');
    final serviceB = _service(dbB, 'device-b');

    final results = await Future.wait([
      serviceA.reserve(
        ReserveCableResourcesCommand(
          commandId: 'reserve-a',
          projectId: _projectId,
          allocationId: 'alloc-a',
          expectedRevision: 1,
          selection: ResourceSetSelection(const ['COND-1']),
        ),
      ),
      serviceB.reserve(
        ReserveCableResourcesCommand(
          commandId: 'reserve-b',
          projectId: _projectId,
          allocationId: 'alloc-b',
          expectedRevision: 1,
          selection: ResourceSetSelection(const ['COND-1']),
        ),
      ),
    ]);

    expect(
      results.whereType<ElvCommandSuccess<CableAllocation>>(),
      hasLength(1),
    );
    final failures =
        results.whereType<ElvCommandFailureResult<CableAllocation>>();
    expect(failures, hasLength(1));
    expect(failures.single.failure.code, 'ELV_ALLOC_RESOURCE_OVERLAP');

    final verifier = AppDatabase(_native(file));
    final claims =
        await (verifier.select(verifier.cableResourceClaims)
          ..where((row) => row.resourceAtom.equals('COND-1'))).get();
    expect(claims, hasLength(1));
    await verifier.close();
  });
}
