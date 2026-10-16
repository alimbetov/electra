final class Elv4QualificationEvidenceRow {
  Elv4QualificationEvidenceRow({
    required this.caseId,
    required this.processCode,
    required this.context,
    required this.dimension,
    required this.completion,
    required this.assessment,
    required this.execution,
    required this.evaluationId,
  });

  final String caseId;
  final String processCode;
  final String context;
  final String dimension;
  final String completion;
  final String assessment;
  final String execution;
  final String evaluationId;

  String get key => '$caseId|$processCode|$context|$dimension';
}

final class Elv4QualificationExpectedRow {
  const Elv4QualificationExpectedRow({
    required this.caseId,
    required this.processCode,
    required this.context,
    required this.dimension,
    required this.completion,
    required this.assessment,
    required this.execution,
  });

  final String caseId;
  final String processCode;
  final String context;
  final String dimension;
  final String completion;
  final String assessment;
  final String execution;

  String get key => '$caseId|$processCode|$context|$dimension';
}

final class Elv4QualificationMatrixContract {
  Elv4QualificationMatrixContract._({
    required this.requiredCaseIds,
    required this.expectedRows,
  });

  final List<String> requiredCaseIds;
  final List<Elv4QualificationExpectedRow> expectedRows;

  factory Elv4QualificationMatrixContract.fromManifest(
    Map<String, Object?> manifest,
  ) {
    if (manifest['schema'] != 'electra.elv4-qualification.v1') {
      throw const FormatException('Unsupported ELV4 qualification schema.');
    }
    final requiredCaseIds = _stringList(
      manifest['requiredPositiveCaseIds'],
      'requiredPositiveCaseIds',
    );
    if (requiredCaseIds.isEmpty || requiredCaseIds.toSet().length != requiredCaseIds.length) {
      throw const FormatException(
        'requiredPositiveCaseIds must be non-empty and unique.',
      );
    }
    final positiveCases = _objectList(manifest['positiveCases'], 'positiveCases');
    final casesById = <String, Map<String, Object?>>{};
    for (final caseValue in positiveCases) {
      final caseId = _text(caseValue['id'], 'positiveCases.id');
      if (casesById.putIfAbsent(caseId, () => caseValue) != caseValue) {
        throw FormatException('Duplicate qualification case: $caseId.');
      }
    }
    if (casesById.keys.toSet().difference(requiredCaseIds.toSet()).isNotEmpty ||
        requiredCaseIds.toSet().difference(casesById.keys.toSet()).isNotEmpty) {
      throw const FormatException(
        'requiredPositiveCaseIds must exactly match positiveCases ids.',
      );
    }

    final rows = <Elv4QualificationExpectedRow>[];
    final seen = <String>{};
    for (final caseId in requiredCaseIds) {
      final caseValue = casesById[caseId]!;
      if (caseValue['kind'] != 'POSITIVE') {
        throw FormatException('$caseId must be a POSITIVE qualification case.');
      }
      final requiredResults = _objectList(
        caseValue['requiredResults'],
        '$caseId.requiredResults',
      );
      final contexts = _object(
        caseValue['requiredContexts'],
        '$caseId.requiredContexts',
      );
      final resultProcesses = <String>{};
      for (final result in requiredResults) {
        final processCode = _text(
          result['processCode'],
          '$caseId.requiredResults.processCode',
        );
        if (!resultProcesses.add(processCode)) {
          throw FormatException('$caseId has duplicate result $processCode.');
        }
        final dimensions = _stringList(
          result['requiredDimensions'],
          '$caseId.$processCode.requiredDimensions',
        );
        if (dimensions.isEmpty || dimensions.toSet().length != dimensions.length) {
          throw FormatException(
            '$caseId/$processCode dimensions must be non-empty and unique.',
          );
        }
        final processContexts = _stringList(
          contexts[processCode],
          '$caseId.requiredContexts.$processCode',
        );
        if (processContexts.isEmpty ||
            processContexts.toSet().length != processContexts.length) {
          throw FormatException(
            '$caseId/$processCode contexts must be non-empty and unique.',
          );
        }
        final completion = _text(
          result['completion'],
          '$caseId.$processCode.completion',
        );
        final assessment = _text(
          result['assessment'],
          '$caseId.$processCode.assessment',
        );
        final execution = _text(
          result['execution'],
          '$caseId.$processCode.execution',
        );
        for (final context in processContexts) {
          for (final dimension in dimensions) {
            final row = Elv4QualificationExpectedRow(
              caseId: caseId,
              processCode: processCode,
              context: context,
              dimension: dimension,
              completion: completion,
              assessment: assessment,
              execution: execution,
            );
            if (!seen.add(row.key)) {
              throw FormatException('Duplicate qualification obligation ${row.key}.');
            }
            rows.add(row);
          }
        }
      }
      final contextProcesses = contexts.keys.toSet();
      if (contextProcesses.difference(resultProcesses).isNotEmpty ||
          resultProcesses.difference(contextProcesses).isNotEmpty) {
        throw FormatException(
          '$caseId requiredResults and requiredContexts process sets differ.',
        );
      }
    }
    rows.sort((a, b) => a.key.compareTo(b.key));
    return Elv4QualificationMatrixContract._(
      requiredCaseIds: List.unmodifiable(requiredCaseIds),
      expectedRows: List.unmodifiable(rows),
    );
  }

  void validateEvidence(Iterable<Elv4QualificationEvidenceRow> evidence) {
    final actual = <String, Elv4QualificationEvidenceRow>{};
    for (final row in evidence) {
      if (row.evaluationId.trim().isEmpty) {
        throw StateError('Qualification evidence ${row.key} has no evaluationId.');
      }
      if (actual.containsKey(row.key)) {
        throw StateError('Duplicate qualification evidence ${row.key}.');
      }
      actual[row.key] = row;
    }
    final expected = {for (final row in expectedRows) row.key: row};
    final missing = expected.keys.toSet().difference(actual.keys.toSet()).toList()
      ..sort();
    final extra = actual.keys.toSet().difference(expected.keys.toSet()).toList()
      ..sort();
    if (missing.isNotEmpty || extra.isNotEmpty) {
      throw StateError(
        'ELV4 qualification matrix mismatch: missing=$missing extra=$extra',
      );
    }
    for (final entry in expected.entries) {
      final requirement = entry.value;
      final row = actual[entry.key]!;
      if (row.completion != requirement.completion ||
          row.assessment != requirement.assessment ||
          row.execution != requirement.execution) {
        throw StateError(
          'ELV4 qualification status mismatch for ${entry.key}: '
          'expected ${requirement.completion}/${requirement.assessment}/'
          '${requirement.execution}, got '
          '${row.completion}/${row.assessment}/${row.execution}.',
        );
      }
    }
  }
}

Map<String, Object?> _object(Object? value, String field) {
  if (value is! Map) throw FormatException('$field must be an object.');
  return value.cast<String, Object?>();
}

List<Map<String, Object?>> _objectList(Object? value, String field) {
  if (value is! List) throw FormatException('$field must be an array.');
  return value.map((entry) => _object(entry, field)).toList(growable: false);
}

List<String> _stringList(Object? value, String field) {
  if (value is! List || value.any((entry) => entry is! String)) {
    throw FormatException('$field must be a string array.');
  }
  return value.cast<String>().map((entry) => _text(entry, field)).toList();
}

String _text(Object? value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$field must be a non-empty string.');
  }
  return value.trim();
}
