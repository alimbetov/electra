import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:electra_mobile/application/id_generator.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/drift_engineering_placement_repository.dart';
import 'package:electra_mobile/data/repositories/drift_engineering_reference_adoption_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'engineering_reference_adoption_persistence_test.dart' as fixture;

void main() {
  test('P6 adoption cannot rewrite an active ELV4 power-owned port', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await fixture.seedP6(db);

    final placement = DriftEngineeringPlacementRepository(
      db,
      originDeviceId: 'elv4-p9-adoption-guard',
    );
    final placed = await placement.place(
      fixture.placementFor('CAMERA', operation: 'place-power-owned-camera'),
    );
    final candidate = fixture.placementChangeCandidate(['CAMERA']);
    await fixture.insertCandidate(db, candidate);
    final command = await fixture.reviewedCommand(
      db: db,
      operationId: 'adopt-power-owned-camera',
      componentId: placed.componentId,
      candidate: candidate,
    );
    final binding = await fixture.bindingFor(db, placed.componentId);
    final ownedPortId = binding.portIds.first;
    final now = DateTime.utc(2026, 10, 16, 2);

    await db.into(db.projectDesignRevisions).insert(
      ProjectDesignRevisionsCompanion.insert(
        id: 'revision-power-owned-camera',
        projectId: 'project-1',
        code: 'R-POWER',
        sequence: 1,
        state: 'WORKING',
        createdAt: now,
        updatedAt: now,
        originDeviceId: 'elv4-p9-adoption-guard',
      ),
    );
    await db.into(db.powerPortBindings).insert(
      PowerPortBindingsCompanion.insert(
        projectId: 'project-1',
        designRevisionId: 'revision-power-owned-camera',
        id: 'power-owned-camera-port',
        createdAt: now,
        updatedAt: now,
        originDeviceId: 'elv4-p9-adoption-guard',
        portId: ownedPortId,
        resolvedProfileJson: '{}',
        profileSchema: 'electra.power-port-binding.v1',
        profileSha256:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      ),
    );

    final before = await fixture.adoptionState(db, placed.componentId);
    final repository = DriftEngineeringReferenceAdoptionRepository(
      db,
      originDeviceId: 'elv4-p9-adoption-guard',
      idGenerator: UuidV7IdGenerator(),
    );

    await expectLater(
      repository.adopt(command),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('ELV4_POWER_PORT_OWNED'),
        ),
      ),
    );

    expect(await fixture.adoptionState(db, placed.componentId), before);
    final durablePowerBinding =
        await (db.select(db.powerPortBindings)..where(
          (row) => row.id.equals('power-owned-camera-port'),
        )).getSingle();
    expect(durablePowerBinding.portId, ownedPortId);
    expect(durablePowerBinding.deletedAt, isNull);
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
  });
}
