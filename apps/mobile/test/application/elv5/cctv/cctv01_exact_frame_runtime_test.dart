import 'package:electra_mobile/application/component_instance_repository.dart';
import 'package:electra_mobile/application/geometry_repository.dart';
import 'package:electra_mobile/application/elv5/calculation/elv5_blocked_capture.dart';
import 'package:electra_mobile/application/elv5/calculation/elv5_calculation_runtime.dart';
import 'package:electra_mobile/application/elv5/cctv/cctv01_geometry_contract.dart';
import 'package:electra_mobile/application/elv5/cctv/cctv01_runtime.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CCTV-01 uses exact v2 axes for engineering coordinates', () async {
    final resolver = Cctv01PersistedInputResolver(
      contractSource: _ContractSource(_contract()),
      components: const _Components(),
      geometry: _Geometry(hostSkew: 0),
      nowUtc: () => DateTime.utc(2026, 10, 17),
    );

    final captured = await resolver.capture(_request());

    expect(captured.value.opticalCenter.x, Elv5Rational.integer(0));
    expect(captured.value.opticalCenter.y, Elv5Rational.integer(100));
    expect(captured.value.opticalCenter.z, Elv5Rational.integer(200));
    expect(captured.inputFingerprint, matches(RegExp(r'^[0-9a-f]{64}$')));
  });

  test('legacy frame outside declared compatibility tolerance blocks capture', () async {
    final resolver = Cctv01PersistedInputResolver(
      contractSource: _ContractSource(_contract()),
      components: const _Components(),
      geometry: _Geometry(hostSkew: 0.001),
      nowUtc: () => DateTime.utc(2026, 10, 17),
    );

    try {
      await resolver.capture(_request());
      fail('Expected CCTV01_HOST_FRAME_COMPATIBILITY_MISMATCH.');
    } on Elv5CaptureBlockedException catch (error) {
      expect(error.reasonCode, 'CCTV01_HOST_FRAME_COMPATIBILITY_MISMATCH');
    }
  });
}

Elv5CalculationRequest _request() => Elv5CalculationRequest(
  projectId: 'project-1',
  designRevisionId: 'design-1',
  scope: Elv5ScopeRef(
    kind: Elv5ScopeKind.design,
    scopeId: 'design-1',
    scenarioKey: 'NONE',
  ),
  processCode: Elv5ProcessCode.cctv01,
  subject: Elv5SubjectRef(kind: 'CAMERA', id: 'cam-1'),
  expectedPointerGeneration: 0,
);

Cctv01GeometryContract _contract() {
  Cctv01ExactVec3Contract v(int x, int y, int z) =>
      Cctv01ExactVec3Contract(
        x: Elv5Rational.integer(x),
        y: Elv5Rational.integer(y),
        z: Elv5Rational.integer(z),
      );
  return Cctv01GeometryContract(
    cameraId: 'cam-1',
    roomId: 'room-1',
    expectedDefinitionId: 'camera-def',
    expectedDefinitionVersion: 2,
    targetSurfacePatchId: 'target',
    geometryModelEditionId: 'geometry-edition-1',
    geometryModelContentHash: _h('a'),
    rectilinearPinholeSupported: true,
    targetIsPlanar: true,
    sensorWidthMm: Elv5Rational.integer(8),
    sensorHeightMm: Elv5Rational.integer(6),
    focalLengthMm: Elv5Rational.integer(4),
    forward: v(1, 0, 0),
    right: v(0, 1, 0),
    up: v(0, 0, 1),
    expectedHostSurfacePatchId: 'host',
    hostSurfaceFrame: Cctv01ExactSurfaceFrameContract(
      uAxis: v(0, 1, 0),
      vAxis: v(0, 0, 1),
    ),
    targetSurfaceFrame: Cctv01ExactSurfaceFrameContract(
      uAxis: v(0, 1, 0),
      vAxis: v(0, 0, 1),
    ),
    legacyFrameAxisTolerance: Elv5Rational(
      BigInt.one,
      BigInt.from(1000000),
    ),
  );
}

final class _ContractSource implements Cctv01GeometryContractSource {
  const _ContractSource(this.contract);
  final Cctv01GeometryContract contract;

  @override
  Future<Cctv01GeometryContractSnapshot?> loadActiveForCamera({
    required String projectId,
    required String designRevisionId,
    required String cameraId,
  }) async => Cctv01GeometryContractSnapshot(
    bindingId: 'binding-1',
    bindingRevision: 2,
    evidenceRef: 'CCTV01:cam-1:${_h('b')}',
    contentHash: _h('b'),
    contract: contract,
  );
}

final class _Components implements ComponentInstanceRepository {
  const _Components();

  @override
  Future<List<ComponentInstance>> loadRoomComponents(String roomId) async =>
      const <ComponentInstance>[
        ComponentInstance(
          id: 'cam-1',
          definitionId: 'camera-def',
          definitionVersion: 2,
          roomId: 'room-1',
          hostSurfacePatchId: 'host',
          localPosition: Point2Mm(100, 200),
        ),
      ];

  @override
  Stream<List<ComponentInstance>> watchRoomComponents(String roomId) =>
      const Stream<List<ComponentInstance>>.empty();

  @override
  Future<void> removeComponent(String instanceId) async {}
  @override
  Future<void> saveComponent(ComponentInstance instance) async {}
  @override
  Future<void> replaceRoomComponents({
    required String roomId,
    required Iterable<ComponentInstance> instances,
  }) async {}
}

final class _Geometry implements GeometryRepository {
  const _Geometry({required this.hostSkew});
  final double hostSkew;

  @override
  Future<RoomGeometrySnapshot> loadRoomGeometry(String roomId) async =>
      RoomGeometrySnapshot(
        roomId: roomId,
        patches: <SurfacePatch>[
          SurfacePatch(
            id: 'host',
            roomId: roomId,
            surfaceId: 'wall-host',
            frame: LocalCoordinateFrame(
              origin: const Point3Mm(0, 0, 0),
              uAxis: Vector3D(hostSkew, 1, 0),
              vAxis: const Vector3D(0, 0, 1),
            ),
            boundary: Polygon2Mm(const <Point2Mm>[
              Point2Mm(0, 0),Point2Mm(1000, 0),
              Point2Mm(1000, 1000),Point2Mm(0, 1000),
            ]),
            orientation: SurfaceOrientation.vertical,
          ),
          SurfacePatch(
            id: 'target',
            roomId: roomId,
            surfaceId: 'wall-target',
            frame: LocalCoordinateFrame(
              origin: const Point3Mm(1000, 0, 0),
              uAxis: const Vector3D(0, 1, 0),
              vAxis: const Vector3D(0, 0, 1),
            ),
            boundary: Polygon2Mm(const <Point2Mm>[
              Point2Mm(0, 0),Point2Mm(1000, 0),
              Point2Mm(1000, 1000),Point2Mm(0, 1000),
            ]),
            orientation: SurfaceOrientation.vertical,
          ),
        ],
      );

  @override
  Stream<RoomGeometrySnapshot> watchRoomGeometry(String roomId) =>
      const Stream<RoomGeometrySnapshot>.empty();

  @override
  Future<void> replaceRoomGeometry(RoomGeometrySnapshot snapshot) async {}
}

String _h(String char) => List<String>.filled(64, char).join();
