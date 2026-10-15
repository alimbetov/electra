import 'dart:convert';

import 'engineering_hash.dart';

enum PowerDependencyKind {
  definition,
  poeDelivery,
  pathStage,
  allocation,
  cableRun,
  capacityGroup,
  groupMembership,
  scenario,
  segment,
  transferLoss,
  missingInput,
}

enum PowerDependencyPresence { present, missing }

/// Canonical dependency identity from ELV4 P7.
///
/// The key is a JSON tuple and never relies on delimiter parsing. Scenario and
/// segment suffixes are appended only for scenario-specific consumed facts.
final class PowerDependencyKey implements Comparable<PowerDependencyKey> {
  PowerDependencyKey({
    required String projectId,
    required String revisionId,
    required this.kind,
    required String entityId,
    required String purpose,
    String? scenarioId,
    String? segmentId,
  })  : projectId = _text(projectId, 'projectId'),
        revisionId = _text(revisionId, 'revisionId'),
        entityId = _text(entityId, 'entityId'),
        purpose = _code(purpose, 'purpose'),
        scenarioId = scenarioId == null ? null : _text(scenarioId, 'scenarioId'),
        segmentId = segmentId == null ? null : _text(segmentId, 'segmentId') {
    if (this.segmentId != null && this.scenarioId == null) {
      throw ArgumentError('Segment dependency requires a scenario identity.');
    }
  }

  final String projectId;
  final String revisionId;
  final PowerDependencyKind kind;
  final String entityId;
  final String purpose;
  final String? scenarioId;
  final String? segmentId;

  List<Object?> toTuple() => [
        'elv4-dep-v1',
        projectId,
        revisionId,
        _kindWire(kind),
        entityId,
        purpose,
        if (scenarioId != null) scenarioId,
        if (segmentId != null) segmentId,
      ];

  String encode() => canonicalEngineeringJsonV1(toTuple());

  String get sha256 => sha256HexUtf8(encode());

  factory PowerDependencyKey.decode(String encoded) {
    final decoded = jsonDecode(encoded);
    if (decoded is! List ||
        decoded.length < 6 ||
        decoded.length > 8 ||
        decoded.first != 'elv4-dep-v1') {
      throw const FormatException('Invalid ELV4 dependency key v1.');
    }
    final values = decoded.cast<Object?>();
    if (values.sublist(1).any((value) => value is! String)) {
      throw const FormatException('Dependency key fields must be strings.');
    }
    return PowerDependencyKey(
      projectId: values[1]! as String,
      revisionId: values[2]! as String,
      kind: _kindFromWire(values[3]! as String),
      entityId: values[4]! as String,
      purpose: values[5]! as String,
      scenarioId: values.length >= 7 ? values[6]! as String : null,
      segmentId: values.length == 8 ? values[7]! as String : null,
    );
  }

  @override
  int compareTo(PowerDependencyKey other) => encode().compareTo(other.encode());

  @override
  bool operator ==(Object other) =>
      other is PowerDependencyKey && encode() == other.encode();

  @override
  int get hashCode => encode().hashCode;
}

final class PowerConsumedFact {
  PowerConsumedFact._({
    required this.key,
    required String valueSchema,
    required this.presence,
    required String canonicalValueJson,
  })  : valueSchema = _text(valueSchema, 'valueSchema'),
        canonicalValueJson =
            _text(canonicalValueJson, 'canonicalValueJson');

  factory PowerConsumedFact.present({
    required PowerDependencyKey key,
    required String valueSchema,
    required Object? value,
  }) =>
      PowerConsumedFact._(
        key: key,
        valueSchema: valueSchema,
        presence: PowerDependencyPresence.present,
        canonicalValueJson: canonicalEngineeringJsonV1(value),
      );

  factory PowerConsumedFact.missing({
    required PowerDependencyKey key,
    required String valueSchema,
  }) =>
      PowerConsumedFact._(
        key: key,
        valueSchema: valueSchema,
        presence: PowerDependencyPresence.missing,
        canonicalValueJson: canonicalEngineeringJsonV1(null),
      );

  final PowerDependencyKey key;
  final String valueSchema;
  final PowerDependencyPresence presence;
  final String canonicalValueJson;

  Map<String, Object?> toMap() => {
        'key': key.encode(),
        'valueSchema': valueSchema,
        'canonicalValueJson': canonicalValueJson,
        'presence': presence.name.toUpperCase(),
      };
}

final class PowerConsumedEvaluationRef
    implements Comparable<PowerConsumedEvaluationRef> {
  PowerConsumedEvaluationRef({
    required String logicalNodeKey,
    required String evaluationId,
    required String inputFingerprint,
  })  : logicalNodeKey = _text(logicalNodeKey, 'logicalNodeKey'),
        evaluationId = _text(evaluationId, 'evaluationId'),
        inputFingerprint = _sha256(inputFingerprint, 'inputFingerprint');

  final String logicalNodeKey;
  final String evaluationId;
  final String inputFingerprint;

  Map<String, Object?> toMap() => {
        'logicalNodeKey': logicalNodeKey,
        'evaluationId': evaluationId,
        'inputFingerprint': inputFingerprint,
      };

  @override
  int compareTo(PowerConsumedEvaluationRef other) {
    final byNode = logicalNodeKey.compareTo(other.logicalNodeKey);
    return byNode != 0 ? byNode : evaluationId.compareTo(other.evaluationId);
  }
}

final class PowerConsumedInputDiff {
  const PowerConsumedInputDiff({
    required this.algorithmChanged,
    required this.changedDependencyKeys,
    required this.changedEvaluationNodeKeys,
  });

  final bool algorithmChanged;
  final List<String> changedDependencyKeys;
  final List<String> changedEvaluationNodeKeys;

  bool get requiresRecalculation =>
      algorithmChanged ||
      changedDependencyKeys.isNotEmpty ||
      changedEvaluationNodeKeys.isNotEmpty;
}

/// Exact RM13 consumed-input projection.
///
/// `dependencyKeys` is derived from the fact set, so the recorded dependency
/// list and hashed facts cannot diverge accidentally.
final class PowerConsumedInput {
  PowerConsumedInput({
    required String algorithmVersion,
    required String inputSchemaVersion,
    required String numericPolicyVersion,
    required Iterable<PowerConsumedFact> facts,
    Iterable<PowerConsumedEvaluationRef> evaluations = const [],
  })  : algorithmVersion = _text(algorithmVersion, 'algorithmVersion'),
        inputSchemaVersion = _text(inputSchemaVersion, 'inputSchemaVersion'),
        numericPolicyVersion = _text(numericPolicyVersion, 'numericPolicyVersion'),
        facts = List.unmodifiable(_sortedFacts(facts)),
        evaluations = List.unmodifiable(_sortedEvaluations(evaluations));

  final String algorithmVersion;
  final String inputSchemaVersion;
  final String numericPolicyVersion;
  final List<PowerConsumedFact> facts;
  final List<PowerConsumedEvaluationRef> evaluations;

  List<String> get dependencyKeys =>
      List.unmodifiable(facts.map((fact) => fact.key.encode()));

  Map<String, Object?> get fingerprintPayload => {
        'algorithmVersion': algorithmVersion,
        'inputSchemaVersion': inputSchemaVersion,
        'numericPolicyVersion': numericPolicyVersion,
        'dependencyKeys': dependencyKeys,
        'consumedFacts': facts.map((fact) => fact.toMap()).toList(growable: false),
        'consumedEvaluations':
            evaluations.map((value) => value.toMap()).toList(growable: false),
      };

  String get inputFingerprint =>
      sha256HexUtf8(canonicalEngineeringJsonV1(fingerprintPayload));

  PowerConsumedInputDiff diff(PowerConsumedInput previous) {
    final currentFacts = {for (final fact in facts) fact.key.encode(): fact};
    final previousFacts = {
      for (final fact in previous.facts) fact.key.encode(): fact,
    };
    final factKeys = {...currentFacts.keys, ...previousFacts.keys}.toList()..sort();
    final changedFacts = <String>[];
    for (final key in factKeys) {
      if (canonicalEngineeringJsonV1(currentFacts[key]?.toMap()) !=
          canonicalEngineeringJsonV1(previousFacts[key]?.toMap())) {
        changedFacts.add(key);
      }
    }

    final currentEvaluations = {
      for (final value in evaluations) value.logicalNodeKey: value,
    };
    final previousEvaluations = {
      for (final value in previous.evaluations) value.logicalNodeKey: value,
    };
    final evaluationKeys = {
      ...currentEvaluations.keys,
      ...previousEvaluations.keys,
    }.toList()
      ..sort();
    final changedEvaluations = <String>[];
    for (final key in evaluationKeys) {
      if (canonicalEngineeringJsonV1(currentEvaluations[key]?.toMap()) !=
          canonicalEngineeringJsonV1(previousEvaluations[key]?.toMap())) {
        changedEvaluations.add(key);
      }
    }

    return PowerConsumedInputDiff(
      algorithmChanged: algorithmVersion != previous.algorithmVersion ||
          inputSchemaVersion != previous.inputSchemaVersion ||
          numericPolicyVersion != previous.numericPolicyVersion,
      changedDependencyKeys: List.unmodifiable(changedFacts),
      changedEvaluationNodeKeys: List.unmodifiable(changedEvaluations),
    );
  }
}

String _kindWire(PowerDependencyKind kind) => switch (kind) {
      PowerDependencyKind.definition => 'DEFINITION',
      PowerDependencyKind.poeDelivery => 'POE_DELIVERY',
      PowerDependencyKind.pathStage => 'PATH_STAGE',
      PowerDependencyKind.allocation => 'ALLOCATION',
      PowerDependencyKind.cableRun => 'CABLE_RUN',
      PowerDependencyKind.capacityGroup => 'CAPACITY_GROUP',
      PowerDependencyKind.groupMembership => 'GROUP_MEMBERSHIP',
      PowerDependencyKind.scenario => 'SCENARIO',
      PowerDependencyKind.segment => 'SEGMENT',
      PowerDependencyKind.transferLoss => 'TRANSFER_LOSS',
      PowerDependencyKind.missingInput => 'MISSING_INPUT',
    };

PowerDependencyKind _kindFromWire(String value) => switch (value) {
      'DEFINITION' => PowerDependencyKind.definition,
      'POE_DELIVERY' => PowerDependencyKind.poeDelivery,
      'PATH_STAGE' => PowerDependencyKind.pathStage,
      'ALLOCATION' => PowerDependencyKind.allocation,
      'CABLE_RUN' => PowerDependencyKind.cableRun,
      'CAPACITY_GROUP' => PowerDependencyKind.capacityGroup,
      'GROUP_MEMBERSHIP' => PowerDependencyKind.groupMembership,
      'SCENARIO' => PowerDependencyKind.scenario,
      'SEGMENT' => PowerDependencyKind.segment,
      'TRANSFER_LOSS' => PowerDependencyKind.transferLoss,
      'MISSING_INPUT' => PowerDependencyKind.missingInput,
      _ => throw const FormatException('Unknown ELV4 dependency kind.'),
    };

List<PowerConsumedFact> _sortedFacts(Iterable<PowerConsumedFact> values) {
  final result = values.toList()..sort((a, b) => a.key.compareTo(b.key));
  final keys = result.map((value) => value.key.encode()).toList();
  if (keys.toSet().length != keys.length) {
    throw ArgumentError('Consumed dependency keys must be unique.');
  }
  return result;
}

List<PowerConsumedEvaluationRef> _sortedEvaluations(
  Iterable<PowerConsumedEvaluationRef> values,
) {
  final result = values.toList()..sort();
  final keys = result.map((value) => value.logicalNodeKey).toList();
  if (keys.toSet().length != keys.length) {
    throw ArgumentError('Consumed evaluation logical node keys must be unique.');
  }
  return result;
}

String _text(String value, String field) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, field, 'Must not be empty.');
  }
  return normalized;
}

String _code(String value, String field) {
  final normalized = _text(value, field).toUpperCase();
  if (!RegExp(r'^[A-Z][A-Z0-9_-]{0,127}$').hasMatch(normalized)) {
    throw ArgumentError.value(value, field, 'Invalid canonical code.');
  }
  return normalized;
}

String _sha256(String value, String field) {
  final normalized = _text(value, field).toLowerCase();
  if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(normalized)) {
    throw ArgumentError.value(value, field, 'Expected lowercase SHA-256.');
  }
  return normalized;
}
