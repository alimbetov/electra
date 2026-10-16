import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:test/test.dart';

void main() {
  test('LAN-02 applies exact ratio spare and reaches zero headroom', () {
    final result = const Lan02PortCapacityKernel().evaluate(
      Lan02Input(
        switchId: 'sw-1',
        ports: [
          Lan02PhysicalPort(portId: 'p1', media: 'copper', maxSpeedMbps: 1000),
          Lan02PhysicalPort(portId: 'p2', media: 'copper', maxSpeedMbps: 1000),
          Lan02PhysicalPort(portId: 'p3', media: 'copper', maxSpeedMbps: 1000),
          Lan02PhysicalPort(portId: 'p4', media: 'copper', maxSpeedMbps: 1000),
          Lan02PhysicalPort(portId: 'p5', media: 'copper', maxSpeedMbps: 1000),
          Lan02PhysicalPort(portId: 'p6', media: 'copper', maxSpeedMbps: 1000),
          Lan02PhysicalPort(portId: 'p7', media: 'copper', maxSpeedMbps: 1000),
          Lan02PhysicalPort(portId: 'p8', media: 'copper', maxSpeedMbps: 1000),
        ],
        assignments: [
          for (var i = 1; i <= 6; i++)
            Lan02PortAssignment(
              endpointId: 'e$i',
              portId: 'p$i',
              requiredMedia: 'copper',
              requiredSpeedMbps: 1000,
            ),
        ],
        unavailablePortIds: {},
        sparePolicy: Lan02SparePolicy(
          absoluteMinimum: 0,
          ratio: Elv5Rational.parseDecimal('0.25'),
          combiner: Lan02SpareCombiner.max,
        ),
      ),
    );
    expect(result.requiredSpare, 2);
    expect(result.headroomPorts, 0);
    expect(result.status, Lan02AssessmentStatus.pass);
  });

  test('duplicate exclusive physical port assignment fails', () {
    final result = const Lan02PortCapacityKernel().evaluate(
      Lan02Input(
        switchId: 'sw-1',
        ports: [
          Lan02PhysicalPort(portId: 'p1', media: 'copper', maxSpeedMbps: 1000),
          Lan02PhysicalPort(portId: 'p2', media: 'copper', maxSpeedMbps: 1000),
        ],
        assignments: [
          Lan02PortAssignment(endpointId: 'e1', portId: 'p1', requiredMedia: 'copper', requiredSpeedMbps: 1000),
          Lan02PortAssignment(endpointId: 'e2', portId: 'p1', requiredMedia: 'copper', requiredSpeedMbps: 1000),
        ],
        unavailablePortIds: {},
        sparePolicy: Lan02SparePolicy(
          absoluteMinimum: 0,
          ratio: Elv5Rational.zero,
          combiner: Lan02SpareCombiner.max,
        ),
      ),
    );
    expect(result.status, Lan02AssessmentStatus.fail);
    expect(result.incompatibleEndpointIds, contains('e2'));
  });
}
