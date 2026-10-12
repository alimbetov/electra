import 'package:electra_mobile/application/cable_routing_repository.dart';
import 'package:electra_mobile/application/geometry_repository.dart';
import 'package:electra_mobile/features/editor/editor_interaction.dart';
import 'package:electra_mobile/features/editor/room_routing_screen.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  SurfacePatch patch(String id) => SurfacePatch(
    id: id,
    roomId: 'room',
    surfaceId: 'Wall $id',
    frame: LocalCoordinateFrame(
      origin: Point3Mm(id == 'a' ? 0 : 4000, 0, 0),
      uAxis: id == 'a' ? const Vector3D(1, 0, 0) : const Vector3D(0, 1, 0),
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
  final patches = [patch('a'), patch('b')];
  final geometry = RoomGeometrySnapshot(
    roomId: 'room',
    patches: patches,
    edges: [
      SurfaceEdge(
        id: 'ea',
        patchId: 'a',
        start: const Point2Mm(4000, 0),
        end: const Point2Mm(4000, 3000),
        kind: SurfaceEdgeKind.fold,
      ),
      SurfaceEdge(
        id: 'eb',
        patchId: 'b',
        start: const Point2Mm(0, 0),
        end: const Point2Mm(0, 3000),
        kind: SurfaceEdgeKind.fold,
      ),
    ],
    adjacencies: [
      SurfaceAdjacency(
        id: 'ab',
        fromPatchId: 'a',
        fromEdgeId: 'ea',
        toPatchId: 'b',
        toEdgeId: 'eb',
      ),
    ],
  );
  final snapshot = RoomRoutingSnapshot(
    geometry: geometry,
    activeCircuitIds: const {'circuit'},
  );

  Future<void> tapLocal(
    WidgetTester tester,
    SurfacePatch patch,
    Point2Mm point,
  ) async {
    final rect = tester.getRect(find.byType(InteractiveViewer));
    final transform = SurfaceViewportTransform(
      boundary: patch.boundary,
      viewportWidth: rect.width,
      viewportHeight: rect.height,
    );
    final local = transform.localToViewport(point);
    await tester.tapAt(rect.topLeft + Offset(local.x, local.y));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'draws across a fold and saves exact route and cable allowances',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var sequence = 0;
      CableRoute? savedRoute;
      CableRun? savedRun;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CableRouteEditor(
              snapshot: snapshot,
              circuits: const {'circuit': 'Workshop circuit'},
              nextId: () => 'id-${sequence++}',
              onSave: ({required route, required run}) async {
                savedRoute = route;
                savedRun = run;
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('New route'));
      await tester.pumpAndSettle();
      await tapLocal(tester, patches[0], const Point2Mm(1000, 1000));
      await tapLocal(tester, patches[0], const Point2Mm(3950, 1000));
      expect(find.text('Wall b'), findsOneWidget);
      await tapLocal(tester, patches[1], const Point2Mm(2000, 1000));
      await tester.scrollUntilVisible(
        find.text('Reserve (%)'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Reserve (%)'),
        '10',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Termination allowance (mm)'),
        '250',
      );
      await tester.scrollUntilVisible(
        find.text('Save route'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Save route'));
      await tester.pumpAndSettle();
      expect(savedRoute!.nodes, hasLength(3));
      expect(savedRoute!.nodes[1].kind, RouteNodeKind.surfaceTransition);
      expect(
        savedRoute!.nodes[1].anchor.localPosition,
        const Point2Mm(4000, 1000),
      );
      expect(
        savedRoute!.nodes[1].otherAnchor!.localPosition,
        const Point2Mm(0, 1000),
      );
      expect(savedRoute!.segments.map((segment) => segment.surfacePatchId), [
        'a',
        'b',
      ]);
      expect(savedRun!.circuitId, 'circuit');
      expect(snapshot.calculate(savedRoute!).cableLengthMm(savedRun!), 5750);
      expect(find.text('Route and CableRun saved.'), findsOneWidget);
    },
  );
  testWidgets('compact canvas and failed save preserve the draft for retry', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var sequence = 0;
    var writes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CableRouteEditor(
            snapshot: snapshot,
            circuits: const {
              'circuit': 'Workshop circuit with a long engineering name',
            },
            nextId: () => 'id-${sequence++}',
            onSave: ({required route, required run}) async {
              writes++;
              throw StateError('disk failure');
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('New route'));
    await tester.pumpAndSettle();
    await tapLocal(tester, patches[0], const Point2Mm(1000, 1000));
    await tapLocal(tester, patches[0], const Point2Mm(2000, 1000));
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('Save route'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Save route'));
    await tester.pump();
    expect(writes, 1);
    expect(find.textContaining('Unable to save route'), findsOneWidget);
    expect(find.text('Save route'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
