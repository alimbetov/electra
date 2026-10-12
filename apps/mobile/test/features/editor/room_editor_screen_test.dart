import 'package:electra_mobile/application/geometry_repository.dart';
import 'package:electra_mobile/domain/project_models.dart';
import 'package:electra_mobile/features/editor/room_editor_screen.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final timestamp = DateTime.utc(2026, 10, 12, 12);

  ProjectRecord project() => ProjectRecord(
    id: 'project-editor',
    name: 'Editor Project',
    reference: 'ED-01',
    measurementSystem: MeasurementSystem.metric,
    defaultStructuralHeightMm: 3200,
    defaultFinishedCeilingHeightMm: 3000,
    revision: 1,
    createdAt: timestamp,
    updatedAt: timestamp,
    originDeviceId: 'widget-test',
  );

  RoomRecord room() => RoomRecord(
    id: 'room-editor',
    floorId: 'floor-editor',
    name: 'Workshop 01',
    type: RoomType.workshop,
    category: RoomCategory.technical,
    widthMm: 4000,
    depthMm: 3000,
    revision: 1,
    createdAt: timestamp,
    updatedAt: timestamp,
    originDeviceId: 'widget-test',
  );

  SurfacePatch patch() => SurfacePatch(
    id: 'patch-editor',
    roomId: 'room-editor',
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

  Future<void> pumpEditor(WidgetTester tester) async {
    final surface = patch();
    await tester.pumpWidget(
      MaterialApp(
        home: RoomEditorScreen(
          project: project(),
          room: room(),
          geometry: RoomGeometrySnapshot(
            roomId: 'room-editor',
            patches: [surface],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('select tool resolves a persisted surface from canvas tap', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpEditor(tester);

    expect(find.textContaining('Workshop 01 · wall-a'), findsOneWidget);
    expect(find.text('Patches: 1'), findsOneWidget);

    final canvas = find.byType(InteractiveViewer);
    expect(canvas, findsOneWidget);
    await tester.tapAt(tester.getCenter(canvas));
    await tester.pump();

    expect(find.text('Selected id: patch-editor'), findsOneWidget);
    expect(find.textContaining('Selected · surfacePatch'), findsOneWidget);
  });

  testWidgets('measure tool captures two canvas points in millimetres', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpEditor(tester);

    await tester.tap(find.text('measure'));
    await tester.pump();

    final canvas = find.byType(InteractiveViewer);
    final rect = tester.getRect(canvas);
    await tester.tapAt(Offset(rect.left + rect.width * 0.35, rect.center.dy));
    await tester.pump();
    expect(find.text('Measure · choose second point'), findsOneWidget);

    await tester.tapAt(Offset(rect.left + rect.width * 0.65, rect.center.dy));
    await tester.pump();

    expect(find.textContaining('Measurement:'), findsOneWidget);
    expect(find.textContaining('Measure · '), findsWidgets);
  });
}
