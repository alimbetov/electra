import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:electra_mobile/application/engineering_reference_adoption_repository.dart';
import 'package:electra_mobile/application/engineering_reference_repository.dart';
import 'package:electra_mobile/application/engineering_reference_revision_preview.dart';
import 'package:electra_mobile/application/id_generator.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/drift_engineering_placement_repository.dart';
import 'package:electra_mobile/data/repositories/drift_engineering_reference_adoption_repository.dart';
import 'package:electra_mobile/data/repositories/drift_engineering_reference_repository.dart';
import 'package:electra_mobile/data/repositories/drift_engineering_topology_repository.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'engineering_reference_adoption_persistence_test.dart' as p6;

void main() {
  late AppDatabase db;
  late DriftEngineeringPlacementRepository placement;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await p6.seedP6(db);
    placement = DriftEngineeringPlacementRepository(
      db,
      originDeviceId: 'round2-placement',
    );
  });

  tearDown(() => db.close());

  test('current catalog row version drift blocks adoption with zero mutation', () async {
    final placed = await placement.place(
      p6.placementFor('CAMERA', operation: 'place-provenance-drift'),
    );
    final candidate = p6.placementChangeCandidate(['CAMERA']);
    await p6.insertCandidate(db, candidate);
    final reviewed = await p6.reviewedCommand(
      db: db,
      operationId: 'adopt-provenance-drift',
      componentId: placed.componentId,
      candidate: candidate,
    );
    await (db.update(db.engineeringReferenceCatalogs)
      ..where((row) => row.id.equals('catalog-1'))).write(
      const EngineeringReferenceCatalogsCompanion(
        catalogVersion: Value('0.9.0-corrupt'),
      ),
    );
    final before = await p6.adoptionState(db, placed.componentId);
    final repository = DriftEngineeringReferenceAdoptionRepository(
      db,
      originDeviceId: 'round2-adopt',
      idGenerator: UuidV7IdGenerator(),
    );

    await expectLater(
      repository.adopt(reviewed),
      throwsA(
        isA<EngineeringReferenceAdoptionFailure>().having(
          (error) => error.code,
          'code',
          EngineeringReferenceAdoptionFailureCode.currentBindingUnavailable,
        ),
      ),
    );
    expect(await p6.adoptionState(db, placed.componentId), before);
  });

  test('same exact edition with exact aggregate is a deterministic zero-write no-op', () async {
    final placed = await placement.place(
      p6.placementFor('CAMERA', operation: 'place-same-edition'),
    );
    final references = await DriftEngineeringReferenceRepository(
      db,
      originDeviceId: 'round2-review',
      idGenerator: UuidV7IdGenerator(),
    ).load('project-1');
    final topology = await DriftEngineeringTopologyRepository(
      db,
      originDeviceId: 'round2-review',
    ).load('project-1');
    final binding = references.bindings.singleWhere(
      (item) => item.componentId == placed.componentId,
    );
    final graphFingerprint = canonicalEngineeringJson({
      'connections': topology.connections
          .where(
            (item) => binding.portIds.contains(item.fromPortId) ||
                binding.portIds.contains(item.toPortId),
          )
          .map((item) => item.toMap())
          .toList(),
      'groups': topology.groups
          .where(
            (item) => binding.portIds.contains(item.startPortId) ||
                (item.endPortId != null && binding.portIds.contains(item.endPortId)),
          )
          .map((item) => item.toMap())
          .toList(),
      'internal': topology.internalLinks
          .where(
            (item) => binding.portIds.contains(item.fromPortId) ||
                binding.portIds.contains(item.toPortId),
          )
          .map((item) => item.toMap())
          .toList(),
    });
    final command = EngineeringReferenceAdoptionCommand(
      operationId: 'same-edition-noop',
      projectId: 'project-1',
      componentId: placed.componentId,
      expectedCatalogId: binding.catalogId,
      expectedCatalogVersion: binding.catalogVersion,
      candidateCatalogId: binding.catalogId,
      candidateCatalogVersion: binding.catalogVersion,
      profileCode: binding.profileCode,
      reviewedBindingFingerprint: canonicalEngineeringJson(binding.toMap()),
      reviewedGraphFingerprint: graphFingerprint,
    );
    final before = await p6.adoptionState(db, placed.componentId);
    final repository = DriftEngineeringReferenceAdoptionRepository(
      db,
      originDeviceId: 'round2-adopt',
      idGenerator: UuidV7IdGenerator(),
    );

    final first = await repository.adopt(command);
    final second = await repository.adopt(command);

    expect(first.toMap(), second.toMap());
    expect(first.catalogId, binding.catalogId);
    expect(first.catalogVersion, binding.catalogVersion);
    expect(first.portIds, binding.portIds);
    expect(await p6.adoptionState(db, placed.componentId), before);
  });
}
