import 'package:engineering_core/engineering_core_elv5.dart';

final class Acs02PolicyIdentity {
  Acs02PolicyIdentity({
    required String policyCode,
    required String editionId,
    required String contentHash,
  }) : policyCode = _text(policyCode, 'policyCode'),
       editionId = _text(editionId, 'editionId'),
       contentHash = _sha(contentHash, 'contentHash');

  final String policyCode;
  final String editionId;
  final String contentHash;

  Map<String, Object?> toCanonicalValue() => <String, Object?>{
    'policyCode': policyCode,
    'editionId': editionId,
    'contentHash': contentHash,
  };

  factory Acs02PolicyIdentity.fromMap(Map<String, Object?> map) {
    _exact(map, const {'policyCode', 'editionId', 'contentHash'}, 'policy');
    return Acs02PolicyIdentity(
      policyCode: _mapText(map, 'policyCode'),
      editionId: _mapText(map, 'editionId'),
      contentHash: _mapText(map, 'contentHash'),
    );
  }
}

final class Acs02ResourceContractItem {
  Acs02ResourceContractItem({
    required String resourceId,
    required String resourceKindCode,
  }) : resourceId = _text(resourceId, 'resourceId'),
       resourceKindCode = _kind(resourceKindCode);

  final String resourceId;
  final String resourceKindCode;

  Map<String, Object?> toCanonicalValue() => <String, Object?>{
    'resourceId': resourceId,
    'resourceKindCode': resourceKindCode,
  };

  factory Acs02ResourceContractItem.fromMap(Map<String, Object?> map) {
    _exact(map, const {'resourceId', 'resourceKindCode'}, 'resource');
    return Acs02ResourceContractItem(
      resourceId: _mapText(map, 'resourceId'),
      resourceKindCode: _mapText(map, 'resourceKindCode'),
    );
  }
}

final class Acs02SpareRuleContract {
  Acs02SpareRuleContract({
    required String resourceKindCode,
    required this.absoluteMinimum,
    required this.ratio,
  }) : resourceKindCode = _kind(resourceKindCode) {
    if (absoluteMinimum < 0 || ratio < Elv5Rational.zero) {
      throw ArgumentError('ACS02 spare rule values must be nonnegative.');
    }
  }

  final String resourceKindCode;
  final int absoluteMinimum;
  final Elv5Rational ratio;

  Map<String, Object?> toCanonicalValue() => <String, Object?>{
    'resourceKindCode': resourceKindCode,
    'absoluteMinimum': absoluteMinimum,
    'ratio': ratio.toMap(),
  };

  factory Acs02SpareRuleContract.fromMap(Map<String, Object?> map) {
    _exact(map, const {
      'resourceKindCode',
      'absoluteMinimum',
      'ratio',
    }, 'spareRule');
    final minimum = map['absoluteMinimum'];
    if (minimum is! int) {
      throw const FormatException('absoluteMinimum must be integer.');
    }
    return Acs02SpareRuleContract(
      resourceKindCode: _mapText(map, 'resourceKindCode'),
      absoluteMinimum: minimum,
      ratio: Elv5Rational.fromMap(_map(map['ratio'], 'ratio')),
    );
  }
}

final class Acs02ResourceContract {
  Acs02ResourceContract({
    required String controllerId,
    required String expectedControllerAggregateFingerprint,
    required this.reservePolicy,
    required Iterable<Acs02ResourceContractItem> resources,
    Iterable<String> unavailableResourceIds = const [],
    required Iterable<Acs02SpareRuleContract> spareRules,
  }) : controllerId = _text(controllerId, 'controllerId'),
       expectedControllerAggregateFingerprint = _sha(
         expectedControllerAggregateFingerprint,
         'expectedControllerAggregateFingerprint',
       ),
       resources = List.unmodifiable(_resources(resources)),
       unavailableResourceIds = Set.unmodifiable(
         unavailableResourceIds.map((e) => _text(e, 'unavailableResourceId')),
       ),
       spareRules = List.unmodifiable(_spareRules(spareRules)) {
    final resourceIds = this.resources.map((e) => e.resourceId).toSet();
    if (!resourceIds.containsAll(this.unavailableResourceIds)) {
      throw ArgumentError(
        'ACS02 unavailable resource must exist in inventory.',
      );
    }
  }

  static const schema = 'electra.elv5-acs02-resource-contract.v1';

  final String controllerId;
  final String expectedControllerAggregateFingerprint;
  final Acs02PolicyIdentity reservePolicy;
  final List<Acs02ResourceContractItem> resources;
  final Set<String> unavailableResourceIds;
  final List<Acs02SpareRuleContract> spareRules;

  Map<String, Object?> toCanonicalValue() => <String, Object?>{
    'schema': schema,
    'controllerId': controllerId,
    'expectedControllerAggregateFingerprint':
        expectedControllerAggregateFingerprint,
    'reservePolicy': reservePolicy.toCanonicalValue(),
    'resources': <Object?>[
      for (final value in resources) value.toCanonicalValue(),
    ],
    'unavailableResourceIds': unavailableResourceIds.toList()..sort(),
    'spareRules': <Object?>[
      for (final value in spareRules) value.toCanonicalValue(),
    ],
  };

  factory Acs02ResourceContract.fromMap(Map<String, Object?> map) {
    _exact(map, const {
      'schema',
      'controllerId',
      'expectedControllerAggregateFingerprint',
      'reservePolicy',
      'resources',
      'unavailableResourceIds',
      'spareRules',
    }, 'ACS02 contract');
    if (map['schema'] != schema) {
      throw const FormatException('Unsupported ACS02 contract schema.');
    }
    final resources = map['resources'];
    final unavailable = map['unavailableResourceIds'];
    final rules = map['spareRules'];
    if (resources is! List || unavailable is! List || rules is! List) {
      throw const FormatException('ACS02 collection fields must be arrays.');
    }
    return Acs02ResourceContract(
      controllerId: _mapText(map, 'controllerId'),
      expectedControllerAggregateFingerprint: _mapText(
        map,
        'expectedControllerAggregateFingerprint',
      ),
      reservePolicy: Acs02PolicyIdentity.fromMap(
        _map(map['reservePolicy'], 'reservePolicy'),
      ),
      resources: <Acs02ResourceContractItem>[
        for (final raw in resources)
          Acs02ResourceContractItem.fromMap(_map(raw, 'resource')),
      ],
      unavailableResourceIds: <String>[
        for (final raw in unavailable) _string(raw, 'unavailableResourceId'),
      ],
      spareRules: <Acs02SpareRuleContract>[
        for (final raw in rules)
          Acs02SpareRuleContract.fromMap(_map(raw, 'spareRule')),
      ],
    );
  }
}

final class Acs02ResourceContractSnapshot {
  const Acs02ResourceContractSnapshot({
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
  final Acs02ResourceContract contract;
}

abstract interface class Acs02ResourceContractSource {
  Future<Acs02ResourceContractSnapshot?> loadActiveForController({
    required String projectId,
    required String designRevisionId,
    required String controllerId,
  });
}

final class ReplaceAcs02ResourceContractCommand {
  ReplaceAcs02ResourceContractCommand({
    required this.projectId,
    required this.designRevisionId,
    required this.expectedDesignRevision,
    required this.bindingId,
    required this.expectedBindingRevision,
    required this.contract,
  }) {
    if (projectId.trim().isEmpty ||
        designRevisionId.trim().isEmpty ||
        bindingId.trim().isEmpty) {
      throw ArgumentError('ACS02 command identity is required.');
    }
    if (expectedDesignRevision < 1 ||
        (expectedBindingRevision != null && expectedBindingRevision! < 1)) {
      throw ArgumentError('ACS02 expected revisions must be positive.');
    }
  }

  final String projectId;
  final String designRevisionId;
  final int expectedDesignRevision;
  final String bindingId;
  final int? expectedBindingRevision;
  final Acs02ResourceContract contract;
}

abstract interface class Acs02ResourceContractWriter {
  Future<void> replace(ReplaceAcs02ResourceContractCommand command);
}

List<Acs02ResourceContractItem> _resources(
  Iterable<Acs02ResourceContractItem> values,
) {
  final out = values.toList()
    ..sort((a, b) => a.resourceId.compareTo(b.resourceId));
  final ids = <String>{};
  for (final value in out) {
    if (!ids.add(value.resourceId)) {
      throw ArgumentError('ACS02 duplicate resourceId: ${value.resourceId}');
    }
  }
  if (out.isEmpty)
    throw ArgumentError('ACS02 resource inventory must not be empty.');
  return out;
}

List<Acs02SpareRuleContract> _spareRules(
  Iterable<Acs02SpareRuleContract> values,
) {
  final out = values.toList()
    ..sort((a, b) => a.resourceKindCode.compareTo(b.resourceKindCode));
  final kinds = <String>{};
  for (final value in out) {
    if (!kinds.add(value.resourceKindCode)) {
      throw ArgumentError(
        'ACS02 duplicate spare rule: ${value.resourceKindCode}',
      );
    }
  }
  const required = {
    'READER_CHANNEL',
    'RELAY_OUTPUT',
    'SUPERVISED_INPUT',
    'OTHER',
  };
  if (kinds.length != required.length || !kinds.containsAll(required)) {
    throw ArgumentError(
      'ACS02 requires explicit spare rules for all resource kinds.',
    );
  }
  return out;
}

String _kind(String value) {
  final code = _text(value, 'resourceKindCode').toUpperCase();
  if (!const {
    'READER_CHANNEL',
    'RELAY_OUTPUT',
    'SUPERVISED_INPUT',
    'OTHER',
  }.contains(code)) {
    throw ArgumentError('Unsupported ACS02 resource kind: $code');
  }
  return code;
}

Map<String, Object?> _map(Object? value, String field) {
  if (value is! Map) throw FormatException('$field must be object.');
  return Map<String, Object?>.from(value);
}

String _mapText(Map<String, Object?> map, String key) => _string(map[key], key);

String _string(Object? value, String field) {
  if (value is! String) throw FormatException('$field must be text.');
  return _text(value, field);
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
