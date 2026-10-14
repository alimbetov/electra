import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:electra_mobile/application/elv_cable_allocation_command.dart';
import 'package:electra_mobile/application/elv_cable_allocation_service.dart';
import 'package:electra_mobile/application/elv_cable_command.dart';
import 'package:electra_mobile/application/elv_cable_command_service.dart';
import 'package:electra_mobile/application/elv_command_result.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/drift_elv_cable_allocation_repository.dart';
import 'package:electra_mobile/data/repositories/drift_elv_cable_allocation_write_unit_of_work.dart';
import 'package:electra_mobile/data/repositories/drift_elv_cable_write_unit_of_work.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter_test/flutter_test.dart';

const _projectId = 'project-p2';
const _systemId = 'system-p2';
const _profileId = 'profile-wired';
const _catalogId = 'catalog-p2';

TerminationPolicy _bothEnds() => TerminationPolicy(
      mode: TerminationPolicyMode.bothEnds,
      terminalRequired: false,
    );

CableDefinition _multiCore(
  String code,
  int count,
  CableResourceKind kind,
) {
  final atoms = [
    for (var i = 1; i <= count; i++)
      CableResourceDefinition(
        identity: '${kind == CableResourceKind.fiber ? 'FIBER' : 'COND'}-$i',
        kind: kind,
        allocatable: true,
        atomic: true,
        parentResourceId: '__WHOLE_CABLE__',
        terminationPolicy: _bothEnds(),
      ),
  ];
  return CableDefinition(
    code: code,
    label: code,
    mediaCode: kind == CableResourceKind.fiber ? 'FIBER' : 'COPPER',
    conductorCount: kind == CableResourceKind.conductor ? count : null,
    fiberCount: kind == CableResourceKind.fiber ? count : null,
    resourceDefinitions: [
      CableResourceDefinition(
        identity: '__WHOLE_CABLE__',
        kind: CableResourceKind.wholeCable,
        allocatable: true,
        atomic: false,
        childResourceIds: atoms.map((atom) => atom.identity),
        terminationPolicy: _bothEnds(),
      ),
      ...atoms,
    ],
  );
}

EngineeringReferenceCatalog _catalog() => EngineeringReferenceCatalog(
      id: _catalogId,
      code: 'ELV-P2',
      version: '2026.1',
      source: 'test',
      cableDefinitions: [
        _multiCore('CAT6', 8, CableResourceKind.conductor),
        _multiCore('ACS8', 8, CableResourceKind.conductor),
        _multiCore('FIRE2', 2, CableResourceKind.conductor),
        _multiCore('FIBER12', 12, CableResourceKind.fiber),
        _multiCore('ACS8-ALT', 8, CableResourceKind.conductor),
      ],
    );

Future<void> _seedBase(AppDatabase db) async {
  final now = DateTime.utc(2026, 10, 14, 8);
  await db.into(db.projects).insert(
        ProjectsCompanion.insert(
          id: _projectId,
          name: 'ELV3 P2',
          measurementSystem: 'metric',
          defaultStructuralHeightMm: 3000,
          defaultFinishedCeilingHeightMm: 2700,
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'test',
        ),
      );
  await db.into(db.floors).insert(
        FloorsCompanion.insert(
          id: 'floor-p2',
          projectId: _projectId,
          name: 'L1',
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'test',
        ),
      );
  await db.into(db.rooms).insert(
        RoomsCompanion.insert(
          id: 'room-p2',
          floorId: 'floor-p2',
          name: 'Room',
          roomType: 'TECHNICAL',
          roomCategory: 'DEFAULT',
          widthMm: 5000,
          depthMm: 5000,
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'test',
        ),
      );
  await db.into(db.surfacePatches).insert(
        SurfacePatchesCompanion.insert(
          id: 'patch-p2',
          roomId: 'room-p2',
          surfaceId: 'surface-p2',
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
  await db.into(db.engineeringFamilyDefinitions).insert(
        EngineeringFamilyDefinitionsCompanion.insert(
          id: 'family-p2',
          code: 'P2',
          familyVersion: '1',
          payloadJson: '{}',
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'test',
        ),
        mode: InsertMode.insertOrIgnore,
      );
  await db.into(db.projectEngineeringSystems).insert(
        ProjectEngineeringSystemsCompanion.insert(
          id: _systemId,
          projectId: _projectId,
          code: 'P2',
          familyId: 'family-p2',
          payloadJson: '{}',
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'test',
        ),
      );
  await db.into(db.engineeringCompatibilityProfiles).insert(
        EngineeringCompatibilityProfilesCompanion.insert(
          id: _profileId,
          projectId: _projectId,
          code: 'WIRED',
          profileVersion: '1',
          payloadJson: '{}',
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'test',
        ),
      );

  final catalog = _catalog();
  await db.into(db.engineeringReferenceCatalogs).insert(
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
}

Future<void> _seedConnection(AppDatabase db, String id) async {
  final now = DateTime.utc(2026, 10, 14, 8);
  for (final end in ['a', 'b']) {
    final componentId = 'component-$id-$end';
    final portId = 'port-$id-$end';
    await db.into(db.componentInstances).insert(
          ComponentInstancesCompanion.insert(
            id: componentId,
            definitionId: 'fixture',
            definitionVersion: 1,
            roomId: 'room-p2',
            hostSurfacePatchId: 'patch-p2',
            localXmm: end == 'a' ? 100 : 200,
            localYmm: 100,
            createdAt: now,
            updatedAt: now,
            originDeviceId: 'test',
          ),
        );
    await db.into(db.engineeringPortInstances).insert(
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
    id: id,
    systemId: _systemId,
    fromPortId: 'port-$id-a',
    toPortId: 'port-$id-b',
    profileId: _profileId,
    medium: ConnectionMedium.wired,
  );
  await db.into(db.engineeringPortConnections).insert(
        EngineeringPortConnectionsCompanion.insert(
          id: id,
          projectId: _projectId,
          systemId: _systemId,
          fromPortId: connection.fromPortId,
          toPortId: connection.toPortId,
          profileId: _profileId,
          payloadJson: canonicalEngineeringJsonV1(connection.toMap()),
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'test',
        ),
      );
}

Future<void> _seedCable(AppDatabase db, String id, String definitionCode) async {
  final now = DateTime.utc(2026, 10, 14, 8);
  final ref = _catalog().cableDefinitionRef(definitionCode);
  await db.into(db.elvCables).insert(
        ElvCablesCompanion.insert(
          id: id,
          projectId: _projectId,
          label: id.toUpperCase(),
          normalizedLabel: id.toUpperCase(),
          name: id,
          definitionCatalogId: ref.catalogId,
          definitionCatalogVersion: ref.catalogVersion,
          definitionCode: ref.definitionCode,
          definitionContentHash: ref.definitionContentHash,
          lifecycleState: 'ACTIVE',
          revision: const Value(1),
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'test',
        ),
      );
}

DefaultElvCableAllocationService _service(AppDatabase db) =>
    DefaultElvCableAllocationService(
      unitOfWork: DriftElvCableAllocationWriteUnitOfWork(
        db,
        originDeviceId: 'test',
      ),
      originDeviceId: 'test',
      now: () => DateTime.utc(2026, 10, 14, 8, 30),
    );

List<CableTerminationMapping> _terminations(
  String allocationId,
  String connectionId,
  CableResourceSelection selection,
) {
  final resources = switch (selection) {
    WholeCableSelection() => const ['__WHOLE_CABLE__'],
    ResourceSetSelection(:final resourceIdentities) => resourceIdentities,
    DefinitionGroupSelection() => throw UnsupportedError('group fixture'),
  };
  return [
    for (final resource in resources) ...[
      CableTerminationMapping(
        id: '$allocationId-$resource-A',
        allocationId: allocationId,
        resourceIdentity: resource,
        end: CableTerminationEnd.a,
        endpointPortId: 'port-$connectionId-a',
      ),
      CableTerminationMapping(
        id: '$allocationId-$resource-B',
        allocationId: allocationId,
        resourceIdentity: resource,
        end: CableTerminationEnd.b,
        endpointPortId: 'port-$connectionId-b',
      ),
    ],
  ];
}

Future<CableAllocation> _activateFixture(
  AppDatabase db, {
  required String allocationId,
  required String connectionId,
  required String cableId,
  required CableResourceSelection selection,
}) async {
  final service = _service(db);
  final draft = await service.createDraft(
    CreateCableAllocationDraftCommand(
      commandId: 'create-$allocationId',
      projectId: _projectId,
      allocationId: allocationId,
      engineeringConnectionId: connectionId,
      cableId: cableId,
    ),
  );
  expect(draft, isA<ElvCommandSuccess<CableAllocation>>());

  final reserved = await service.reserve(
    ReserveCableResourcesCommand(
      commandId: 'reserve-$allocationId',
      projectId: _projectId,
      allocationId: allocationId,
      expectedRevision: 1,
      selection: selection,
    ),
  );
  expect(reserved, isA<ElvCommandSuccess<CableAllocation>>());

  final terminated = await service.replaceTerminations(
    ReplaceCableTerminationSetCommand(
      commandId: 'terminate-$allocationId',
      projectId: _projectId,
      allocationId: allocationId,
      expectedRevision: 2,
      completeMappings: _terminations(allocationId, connectionId, selection),
    ),
  );
  expect(terminated, isA<ElvCommandSuccess<CableAllocation>>());

  final active = await service.activate(
    ActivateCableAllocationCommand(
      commandId: 'activate-$allocationId',
      projectId: _projectId,
      allocationId: allocationId,
      expectedRevision: 3,
    ),
  );
  expect(active, isA<ElvCommandSuccess<CableAllocation>>());
  return (active as ElvCommandSuccess<CableAllocation>).value;
}

Future<void> _seedScenarioGraph(AppDatabase db) async {
  await _seedBase(db);
  for (final connectionId in [
    'cctv',
    'lan',
    'acs-reader',
    'acs-contact',
    'acs-rex',
    'acs-lock',
    'fire',
    'fiber-a',
    'fiber-b',
  ]) {
    await _seedConnection(db, connectionId);
  }
  await _seedCable(db, 'cable-cctv', 'CAT6');
  await _seedCable(db, 'cable-lan', 'CAT6');
  await _seedCable(db, 'cable-acs', 'ACS8');
  await _seedCable(db, 'cable-fire', 'FIRE2');
  await _seedCable(db, 'cable-fiber', 'FIBER12');
}

void main() {
  test('CCTV LAN ACS Fire Fiber share one canonical P2 model', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await _seedScenarioGraph(db);

    await _activateFixture(
      db,
      allocationId: 'alloc-cctv',
      connectionId: 'cctv',
      cableId: 'cable-cctv',
      selection: const WholeCableSelection(),
    );
    await _activateFixture(
      db,
      allocationId: 'alloc-lan',
      connectionId: 'lan',
      cableId: 'cable-lan',
      selection: const WholeCableSelection(),
    );
    await _activateFixture(
      db,
      allocationId: 'alloc-acs-reader',
      connectionId: 'acs-reader',
      cableId: 'cable-acs',
      selection: ResourceSetSelection(const ['COND-1', 'COND-2']),
    );
    await _activateFixture(
      db,
      allocationId: 'alloc-acs-contact',
      connectionId: 'acs-contact',
      cableId: 'cable-acs',
      selection: ResourceSetSelection(const ['COND-3', 'COND-4']),
    );
    await _activateFixture(
      db,
      allocationId: 'alloc-acs-rex',
      connectionId: 'acs-rex',
      cableId: 'cable-acs',
      selection: ResourceSetSelection(const ['COND-5', 'COND-6']),
    );
    await _activateFixture(
      db,
      allocationId: 'alloc-acs-lock',
      connectionId: 'acs-lock',
      cableId: 'cable-acs',
      selection: ResourceSetSelection(const ['COND-7', 'COND-8']),
    );
    await _activateFixture(
      db,
      allocationId: 'alloc-fire',
      connectionId: 'fire',
      cableId: 'cable-fire',
      selection: const WholeCableSelection(),
    );
    await _activateFixture(
      db,
      allocationId: 'alloc-fiber-a',
      connectionId: 'fiber-a',
      cableId: 'cable-fiber',
      selection: ResourceSetSelection(const ['FIBER-1', 'FIBER-2']),
    );
    await _activateFixture(
      db,
      allocationId: 'alloc-fiber-b',
      connectionId: 'fiber-b',
      cableId: 'cable-fiber',
      selection: ResourceSetSelection(const ['FIBER-3', 'FIBER-4']),
    );

    final repo = DriftElvCableAllocationRepository(db);
    expect(await repo.loadCableAllocations(_projectId, 'cable-acs'), hasLength(4));
    expect(await repo.loadCableAllocations(_projectId, 'cable-fiber'), hasLength(2));
    final claims = await db.select(db.cableResourceClaims).get();
    expect(claims.where((row) => row.cableId == 'cable-acs'), hasLength(8));
    expect(claims.where((row) => row.cableId == 'cable-fiber'), hasLength(4));
  });

  test('whole cable claim blocks any atomic claim on same cable', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await _seedBase(db);
    await _seedConnection(db, 'conn-whole');
    await _seedConnection(db, 'conn-atom');
    await _seedCable(db, 'cable-shared', 'ACS8');
    final service = _service(db);

    await service.createDraft(
      const CreateCableAllocationDraftCommand(
        commandId: 'create-whole',
        projectId: _projectId,
        allocationId: 'alloc-whole',
        engineeringConnectionId: 'conn-whole',
        cableId: 'cable-shared',
      ),
    );
    expect(
      await service.reserve(
        const ReserveCableResourcesCommand(
          commandId: 'reserve-whole',
          projectId: _projectId,
          allocationId: 'alloc-whole',
          expectedRevision: 1,
          selection: WholeCableSelection(),
        ),
      ),
      isA<ElvCommandSuccess<CableAllocation>>(),
    );

    await service.createDraft(
      const CreateCableAllocationDraftCommand(
        commandId: 'create-atom',
        projectId: _projectId,
        allocationId: 'alloc-atom',
        engineeringConnectionId: 'conn-atom',
        cableId: 'cable-shared',
      ),
    );
    final overlap = await service.reserve(
      ReserveCableResourcesCommand(
        commandId: 'reserve-atom',
        projectId: _projectId,
        allocationId: 'alloc-atom',
        expectedRevision: 1,
        selection: ResourceSetSelection(const ['COND-1']),
      ),
    );
    expect(overlap, isA<ElvCommandFailureResult<CableAllocation>>());
    expect(
      (overlap as ElvCommandFailureResult<CableAllocation>).failure.code,
      'ELV_ALLOC_RESOURCE_OVERLAP',
    );
    expect(
      await (db.select(db.cableAllocationResourceSelections)
            ..where((row) => row.allocationId.equals('alloc-atom')))
          .getSingleOrNull(),
      isNull,
    );
  });

  test('P2 resource history blocks P1 in-place definition change', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await _seedBase(db);
    await _seedConnection(db, 'conn-p1-block');
    await _seedCable(db, 'cable-p1-block', 'ACS8');
    final p2 = _service(db);
    await p2.createDraft(
      const CreateCableAllocationDraftCommand(
        commandId: 'create-p1-block',
        projectId: _projectId,
        allocationId: 'alloc-p1-block',
        engineeringConnectionId: 'conn-p1-block',
        cableId: 'cable-p1-block',
      ),
    );
    await p2.reserve(
      ReserveCableResourcesCommand(
        commandId: 'reserve-p1-block',
        projectId: _projectId,
        allocationId: 'alloc-p1-block',
        expectedRevision: 1,
        selection: ResourceSetSelection(const ['COND-1', 'COND-2']),
      ),
    );

    final p1 = DefaultElvCableCommandService(
      unitOfWork: DriftElvCableWriteUnitOfWork(db, originDeviceId: 'test'),
      originDeviceId: 'test',
    );
    final changed = await p1.changeDefinition(
      ChangeCableDefinitionRefCommand(
        commandId: 'change-after-p2',
        projectId: _projectId,
        cableId: 'cable-p1-block',
        expectedRevision: 1,
        definitionRef: _catalog().cableDefinitionRef('ACS8-ALT'),
      ),
    );
    expect(changed, isA<ElvCommandFailureResult<Cable>>());
    expect(
      (changed as ElvCommandFailureResult<Cable>).failure.code,
      'ELV_CABLE_DEFINITION_CHANGE_BLOCKED',
    );
  });

  test('P2 allocation, evidence, claims, terminations and replay survive restart', () async {
    final dir = await Directory.systemTemp.createTemp('electra-elv3-p2-restart-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/p2.sqlite');

    var db = AppDatabase(NativeDatabase(file));
    await _seedBase(db);
    await _seedConnection(db, 'restart');
    await _seedCable(db, 'cable-restart', 'ACS8');
    await _activateFixture(
      db,
      allocationId: 'alloc-restart',
      connectionId: 'restart',
      cableId: 'cable-restart',
      selection: ResourceSetSelection(const ['COND-1', 'COND-2']),
    );
    await db.close();

    db = AppDatabase(NativeDatabase(file));
    final repo = DriftElvCableAllocationRepository(db);
    final restored = await repo.findAllocation(_projectId, 'alloc-restart');
    expect(restored, isNotNull);
    expect(restored!.state, CableAllocationState.active);
    expect(restored.revision, 4);
    expect((await repo.loadSelectionEvidence(_projectId, 'alloc-restart'))!.resolvedAtoms,
        ['COND-1', 'COND-2']);
    expect(
      await repo.loadTerminationMappings(_projectId, 'alloc-restart'),
      hasLength(4),
    );

    final replay = await _service(db).activate(
      const ActivateCableAllocationCommand(
        commandId: 'activate-alloc-restart',
        projectId: _projectId,
        allocationId: 'alloc-restart',
        expectedRevision: 3,
      ),
    );
    expect(replay, isA<ElvCommandSuccess<CableAllocation>>());
    expect((replay as ElvCommandSuccess<CableAllocation>).value.revision, 4);
    await db.close();
  });
}
