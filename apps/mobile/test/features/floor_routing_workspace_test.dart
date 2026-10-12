import 'package:electra_mobile/application/cable_routing_repository.dart';
import 'package:electra_mobile/application/floor_routing_repository.dart';
import 'package:electra_mobile/application/geometry_repository.dart';
import 'package:electra_mobile/domain/project_models.dart';
import 'package:electra_mobile/features/floors/floor_routing_screen.dart';
import 'package:electra_mobile/features/editor/room_routing_screen.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

FloorRoutingSnapshot fixture() {
  final date = DateTime.utc(2026, 10, 12);
  final floor = FloorRecord(
    id: 'floor',
    projectId: 'project',
    name: 'F01',
    code: 'F01',
    sortOrder: 1,
    revision: 1,
    createdAt: date,
    updatedAt: date,
    originDeviceId: 'test',
  );
  final rooms = [
    for (final id in ['Hall', 'Workshop'])
      RoomRecord(
        id: id,
        floorId: 'floor',
        name: id,
        type: RoomType.workshop,
        category: RoomCategory.technical,
        widthMm: 4000,
        depthMm: 3000,
        revision: 1,
        createdAt: date,
        updatedAt: date,
        originDeviceId: 'test',
      ),
  ];
  var sequence = 0;
  final routing = <String, RoomRoutingSnapshot>{};
  for (final room in rooms) {
    final patch = SurfacePatch(
      id: room.id,
      roomId: room.id,
      surfaceId: room.id,
      orientation: SurfaceOrientation.vertical,
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
    );
    final channel = PhysicalChannel(
      id: 'channel-${room.id}',
      roomId: room.id,
      name: 'Conduit',
      kind: PhysicalChannelKind.conduit,
    );
    final draft =
        SurfaceRouteDraft(nextId: () => 'node-${sequence++}')
          ..addPoint(patch, const Point2Mm(100, 1000))
          ..addPoint(
            patch,
            const Point2Mm(2000, 1000),
            method: LayingMethod.conduit,
            channelId: channel.id,
          );
    final route = draft.route(
      id: room.id,
      roomId: room.id,
      name: 'Route ${room.id}',
    );
    routing[room.id] = RoomRoutingSnapshot(
      geometry: RoomGeometrySnapshot(roomId: room.id, patches: [patch]),
      routes: [route],
      runs: [
        CableRun(
          id: room.id,
          roomId: room.id,
          name: 'Feed ${room.id}',
          circuitId: 'c-${room.id}',
          routeId: room.id,
        ),
      ],
      channels: [channel],
      activeCircuitIds: {'c-${room.id}'},
    );
  }
  final base = FloorRoutingSnapshot(
        floor: floor,
        rooms: rooms,
        routing: routing,
      ),
      graph = base.graph();
  return FloorRoutingSnapshot(
    floor: floor,
    rooms: rooms,
    routing: routing,
    panels: [
      FloorRoutingPanel(
        id: 'p',
        floorId: 'floor',
        code: 'DB-01',
        name: 'Panel',
        feeds: [
          FloorPanelFeed(
            runId: 'Hall',
            endpointSignature: graph.runs['Hall']!.endpointSignature(
              start: true,
            ),
          ),
        ],
      ),
    ],
    handoffs: [
      FloorRoutingHandoff(
        id: 'h',
        floorId: 'floor',
        name: 'Handoff',
        fromRunId: 'Hall',
        toRunId: 'Workshop',
        fromSignature: graph.runs['Hall']!.endpointSignature(start: false),
        toSignature: graph.runs['Workshop']!.endpointSignature(start: true),
      ),
    ],
  );
}

void main() {
  Future<void> render(
    WidgetTester tester, {
    required FloorRoutingSnapshot snapshot,
    ValueChanged<CableRun>? open,
    Future<void> Function(FloorRoutingPanel)? save,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FloorRoutingWorkspace(
            snapshot: snapshot,
            nextId: () => 'new-panel',
            onSavePanel: save ?? (_) async {},
            onSaveHandoff: (_) async {},
            onDeletePanel: (_) async {},
            onDeleteHandoff: (_) async {},
            onOpenRun: open ?? (_) {},
            onOpenJunction: (_) {},
          ),
        ),
      ),
    );
  }

  testWidgets(
    'floor drill-down opens the selected persisted route immediately',
    (tester) async {
      final snapshot = fixture().routing['Workshop']!;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CableRouteEditor(
              snapshot: snapshot,
              initialRunId: 'Workshop',
              circuits: const {'c-Workshop': 'Workshop circuit'},
              nextId: () => 'unused',
              onSave: ({required route, required run}) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Route / CableRun name'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester
            .widget<TextField>(
              find.widgetWithText(TextField, 'Route / CableRun name'),
            )
            .controller!
            .text,
        'Route Workshop',
      );
      await tester.scrollUntilVisible(
        find.text('Cancel draft'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Cancel draft'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('compact floor trace retains selection and opens real room run', (
    tester,
  ) async {
    CableRun? opened;
    await render(tester, snapshot: fixture(), open: (run) => opened = run);
    await tester.scrollUntilVisible(
      find.text('DB-01 · Panel'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('DB-01 · Panel'));
    await tester.pumpAndSettle();
    expect(find.text('Trace: 2 runs · 1 source panels'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Workshop'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Workshop'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byTooltip('Open room route'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byTooltip('Open room route'));
    await tester.pump();
    expect(opened?.id, 'Workshop');
    expect(find.text('Trace: 2 runs · 1 source panels'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('source panel failed save preserves entered draft', (
    tester,
  ) async {
    FloorRoutingPanel? submitted;
    await render(
      tester,
      snapshot: fixture(),
      save: (p) async {
        submitted = p;
        throw StateError('write failed');
      },
    );
    await tester.tap(find.text('Add source panel'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Panel code'),
      'DB-02',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Panel name'),
      'Second panel',
    );
    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Save panel'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Save panel'));
    await tester.pumpAndSettle();
    expect(submitted?.feeds.single.runId, 'Hall');
    expect(find.textContaining('write failed'), findsOneWidget);
    expect(find.text('DB-02'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
