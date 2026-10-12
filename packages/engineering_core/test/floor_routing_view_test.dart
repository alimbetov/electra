import 'package:engineering_core/engineering_core.dart';
import 'package:test/test.dart';

void main() {
  test('floor routing view aggregates floor routing artifacts', () {
    const view = FloorRoutingView(
      floorId: 'F02',
      displayMode: FloorRoutingDisplayMode.overview,
      rootPanels: [
        FloorRoutingPanelRef(panelId: 'DB-F02', name: 'DB-F02'),
      ],
      trayRuns: [
        FloorRoutingBackboneRef(
          routeId: 'TR-01',
          name: 'TR-01',
          visualState: RouteVisualState.design,
        ),
        FloorRoutingBackboneRef(
          routeId: 'TR-02',
          name: 'TR-02',
          visualState: RouteVisualState.installed,
        ),
      ],
      routingJunctions: [
        FloorRoutingJunctionRef(junctionId: 'J-014', name: 'J-014'),
        FloorRoutingJunctionRef(junctionId: 'J-015', name: 'J-015'),
      ],
      roomReferences: [
        FloorRoutingRoomRef(roomId: 'R201', name: 'Room 201'),
      ],
      outgoingBranches: [
        FloorRoutingBranchRef(
          branchId: 'B-01',
          name: 'Branch 01',
          fromRef: 'J-014',
          toRef: 'R201',
        ),
      ],
    );

    expect(view.floorId, 'F02');
    expect(view.displayMode, FloorRoutingDisplayMode.overview);
    expect(view.backboneCount, 2);
    expect(view.routingJunctions.length, 2);
    expect(view.outgoingBranches.single.toRef, 'R201');
    expect(view.hasContent, isTrue);
  });
}
