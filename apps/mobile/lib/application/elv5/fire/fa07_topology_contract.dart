final class Fa07TopologyProfileIdentity {
  Fa07TopologyProfileIdentity({
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
  factory Fa07TopologyProfileIdentity.fromMap(Map<String, Object?> map) {
    _exact(map, const <String>{
      'profileCode',
      'editionId',
      'contentHash',
    }, 'topologyProfile');
    return Fa07TopologyProfileIdentity(
      profileCode: _mapText(map, 'profileCode'),
      editionId: _mapText(map, 'editionId'),
      contentHash: _mapText(map, 'contentHash'),
    );
  }
}

final class Fa07EdgeContract {
  Fa07EdgeContract({
    required String edgeId,
    required String fromNodeId,
    required String toNodeId,
  }) : edgeId = _text(edgeId, 'edgeId'),
       fromNodeId = _text(fromNodeId, 'fromNodeId'),
       toNodeId = _text(toNodeId, 'toNodeId');
  final String edgeId;
  final String fromNodeId;
  final String toNodeId;
  Map<String, Object?> toCanonicalValue() => <String, Object?>{
    'edgeId': edgeId,
    'fromNodeId': fromNodeId,
    'toNodeId': toNodeId,
  };
  factory Fa07EdgeContract.fromMap(Map<String, Object?> map) {
    _exact(map, const <String>{'edgeId', 'fromNodeId', 'toNodeId'}, 'edge');
    return Fa07EdgeContract(
      edgeId: _mapText(map, 'edgeId'),
      fromNodeId: _mapText(map, 'fromNodeId'),
      toNodeId: _mapText(map, 'toNodeId'),
    );
  }
}

final class Fa07FaultScenarioContract {
  Fa07FaultScenarioContract({
    required String caseCode,
    required Iterable<String> removedEdgeIds,
    required Iterable<String> expectedReachableDeviceIds,
  }) : caseCode = _faultCase(caseCode),
       removedEdgeIds = Set.unmodifiable(
         removedEdgeIds.map((e) => _text(e, 'removedEdgeId')),
       ),
       expectedReachableDeviceIds = Set.unmodifiable(
         expectedReachableDeviceIds.map(
           (e) => _text(e, 'expectedReachableDeviceId'),
         ),
       );
  final String caseCode;
  final Set<String> removedEdgeIds;
  final Set<String> expectedReachableDeviceIds;
  Map<String, Object?> toCanonicalValue() => <String, Object?>{
    'caseCode': caseCode,
    'removedEdgeIds': removedEdgeIds.toList()..sort(),
    'expectedReachableDeviceIds': expectedReachableDeviceIds.toList()..sort(),
  };
  factory Fa07FaultScenarioContract.fromMap(Map<String, Object?> map) {
    _exact(map, const <String>{
      'caseCode',
      'removedEdgeIds',
      'expectedReachableDeviceIds',
    }, 'faultScenario');
    return Fa07FaultScenarioContract(
      caseCode: _mapText(map, 'caseCode'),
      removedEdgeIds: _strings(map['removedEdgeIds'], 'removedEdgeIds'),
      expectedReachableDeviceIds: _strings(
        map['expectedReachableDeviceIds'],
        'expectedReachableDeviceIds',
      ),
    );
  }
}

final class Fa07TopologyContract {
  Fa07TopologyContract({
    required String loopId,
    required this.topologyProfile,
    required String expectedFa01MembershipFingerprint,
    required String sourceNodeId,
    required String returnNodeId,
    required Map<String, String> deviceNodeIdByDeviceId,
    required Iterable<Fa07EdgeContract> edges,
    required Iterable<String> permittedBranchNodeIds,
    required this.maxBranchNodes,
    required Iterable<String> requiredFaultCases,
    required Iterable<Fa07FaultScenarioContract> faultScenarios,
  }) : loopId = _text(loopId, 'loopId'),
       expectedFa01MembershipFingerprint = _sha(
         expectedFa01MembershipFingerprint,
         'expectedFa01MembershipFingerprint',
       ),
       sourceNodeId = _text(sourceNodeId, 'sourceNodeId'),
       returnNodeId = _text(returnNodeId, 'returnNodeId'),
       deviceNodeIdByDeviceId = Map.unmodifiable(
         _deviceMap(deviceNodeIdByDeviceId),
       ),
       edges = List.unmodifiable(_edges(edges)),
       permittedBranchNodeIds = Set.unmodifiable(
         permittedBranchNodeIds.map((e) => _text(e, 'permittedBranchNodeId')),
       ),
       requiredFaultCases = Set.unmodifiable(
         requiredFaultCases.map(_faultCase),
       ),
       faultScenarios = List.unmodifiable(_faults(faultScenarios)) {
    if (maxBranchNodes < 0)
      throw ArgumentError('FA07 maxBranchNodes must be nonnegative.');
    if (this.sourceNodeId == this.returnNodeId)
      throw ArgumentError('FA07 source and return nodes must differ.');
    final edgeIds = this.edges.map((e) => e.edgeId).toSet();
    final graphNodes = <String>{
      for (final edge in this.edges) ...<String>{
        edge.fromNodeId,
        edge.toNodeId,
      },
    };
    final mandatoryNodes = <String>{
      this.sourceNodeId,
      this.returnNodeId,
      ...this.deviceNodeIdByDeviceId.values,
    };
    if (!graphNodes.containsAll(mandatoryNodes))
      throw ArgumentError('FA07 graph omits source/return/device node.');
    if (!graphNodes.containsAll(this.permittedBranchNodeIds))
      throw ArgumentError('FA07 permitted branch node is outside graph.');
    for (final fault in this.faultScenarios) {
      if (!edgeIds.containsAll(fault.removedEdgeIds))
        throw ArgumentError('FA07 fault references unknown edge.');
      if (!this.deviceNodeIdByDeviceId.keys.toSet().containsAll(
        fault.expectedReachableDeviceIds,
      ))
        throw ArgumentError(
          'FA07 fault expected set references unknown device.',
        );
    }
  }
  static const schema = 'electra.elv5-fa07-topology-contract.v1';
  final String loopId;
  final Fa07TopologyProfileIdentity topologyProfile;
  final String expectedFa01MembershipFingerprint;
  final String sourceNodeId;
  final String returnNodeId;
  final Map<String, String> deviceNodeIdByDeviceId;
  final List<Fa07EdgeContract> edges;
  final Set<String> permittedBranchNodeIds;
  final int maxBranchNodes;
  final Set<String> requiredFaultCases;
  final List<Fa07FaultScenarioContract> faultScenarios;
  Map<String, Object?> toCanonicalValue() => <String, Object?>{
    'schema': schema,
    'loopId': loopId,
    'topologyProfile': topologyProfile.toCanonicalValue(),
    'expectedFa01MembershipFingerprint': expectedFa01MembershipFingerprint,
    'sourceNodeId': sourceNodeId,
    'returnNodeId': returnNodeId,
    'deviceNodeIdByDeviceId': <String, Object?>{
      for (final k in (deviceNodeIdByDeviceId.keys.toList()..sort()))
        k: deviceNodeIdByDeviceId[k],
    },
    'edges': [for (final e in edges) e.toCanonicalValue()],
    'permittedBranchNodeIds': permittedBranchNodeIds.toList()..sort(),
    'maxBranchNodes': maxBranchNodes,
    'requiredFaultCases': requiredFaultCases.toList()..sort(),
    'faultScenarios': [for (final f in faultScenarios) f.toCanonicalValue()],
  };
  factory Fa07TopologyContract.fromMap(Map<String, Object?> map) {
    _exact(map, const <String>{
      'schema',
      'loopId',
      'topologyProfile',
      'expectedFa01MembershipFingerprint',
      'sourceNodeId',
      'returnNodeId',
      'deviceNodeIdByDeviceId',
      'edges',
      'permittedBranchNodeIds',
      'maxBranchNodes',
      'requiredFaultCases',
      'faultScenarios',
    }, 'FA07 contract');
    if (map['schema'] != schema)
      throw const FormatException('Unsupported FA07 contract schema.');
    final deviceRaw = _object(
      map['deviceNodeIdByDeviceId'],
      'deviceNodeIdByDeviceId',
    );
    final edgeRaw = map['edges'];
    final faultRaw = map['faultScenarios'];
    final max = map['maxBranchNodes'];
    if (edgeRaw is! List || faultRaw is! List || max is! int)
      throw const FormatException('FA07 contract field type mismatch.');
    return Fa07TopologyContract(
      loopId: _mapText(map, 'loopId'),
      topologyProfile: Fa07TopologyProfileIdentity.fromMap(
        _object(map['topologyProfile'], 'topologyProfile'),
      ),
      expectedFa01MembershipFingerprint: _mapText(
        map,
        'expectedFa01MembershipFingerprint',
      ),
      sourceNodeId: _mapText(map, 'sourceNodeId'),
      returnNodeId: _mapText(map, 'returnNodeId'),
      deviceNodeIdByDeviceId: <String, String>{
        for (final e in deviceRaw.entries)
          _text(e.key, 'deviceId'): _stringValue(e.value, 'nodeId'),
      },
      edges: [
        for (final e in edgeRaw) Fa07EdgeContract.fromMap(_object(e, 'edge')),
      ],
      permittedBranchNodeIds: _strings(
        map['permittedBranchNodeIds'],
        'permittedBranchNodeIds',
      ),
      maxBranchNodes: max,
      requiredFaultCases: _strings(
        map['requiredFaultCases'],
        'requiredFaultCases',
      ),
      faultScenarios: [
        for (final f in faultRaw)
          Fa07FaultScenarioContract.fromMap(_object(f, 'faultScenario')),
      ],
    );
  }
}

final class Fa07TopologyContractSnapshot {
  const Fa07TopologyContractSnapshot({
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
  final Fa07TopologyContract contract;
}

abstract interface class Fa07TopologyContractSource {
  Future<Fa07TopologyContractSnapshot?> loadActiveForLoop({
    required String projectId,
    required String designRevisionId,
    required String loopId,
  });
}

Map<String, String> _deviceMap(Map<String, String> input) {
  final out = <String, String>{};
  final nodes = <String>{};
  for (final e in input.entries) {
    final id = _text(e.key, 'deviceId');
    final node = _text(e.value, 'nodeId');
    if (!nodes.add(node))
      throw ArgumentError('FA07 duplicate device node: $node');
    out[id] = node;
  }
  if (out.isEmpty) throw ArgumentError('FA07 device map empty.');
  return out;
}

List<Fa07EdgeContract> _edges(Iterable<Fa07EdgeContract> values) {
  final out = values.toList()..sort((a, b) => a.edgeId.compareTo(b.edgeId));
  final ids = <String>{};
  for (final e in out) {
    if (!ids.add(e.edgeId))
      throw ArgumentError('FA07 duplicate edgeId: ${e.edgeId}');
  }
  if (out.isEmpty) throw ArgumentError('FA07 edge set empty.');
  return out;
}

List<Fa07FaultScenarioContract> _faults(
  Iterable<Fa07FaultScenarioContract> values,
) {
  final out = values.toList()..sort((a, b) => a.caseCode.compareTo(b.caseCode));
  final cases = <String>{};
  for (final f in out) {
    if (!cases.add(f.caseCode))
      throw ArgumentError('FA07 duplicate fault case: ${f.caseCode}');
  }
  return out;
}

String _faultCase(String value) {
  final code = _text(value, 'faultCase');
  if (!const <String>{
    'OPEN_FAULT',
    'SHORT_FAULT',
    'RETURN_LOSS',
  }.contains(code))
    throw ArgumentError('Unsupported FA07 fault case: $code');
  return code;
}

Map<String, Object?> _object(Object? v, String f) {
  if (v is! Map) throw FormatException('$f must be object.');
  return Map<String, Object?>.from(v);
}

List<String> _strings(Object? v, String f) {
  if (v is! List || v.any((e) => e is! String))
    throw FormatException('$f must be string array.');
  return v.cast<String>();
}

String _stringValue(Object? v, String f) {
  if (v is! String) throw FormatException('$f must be text.');
  return _text(v, f);
}

String _mapText(Map<String, Object?> m, String k) {
  final v = m[k];
  if (v is! String) throw FormatException('$k must be text.');
  return _text(v, k);
}

String _text(String v, String f) {
  final n = v.trim();
  if (n.isEmpty) throw ArgumentError.value(v, f, 'Must not be empty.');
  return n;
}

String _sha(String v, String f) {
  final n = _text(v, f);
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(n))
    throw ArgumentError.value(v, f, 'Must be lowercase SHA-256.');
  return n;
}

void _exact(Map<String, Object?> m, Set<String> e, String f) {
  final a = m.keys.toSet();
  if (a.length != e.length ||
      a.difference(e).isNotEmpty ||
      e.difference(a).isNotEmpty)
    throw FormatException('$f has missing or unknown fields.');
}
