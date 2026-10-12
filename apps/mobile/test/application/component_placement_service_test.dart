import 'dart:async';

import 'package:electra_mobile/application/component_instance_repository.dart';
import 'package:electra_mobile/application/component_placement_service.dart';
import 'package:electra_mobile/application/geometry_repository.dart';
import 'package:electra_mobile/application/id_generator.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const roomId = 'room-components';
  final patch = SurfacePatch(
    id: 'wall-a',
    roomId: roomId,
    surfaceId: 'Wall A',
    frame: LocalCoordinateFrame(
      origin: const Point3Mm(0, 0, 0),
      uAxis: const Vector3D(1, 0, 0),
      vAxis: const Vector3D(0, 0, 1),
    ),
    boundary: Polygon2Mm(const [
      Point2Mm(0, 0),
      Point2Mm(4000, 0),
      Point2Mm(4000, 3000),
      Point2Mm(0, 3000),
    ]),
    orientation: SurfaceOrientation.vertical,
  );
  const definition = ComponentDefinition(
    id: 'system-socket',
    code: 'SOCKET_230V',
    displayName: 'Socket 230V',
    category: 'SOCKET',
    primaryDiscipline: Discipline.electrical,
    source: ComponentDefinitionSource.system,
    version: 3,
  );

  test('valid placement saves one exact project component instance', () async {
    final components = _RecordingComponentRepository();
    final geometry = _FakeGeometryRepository(
      RoomGeometrySnapshot(roomId: roomId, patches: [patch]),
    );
    final service = ComponentPlacementService(
      components: components,
      geometry: geometry,
      idGenerator: FixedSequenceIdGenerator(const ['instance-001']),
    );

    final result = await service.place(
      roomId: roomId,
      definition: definition,
      hostSurfacePatchId: patch.id,
      localPosition: const Point2Mm(1250, 300),
      rotationRadians: 0.25,
    );

    expect(components.saved, hasLength(1));
    expect(components.saved.single, same(result));
    expect(result.id, 'instance-001');
    expect(result.definitionId, definition.id);
    expect(result.definitionVersion, 3);
    expect(result.roomId, roomId);
    expect(result.hostSurfacePatchId, patch.id);
    expect(result.localPosition, const Point2Mm(1250, 300));
    expect(result.rotationRadians, 0.25);
  });

  test(
    'placement outside host patch is rejected before repository write',
    () async {
      final components = _RecordingComponentRepository();
      final geometry = _FakeGeometryRepository(
        RoomGeometrySnapshot(roomId: roomId, patches: [patch]),
      );
      final service = ComponentPlacementService(
        components: components,
        geometry: geometry,
        idGenerator: FixedSequenceIdGenerator(const ['instance-invalid']),
      );

      await expectLater(
        service.place(
          roomId: roomId,
          definition: definition,
          hostSurfacePatchId: patch.id,
          localPosition: const Point2Mm(4500, 300),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('outsideHostPatch'),
          ),
        ),
      );

      expect(components.saved, isEmpty);
    },
  );
}

final class _RecordingComponentRepository
    implements ComponentInstanceRepository {
  final List<ComponentInstance> saved = [];

  @override
  Future<void> removeComponent(String instanceId) async {
    saved.removeWhere((item) => item.id == instanceId);
  }

  @override
  Future<List<ComponentInstance>> loadRoomComponents(String roomId) async =>
      List.unmodifiable(saved.where((item) => item.roomId == roomId));

  @override
  Future<void> replaceRoomComponents({
    required String roomId,
    required Iterable<ComponentInstance> instances,
  }) async {
    saved
      ..removeWhere((item) => item.roomId == roomId)
      ..addAll(instances);
  }

  @override
  Future<void> saveComponent(ComponentInstance instance) async {
    saved.add(instance);
  }

  @override
  Stream<List<ComponentInstance>> watchRoomComponents(String roomId) =>
      Stream.value(
        List.unmodifiable(saved.where((item) => item.roomId == roomId)),
      );
}

final class _FakeGeometryRepository implements GeometryRepository {
  _FakeGeometryRepository(this.snapshot);

  final RoomGeometrySnapshot snapshot;

  @override
  Future<RoomGeometrySnapshot> loadRoomGeometry(String roomId) async =>
      snapshot;

  @override
  Future<void> replaceRoomGeometry(RoomGeometrySnapshot snapshot) async =>
      throw UnsupportedError('Not needed by this test.');

  @override
  Stream<RoomGeometrySnapshot> watchRoomGeometry(String roomId) =>
      Stream.value(snapshot);
}
