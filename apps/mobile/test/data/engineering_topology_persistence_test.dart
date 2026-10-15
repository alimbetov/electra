import 'dart:convert';

import 'package:electra_mobile/data/repositories/drift_engineering_reference_repository.dart';
import 'package:electra_mobile/data/repositories/drift_dependency_recalculation_repository.dart';
import 'package:electra_mobile/data/repositories/drift_engineering_system_repository.dart';
import 'package:electra_mobile/data/repositories/drift_engineering_topology_repository.dart';
import 'package:electra_mobile/application/engineering_topology_repository.dart';

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
    'ELV1 four persisted scenarios, topology trace, dependency guards, edition pinning and migration',
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
          'other-project',
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
        id: 'camera',
        definitionId: 'motor',
        definitionVersion: 1,
        roomId: 'room-components',
        hostSurfacePatchId: 'wall-components',
        localPosition: Point2Mm(1250, 300),
      );
      await components.saveComponent(instance);
      var topology = DriftEngineeringTopologyRepository(
        database,
        originDeviceId: 'elv1-test',
      );
      var networks = DriftEngineeringSystemRepository(
        database,
        originDeviceId: 'elv1-test',
      );
      final oldState = await DriftDependencyRecalculationRepository(
        database,
        originDeviceId: 'elv1-test',
      ).load(project.id);
      final deviceIds = [
        'switch',
        'ups',
        'outlet',
        'patch',
        'controller',
        'reader',
        'lock',
        'psu',
        'facp',
        'detector',
        'callpoint',
        'reader2',
      ];
      for (final id in deviceIds) {
        await components.saveComponent(
          ComponentInstance(
            id: id,
            definitionId: 'fictional-test-device',
            definitionVersion: 1,
            roomId: room.id,
            hostSurfacePatchId: patch.id,
            localPosition: const Point2Mm(1000, 300),
          ),
        );
      }
      final catalog = await networks.load(project.id);
      for (final entry
          in {
            'cctv': 'CCTV',
            'lan': 'LAN',
            'power': 'POWER',
            'acs': 'ACS',
            'fire': 'FIRE',
          }.entries) {
        final family = catalog.families.firstWhere(
          (f) => f.code == entry.value,
        );
        await networks.saveSystem(
          EngineeringSystem(
            id: entry.key,
            projectId: project.id,
            code: entry.key.toUpperCase(),
            name: entry.key,
            familyId: family.id,
            familyVersion: family.version,
          ),
        );
      }
      for (final entry
          in {
            'cctv': ['camera', 'switch'],
            'lan': ['switch', 'outlet', 'patch'],
            'power': ['switch', 'ups'],
            'acs': ['controller', 'reader', 'lock', 'psu', 'reader2'],
            'fire': ['facp', 'detector', 'callpoint'],
          }.entries) {
        for (final device in entry.value) {
          await networks.assign(
            project.id,
            ComponentSystemMembership(
              systemId: entry.key,
              componentId: device,
              role: 'TEST_PARTICIPANT',
            ),
          );
        }
      }
      ProfileIdentity identity(
        String id, {
        String version = '1',
      }) => ProfileIdentity(
        id: id,
        projectId: project.id,
        code: id,
        version: version,
        source:
            'Fictional test conditions, not normative or vendor specifications',
      );
      Future<void> port(
        String component,
        String code, {
        EngineeringPortKind kind = EngineeringPortKind.data,
        PortDirection direction = PortDirection.bidirectional,
        PortDirection? powerDirection,
        String protocol = 'TEST-ETH',
        String connector = 'TEST-CONNECTOR',
        double? voltage,
        double? maxV,
        int capacity = 1,
      }) => topology.savePort(
        project.id,
        EngineeringPort(
          id: '$component.$code',
          componentId: component,
          code: code,
          kind: kind,
          direction: direction,
          capacity: capacity,
          connector: connector,
          protocol: EngineeringProfileReference(id: protocol, version: '1'),
          powerDirection: powerDirection,
          voltage:
              voltage == null
                  ? null
                  : PortVoltageDomain(
                    currentKind: PortCurrentKind.dc,
                    minimumV: voltage,
                    maximumV: maxV ?? voltage,
                  ),
          templateProvenance: const EngineeringProfileReference(
            id: 'fictional-template',
            version: '1',
          ),
        ),
      );
      ConnectionCompatibilityProfile profile(
        String id,
        String family, {
        EngineeringPortKind kind = EngineeringPortKind.data,
        ConnectionLayer layer = ConnectionLayer.data,
        CompatibilityFlow flow = CompatibilityFlow.bidirectional,
        String protocol = 'TEST-ETH',
        String a = 'TEST-CONNECTOR',
        String b = 'TEST-CONNECTOR',
      }) => ConnectionCompatibilityProfile(
        identity: identity(id),
        familyCodes: [family],
        media: const [ConnectionMedium.wired],
        semanticCode: id,
        layer: layer,
        flow: flow,
        kindA: kind,
        kindB: kind,
        connectorA: a,
        connectorB: b,
        protocolA: EngineeringProfileReference(id: protocol, version: '1'),
        protocolB: EngineeringProfileReference(id: protocol, version: '1'),
      );
      EngineeringConnection connection(
        String id,
        String system,
        String a,
        String b,
        String profile, {
        String? group,
      }) => EngineeringConnection(
        id: id,
        systemId: system,
        fromPortId: a,
        toPortId: b,
        profileId: profile,
        medium: ConnectionMedium.wired,
        groupId: group,
      );
      Future<void> mapping(
        String id,
        String component,
        String a,
        String b,
        ConnectionLayer layer, {
        bool bidirectional = true,
      }) => topology.saveInternal(
        project.id,
        InternalConnectivity(
          id: id,
          componentId: component,
          fromPortId: a,
          toPortId: b,
          layer: layer,
          bidirectional: bidirectional,
          evidence: 'Declared static passive test mapping',
        ),
      );
      // CCTV shares the same physical switch with its power and LAN systems.
      await port(
        'switch',
        'POE',
        kind: EngineeringPortKind.dataPower,
        powerDirection: PortDirection.output,
        voltage: 48,
      );
      await port(
        'camera',
        'ETH',
        kind: EngineeringPortKind.dataPower,
        powerDirection: PortDirection.input,
        voltage: 44,
        maxV: 57,
      );
      final poe = profile(
        'poe',
        'CCTV',
        kind: EngineeringPortKind.dataPower,
        layer: ConnectionLayer.dataPower,
      );
      await topology.saveConnectionProfile(poe);
      final cameraLink = connection(
        'camera-link',
        'cctv',
        'switch.POE',
        'camera.ETH',
        'poe',
      );
      final events = StreamIterator(topology.watch(project.id));
      expect(await events.moveNext(), isTrue);
      final observed = () async {
        while (await events.moveNext()) {
          if (events.current.connections.any((c) => c.id == cameraLink.id))
            return;
        }
        throw StateError('No topology event');
      }();
      await topology.saveConnection(project.id, cameraLink);
      await observed.timeout(const Duration(seconds: 10));
      await events.cancel();
      await port(
        'ups',
        'OUT',
        kind: EngineeringPortKind.power,
        direction: PortDirection.output,
        powerDirection: PortDirection.output,
        voltage: 24,
        protocol: 'TEST-DC',
      );
      await port(
        'switch',
        'PWR',
        kind: EngineeringPortKind.power,
        direction: PortDirection.input,
        powerDirection: PortDirection.input,
        voltage: 24,
        protocol: 'TEST-DC',
      );
      await topology.saveConnectionProfile(
        profile(
          'dc',
          'POWER',
          kind: EngineeringPortKind.power,
          layer: ConnectionLayer.power,
          flow: CompatibilityFlow.directed,
          protocol: 'TEST-DC',
        ),
      );
      await topology.saveConnection(
        project.id,
        connection('switch-feed', 'power', 'ups.OUT', 'switch.PWR', 'dc'),
      );
      // LAN links are connected through a passive IDC -> connector mapping, not a third external cable.
      await port('outlet', 'ETH');
      await port('patch', 'REAR', connector: 'TEST-IDC');
      await port('patch', 'FRONT');
      await port('switch', 'LAN');
      await topology.saveConnectionProfile(
        profile('horizontal', 'LAN', b: 'TEST-IDC'),
      );
      await topology.saveConnectionProfile(profile('patch-cord', 'LAN'));
      await mapping(
        'patch-mapping',
        'patch',
        'patch.REAR',
        'patch.FRONT',
        ConnectionLayer.data,
      );
      await topology.saveTopologyProfile(
        TopologyProfile(
          identity: identity('lan-path'),
          shape: TopologyShape.path,
          layer: TraceLayer.data,
        ),
      );
      const link = TopologyGroup(
        id: 'lan-link',
        systemId: 'lan',
        code: 'LINK-01',
        profileId: 'lan-path',
        startPortId: 'outlet.ETH',
        endPortId: 'switch.LAN',
      );
      await topology.saveGroup(project.id, link);
      final horizontal = connection(
        'horizontal-link',
        'lan',
        'outlet.ETH',
        'patch.REAR',
        'horizontal',
        group: 'lan-link',
      );
      await topology.saveConnection(project.id, horizontal);
      await topology.saveConnection(
        project.id,
        connection(
          'patch-link',
          'lan',
          'patch.FRONT',
          'switch.LAN',
          'patch-cord',
          group: 'lan-link',
        ),
      );
      // ACS: independent reader bus and lock feed; assembly does not contain equipment.
      await port(
        'controller',
        'READER',
        kind: EngineeringPortKind.bus,
        protocol: 'TEST-OSDP',
      );
      await port(
        'reader',
        'BUS',
        kind: EngineeringPortKind.bus,
        protocol: 'TEST-OSDP',
      );
      await port(
        'reader2',
        'BUS',
        kind: EngineeringPortKind.bus,
        protocol: 'TEST-OSDP',
      );
      await topology.saveConnectionProfile(
        profile(
          'reader-bus',
          'ACS',
          kind: EngineeringPortKind.bus,
          layer: ConnectionLayer.signal,
          protocol: 'TEST-OSDP',
        ),
      );
      await topology.saveConnection(
        project.id,
        connection(
          'reader-link',
          'acs',
          'controller.READER',
          'reader.BUS',
          'reader-bus',
        ),
      );
      await expectLater(
        topology.saveConnection(
          project.id,
          connection(
            'reader-overflow',
            'acs',
            'controller.READER',
            'reader2.BUS',
            'reader-bus',
          ),
        ),
        throwsStateError,
      );
      await port(
        'psu',
        'OUT',
        kind: EngineeringPortKind.power,
        direction: PortDirection.output,
        powerDirection: PortDirection.output,
        voltage: 24,
        protocol: 'TEST-DC',
      );
      await port(
        'lock',
        'IN',
        kind: EngineeringPortKind.power,
        direction: PortDirection.input,
        powerDirection: PortDirection.input,
        voltage: 12,
        protocol: 'TEST-DC',
      );
      await topology.saveConnectionProfile(
        profile(
          'lock-feed',
          'ACS',
          kind: EngineeringPortKind.power,
          layer: ConnectionLayer.power,
          flow: CompatibilityFlow.directed,
          protocol: 'TEST-DC',
        ),
      );
      final lockFeed = connection(
        'lock-feed',
        'acs',
        'psu.OUT',
        'lock.IN',
        'lock-feed',
      );
      await expectLater(
        topology.saveConnection(project.id, lockFeed),
        throwsStateError,
      );
      await port(
        'lock',
        'IN',
        kind: EngineeringPortKind.power,
        direction: PortDirection.input,
        powerDirection: PortDirection.input,
        voltage: 24,
        protocol: 'TEST-DC',
      );
      await topology.saveConnection(project.id, lockFeed);
      await topology.saveAssemblyProfile(
        AssemblyProfile(
          identity: identity('door-profile'),
          roles: const [
            AssemblyRoleRule(code: 'READER', minimum: 1, maximum: 1),
            AssemblyRoleRule(code: 'LOCK', minimum: 1, maximum: 1),
            AssemblyRoleRule(code: 'CONTROLLER', minimum: 1, maximum: 1),
          ],
          allowSharedComponents: false,
        ),
      );
      final door = ComponentAssembly(
        id: 'door',
        code: 'D101',
        profileId: 'door-profile',
        members: const [
          AssemblyMember(componentId: 'reader', role: 'READER'),
          AssemblyMember(componentId: 'lock', role: 'LOCK'),
          AssemblyMember(componentId: 'controller', role: 'CONTROLLER'),
        ],
      );
      await topology.saveAssembly(project.id, door);
      await expectLater(
        topology.saveAssembly(
          project.id,
          ComponentAssembly(
            id: 'door2',
            code: 'D102',
            profileId: door.profileId,
            members: door.members,
          ),
        ),
        throwsStateError,
      );
      // Fire loop: distinct source/return ports and directed device internals.
      await port(
        'facp',
        'OUT',
        kind: EngineeringPortKind.bus,
        direction: PortDirection.output,
        protocol: 'TEST-LOOP',
      );
      await port(
        'facp',
        'RETURN',
        kind: EngineeringPortKind.bus,
        direction: PortDirection.input,
        protocol: 'TEST-LOOP',
      );
      for (final component in ['detector', 'callpoint']) {
        await port(
          component,
          'IN',
          kind: EngineeringPortKind.bus,
          direction: PortDirection.input,
          protocol: 'TEST-LOOP',
        );
        await port(
          component,
          'OUT',
          kind: EngineeringPortKind.bus,
          direction: PortDirection.output,
          protocol: 'TEST-LOOP',
        );
        await mapping(
          '$component-mapping',
          component,
          '$component.IN',
          '$component.OUT',
          ConnectionLayer.signal,
          bidirectional: false,
        );
      }
      await topology.saveConnectionProfile(
        profile(
          'loop-segment',
          'FIRE',
          kind: EngineeringPortKind.bus,
          layer: ConnectionLayer.signal,
          flow: CompatibilityFlow.directed,
          protocol: 'TEST-LOOP',
        ),
      );
      await topology.saveTopologyProfile(
        TopologyProfile(
          identity: identity('loop-profile'),
          shape: TopologyShape.loop,
          layer: TraceLayer.signal,
        ),
      );
      const loop = TopologyGroup(
        id: 'fire-loop',
        systemId: 'fire',
        code: 'L1',
        profileId: 'loop-profile',
        startPortId: 'facp.OUT',
        endPortId: 'facp.RETURN',
      );
      await topology.saveGroup(project.id, loop);
      await topology.saveConnection(
        project.id,
        connection(
          'fire-first',
          'fire',
          'facp.OUT',
          'detector.IN',
          'loop-segment',
          group: loop.id,
        ),
      );
      await topology.saveConnection(
        project.id,
        connection(
          'fire-second',
          'fire',
          'detector.OUT',
          'callpoint.IN',
          'loop-segment',
          group: loop.id,
        ),
      );
      await topology.saveConnection(
        project.id,
        connection(
          'fire-return',
          'fire',
          'callpoint.OUT',
          'facp.RETURN',
          'loop-segment',
          group: loop.id,
        ),
      );
      var data = await topology.load(project.id);
      expect(data.graph().findings(), isEmpty);
      final lanTrace = data.graph().trace(
        'outlet.ETH',
        layer: TraceLayer.data,
        systemId: 'lan',
      );
      expect(lanTrace.internalLinkIds, ['patch-mapping']);
      expect(lanTrace.connectionIds, ['horizontal-link', 'patch-link']);
      expect(
        data
            .graph()
            .trace(
              'facp.OUT',
              layer: TraceLayer.signal,
              direction: TopologyTraceDirection.downstream,
            )
            .portIds,
        contains('facp.RETURN'),
      );
      expect(
        data
            .graph()
            .trace(
              'camera.ETH',
              layer: TraceLayer.power,
              direction: TopologyTraceDirection.downstream,
            )
            .connectionIds,
        isEmpty,
      );
      expect((await database.select(database.cableRuns).get()), isEmpty);
      // No accidental deletion/undo cascade through system, port, placement or hierarchy.
      await expectLater(
        topology.archive(project.id, TopologyObjectKind.port, 'camera.ETH'),
        throwsStateError,
      );
      await expectLater(
        topology.archive(project.id, TopologyObjectKind.group, link.id),
        throwsStateError,
      );
      await expectLater(
        networks.detach(project.id, 'cctv', 'camera'),
        throwsStateError,
      );
      await expectLater(components.removeComponent('camera'), throwsStateError);
      await expectLater(
        components.replaceRoomComponents(
          roomId: room.id,
          instances: (await components.loadRoomComponents(
            room.id,
          )).where((c) => c.id != 'camera'),
        ),
        throwsStateError,
      );
      await expectLater(hierarchy.deleteRoom(room.id), throwsStateError);
      await expectLater(hierarchy.deleteFloor(floor.id), throwsStateError);
      await expectLater(hierarchy.deleteProject(project.id), throwsStateError);
      await expectLater(
        port(
          'camera',
          'ETH',
          kind: EngineeringPortKind.data,
          protocol: 'changed',
        ),
        throwsStateError,
      );
      await expectLater(
        topology.saveConnectionProfile(
          ConnectionCompatibilityProfile.fromMap({
            ...poe.toMap(),
            'semanticCode': 'changed',
          }),
        ),
        throwsStateError,
      );
      final v2 = ConnectionCompatibilityProfile.fromMap({
        ...poe.toMap(),
        'identity': identity('poe-v2', version: '2').toMap(),
      });
      await topology.saveConnectionProfile(v2);
      final other = await hierarchyService.createProject(
        const ProjectFormDraft(
          name: 'Foreign',
          reference: 'Foreign',
          measurementSystem: MeasurementSystem.metric,
          defaultStructuralHeightMm: 3200,
          defaultFinishedCeilingHeightMm: 3000,
        ),
      );
      await expectLater(
        topology.savePort(other.id, data.ports.first),
        throwsStateError,
      );
      final newState = await DriftDependencyRecalculationRepository(
        database,
        originDeviceId: 'elv1-test',
      ).load(project.id);
      expect(newState.session.fingerprints, oldState.session.fingerprints);
      // Deleting a connection preserves route infrastructure and leaves its former group explicitly draft.
      final beforeRow =
          await (database.select(database.engineeringPortConnections)
            ..where((r) => r.id.equals(horizontal.id))).getSingle();
      await topology.archive(
        project.id,
        TopologyObjectKind.connection,
        horizontal.id,
      );
      data = await topology.load(project.id);
      expect(
        data.graph().groupFindings(link).map((f) => f.code),
        contains('GROUP_INCOMPLETE'),
      );
      await topology.saveConnection(project.id, horizontal);
      final restoredRow =
          await (database.select(database.engineeringPortConnections)
            ..where((r) => r.id.equals(horizontal.id))).getSingle();
      expect(restoredRow.createdAt, beforeRow.createdAt);
      expect(restoredRow.revision, beforeRow.revision + 2);
      // ELV2 binds five vendor-neutral profiles across four systems atomically.
      var references = DriftEngineeringReferenceRepository(
        database,
        originDeviceId: 'elv2-test',
        idGenerator: FixedSequenceIdGenerator([
          'catalog-camera',
          'catalog-outlet',
          'catalog-reader',
          'catalog-lock',
          'catalog-detector-in',
          'catalog-detector-out',
        ]),
      );
      final referenceCatalog = EngineeringReferenceCatalog.fromMap(
        jsonDecode(
              await File(
                '../../docs/examples/elv2-reference-catalog.json',
              ).readAsString(),
            )
            as Map<String, dynamic>,
      );
      await references.importCatalog(project.id, referenceCatalog);
      final profileSystems = {
        'CAMERA': 'cctv',
        'OUTLET': 'lan',
        'READER': 'acs',
        'LOCK': 'acs',
        'DETECTOR': 'fire',
      };
      for (final entry in profileSystems.entries) {
        final id = 'catalog-${entry.key.toLowerCase()}-device';
        await components.saveComponent(
          ComponentInstance(
            id: id,
            definitionId: 'product-neutral',
            definitionVersion: 1,
            roomId: room.id,
            hostSurfacePatchId: patch.id,
            localPosition: const Point2Mm(1000, 300),
          ),
        );
        await networks.assign(
          project.id,
          ComponentSystemMembership(
            systemId: entry.value,
            componentId: id,
            role: 'PROFILED_DEVICE',
          ),
        );
        await references.bind(project.id, id, referenceCatalog.id, entry.key);
      }
      final bound = await references.load(project.id);
      expect(bound.bindings.length, 5);
      await expectLater(
        references.importCatalog(
          project.id,
          EngineeringReferenceCatalog.fromMap({
            ...referenceCatalog.toMap(),
            'source': 'changed in place',
          }),
        ),
        throwsStateError,
      );
      final catalogV2 = EngineeringReferenceCatalog.fromMap({
        ...referenceCatalog.toMap(),
        'id': 'fictional-elv2-v2',
        'version': '2',
      });
      await references.importCatalog(project.id, catalogV2);
      await expectLater(
        references.bind(
          project.id,
          'catalog-camera-device',
          catalogV2.id,
          'CAMERA',
        ),
        throwsStateError,
      );
      await expectLater(
        references.bind(
          other.id,
          'catalog-camera-device',
          referenceCatalog.id,
          'CAMERA',
        ),
        throwsStateError,
      );
      await expectLater(
        references.unbind(project.id, 'catalog-camera-device'),
        throwsStateError,
      );
      await expectLater(
        components.removeComponent('catalog-camera-device'),
        throwsStateError,
      );
      final portRows =
          await database.select(database.engineeringPortInstances).get();
      // Rollback restores any ports inserted before a later generated identity collides.
      final faulty = DriftEngineeringReferenceRepository(
        database,
        originDeviceId: 'elv2-rollback',
        idGenerator: FixedSequenceIdGenerator([
          'rollback-new',
          'catalog-detector-in',
        ]),
      );
      await components.saveComponent(
        ComponentInstance(
          id: 'rollback-device',
          definitionId: 'product-neutral',
          definitionVersion: 1,
          roomId: room.id,
          hostSurfacePatchId: patch.id,
          localPosition: const Point2Mm(1000, 300),
        ),
      );
      await networks.assign(
        project.id,
        const ComponentSystemMembership(
          systemId: 'fire',
          componentId: 'rollback-device',
          role: 'TEST',
        ),
      );
      await expectLater(
        faulty.bind(
          project.id,
          'rollback-device',
          referenceCatalog.id,
          'DETECTOR',
        ),
        throwsStateError,
      );
      expect(
        (await database.select(database.engineeringPortInstances).get()).length,
        portRows.length,
      );
      expect((await references.load(project.id)).bindings.length, 5);
      await database.close();
      database = openDatabase();
      topology = DriftEngineeringTopologyRepository(
        database,
        originDeviceId: 'elv1-restart',
      );
      data = await topology.load(project.id);
      references = DriftEngineeringReferenceRepository(
        database,
        originDeviceId: 'elv2-restart',
        idGenerator: FixedSequenceIdGenerator([]),
      );
      final restoredBindings = await references.load(project.id);
      expect(restoredBindings.catalogs.length, 2);
      expect(
        restoredBindings.bindings.map((b) => b.toMap()),
        bound.bindings.map((b) => b.toMap()),
      );
      expect(
        restoredBindings.bindings.every((b) => b.catalogVersion == '1'),
        isTrue,
      );
      expect(data.graph().findings(), isEmpty);
      expect(
        data.connections.firstWhere((c) => c.id == cameraLink.id).profileId,
        'poe',
      );
      expect(
        data.connectionProfiles
            .firstWhere((p) => p.id == 'poe')
            .identity
            .version,
        '1',
      );
      expect(
        data.ports
            .firstWhere((p) => p.id == 'camera.ETH')
            .templateProvenance!
            .version,
        '1',
      );
      expect(
        data.graph().trace('outlet.ETH', layer: TraceLayer.data).portIds,
        lanTrace.portIds,
      );
      expect(data.assemblies.single.members.map((m) => m.componentId).toSet(), {
        'reader',
        'lock',
        'controller',
      });
      // Explicit edition migration preserves port identities after retirement/release.
      final cameraBinding = restoredBindings.bindings.singleWhere(
        (b) => b.componentId == 'catalog-camera-device',
      );
      final cameraPort = data.ports.singleWhere(
        (p) => p.id == cameraBinding.portIds.single,
      );
      await expectLater(
        topology.savePort(
          project.id,
          EngineeringPort.fromMap({
            ...cameraPort.toMap(),
            'connector': 'silent edit',
          }),
        ),
        throwsStateError,
      );
      await topology.archive(
        project.id,
        TopologyObjectKind.port,
        cameraPort.id,
      );
      await references.unbind(project.id, cameraBinding.componentId);
      await references.bind(
        project.id,
        cameraBinding.componentId,
        catalogV2.id,
        'CAMERA',
      );
      final migratedBinding = (await references.load(project.id)).bindings
          .singleWhere((b) => b.componentId == cameraBinding.componentId);
      expect(migratedBinding.catalogVersion, '2');
      expect(migratedBinding.portIds, cameraBinding.portIds);
      expect(
        (await topology.load(project.id)).ports
            .singleWhere((p) => p.id == cameraPort.id)
            .templateProvenance!
            .version,
        '2',
      );
      // Additive v14 -> v15 migration retains ELV0 network participation and placement identities.
      for (final table in [
        'engineering_port_connections',
        'engineering_internal_mappings',
        'engineering_component_assemblies',
        'engineering_topology_groups',
        'engineering_compatibility_profiles',
        'engineering_topology_profiles',
        'engineering_assembly_profiles',
        'engineering_port_instances',
      ]) {
        await database.customStatement('DROP TABLE $table');
      }
      await database.customStatement('DROP TABLE component_reference_bindings');
      await database.customStatement(
        'DROP TABLE engineering_reference_catalogs',
      );
      await database.customStatement('PRAGMA user_version = 14');
      await database.close();
      database = openDatabase();
      topology = DriftEngineeringTopologyRepository(
        database,
        originDeviceId: 'elv1-migration',
      );
      data = await topology.load(project.id);
      expect(database.schemaVersion, 21);
      expect(data.ports, isEmpty);
      expect(data.connections, isEmpty);
      expect(data.systems.systems.length, 5);
      expect(
        data.systems.memberships.where((m) => m.componentId == 'switch').length,
        3,
      );
      expect(data.systems.components.length, deviceIds.length + 7);
      await database.close();
      await directory.delete(recursive: true);
    },
  );
}
