import 'package:engineering_core/engineering_core.dart';
import 'package:test/test.dart';

void main() {
  SurfacePatch wall() => SurfacePatch(
        id: 'wall-a',
        roomId: 'room-a',
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

  test('valid component placement uses exact host patch local millimetres', () {
    const instance = ComponentInstance(
      id: 'socket-1',
      definitionId: 'system-socket',
      definitionVersion: 3,
      roomId: 'room-a',
      hostSurfacePatchId: 'wall-a',
      localPosition: Point2Mm(1200, 300),
      rotationRadians: 0,
    );

    expect(
      ComponentPlacementValidator.validate(
        instance: instance,
        patches: [wall()],
      ),
      isEmpty,
    );
    expect(instance.localPosition, const Point2Mm(1200, 300));
    expect(instance.definitionVersion, 3);
  });

  test('component placement rejects a missing host patch', () {
    const instance = ComponentInstance(
      id: 'socket-1',
      definitionId: 'system-socket',
      definitionVersion: 1,
      roomId: 'room-a',
      hostSurfacePatchId: 'wall-missing',
      localPosition: Point2Mm(1000, 300),
    );

    final violations = ComponentPlacementValidator.validate(
      instance: instance,
      patches: [wall()],
    );

    expect(
      violations.map((item) => item.code),
      contains(ComponentPlacementViolationCode.missingHostPatch),
    );
  });

  test('component placement rejects room mismatch and outside position', () {
    const instance = ComponentInstance(
      id: 'socket-1',
      definitionId: 'system-socket',
      definitionVersion: 1,
      roomId: 'room-b',
      hostSurfacePatchId: 'wall-a',
      localPosition: Point2Mm(4500, 500),
    );

    final violations = ComponentPlacementValidator.validate(
      instance: instance,
      patches: [wall()],
    );
    final codes = violations.map((item) => item.code).toSet();

    expect(codes, contains(ComponentPlacementViolationCode.roomMismatch));
    expect(codes, contains(ComponentPlacementViolationCode.outsideHostPatch));
  });

  test('component placement rejects invalid definition metadata', () {
    const instance = ComponentInstance(
      id: '',
      definitionId: '',
      definitionVersion: 0,
      roomId: 'room-a',
      hostSurfacePatchId: 'wall-a',
      localPosition: Point2Mm(1000, 500),
      rotationRadians: double.nan,
    );

    final violations = ComponentPlacementValidator.validate(
      instance: instance,
      patches: [wall()],
    );
    final codes = violations.map((item) => item.code).toSet();

    expect(codes, contains(ComponentPlacementViolationCode.emptyInstanceId));
    expect(codes, contains(ComponentPlacementViolationCode.emptyDefinitionId));
    expect(
      codes,
      contains(ComponentPlacementViolationCode.invalidDefinitionVersion),
    );
    expect(codes, contains(ComponentPlacementViolationCode.nonFiniteRotation));
  });
}
