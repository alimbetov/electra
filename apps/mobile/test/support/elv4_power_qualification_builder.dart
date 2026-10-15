import 'package:electra_mobile/application/elv_command_result.dart';
import 'package:electra_mobile/application/elv_design_revision_command.dart';
import 'package:electra_mobile/application/geometry_repository.dart';
import 'package:electra_mobile/application/power_mutation_command.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/drift_component_instance_repository.dart';
import 'package:electra_mobile/data/repositories/drift_elv_design_revision_repository.dart';
import 'package:electra_mobile/data/repositories/drift_engineering_topology_repository.dart';
import 'package:electra_mobile/data/repositories/drift_geometry_repository.dart';
import 'package:electra_mobile/data/repositories/drift_power_command_service.dart';
import 'package:electra_mobile/data/repositories/drift_project_hierarchy_repository.dart';
import 'package:electra_mobile/domain/project_models.dart';
import 'package:engineering_core/engineering_core.dart';

final class Elv4QualificationBuilder {
  Elv4QualificationBuilder(
    this.database, {
    this.projectId = 'elv4-qualification',
    this.revisionId = 'REV-1',
    DateTime? instant,
  }) : instant = instant ?? DateTime.utc(2026, 10, 15, 21),
       hierarchy = DriftProjectHierarchyRepository(database),
       geometry = DriftGeometryRepository(database, originDeviceId: 'qualification'),
       components = DriftComponentInstanceRepository(
         database,
         originDeviceId: 'qualification',
       ),
       topology = DriftEngineeringTopologyRepository(
         database,
         originDeviceId: 'qualification',
       ),
       revisions = DriftElvDesignRevisionRepository(
         database,
         originDeviceId: 'qualification',
         now: () => instant ?? DateTime.utc(2026, 10, 15, 21),
       ),
       power = DriftPowerCommandService(
         database,
         originDeviceId: 'qualification',
         now: () => instant ?? DateTime.utc(2026, 10, 15, 21),
       );

  final AppDatabase database;
  final String projectId;
  final String revisionId;
  final DateTime instant;
  final DriftProjectHierarchyRepository hierarchy;
  final DriftGeometryRepository geometry;
  final DriftComponentInstanceRepository components;
  final DriftEngineeringTopologyRepository topology;
  final DriftElvDesignRevisionRepository revisions;
  final DriftPowerCommandService power;

  String get floorId => '$projectId-floor';
  String get roomId => '$projectId-room';
  String get patchId => '$projectId-wall';

  Future<void> createStructuralBaseline() async {
    await hierarchy.saveProject(
      ProjectRecord(
        id: projectId,
        name: 'ELV4 qualification',
        reference: 'ELV4-P8',
        measurementSystem: MeasurementSystem.metric,
        defaultStructuralHeightMm: 3200,
        defaultFinishedCeilingHeightMm: 3000,
        revision: 1,
        createdAt: instant,
        updatedAt: instant,
        originDeviceId: 'qualification',
      ),
    );
    await hierarchy.saveFloor(
      FloorRecord(
        id: floorId,
        projectId: projectId,
        name: 'Qualification floor',
        code: 'Q1',
        sortOrder: 1,
        revision: 1,
        createdAt: instant,
        updatedAt: instant,
        originDeviceId: 'qualification',
      ),
    );
    await hierarchy.saveRoom(
      RoomRecord(
        id: roomId,
        floorId: floorId,
        name: 'Qualification room',
        type: RoomType.technical,
        category: RoomCategory.technical,
        widthMm: 10000,
        depthMm: 8000,
        revision: 1,
        createdAt: instant,
        updatedAt: instant,
        originDeviceId: 'qualification',
      ),
    );
    await geometry.replaceRoomGeometry(
      RoomGeometrySnapshot(
        roomId: roomId,
        patches: [
          SurfacePatch(
            id: patchId,
            roomId: roomId,
            surfaceId: 'WALL-A',
            frame: LocalCoordinateFrame(
              origin: const Point3Mm(0, 0, 0),
              uAxis: const Vector3D(1, 0, 0),
              vAxis: const Vector3D(0, 0, 1),
            ),
            boundary: Polygon2Mm(const [
              Point2Mm(0, 0),
              Point2Mm(10000, 0),
              Point2Mm(10000, 3200),
              Point2Mm(0, 3200),
            ]),
            orientation: SurfaceOrientation.vertical,
          ),
        ],
      ),
    );
    final result = await revisions.bootstrap(
      BootstrapProjectDesignRevisionCommand(
        commandId: '$projectId-bootstrap',
        projectId: projectId,
        revisionId: revisionId,
        code: 'R1',
      ),
    );
    if (result is! ElvCommandSuccess<ProjectDesignRevision>) {
      throw StateError('Unable to bootstrap qualification revision: $result');
    }
  }

  Future<void> addComponent(
    String id, {
    int xMm = 500,
    Iterable<EngineeringPort> ports = const [],
  }) async {
    await components.saveComponent(
      ComponentInstance(
        id: id,
        definitionId: 'qualification/$id',
        definitionVersion: 1,
        roomId: roomId,
        hostSurfacePatchId: patchId,
        localPosition: Point2Mm(xMm, 1000),
      ),
    );
    for (final port in ports) {
      if (port.componentId != id) {
        throw ArgumentError('Port ${port.id} does not belong to $id.');
      }
      await topology.savePort(projectId, port);
    }
  }

  EngineeringPort powerPort(
    String componentId,
    String code, {
    PortDirection direction = PortDirection.input,
    EngineeringPortKind kind = EngineeringPortKind.power,
    double? limitW,
    double? demandW,
  }) => EngineeringPort(
    id: '$componentId-$code',
    componentId: componentId,
    code: code,
    kind: kind,
    direction: direction,
    capacity: 1,
    connector: kind == EngineeringPortKind.fiber ? 'LC' : 'POWER',
    voltage: const PortVoltageDomain(
      currentKind: PortCurrentKind.dc,
      minimumV: 10,
      maximumV: 60,
    ),
    powerDirection: direction,
    powerLimitW: limitW,
    powerDemandW: demandW,
  );

  PowerDefinitionRef definition(PowerDefinitionKind kind, String code) =>
      PowerDefinitionRef(
        catalogId: 'elv4-qualification',
        catalogVersion: '1',
        definitionKind: kind,
        definitionCode: code,
        definitionVersion: '1',
        definitionSchema: 'electra.elv4-qualification.v1',
        contentSha256:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        sourceRef: 'P8 qualification fixture',
      );

  PowerPortBinding portBinding(
    String portId,
    PowerPortRole role, {
    PowerCurrentKind currentKind = PowerCurrentKind.dc,
  }) => PowerPortBinding(
    portId: portId,
    profileRef: definition(PowerDefinitionKind.port, 'PORT-$portId'),
    role: role,
    voltageEnvelope: PowerVoltageEnvelope(
      currentKind: currentKind,
      minV: PowerRational.integer(currentKind == PowerCurrentKind.ac ? 180 : 10),
      nominalV:
          PowerRational.integer(currentKind == PowerCurrentKind.ac ? 230 : 48),
      maxV: PowerRational.integer(currentKind == PowerCurrentKind.ac ? 260 : 60),
      frequencyHz: currentKind == PowerCurrentKind.ac
          ? PowerRational.integer(50)
          : null,
    ),
    terminalRoles: const ['POWER'],
    ownership: PowerProjectionOwnership([
      for (final field in [
        PowerProjectionField.currentKind,
        PowerProjectionField.voltageEnvelope,
        PowerProjectionField.powerDirection,
        PowerProjectionField.terminalRoles,
        if (currentKind == PowerCurrentKind.ac) PowerProjectionField.frequency,
      ])
        PowerProjectionClaim(
          field: field,
          ownerKind: PowerProjectionOwnerKind.elv4,
          ownerRef: 'P8-QUALIFICATION',
        ),
    ]),
  );

  PowerLossDefinition get efficientLoss => PowerLossDefinition(
    efficiency: PowerRational.fromFraction(9, 10),
    idleW: PowerRational.zero,
    idleAccounting: PowerIdleAccounting.includesIdle,
  );

  PowerDependencyKey dependency(String entityId, {String purpose = 'INPUT'}) =>
      PowerDependencyKey(
        projectId: projectId,
        revisionId: revisionId,
        kind: PowerDependencyKind.definition,
        entityId: entityId,
        purpose: purpose,
      );

  Future<PowerMutationReceipt> bindComponent(
    String componentId,
    Iterable<PowerComponentCapability> capabilities, {
    required int expectedRevision,
    Iterable<String> ownLoadContributionIds = const [],
  }) => power.execute(
    BindPowerComponentCommand(
      operationId: 'bind-component-$componentId',
      projectId: projectId,
      designRevisionId: revisionId,
      expectedRevision: expectedRevision,
      changedDependencies: [dependency('COMPONENT-$componentId')],
      bindingId: 'binding-$componentId',
      binding: PowerComponentBinding(
        componentId: componentId,
        capabilities: capabilities,
        definitionRefs: [definition(PowerDefinitionKind.component, componentId)],
        ownLoadContributionIds: ownLoadContributionIds,
      ),
    ),
  );

  Future<PowerMutationReceipt> bindPort(
    String portId,
    PowerPortRole role, {
    required int expectedRevision,
    PowerCurrentKind currentKind = PowerCurrentKind.dc,
  }) => power.execute(
    BindPowerPortCommand(
      operationId: 'bind-port-$portId',
      projectId: projectId,
      designRevisionId: revisionId,
      expectedRevision: expectedRevision,
      changedDependencies: [dependency('PORT-$portId')],
      bindingId: 'binding-$portId',
      binding: portBinding(portId, role, currentKind: currentKind),
    ),
  );
}
