import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:electra_mobile/application/geometry_repository.dart';
import 'package:electra_mobile/application/id_generator.dart';
import 'package:electra_mobile/application/project_hierarchy_service.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/database/drift_unit_of_work.dart';
import 'package:electra_mobile/data/repositories/drift_component_instance_repository.dart';
import 'package:electra_mobile/data/repositories/drift_engineering_reference_repository.dart';
import 'package:electra_mobile/data/repositories/drift_engineering_system_repository.dart';
import 'package:electra_mobile/data/repositories/drift_engineering_topology_repository.dart';
import 'package:electra_mobile/data/repositories/drift_geometry_repository.dart';
import 'package:electra_mobile/data/repositories/drift_project_hierarchy_repository.dart';
import 'package:electra_mobile/domain/project_models.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ELV2 typed catalog import is atomic and four discipline connections retain exact editions after restart', () async {
    final directory = await Directory.systemTemp.createTemp('electra-elv2-');
    final file = File('${directory.path}/project.sqlite');
    var database = AppDatabase(NativeDatabase(file));
    addTearDown(() async {
      await database.close();
      await directory.delete(recursive: true);
    });
    final hierarchy = DriftProjectHierarchyRepository(database);
    final service = ProjectHierarchyService(
      projects: hierarchy,
      floors: hierarchy,
      rooms: hierarchy,
      unitOfWork: DriftUnitOfWork(database),
      idGenerator: FixedSequenceIdGenerator(['p', 'f', 'r']),
      originDeviceId: 'test',
    );
    final project = await service.createProject(
      const ProjectFormDraft(
        name: 'ELV2',
        reference: 'ELV2',
        measurementSystem: MeasurementSystem.metric,
        defaultStructuralHeightMm: 3200,
        defaultFinishedCeilingHeightMm: 3000,
      ),
    );
    final floor = await service.createFloor(
      projectId: project.id,
      draft: const FloorFormDraft(name: 'Floor', code: 'F', sortOrder: 1),
    );
    final room = await service.createRoom(
      floorId: floor.id,
      draft: const RoomFormDraft(
        name: 'Room',
        type: RoomType.workshop,
        category: RoomCategory.technical,
        widthMm: 6000,
        depthMm: 5000,
      ),
    );
    final patch = SurfacePatch(
      id: 'wall',
      roomId: room.id,
      surfaceId: 'Wall',
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
    await DriftGeometryRepository(
      database,
      originDeviceId: 'test',
    ).replaceRoomGeometry(
      RoomGeometrySnapshot(roomId: room.id, patches: [patch]),
    );
    final components = DriftComponentInstanceRepository(
      database,
      originDeviceId: 'test',
    );
    final systems = DriftEngineeringSystemRepository(
      database,
      originDeviceId: 'test',
    );
    var topology = DriftEngineeringTopologyRepository(
      database,
      originDeviceId: 'test',
    );
    var references = DriftEngineeringReferenceRepository(
      database,
      originDeviceId: 'test',
      idGenerator: FixedSequenceIdGenerator(
        List.generate(30, (i) => 'port-$i'),
      ),
    );
    final catalog = EngineeringReferenceCatalog.fromMap(
      jsonDecode(
        File('../../docs/examples/elv2-interface-catalog.json')
            .readAsStringSync(),
      ) as Map<String, dynamic>,
    );
    for (final discipline in ReferenceDiscipline.values) {
      final family = (await systems.load(project.id)).families
          .firstWhere((f) => f.code == discipline.name.toUpperCase());
      await systems.saveSystem(
        EngineeringSystem(
          id: discipline.name,
          projectId: project.id,
          code: discipline.name.toUpperCase(),
          name: discipline.name,
          familyId: family.id,
          familyVersion: family.version,
        ),
      );
    }
    // The second profile fails after the first has been inserted: both must roll back.
    final badMap =
        jsonDecode(jsonEncode(catalog.toMap())) as Map<String, dynamic>;
    badMap['id'] = 'failed-edition';
    badMap['code'] = 'FAILED';
    badMap['vocabulary']['compatibility'][1]['familyCodes'] = ['UNKNOWN'];
    await expectLater(
      references.importCatalog(
        project.id,
        EngineeringReferenceCatalog.fromMap(badMap),
      ),
      throwsStateError,
    );
    expect((await references.load(project.id)).catalogs, isEmpty);
    expect((await topology.load(project.id)).connectionProfiles, isEmpty);
    await references.importCatalog(project.id, catalog);
    await references.importCatalog(project.id, catalog);
    expect((await topology.load(project.id)).connectionProfiles.length, 5);
    // Existing catalog JSON without vocabulary remains reimportable unchanged.
    final legacy = EngineeringReferenceCatalog.fromMap(
      jsonDecode(
        File('../../docs/examples/elv2-reference-catalog.json')
            .readAsStringSync(),
      ) as Map<String, dynamic>,
    );
    await references.importCatalog(project.id, legacy);
    await references.importCatalog(project.id, legacy);
    for (final profile in catalog.profiles) {
      await components.saveComponent(
        ComponentInstance(
          id: profile.code,
          definitionId: 'fictional-device',
          definitionVersion: 1,
          roomId: room.id,
          hostSurfacePatchId: patch.id,
          localPosition: const Point2Mm(1000, 300),
        ),
      );
      await systems.assign(
        project.id,
        ComponentSystemMembership(
          systemId: profile.discipline.name,
          componentId: profile.code,
          role: 'TEST',
        ),
      );
      await references.bind(project.id, profile.code, catalog.id, profile.code);
    }
    var snapshot = await topology.load(project.id);
    String port(String component, String code) => snapshot.ports
        .singleWhere((p) => p.componentId == component && p.code == code)
        .id;
    Future<void> connect(
      String id,
      String system,
      String a,
      String ac,
      String b,
      String bc,
      String rule,
    ) => topology.saveConnection(
      project.id,
      EngineeringConnection(
        id: id,
        systemId: system,
        fromPortId: port(a, ac),
        toPortId: port(b, bc),
        profileId: '${catalog.id}/compatibility/$rule',
        medium: ConnectionMedium.wired,
      ),
    );
    await connect(
      'camera',
      'cctv',
      'POE_SWITCH',
      'ETH',
      'CAMERA',
      'ETH',
      'CCTV-POE',
    );
    await connect(
      'horizontal',
      'lan',
      'OUTLET',
      'ETH',
      'PATCH',
      'REAR',
      'LAN-LINK',
    );
    await connect(
      'patch-cord',
      'lan',
      'PATCH',
      'FRONT',
      'LAN_SWITCH',
      'ETH',
      'LAN-LINK',
    );
    await topology.saveInternal(
      project.id,
      InternalConnectivity(
        id: 'patch',
        componentId: 'PATCH',
        fromPortId: port('PATCH', 'REAR'),
        toPortId: port('PATCH', 'FRONT'),
        layer: ConnectionLayer.data,
        bidirectional: true,
        evidence: 'Declared fictional passive patch mapping',
      ),
    );
    await connect(
      'reader',
      'acs',
      'CONTROLLER',
      'BUS',
      'READER',
      'BUS',
      'ACS-BUS',
    );
    await connect(
      'lock',
      'acs',
      'CONTROLLER',
      'PWR',
      'LOCK',
      'PWR',
      'ACS-POWER',
    );
    await connect(
      'loop-out',
      'fire',
      'FACP',
      'OUT',
      'DETECTOR',
      'IN',
      'FIRE-LOOP',
    );
    await connect(
      'loop-return',
      'fire',
      'DETECTOR',
      'OUT',
      'FACP',
      'RETURN',
      'FIRE-LOOP',
    );
    await topology.saveInternal(
      project.id,
      InternalConnectivity(
        id: 'detector',
        componentId: 'DETECTOR',
        fromPortId: port('DETECTOR', 'IN'),
        toPortId: port('DETECTOR', 'OUT'),
        layer: ConnectionLayer.signal,
        bidirectional: false,
        evidence: 'Declared fictional passive loop continuation',
      ),
    );
    snapshot = await topology.load(project.id);
    expect(snapshot.graph().findings(), isEmpty);
    final traces = {
      port('POE_SWITCH', 'ETH'): TraceLayer.power,
      port('OUTLET', 'ETH'): TraceLayer.data,
      port('CONTROLLER', 'BUS'): TraceLayer.signal,
      port('CONTROLLER', 'PWR'): TraceLayer.power,
      port('FACP', 'OUT'): TraceLayer.signal,
    };
    final expectedTraces = {
      for (final e in traces.entries)
        e.key: snapshot.graph().trace(e.key, layer: e.value).portIds,
    };
    final originalPorts = snapshot.ports.map((p) => p.toMap()).toList();
    final originalBindings = (await references.load(project.id)).bindings
        .map((b) => b.toMap())
        .toList();
    final nextMap =
        jsonDecode(jsonEncode(catalog.toMap())) as Map<String, dynamic>;
    nextMap['id'] = 'fictional-interfaces-v2';
    nextMap['version'] = '2';
    nextMap['vocabulary']['interfaces'][1]['powerDemandW'] = 9;
    final next = EngineeringReferenceCatalog.fromMap(nextMap);
    await references.importCatalog(project.id, next);
    await expectLater(
      references.bind(project.id, 'CAMERA', next.id, 'CAMERA'),
      throwsStateError,
    );
    final oldLink = snapshot.connections.singleWhere((c) => c.id == 'camera');
    await expectLater(
      topology.saveConnection(
        project.id,
        EngineeringConnection.fromMap({
          ...oldLink.toMap(),
          'profileId': '${next.id}/compatibility/CCTV-POE',
        }),
      ),
      throwsStateError,
    );
    await expectLater(
      topology.savePort(
        project.id,
        EngineeringPort.fromMap({
          ...snapshot.ports.first.toMap(),
          'interfaceProvenance': {'id': 'other-interface', 'version': '1'},
        }),
      ),
      throwsStateError,
    );
    await database.close();
    database = AppDatabase(NativeDatabase(file));
    topology = DriftEngineeringTopologyRepository(
      database,
      originDeviceId: 'restart',
    );
    references = DriftEngineeringReferenceRepository(
      database,
      originDeviceId: 'restart',
      idGenerator: FixedSequenceIdGenerator([]),
    );
    final restored = await references.load(project.id);
    snapshot = await topology.load(project.id);
    expect(restored.catalogs.length, 3);
    expect(
      restored.catalogs.singleWhere((c) => c.id == catalog.id).toMap(),
      catalog.toMap(),
    );
    expect(restored.bindings.map((b) => b.toMap()), originalBindings);
    expect(snapshot.ports.map((p) => p.toMap()), originalPorts);
    expect(snapshot.connectionProfiles.length, 10);
    expect(snapshot.graph().findings(), isEmpty);
    for (final e in traces.entries) {
      expect(
        snapshot.graph().trace(e.key, layer: e.value).portIds,
        expectedTraces[e.key],
      );
    }
    final camera = snapshot.ports.singleWhere((p) => p.componentId == 'CAMERA');
    expect(camera.powerDemandW, 8);
    expect(camera.interfaceProvenance!.version, '1');
    expect(camera.protocol!.version, '1');
    expect(
      snapshot.connections.singleWhere((c) => c.id == 'camera').profileId,
      oldLink.profileId,
    );
    // Exact generated compatibility survives persistence, including its ordered interface references.
    expect(
      snapshot.connectionProfiles
          .singleWhere((p) => p.id == oldLink.profileId)
          .toMap(),
      catalog.connectionProfiles(project.id).first.toMap(),
    );
  });
}
