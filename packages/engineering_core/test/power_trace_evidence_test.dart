import 'package:engineering_core/engineering_core.dart';
import 'package:test/test.dart';

void main() {
  group('P3 ordered trace evidence', () {
    test(
        'upstream trace retains ordered canonical provenance and physical refs',
        () {
      final graph = buildPowerGraph(
        PowerGraphInput(
          revisionId: 'revision-r1',
          scenarioId: 'scenario-normal',
          segmentId: 'segment-1',
          ports: [
            _port('source', 'psu', PowerPortRole.source, source: true),
            _port('patch', 'patch-panel', PowerPortRole.passive),
            _port('load', 'camera', PowerPortRole.consumer),
          ],
          edges: [
            _edge(
              'e-01',
              'source',
              'patch',
              entity: 'cable-run-1',
              provenance: 'connection:power-1',
              physicalRefs: const ['run:1', 'route:1'],
            ),
            _edge(
              'e-02',
              'patch',
              'load',
              entity: 'mapping-1',
              provenance: 'passive-map:1',
              kind: PowerGraphEdgeKind.passiveContinuity,
              physicalRefs: const ['enclosure:pp-1'],
            ),
          ],
          supplyRequirements: [_requirement('load', 'source')],
        ),
      ).graph!;

      final trace = buildPowerTraceEvidence(
        graph,
        PowerTraceRequest(
          portId: 'load',
          direction: PowerTraceDirection.upstream,
        ),
      );

      expect(trace.revisionId, 'revision-r1');
      expect(trace.scenarioId, 'scenario-normal');
      expect(trace.segmentId, 'segment-1');
      expect(trace.sourceBoundaryPortIds, ['source']);
      expect(trace.unresolvedFrontierPortIds, isEmpty);
      expect(trace.entries.map((entry) => entry.edgeId), ['e-02', 'e-01']);

      final first = trace.entries.first;
      expect(first.sourceEntityId, 'mapping-1');
      expect(first.fromPortId, 'patch');
      expect(first.toPortId, 'load');
      expect(first.fromComponentId, 'patch-panel');
      expect(first.toComponentId, 'camera');
      expect(first.provenanceRef, 'passive-map:1');
      expect(first.physicalEvidenceRefs, ['enclosure:pp-1']);
      expect(first.activeReason, 'SCENARIO_SELECTED');
    });

    test('both-direction trace is deterministic and never duplicates an edge',
        () {
      final graph = buildPowerGraph(
        PowerGraphInput(
          revisionId: 'revision-r1',
          scenarioId: 'scenario-normal',
          segmentId: 'segment-1',
          ports: [
            _port('source', 'psu', PowerPortRole.source, source: true),
            _port('mid', 'distribution', PowerPortRole.passive),
            _port('load-a', 'camera-a', PowerPortRole.consumer),
            _port('load-b', 'camera-b', PowerPortRole.consumer),
          ],
          edges: [
            _edge('e-01', 'source', 'mid'),
            _edge('e-02', 'mid', 'load-a'),
            _edge('e-03', 'mid', 'load-b'),
          ],
          supplyRequirements: [
            _requirement('load-a', 'source'),
            _requirement('load-b', 'source'),
          ],
        ),
      ).graph!;

      final trace = buildPowerTraceEvidence(
        graph,
        PowerTraceRequest(
          portId: 'mid',
          direction: PowerTraceDirection.both,
        ),
      );

      expect(trace.entries.map((entry) => entry.edgeId), [
        'e-01',
        'e-02',
        'e-03',
      ]);
      expect(trace.entries.map((entry) => entry.edgeId).toSet(), hasLength(3));
    });
  });
}

PowerGraphPort _port(
  String id,
  String componentId,
  PowerPortRole role, {
  bool source = false,
}) =>
    PowerGraphPort(
      portId: id,
      componentId: componentId,
      role: role,
      envelope: PowerVoltageEnvelope(
        currentKind: PowerCurrentKind.dc,
        minV: PowerRational.fromWireDecimal('24'),
        nominalV: PowerRational.fromWireDecimal('24'),
        maxV: PowerRational.fromWireDecimal('24'),
      ),
      terminalRoles: const ['PLUS', 'MINUS'],
      isExplicitSourceBoundary: source,
    );

PowerGraphEdgeSpec _edge(
  String id,
  String from,
  String to, {
  String? entity,
  String? provenance,
  PowerGraphEdgeKind kind = PowerGraphEdgeKind.externalConnection,
  Iterable<String> physicalRefs = const [],
}) =>
    PowerGraphEdgeSpec(
      edgeId: id,
      fromPortId: from,
      toPortId: to,
      kind: kind,
      layer: PowerGraphLayer.power,
      sourceEntityId: entity ?? 'entity-$id',
      provenanceRef: provenance ?? 'fixture:$id',
      physicalEvidenceRefs: physicalRefs,
    );

PowerSupplyRequirement _requirement(String inputPort, String sourceId) =>
    PowerSupplyRequirement(
      id: 'REQ-$inputPort',
      consumerComponentId: 'component-$inputPort',
      supplySetId: 'PRIMARY-$inputPort',
      inputPortIds: [inputPort],
      selectionMode: PowerSupplySelectionMode.single,
      candidateSourceIds: [sourceId],
      requiredCurrentKind: PowerCurrentKind.dc,
      requiredStateCodes: const ['NORMAL'],
    );
