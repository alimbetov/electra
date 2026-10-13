import 'dart:convert';
import 'recalculation.dart';

/// Exact, sorted JSON avoids hash collisions and depends only on semantic inputs.
String canonicalEngineeringJson(Object? value) {
  Object? sorted(Object? object) {
    if (object is Map) {
      final keys = object.keys.map((k) => k.toString()).toList()..sort();
      return {for (final key in keys) key: sorted(object[key])};
    }
    if (object is Iterable) return object.map(sorted).toList(growable: false);
    return object;
  }

  return jsonEncode(sorted(value));
}

class DependencyProposal {
  DependencyProposal(
      {required Map<String, Object?> values,
      Iterable<String> issues = const [],
      this.requiresReview = false})
      : values = Map.unmodifiable(values),
        issues = List.unmodifiable(issues);
  final Map<String, Object?> values;
  final List<String> issues;
  final bool requiresReview;
}

class RecalculationNode {
  RecalculationNode(
      {required this.key,
      required this.label,
      required this.version,
      required Map<String, Object?> inputs,
      Iterable<String> dependencies = const [],
      required this.evaluate})
      : inputs = Map.unmodifiable(inputs),
        dependencies = List.unmodifiable(dependencies);
  final String key, label, version;
  final Map<String, Object?> inputs;
  final List<String> dependencies;
  final DependencyProposal Function(Map<String, DependencyProposal>) evaluate;
}

class RecalculationCache {
  RecalculationCache(
      {required this.key,
      required this.fingerprint,
      required this.inputsJson,
      required this.dependenciesJson,
      required this.resultJson,
      required this.state,
      this.previousResultJson,
      this.changesJson = '[]',
      this.manualValue,
      this.manualReason,
      this.manualReviewedFingerprint});
  final String key,
      fingerprint,
      inputsJson,
      dependenciesJson,
      resultJson,
      changesJson;
  final String? previousResultJson,
      manualValue,
      manualReason,
      manualReviewedFingerprint;
  final EngineeringDerivedState state;
  DependencyProposal get proposal {
    final decoded = jsonDecode(resultJson) as Map<String, dynamic>;
    return DependencyProposal(
        values: Map<String, Object?>.from(decoded['values'] as Map),
        issues: (decoded['issues'] as List).cast<String>(),
        requiresReview: decoded['requiresReview'] as bool);
  }
}

class RecalculationSession {
  RecalculationSession(
      {required Iterable<RecalculationNode> nodes,
      Iterable<RecalculationCache> cache = const []})
      : cache = {for (final entry in cache) entry.key: entry} {
    for (final node in nodes) {
      if (this.nodes.containsKey(node.key))
        throw StateError('Duplicate dependency node: ${node.key}');
      if (node.dependencies.toSet().length != node.dependencies.length ||
          node.key.trim().isEmpty)
        throw StateError('Invalid dependency node: ${node.key}');
      this.nodes[node.key] = node;
    }
    final visiting = <String>{}, visited = <String>{};
    void visit(String key) {
      if (visited.contains(key) || !this.nodes.containsKey(key)) return;
      if (!visiting.add(key)) throw StateError('Dependency cycle at $key');
      final dependencies = this.nodes[key]!.dependencies.toList()..sort();
      for (final dependency in dependencies) visit(dependency);
      visiting.remove(key);
      visited.add(key);
      order.add(key);
    }

    final keys = this.nodes.keys.toList()..sort();
    for (final key in keys) visit(key);
    for (final key in order) {
      final closure = <String, Object?>{};
      void collect(String dependency) {
        if (closure.containsKey(dependency)) return;
        final node = this.nodes[dependency];
        closure[dependency] = node == null
            ? {'missing': true}
            : {
                'version': node.version,
                'inputs': node.inputs,
                if (dependency != key &&
                    this.cache[dependency]?.manualValue != null)
                  'manualDecision': {
                    'value': this.cache[dependency]?.manualValue,
                    'reason': this.cache[dependency]?.manualReason,
                    'reviewed':
                        this.cache[dependency]?.manualReviewedFingerprint ==
                            fingerprints[dependency],
                  },
                'dependencies': node.dependencies.toList()..sort()
              };
        if (node != null) for (final child in node.dependencies) collect(child);
      }

      collect(key);
      fingerprints[key] = canonicalEngineeringJson(closure);
    }
  }
  final Map<String, RecalculationNode> nodes = {};
  final Map<String, RecalculationCache> cache;
  final List<String> order = [];
  final Map<String, String> fingerprints = {};
  Set<String> get affectedKeys => nodes.keys
      .where((key) =>
          cache[key]?.fingerprint != fingerprints[key] ||
          cache[key]?.state == EngineeringDerivedState.error)
      .toSet();
  Set<String> get removedKeys =>
      cache.keys.where((key) => !nodes.containsKey(key)).toSet();
  EngineeringDerivedState state(String key) {
    final old = cache[key];
    if (old == null || old.fingerprint != fingerprints[key]) {
      return old?.manualValue != null
          ? EngineeringDerivedState.reviewRequired
          : EngineeringDerivedState.stale;
    }
    if (old.manualValue != null &&
        old.manualReviewedFingerprint != fingerprints[key]) {
      return EngineeringDerivedState.reviewRequired;
    }
    return old.state;
  }

  List<Map<String, Object?>> changes(String key) {
    final node = nodes[key], old = cache[key];
    if (node == null)
      return [
        {'source': key, 'field': 'availability', 'before': true, 'after': false}
      ];
    final changes = <Map<String, Object?>>[];
    final seen = <String>{};
    void inspect(String id) {
      if (!seen.add(id)) return;
      final current = nodes[id], prior = cache[id];
      if (current == null) {
        changes.add({
          'source': id,
          'field': 'availability',
          'before': true,
          'after': false
        });
        return;
      }
      final before = prior == null
          ? <String, dynamic>{}
          : jsonDecode(prior.inputsJson) as Map<String, dynamic>;
      for (final field in {...before.keys, ...current.inputs.keys}.toList()
        ..sort()) {
        if (canonicalEngineeringJson(before[field]) !=
            canonicalEngineeringJson(current.inputs[field])) {
          changes.add({
            'source': id,
            'field': field,
            'before': before[field],
            'after': current.inputs[field]
          });
        }
      }
      final priorDeps = prior == null
          ? <String, dynamic>{}
          : jsonDecode(prior.dependenciesJson) as Map<String, dynamic>;
      if (canonicalEngineeringJson(priorDeps.keys.toList()..sort()) !=
          canonicalEngineeringJson(current.dependencies.toList()..sort())) {
        changes.add({
          'source': id,
          'field': 'dependencies',
          'before': priorDeps.keys.toList()..sort(),
          'after': current.dependencies.toList()..sort()
        });
      }
      if (prior != null &&
          prior.fingerprint != fingerprints[id] &&
          before.isNotEmpty &&
          current.dependencies.isEmpty &&
          canonicalEngineeringJson(before) ==
              canonicalEngineeringJson(current.inputs)) {
        changes.add({
          'source': id,
          'field': 'algorithm',
          'before': 'previous version',
          'after': current.version
        });
      }
      for (final child in current.dependencies) inspect(child);
    }

    inspect(key);
    if (old == null && changes.isEmpty)
      changes.add({
        'source': key,
        'field': 'baseline',
        'before': null,
        'after': node.version
      });
    if (changes.isEmpty &&
        old != null &&
        old.fingerprint != fingerprints[key]) {
      changes.add({
        'source': key,
        'field': 'dependencyReview',
        'before': 'Previous decision basis',
        'after': 'Manual decision or calculation version changed'
      });
    }
    return changes;
  }

  /// Evaluates only affected nodes in dependency order; failed ancestors block totals.
  Map<String, RecalculationCache> recalculate() {
    final affected = affectedKeys, results = <String, DependencyProposal>{};
    final updated = <String, RecalculationCache>{};
    for (final key in order) {
      final node = nodes[key]!, old = cache[key];
      if (!affected.contains(key)) {
        results[key] = old!.proposal;
        continue;
      }
      DependencyProposal proposal;
      final missing =
          node.dependencies.where((id) => !results.containsKey(id)).toList();
      final failed = node.dependencies
          .where((id) => results[id]?.issues.isNotEmpty ?? false)
          .toList();
      try {
        proposal = missing.isNotEmpty || failed.isNotEmpty
            ? DependencyProposal(values: {}, issues: [
                'Unavailable or failed dependencies: ${[
                  ...missing,
                  ...failed
                ].join(", ")}'
              ])
            : node.evaluate(
                {for (final id in node.dependencies) id: results[id]!});
        // Validate serializability before accepting a proposal.
        canonicalEngineeringJson(proposal.values);
      } catch (error) {
        proposal = DependencyProposal(
            values: {}, issues: ['Calculation failed: $error']);
      }
      results[key] = proposal;
      final review = proposal.requiresReview ||
          node.dependencies.any((id) =>
              results[id]?.requiresReview == true ||
              cache[id]?.manualValue != null &&
                  cache[id]?.manualReviewedFingerprint != fingerprints[id]);
      proposal = DependencyProposal(
          values: proposal.values,
          issues: proposal.issues,
          requiresReview: review);
      results[key] = proposal;
      updated[key] = RecalculationCache(
          key: key,
          fingerprint: fingerprints[key]!,
          inputsJson: canonicalEngineeringJson(node.inputs),
          dependenciesJson: canonicalEngineeringJson({
            for (final id in node.dependencies)
              id: fingerprints[id] ?? 'missing'
          }),
          resultJson: canonicalEngineeringJson({
            'values': proposal.values,
            'issues': proposal.issues,
            'requiresReview': review
          }),
          state: proposal.issues.isNotEmpty
              ? EngineeringDerivedState.error
              : review
                  ? EngineeringDerivedState.reviewRequired
                  : EngineeringDerivedState.current,
          previousResultJson: old?.resultJson,
          changesJson: canonicalEngineeringJson(changes(key)),
          manualValue: old?.manualValue,
          manualReason: old?.manualReason,
          manualReviewedFingerprint: old?.manualReviewedFingerprint);
    }
    return updated;
  }
}
