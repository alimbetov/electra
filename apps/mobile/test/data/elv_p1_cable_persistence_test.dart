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
  family: CableFamily.data,
  conductorKind: CableConductorKind.copper,
  resourceDefinition: const CableResourceDefinition(
    kind: CableResourceDefinitionKind.pairs,
    resourceCount: 4,
  ),
  terminationPolicy: _bothEnds(),
);

void main() {
  test('P1 cable persistence survives SQLite reopen', () async {
    final directory = await Directory.systemTemp.createTemp('electra-elv-p1-');
    final databaseFile = File('${directory.path}/electra.sqlite');

    try {
      var database = AppDatabase.forTesting(NativeDatabase(databaseFile));
      var repository = DriftElvCableRepository(database);
      var service = DefaultElvCableCommandService(
        unitOfWork: DriftElvCableWriteUnitOfWork(database),
      );

      final createResult = await service.createDraft(
        CreateCableDraftCommand(
          commandId: 'cmd-create-cable-01',
          projectId: 'project-01',
          cableId: 'cable-01',
          designRevisionId: 'design-revision-01',
          definition: _definition(),
          originDeviceId: 'device-01',
          now: DateTime.utc(2026, 10, 14, 10),
        ),
      );

      expect(createResult.status, ElvCommandStatus.applied);
      expect(createResult.value, isNotNull);
      expect(createResult.value!.revision, 1);

      await database.close();

      database = AppDatabase.forTesting(NativeDatabase(databaseFile));
      repository = DriftElvCableRepository(database);

      final restored = await repository.findCable('project-01', 'cable-01');
      expect(restored, isNotNull);
      expect(restored!.id, 'cable-01');
      expect(restored.projectId, 'project-01');
      expect(restored.designRevisionId, 'design-revision-01');
      expect(restored.definition.code, 'CAT6-UUTP');
      expect(restored.definition.resourceDefinition.resourceCount, 4);
      expect(restored.revision, 1);
      expect(restored.originDeviceId, 'device-01');

      await database.close();
    } finally {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    }
  });
}
