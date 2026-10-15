import 'package:engineering_core/engineering_core.dart';
import 'package:test/test.dart';

void main() {
  group('ELV4 typed dependency key v1', () {
    test('delimiter-heavy ids round-trip without parsing ambiguity', () {
      final key = PowerDependencyKey(
        projectId: 'project|A',
        revisionId: 'revision/1',
        kind: PowerDependencyKind.pathStage,
        entityId: 'stage:patch/A|B',
        purpose: 'poe_path_stage',
        scenarioId: 'scenario:normal',
        segmentId: 'segment|1',
      );

      final decoded = PowerDependencyKey.decode(key.encode());
      expect(decoded, key);
      expect(decoded.sha256, hasLength(64));
      expect(key.toTuple().first, 'elv4-dep-v1');
    });

    test('segment dependency cannot exist without scenario identity', () {
      expect(
        () => PowerDependencyKey(
          projectId: 'project',
          revisionId: 'revision',
          kind: PowerDependencyKind.segment,
          entityId: 'segment',
          purpose: 'scenario_state',
          segmentId: 'segment',
        ),
        throwsArgumentError,
      );
    });
  });

  group('RM13 consumed input projection', () {
    test('enumeration order does not change dependency list or fingerprint', () {
      final a = _fact('a', '1');
      final b = _fact('b', '2');
      final evalA = _evaluation('node-a', 'eval-a', 'a');
      final evalB = _evaluation('node-b', 'eval-b', 'b');

      final first = PowerConsumedInput(
        algorithmVersion: 'algo-v1',
        inputSchemaVersion: 'input-v1',
        numericPolicyVersion: 'numeric-v1',
        facts: [b, a],
        evaluations: [evalB, evalA],
      );
      final second = PowerConsumedInput(
        algorithmVersion: 'algo-v1',
        inputSchemaVersion: 'input-v1',
        numericPolicyVersion: 'numeric-v1',
        facts: [a, b],
        evaluations: [evalA, evalB],
      );

      expect(first.dependencyKeys, second.dependencyKeys);
      expect(first.inputFingerprint, second.inputFingerprint);
    });

    test('present to missing transition invalidates only the exact dependency', () {
      final present = PowerConsumedInput(
        algorithmVersion: 'algo-v1',
        inputSchemaVersion: 'input-v1',
        numericPolicyVersion: 'numeric-v1',
        facts: [_fact('run-stage-a', 'run-1')],
      );
      final key = PowerDependencyKey(
        projectId: 'project',
        revisionId: 'revision',
        kind: PowerDependencyKind.cableRun,
        entityId: 'run-stage-a',
        purpose: 'required_run',
      );
      final missing = PowerConsumedInput(
        algorithmVersion: 'algo-v1',
        inputSchemaVersion: 'input-v1',
        numericPolicyVersion: 'numeric-v1',
        facts: [
          PowerConsumedFact.missing(
            key: key,
            valueSchema: 'test.value.v1',
          ),
        ],
      );

      final diff = missing.diff(present);
      expect(diff.requiresRecalculation, isTrue);
      expect(diff.changedDependencyKeys, [key.encode()]);
      expect(diff.changedEvaluationNodeKeys, isEmpty);
    });

    test('identical consumed input reopens without recalculation', () {
      final first = PowerConsumedInput(
        algorithmVersion: 'algo-v1',
        inputSchemaVersion: 'input-v1',
        numericPolicyVersion: 'numeric-v1',
        facts: [_fact('a', '1')],
        evaluations: [_evaluation('node-a', 'eval-a', 'a')],
      );
      final reopened = PowerConsumedInput(
        algorithmVersion: 'algo-v1',
        inputSchemaVersion: 'input-v1',
        numericPolicyVersion: 'numeric-v1',
        facts: [_fact('a', '1')],
        evaluations: [_evaluation('node-a', 'eval-a', 'a')],
      );

      expect(reopened.inputFingerprint, first.inputFingerprint);
      expect(reopened.diff(first).requiresRecalculation, isFalse);
    });
  });
}

PowerConsumedFact _fact(String entityId, String value) =>
    PowerConsumedFact.present(
      key: PowerDependencyKey(
        projectId: 'project',
        revisionId: 'revision',
        kind: PowerDependencyKind.cableRun,
        entityId: entityId,
        purpose: 'required_run',
      ),
      valueSchema: 'test.value.v1',
      value: {'value': value},
    );

PowerConsumedEvaluationRef _evaluation(
  String node,
  String evaluation,
  String hex,
) =>
    PowerConsumedEvaluationRef(
      logicalNodeKey: node,
      evaluationId: evaluation,
      inputFingerprint: List.filled(64, hex).join(),
    );
