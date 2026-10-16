import 'package:drift/native.dart';
import 'package:electra_mobile/application/engineering_topology_repository.dart';
import 'package:electra_mobile/application/power_mutation_command.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/elv4_power_qualification_builder.dart';

void main() {
  test(
    'ELV1 port writer cannot edit or retire an active ELV4-owned port',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final builder = Elv4QualificationBuilder(db);
      await builder.createStructuralBaseline();
      final port = builder.powerPort('load', 'IN');
      await builder.addComponent('load', ports: [port]);
      final receipt = await builder.bindPort(
        port.id,
        PowerPortRole.consumer,
        expectedRevision: 1,
      );
      final original =
          (await builder.topology.load(builder.projectId)).ports.single;
      // Exact replay/no-op is allowed and does not advance canonical row state.
      await builder.topology.savePort(builder.projectId, original);
      final changed = EngineeringPort.fromMap({
        ...original.toMap(),
        'code': 'EDITED',
      });
      final owned = throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('ELV4_POWER_PORT_OWNED'),
        ),
      );
      await expectLater(
        builder.topology.savePort(builder.projectId, changed),
        owned,
      );
      await expectLater(
        builder.topology.archive(
          builder.projectId,
          TopologyObjectKind.port,
          port.id,
        ),
        owned,
      );
      expect(
        (await builder.topology.load(builder.projectId)).ports.single.toMap(),
        original.toMap(),
      );
      final revision = await (db.select(db.projectDesignRevisions)).getSingle();
      expect(revision.revision, receipt.currentRevision);
      await builder.power.execute(
        ReleasePowerPortCommand(
          operationId: 'release',
          projectId: builder.projectId,
          designRevisionId: builder.revisionId,
          expectedRevision: receipt.currentRevision,
          changedDependencies: [builder.dependency('PORT-${port.id}')],
          bindingId: 'binding-${port.id}',
        ),
      );
      await builder.topology.savePort(builder.projectId, changed);
      expect(
        (await builder.topology.load(builder.projectId)).ports.single.code,
        'EDITED',
      );
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    },
  );

  test(
    'ELV1 port writer blocks indirect load ownership without power-port binding',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final builder = Elv4QualificationBuilder(db);
      await builder.createStructuralBaseline();
      final port = builder.powerPort('load', 'IN');
      await builder.addComponent('load', ports: [port]);

      final receipt = await builder.power.execute(
        SetPowerLoadCommand(
          operationId: 'set-indirect-load',
          projectId: builder.projectId,
          designRevisionId: builder.revisionId,
          expectedRevision: 1,
          changedDependencies: [builder.dependency('LOAD-indirect')],
          contribution: PowerOwnLoadContribution(
            id: 'LOAD-indirect',
            componentId: 'load',
            inputPortId: port.id,
            accountingKind: PowerAccountingKind.consumerInput,
            stateCode: 'NORMAL',
            demand: DcConstantPowerDemand(PowerRational.integer(12)),
          ),
        ),
      );
      expect(await db.select(db.powerPortBindings).get(), isEmpty);
      expect(await db.select(db.powerLoadBindings).get(), hasLength(1));

      final original =
          (await builder.topology.load(builder.projectId)).ports.single;
      final changed = EngineeringPort.fromMap({
        ...original.toMap(),
        'code': 'INDIRECT-EDIT',
      });
      final owned = throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('ELV4_POWER_PORT_OWNED'),
        ),
      );

      await expectLater(
        builder.topology.savePort(builder.projectId, changed),
        owned,
      );
      await expectLater(
        builder.topology.archive(
          builder.projectId,
          TopologyObjectKind.port,
          port.id,
        ),
        owned,
      );
      expect(
        (await builder.topology.load(builder.projectId)).ports.single.toMap(),
        original.toMap(),
      );
      final revision = await (db.select(db.projectDesignRevisions)).getSingle();
      expect(revision.revision, receipt.currentRevision);
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    },
  );
}
