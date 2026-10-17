import 'package:engineering_core/engineering_core_elv5.dart';

enum Fa04SourceDimension { watt, current }

final class Fa04RequirementContributorRef {
  Fa04RequirementContributorRef({
    required String contributorId,
    required String disciplineCode,
    required String policyCode,
    required String editionId,
    required String contentHash,
  })  : contributorId = _text(contributorId, 'contributorId'),
        disciplineCode = _text(disciplineCode, 'disciplineCode'),
        policyCode = _text(policyCode, 'policyCode'),
        editionId = _text(editionId, 'editionId'),
        contentHash = _sha(contentHash, 'contentHash');

  final String contributorId;
  final String disciplineCode;
  final String policyCode;
  final String editionId;
  final String contentHash;

  Map<String, Object?> toCanonicalValue() => <String, Object?>{
        'contributorId': contributorId,
        'disciplineCode': disciplineCode,
        'policyCode': policyCode,
        'editionId': editionId,
        'contentHash': contentHash,
      };

  factory Fa04RequirementContributorRef.fromMap(Map<String, Object?> map) {
    _exact(map, const <String>{
      'contributorId',
      'disciplineCode',
      'policyCode',
      'editionId',
      'contentHash',
    }, 'FA04 contributor');
    return Fa04RequirementContributorRef(
      contributorId: _mapText(map, 'contributorId'),
      disciplineCode: _mapText(map, 'disciplineCode'),
      policyCode: _mapText(map, 'policyCode'),
      editionId: _mapText(map, 'editionId'),
      contentHash: _mapText(map, 'contentHash'),
    );
  }
}

final class Fa04SourceCaseContract {
  Fa04SourceCaseContract({
    required String caseId,
    required String scenarioId,
    required String segmentId,
    required this.dimension,
    required String pwr01SubjectKind,
    required String pwr01SubjectId,
    required String pwr02SubjectKind,
    required String pwr02SubjectId,
    required String expectedPwr02InputFingerprint,
  })  : caseId = _text(caseId, 'caseId'),
        scenarioId = _text(scenarioId, 'scenarioId'),
        segmentId = _text(segmentId, 'segmentId'),
        pwr01SubjectKind = _text(pwr01SubjectKind, 'pwr01SubjectKind'),
        pwr01SubjectId = _text(pwr01SubjectId, 'pwr01SubjectId'),
        pwr02SubjectKind = _text(pwr02SubjectKind, 'pwr02SubjectKind'),
        pwr02SubjectId = _text(pwr02SubjectId, 'pwr02SubjectId'),
        expectedPwr02InputFingerprint =
            _sha(expectedPwr02InputFingerprint, 'expectedPwr02InputFingerprint');

  final String caseId;
  final String scenarioId;
  final String segmentId;
  final Fa04SourceDimension dimension;
  final String pwr01SubjectKind;
  final String pwr01SubjectId;
  final String pwr02SubjectKind;
  final String pwr02SubjectId;
  final String expectedPwr02InputFingerprint;

  Map<String, Object?> toCanonicalValue() => <String, Object?>{
        'caseId': caseId,
        'scenarioId': scenarioId,
        'segmentId': segmentId,
        'dimension': dimension == Fa04SourceDimension.watt ? 'WATT' : 'CURRENT',
        'pwr01SubjectKind': pwr01SubjectKind,
        'pwr01SubjectId': pwr01SubjectId,
        'pwr02SubjectKind': pwr02SubjectKind,
        'pwr02SubjectId': pwr02SubjectId,
        'expectedPwr02InputFingerprint': expectedPwr02InputFingerprint,
      };

  factory Fa04SourceCaseContract.fromMap(Map<String, Object?> map) {
    _exact(map, const <String>{
      'caseId',
      'scenarioId',
      'segmentId',
      'dimension',
      'pwr01SubjectKind',
      'pwr01SubjectId',
      'pwr02SubjectKind',
      'pwr02SubjectId',
      'expectedPwr02InputFingerprint',
    }, 'FA04 source case');
    final dimension = switch (_mapText(map, 'dimension')) {
      'WATT' => Fa04SourceDimension.watt,
      'CURRENT' => Fa04SourceDimension.current,
      final value => throw FormatException('Unsupported FA04 dimension: $value'),
    };
    return Fa04SourceCaseContract(
      caseId: _mapText(map, 'caseId'),
      scenarioId: _mapText(map, 'scenarioId'),
      segmentId: _mapText(map, 'segmentId'),
      dimension: dimension,
      pwr01SubjectKind: _mapText(map, 'pwr01SubjectKind'),
      pwr01SubjectId: _mapText(map, 'pwr01SubjectId'),
      pwr02SubjectKind: _mapText(map, 'pwr02SubjectKind'),
      pwr02SubjectId: _mapText(map, 'pwr02SubjectId'),
      expectedPwr02InputFingerprint:
          _mapText(map, 'expectedPwr02InputFingerprint'),
    );
  }
}

final class Fa04SourceRequirementContract {
  Fa04SourceRequirementContract({
    required String sourceId,
    required String sourceDefinitionContentHash,
    required Iterable<Fa04RequirementContributorRef> contributors,
    required Iterable<Fa04SourceCaseContract> cases,
  })  : sourceId = _text(sourceId, 'sourceId'),
        sourceDefinitionContentHash =
            _sha(sourceDefinitionContentHash, 'sourceDefinitionContentHash'),
        contributors = List.unmodifiable(_contributors(contributors)),
        cases = List.unmodifiable(_cases(cases)) {
    if (this.contributors.isEmpty) {
      throw ArgumentError('FA04 requires participating requirement contributors.');
    }
    if (!this.contributors.any((value) => value.disciplineCode == 'FIRE')) {
      throw ArgumentError('FA04 requirement set must contain a FIRE contributor.');
    }
    if (this.cases.isEmpty) {
      throw ArgumentError('FA04 requires at least one source operating case.');
    }
  }

  static const schema = 'electra.elv5-fa04-source-requirement-contract.v1';
  static const _encoder = Elv5CanonicalJsonV1();

  final String sourceId;
  final String sourceDefinitionContentHash;
  final List<Fa04RequirementContributorRef> contributors;
  final List<Fa04SourceCaseContract> cases;

  String get requirementSetFingerprint => _encoder.sha256(<String, Object?>{
        'schema': 'electra.elv5-source-requirement-set-fingerprint.v1',
        'sourceId': sourceId,
        'sourceDefinitionContentHash': sourceDefinitionContentHash,
        'contributors': [for (final value in contributors) value.toCanonicalValue()],
        'cases': [for (final value in cases) value.toCanonicalValue()],
      });

  Map<String, Object?> toCanonicalValue() => <String, Object?>{
        'schema': schema,
        'sourceId': sourceId,
        'sourceDefinitionContentHash': sourceDefinitionContentHash,
        'contributors': [for (final value in contributors) value.toCanonicalValue()],
        'cases': [for (final value in cases) value.toCanonicalValue()],
      };

  factory Fa04SourceRequirementContract.fromMap(Map<String, Object?> map) {
    _exact(map, const <String>{
      'schema',
      'sourceId',
      'sourceDefinitionContentHash',
      'contributors',
      'cases',
    }, 'FA04 source requirement contract');
    if (map['schema'] != schema) {
      throw const FormatException('Unsupported FA04 source contract schema.');
    }
    final contributors = map['contributors'];
    final cases = map['cases'];
    if (contributors is! List || cases is! List) {
      throw const FormatException('FA04 contributors/cases must be arrays.');
    }
    return Fa04SourceRequirementContract(
      sourceId: _mapText(map, 'sourceId'),
      sourceDefinitionContentHash: _mapText(map, 'sourceDefinitionContentHash'),
      contributors: <Fa04RequirementContributorRef>[
        for (final raw in contributors)
          Fa04RequirementContributorRef.fromMap(_object(raw, 'FA04 contributor')),
      ],
      cases: <Fa04SourceCaseContract>[
        for (final raw in cases)
          Fa04SourceCaseContract.fromMap(_object(raw, 'FA04 source case')),
      ],
    );
  }
}

final class Fa04SourceRequirementContractSnapshot {
  const Fa04SourceRequirementContractSnapshot({
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
  final Fa04SourceRequirementContract contract;
}

abstract interface class Fa04SourceRequirementContractSource {
  Future<Fa04SourceRequirementContractSnapshot?> loadActiveForSource({
    required String projectId,
    required String designRevisionId,
    required String sourceId,
  });
}

List<Fa04RequirementContributorRef> _contributors(
  Iterable<Fa04RequirementContributorRef> values,
) {
  final result = values.toList()
    ..sort((a, b) => a.contributorId.compareTo(b.contributorId));
  final ids = <String>{};
  for (final value in result) {
    if (!ids.add(value.contributorId)) {
      throw ArgumentError('FA04 duplicate contributorId: ${value.contributorId}');
    }
  }
  return result;
}

List<Fa04SourceCaseContract> _cases(Iterable<Fa04SourceCaseContract> values) {
  final result = values.toList()..sort((a, b) => a.caseId.compareTo(b.caseId));
  final ids = <String>{};
  for (final value in result) {
    if (!ids.add(value.caseId)) {
      throw ArgumentError('FA04 duplicate caseId: ${value.caseId}');
    }
  }
  return result;
}

Map<String, Object?> _object(Object? value, String field) {
  if (value is! Map) throw FormatException('$field must be an object.');
  return Map<String, Object?>.from(value);
}

String _mapText(Map<String, Object?> map, String field) {
  final value = map[field];
  if (value is! String) throw FormatException('$field must be text.');
  return _text(value, field);
}

String _text(String value, String field) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, field, 'Must not be empty.');
  }
  return normalized;
}

String _sha(String value, String field) {
  final normalized = _text(value, field);
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(normalized)) {
    throw ArgumentError.value(value, field, 'Must be lowercase SHA-256.');
  }
  return normalized;
}

void _exact(Map<String, Object?> value, Set<String> expected, String field) {
  final actual = value.keys.toSet();
  if (actual.length != expected.length ||
      actual.difference(expected).isNotEmpty ||
      expected.difference(actual).isNotEmpty) {
    throw FormatException('$field has missing or unknown fields.');
  }
}
