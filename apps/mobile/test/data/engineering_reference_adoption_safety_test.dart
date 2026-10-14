import 'dart:convert';

import 'package:drift/native.dart';
import 'package:electra_mobile/application/engineering_placement_command.dart';
import 'package:electra_mobile/application/engineering_reference_adoption_repository.dart';
import 'package:electra_mobile/application/id_generator.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/drift_engineering_placement_repository.dart';
import 'package:electra_mobile/data/repositories/drift_engineering_reference_adoption_repository.dart';
import 'package:electra_mobile/data/repositories/drift_engineering_topology_repository.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'engineering_reference_adoption_persistence_test.dart' as p6;

PlaceEngineeringProfileCommand poeSwitchCommand() {
  final camera = p6.placementFor('CAMERA', operation: 'place-poe-switch');
  return PlaceEngineeringProfileCommand.fromMap({
    ...camera.toMap(),
    'profileCode': 'POE_SWITCH',
    'displayNameOverride': 'PoE Switch',
    'placementContext': {
      ...camera.placementContext.toMap(),
      'installationSurface': 'rack',
      'mountingMethod': 'rackUnit',
      'topologyRole': 'hub',
    },
  });
}

void main() {
  late AppDatabase db;
  late DriftEngineeringPlacementRepository placement;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await p6.seedP6(db);
    placement = DriftEngineeringPlacementRepository(
      db,
      originDeviceId: 'p6-safety-placement',
    );
  });

  tearDown(() => db.close());

  test(
    'connected reused port rejects candidate edition incompatible with persisted connection profile',
    () async {
      final switchResult = await placement.place(poeSwitchCommand());
      final cameraResult = await placement.place(
        p6.placementFor('CAMERA', operation: 'place-connected-camera'),
      );
      final switchBinding = await p6.bindingFor(db, switchResult.componentId);
      final cameraBinding = await p6.bindingFor(db, cameraResult.componentId);
      final source = p6.sourceCatalog();
      final connectionProfile = source
          .connectionProfiles('project-1')
          .singleWhere((profile) => profile.semanticCode == 'CCTV-POE');
      final topology = DriftEngineeringTopologyRepository(
        db,
        originDeviceId: 'p6-safety-topology',
      );
      await topology.saveConnectionProfile(connectionProfile);
      await topology.saveConnection(
        'project-1',
        EngineeringConnection(
          id: 'cctv-live-link',
          systemId: 'system-1',
          fromPortId: switchBinding.portIds.single,
          toPortId: cameraBinding.portIds.single,
          profileId: connectionProfile.id,
          medium: ConnectionMedium.wired,
        ),
      );

      final candidate = p6.placementChangeCandidate(['CAMERA']);
      await p6.insertCandidate(db, candidate);
      final command = await p6.reviewedCommand(
        db: db,
        operationId: 'adopt-connected-camera',
        componentId: cameraResult.componentId,
        candidate: candidate,
      );
      expect(command.reviewedConnectionIds, ['cctv-live-link']);
      final before = await p6.adoptionState(db, cameraResult.componentId);
      final repository = DriftEngineeringReferenceAdoptionRepository(
        db,
        originDeviceId: 'p6-safety-adopt',
        idGenerator: UuidV7IdGenerator(),
      );

      await expectLater(
        repository.adopt(command),
        throwsA(
          isA<EngineeringReferenceAdoptionFailure>().having(
            (error) => error.code,
            'code',
            EngineeringReferenceAdoptionFailureCode.graphIncompatible,
          ),
        ),
      );
      expect(await p6.adoptionState(db, cameraResult.componentId), before);
      final connection =
          await (db.select(db.engineeringPortConnections)
            ..where((row) => row.id.equals('cctv-live-link'))).getSingle();
      expect(
        EngineeringConnection.fromMap(
          jsonDecode(connection.payloadJson) as Map<String, dynamic>,
        ).toPortId,
        cameraBinding.portIds.single,
      );
    },
  );

  test('reviewed v2 adoption never switches to later imported v3', () async {
    final placed = await placement.place(
      p6.placementFor('CAMERA', operation: 'place-no-latest'),
    );
    final candidateV2 = p6.placementChangeCandidate(['CAMERA']);
    await p6.insertCandidate(db, candidateV2);
    final reviewed = await p6.reviewedCommand(
      db: db,
      operationId: 'adopt-reviewed-v2',
      componentId: placed.componentId,
      candidate: candidateV2,
    );

    final candidateV3 = EngineeringReferenceCatalog.fromMap({
      ...candidateV2.toMap(),
      'id': 'catalog-3',
      'version': '3.0.0',
    });
    await p6.insertCandidate(db, candidateV3);
    final repository = DriftEngineeringReferenceAdoptionRepository(
      db,
      originDeviceId: 'p6-exact-edition',
      idGenerator: UuidV7IdGenerator(),
    );

    final result = await repository.adopt(reviewed);
    expect(result.catalogId, 'catalog-2');
    expect(result.catalogVersion, '2.0.0');
    final binding = await p6.bindingFor(db, placed.componentId);
    expect(binding.catalogId, 'catalog-2');
    expect(binding.catalogVersion, '2.0.0');
    final replay = await repository.adopt(reviewed);
    expect(replay.catalogId, 'catalog-2');
    expect(replay.catalogVersion, '2.0.0');
  });
}
