import 'package:engineering_core/engineering_core_elv5.dart';

/// Canonical Foundation pilot gates from the F1/F2 execution contract.
enum Elv5QualificationGate {
  q0ContractSchemaInventory,
  q1MathematicalReferenceVectors,
  q2IndependentOracle,
  q3BoundaryQualification,
  q4PropertyMetamorphic,
  q5RealisticScenarioCombinatorial,
  q6PersistenceReplayInvalidationPublication,
  q7FailureConcurrencyRestart,
  q8FreezeHistoricalDeterminism,
  q9PerformanceBounds,
}

final class Elv5ReferenceVector<I, O> {
  Elv5ReferenceVector({
    required String id,
    required this.input,
    required this.expected,
    Map<String, Object?> metadata = const <String, Object?>{},
  })  : id = _text(id, 'id'),
        metadata = Map.unmodifiable(metadata);

  final String id;
  final I input;
  final O expected;
  final Map<String, Object?> metadata;
}

final class Elv5BoundaryTriplet<T> {
  const Elv5BoundaryTriplet({
    required this.below,
    required this.exact,
    required this.above,
  });

  final T below;
  final T exact;
  final T above;

  Iterable<T> get values sync* {
    yield below;
    yield exact;
    yield above;
  }
}

final class Elv5QualificationEvidencePin implements Elv5CanonicalValue {
  Elv5QualificationEvidencePin({
    required String sourceSha,
    required String authorityFingerprint,
    required String processVersion,
    required String rulesetVersion,
    required String testId,
  })  : sourceSha = _gitSha(sourceSha),
        authorityFingerprint =
            _sha(authorityFingerprint, 'authorityFingerprint'),
        processVersion = _text(processVersion, 'processVersion'),
        rulesetVersion = _text(rulesetVersion, 'rulesetVersion'),
        testId = _text(testId, 'testId');

  static const schema = 'electra.elv5-foundation-qualification-evidence-pin.v1';

  final String sourceSha;
  final String authorityFingerprint;
  final String processVersion;
  final String rulesetVersion;
  final String testId;

  @override
  Map<String, Object?> toCanonicalValue() => <String, Object?>{
        'schema': schema,
        'sourceSha': sourceSha,
        'authorityFingerprint': authorityFingerprint,
        'processVersion': processVersion,
        'rulesetVersion': rulesetVersion,
        'testId': testId,
      };

  String sha256({Elv5CanonicalEncoder encoder = const Elv5CanonicalJsonV1()}) =>
      encoder.sha256(toCanonicalValue());
}

final class Elv5QualificationGateEvidence implements Elv5CanonicalValue {
  Elv5QualificationGateEvidence({
    required this.gate,
    required this.pin,
    required Iterable<String> evidenceRefs,
    required Iterable<String> assertions,
  })  : evidenceRefs =
            List.unmodifiable(_sortedUnique(evidenceRefs, 'evidenceRefs')),
        assertions =
            List.unmodifiable(_sortedUnique(assertions, 'assertions')) {
    if (this.evidenceRefs.isEmpty || this.assertions.isEmpty) {
      throw ArgumentError('Qualification gate evidence must not be empty.');
    }
  }

  final Elv5QualificationGate gate;
  final Elv5QualificationEvidencePin pin;
  final List<String> evidenceRefs;
  final List<String> assertions;

  @override
  Map<String, Object?> toCanonicalValue() => <String, Object?>{
        'gate': gate.name,
        'pin': pin.toCanonicalValue(),
        'evidenceRefs': evidenceRefs,
        'assertions': assertions,
      };
}

final class Elv5PilotQualificationMatrix implements Elv5CanonicalValue {
  Elv5PilotQualificationMatrix({
    required String pilotId,
    required Iterable<Elv5QualificationGate> mandatoryGates,
    required Iterable<Elv5QualificationGateEvidence> evidence,
  })  : pilotId = _text(pilotId, 'pilotId'),
        mandatoryGates = Set.unmodifiable(mandatoryGates),
        evidence = List.unmodifiable(evidence) {
    if (this.mandatoryGates.isEmpty) {
      throw ArgumentError('Pilot must declare mandatory qualification gates.');
    }
    final byGate = <Elv5QualificationGate, Elv5QualificationGateEvidence>{};
    for (final item in this.evidence) {
      if (byGate.putIfAbsent(item.gate, () => item) != item) {
        throw ArgumentError(
            'Duplicate qualification evidence for ${item.gate.name}.');
      }
    }
  }

  final String pilotId;
  final Set<Elv5QualificationGate> mandatoryGates;
  final List<Elv5QualificationGateEvidence> evidence;

  Set<Elv5QualificationGate> get evidencedGates =>
      Set.unmodifiable(evidence.map((value) => value.gate).toSet());

  Set<Elv5QualificationGate> get missingMandatoryGates => Set.unmodifiable(
        mandatoryGates.difference(evidencedGates),
      );

  bool get allMandatoryGatesSatisfied => missingMandatoryGates.isEmpty;

  @override
  Map<String, Object?> toCanonicalValue() {
    final gates = mandatoryGates.map((value) => value.name).toList()..sort();
    final rows = evidence.toList()
      ..sort((a, b) => a.gate.name.compareTo(b.gate.name));
    return <String, Object?>{
      'pilotId': pilotId,
      'mandatoryGates': gates,
      'evidence': <Object?>[for (final row in rows) row.toCanonicalValue()],
    };
  }

  String sha256({Elv5CanonicalEncoder encoder = const Elv5CanonicalJsonV1()}) =>
      encoder.sha256(toCanonicalValue());
}

void requireIndependentOracle<T>({
  required T production,
  required T oracle,
  bool Function(T left, T right)? equivalent,
}) {
  final same = equivalent?.call(production, oracle) ?? production == oracle;
  if (!same) {
    throw StateError('ELV5_INDEPENDENT_ORACLE_MISMATCH:$production:$oracle');
  }
}

void requireMetamorphicInvariant<T>({
  required String relation,
  required T baseline,
  required T transformed,
  required bool Function(T left, T right) invariant,
}) {
  if (!invariant(baseline, transformed)) {
    throw StateError(
        'ELV5_METAMORPHIC_INVARIANT_FAILED:${_text(relation, 'relation')}');
  }
}

void requireDeterministicHashes(Iterable<String> hashes) {
  final values = hashes.toList(growable: false);
  if (values.isEmpty)
    throw ArgumentError('Determinism sample cannot be empty.');
  for (final value in values) {
    _sha(value, 'hash');
  }
  if (values.toSet().length != 1) {
    throw StateError('ELV5_DETERMINISM_HASH_MISMATCH');
  }
}

List<String> _sortedUnique(Iterable<String> values, String field) {
  final result = <String>{};
  for (final value in values) {
    result.add(_text(value, field));
  }
  final sorted = result.toList()..sort();
  return sorted;
}

String _text(String value, String field) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, field, 'Must not be empty.');
  }
  return normalized;
}

String _sha(String value, String field) {
  final normalized = _text(value, field).toLowerCase();
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(normalized)) {
    throw ArgumentError.value(value, field, 'Expected lowercase SHA-256.');
  }
  return normalized;
}

String _gitSha(String value) {
  final normalized = _text(value, 'sourceSha').toLowerCase();
  if (!RegExp(r'^(?:[0-9a-f]{40}|[0-9a-f]{64})$').hasMatch(normalized)) {
    throw ArgumentError.value(
        value, 'sourceSha', 'Expected full Git SHA-1 or SHA-256 object id.');
  }
  return normalized;
}
