import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:electra_mobile/application/engineering_placement_command.dart';
import 'package:electra_mobile/application/engineering_placement_repository.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/drift_engineering_placement_repository.dart';
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
    );
    await _seedPlacementParents(database);
  });

  tearDown(() => database.close());

  test('schema 17 exposes mandatory placement operation ledger', () async {
    expect(database.schemaVersion, 17);

    final rows = await database.customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'engineering_placement_operations'",
    ).get();
    expect(rows, hasLength(1));

    final columns = await database.customSelect(
      'PRAGMA table_info(engineering_placement_operations)',
    ).get();
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

  test('P4.2 absent-operation path performs zero durable mutation', () async {
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
            .having(
              (failure) => failure.details['phase'],
              'phase',
              'P4.2',
            ),
      ),
    );

    expect(
      await database.select(database.engineeringPlacementOperations).get(),
      isEmpty,
    );
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
    expect(restored.commandFingerprint, engineeringPlacementFingerprintV1(command));
    expect(restored.result.portIds, result.portIds);
  });
}

Future<void> _seedPlacementParents(AppDatabase database) async {
  final now = DateTime.utc(2026, 10, 13, 19);
  await database.into(database.projects).insert(
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
  await database.into(database.floors).insert(
    FloorsCompanion.insert(
      id: 'floor-1',
      projectId: 'project-1',
      name: 'Floor 1',
      createdAt: now,
      updatedAt: now,
      originDeviceId: 'p4-test-device',
    ),
  );
  await database.into(database.rooms).insert(
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
  await database.into(database.surfacePatches).insert(
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
      boundaryJson: '[]',
      createdAt: now,
      updatedAt: now,
      originDeviceId: 'p4-test-device',
    ),
  );
  await database.into(database.componentInstances).insert(
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
  await database.into(database.engineeringPlacementOperations).insert(
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
  Point2Mm localPosition = const Point2Mm(120, 80),
}) => PlaceEngineeringProfileCommand(
  operationId: operationId,
  projectId: 'project-1',
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
    projectId: 'project-1',
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
  displayNameOverride: 'Camera A',
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
