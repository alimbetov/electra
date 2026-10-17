import 'package:engineering_core/engineering_core_elv5.dart';

final class Acs06TopologyProfileIdentity {
  Acs06TopologyProfileIdentity({
    required String profileCode,
    required String editionId,
    required String contentHash,
  }) : profileCode = _text(profileCode, 'profileCode'),
       editionId = _text(editionId, 'editionId'),
       contentHash = _sha(contentHash, 'contentHash');

  final String profileCode;
  final String editionId;
  final String contentHash;

  Map<String, Object?> toCanonicalValue() => <String, Object?>{
    'profileCode': profileCode,
    'editionId': editionId,
    'contentHash': contentHash,
  };

  factory Acs06TopologyProfileIdentity.fromMap(Map<String, Object?> map) {
    _exact(map, const {
      'profileCode',
      'editionId',
      'contentHash',
    }, 'topologyProfile');
    return Acs06TopologyProfileIdentity(
      profileCode: _mapText(map, 'profileCode'),
      editionId: _mapText(map, 'editionId'),
      contentHash: _mapText(map, 'contentHash'),
    );
  }
}

final class Acs06TopologyEdgeContract {
  Acs06TopologyEdgeContract({
    required String edgeId,
    required String fromNodeId,
    required String toNodeId,
    required String kindCode,
  }) : edgeId = _text(edgeId, 'edgeId'),
       fromNodeId = _text(fromNodeId, 'fromNodeId'),
       toNodeId = _text(toNodeId, 'toNodeId'),
       kindCode = _edgeKind(kindCode);

  final String edgeId;
  final String fromNodeId;
  final String toNodeId;
  final String kindCode;

  Map<String, Object?> toCanonicalValue() => <String, Object?>{
    'edgeId': edgeId,
    'fromNodeId': fromNodeId,
    'toNodeId': toNodeId,
    'kindCode': kindCode,
  };

  factory Acs06TopologyEdgeContract.fromMap(Map<String, Object?> map) {
    _exact(map, const {'edgeId', 'fromNodeId', 'toNodeId', 'kindCode'}, 'edge');
    return Acs06TopologyEdgeContract(
      edgeId: _mapText(map, 'edgeId'),
      fromNodeId: _mapText(map, 'fromNodeId'),
      toNodeId: _mapText(map, 'toNodeId'),
      kindCode: _mapText(map, 'kindCode'),
    );
  }
}

final class Acs06PathRequirementContract {
  Acs06PathRequirementContract({
    required String requirementId,
    required String fromNodeId,
    required String toNodeId,
    required Iterable<String> allowedKindCodes,
  }) : requirementId = _text(requirementId, 'requirementId'),
       fromNodeId = _text(fromNodeId, 'fromNodeId'),
       toNodeId = _text(toNodeId, 'toNodeId'),
       allowedKindCodes = Set.unmodifiable(allowedKindCodes.map(_edgeKind)) {
    if (this.allowedKindCodes.isEmpty) {
      throw ArgumentError(
        'ACS06 path requirement must allow at least one edge kind.',
      );
    }
  }

  final String requirementId;
  final String fromNodeId;
  final String toNodeId;
  final Set<String> allowedKindCodes;

  Map<String, Object?> toCanonicalValue() => <String, Object?>{
    'requirementId': requirementId,
    'fromNodeId': fromNodeId,
    'toNodeId': toNodeId,
    'allowedKindCodes': allowedKindCodes.toList()..sort(),
  };

  factory Acs06PathRequirementContract.fromMap(Map<String, Object?> map) {
    _exact(map, const {
      'requirementId',
      'fromNodeId',
      'toNodeId',
      'allowedKindCodes',
    }, 'pathRequirement');
    return Acs06PathRequirementContract(
      requirementId: _mapText(map, 'requirementId'),
      fromNodeId: _mapText(map, 'fromNodeId'),
      toNodeId: _mapText(map, 'toNodeId'),
      allowedKindCodes: _strings(map['allowedKindCodes'], 'allowedKindCodes'),
    );
  }
}

final class Acs06CauseProfileContract {
  Acs06CauseProfileContract({
    required String causeCode,
    required Iterable<Acs06PathRequirementContract> requiredPaths,
    required String outcomeWhenSatisfiedCode,
    required this.requiresConductiveFeed,
    required this.requiresSupervision,
  }) : causeCode = _cause(causeCode),
       requiredPaths = List.unmodifiable(_paths(requiredPaths)),
       outcomeWhenSatisfiedCode = _outcome(outcomeWhenSatisfiedCode);

  final String causeCode;
  final List<Acs06PathRequirementContract> requiredPaths;
  final String outcomeWhenSatisfiedCode;
  final bool requiresConductiveFeed;
  final bool requiresSupervision;

  Map<String, Object?> toCanonicalValue() => <String, Object?>{
    'causeCode': causeCode,
    'requiredPaths': <Object?>[
      for (final value in requiredPaths) value.toCanonicalValue(),
    ],
    'outcomeWhenSatisfiedCode': outcomeWhenSatisfiedCode,
    'requiresConductiveFeed': requiresConductiveFeed,
    'requiresSupervision': requiresSupervision,
  };

  factory Acs06CauseProfileContract.fromMap(Map<String, Object?> map) {
    _exact(map, const {
      'causeCode',
      'requiredPaths',
      'outcomeWhenSatisfiedCode',
      'requiresConductiveFeed',
      'requiresSupervision',
    }, 'causeProfile');
    final paths = map['requiredPaths'];
    if (paths is! List ||
        map['requiresConductiveFeed'] is! bool ||
        map['requiresSupervision'] is! bool) {
      throw const FormatException('ACS06 cause profile field type mismatch.');
    }
    return Acs06CauseProfileContract(
      causeCode: _mapText(map, 'causeCode'),
      requiredPaths: <Acs06PathRequirementContract>[
        for (final raw in paths)
          Acs06PathRequirementContract.fromMap(_map(raw, 'requiredPath')),
      ],
      outcomeWhenSatisfiedCode: _mapText(map, 'outcomeWhenSatisfiedCode'),
      requiresConductiveFeed: map['requiresConductiveFeed']! as bool,
      requiresSupervision: map['requiresSupervision']! as bool,
    );
  }
}

final class Acs06TopologyContract {
  Acs06TopologyContract({
    required String doorId,
    required String expectedDoorAggregateFingerprint,
    required this.topologyProfile,
    required Map<String, String> componentNodeIdByComponentId,
    required Iterable<Acs06TopologyEdgeContract> edges,
    required Iterable<Acs06CauseProfileContract> causeProfiles,
    String? projectDefinedPowerFailureOutcomeCode,
  }) : doorId = _text(doorId, 'doorId'),
       expectedDoorAggregateFingerprint = _sha(
         expectedDoorAggregateFingerprint,
         'expectedDoorAggregateFingerprint',
       ),
       componentNodeIdByComponentId = Map.unmodifiable(
         _componentNodes(componentNodeIdByComponentId),
       ),
       edges = List.unmodifiable(_edges(edges)),
       causeProfiles = List.unmodifiable(_causes(causeProfiles)),
       projectDefinedPowerFailureOutcomeCode =
           projectDefinedPowerFailureOutcomeCode == null
               ? null
               : _outcome(projectDefinedPowerFailureOutcomeCode) {
    final graphNodes = <String>{
      for (final edge in this.edges) edge.fromNodeId,
      for (final edge in this.edges) edge.toNodeId,
    };
    if (!graphNodes.containsAll(this.componentNodeIdByComponentId.values)) {
      throw ArgumentError('ACS06 graph omits mapped component node.');
    }
    for (final profile in this.causeProfiles) {
      for (final path in profile.requiredPaths) {
        if (!graphNodes.contains(path.fromNodeId) ||
            !graphNodes.contains(path.toNodeId)) {
          throw ArgumentError(
            'ACS06 path requirement references node outside graph: '
            '${path.requirementId}',
          );
        }
      }
    }
  }

  static const schema = 'electra.elv5-acs06-topology-contract.v1';

  final String doorId;
  final String expectedDoorAggregateFingerprint;
  final Acs06TopologyProfileIdentity topologyProfile;
  final Map<String, String> componentNodeIdByComponentId;
  final List<Acs06TopologyEdgeContract> edges;
  final List<Acs06CauseProfileContract> causeProfiles;
  final String? projectDefinedPowerFailureOutcomeCode;

  Map<String, Object?> toCanonicalValue() => <String, Object?>{
    'schema': schema,
    'doorId': doorId,
    'expectedDoorAggregateFingerprint': expectedDoorAggregateFingerprint,
    'topologyProfile': topologyProfile.toCanonicalValue(),
    'componentNodeIdByComponentId': <String, Object?>{
      for (final key in componentNodeIdByComponentId.keys.toList()..sort())
        key: componentNodeIdByComponentId[key],
    },
    'edges': <Object?>[for (final edge in edges) edge.toCanonicalValue()],
    'causeProfiles': <Object?>[
      for (final profile in causeProfiles) profile.toCanonicalValue(),
    ],
    'projectDefinedPowerFailureOutcomeCode':
        projectDefinedPowerFailureOutcomeCode,
  };

  factory Acs06TopologyContract.fromMap(Map<String, Object?> map) {
    _exact(map, const {
      'schema',
      'doorId',
      'expectedDoorAggregateFingerprint',
      'topologyProfile',
      'componentNodeIdByComponentId',
      'edges',
      'causeProfiles',
      'projectDefinedPowerFailureOutcomeCode',
    }, 'ACS06 contract');
    if (map['schema'] != schema)
      throw const FormatException('Unsupported ACS06 contract schema.');
    final componentNodes = _map(
      map['componentNodeIdByComponentId'],
      'componentNodeIdByComponentId',
    );
    final edges = map['edges'];
    final causes = map['causeProfiles'];
    if (edges is! List || causes is! List)
      throw const FormatException('ACS06 edges/causeProfiles must be arrays.');
    return Acs06TopologyContract(
      doorId: _mapText(map, 'doorId'),
      expectedDoorAggregateFingerprint: _mapText(
        map,
        'expectedDoorAggregateFingerprint',
      ),
      topologyProfile: Acs06TopologyProfileIdentity.fromMap(
        _map(map['topologyProfile'], 'topologyProfile'),
      ),
      componentNodeIdByComponentId: <String, String>{
        for (final entry in componentNodes.entries)
          _text(entry.key, 'componentId'): _string(entry.value, 'nodeId'),
      },
      edges: <Acs06TopologyEdgeContract>[
        for (final raw in edges)
          Acs06TopologyEdgeContract.fromMap(_map(raw, 'edge')),
      ],
      causeProfiles: <Acs06CauseProfileContract>[
        for (final raw in causes)
          Acs06CauseProfileContract.fromMap(_map(raw, 'causeProfile')),
      ],
      projectDefinedPowerFailureOutcomeCode: _nullableText(
        map['projectDefinedPowerFailureOutcomeCode'],
        'projectDefinedPowerFailureOutcomeCode',
      ),
    );
  }
}

final class Acs06TopologyContractSnapshot {
  const Acs06TopologyContractSnapshot({
    required this.bindingId,
    required this.bindingRevision,
    required this.evidenceRef,
    required this.contentHash,
    required this.contract,
  });
  final String bindingId;
  final int bindingRevision;
  final String evidenceRef;
  final String contentHash;
  final Acs06TopologyContract contract;
}

abstract interface class Acs06TopologyContractSource {
  Future<Acs06TopologyContractSnapshot?> loadActiveForDoor({
    required String projectId,
    required String designRevisionId,
    required String doorId,
  });
}

Map<String, String> _componentNodes(Map<String, String> input) {
  final out = <String, String>{};
  final nodes = <String>{};
  for (final entry in input.entries) {
    final component = _text(entry.key, 'componentId');
    final node = _text(entry.value, 'nodeId');
    if (!nodes.add(node))
      throw ArgumentError('ACS06 duplicate component node: $node');
    out[component] = node;
  }
  if (out.isEmpty)
    throw ArgumentError('ACS06 component-node map must not be empty.');
  return out;
}

List<Acs06TopologyEdgeContract> _edges(
  Iterable<Acs06TopologyEdgeContract> values,
) {
  final out = values.toList()..sort((a, b) => a.edgeId.compareTo(b.edgeId));
  final ids = <String>{};
  for (final edge in out) {
    if (!ids.add(edge.edgeId))
      throw ArgumentError('ACS06 duplicate edgeId: ${edge.edgeId}');
  }
  if (out.isEmpty) throw ArgumentError('ACS06 edge set must not be empty.');
  return out;
}

List<Acs06PathRequirementContract> _paths(
  Iterable<Acs06PathRequirementContract> values,
) {
  final out =
      values.toList()
        ..sort((a, b) => a.requirementId.compareTo(b.requirementId));
  final ids = <String>{};
  for (final path in out) {
    if (!ids.add(path.requirementId)) {
      throw ArgumentError(
        'ACS06 duplicate path requirementId: ${path.requirementId}',
      );
    }
  }
  return out;
}

List<Acs06CauseProfileContract> _causes(
  Iterable<Acs06CauseProfileContract> values,
) {
  final out =
      values.toList()..sort((a, b) => a.causeCode.compareTo(b.causeCode));
  final actual = out.map((e) => e.causeCode).toSet();
  const expected = {
    'NORMAL_ACCESS',
    'REQUEST_TO_EXIT',
    'FIRE_RELEASE',
    'EMERGENCY_BREAK_GLASS',
    'POWER_FAILURE',
  };
  if (actual.length != expected.length || !actual.containsAll(expected)) {
    throw ArgumentError(
      'ACS06 requires exactly five canonical cause profiles.',
    );
  }
  return out;
}

String _edgeKind(String value) {
  final code = _text(value, 'edgeKind').toUpperCase();
  if (!const {
    'DATA',
    'CONTROL',
    'POWER_FEED',
    'MONITOR',
    'RELEASE',
  }.contains(code)) {
    throw ArgumentError('Unsupported ACS06 edge kind: $code');
  }
  return code;
}

String _cause(String value) {
  final code = _text(value, 'causeCode').toUpperCase();
  if (!const {
    'NORMAL_ACCESS',
    'REQUEST_TO_EXIT',
    'FIRE_RELEASE',
    'EMERGENCY_BREAK_GLASS',
    'POWER_FAILURE',
  }.contains(code)) {
    throw ArgumentError('Unsupported ACS06 cause: $code');
  }
  return code;
}

String _outcome(String value) {
  final code = _text(value, 'outcomeCode').toUpperCase();
  if (!const {'LOCKED', 'UNLOCKED', 'SECURED', 'RELEASED'}.contains(code)) {
    throw ArgumentError('Unsupported ACS06 outcome: $code');
  }
  return code;
}

Map<String, Object?> _map(Object? value, String field) {
  if (value is! Map) throw FormatException('$field must be object.');
  return Map<String, Object?>.from(value);
}

List<String> _strings(Object? value, String field) {
  if (value is! List || value.any((e) => e is! String)) {
    throw FormatException('$field must be string array.');
  }
  return value.cast<String>();
}

String _mapText(Map<String, Object?> map, String key) => _string(map[key], key);
String _string(Object? value, String field) {
  if (value is! String) throw FormatException('$field must be text.');
  return _text(value, field);
}

String? _nullableText(Object? value, String field) {
  if (value == null) return null;
  return _string(value, field);
}

String _text(String value, String field) {
  final normalized = value.trim();
  if (normalized.isEmpty)
    throw ArgumentError.value(value, field, 'Must not be empty.');
  return normalized;
}

String _sha(String value, String field) {
  final normalized = _text(value, field).toLowerCase();
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(normalized)) {
    throw ArgumentError.value(value, field, 'Expected lowercase SHA-256.');
  }
  return normalized;
}

void _exact(Map<String, Object?> map, Set<String> expected, String field) {
  final actual = map.keys.toSet();
  if (actual.length != expected.length ||
      actual.difference(expected).isNotEmpty ||
      expected.difference(actual).isNotEmpty) {
    throw FormatException('$field has missing or unknown fields.');
  }
}
