import 'package:electra_mobile/application/geometry_repository.dart';
import 'package:electra_mobile/domain/project_models.dart';
import 'package:electra_mobile/features/editor/room_editor_screen.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final timestamp = DateTime.utc(2026, 10, 12, 14);

  final project = ProjectRecord(
    id: 'project-nav',
    name: 'Navigation Project',
    reference: 'NAV-01',
    measurementSystem: MeasurementSystem.metric,
    defaultStructuralHeightMm: 3200,
    defaultFinishedCeilingHeightMm: 3000,
    revision: 1,
    createdAt: timestamp,
    updatedAt: timestamp,
    originDeviceId: 'widget-test',
  );

  final room = RoomRecord(
    id: 'room-nav',
    floorId: 'floor-nav',
    name: 'Navigation Room',
    type: RoomType.workshop,
    category: RoomCategory.technical,
    widthMm: 4000,
    depthMm: 5000,
    revision: 1,
    createdAt: timestamp,
    updatedAt: timestamp,
    originDeviceId: 'widget-test',
  );

  final wallA = SurfacePatch(
    id: 'wall-a',
    roomId: room.id,
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

  final wallB = SurfacePatch(
    id: 'wall-b',
    roomId: room.id,
    surfaceId: 'Wall B',
    frame: LocalCoordinateFrame(
      origin: const Point3Mm(4000, 0, 0),
      uAxis: const Vector3D(0, 1, 0),
      vAxis: const Vector3D(0, 0, 1),
    ),
    boundary: Polygon2Mm(const [
      Point2Mm(0, 0),
      Point2Mm(5000, 0),
      Point2Mm(5000, 3000),
      Point2Mm(0, 3000),
    ]),
    orientation: SurfaceOrientation.vertical,
  );

  final edgeA = SurfaceEdge(
    id: 'wall-a-right',
    patchId: wallA.id,
    start: const Point2Mm(4000, 0),
    end: const Point2Mm(4000, 3000),
    kind: SurfaceEdgeKind.fold,
  );

  final edgeB = SurfaceEdge(
    id: 'wall-b-left',
    patchId: wallB.id,
    start: const Point2Mm(0, 3000),
    end: const Point2Mm(0, 0),
    kind: SurfaceEdgeKind.fold,
  );

  final adjacency = SurfaceAdjacency(
    id: 'wall-a-wall-b',
    fromPatchId: wallA.id,
    fromEdgeId: edgeA.id,
    toPatchId: wallB.id,
    toEdgeId: edgeB.id,
  );

  testWidgets('strong edge proximity opens the adjacent persisted surface', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: RoomEditorScreen(
          project: project,
          room: room,
          geometry: RoomGeometrySnapshot(
            roomId: room.id,
            patches: [wallA, wallB],
            edges: [edgeA, edgeB],
            adjacencies: [adjacency],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Navigation Room · Wall A'), findsOneWidget);

    final viewer = find.byType(InteractiveViewer);
    final rect = tester.getRect(viewer);
    final nearRightEdge = Offset(rect.right - 28, rect.center.dy);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: rect.center);
    await gesture.moveTo(nearRightEdge);
    await tester.pump();

    expect(find.textContaining('Open → Wall B'), findsOneWidget);

    await tester.tapAt(nearRightEdge);
    await tester.pump();

    expect(find.textContaining('Navigation Room · Wall B'), findsOneWidget);
    expect(find.textContaining('Active surface: Wall B'), findsOneWidget);
  });
}
