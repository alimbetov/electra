import 'package:drift/native.dart';
import 'package:electra_mobile/application/engineering_placement_command.dart';
import 'package:electra_mobile/application/engineering_placement_repository.dart';
import 'package:electra_mobile/application/id_generator.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/drift_engineering_placement_repository.dart';
import 'package:electra_mobile/domain/system_component_catalog.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late DriftEngineeringPlacementRepository repository;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftEngineeringPlacementRepository(
      database,
      originDeviceId: 'p4-test-device',
      idGenerator: FixedSequenceIdGenerator(['component-p4-3']),
      clock: () => DateTime.utc(2026, 10, 13, 20, 30),
    );
    await _seedPlacementParents(database);
  });

  tearDown(() => database.close());

  test('schema 17 exposes mandatory placement operation ledger', () async {
    expect(database.schemaVersion, 17);

    final rows =
        await database
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'engineering_placement_operations'",
            )
            .get();
    expect(rows, hasLength(1));

    final columns =
        await database
            .customSelect('PRAGMA table_info(engineering_placement_operations)')
            .get();
    expect(
      columns.map((row) => row.read<String>('name')).toList(),
      containsAll(<String>[
        'operation_id',
        'project_id',
        'fingerprint_version',
        'command_fingerprint',
        'status',
        'component_id',
        'result_json',
        'created_at',
        'updated_at',
        'origin_device_id',
      ]),
    );
  });

  test('completed same-fingerprint retry returns stored result', () async {
    final command = _command();
    final expected = _result();
    await _seedOperation(
      database,
      command: command,
      result: expected,
      status: 'COMPLETED',
    );

    final replayed = await repository.place(command);

    expect(replayed.operationId, expected.operationId);
    expect(replayed.componentId, expected.componentId);
    expect(replayed.portIds, expected.portIds);
    expect(replayed.committedAt, expected.committedAt);
    expect(
      await database.select(database.engineeringPlacementOperations).get(),
      hasLength(1),
    );
  });

  test('same operation id with changed semantics is rejected', () async {
    final original = _command();
    await _seedOperation(
      database,
      command: original,
      result: _result(),
      status: 'COMPLETED',
    );

    final changed = _command(localPosition: const Point2Mm(999, 80));

    await expectLater(
      repository.place(changed),
      throwsA(
        isA<EngineeringPlacementFailure>().having(
          (failure) => failure.code,
          'code',
          EngineeringPlacementFailureCode.idempotencyConflict,
        ),
      ),
    );
  });

  test('normal retry of UNDONE operation is rejected', () async {
    final command = _command();
    await _seedOperation(
      database,
      command: command,
      result: _result(),
      status: 'UNDONE',
    );

    await expectLater(
      repository.place(command),
      throwsA(
        isA<EngineeringPlacementFailure>().having(
          (failure) => failure.code,
          'code',
          EngineeringPlacementFailureCode.operationUndone,
        ),
      ),
    );
  });

  test('P4.3 place inserts component only inside transaction then rolls back', () async {
    final command = _command(operationId: 'op-new');

    await expectLater(
      repository.place(command),
      throwsA(
        isA<EngineeringPlacementFailure>()
            .having(
              (failure) => failure.code,
              'code',
              EngineeringPlacementFailureCode.transactionFailed,
            )
            .having((failure) => failure.details['phase'], 'phase', 'P4.3')
            .having(
              (failure) => failure.details['componentId'],
              'componentId',
              'component-p4-3',
            ),
      ),
    );

    expect(
      await database.select(database.engineeringPlacementOperations).get(),
      isEmpty,
    );
    final components = await database.select(database.componentInstances).get();
    expect(components.map((row) => row.id), ['component-1']);
  });

  test('findOperation reconstructs immutable durable record', () async {
    final command = _command();
    final result = _result();
    await _seedOperation(
      database,
      command: command,
      result: result,
      status: 'COMPLETED',
    );

    final restored = await repository.findOperation(command.operationId);

    expect(restored, isNotNull);
    expect(restored!.status, EngineeringPlacementOperationStatus.completed);
    expect(restored.fingerprintVersion, engineeringPlacementFingerprintVersion);
    expect(
      restored.commandFingerprint,
      engineeringPlacementFingerprintV1(command),
    );
    expect(restored.result.portIds, result.portIds);
  });

  test('canonical ELV definition is frozen as one system physical identity', () {
    expect(canonicalElvComponentDefinition.id, canonicalElvComponentDefinitionId);
    expect(
      canonicalElvComponentDefinition.code,
      canonicalElvComponentDefinitionCode,
    );
    expect(
      canonicalElvComponentDefinition.version,
      canonicalElvComponentDefinitionVersion,
    );
    expect(
      canonicalElvComponentDefinition.source,
      ComponentDefinitionSource.system,
    );
    expect(canonicalElvComponentDefinition.primaryDiscipline, Discipline.lowVoltage);
    expect(
      canonicalElvComponentDefinition.compatibleDisciplines,
      containsAll(<Discipline>[
        Discipline.cctv,
        Discipline.fireAlarm,
        Discipline.security,
        Discipline.accessControl,
      ]),
    );
    expect(canonicalElvComponentDefinition.ports, isEmpty);
  });

  test('P4.3 writer persists exact component identity geometry and audit', () async {
    final writer = DriftEngineeringPlacementComponentWriter(
      database,
      originDeviceId: 'writer-device',
      idGenerator: FixedSequenceIdGenerator(['component-new']),
      clock: () => DateTime.utc(2026, 10, 13, 20, 45, 30),
    );

    final instance = await database.transaction(
      () => writer.insertCanonicalComponent(
        _command(displayNameOverride: '  Camera A  '),
      ),
    );

    expect(instance.id, 'component-new');
    expect(instance.definitionId, canonicalElvComponentDefinitionId);
    expect(instance.definitionVersion, canonicalElvComponentDefinitionVersion);
    expect(instance.displayNameOverride, 'Camera A');

    final row =
        await (database.select(database.componentInstances)
              ..where((candidate) => candidate.id.equals('component-new')))
            .getSingle();
    expect(row.definitionId, canonicalElvComponentDefinitionId);
    expect(row.definitionVersion, canonicalElvComponentDefinitionVersion);
    expect(row.roomId, 'room-1');
    expect(row.hostSurfacePatchId, 'patch-1');
    expect(row.localXmm, 120);
    expect(row.localYmm, 80);
    expect(row.rotationRadians, 0.25);
    expect(row.displayNameOverride, 'Camera A');
    expect(row.metadataOverridesJson, '{}');
    expect(row.revision, 1);
    expect(row.createdAt, DateTime.utc(2026, 10, 13, 20, 45, 30));
    expect(row.updatedAt, row.createdAt);
    expect(row.deletedAt, isNull);
    expect(row.originDeviceId, 'writer-device');
  });

  test('P4.3 writer rejects room outside requested project before insert', () async {
    final now = DateTime.utc(2026, 10, 13, 20);
    await database.into(database.projects).insert(
      ProjectsCompanion.insert(
        id: 'project-2',
        name: 'Other project',
        measurementSystem: 'metric',
        defaultStructuralHeightMm: 3200,
        defaultFinishedCeilingHeightMm: 3000,
        createdAt: now,
        updatedAt: now,
        originDeviceId: 'p4-test-device',
      ),
    );
    final writer = DriftEngineeringPlacementComponentWriter(
      database,
      originDeviceId: 'writer-device',
      idGenerator: FixedSequenceIdGenerator(['must-not-be-used']),
    );

    await expectLater(
      database.transaction(
        () => writer.insertCanonicalComponent(_command(projectId: 'project-2')),
      ),
      throwsA(
        isA<EngineeringPlacementFailure>().having(
          (failure) => failure.code,
          'code',
          EngineeringPlacementFailureCode.roomNotFound,
        ),
      ),
    );
    expect(
      await (database.select(database.componentInstances)..where(
        (row) => row.id.equals('must-not-be-used'),
      )).get(),
      isEmpty,
    );
  });

  test('P4.3 writer rejects generated component identity collision', () async {
    final writer = DriftEngineeringPlacementComponentWriter(
      database,
      originDeviceId: 'writer-device',
      idGenerator: FixedSequenceIdGenerator(['component-1']),
    );

    await expectLater(
      database.transaction(() => writer.insertCanonicalComponent(_command())),
      throwsA(
        isA<EngineeringPlacementFailure>().having(
          (failure) => failure.code,
          'code',
          EngineeringPlacementFailureCode.componentConflict,
        ),
      ),
    );
    expect(
      await database.select(database.componentInstances).get(),
      hasLength(1),
    );
  });

  test('P4.3 writer rejects placement outside persisted surface geometry', () async {
    final writer = DriftEngineeringPlacementComponentWriter(
      database,
      originDeviceId: 'writer-device',
      idGenerator: FixedSequenceIdGenerator(['component-outside']),
    );

    await expectLater(
      database.transaction(
        () => writer.insertCanonicalComponent(
          _command(localPosition: const Point2Mm(7000, 80)),
        ),
      ),
      throwsA(
        isA<EngineeringPlacementFailure>().having(
          (failure) => failure.code,
          'code',
          EngineeringPlacementFailureCode.placementForbidden,
        ),
      ),
    );
    expect(
      await (database.select(database.componentInstances)..where(
        (row) => row.id.equals('component-outside'),
      )).get(),
      isEmpty,
    );
  });
}

Future<void> _seedPlacementParents(AppDatabase database) async {
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

Future<void> _seedOperation(
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

PlaceEngineeringProfileCommand _command({
  String operationId = 'op-1',
  String projectId = 'project-1',
  Point2Mm localPosition = const Point2Mm(120, 80),
  String? displayNameOverride = 'Camera A',
}) => PlaceEngineeringProfileCommand(
  operationId: operationId,
  projectId: projectId,
  roomId: 'room-1',
  systemId: 'system-1',
  membershipRole: canonicalElvMembershipRole,
  catalogId: 'catalog-1',
  catalogVersion: '1.0.0',
  profileCode: 'CAMERA',
  hostSurfacePatchId: 'patch-1',
  localPosition: localPosition,
  rotationRadians: 0.25,
  placementContext: PlacementCandidateContext(
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

EngineeringPlacementResult _result() => EngineeringPlacementResult(
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
