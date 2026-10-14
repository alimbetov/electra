from pathlib import Path

path = Path('apps/mobile/lib/application/engineering_reference_revision_preview.dart')
text = path.read_text()

text = text.replace(
"""    required Iterable<String> connectionIds,
    required Iterable<String> topologyGroupIds,
    required this.graphFingerprint,""",
"""    required Iterable<String> connectionIds,
    required Iterable<String> topologyGroupIds,
    required Iterable<String> internalMappingIds,
    required this.graphFingerprint,""",
1,
)
text = text.replace(
"""       connectionIds = List.unmodifiable(connectionIds),
       topologyGroupIds = List.unmodifiable(topologyGroupIds),
       candidateProfileValidationErrors = List.unmodifiable(""",
"""       connectionIds = List.unmodifiable(connectionIds),
       topologyGroupIds = List.unmodifiable(topologyGroupIds),
       internalMappingIds = List.unmodifiable(internalMappingIds),
       candidateProfileValidationErrors = List.unmodifiable(""",
1,
)
text = text.replace(
"""  final List<String> connectionIds;
  final List<String> topologyGroupIds;
  final String graphFingerprint;""",
"""  final List<String> connectionIds;
  final List<String> topologyGroupIds;
  final List<String> internalMappingIds;
  final String graphFingerprint;""",
1,
)
text = text.replace(
"""  bool get affectsProjectGraph =>
      connectionIds.isNotEmpty || topologyGroupIds.isNotEmpty;""",
"""  bool get affectsProjectGraph =>
      connectionIds.isNotEmpty ||
      topologyGroupIds.isNotEmpty ||
      internalMappingIds.isNotEmpty;""",
1,
)
text = text.replace(
"""  Set<String> get affectedTopologyGroupIds => {
    for (final impact in bindingImpacts) ...impact.topologyGroupIds,
  };

  bool get affectsPlacement""",
"""  Set<String> get affectedTopologyGroupIds => {
    for (final impact in bindingImpacts) ...impact.topologyGroupIds,
  };

  Set<String> get affectedInternalMappingIds => {
    for (final impact in bindingImpacts) ...impact.internalMappingIds,
  };

  bool get affectsPlacement""",
1,
)
text = text.replace(
"""          connectionIds: graph.connections,
          topologyGroupIds: graph.groups,
          graphFingerprint: graph.fingerprint,""",
"""          connectionIds: graph.connections,
          topologyGroupIds: graph.groups,
          internalMappingIds: graph.internalMappings,
          graphFingerprint: graph.fingerprint,""",
1,
)
text = text.replace(
"""        connectionIds: graph.connections,
        topologyGroupIds: graph.groups,
        graphFingerprint: graph.fingerprint,""",
"""        connectionIds: graph.connections,
        topologyGroupIds: graph.groups,
        internalMappingIds: graph.internalMappings,
        graphFingerprint: graph.fingerprint,""",
1,
)
text = text.replace(
"""({List<String> connections, List<String> groups, String fingerprint})
_graphImpact(""",
"""({
  List<String> connections,
  List<String> groups,
  List<String> internalMappings,
  String fingerprint,
}) _graphImpact(""",
1,
)
text = text.replace(
"""    connections: relevantConnections.map((item) => item.id).toList(),
    groups: relevantGroups.map((item) => item.id).toList(),
    fingerprint: canonicalEngineeringJson({""",
"""    connections: relevantConnections.map((item) => item.id).toList(),
    groups: relevantGroups.map((item) => item.id).toList(),
    internalMappings: relevantInternal.map((item) => item.id).toList(),
    fingerprint: canonicalEngineeringJson({""",
1,
)
path.write_text(text)
