import 'power_graph.dart';

final class PowerTraceEvidenceEntry {
  PowerTraceEvidenceEntry({
    required this.edgeId,
    required this.kind,
    required this.layer,
    required this.sourceEntityId,
    required this.fromPortId,
    required this.toPortId,
    required this.fromComponentId,
    required this.toComponentId,
    required this.provenanceRef,
    required Iterable<String> physicalEvidenceRefs,
    required this.activeReason,
  }) : physicalEvidenceRefs = List.unmodifiable(physicalEvidenceRefs);

  final String edgeId;
  final PowerGraphEdgeKind kind;
  final PowerGraphLayer layer;
  final String sourceEntityId;
  final String fromPortId;
  final String toPortId;
  final String fromComponentId;
  final String toComponentId;
  final String provenanceRef;
  final List<String> physicalEvidenceRefs;
  final String activeReason;
}

final class PowerTraceEvidenceResult {
  const PowerTraceEvidenceResult({
    required this.revisionId,
    required this.scenarioId,
    required this.segmentId,
    required this.subjectPortId,
    required this.direction,
    required this.entries,
    required this.sourceBoundaryPortIds,
    required this.unresolvedFrontierPortIds,
    required this.findings,
  });

  final String revisionId;
  final String scenarioId;
  final String segmentId;
  final String subjectPortId;
  final PowerTraceDirection direction;
  final List<PowerTraceEvidenceEntry> entries;
  final List<String> sourceBoundaryPortIds;
  final List<String> unresolvedFrontierPortIds;
  final List<PowerGraphFinding> findings;
}

PowerTraceEvidenceResult buildPowerTraceEvidence(
  PowerGraphSnapshot graph,
  PowerTraceRequest request,
) {
  if (!graph.portsById.containsKey(request.portId)) {
    throw ArgumentError('Trace subject port is not present in the graph.');
  }

  final base = tracePower(graph, request);
  final entries = <PowerTraceEvidenceEntry>[];
  final visitedEdges = <String>{};
  final visitedVertices = <String>{};

  void walk(String portId, bool upstream) {
    final vertexKey = '${upstream ? 'U' : 'D'}:$portId';
    if (!visitedVertices.add(vertexKey)) return;

    final port = graph.portsById[portId]!;
    if (upstream && port.isExplicitSourceBoundary) return;

    final edges = (upstream ? graph.incoming(portId) : graph.outgoing(portId))
        .toList(growable: false)
      ..sort((a, b) => a.spec.edgeId.compareTo(b.spec.edgeId));

    for (final edge in edges) {
      if (visitedEdges.add(edge.spec.edgeId)) {
        final from = graph.portsById[edge.spec.fromPortId]!;
        final to = graph.portsById[edge.spec.toPortId]!;
        entries.add(
          PowerTraceEvidenceEntry(
            edgeId: edge.spec.edgeId,
            kind: edge.spec.kind,
            layer: edge.spec.layer,
            sourceEntityId: edge.spec.sourceEntityId,
            fromPortId: edge.spec.fromPortId,
            toPortId: edge.spec.toPortId,
            fromComponentId: from.componentId,
            toComponentId: to.componentId,
            provenanceRef: edge.spec.provenanceRef,
            physicalEvidenceRefs: edge.spec.physicalEvidenceRefs,
            activeReason: edge.activeReason,
          ),
        );
      }
      walk(upstream ? edge.spec.fromPortId : edge.spec.toPortId, upstream);
    }
  }

  switch (request.direction) {
    case PowerTraceDirection.upstream:
      walk(request.portId, true);
    case PowerTraceDirection.downstream:
      walk(request.portId, false);
    case PowerTraceDirection.both:
      walk(request.portId, true);
      walk(request.portId, false);
  }

  return PowerTraceEvidenceResult(
    revisionId: graph.input.revisionId,
    scenarioId: graph.input.scenarioId,
    segmentId: graph.input.segmentId,
    subjectPortId: request.portId,
    direction: request.direction,
    entries: List.unmodifiable(entries),
    sourceBoundaryPortIds: base.sourceBoundaryPortIds,
    unresolvedFrontierPortIds: base.unresolvedFrontierPortIds,
    findings: base.findings,
  );
}
