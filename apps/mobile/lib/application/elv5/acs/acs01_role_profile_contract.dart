import 'package:engineering_core/engineering_core_elv5.dart';

final class Acs01RoleRequirementContract {
  Acs01RoleRequirementContract.roleCount({
    required String nodeId,
    required String kindCode,
    required String roleCode,
    required this.count,
  }) : nodeId = _text(nodeId, 'nodeId'),
       kindCode = _countKind(kindCode),
       roleCode = _role(roleCode),
       children = const <Acs01RoleRequirementContract>[] {
    if (count == null || count! < 0) {
      throw ArgumentError('ACS01 requirement count must be nonnegative.');
    }
  }

  Acs01RoleRequirementContract.group({
    required String nodeId,
    required String kindCode,
    required Iterable<Acs01RoleRequirementContract> children,
  }) : nodeId = _text(nodeId, 'nodeId'),
       kindCode = _groupKind(kindCode),
       roleCode = null,
       count = null,
       children = List.unmodifiable(_children(children));

  final String nodeId;
  final String kindCode;
  final String? roleCode;
  final int? count;
  final List<Acs01RoleRequirementContract> children;

  Map<String, Object?> toCanonicalValue() => <String, Object?>{
    'nodeId': nodeId,
    'kindCode': kindCode,
    'roleCode': roleCode,
    'count': count,
    'children': <Object?>[
      for (final child in children) child.toCanonicalValue(),
    ],
  };

  factory Acs01RoleRequirementContract.fromMap(Map<String, Object?> map) {
    _exact(map, const {
      'nodeId',
      'kindCode',
      'roleCode',
      'count',
      'children',
    }, 'ACS01 requirement');
    final kind = _mapText(map, 'kindCode').toUpperCase();
    final children = map['children'];
    if (children is! List)
      throw const FormatException('ACS01 children must be array.');
    if (kind == 'AT_LEAST' || kind == 'EXACTLY') {
      final count = map['count'];
      if (count is! int)
        throw const FormatException('ACS01 count must be integer.');
      return Acs01RoleRequirementContract.roleCount(
        nodeId: _mapText(map, 'nodeId'),
        kindCode: kind,
        roleCode: _nullableText(map['roleCode'], 'roleCode')!,
        count: count,
      );
    }
    return Acs01RoleRequirementContract.group(
      nodeId: _mapText(map, 'nodeId'),
      kindCode: kind,
      children: <Acs01RoleRequirementContract>[
        for (final raw in children)
          Acs01RoleRequirementContract.fromMap(_map(raw, 'child')),
      ],
    );
  }
}

final class Acs01ComponentCapabilityContract {
  Acs01ComponentCapabilityContract({
    required String componentId,
    required Iterable<String> allowedRoleCodes,
    required this.allowRoleSharing,
    required String evidenceRef,
    required String evidenceContentHash,
  }) : componentId = _text(componentId, 'componentId'),
       allowedRoleCodes = Set.unmodifiable(allowedRoleCodes.map(_role)),
       evidenceRef = _text(evidenceRef, 'evidenceRef'),
       evidenceContentHash = _sha(evidenceContentHash, 'evidenceContentHash') {
    if (this.allowedRoleCodes.isEmpty) {
      throw ArgumentError('ACS01 component capability must allow a role.');
    }
  }

  final String componentId;
  final Set<String> allowedRoleCodes;
  final bool allowRoleSharing;
  final String evidenceRef;
  final String evidenceContentHash;

  Map<String, Object?> toCanonicalValue() => <String, Object?>{
    'componentId': componentId,
    'allowedRoleCodes': allowedRoleCodes.toList()..sort(),
    'allowRoleSharing': allowRoleSharing,
    'evidenceRef': evidenceRef,
    'evidenceContentHash': evidenceContentHash,
  };

  factory Acs01ComponentCapabilityContract.fromMap(Map<String, Object?> map) {
    _exact(map, const {
      'componentId',
      'allowedRoleCodes',
      'allowRoleSharing',
      'evidenceRef',
      'evidenceContentHash',
    }, 'ACS01 capability');
    if (map['allowRoleSharing'] is! bool) {
      throw const FormatException('allowRoleSharing must be boolean.');
    }
    return Acs01ComponentCapabilityContract(
      componentId: _mapText(map, 'componentId'),
      allowedRoleCodes: _strings(map['allowedRoleCodes'], 'allowedRoleCodes'),
      allowRoleSharing: map['allowRoleSharing']! as bool,
      evidenceRef: _mapText(map, 'evidenceRef'),
      evidenceContentHash: _mapText(map, 'evidenceContentHash'),
    );
  }
}

final class Acs01RoleProfileContract {
  Acs01RoleProfileContract({
    required String doorId,
    required String profileId,
    required String expectedDoorAggregateFingerprint,
    required this.rootRequirement,
    required Iterable<Acs01ComponentCapabilityContract> capabilities,
    required this.assignmentClosureComplete,
  }) : doorId = _text(doorId, 'doorId'),
       profileId = _text(profileId, 'profileId'),
       expectedDoorAggregateFingerprint = _sha(
         expectedDoorAggregateFingerprint,
         'expectedDoorAggregateFingerprint',
       ),
       capabilities = List.unmodifiable(_capabilities(capabilities));

  static const schema = 'electra.elv5-acs01-role-profile-contract.v1';

  final String doorId;
  final String profileId;
  final String expectedDoorAggregateFingerprint;
  final Acs01RoleRequirementContract rootRequirement;
  final List<Acs01ComponentCapabilityContract> capabilities;
  final bool assignmentClosureComplete;

  Map<String, Object?> toCanonicalValue() => <String, Object?>{
    'schema': schema,
    'doorId': doorId,
    'profileId': profileId,
    'expectedDoorAggregateFingerprint': expectedDoorAggregateFingerprint,
    'rootRequirement': rootRequirement.toCanonicalValue(),
    'capabilities': <Object?>[
      for (final capability in capabilities) capability.toCanonicalValue(),
    ],
    'assignmentClosureComplete': assignmentClosureComplete,
  };

  factory Acs01RoleProfileContract.fromMap(Map<String, Object?> map) {
    _exact(map, const {
      'schema',
      'doorId',
      'profileId',
      'expectedDoorAggregateFingerprint',
      'rootRequirement',
      'capabilities',
      'assignmentClosureComplete',
    }, 'ACS01 contract');
    if (map['schema'] != schema || map['assignmentClosureComplete'] is! bool) {
      throw const FormatException(
        'Unsupported ACS01 contract schema or field type.',
      );
    }
    final caps = map['capabilities'];
    if (caps is! List)
      throw const FormatException('ACS01 capabilities must be array.');
    return Acs01RoleProfileContract(
      doorId: _mapText(map, 'doorId'),
      profileId: _mapText(map, 'profileId'),
      expectedDoorAggregateFingerprint: _mapText(
        map,
        'expectedDoorAggregateFingerprint',
      ),
      rootRequirement: Acs01RoleRequirementContract.fromMap(
        _map(map['rootRequirement'], 'rootRequirement'),
      ),
      capabilities: <Acs01ComponentCapabilityContract>[
        for (final raw in caps)
          Acs01ComponentCapabilityContract.fromMap(_map(raw, 'capability')),
      ],
      assignmentClosureComplete: map['assignmentClosureComplete']! as bool,
    );
  }
}

final class Acs01RoleProfileContractSnapshot {
  const Acs01RoleProfileContractSnapshot({
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
  final Acs01RoleProfileContract contract;
}

abstract interface class Acs01RoleProfileContractSource {
  Future<Acs01RoleProfileContractSnapshot?> loadActiveForDoor({
    required String projectId,
    required String designRevisionId,
    required String doorId,
  });
}

List<Acs01ComponentCapabilityContract> _capabilities(
  Iterable<Acs01ComponentCapabilityContract> values,
) {
  final out = values.toList()
    ..sort((a, b) => a.componentId.compareTo(b.componentId));
  final ids = <String>{};
  for (final value in out) {
    if (!ids.add(value.componentId)) {
      throw ArgumentError('ACS01 duplicate capability: ${value.componentId}');
    }
  }
  return out;
}

List<Acs01RoleRequirementContract> _children(
  Iterable<Acs01RoleRequirementContract> values,
) {
  final out = values.toList()..sort((a, b) => a.nodeId.compareTo(b.nodeId));
  if (out.isEmpty) throw ArgumentError('ACS01 group must have children.');
  return out;
}

String _role(String value) {
  final code = _text(value, 'roleCode').toUpperCase();
  const supported = {
    'READER_ENTRY',
    'READER_EXIT',
    'REQUEST_TO_EXIT',
    'EXIT_BUTTON',
    'LOCK',
    'DOOR_CONTACT',
    'EMERGENCY_RELEASE',
    'FIRE_RELEASE_INPUT',
    'OTHER',
  };
  if (!supported.contains(code))
    throw ArgumentError('Unsupported ACS01 role: $code');
  return code;
}

String _countKind(String value) {
  final code = _text(value, 'kindCode').toUpperCase();
  if (!const {'AT_LEAST', 'EXACTLY'}.contains(code)) {
    throw ArgumentError('Unsupported ACS01 count kind: $code');
  }
  return code;
}

String _groupKind(String value) {
  final code = _text(value, 'kindCode').toUpperCase();
  if (!const {'ALL_OF', 'ANY_OF', 'EXACTLY_ONE_OF'}.contains(code)) {
    throw ArgumentError('Unsupported ACS01 group kind: $code');
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
