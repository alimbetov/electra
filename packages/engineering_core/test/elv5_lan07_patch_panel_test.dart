import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:test/test.dart';

void main() {
  test(
      'LAN-07 counts distinct physical ports and preserves mapping completeness',
      () {
    final result = const Lan07PatchPanelKernel().evaluate(
      Lan07Input(
        panelId: 'panel-1',
        ports: [
          for (var i = 1; i <= 8; i++) Lan07PhysicalPort(portId: 'p$i'),
        ],
        assignments: [
          Lan07PatchAssignment(
            assignmentId: 'a1',
            portId: 'p1',
            sourceEndpointId: 's1',
            destinationEndpointId: 'd1',
          ),
          Lan07PatchAssignment(
            assignmentId: 'a2',
            portId: 'p2',
            sourceEndpointId: 's2',
            destinationEndpointId: 'd2',
          ),
          Lan07PatchAssignment(
            assignmentId: 'a3',
            portId: 'p3',
            sourceEndpointId: 's3',
            destinationEndpointId: 'd3',
          ),
          Lan07PatchAssignment(
            assignmentId: 'a4',
            portId: 'p4',
            sourceEndpointId: 's4',
            destinationEndpointId: 'd4',
          ),
          Lan07PatchAssignment(
            assignmentId: 'a5',
            portId: 'p5',
            sourceEndpointId: 's5',
            destinationEndpointId: 'd5',
          ),
        ],
        unavailablePortIds: {},
        requiredSourceEndpointIds: {'s1', 's2', 's3', 's4', 's5'},
        sparePolicy: Lan07SparePolicy(
          absoluteMinimum: 2,
          ratio: Elv5Rational.zero,
          combiner: Lan07SpareCombiner.max,
        ),
      ),
    );
    expect(result.occupied, 5);
    expect(result.free, 3);
    expect(result.spareHeadroom, 1);
    expect(result.status, Lan07AssessmentStatus.pass);
  });

  test('two relationships on one physical port count one occupied unit', () {
    final result = const Lan07PatchPanelKernel().evaluate(
      Lan07Input(
        panelId: 'panel-1',
        ports: [
          Lan07PhysicalPort(portId: 'p1'),
          Lan07PhysicalPort(portId: 'p2'),
        ],
        assignments: [
          Lan07PatchAssignment(
            assignmentId: 'termination',
            portId: 'p1',
            sourceEndpointId: 's1',
          ),
          Lan07PatchAssignment(
            assignmentId: 'patch',
            portId: 'p1',
            sourceEndpointId: 's1',
            destinationEndpointId: 'd1',
          ),
        ],
        unavailablePortIds: {},
        requiredSourceEndpointIds: {'s1'},
        sparePolicy: Lan07SparePolicy(
          absoluteMinimum: 1,
          ratio: Elv5Rational.zero,
          combiner: Lan07SpareCombiner.max,
        ),
      ),
    );
    expect(result.occupied, 1);
    expect(result.status, Lan07AssessmentStatus.pass);
  });

  test('different sources cannot share termination and patch on one port', () {
    final assignments = [
      Lan07PatchAssignment(
        assignmentId: 'termination',
        portId: 'p1',
        sourceEndpointId: 's1',
      ),
      Lan07PatchAssignment(
        assignmentId: 'patch',
        portId: 'p1',
        sourceEndpointId: 's2',
        destinationEndpointId: 'd2',
      ),
    ];
    for (final order in [assignments, assignments.reversed.toList()]) {
      final result = const Lan07PatchPanelKernel().evaluate(Lan07Input(
        panelId: 'panel-1',
        ports: [
          Lan07PhysicalPort(portId: 'p1'),
          Lan07PhysicalPort(portId: 'p2')
        ],
        assignments: order,
        unavailablePortIds: {},
        requiredSourceEndpointIds: {'s2'},
        sparePolicy: Lan07SparePolicy(
          absoluteMinimum: 0,
          ratio: Elv5Rational.zero,
          combiner: Lan07SpareCombiner.max,
        ),
      ));
      expect(result.occupied, 1);
      expect(result.status, Lan07AssessmentStatus.fail);
      expect(result.conflictingAssignmentIds, ['patch', 'termination']);
    }
  });

  test('missing destination leaves mapping unresolved', () {
    final result = const Lan07PatchPanelKernel().evaluate(
      Lan07Input(
        panelId: 'panel-1',
        ports: [Lan07PhysicalPort(portId: 'p1')],
        assignments: [
          Lan07PatchAssignment(
            assignmentId: 'a1',
            portId: 'p1',
            sourceEndpointId: 's1',
          ),
        ],
        unavailablePortIds: {},
        requiredSourceEndpointIds: {'s1'},
        sparePolicy: Lan07SparePolicy(
          absoluteMinimum: 0,
          ratio: Elv5Rational.zero,
          combiner: Lan07SpareCombiner.max,
        ),
      ),
    );
    expect(result.status, Lan07AssessmentStatus.unresolved);
  });

  test('multiple destinations for one required source fail mapping cardinality',
      () {
    final result = const Lan07PatchPanelKernel().evaluate(
      Lan07Input(
        panelId: 'panel-1',
        ports: [
          Lan07PhysicalPort(portId: 'p1'),
          Lan07PhysicalPort(portId: 'p2'),
        ],
        assignments: [
          Lan07PatchAssignment(
            assignmentId: 'a1',
            portId: 'p1',
            sourceEndpointId: 's1',
            destinationEndpointId: 'd1',
          ),
          Lan07PatchAssignment(
            assignmentId: 'a2',
            portId: 'p2',
            sourceEndpointId: 's1',
            destinationEndpointId: 'd2',
          ),
        ],
        unavailablePortIds: {},
        requiredSourceEndpointIds: {'s1'},
        sparePolicy: Lan07SparePolicy(
          absoluteMinimum: 0,
          ratio: Elv5Rational.zero,
          combiner: Lan07SpareCombiner.max,
        ),
      ),
    );
    expect(result.status, Lan07AssessmentStatus.fail);
  });
}
