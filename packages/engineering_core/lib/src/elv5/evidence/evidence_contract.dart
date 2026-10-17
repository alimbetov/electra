enum Elv5EvidenceState {
  verified,
  declared,
  derived,
  assumed,
  unknown,
}

enum Elv5EvidenceSourceType {
  measurement,
  manufacturerDatasheet,
  catalog,
  normativeTable,
  projectFact,
  derivedCalculation,
  engineeringAssumption,
  other,
}

final class Elv5EvidenceApplicability {
  Elv5EvidenceApplicability({
    required String scope,
    Iterable<String> scenarioIds = const <String>[],
    Iterable<String> environmentCodes = const <String>[],
  })  : scope = _text(scope, 'scope'),
        scenarioIds = Set.unmodifiable(
          scenarioIds.map((value) => _text(value, 'scenarioId')),
        ),
        environmentCodes = Set.unmodifiable(
          environmentCodes.map((value) => _text(value, 'environmentCode')),
        );

  final String scope;
  final Set<String> scenarioIds;
  final Set<String> environmentCodes;

  Map<String, Object?> toCanonicalValue() => <String, Object?>{
        'scope': scope,
        'scenarioIds': scenarioIds.toList()..sort(),
        'environmentCodes': environmentCodes.toList()..sort(),
      };
}

final class Elv5AssumptionDescriptor {
  Elv5AssumptionDescriptor({
    required String reason,
    required String scope,
    required String authorOrSource,
    required Elv5EvidenceApplicability applicability,
  })  : reason = _text(reason, 'reason'),
        scope = _text(scope, 'scope'),
        authorOrSource = _text(authorOrSource, 'authorOrSource'),
        applicability = applicability;

  final String reason;
  final String scope;
  final String authorOrSource;
  final Elv5EvidenceApplicability applicability;

  Map<String, Object?> toCanonicalValue() => <String, Object?>{
        'reason': reason,
        'scope': scope,
        'authorOrSource': authorOrSource,
        'applicability': applicability.toCanonicalValue(),
      };
}

/// Shared evidence identity/state primitive for Foundation F1.
///
/// This deliberately does not own a process value. A process may attach this
/// descriptor to an exact quantity, interval, categorical fact, or reference.
/// Keeping identity/state separate avoids forcing every engineering domain into
/// one generic serialized value container.
final class Elv5EvidenceDescriptor {
  Elv5EvidenceDescriptor({
    required String evidenceId,
    required this.state,
    required this.sourceType,
    required String sourceId,
    required String sourceEdition,
    required String contentHash,
    required Elv5EvidenceApplicability applicability,
    String? capturedAtUtc,
    String? effectiveAtUtc,
    String? unitCode,
    String? confidenceBasis,
    Elv5AssumptionDescriptor? assumption,
  })  : evidenceId = _text(evidenceId, 'evidenceId'),
        sourceId = _text(sourceId, 'sourceId'),
        sourceEdition = _text(sourceEdition, 'sourceEdition'),
        contentHash = _sha(contentHash, 'contentHash'),
        applicability = applicability,
        capturedAtUtc = _nullableText(capturedAtUtc, 'capturedAtUtc'),
        effectiveAtUtc = _nullableText(effectiveAtUtc, 'effectiveAtUtc'),
        unitCode = _nullableText(unitCode, 'unitCode'),
        confidenceBasis = _nullableText(confidenceBasis, 'confidenceBasis'),
        assumption = assumption {
    if (state == Elv5EvidenceState.assumed && assumption == null) {
      throw ArgumentError('ASSUMED evidence requires an assumption descriptor.');
    }
    if (state != Elv5EvidenceState.assumed && assumption != null) {
      throw ArgumentError('Only ASSUMED evidence may carry assumption metadata.');
    }
    if (state == Elv5EvidenceState.unknown &&
        sourceType == Elv5EvidenceSourceType.engineeringAssumption) {
      throw ArgumentError('UNKNOWN evidence cannot masquerade as an assumption.');
    }
  }

  final String evidenceId;
  final Elv5EvidenceState state;
  final Elv5EvidenceSourceType sourceType;
  final String sourceId;
  final String sourceEdition;
  final String contentHash;
  final Elv5EvidenceApplicability applicability;
  final String? capturedAtUtc;
  final String? effectiveAtUtc;
  final String? unitCode;
  final String? confidenceBasis;
  final Elv5AssumptionDescriptor? assumption;

  bool get maySatisfyVerifiedOnly => state == Elv5EvidenceState.verified;

  Map<String, Object?> toCanonicalValue() => <String, Object?>{
        'evidenceId': evidenceId,
        'state': state.name.toUpperCase(),
        'sourceType': sourceType.name,
        'sourceId': sourceId,
        'sourceEdition': sourceEdition,
        'contentHash': contentHash,
        'capturedAtUtc': capturedAtUtc,
        'effectiveAtUtc': effectiveAtUtc,
        'applicability': applicability.toCanonicalValue(),
        'unitCode': unitCode,
        'confidenceBasis': confidenceBasis,
        'assumption': assumption?.toCanonicalValue(),
      };
}

String _text(String value, String field) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, field, 'Must not be empty.');
  }
  return normalized;
}

String? _nullableText(String? value, String field) =>
    value == null ? null : _text(value, field);

String _sha(String value, String field) {
  final normalized = _text(value, field).toLowerCase();
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(normalized)) {
    throw ArgumentError.value(value, field, 'Expected lowercase SHA-256.');
  }
  return normalized;
}
