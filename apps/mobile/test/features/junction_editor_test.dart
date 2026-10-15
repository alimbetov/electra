import 'package:electra_mobile/application/cable_routing_repository.dart';
import 'package:electra_mobile/application/geometry_repository.dart';
import 'package:electra_mobile/features/editor/junction_editor.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'compact junction detail navigates runs and retains failed save draft',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final patch = SurfacePatch(
        id: 'wall',
        roomId: 'room',
        surfaceId: 'wall',
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
      var sequence = 0;
      CableRoute route(String id, Point2Mm start, Point2Mm end) {
        final draft = SurfaceRouteDraft(nextId: () => 'node-${sequence++}')
          ..addPoint(patch, start)
          ..addPoint(patch, end);
        return draft.route(id: id, roomId: 'room', name: id);
      }

      final paths = [
        route('in', const Point2Mm(100, 1000), const Point2Mm(1000, 1000)),
        route('out1', const Point2Mm(1000, 1000), const Point2Mm(2000, 1000)),
        route('out2', const Point2Mm(1000, 1000), const Point2Mm(1000, 2000)),
      ];
      final runs = [
        for (final p in paths)
          CableRun(
            id: p.id,
            roomId: 'room',
            name: p.id,
            circuitId: 'c',
            routeId: p.id,
          ),
      ];
      final junction = RoutingJunction(
        id: 'j',
        code: 'J-01',
        type: RoutingJunctionType.junctionBox,
        roomId: 'room',
        surfacePatchId: 'wall',
        localPosition: const Point2Mm(1000, 1000),
        xMm: 1000,
        yMm: 0,
        zMm: 1000,
        connections: [
          for (final p in paths)
            RoutingJunctionConnection(
              runId: p.id,
              direction: p.id == 'in'
                  ? RoutingConnectionDirection.incoming
                  : RoutingConnectionDirection.outgoing,
              nodeId: (p.id == 'in' ? p.nodes.last : p.nodes.first).id,
              circuitOrNetworkId: 'c',
            ),
        ],
      );
      CableRun? opened;
      await tester.pumpWidget(
        MaterialApp(
          home: JunctionEditor(
            snapshot: RoomRoutingSnapshot(
              geometry: RoomGeometrySnapshot(roomId: 'room', patches: [patch]),
              routes: paths,
              runs: runs,
              junctions: [junction],
              activeCircuitIds: {'c'},
            ),
            id: 'j',
            junction: junction,
            onOpenRun: (run) => opened = run,
            onSave: (_) async => throw StateError('write failed'),
          ),
        ),
      );
      await tester.scrollUntilVisible(
        find.text('Open route').first,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Open route').first);
      expect(opened?.id, 'in');
      await tester.scrollUntilVisible(
        find.text('Save junction'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Save junction'));
      await tester.pumpAndSettle();
      expect(find.textContaining('write failed'), findsOneWidget);
      expect(find.text('J-01'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}
