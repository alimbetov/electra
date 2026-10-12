import 'package:engineering_core/engineering_core.dart';
import 'package:test/test.dart';

void main() {
  test('routing junction exposes incoming and outgoing branches', () {
    const junction = RoutingJunction(
      id: 'junction-14',
      code: 'J-014',
      type: RoutingJunctionType.distributionBox,
      xMm: 4200,
      yMm: 1800,
      zMm: 2700,
      floorId: 'floor-02',
      roomId: 'room-201',
      connections: [
        RoutingJunctionConnection(
          runId: 'run-main',
          direction: RoutingConnectionDirection.incoming,
          circuitOrNetworkId: 'C-200',
        ),
        RoutingJunctionConnection(
          runId: 'run-201',
          direction: RoutingConnectionDirection.outgoing,
          circuitOrNetworkId: 'C-201',
        ),
        RoutingJunctionConnection(
          runId: 'run-202',
          direction: RoutingConnectionDirection.outgoing,
          circuitOrNetworkId: 'C-202',
        ),
      ],
    );

    expect(junction.incoming.length, 1);
    expect(junction.outgoing.length, 2);
    expect(junction.isBranching, isTrue);
  });
}
