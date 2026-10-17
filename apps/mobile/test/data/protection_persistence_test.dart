import 'package:electra_mobile/data/repositories/drift_electrical_circuit_repository.dart';
import 'package:electra_mobile/data/repositories/drift_electrical_load_repository.dart';
import 'package:electra_mobile/data/repositories/drift_dependency_recalculation_repository.dart';
import 'package:electra_mobile/data/repositories/drift_protection_repository.dart';
import 'package:electra_mobile/data/repositories/drift_cable_routing_repository.dart';
import 'package:electra_mobile/data/repositories/drift_floor_routing_repository.dart';

import 'dart:async';

import 'dart:io';

import 'package:drift/native.dart';
import 'package:electra_mobile/application/geometry_repository.dart';
import 'package:electra_mobile/application/id_generator.dart';
import 'package:electra_mobile/application/project_hierarchy_service.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/database/drift_unit_of_work.dart';
import 'package:electra_mobile/data/repositories/drift_component_instance_repository.dart';
import 'package:electra_mobile/data/repositories/drift_geometry_repository.dart';
import 'package:electra_mobile/data/repositories/drift_project_hierarchy_repository.dart';
import 'package:electra_mobile/domain/project_models.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'protection catalog, immutable rules and reviewed requirement survive restart and invalidation',
    () async {
      final directory = await Directory.systemTemp.createTemp('electra-fl6-');
      final file = File('${directory.path}/electra.sqlite');
      AppDatabase openDatabase() => AppDatabase(NativeDatabase(file));

      var database = openDatabase();
      final hierarchy = DriftProjectHierarchyRepository(database);
      final hierarchyService = ProjectHierarchyService(
        projects: hierarchy,
        floors: hierarchy,
        rooms: hierarchy,
        unitOfWork: DriftUnitOfWork(database),
        idGenerator: FixedSequenceIdGenerator(const [
          'project-components',
          'floor-components',
          'room-components',
          'room-other',
        ]),
        originDeviceId: 'component-test-device',
        clock: () => DateTime.utc(2026, 10, 12, 15),
      );

      final project = await hierarchyService.createProject(
        const ProjectFormDraft(
          name: 'Components Project',
          reference: 'C-01',
          measurementSystem: MeasurementSystem.metric,
          defaultStructuralHeightMm: 3200,
          defaultFinishedCeilingHeightMm: 3000,
        ),
      );
      final floor = await hierarchyService.createFloor(
        projectId: project.id,
        draft: const FloorFormDraft(
          name: 'Floor 01',
          code: 'F01',
          sortOrder: 1,
        ),
      );
      final room = await hierarchyService.createRoom(
        floorId: floor.id,
        draft: const RoomFormDraft(
          name: 'Workshop',
          type: RoomType.workshop,
          category: RoomCategory.technical,
          widthMm: 6000,
          depthMm: 5000,
        ),
      );

      final patch = SurfacePatch(
        id: 'wall-components',
        roomId: room.id,
        surfaceId: 'Wall A',
        frame: LocalCoordinateFrame(
          origin: const Point3Mm(0, 0, 0),
          uAxis: const Vector3D(1, 0, 0),
          vAxis: const Vector3D(0, 0, 1),
        ),
        boundary: Polygon2Mm(const [
          Point2Mm(0, 0),
          Point2Mm(6000, 0),
          Point2Mm(6000, 3200),
          Point2Mm(0, 3200),
        ]),
        orientation: SurfaceOrientation.vertical,
      );
      final geometry = DriftGeometryRepository(
        database,
        originDeviceId: 'component-test-device',
        clock: () => DateTime.utc(2026, 10, 12, 16),
      );
      await geometry.replaceRoomGeometry(
        RoomGeometrySnapshot(roomId: room.id, patches: [patch]),
      );

      final components = DriftComponentInstanceRepository(
        database,
        originDeviceId: 'load-test',
      );
      const instance = ComponentInstance(
        id: 'motor-001',
        definitionId: 'motor',
        definitionVersion: 1,
        roomId: 'room-components',
        hostSurfacePatchId: 'wall-components',
        localPosition: Point2Mm(1250, 300),
      );
      await components.saveComponent(instance);
      var loads = DriftElectricalLoadRepository(
        database,
        originDeviceId: 'circuit-test',
      );
      const group = RoomConsumptionGroup(
        id: 'group-motors',
        roomId: 'room-components',
        name: 'Workshop sockets',
      );
      await loads.saveGroup(group);
      const profile = ElectricalLoadProfile(
        nominalVoltageV: 230,
        phases: 1,
        ratedPowerW: 2300,
        powerFactor: 1,
      );
      const load = EquipmentElectricalLoad(
        componentInstanceId: 'motor-001',
        consumptionGroupId: 'group-motors',
        profile: profile,
        powerBasis: ElectricalPowerBasis.electricalInput,
      );
      await loads.saveLoad(load);
      var circuits = DriftElectricalCircuitRepository(
        database,
        originDeviceId: 'circuit-test',
      );
      await circuits.createFromGroup(
        circuitId: 'circuit-1',
        groupId: group.id,
        name: 'Workshop circuit',
        demandFactor: 0.8,
      );

      final cableRepository = DriftCableRoutingRepository(
        database,
        originDeviceId: 'protection-test',
      );
      var sequence = 0;
      final draft =
          SurfaceRouteDraft(nextId: () => 'protection-node-${sequence++}')
            ..addPoint(patch, const Point2Mm(100, 1000))
            ..addPoint(patch, const Point2Mm(2000, 1000));
      final route = draft.route(
        id: 'route',
        roomId: room.id,
        name: 'Test cable',
      );
      await cableRepository.saveRouteWithRun(
        route: route,
        run: CableRun(
          id: 'run',
          roomId: room.id,
          name: 'Test cable',
          circuitId: 'circuit-1',
          routeId: route.id,
        ),
      );
      final floorRepository = DriftFloorRoutingRepository(
        database,
        originDeviceId: 'protection-test',
      );
      final floorGraph = (await floorRepository.load(floor.id)).graph();
      await floorRepository.savePanel(
        FloorRoutingPanel(
          id: 'panel',
          floorId: floor.id,
          code: 'DB-01',
          name: 'Panel',
          feeds: [
            FloorPanelFeed(
              runId: 'run',
              endpointSignature: floorGraph.runs['run']!.endpointSignature(
                start: true,
              ),
            ),
          ],
        ),
      );
      var repository = DriftProtectionRepository(
        database,
        originDeviceId: 'protection-test',
      );
      var snapshot = await repository.load(project.id);
      expect(snapshot.documents.length, 3);
      final doc = snapshot.documents.firstWhere((d) => d.supportsPlanner);
      ProtectionRuleset policy(
        String id,
        String version,
        List<double> ratings,
      ) => ProtectionRuleset(
        id: id,
        projectId: project.id,
        normativeDocumentId: doc.id,
        reference: ElectricalRulesetRef(
          id: 'Workshop policy',
          jurisdiction: doc.jurisdiction,
          standardCode: doc.standardCode,
          version: version,
          sourceReference: doc.source,
        ),
        nominalCurrentsA: ratings,
        tripCurves: const ['B', 'C'],
        residualTypes: const ['A', 'B'],
        minimumBreakingCapacityKa: 6,
      );
      final rule = policy('rules-v1', '1', [6, 10, 16, 20]);
      await repository.saveRuleset(rule);
      await expectLater(
        repository.saveRuleset(policy('rules-v1', '1', [16])),
        throwsStateError,
      );
      await expectLater(
        repository.saveDocument(
          NormativeDocument(
            id: doc.id,
            standardCode: doc.standardCode,
            title: doc.title,
            version: doc.version,
            jurisdiction: doc.jurisdiction,
            publisher: doc.publisher,
            source: doc.source,
            kind: doc.kind,
            criteria: doc.criteria,
            clauseReference: doc.clauseReference,
            notes: 'changed',
          ),
        ),
        throwsStateError,
      );
      CircuitProtectionInputs input({
        String rulesetId = 'rules-v1',
        double iz = 20,
        ResidualProtectionPolicy residual =
            ResidualProtectionPolicy.notRequired,
      }) => CircuitProtectionInputs(
        circuitId: 'circuit-1',
        rulesetId: rulesetId,
        allowableCurrentA: iz,
        prospectiveFaultKa: 4,
        poles: 2,
        tripCurve: 'C',
        residualPolicy: residual,
        residualCurrentMa:
            residual == ResidualProtectionPolicy.required ? 30 : null,
        residualType:
            residual == ResidualProtectionPolicy.required ? 'A' : null,
        evidence: 'Declared test ampacity, fault current and residual policy.',
      );
      await repository.saveSettings(project.id, input());
      snapshot = await repository.load(project.id);
      var view = snapshot.circuits.single;
      expect(view.checkpoint!.proposal.values['ratedCurrentA'], 10);
      expect(view.checkpoint!.proposal.values['breakingCapacityKa'], 6);
      expect(view.checkpoint!.proposal.values['role'], 'mcb');
      expect(view.status, 'Proposed');
      expect(
        (view.checkpoint!.proposal.values['inputs']
            as Map)['normativeDocument'],
        doc.toMap(),
      );
      final before = view.fingerprint;
      await repository.confirm(project.id, view.circuitId, before);
      expect(
        (await repository.load(project.id)).circuits.single.status,
        'Confirmed requirement',
      );
      await database.close();
      database = openDatabase();
      repository = DriftProtectionRepository(
        database,
        originDeviceId: 'protection-test',
      );
      loads = DriftElectricalLoadRepository(
        database,
        originDeviceId: 'protection-test',
      );
      snapshot = await repository.load(project.id);
      expect(snapshot.circuits.single.status, 'Confirmed requirement');
      expect(snapshot.documents.length, 3);
      expect(snapshot.rulesets.single.nominalCurrentsA, [6, 10, 16, 20]);
      final events = StreamIterator(repository.watch(project.id));
      expect(await events.moveNext(), isTrue);
      Future<void> waitReview() async {
        while (await events.moveNext()) {
          if (events.current.circuits.single.status == 'Review required')
            return;
        }
        throw StateError('No review event.');
      }

      final review = waitReview().timeout(const Duration(seconds: 10));
      await loads.saveLoad(
        const EquipmentElectricalLoad(
          componentInstanceId: 'motor-001',
          consumptionGroupId: 'group-motors',
          profile: ElectricalLoadProfile(
            nominalVoltageV: 230,
            phases: 1,
            ratedPowerW: 4600,
            powerFactor: 1,
          ),
          powerBasis: ElectricalPowerBasis.electricalInput,
        ),
      );
      await review;
      await events.cancel();
      await expectLater(
        repository.confirm(project.id, 'circuit-1', before),
        throwsStateError,
      );
      await repository.recalculate(project.id);
      view = (await repository.load(project.id)).circuits.single;
      expect(view.checkpoint!.proposal.values['ratedCurrentA'], 16);
      expect(view.status, 'Review required');
      await repository.confirm(project.id, 'circuit-1', view.fingerprint);
      final revised = policy('rules-v2', '2', [20]);
      await repository.saveRuleset(revised);
      await repository.saveSettings(project.id, input(rulesetId: 'rules-v2'));
      view = (await repository.load(project.id)).circuits.single;
      expect(view.checkpoint!.proposal.values['ratedCurrentA'], 20);
      expect(view.status, 'Review required');
      expect(
        (view.checkpoint!.proposal.values['ruleset'] as Map)['version'],
        '2',
      );
      await repository.saveSettings(
        project.id,
        input(
          rulesetId: 'rules-v2',
          residual: ResidualProtectionPolicy.required,
        ),
      );
      view = (await repository.load(project.id)).circuits.single;
      expect(view.checkpoint!.proposal.values['role'], 'rcbo');
      expect(view.checkpoint!.proposal.values['residualCurrentMa'], 30);
      await expectLater(
        repository.saveSettings(project.id, input(rulesetId: 'foreign-rule')),
        throwsStateError,
      );
      await repository.saveSettings(
        project.id,
        input(rulesetId: 'rules-v2', iz: 5),
      );
      view = (await repository.load(project.id)).circuits.single;
      expect(view.checkpoint!.proposal.values['proposalState'], 'invalid');
      expect(view.checkpoint!.proposal.values['ratedCurrentA'], isNull);
      await expectLater(
        repository.confirm(project.id, 'circuit-1', view.fingerprint),
        throwsStateError,
      );
      final derived = await DriftDependencyRecalculationRepository(
        database,
        originDeviceId: 'protection-test',
      ).load(project.id);
      expect(
        derived.session.cache['panel:panel']!.state,
        EngineeringDerivedState.error,
      );
      await database.customStatement('DROP TABLE engineering_port_connections');
      await database.customStatement(
        'DROP TABLE engineering_internal_mappings',
      );
      await database.customStatement(
        'DROP TABLE engineering_component_assemblies',
      );
      await database.customStatement('DROP TABLE engineering_topology_groups');
      await database.customStatement(
        'DROP TABLE engineering_compatibility_profiles',
      );
      await database.customStatement(
        'DROP TABLE engineering_topology_profiles',
      );
      await database.customStatement(
        'DROP TABLE engineering_assembly_profiles',
      );
      await database.customStatement('DROP TABLE engineering_port_instances');
      await database.customStatement(
        'DROP TABLE component_engineering_memberships',
      );
      await database.customStatement('DROP TABLE project_engineering_systems');
      await database.customStatement(
        'DROP TABLE engineering_family_definitions',
      );
      await database.customStatement('DROP TABLE panel_generation_configs');
      await database.customStatement('DROP TABLE circuit_product_selections');
      await database.customStatement('DROP TABLE manufacturer_policies');
      await database.customStatement('DROP TABLE manufacturer_products');
      await database.customStatement('DROP TABLE manufacturer_catalogs');
      await database.customStatement('DROP TABLE circuit_protection_settings');
      await database.customStatement('DROP TABLE protection_rulesets');
      await database.customStatement('DROP TABLE normative_documents');
      await database.customStatement('DROP TABLE component_reference_bindings');
      await database.customStatement(
        'DROP TABLE engineering_reference_catalogs',
      );
      await database.customStatement('PRAGMA user_version = 10');
      await database.close();
      database = openDatabase();
      repository = DriftProtectionRepository(
        database,
        originDeviceId: 'protection-test',
      );
      snapshot = await repository.load(project.id);
      expect(snapshot.documents.length, 3);
      expect(snapshot.rulesets, isEmpty);
      expect(snapshot.circuits.single.settings.rulesetId, isNull);
      expect(database.schemaVersion, 24);
      await database.close();
      await directory.delete(recursive: true);
    },
  );
}
