import 'package:engineering_core/engineering_core_elv5.dart';

final class Fa08CablePolicyContract {
  Fa08CablePolicyContract({
    required String cableRunId,
    required String policyId,
    required Iterable<Fa08Requirement> requirements,
  }) : cableRunId = _text(cableRunId, 'cableRunId'),
       policy = Fa08Policy(
         policyId: _text(policyId, 'policyId'),
         requirements: List.unmodifiable(requirements),
       );

  static const schema = 'electra.elv5-fa08-cable-policy-contract.v1';

  final String cableRunId;
  final Fa08Policy policy;

  Map<String, Object?> toCanonicalValue() => <String, Object?>{
    'schema': schema,
    'cableRunId': cableRunId,
    'policyId': policy.policyId,
    'requirements': <Object?>[
      for (final item in [...policy.requirements]
        ..sort((a, b) => a.code.compareTo(b.code)))
        _requirementToMap(item),
    ],
  };

  factory Fa08CablePolicyContract.fromMap(Map<String, Object?> map) {
    _exact(map, const <String>{
      'schema',
      'cableRunId',
      'policyId',
      'requirements',
    }, 'FA08 policy contract');
    if (map['schema'] != schema) {
      throw const FormatException('Unsupported FA08 policy contract schema.');
    }
    final raw = map['requirements'];
    if (raw is! List)
      throw const FormatException('requirements must be array.');
    return Fa08CablePolicyContract(
      cableRunId: _mapText(map, 'cableRunId'),
      policyId: _mapText(map, 'policyId'),
      requirements: <Fa08Requirement>[
        for (final value in raw)
          _requirementFromMap(_map(value, 'requirement')),
      ],
    );
  }
}

final class Fa08CablePolicyContractSnapshot {
  const Fa08CablePolicyContractSnapshot({
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
  final Fa08CablePolicyContract contract;
}

abstract interface class Fa08CablePolicyContractSource {
  Future<Fa08CablePolicyContractSnapshot?> loadActiveForCableRun({
    required String projectId,
    required String designRevisionId,
    required String cableRunId,
  });
}

final class ReplaceFa08CablePolicyContractCommand {
  ReplaceFa08CablePolicyContractCommand({
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
      throw ArgumentError('FA08 policy command identity is required.');
    }
    if (expectedDesignRevision < 1) {
      throw ArgumentError('expectedDesignRevision must be >= 1.');
    }
    if (expectedBindingRevision != null && expectedBindingRevision! < 1) {
      throw ArgumentError(
        'expectedBindingRevision must be >= 1 when supplied.',
      );
    }
  }

  final String projectId;
  final String designRevisionId;
  final int expectedDesignRevision;
  final String bindingId;
  final int? expectedBindingRevision;
  final Fa08CablePolicyContract contract;
}

abstract interface class Fa08CablePolicyContractWriter {
  Future<void> replace(ReplaceFa08CablePolicyContractCommand command);
}

Map<String, Object?> _requirementToMap(Fa08Requirement item) =>
    <String, Object?>{
      'code': item.code,
      'kind': item.kind.name,
      'expectedToken': item.expectedToken,
      'propertyCode': item.propertyCode,
      'unitCode': item.unitCode,
      'threshold': item.threshold?.toMap(),
    };

Fa08Requirement _requirementFromMap(Map<String, Object?> map) {
  _exact(map, const <String>{
    'code',
    'kind',
    'expectedToken',
    'propertyCode',
    'unitCode',
    'threshold',
  }, 'FA08 requirement');
  final kindName = _mapText(map, 'kind');
  final kind = Fa08RequirementKind.values.firstWhere(
    (value) => value.name == kindName,
    orElse:
        () =>
            throw FormatException(
              'Unsupported FA08 requirement kind: $kindName',
            ),
  );
  final code = _mapText(map, 'code');
  switch (kind) {
    case Fa08RequirementKind.cableClassEquals:
      return Fa08Requirement.cableClass(
        code: code,
        expectedClass: _nullableText(map['expectedToken'], 'expectedToken')!,
      );
    case Fa08RequirementKind.environmentTagPresent:
      return Fa08Requirement.environmentTag(
        code: code,
        requiredTag: _nullableText(map['expectedToken'], 'expectedToken')!,
      );
    case Fa08RequirementKind.numericMinimum:
    case Fa08RequirementKind.numericMaximum:
      return Fa08Requirement.numeric(
        code: code,
        kind: kind,
        propertyCode: _nullableText(map['propertyCode'], 'propertyCode'),
        unitCode: _nullableText(map['unitCode'], 'unitCode'),
        threshold: Elv5Rational.fromMap(_map(map['threshold'], 'threshold')),
      );
  }
}

Map<String, Object?> _map(Object? value, String field) {
  if (value is! Map) throw FormatException('$field must be object.');
  return Map<String, Object?>.from(value);
}

String _mapText(Map<String, Object?> map, String field) {
  final value = map[field];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$field must be non-empty text.');
  }
  return value.trim();
}

String? _nullableText(Object? value, String field) {
  if (value == null) return null;
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$field must be non-empty text or null.');
  }
  return value.trim();
}

String _text(String value, String field) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, field, 'Must not be empty.');
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
