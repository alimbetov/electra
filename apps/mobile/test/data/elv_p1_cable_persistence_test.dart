import 'dart:io';

import 'package:drift/native.dart';
import 'package:electra_mobile/application/elv_cable_command.dart';
import 'package:electra_mobile/application/elv_cable_command_service.dart';
import 'package:electra_mobile/application/elv_command_result.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/drift_elv_cable_repository.dart';
import 'package:electra_mobile/data/repositories/drift_elv_cable_write_unit_of_work.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter_test/flutter_test.dart';

TerminationPolicy _bothEnds() => TerminationPolicy(
  mode: TerminationPolicyMode.bothEnds,
  terminalRequired: true,
);

CableDefinition _definition() => CableDefinition(
  code: 'CAT6-UUTP',
  label: 'Cat6 U/UTP',
  mediaCode: 'COPPER_BALANCED',
  categoryCode: 'CAT6',
  outerDiameterMm: 6.2,
  resourceDefinitions: [
    CableResourceDefinition(
      identity: '__WHOLE_CABLE__',
      kind: CableResourceKind.wholeCable,
      allocatable: true,
      atomic: false,
      childResourceIds: const ['COND-1', 'COND-2'],
      terminationPolicy: _bothEnds(),
    ),
    CableResourceDefinition(
      identity: 'COND-1',
      kind: CableResourceKind.conductor,
      allocatable: true,
      atomic: true,
      parentResourceId: '__WHOLE_CABLE__',
      terminationPolicy: _bothEnds(),
    ),
    CableResourceDefinition(
      identity: 'COND-2',
      kind: CableResourceKind.conductor,
      allocatable: true,
      atomic: true,
      parentResourceId: '__WHOLE_CABLE__',
      terminationPolicy: _bothEnds(),
    ),
  ],
);

EngineeringReferenceCatalog _catalog() => EngineeringReferenceCatalog(
  id: 'catalog-cables',
  code: 'ELV-CABLES',
  version: '2026.1',
  source: 'test',
  cableDefinitions: [_definition()],
);

Future<void> _seed(AppDatabase db) async {
  final now = DateTime.utc(2026, 10, 14, 6);
  await db
      .into(db.projects)
      .insert(
        ProjectsCompanion.insert(
          id: 'project-1',
          name: 'ELV3 P1',
          measurementSystem: 'metric',
          defaultStructuralHeightMm: 3000,
          defaultFinishedCeilingHeightMm: 2700,
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'test',
        ),
      );
  final catalog = _catalog();
  await db
      .into(db.engineeringReferenceCatalogs)
      .insert(
        EngineeringReferenceCatalogsCompanion.insert(
          id: catalog.id,
          projectId: 'project-1',
          code: catalog.code,
          catalogVersion: catalog.version,
          payloadJson: canonicalEngineeringJsonV1(catalog.toMap()),
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'test',
        ),
      );
}

DefaultElvCableCommandService _service(AppDatabase db) =>
    DefaultElvCableCommandService(
      unitOfWork: DriftElvCableWriteUnitOfWork(db, originDeviceId: 'test'),
      originDeviceId: 'test',
      now: () => DateTime.utc(2026, 10, 14, 6, 30),
    );

CreateCableCommand _create({
  String commandId = 'cmd-create-1',
  String cableId = 'cable-1',
  String label = 'C-01',
}) {
  final catalog = _catalog();
  return CreateCableCommand(
    commandId: commandId,
    projectId: 'project-1',
    cableId: cableId,
    label: label,
    name: 'Horizontal cable',
    definitionRef: catalog.cableDefinitionRef('CAT6-UUTP'),
  );
}

void main() {
  test(
    'P1 create persists exact definition reference and replays idempotently',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _seed(db);

      final service = _service(db);
      final first = await service.create(_create());
      expect(first, isA<ElvCommandSuccess<Cable>>());

      final replay = await service.create(_create());
      expect(replay, isA<ElvCommandSuccess<Cable>>());

      final cables = await DriftElvCableRepository(db)
          .loadProjectCables('project-1');
      expect(cables, hasLength(1));
      expect(cables.single.definitionRef.definitionCode, 'CAT6-UUTP');
      expect(cables.single.definitionRef.definitionContentHash, hasLength(64));

      final ledgerRows = await db.select(db.commandExecutionRecords).get();
      expect(ledgerRows, hasLength(1));
      expect(ledgerRows.single.outcomeKind, 'SUCCESS');
    },
  );

  test(
    'same commandId with changed payload is rejected as idempotency conflict',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _seed(db);
      final service = _service(db);

      expect(await service.create(_create()), isA<ElvCommandSuccess<Cable>>());
      final changed = await service.create(_create(label: 'C-02'));
      expect(changed, isA<ElvCommandFailureResult<Cable>>());
      expect(
        (changed as ElvCommandFailureResult<Cable>).failure.code,
        'ELV_IDEMPOTENCY_CONFLICT',
      );
    },
  );

  test(
    'active normalized label is unique while archived label can be reused',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _seed(db);
      final service = _service(db);

      final created = await service.create(_create());
      expect(created, isA<ElvCommandSuccess<Cable>>());

      final duplicate = await service.create(
        _create(commandId: 'cmd-create-2', cableId: 'cable-2', label: ' c-01 '),
      );
      expect(
        (duplicate as ElvCommandFailureResult<Cable>).failure.code,
        'ELV_CABLE_LABEL_CONFLICT',
      );

      final archived = await service.archive(
        const ArchiveCableCommand(
          commandId: 'cmd-archive-1',
          projectId: 'project-1',
          cableId: 'cable-1',
          expectedRevision: 1,
        ),
      );
      expect(archived, isA<ElvCommandSuccess<Cable>>());

      final reused = await service.create(
        _create(commandId: 'cmd-create-3', cableId: 'cable-3', label: 'C-01'),
      );
      expect(reused, isA<ElvCommandSuccess<Cable>>());
    },
  );

  test('P1 state and command outcome survive database reopen', () async {
    final dir = await Directory.systemTemp.createTemp('electra-elv3-p1-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/p1.sqlite');

    var db = AppDatabase(NativeDatabase(file));
    await _seed(db);
    expect(
      await _service(db).create(_create()),
      isA<ElvCommandSuccess<Cable>>(),
    );
    await db.close();

    db = AppDatabase(NativeDatabase(file));
    final repo = DriftElvCableRepository(db);
    final restored = await repo.findCable('project-1', 'cable-1');
    expect(restored, isNotNull);
    expect(restored!.revision, 1);
    expect(restored.definitionRef.definitionCode, 'CAT6-UUTP');

    final replay = await _service(db).create(_create());
    expect(replay, isA<ElvCommandSuccess<Cable>>());
    expect(await repo.loadProjectCables('project-1'), hasLength(1));
    await db.close();
  });
}
