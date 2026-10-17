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

TerminationPolicy _policy() => TerminationPolicy(
  mode: TerminationPolicyMode.bothEnds,
  terminalRequired: true,
);

EngineeringReferenceCatalog _catalog() {
  final definition = CableDefinition(
    code: 'CABLE',
    label: 'Cable',
    mediaCode: 'COPPER',
    resourceDefinitions: [
      CableResourceDefinition(
        identity: '__WHOLE_CABLE__',
        kind: CableResourceKind.wholeCable,
        allocatable: true,
        atomic: false,
        childResourceIds: const ['COND-1'],
        terminationPolicy: _policy(),
      ),
      CableResourceDefinition(
        identity: 'COND-1',
        kind: CableResourceKind.conductor,
        allocatable: true,
        atomic: true,
        parentResourceId: '__WHOLE_CABLE__',
        terminationPolicy: _policy(),
      ),
    ],
  );
  return EngineeringReferenceCatalog(
    id: 'catalog',
    code: 'ELV-CABLE',
    version: '1',
    source: 'test',
    cableDefinitions: [definition],
  );
}

Future<void> _seed(AppDatabase db) async {
  final now = DateTime.utc(2026, 10, 14);
  await db
      .into(db.projects)
      .insert(
        ProjectsCompanion.insert(
          id: 'project',
          name: 'Project',
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
          projectId: 'project',
          code: catalog.code,
          catalogVersion: catalog.version,
          payloadJson: canonicalEngineeringJsonV1(catalog.toMap()),
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'test',
        ),
      );
}

DefaultElvCableCommandService _service(AppDatabase db, String device) =>
    DefaultElvCableCommandService(
      unitOfWork: DriftElvCableWriteUnitOfWork(db, originDeviceId: device),
      originDeviceId: device,
      now: () => DateTime.utc(2026, 10, 14, 7),
    );

CreateCableCommand _command(String commandId, String cableId) {
  final catalog = _catalog();
  return CreateCableCommand(
    commandId: commandId,
    projectId: 'project',
    cableId: cableId,
    label: ' C-01 ',
    name: cableId,
    definitionRef: catalog.cableDefinitionRef('CABLE'),
  );
}

void main() {
  test(
    'two SQLite connections cannot commit same active normalized label',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'electra-elv3-p1-race-',
      );
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/race.sqlite');

      final seed = AppDatabase(NativeDatabase(file));
      await _seed(seed);
      await seed.close();

      // Keep the DB-level race real while tolerating a loaded shared CI runner.
      final a = AppDatabase(NativeDatabase.createInBackground(file));
      final b = AppDatabase(NativeDatabase.createInBackground(file));
      await a.customStatement('PRAGMA busy_timeout = 30000');
      await b.customStatement('PRAGMA busy_timeout = 30000');

      final results = await Future.wait([
        _service(a, 'A').create(_command('cmd-a', 'cable-a')),
        _service(b, 'B').create(_command('cmd-b', 'cable-b')),
      ]);

      expect(results.whereType<ElvCommandSuccess<Cable>>(), hasLength(1));
      expect(results.whereType<ElvCommandFailureResult<Cable>>(), hasLength(1));
      expect(
        results.whereType<ElvCommandFailureResult<Cable>>().single.failure.code,
        'ELV_CABLE_LABEL_CONFLICT',
      );

      await a.close();
      await b.close();

      final verify = AppDatabase(NativeDatabase(file));
      final cables = await DriftElvCableRepository(verify)
          .loadProjectCables('project');
      expect(
        cables.where(
          (cable) => cable.lifecycleState == CableLifecycleState.active,
        ),
        hasLength(1),
      );
      await verify.close();
    },
  );
}
