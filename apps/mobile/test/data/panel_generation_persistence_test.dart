import 'package:electra_mobile/data/repositories/drift_electrical_circuit_repository.dart';
import 'package:electra_mobile/data/repositories/drift_electrical_load_repository.dart';
import 'package:electra_mobile/data/repositories/drift_protection_repository.dart';
import 'package:electra_mobile/data/repositories/drift_panel_generation_repository.dart';
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
  test('panel proposal follows group membership, exact confirmation and durable policy through restart and migration', () async {
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
      draft: const FloorFormDraft(name: 'Floor 01', code: 'F01', sortOrder: 1),
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
    final route = draft.route(id: 'route', roomId: room.id, name: 'Test cable');
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
    ProtectionRuleset policy(String id, String version, List<double> ratings) =>
        ProtectionRuleset(
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
      ResidualProtectionPolicy residual = ResidualProtectionPolicy.notRequired,
    }) => CircuitProtectionInputs(
      circuitId: 'circuit-1',
      rulesetId: rulesetId,
      allowableCurrentA: iz,
      prospectiveFaultKa: 4,
      poles: 2,
      tripCurve: 'C',
      residualPolicy: residual,
      residualCurrentMa: residual == ResidualProtectionPolicy.required
          ? 30
          : null,
      residualType: residual == ResidualProtectionPolicy.required ? 'A' : null,
      evidence: 'Declared test ampacity, fault current and residual policy.',
    );
    await repository.saveSettings(project.id, input());
    var panels = DriftPanelGenerationRepository(
      database,
      originDeviceId: 'panel-test',
    );
    PanelGenerationPolicy config({
      String id = 'generated-panel',
      double reserve = 25,
    }) => PanelGenerationPolicy(
      id: id,
      projectId: project.id,
      floorId: floor.id,
      name: 'Floor panel',
      rulesetId: rule.id,
      phases: 1,
      phaseVoltageV: 230,
      lineVoltageV: 400,
      demandFactor: 0.8,
      reservePercent: reserve,
      minimumSpareModules: 2,
      moduleWidths: const {'mcb:2': 2},
      outgoing: input(),
      incoming: input(iz: 100),
    );
    await panels.save(config());
    var data = await panels.load(project.id);
    var view = data.panels.single;
    final key = view.key;
    var session = data.protection.recalculation.session;
    expect(data.status(view), 'Proposed');
    expect((session.cache[key]!.proposal.values['circuits'] as List).length, 1);
    expect(session.cache[key]!.proposal.values['incomingDesignCurrentA'], 8);
    final fingerprint = session.fingerprints[key]!;
    await panels.confirm(project.id, view.policy.id, fingerprint);
    data = await panels.load(project.id);
    expect(data.status(data.panels.single), 'Confirmed');
    await database.close();
    database = openDatabase();
    panels = DriftPanelGenerationRepository(
      database,
      originDeviceId: 'panel-test',
    );
    loads = DriftElectricalLoadRepository(
      database,
      originDeviceId: 'panel-test',
    );
    data = await panels.load(project.id);
    expect(data.status(data.panels.single), 'Confirmed');
    expect(data.panels.single.policy.toMap(), config().toMap());
    final oldCircuit =
        (await database.select(database.electricalCircuits).get()).single;
    final events = StreamIterator(panels.watch(project.id));
    expect(await events.moveNext(), isTrue);
    final changed = () async {
      while (await events.moveNext()) {
        if (events.current.status(events.current.panels.single) == 'Stale')
          return;
      }
      throw StateError('Missing invalidation event');
    }();
    await loads.saveGroup(
      const RoomConsumptionGroup(
        id: 'group-new',
        roomId: 'room-components',
        name: 'Dedicated group',
      ),
    );
    await changed.timeout(const Duration(seconds: 10));
    await events.cancel();
    await expectLater(
      panels.confirm(project.id, view.policy.id, fingerprint),
      throwsStateError,
    );
    await panels.recalculate(project.id);
    data = await panels.load(project.id);
    expect(data.status(data.panels.single), 'Review required');
    final updatedComponents = DriftComponentInstanceRepository(
      database,
      originDeviceId: 'panel-test',
    );
    await updatedComponents.saveComponent(
      const ComponentInstance(
        id: 'second-load',
        definitionId: 'motor',
        definitionVersion: 1,
        roomId: 'room-components',
        hostSurfacePatchId: 'wall-components',
        localPosition: Point2Mm(1500, 300),
      ),
    );
    await loads.saveLoad(
      const EquipmentElectricalLoad(
        componentInstanceId: 'second-load',
        consumptionGroupId: 'group-new',
        profile: profile,
        powerBasis: ElectricalPowerBasis.electricalInput,
      ),
    );
    await panels.recalculate(project.id);
    data = await panels.load(project.id);
    expect(
      (data
                  .protection
                  .recalculation
                  .session
                  .cache[key]!
                  .proposal
                  .values['circuits']
              as List)
          .length,
      2,
    );
    expect(
      data
          .protection
          .recalculation
          .session
          .cache[key]!
          .proposal
          .values['incomingDesignCurrentA'],
      16,
    );
    await updatedComponents.removeComponent('second-load');
    await panels.recalculate(project.id);
    data = await panels.load(project.id);
    expect(
      (data
                  .protection
                  .recalculation
                  .session
                  .cache[key]!
                  .proposal
                  .values['circuits']
              as List)
          .length,
      1,
    );
    // Moving the source load changes the generated circuit provenance, not actual FL8 assignments.
    await loads.saveLoad(
      const EquipmentElectricalLoad(
        componentInstanceId: 'motor-001',
        consumptionGroupId: 'group-new',
        profile: profile,
        powerBasis: ElectricalPowerBasis.electricalInput,
      ),
    );
    await panels.recalculate(project.id);
    data = await panels.load(project.id);
    var values =
        data.protection.recalculation.session.cache[key]!.proposal.values;
    expect(
      ((values['circuits'] as List).single as Map)['sourceGroupId'],
      'group-new',
    );
    expect(
      (await database.select(database.electricalCircuits).get()).single
          .toJson(),
      oldCircuit.toJson(),
    );
    // Removing a populated group reports the unowned load; no partial incoming total.
    await database.customStatement(
      "UPDATE consumption_groups SET deleted_at = 1 WHERE id = 'group-new'",
    );
    await panels.recalculate(project.id);
    data = await panels.load(project.id);
    values = data.protection.recalculation.session.cache[key]!.proposal.values;
    expect(data.status(data.panels.single), 'Needs input');
    expect(values['incomingDesignCurrentA'], isNull);
    expect(values['circuits'], isEmpty);
    await expectLater(
      panels.confirm(
        project.id,
        view.policy.id,
        data.protection.recalculation.session.fingerprints[key]!,
      ),
      throwsStateError,
    );
    await loads.saveLoad(load);
    await panels.recalculate(project.id);
    data = await panels.load(project.id);
    expect(
      (data
                  .protection
                  .recalculation
                  .session
                  .cache[key]!
                  .proposal
                  .values['circuits']
              as List)
          .length,
      1,
    );
    await panels.save(config(reserve: 50));
    data = await panels.load(project.id);
    expect(data.status(data.panels.single), 'Proposed');
    await expectLater(
      panels.save(config(id: 'second-panel')),
      throwsStateError,
    );
    // FL14 data remains readable across 12 -> 13 migration.
    await database.customStatement('DROP TABLE engineering_port_connections');
    await database.customStatement('DROP TABLE engineering_internal_mappings');
    await database.customStatement(
      'DROP TABLE engineering_component_assemblies',
    );
    await database.customStatement('DROP TABLE engineering_topology_groups');
    await database.customStatement(
      'DROP TABLE engineering_compatibility_profiles',
    );
    await database.customStatement('DROP TABLE engineering_topology_profiles');
    await database.customStatement('DROP TABLE engineering_assembly_profiles');
    await database.customStatement('DROP TABLE engineering_port_instances');
    await database.customStatement(
      'DROP TABLE component_engineering_memberships',
    );
    await database.customStatement('DROP TABLE project_engineering_systems');
    await database.customStatement('DROP TABLE engineering_family_definitions');
    await database.customStatement('DROP TABLE panel_generation_configs');
    await database.customStatement('DROP TABLE component_reference_bindings');
    await database.customStatement('DROP TABLE engineering_reference_catalogs');
    await database.customStatement('PRAGMA user_version = 12');
    await database.close();
    database = openDatabase();
    panels = DriftPanelGenerationRepository(
      database,
      originDeviceId: 'panel-test',
    );
    data = await panels.load(project.id);
    expect(data.panels, isEmpty);
    expect(data.protection.rulesets.single.id, rule.id);
    expect(
      (await database.select(database.electricalCircuits).get()).single.id,
      'circuit-1',
    );
    expect(database.schemaVersion, 23);
    await panels.save(config());
    await panels.archive(project.id, 'generated-panel');
    data = await panels.load(project.id);
    expect(data.panels, isEmpty);
    expect(
      data.protection.recalculation.retired.any((r) => r.key == key),
      isTrue,
    );
    await panels.save(config());
    data = await panels.load(project.id);
    expect(data.status(data.panels.single), 'Proposed');
    await database.close();
    await directory.delete(recursive: true);
  });
}
