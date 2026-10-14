import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:electra_mobile/application/engineering_placement_command.dart';
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

import '../support/engineering_placement_fixture.dart';

Future<void> seedP6(AppDatabase db) async {
  await seedPlacementParents(db);
  await seedPlacementSystemAndCatalog(db);
  for (final code in ['LAN', 'ACS', 'FIRE']) {
    await seedEngineeringSystem(db, id: code, code: code, familyCode: code);
  }
}

PlaceEngineeringProfileCommand placementFor(String code, {String? operation}) {
  final initial = placementCommand();
  return PlaceEngineeringProfileCommand.fromMap({
    ...initial.toMap(),
    'operationId': operation ?? 'place-$code',
    'profileCode': code,
    'systemId': switch (code) {
      'CAMERA' => 'system-1',
      'OUTLET' => 'LAN',
      'READER' || 'LOCK' => 'ACS',
      _ => 'FIRE',
    },
    'placementContext': {
      ...initial.placementContext.toMap(),
      'installationSurface': code == 'DETECTOR' ? 'ceiling' : 'wall',
      'mountingMethod': switch (code) {
        'CAMERA' => 'bracket',
        'OUTLET' => 'flush',
        _ => 'surface',
      },
      'topologyShape': code == 'DETECTOR' ? 'loop' : 'star',
    },
  });
}

EngineeringReferenceCatalog sourceCatalog() {
  final map =
      jsonDecode(
            File(
              '../../docs/examples/elv2-interface-catalog.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  return EngineeringReferenceCatalog.fromMap({
    ...map,
    'id': 'catalog-1',
    'version': '1.0.0',
  });
}

EngineeringReferenceCatalog placementChangeCandidate(
  Iterable<String> profileCodes,
) {
  final source = sourceCatalog();
  final selected = profileCodes.toSet();
  return EngineeringReferenceCatalog.fromMap({
    ...source.toMap(),
    'id': 'catalog-2',
    'version': '2.0.0',
    'profiles': [
      for (final profile in source.profiles)
        if (selected.contains(profile.code))
          {
            ...profile.toMap(),
            'constraints': {
              ...profile.constraints!.toMap(),
              'mounting': {
                ...profile.constraints!.mounting.toMap(),
                'minimumClearanceMm':
                    profile.constraints!.mounting.minimumClearanceMm == 50
                        ? 49
                        : (profile.constraints!.mounting.minimumClearanceMm ??
                                0) +
                            1,
              },
            },
          }
        else
          profile.toMap(),
    ],
  });
}

EngineeringReferenceCatalog migrationCandidate() {
  final source = sourceCatalog();
  final detector = source.profile('DETECTOR');
  final first = detector.portTemplates.first;
  final second = detector.portTemplates.last;
  final auxiliary = EngineeringPort.fromMap({
    ...second.toMap(),
    'id': 'template-aux',
    'componentId': 'template',
    'code': 'AUX',
  });
  final interfaceCodes = Map<String, String>.from(detector.portInterfaceCodes);
  final removedInterface = interfaceCodes.remove(second.code);
  if (removedInterface != null) interfaceCodes['AUX'] = removedInterface;
  return EngineeringReferenceCatalog.fromMap({
    ...source.toMap(),
    'id': 'catalog-2',
    'version': '2.0.0',
    'profiles': [
      for (final profile in source.profiles)
        if (profile.code == 'DETECTOR')
          {
            ...profile.toMap(),
            'portTemplates': [first.toMap(), auxiliary.toMap()],
            'portInterfaceCodes': interfaceCodes,
          }
        else
          profile.toMap(),
    ],
  });
}

Future<void> insertCandidate(
  AppDatabase db,
  EngineeringReferenceCatalog catalog,
) async {
  final now = DateTime.utc(2026, 10, 14, 2);
  await db
      .into(db.engineeringReferenceCatalogs)
      .insert(
        EngineeringReferenceCatalogsCompanion.insert(
          id: catalog.id,
          projectId: 'project-1',
          code: catalog.code,
          catalogVersion: catalog.version,
          payloadJson: canonicalEngineeringJson(catalog.toMap()),
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'p6-test',
        ),
      );
}

Future<ComponentReferenceBinding> bindingFor(
  AppDatabase db,
  String componentId,
) async {
  final row =
      await (db.select(db.componentReferenceBindings)..where(
        (candidate) => candidate.componentId.equals(componentId),
      )).getSingle();
  return ComponentReferenceBinding.fromMap(
    jsonDecode(row.payloadJson) as Map<String, dynamic>,
  );
}

Future<EngineeringReferenceAdoptionCommand> reviewedCommand({
  required AppDatabase db,
  required String operationId,
  required String componentId,
  required EngineeringReferenceCatalog candidate,
}) async {
  final references = await DriftEngineeringReferenceRepository(
    db,
    originDeviceId: 'p6-review',
    idGenerator: UuidV7IdGenerator(),
  ).load('project-1');
  final topology = await DriftEngineeringTopologyRepository(
    db,
    originDeviceId: 'p6-review',
  ).load('project-1');
  final preview = previewCatalogRevision(
    references: references,
    topology: topology,
    candidate: candidate,
  );
  final impact = preview.bindingImpacts.singleWhere(
    (item) => item.componentId == componentId,
  );
  final binding = references.bindings.singleWhere(
    (item) => item.componentId == componentId,
  );
  expect(impact.adoptionBlocked, isFalse);
  return EngineeringReferenceAdoptionCommand(
    operationId: operationId,
    projectId: 'project-1',
    componentId: componentId,
    expectedCatalogId: binding.catalogId,
    expectedCatalogVersion: binding.catalogVersion,
    candidateCatalogId: candidate.id,
    candidateCatalogVersion: candidate.version,
    profileCode: binding.profileCode,
    reviewedBindingFingerprint: canonicalEngineeringJson(binding.toMap()),
    reviewedGraphFingerprint: impact.graphFingerprint,
    reviewedConnectionIds: impact.connectionIds,
    reviewedTopologyGroupIds: impact.topologyGroupIds,
  );
}

Future<String> adoptionState(AppDatabase db, String componentId) async =>
    canonicalEngineeringJson({
      'binding': [
        for (final row
            in await (db.select(db.componentReferenceBindings)..where(
              (candidate) => candidate.componentId.equals(componentId),
            )).get())
          row.toJson(),
      ],
      'ports': [
        for (final row
            in await (db.select(db.engineeringPortInstances)..where(
              (candidate) => candidate.componentId.equals(componentId),
            )).get())
          row.toJson(),
      ],
      'operations': [
        for (final row
            in await db.select(db.engineeringPlacementOperations).get())
          row.toJson(),
      ],
    });

void main() {
  late AppDatabase db;
  late DriftEngineeringPlacementRepository placement;
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await seedP6(db);
    placement = DriftEngineeringPlacementRepository(
      db,
      originDeviceId: 'p6-placement',
    );
  });
  tearDown(() => db.close());

  test(
    'explicit adoption preserves identities, freezes candidate and replays',
    () async {
      final placed = await placement.place(placementFor('CAMERA'));
      final candidate = placementChangeCandidate(['CAMERA']);
      await insertCandidate(db, candidate);
      final command = await reviewedCommand(
        db: db,
        operationId: 'adopt-camera',
        componentId: placed.componentId,
        candidate: candidate,
      );
      final beforePorts = (await bindingFor(db, placed.componentId)).portIds;
      final repo = DriftEngineeringReferenceAdoptionRepository(
        db,
        originDeviceId: 'p6-adopt',
        idGenerator: FixedSequenceIdGenerator(['new-unused']),
      );

      final result = await repo.adopt(command);
      expect(result.catalogId, 'catalog-2');
      expect(result.catalogVersion, '2.0.0');
      expect(result.portIds, beforePorts);
      final binding = await bindingFor(db, placed.componentId);
      expect(binding.catalogId, 'catalog-2');
      expect(binding.catalogVersion, '2.0.0');
      expect(binding.profile.toMap(), candidate.profile('CAMERA').toMap());
      expect(binding.portIds, beforePorts);
      final stable = await adoptionState(db, placed.componentId);
      final replay = await repo.adopt(command);
      expect(replay.toMap(), result.toMap());
      expect(await adoptionState(db, placed.componentId), stable);
    },
  );

  test(
    'changed reviewed graph fingerprint blocks with zero mutation',
    () async {
      final placed = await placement.place(placementFor('CAMERA'));
      final candidate = placementChangeCandidate(['CAMERA']);
      await insertCandidate(db, candidate);
      final reviewed = await reviewedCommand(
        db: db,
        operationId: 'adopt-stale',
        componentId: placed.componentId,
        candidate: candidate,
      );
      final command = EngineeringReferenceAdoptionCommand(
        operationId: reviewed.operationId,
        projectId: reviewed.projectId,
        componentId: reviewed.componentId,
        expectedCatalogId: reviewed.expectedCatalogId,
        expectedCatalogVersion: reviewed.expectedCatalogVersion,
        candidateCatalogId: reviewed.candidateCatalogId,
        candidateCatalogVersion: reviewed.candidateCatalogVersion,
        profileCode: reviewed.profileCode,
        reviewedBindingFingerprint: reviewed.reviewedBindingFingerprint,
        reviewedGraphFingerprint: '${reviewed.reviewedGraphFingerprint}-stale',
        reviewedConnectionIds: reviewed.reviewedConnectionIds,
        reviewedTopologyGroupIds: reviewed.reviewedTopologyGroupIds,
      );
      final before = await adoptionState(db, placed.componentId);
      final repo = DriftEngineeringReferenceAdoptionRepository(
        db,
        originDeviceId: 'p6-adopt',
        idGenerator: FixedSequenceIdGenerator(['unused']),
      );
      await expectLater(
        repo.adopt(command),
        throwsA(
          isA<EngineeringReferenceAdoptionFailure>().having(
            (error) => error.code,
            'code',
            EngineeringReferenceAdoptionFailureCode.staleReview,
          ),
        ),
      );
      expect(await adoptionState(db, placed.componentId), before);
    },
  );

  test(
    'live internal dependency blocks removal and preserves aggregate',
    () async {
      final placed = await placement.place(placementFor('DETECTOR'));
      final binding = await bindingFor(db, placed.componentId);
      expect(binding.portIds, hasLength(2));
      final now = DateTime.utc(2026, 10, 14, 2, 20);
      final mapping = InternalConnectivity(
        id: 'internal-live',
        componentId: placed.componentId,
        fromPortId: binding.portIds.first,
        toPortId: binding.portIds.last,
        layer: ConnectionLayer.signal,
        bidirectional: true,
        evidence: 'P6 live dependency',
      );
      await db
          .into(db.engineeringInternalMappings)
          .insert(
            EngineeringInternalMappingsCompanion.insert(
              id: mapping.id,
              projectId: 'project-1',
              componentId: placed.componentId,
              fromPortId: mapping.fromPortId,
              toPortId: mapping.toPortId,
              payloadJson: canonicalEngineeringJson(mapping.toMap()),
              createdAt: now,
              updatedAt: now,
              originDeviceId: 'p6-test',
            ),
          );
      final candidate = migrationCandidate();
      await insertCandidate(db, candidate);
      final references = await DriftEngineeringReferenceRepository(
        db,
        originDeviceId: 'review',
        idGenerator: UuidV7IdGenerator(),
      ).load('project-1');
      final topology = await DriftEngineeringTopologyRepository(
        db,
        originDeviceId: 'review',
      ).load('project-1');
      final preview = previewCatalogRevision(
        references: references,
        topology: topology,
        candidate: candidate,
      );
      final impact = preview.bindingImpacts.singleWhere(
        (item) => item.componentId == placed.componentId,
      );
      final current = references.bindings.singleWhere(
        (item) => item.componentId == placed.componentId,
      );
      final command = EngineeringReferenceAdoptionCommand(
        operationId: 'adopt-detector-blocked',
        projectId: 'project-1',
        componentId: placed.componentId,
        expectedCatalogId: current.catalogId,
        expectedCatalogVersion: current.catalogVersion,
        candidateCatalogId: candidate.id,
        candidateCatalogVersion: candidate.version,
        profileCode: current.profileCode,
        reviewedBindingFingerprint: canonicalEngineeringJson(current.toMap()),
        reviewedGraphFingerprint: impact.graphFingerprint,
        reviewedConnectionIds: impact.connectionIds,
        reviewedTopologyGroupIds: impact.topologyGroupIds,
      );
      final before = await adoptionState(db, placed.componentId);
      final repo = DriftEngineeringReferenceAdoptionRepository(
        db,
        originDeviceId: 'p6-adopt',
        idGenerator: FixedSequenceIdGenerator(['new-aux']),
      );
      await expectLater(
        repo.adopt(command),
        throwsA(
          isA<EngineeringReferenceAdoptionFailure>().having(
            (error) => error.code,
            'code',
            EngineeringReferenceAdoptionFailureCode.dependencyConflict,
          ),
        ),
      );
      expect(await adoptionState(db, placed.componentId), before);
    },
  );

  for (final point in EngineeringReferenceAdoptionFailurePoint.values) {
    test(
      'injected $point rolls back binding ports and operation ledger',
      () async {
        final placed = await placement.place(placementFor('DETECTOR'));
        final candidate = migrationCandidate();
        await insertCandidate(db, candidate);
        final command = await reviewedCommand(
          db: db,
          operationId: 'fault-${point.name}',
          componentId: placed.componentId,
          candidate: candidate,
        );
        final before = await adoptionState(db, placed.componentId);
        final repo = DriftEngineeringReferenceAdoptionRepository(
          db,
          originDeviceId: 'p6-fault',
          idGenerator: FixedSequenceIdGenerator(['new-aux']),
          failurePoint: point,
        );
        await expectLater(repo.adopt(command), throwsA(anything));
        expect(await adoptionState(db, placed.componentId), before);
      },
    );
  }

  test(
    'four disciplines adopt exact editions and survive SQLite restart',
    () async {
      final directory = await Directory.systemTemp.createTemp('electra-p6-');
      final file = File('${directory.path}/p6.sqlite');
      await db.close();
      db = AppDatabase(NativeDatabase(file));
      await seedP6(db);
      placement = DriftEngineeringPlacementRepository(
        db,
        originDeviceId: 'p7-placement',
      );
      final codes = ['CAMERA', 'OUTLET', 'READER', 'DETECTOR'];
      final results = <String, EngineeringReferenceAdoptionResult>{};
      final candidate = placementChangeCandidate(codes);
      await insertCandidate(db, candidate);
      for (final code in codes) {
        final placed = await placement.place(
          placementFor(code, operation: 'p7-place-$code'),
        );
        final command = await reviewedCommand(
          db: db,
          operationId: 'p7-adopt-$code',
          componentId: placed.componentId,
          candidate: candidate,
        );
        results[code] = await DriftEngineeringReferenceAdoptionRepository(
          db,
          originDeviceId: 'p7-adopt',
          idGenerator: UuidV7IdGenerator(),
        ).adopt(command);
      }
      await db.close();
      db = AppDatabase(NativeDatabase(file));
      for (final entry in results.entries) {
        final binding = await bindingFor(db, entry.value.componentId);
        expect(binding.catalogId, 'catalog-2');
        expect(binding.catalogVersion, '2.0.0');
        expect(binding.profileCode, entry.key);
        expect(binding.portIds, entry.value.portIds);
        for (final portId in binding.portIds) {
          final row =
              await (db.select(
                db.engineeringPortInstances,
              )..where((candidate) => candidate.id.equals(portId))).getSingle();
          final port = EngineeringPort.fromMap(
            jsonDecode(row.payloadJson) as Map<String, dynamic>,
          );
          expect(port.templateProvenance!.version, '2.0.0');
        }
        final operation =
            await (db.select(db.engineeringPlacementOperations)..where(
              (row) => row.operationId.equals('adopt:p7-adopt-${entry.key}'),
            )).getSingle();
        expect(operation.status, engineeringReferenceAdoptionCompletedStatus);
      }
      await db.close();
      await directory.delete(recursive: true);
      db = AppDatabase(NativeDatabase.memory());
    },
  );
}
