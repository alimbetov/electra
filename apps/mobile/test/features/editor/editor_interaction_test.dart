import 'package:electra_mobile/application/geometry_repository.dart';
import 'package:electra_mobile/features/editor/editor_interaction.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  SurfacePatch patch() => SurfacePatch(
    id: 'patch-a',
    roomId: 'room-a',
    surfaceId: 'wall-a',
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

  RoomGeometrySnapshot snapshot() {
    final surface = patch();
    return RoomGeometrySnapshot(
      roomId: 'room-a',
      patches: [surface],
      openings: [
        Opening(
          id: 'door-a',
          hostSurfacePatchId: surface.id,
          boundary: Polygon2Mm(const [
            Point2Mm(500, 0),
            Point2Mm(1500, 0),
            Point2Mm(1500, 2100),
            Point2Mm(500, 2100),
          ]),
          type: OpeningType.door,
        ),
      ],
      features: [
        SpatialFeature(
          id: 'beam-a',
          hostSurfacePatchId: surface.id,
          type: SpatialFeatureType.beam,
          footprint: Polygon2Mm(const [
            Point2Mm(0, 2600),
            Point2Mm(4000, 2600),
            Point2Mm(4000, 3000),
            Point2Mm(0, 3000),
          ]),
          depthMm: 300,
          elevationMm: 2600,
        ),
      ],
    );
  }

  test('hit testing prioritizes opening and feature before host patch', () {
    final geometry = snapshot();
    final surface = geometry.patches.single;

    expect(
      hitTestSurface(
        geometry: geometry,
        patch: surface,
        localPoint: const Point2Mm(1000, 1000),
      ),
      const EditorSelection(
        kind: EditorSelectionKind.opening,
        id: 'door-a',
        hostPatchId: 'patch-a',
      ),
    );

    expect(
      hitTestSurface(
        geometry: geometry,
        patch: surface,
        localPoint: const Point2Mm(2000, 2800),
      ),
      const EditorSelection(
        kind: EditorSelectionKind.spatialFeature,
        id: 'beam-a',
        hostPatchId: 'patch-a',
      ),
    );

    expect(
      hitTestSurface(
        geometry: geometry,
        patch: surface,
        localPoint: const Point2Mm(3000, 1200),
      ),
      const EditorSelection(
        kind: EditorSelectionKind.surfacePatch,
        id: 'patch-a',
        hostPatchId: 'patch-a',
      ),
    );

    expect(
      hitTestSurface(
        geometry: geometry,
        patch: surface,
        localPoint: const Point2Mm(5000, 1200),
      ),
      isNull,
    );
  });

  test('component hit testing wins over host surface and uses nearest instance', () {
    final geometry = snapshot();
    final surface = geometry.patches.single;
    final components = [
      const ComponentInstance(
        id: 'camera-near',
        definitionId: 'camera',
        definitionVersion: 1,
        roomId: 'room-a',
        hostSurfacePatchId: 'patch-a',
        localPosition: Point2Mm(2100, 1200),
      ),
      const ComponentInstance(
        id: 'camera-far',
        definitionId: 'camera',
        definitionVersion: 1,
        roomId: 'room-a',
        hostSurfacePatchId: 'patch-a',
        localPosition: Point2Mm(2300, 1200),
      ),
    ];

    expect(
      hitTestSurface(
        geometry: geometry,
        patch: surface,
        localPoint: const Point2Mm(2140, 1200),
        components: components,
      ),
      const EditorSelection(
        kind: EditorSelectionKind.component,
        id: 'camera-near',
        hostPatchId: 'patch-a',
      ),
    );
  });

  test('component hit tolerance does not steal distant surface selection', () {
    final geometry = snapshot();
    final surface = geometry.patches.single;

    expect(
      hitTestSurface(
        geometry: geometry,
        patch: surface,
        localPoint: const Point2Mm(3000, 1200),
        components: const [
          ComponentInstance(
            id: 'camera',
            definitionId: 'camera',
            definitionVersion: 1,
            roomId: 'room-a',
            hostSurfacePatchId: 'patch-a',
            localPosition: Point2Mm(2000, 1200),
          ),
        ],
      ),
      const EditorSelection(
        kind: EditorSelectionKind.surfacePatch,
        id: 'patch-a',
        hostPatchId: 'patch-a',
      ),
    );
  });

  test('viewport transform round-trips engineering millimetres', () {
    final transform = SurfaceViewportTransform(
      boundary: patch().boundary,
      viewportWidth: 800,
      viewportHeight: 600,
    );

    const local = Point2Mm(1750, 900);
    final viewport = transform.localToViewport(local);
    final restored = transform.viewportToLocal(viewport.x, viewport.y);

    expect(restored, local);
  });

  test('measurement reports deterministic planar distance in millimetres', () {
    const measurement = EditorMeasurement(
      start: Point2Mm(1000, 1000),
      end: Point2Mm(4000, 5000),
    );

    expect(measurement.lengthMm, 5000);
  });
}
