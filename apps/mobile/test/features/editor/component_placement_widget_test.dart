import 'package:electra_mobile/application/geometry_repository.dart';
import 'package:electra_mobile/domain/project_models.dart';
import 'package:electra_mobile/features/editor/editor_interaction.dart';
import 'package:electra_mobile/features/editor/room_editor_screen.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final timestamp = DateTime.utc(2026, 10, 12, 15);

  final project = ProjectRecord(
    id: 'project-placement',
    name: 'Placement Project',
    reference: 'PL-01',
    measurementSystem: MeasurementSystem.metric,
    defaultStructuralHeightMm: 3200,
    defaultFinishedCeilingHeightMm: 3000,
    revision: 1,
    createdAt: timestamp,
    updatedAt: timestamp,
    originDeviceId: 'widget-test',
  );

  final room = RoomRecord(
    id: 'room-placement',
    floorId: 'floor-placement',
    name: 'Workshop Placement',
    type: RoomType.workshop,
    category: RoomCategory.technical,
    widthMm: 4000,
    depthMm: 3000,
    revision: 1,
    createdAt: timestamp,
    updatedAt: timestamp,
    originDeviceId: 'widget-test',
  );

  final wall = SurfacePatch(
    id: 'wall-placement',
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

  testWidgets(
    'catalog selection stays active for repeated placement until Done',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final placements =
          <
            ({ComponentDefinition definition, String patchId, Point2Mm point})
          >[];

      await tester.pumpWidget(
        MaterialApp(
          home: RoomEditorScreen(
            project: project,
            room: room,
            geometry: RoomGeometrySnapshot(roomId: room.id, patches: [wall]),
            onPlaceComponent: (definition, patchId, point) async {
              placements.add((
                definition: definition,
                patchId: patchId,
                point: point,
              ));
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('equipment'));
      await tester.pump();
      expect(find.text('Catalog'), findsOneWidget);

      expect(tester.getCenter(find.text('Catalog')).dx, lessThan(1200));
      await tester.tap(find.text('Catalog'));
      await tester.pumpAndSettle();
      expect(find.text('Component catalog'), findsOneWidget);

      await tester.tap(find.text('Socket 230V'));
      await tester.pumpAndSettle();

      expect(find.text('Done'), findsOneWidget);
      expect(
        find.textContaining('Socket 230V · tap to place repeatedly'),
        findsOneWidget,
      );

      final viewer = find.byType(InteractiveViewer);
      final rect = tester.getRect(viewer);
      final transform = SurfaceViewportTransform(
        boundary: wall.boundary,
        viewportWidth: rect.width,
        viewportHeight: rect.height,
      );

      Offset globalFor(Point2Mm point) {
        final mapped = transform.localToViewport(point);
        return rect.topLeft + Offset(mapped.x, mapped.y);
      }

      const first = Point2Mm(1000, 500);
      const second = Point2Mm(3000, 1200);

      await tester.tapAt(globalFor(first));
      await tester.pumpAndSettle();
      await tester.tapAt(globalFor(second));
      await tester.pumpAndSettle();

      expect(placements, hasLength(2));
      expect(
        placements.map((item) => item.definition.id),
        everyElement('system-electrical-socket-230v'),
      );
      expect(placements.map((item) => item.patchId), everyElement(wall.id));
      expect(placements[0].point, first);
      expect(placements[1].point, second);

      expect(find.text('Done'), findsOneWidget);
      expect(
        find.textContaining('Socket 230V · tap to place repeatedly'),
        findsOneWidget,
      );

      expect(tester.getCenter(find.text('Done')).dx, lessThan(1200));
      await tester.tap(find.text('Done'));
      await tester.pump();

      expect(find.text('Done'), findsNothing);
      expect(
        find.textContaining('Select · tap a surface object'),
        findsOneWidget,
      );
    },
  );
}
