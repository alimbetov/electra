import 'package:electra_mobile/data/repositories/drift_electrical_circuit_repository.dart';
import 'package:electra_mobile/data/repositories/drift_electrical_load_repository.dart';
import 'package:electra_mobile/data/repositories/drift_dependency_recalculation_repository.dart';
import 'package:electra_mobile/data/repositories/drift_protection_repository.dart';
import 'package:electra_mobile/data/repositories/drift_manufacturer_repository.dart';

import 'dart:convert';

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
  test('manufacturer versions, strict choices and design snapshots survive restart without changing protection', () async {
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
    var manufacturers = DriftManufacturerRepository(
      database,
      originDeviceId: 'catalog-test',
    );
    ManufacturerProductVariant product(
      String id,
      String brand,
      double current, {
      double? voltage = 230,
    }) => ManufacturerProductVariant(
      id: id,
      manufacturer: brand,
      series: 'Test series',
      sku: 'TEST-$id',
      displayName: 'Fictional test variant $id',
      functionalRole: FunctionalDeviceRole.mcb,
      ratedCurrentA: current,
      ratedVoltageV: voltage,
      breakingCapacityKa: 6,
      poles: 2,
      tripCurve: 'C',
      currentKind: ProductCurrentKind.ac,
      moduleWidthUnits: 2,
      widthMm: 36,
      metadata: const {
        'sourceReference': 'Fictional fixture; not vendor specifications',
      },
    );
    ManufacturerCatalog catalog(
      String id,
      String brand,
      String version,
      List<ManufacturerProductVariant> products,
    ) => ManufacturerCatalog(
      id: id,
      manufacturer: brand,
      catalogVersion: version,
      region: 'KZ',
      sourceReference: 'Fictional catalog test fixture',
      products: products,
    );
    final alpha = catalog('alpha', 'Brand A', '1', [
      product('a10', 'Brand A', 10),
      product('a16', 'Brand A', 16),
      product('missing', 'Brand A', 10, voltage: null),
    ]);
    final beta = catalog('beta', 'Brand B', '1', [
      product('b10', 'Brand B', 10),
      product('b16', 'Brand B', 16),
    ]);
    await manufacturers.importCatalog(alpha);
    await manufacturers.importCatalog(beta);
    var data = await manufacturers.load(project.id),
        circuit = (await manufacturers.load(project.id))
            .protection
            .circuits
            .single;
    expect(data.candidates(circuit).map((c) => c.product.id).toSet(), {
      'a10',
      'b10',
    });
    expect(
      data
          .candidates(circuit, includeRejected: true)
          .firstWhere((c) => c.product.id == 'missing')
          .match
          .issues,
      contains('Missing rated voltage.'),
    );
    final requirement = circuit.fingerprint;
    final before = await (database.select(
      database.projectDerivedResults,
    )..where((r) => r.nodeKey.equals('protection:circuit-1'))).getSingle();
    await expectLater(
      manufacturers.selectProduct(
        projectId: project.id,
        circuitId: 'circuit-1',
        productId: 'missing',
        expectedRequirementFingerprint: requirement,
      ),
      throwsStateError,
    );
    await manufacturers.selectProduct(
      projectId: project.id,
      circuitId: 'circuit-1',
      productId: 'a10',
      expectedRequirementFingerprint: requirement,
    );
    data = await manufacturers.load(project.id);
    expect(data.selectionStatus(data.protection.circuits.single), 'Selected');
    await manufacturers.selectProduct(
      projectId: project.id,
      circuitId: 'circuit-1',
      productId: 'b10',
      expectedRequirementFingerprint: requirement,
    );
    final after = await (database.select(
      database.projectDerivedResults,
    )..where((r) => r.nodeKey.equals('protection:circuit-1'))).getSingle();
    expect(after.fingerprint, before.fingerprint);
    expect(after.resultJson, before.resultJson);
    expect(after.revision, before.revision);
    await database.close();
    database = openDatabase();
    manufacturers = DriftManufacturerRepository(
      database,
      originDeviceId: 'catalog-test',
    );
    repository = DriftProtectionRepository(
      database,
      originDeviceId: 'catalog-test',
    );
    loads = DriftElectricalLoadRepository(
      database,
      originDeviceId: 'catalog-test',
    );
    data = await manufacturers.load(project.id);
    expect(data.selections['circuit-1']!.snapshot['catalogVersion'], '1');
    expect(
      (data.selections['circuit-1']!.snapshot['product'] as Map)['sku'],
      'TEST-b10',
    );
    expect(data.selectionStatus(data.protection.circuits.single), 'Selected');
    await expectLater(
      manufacturers.importCatalog(
        catalog('alpha', 'Brand A', '1', [product('a10', 'Brand A', 16)]),
      ),
      throwsStateError,
    );
    await expectLater(
      manufacturers.importCatalog(
        catalog('borrow', 'Brand A', '3', [product('a10', 'Brand A', 10)]),
      ),
      throwsStateError,
    );
    expect((await manufacturers.load(project.id)).catalogs.length, 2);
    await manufacturers.savePolicy(
      project.id,
      const ProjectManufacturerPolicy(
        preferredManufacturers: ['Brand B'],
        allowedManufacturers: ['Brand A', 'Brand B'],
        requiredRegion: 'KZ',
      ),
    );
    data = await manufacturers.load(project.id);
    circuit = data.protection.circuits.single;
    expect(circuit.fingerprint, requirement);
    expect(data.candidates(circuit).first.product.manufacturer, 'Brand B');
    expect(data.selectionStatus(circuit), 'Review required');
    await manufacturers.selectProduct(
      projectId: project.id,
      circuitId: 'circuit-1',
      productId: 'b10',
      expectedRequirementFingerprint: requirement,
    );
    final refresh = catalog('beta2', 'Brand B', '2', [
      product('b10-v2', 'Brand B', 10),
      product('b16-v2', 'Brand B', 16),
    ]);
    await manufacturers.importCatalog(refresh);
    data = await manufacturers.load(project.id);
    expect(data.selections['circuit-1']!.productId, 'b10');
    expect(data.selectionStatus(data.protection.circuits.single), 'Selected');
    await manufacturers.archiveCatalog('beta');
    data = await manufacturers.load(project.id);
    expect(
      data.selectionStatus(data.protection.circuits.single),
      'Review required',
    );
    expect(
      (data.selections['circuit-1']!.snapshot['product'] as Map)['sku'],
      'TEST-b10',
    );
    await manufacturers.selectProduct(
      projectId: project.id,
      circuitId: 'circuit-1',
      productId: 'b10-v2',
      expectedRequirementFingerprint: requirement,
    );
    final events = StreamIterator(manufacturers.watch(project.id));
    expect(await events.moveNext(), isTrue);
    Future<void> waitStale() async {
      while (await events.moveNext()) {
        if (events.current.selectionStatus(
              events.current.protection.circuits.single,
            ) ==
            'Review required')
          return;
      }
      throw StateError('No product invalidation event.');
    }

    final stale = waitStale().timeout(const Duration(seconds: 10));
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
    await stale;
    await events.cancel();
    await expectLater(
      manufacturers.selectProduct(
        projectId: project.id,
        circuitId: 'circuit-1',
        productId: 'b16-v2',
        expectedRequirementFingerprint: requirement,
      ),
      throwsStateError,
    );
    await repository.recalculate(project.id);
    data = await manufacturers.load(project.id);
    circuit = data.protection.circuits.single;
    expect(data.selections['circuit-1']!.productId, 'b10-v2');
    expect(data.selectionStatus(circuit), 'Review required');
    expect(data.candidates(circuit).map((c) => c.product.id).toSet(), {
      'a16',
      'b16-v2',
    });
    await manufacturers.selectProduct(
      projectId: project.id,
      circuitId: 'circuit-1',
      productId: 'b16-v2',
      expectedRequirementFingerprint: circuit.fingerprint,
    );
    await manufacturers.savePolicy(
      project.id,
      const ProjectManufacturerPolicy(allowedManufacturers: ['Brand A']),
    );
    data = await manufacturers.load(project.id);
    expect(
      data.selectionStatus(data.protection.circuits.single),
      'Review required',
    );
    expect(
      (data.selections['circuit-1']!.snapshot['product'] as Map)['sku'],
      'TEST-b16-v2',
    );
    await manufacturers.clearSelection(project.id, 'circuit-1');
    expect((await manufacturers.load(project.id)).selections, isEmpty);
    final archived = await (database.select(
      database.circuitProductSelections,
    )..where((r) => r.circuitId.equals('circuit-1'))).getSingle();
    expect(archived.deletedAt, isNotNull);
    expect(
      (jsonDecode(archived.snapshotJson)['product'] as Map)['sku'],
      'TEST-b16-v2',
    );
    final engine = await DriftDependencyRecalculationRepository(
      database,
      originDeviceId: 'catalog-test',
    ).load(project.id);
    expect(
      engine.session.cache.keys.any((k) => k.startsWith('product:')),
      isFalse,
    );
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
    await database.customStatement('DROP TABLE circuit_product_selections');
    await database.customStatement('DROP TABLE manufacturer_policies');
    await database.customStatement('DROP TABLE manufacturer_products');
    await database.customStatement('DROP TABLE manufacturer_catalogs');
    await database.customStatement('DROP TABLE component_reference_bindings');
    await database.customStatement('DROP TABLE engineering_reference_catalogs');
    await database.customStatement('PRAGMA user_version = 11');
    await database.close();
    database = openDatabase();
    manufacturers = DriftManufacturerRepository(
      database,
      originDeviceId: 'catalog-test',
    );
    data = await manufacturers.load(project.id);
    expect(data.catalogs, isEmpty);
    expect(data.selections, isEmpty);
    expect(data.protection.rulesets.length, 1);
    expect(database.schemaVersion, 21);
    await database.close();
    await directory.delete(recursive: true);
  });
}
