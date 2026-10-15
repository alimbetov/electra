import '../support/engineering_placement_fixture.dart';

import 'package:electra_mobile/data/repositories/drift_engineering_placement_aggregate.dart';
import 'package:drift/native.dart';
import 'package:electra_mobile/application/engineering_placement_command.dart';
import 'package:electra_mobile/application/engineering_placement_repository.dart';
import 'package:electra_mobile/application/id_generator.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/drift_engineering_placement_membership_writer.dart';
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
    await seedPlacementParents(database);
    await seedPlacementSystemAndCatalog(database);
  });

  tearDown(() => database.close());

  test('current schema exposes mandatory placement operation ledger', () async {
    expect(database.schemaVersion, 21);

    final rows = await database
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'engineering_placement_operations'",
        )
        .get();
    expect(rows, hasLength(1));

    final columns = await database
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
    final command = placementCommand();
    final expected = placementResult();
    await seedPlacementOperation(
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
    final original = placementCommand();
    await seedPlacementOperation(
      database,
      command: original,
      result: placementResult(),
      status: 'COMPLETED',
    );

    final changed = placementCommand(localPosition: const Point2Mm(999, 80));

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
    final command = placementCommand();
    await seedPlacementOperation(
      database,
      command: command,
      result: placementResult(),
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

  test('P4.4 place inserts component and membership inside one transaction then rolls back', () async {
    final command = placementCommand(operationId: 'op-new');
    repository = DriftEngineeringPlacementRepository(
      database,
      originDeviceId: 'p4-test-device',
      idGenerator: FixedSequenceIdGenerator(['component-p4-3']),
      fault: (point, _) {
        if (point == EngineeringPlacementFailurePoint.afterMembership)
          throw EngineeringPlacementFailure(
            code: EngineeringPlacementFailureCode.transactionFailed,
            message: 'Injected after membership',
            details: {'phase': 'P4.4', 'componentId': 'component-p4-3'},
          );
      },
    );

    await expectLater(
      repository.place(command),
      throwsA(
        isA<EngineeringPlacementFailure>()
            .having(
              (failure) => failure.code,
              'code',
              EngineeringPlacementFailureCode.transactionFailed,
            )
            .having((failure) => failure.details['phase'], 'phase', 'P4.4')
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
    expect(
      await database.select(database.componentEngineeringMemberships).get(),
      isEmpty,
    );
  });

  test('findOperation reconstructs immutable durable record', () async {
    final command = placementCommand();
    final result = placementResult();
    await seedPlacementOperation(
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

  test(
    'canonical ELV definition is frozen as one system physical identity',
    () {
      expect(
        canonicalElvComponentDefinition.id,
        canonicalElvComponentDefinitionId,
      );
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
      expect(
        canonicalElvComponentDefinition.primaryDiscipline,
        Discipline.lowVoltage,
      );
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
    },
  );

  test(
    'P4.3 writer persists exact component identity geometry and audit',
    () async {
      final writer = DriftEngineeringPlacementComponentWriter(
        database,
        originDeviceId: 'writer-device',
        idGenerator: FixedSequenceIdGenerator(['component-new']),
        clock: () => DateTime.utc(2026, 10, 13, 20, 45, 30),
      );

      final instance = await database.transaction(
        () => writer.insertCanonicalComponent(
          placementCommand(displayNameOverride: '  Camera A  '),
        ),
      );

      expect(instance.id, 'component-new');
      expect(instance.definitionId, canonicalElvComponentDefinitionId);
      expect(
        instance.definitionVersion,
        canonicalElvComponentDefinitionVersion,
      );
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
      expect(
        row.createdAt.isAtSameMomentAs(DateTime.utc(2026, 10, 13, 20, 45, 30)),
        isTrue,
      );
      expect(row.updatedAt.isAtSameMomentAs(row.createdAt), isTrue);
      expect(row.deletedAt, isNull);
      expect(row.originDeviceId, 'writer-device');
    },
  );

  test(
    'P4.3 writer rejects room outside requested project before insert',
    () async {
      final now = DateTime.utc(2026, 10, 13, 20);
      await database
          .into(database.projects)
          .insert(
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
          () => writer.insertCanonicalComponent(
            placementCommand(projectId: 'project-2'),
          ),
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
        await (database.select(
          database.componentInstances,
        )..where((row) => row.id.equals('must-not-be-used'))).get(),
        isEmpty,
      );
    },
  );

  test('P4.3 writer rejects generated component identity collision', () async {
    final writer = DriftEngineeringPlacementComponentWriter(
      database,
      originDeviceId: 'writer-device',
      idGenerator: FixedSequenceIdGenerator(['component-1']),
    );

    await expectLater(
      database.transaction(
        () => writer.insertCanonicalComponent(placementCommand()),
      ),
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

  test(
    'P4.3 writer rejects placement outside persisted surface geometry',
    () async {
      final writer = DriftEngineeringPlacementComponentWriter(
        database,
        originDeviceId: 'writer-device',
        idGenerator: FixedSequenceIdGenerator(['component-outside']),
      );

      await expectLater(
        database.transaction(
          () => writer.insertCanonicalComponent(
            placementCommand(localPosition: const Point2Mm(7000, 80)),
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
        await (database.select(
          database.componentInstances,
        )..where((row) => row.id.equals('component-outside'))).get(),
        isEmpty,
      );
    },
  );

  test(
    'P4.4 writer persists exact DEVICE membership identity and audit',
    () async {
      final writer = DriftEngineeringPlacementMembershipWriter(
        database,
        originDeviceId: 'membership-device',
        clock: () => DateTime.utc(2026, 10, 13, 21, 10, 15),
      );

      final membership = await database.transaction(
        () => writer.insertCanonicalMembership(
          placementCommand(),
          componentId: 'component-1',
        ),
      );

      expect(membership.systemId, 'system-1');
      expect(membership.componentId, 'component-1');
      expect(membership.role, canonicalElvMembershipRole);
      final row = await database
          .select(database.componentEngineeringMemberships)
          .getSingle();
      expect(row.systemId, 'system-1');
      expect(row.componentId, 'component-1');
      expect(row.role, canonicalElvMembershipRole);
      expect(row.revision, 1);
      expect(
        row.createdAt.isAtSameMomentAs(DateTime.utc(2026, 10, 13, 21, 10, 15)),
        isTrue,
      );
      expect(row.updatedAt.isAtSameMomentAs(row.createdAt), isTrue);
      expect(row.deletedAt, isNull);
      expect(row.originDeviceId, 'membership-device');
    },
  );

  test('P4.4 writer rejects profile and system discipline mismatch', () async {
    await seedEngineeringSystem(
      database,
      id: 'system-lan',
      code: 'LAN-01',
      familyCode: 'LAN',
    );
    final writer = DriftEngineeringPlacementMembershipWriter(
      database,
      originDeviceId: 'membership-device',
    );

    await expectLater(
      database.transaction(
        () => writer.insertCanonicalMembership(
          placementCommand(systemId: 'system-lan'),
          componentId: 'component-1',
        ),
      ),
      throwsA(
        isA<EngineeringPlacementFailure>().having(
          (failure) => failure.code,
          'code',
          EngineeringPlacementFailureCode.systemDisciplineMismatch,
        ),
      ),
    );
    expect(
      await database.select(database.componentEngineeringMemberships).get(),
      isEmpty,
    );
  });

  test(
    'P4.4 writer rejects existing membership identity without repair',
    () async {
      final writer = DriftEngineeringPlacementMembershipWriter(
        database,
        originDeviceId: 'membership-device',
        clock: () => DateTime.utc(2026, 10, 13, 21, 20),
      );
      await database.transaction(
        () => writer.insertCanonicalMembership(
          placementCommand(),
          componentId: 'component-1',
        ),
      );

      await expectLater(
        database.transaction(
          () => writer.insertCanonicalMembership(
            placementCommand(),
            componentId: 'component-1',
          ),
        ),
        throwsA(
          isA<EngineeringPlacementFailure>().having(
            (failure) => failure.code,
            'code',
            EngineeringPlacementFailureCode.membershipConflict,
          ),
        ),
      );
      final rows = await database
          .select(database.componentEngineeringMemberships)
          .get();
      expect(rows, hasLength(1));
      expect(rows.single.revision, 1);
      expect(rows.single.role, canonicalElvMembershipRole);
    },
  );
}
