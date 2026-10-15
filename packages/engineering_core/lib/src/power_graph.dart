import 'power_bindings.dart';
import 'power_evaluation.dart';
import 'power_profiles.dart';

enum PowerGraphEdgeKind { externalConnection, passiveContinuity, activeTransfer }

enum PowerGraphLayer { power, dataPower }

enum PowerTraceDirection { upstream, downstream, both }

final class PowerGraphFinding {
  PowerGraphFinding({
    required String code,
    required this.status,
    required String subjectId,
    required String message,
    Iterable<String> witnesses = const [],
  })  : code = _code(code, 'code'),
        subjectId = _text(subjectId, 'subjectId'),
        message = _text(message, 'message'),
        witnesses = List.unmodifiable(_sortedUnique(witnesses, 'witnesses'));

  final String code;
  final PowerEvaluationStatus status;
  final String subjectId;
  final String message;
  final List<String> witnesses;
}

final class PowerGraphPort {
  PowerGraphPort({
    required String portId,
    required String componentId,
    required this.role,
    required this.envelope,
    required Iterable<String> terminalRoles,
    required this.isExplicitSourceBoundary,
  })  : portId = _text(portId, 'portId'),
        componentId = _text(componentId, 'componentId'),
        terminalRoles = List.unmodifiable(
          _sortedUnique(
            terminalRoles.map((value) => value.trim().toUpperCase()),
            'terminalRoles',
          ),
        ) {
    if (this.terminalRoles.isEmpty) {
      throw ArgumentError('Power graph port requires terminal roles.');
    }
    if (isExplicitSourceBoundary &&
        role != PowerPortRole.source &&
        role != PowerPortRole.bidirectional) {
      throw ArgumentError('Explicit source boundary must be source-capable.');
    }
  }

  factory PowerGraphPort.fromBinding({
    required String componentId,
    required PowerPortBinding binding,
    bool isExplicitSourceBoundary = false,
  }) =>
      PowerGraphPort(
        portId: binding.portId,
        componentId: componentId,
        role: binding.role,
        envelope: binding.voltageEnvelope,
        terminalRoles: binding.terminalRoles,
        isExplicitSourceBoundary: isExplicitSourceBoundary,
      );

  final String portId;
  final String componentId;
  final PowerPortRole role;
  final PowerVoltageEnvelope envelope;
  final List<String> terminalRoles;
  final bool isExplicitSourceBoundary;
}

final class PowerGraphEdgeSpec {
  PowerGraphEdgeSpec({
    required String edgeId,
    required String fromPortId,
    required String toPortId,
    required this.kind,
    required this.layer,
    required String sourceEntityId,
    required String provenanceRef,
    Iterable<String> physicalEvidenceRefs = const [],
    this.directionResolved = true,
    String? sourceBoundaryPortId,
    String? supplySetId,
    Iterable<String> enabledStateCodes = const [],
  })  : edgeId = _text(edgeId, 'edgeId'),
        fromPortId = _text(fromPortId, 'fromPortId'),
        toPortId = _text(toPortId, 'toPortId'),
        sourceEntityId = _text(sourceEntityId, 'sourceEntityId'),
        provenanceRef = _text(provenanceRef, 'provenanceRef'),
        physicalEvidenceRefs = List.unmodifiable(
          _sortedUnique(physicalEvidenceRefs, 'physicalEvidenceRefs'),
        ),
        sourceBoundaryPortId = sourceBoundaryPortId == null
            ? null
            : _text(sourceBoundaryPortId, 'sourceBoundaryPortId'),
        supplySetId =
            supplySetId == null ? null : _code(supplySetId, 'supplySetId'),
        enabledStateCodes = List.unmodifiable(
          _sortedUnique(
            enabledStateCodes.map(
              (value) => _code(value, 'enabledStateCode'),
            ),
            'enabledStateCodes',
          ),
        ) {
    if (this.supplySetId != null && this.sourceBoundaryPortId == null) {
      throw ArgumentError('Selected supply edge requires a source boundary id.');
    }
  }

  final String edgeId;
  final String fromPortId;
  final String toPortId;
  final PowerGraphEdgeKind kind;
  final PowerGraphLayer layer;
  final String sourceEntityId;
  final String provenanceRef;
  final List<String> physicalEvidenceRefs;
  final bool directionResolved;
  final String? sourceBoundaryPortId;
  final String? supplySetId;
  final List<String> enabledStateCodes;
}

final class PowerGraphInput {
  PowerGraphInput({
    required String revisionId,
    required String scenarioId,
    required String segmentId,
    required Iterable<PowerGraphPort> ports,
    required Iterable<PowerGraphEdgeSpec> edges,
    required Iterable<PowerSupplyRequirement> supplyRequirements,
    Map<String, String> selectedSourceBySupplySet = const {},
    Iterable<String> unavailableSourceIds = const [],
    Map<String, String> componentStateCodes = const {},
  })  : revisionId = _text(revisionId, 'revisionId'),
        scenarioId = _text(scenarioId, 'scenarioId'),
        segmentId = _text(segmentId, 'segmentId'),
        ports = List.unmodifiable(ports),
        edges = List.unmodifiable(edges),
        supplyRequirements = List.unmodifiable(supplyRequirements),
        selectedSourceBySupplySet = Map.unmodifiable({
          for (final entry in selectedSourceBySupplySet.entries)
            _code(entry.key, 'supplySetId'): _text(entry.value, 'sourceId'),
        }),
        unavailableSourceIds = Set.unmodifiable(
          unavailableSourceIds.map((value) => _text(value, 'sourceId')),
        ),
        componentStateCodes = Map.unmodifiable({
          for (final entry in componentStateCodes.entries)
            _text(entry.key, 'componentId'):
                _code(entry.value, 'componentStateCode'),
        });

  final String revisionId;
  final String scenarioId;
  final String segmentId;
  final List<PowerGraphPort> ports;
  final List<PowerGraphEdgeSpec> edges;
  final List<PowerSupplyRequirement> supplyRequirements;
  final Map<String, String> selectedSourceBySupplySet;
  final Set<String> unavailableSourceIds;
  final Map<String, String> componentStateCodes;
}

final class PowerGraphEdge {
  const PowerGraphEdge({required this.spec, required this.activeReason});

  final PowerGraphEdgeSpec spec;
  final String activeReason;
}

final class PowerGraphSnapshot {
  PowerGraphSnapshot({
    required this.input,
    required Iterable<PowerGraphEdge> activeEdges,
  })  : activeEdges = List.unmodifiable(activeEdges),
        portsById = Map.unmodifiable({
          for (final port in input.ports) port.portId: port,
        });

  final PowerGraphInput input;
  final List<PowerGraphEdge> activeEdges;
  final Map<String, PowerGraphPort> portsById;

  List<PowerGraphEdge> outgoing(String portId) => activeEdges
      .where((edge) => edge.spec.fromPortId == portId)
      .toList(growable: false);

  List<PowerGraphEdge> incoming(String portId) => activeEdges
      .where((edge) => edge.spec.toPortId == portId)
      .toList(growable: false);
}

final class PowerGraphBuildResult {
  const PowerGraphBuildResult({
    required this.graph,
    required this.findings,
    required this.unresolvedEdgeIds,
  });

  final PowerGraphSnapshot? graph;
  final List<PowerGraphFinding> findings;
  final List<String> unresolvedEdgeIds;

  bool get blocked => graph == null;
}

PowerGraphBuildResult buildPowerGraph(PowerGraphInput input) {
  final findings = <PowerGraphFinding>[];
  final duplicatePortIds = _duplicates(input.ports.map((port) => port.portId));
  final duplicateEdgeIds = _duplicates(input.edges.map((edge) => edge.edgeId));
  final duplicateRequirementIds =
      _duplicates(input.supplyRequirements.map((value) => value.id));
  if (duplicatePortIds.isNotEmpty ||
      duplicateEdgeIds.isNotEmpty ||
      duplicateRequirementIds.isNotEmpty) {
    findings.add(
      PowerGraphFinding(
        code: 'ELV4_POWER_GRAPH_DUPLICATE_IDENTITY',
        status: PowerEvaluationStatus.blocked,
        subjectId: input.segmentId,
        message: 'Canonical graph identities must be unique.',
        witnesses: [
          ...duplicatePortIds,
          ...duplicateEdgeIds,
          ...duplicateRequirementIds,
        ],
      ),
    );
    return PowerGraphBuildResult(
      graph: null,
      findings: List.unmodifiable(findings),
      unresolvedEdgeIds: const [],
    );
  }

  final portsById = {for (final port in input.ports) port.portId: port};
  final unresolved = <String>[];
  final activeEdges = <PowerGraphEdge>[];
  for (final edge in input.edges) {
    if (!portsById.containsKey(edge.fromPortId) ||
        !portsById.containsKey(edge.toPortId)) {
      findings.add(
        PowerGraphFinding(
          code: 'ELV4_POWER_GRAPH_UNKNOWN_PORT',
          status: PowerEvaluationStatus.blocked,
          subjectId: edge.edgeId,
          message: 'Graph edge references an unknown canonical port.',
          witnesses: [edge.fromPortId, edge.toPortId],
        ),
      );
      continue;
    }
    if (!edge.directionResolved) {
      unresolved.add(edge.edgeId);
      findings.add(
        PowerGraphFinding(
          code: 'ELV4_POWER_GRAPH_DIRECTION_UNRESOLVED',
          status: PowerEvaluationStatus.unresolved,
          subjectId: edge.edgeId,
          message: 'Power direction must be resolved before activation.',
        ),
      );
      continue;
    }
    if (edge.sourceBoundaryPortId != null &&
        input.unavailableSourceIds.contains(edge.sourceBoundaryPortId)) {
      continue;
    }
    if (edge.supplySetId != null) {
      final selected = input.selectedSourceBySupplySet[edge.supplySetId];
      if (selected == null) {
        unresolved.add(edge.edgeId);
        findings.add(
          PowerGraphFinding(
            code: 'ELV4_POWER_GRAPH_SOURCE_SELECTION_MISSING',
            status: PowerEvaluationStatus.unresolved,
            subjectId: edge.supplySetId!,
            message: 'Alternative supply requires an explicit selected source.',
          ),
        );
        continue;
      }
      if (selected != edge.sourceBoundaryPortId) continue;
    }
    if (edge.enabledStateCodes.isNotEmpty) {
      final componentId = portsById[edge.fromPortId]!.componentId;
      final state = input.componentStateCodes[componentId];
      if (state == null) {
        unresolved.add(edge.edgeId);
        findings.add(
          PowerGraphFinding(
            code: 'ELV4_POWER_GRAPH_COMPONENT_STATE_MISSING',
            status: PowerEvaluationStatus.unresolved,
            subjectId: componentId,
            message: 'Active transfer requires explicit component state.',
          ),
        );
        continue;
      }
      if (!edge.enabledStateCodes.contains(state)) continue;
    }
    activeEdges.add(
      PowerGraphEdge(spec: edge, activeReason: 'SCENARIO_SELECTED'),
    );
  }

  if (findings.any((finding) => finding.status == PowerEvaluationStatus.blocked)) {
    return PowerGraphBuildResult(
      graph: null,
      findings: List.unmodifiable(findings),
      unresolvedEdgeIds: List.unmodifiable(unresolved..sort()),
    );
  }

  activeEdges.sort((a, b) => a.spec.edgeId.compareTo(b.spec.edgeId));
  return PowerGraphBuildResult(
    graph: PowerGraphSnapshot(input: input, activeEdges: activeEdges),
    findings: List.unmodifiable(findings),
    unresolvedEdgeIds: List.unmodifiable(unresolved..sort()),
  );
}

final class PowerTopologyValidation {
  const PowerTopologyValidation({
    required this.status,
    required this.findings,
  });

  final PowerEvaluationStatus status;
  final List<PowerGraphFinding> findings;
}

PowerTopologyValidation validatePowerGraph(PowerGraphSnapshot graph) {
  final findings = <PowerGraphFinding>[];
  final cycle = _cycleWitness(graph);
  if (cycle.isNotEmpty) {
    findings.add(
      PowerGraphFinding(
        code: 'ELV4_POWER_GRAPH_ACTIVE_CYCLE',
        status: PowerEvaluationStatus.blocked,
        subjectId: graph.input.segmentId,
        message: 'Active power graph must be radial and acyclic.',
        witnesses: cycle,
      ),
    );
  }

  for (final edge in graph.activeEdges) {
    if (edge.spec.kind == PowerGraphEdgeKind.activeTransfer) continue;
    final source = graph.portsById[edge.spec.fromPortId]!;
    final consumer = graph.portsById[edge.spec.toPortId]!;
    final compatibility = _validatePortCompatibility(source, consumer);
    if (compatibility != null) findings.add(compatibility);
  }

  if (cycle.isEmpty) {
    findings.addAll(_validateSupplyMultiplicity(graph));
  }

  final unresolvedRequirements = <String>{};
  for (final requirement in graph.input.supplyRequirements) {
    for (final inputPortId in requirement.inputPortIds) {
      if (!graph.portsById.containsKey(inputPortId)) {
        findings.add(
          PowerGraphFinding(
            code: 'ELV4_POWER_GRAPH_REQUIREMENT_PORT_MISSING',
            status: PowerEvaluationStatus.blocked,
            subjectId: requirement.id,
            message: 'Supply requirement references a missing input port.',
            witnesses: [inputPortId],
          ),
        );
      } else if (graph.incoming(inputPortId).isEmpty) {
        unresolvedRequirements.add(requirement.id);
      }
    }
  }
  for (final requirementId in unresolvedRequirements) {
    findings.add(
      PowerGraphFinding(
        code: 'ELV4_POWER_GRAPH_SUPPLY_UNRESOLVED',
        status: PowerEvaluationStatus.unresolved,
        subjectId: requirementId,
        message: 'Consumer supply has no active upstream path.',
      ),
    );
  }

  final status = findings.any(
    (finding) => finding.status == PowerEvaluationStatus.blocked,
  )
      ? PowerEvaluationStatus.blocked
      : findings.any(
          (finding) => finding.status == PowerEvaluationStatus.unresolved,
        )
          ? PowerEvaluationStatus.unresolved
          : PowerEvaluationStatus.pass;
  return PowerTopologyValidation(
    status: status,
    findings: List.unmodifiable(findings),
  );
}

final class PowerTraceRequest {
  PowerTraceRequest({
    required String portId,
    required this.direction,
  }) : portId = _text(portId, 'portId');

  final String portId;
  final PowerTraceDirection direction;
}

final class PowerTraceResult {
  const PowerTraceResult({
    required this.edgeIds,
    required this.sourceBoundaryPortIds,
    required this.unresolvedFrontierPortIds,
    required this.findings,
  });

  final List<String> edgeIds;
  final List<String> sourceBoundaryPortIds;
  final List<String> unresolvedFrontierPortIds;
  final List<PowerGraphFinding> findings;
}

PowerTraceResult tracePower(PowerGraphSnapshot graph, PowerTraceRequest request) {
  if (!graph.portsById.containsKey(request.portId)) {
    throw ArgumentError('Trace subject port is not present in the graph.');
  }
  final edgeIds = <String>{};
  final sources = <String>{};
  final frontier = <String>{};
  final findings = <PowerGraphFinding>[];
  final visited = <String>{};

  void walk(String portId, bool upstream) {
    final visitKey = '${upstream ? 'U' : 'D'}:$portId';
    if (!visited.add(visitKey)) {
      findings.add(
        PowerGraphFinding(
          code: 'ELV4_POWER_TRACE_CYCLE_WITNESS',
          status: PowerEvaluationStatus.blocked,
          subjectId: portId,
          message: 'Trace terminated at an already visited power vertex.',
        ),
      );
      return;
    }
    final port = graph.portsById[portId]!;
    if (upstream && port.isExplicitSourceBoundary) {
      sources.add(port.portId);
      return;
    }
    final edges = upstream ? graph.incoming(portId) : graph.outgoing(portId);
    if (edges.isEmpty) {
      frontier.add(portId);
      return;
    }
    for (final edge in edges) {
      edgeIds.add(edge.spec.edgeId);
      walk(upstream ? edge.spec.fromPortId : edge.spec.toPortId, upstream);
    }
  }

  if (request.direction == PowerTraceDirection.upstream ||
      request.direction == PowerTraceDirection.both) {
    walk(request.portId, true);
  }
  if (request.direction == PowerTraceDirection.downstream ||
      request.direction == PowerTraceDirection.both) {
    walk(request.portId, false);
  }

  final sortedEdges = edgeIds.toList()..sort();
  final sortedSources = sources.toList()..sort();
  final sortedFrontier = frontier.toList()..sort();
  return PowerTraceResult(
    edgeIds: List.unmodifiable(sortedEdges),
    sourceBoundaryPortIds: List.unmodifiable(sortedSources),
    unresolvedFrontierPortIds: List.unmodifiable(sortedFrontier),
    findings: List.unmodifiable(findings),
  );
}

PowerGraphFinding? _validatePortCompatibility(
  PowerGraphPort source,
  PowerGraphPort consumer,
) {
  if (source.envelope.currentKind != consumer.envelope.currentKind) {
    return PowerGraphFinding(
      code: 'ELV4_POWER_DOMAIN_MISMATCH',
      status: PowerEvaluationStatus.blocked,
      subjectId: consumer.portId,
      message: 'Passive/external edge cannot convert AC and DC domains.',
      witnesses: [source.portId],
    );
  }
  if (source.envelope.minV < consumer.envelope.minV ||
      source.envelope.maxV > consumer.envelope.maxV) {
    return PowerGraphFinding(
      code: 'ELV4_POWER_VOLTAGE_GUARANTEE_MISMATCH',
      status: PowerEvaluationStatus.blocked,
      subjectId: consumer.portId,
      message: 'Source guaranteed voltage range is not contained by consumer.',
      witnesses: [source.portId],
    );
  }
  if (source.envelope.currentKind == PowerCurrentKind.ac &&
      (source.envelope.frequencyMinHz! < consumer.envelope.frequencyMinHz! ||
          source.envelope.frequencyMaxHz! > consumer.envelope.frequencyMaxHz!)) {
    return PowerGraphFinding(
      code: 'ELV4_POWER_FREQUENCY_GUARANTEE_MISMATCH',
      status: PowerEvaluationStatus.blocked,
      subjectId: consumer.portId,
      message: 'Source frequency guarantee is outside consumer tolerance.',
      witnesses: [source.portId],
    );
  }
  if (source.envelope.currentKind == PowerCurrentKind.dc) {
    final sourceTerminals = source.terminalRoles.toSet();
    final consumerTerminals = consumer.terminalRoles.toSet();
    if (sourceTerminals.length != consumerTerminals.length ||
        sourceTerminals.difference(consumerTerminals).isNotEmpty) {
      return PowerGraphFinding(
        code: 'ELV4_POWER_DC_TERMINAL_MISMATCH',
        status: PowerEvaluationStatus.blocked,
        subjectId: consumer.portId,
        message: 'DC terminal roles are incompatible.',
        witnesses: [source.portId],
      );
    }
  }
  return null;
}

List<PowerGraphFinding> _validateSupplyMultiplicity(PowerGraphSnapshot graph) {
  final indegree = <String, int>{for (final id in graph.portsById.keys) id: 0};
  for (final edge in graph.activeEdges) {
    indegree[edge.spec.toPortId] = indegree[edge.spec.toPortId]! + 1;
  }
  final queue = indegree.entries
      .where((entry) => entry.value == 0)
      .map((entry) => entry.key)
      .toList()
    ..sort();
  final pathCount = <String, int>{for (final id in graph.portsById.keys) id: 0};
  final sourceSets = <String, Set<String>>{
    for (final id in graph.portsById.keys) id: <String>{},
  };
  for (final port in graph.portsById.values) {
    if (port.isExplicitSourceBoundary &&
        !graph.input.unavailableSourceIds.contains(port.portId)) {
      pathCount[port.portId] = 1;
      sourceSets[port.portId]!.add(port.portId);
    }
  }

  var index = 0;
  while (index < queue.length) {
    final from = queue[index++];
    for (final edge in graph.outgoing(from)) {
      final to = edge.spec.toPortId;
      pathCount[to] = _capTwo(pathCount[to]! + pathCount[from]!);
      sourceSets[to]!.addAll(sourceSets[from]!);
      indegree[to] = indegree[to]! - 1;
      if (indegree[to] == 0) queue.add(to);
    }
  }

  final findings = <PowerGraphFinding>[];
  for (final port in graph.portsById.values) {
    final sources = sourceSets[port.portId]!;
    if (sources.length > 1) {
      findings.add(
        PowerGraphFinding(
          code: 'ELV4_POWER_MULTIPLE_SOURCES',
          status: PowerEvaluationStatus.blocked,
          subjectId: port.portId,
          message: 'Multiple energized source boundaries reach the same port.',
          witnesses: sources,
        ),
      );
    } else if (pathCount[port.portId]! > 1) {
      findings.add(
        PowerGraphFinding(
          code: 'ELV4_POWER_RADIAL_RECONVERGENCE',
          status: PowerEvaluationStatus.blocked,
          subjectId: port.portId,
          message: 'More than one energized path reaches the same port.',
          witnesses: sources,
        ),
      );
    }
  }
  return findings;
}

List<String> _cycleWitness(PowerGraphSnapshot graph) {
  final state = <String, int>{};
  final stack = <String>[];
  List<String> witness = const [];

  bool visit(String portId) {
    state[portId] = 1;
    stack.add(portId);
    for (final edge in graph.outgoing(portId)) {
      final next = edge.spec.toPortId;
      if (state[next] == 1) {
        final start = stack.indexOf(next);
        witness = [...stack.sublist(start), next];
        return true;
      }
      if (state[next] != 2 && visit(next)) return true;
    }
    stack.removeLast();
    state[portId] = 2;
    return false;
  }

  final ids = graph.portsById.keys.toList()..sort();
  for (final id in ids) {
    if (state[id] == null && visit(id)) break;
  }
  return witness;
}

int _capTwo(int value) => value > 1 ? 2 : value;

List<String> _duplicates(Iterable<String> values) {
  final seen = <String>{};
  final duplicates = <String>{};
  for (final value in values) {
    if (!seen.add(value)) duplicates.add(value);
  }
  final result = duplicates.toList()..sort();
  return result;
}

List<String> _sortedUnique(Iterable<String> values, String field) {
  final result = values.map((value) => _text(value, field)).toList()..sort();
  if (result.toSet().length != result.length) {
    throw ArgumentError('$field must be unique.');
  }
  return result;
}

String _text(String value, String field) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, field, 'Must not be empty.');
  }
  return normalized;
}

String _code(String value, String field) {
  final normalized = _text(value, field).toUpperCase();
  if (!RegExp(r'^[A-Z][A-Z0-9_-]{0,127}$').hasMatch(normalized)) {
    throw ArgumentError.value(value, field, 'Invalid canonical code.');
  }
  return normalized;
}
