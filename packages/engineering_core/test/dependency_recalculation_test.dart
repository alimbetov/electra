import 'dart:convert';
import 'package:engineering_core/engineering_core.dart';
import 'package:test/test.dart';

void main() {
  Map<String, int> calls = {};
  List<RecalculationNode> graph(
      {double power = 100, bool fail = false, String version = 'v1'}) {
    RecalculationNode node(
            String key,
            Map<String, Object?> inputs,
            List<String> deps,
            Map<String, Object?> Function(Map<String, DependencyProposal>)
                output) =>
        RecalculationNode(
            key: key,
            label: key,
            version: key == 'circuit:a' ? version : 'v1',
            inputs: inputs,
            dependencies: deps,
            evaluate: (values) {
              calls[key] = (calls[key] ?? 0) + 1;
              if (fail && key == 'circuit:a')
                throw StateError('temporary failure');
              return DependencyProposal(values: output(values));
            });
    return [
      node('consumer:a', {'power': power}, [], (_) => {'power': power}),
      node('consumer:b', {'power': 50}, [], (_) => {'power': 50}),
      node('geometry:wall', {'length': 2000}, [], (_) => {'length': 2000}),
      node('route:r', {}, ['geometry:wall'],
          (v) => {'length': v['geometry:wall']!.values['length']}),
      node('circuit:a', {}, ['consumer:a'],
          (v) => {'current': (v['consumer:a']!.values['power'] as num) / 10}),
      node('circuit:b', {}, ['consumer:b'], (v) => {'current': 5}),
      node(
          'cable:a',
          {},
          ['circuit:a', 'route:r'],
          (v) => {
                'current': v['circuit:a']!.values['current'],
                'length': v['route:r']!.values['length']
              }),
      node('protection:a', {}, ['cable:a'],
          (v) => {'current': v['cable:a']!.values['current']}),
      node('panel:a', {}, ['cable:a', 'protection:a'],
          (v) => {'current': v['cable:a']!.values['current']}),
    ];
  }

  setUp(() => calls = {});
  test(
      'load change evaluates only its downstream subgraph and explains before/after',
      () {
    final initial = RecalculationSession(nodes: graph()).recalculate();
    calls.clear();
    final next =
        RecalculationSession(nodes: graph(power: 200), cache: initial.values);
    expect(next.affectedKeys,
        {'consumer:a', 'circuit:a', 'cable:a', 'protection:a', 'panel:a'});
    expect(next.state('route:r'), EngineeringDerivedState.current);
    expect(
        next.changes('panel:a').single,
        equals({
          'source': 'consumer:a',
          'field': 'power',
          'before': 100.0,
          'after': 200.0
        }));
    final changed = next.recalculate();
    expect(calls.keys.toSet(), next.affectedKeys);
    expect(changed['circuit:a']!.proposal.values['current'], 20);
    expect(
        jsonDecode(changed['circuit:a']!.previousResultJson!)['values']
            ['current'],
        10);
    expect(changed.containsKey('route:r'), isFalse);
    expect(changed.containsKey('circuit:b'), isFalse);
    final stable = RecalculationSession(
        nodes: graph(power: 200), cache: {...initial, ...changed}.values);
    expect(stable.recalculate(), isEmpty);
  });
  test('ordering is canonical, calculation versions invalidate downstream only',
      () {
    final initial = RecalculationSession(nodes: graph()),
        saved = initial.recalculate();
    final reordered =
        RecalculationSession(nodes: graph().reversed, cache: saved.values);
    expect(reordered.fingerprints, initial.fingerprints);
    expect(reordered.affectedKeys, isEmpty);
    expect(
        RecalculationSession(nodes: graph(version: 'v2'), cache: saved.values)
            .affectedKeys,
        {'circuit:a', 'cable:a', 'protection:a', 'panel:a'});
  });
  test(
      'failed node blocks dependent totals, independent circuit stays intact and retry works',
      () {
    final first = RecalculationSession(nodes: graph(fail: true)).recalculate();
    expect(first['panel:a']!.state, EngineeringDerivedState.error);
    expect(first['panel:a']!.proposal.values, isEmpty);
    expect(first['circuit:b']!.state, EngineeringDerivedState.current);
    final retry =
        RecalculationSession(nodes: graph(), cache: first.values).recalculate();
    expect(retry['panel:a']!.proposal.values['current'], 10);
    expect(retry.containsKey('circuit:b'), isFalse);
  });
  test(
      'missing dependency has no partial output and cycles/duplicates are rejected',
      () {
    final missing = RecalculationSession(nodes: [
      RecalculationNode(
          key: 'a',
          label: 'a',
          version: 'v1',
          inputs: const {},
          dependencies: ['gone'],
          evaluate: (_) => throw StateError('must not execute')),
    ]).recalculate();
    expect(missing['a']!.state, EngineeringDerivedState.error);
    expect(missing['a']!.proposal.values, isEmpty);
    RecalculationNode node(String key, List<String> deps) => RecalculationNode(
        key: key,
        label: key,
        version: 'v1',
        inputs: const {},
        dependencies: deps,
        evaluate: (_) => DependencyProposal(values: {}));
    expect(
        () => RecalculationSession(nodes: [
              node('a', ['b']),
              node('b', ['a'])
            ]),
        throwsStateError);
    expect(() => RecalculationSession(nodes: [node('a', []), node('a', [])]),
        throwsStateError);
  });
  test(
      'manual decision survives recalculation and review changes propagate to dependants',
      () {
    final base = RecalculationSession(nodes: graph()),
        saved = base.recalculate();
    final old = saved['circuit:a']!;
    RecalculationCache manual(String? reviewed, {RecalculationCache? entry}) {
      final e = entry ?? old;
      return RecalculationCache(
          key: e.key,
          fingerprint: e.fingerprint,
          inputsJson: e.inputsJson,
          dependenciesJson: e.dependenciesJson,
          resultJson: e.resultJson,
          state: e.state,
          manualValue: 'Engineer decision',
          manualReason: 'Site requirement',
          manualReviewedFingerprint: reviewed);
    }

    saved['circuit:a'] = manual(base.fingerprints['circuit:a']);
    final before = RecalculationSession(nodes: graph(), cache: saved.values);
    saved.addAll(before.recalculate());
    final changed =
        RecalculationSession(nodes: graph(power: 200), cache: saved.values);
    expect(changed.state('circuit:a'), EngineeringDerivedState.reviewRequired);
    final computed = changed.recalculate();
    expect(computed['circuit:a']!.manualValue, 'Engineer decision');
    expect(computed['cable:a']!.state, EngineeringDerivedState.reviewRequired);
    expect(computed['panel:a']!.state, EngineeringDerivedState.reviewRequired);
    saved.addAll(computed);
    saved['circuit:a'] =
        manual(changed.fingerprints['circuit:a'], entry: saved['circuit:a']);
    final reviewed =
        RecalculationSession(nodes: graph(power: 200), cache: saved.values);
    expect(reviewed.state('circuit:a'), EngineeringDerivedState.current);
    expect(reviewed.recalculate()['cable:a']!.state,
        EngineeringDerivedState.current);
  });
  test('removed nodes remain explicit, nonfinite output becomes error', () {
    final saved = RecalculationSession(nodes: graph()).recalculate();
    expect(
        RecalculationSession(nodes: const [], cache: saved.values).removedKeys,
        saved.keys.toSet());
    final bad = RecalculationSession(nodes: [
      RecalculationNode(
          key: 'nan',
          label: 'nan',
          version: 'v1',
          inputs: const {},
          evaluate: (_) => DependencyProposal(values: {'value': double.nan}))
    ]).recalculate();
    expect(bad['nan']!.state, EngineeringDerivedState.error);
    expect(bad['nan']!.proposal.values, isEmpty);
  });
}
