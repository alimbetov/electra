import 'package:engineering_core/engineering_core.dart';
import 'package:test/test.dart';

void main() {
  group('P2 ELV4 node/evaluation key v2', () {
    test('canonical tuple codec is delimiter-safe and round-trips exactly', () {
      final key = PowerNodeKeyV2(
        revisionId: 'revision|1',
        scenarioId: 'scenario/backup',
        scopeKind: PowerEvaluationScopeKind.segment,
        scopeId: 'segment:alarm',
        processCode: PowerProcessCode.pwr03,
        subjectKind: 'consumer_port',
        subjectId: 'port|A/B',
      );

      final decoded = PowerNodeKeyV2.decode(key.encode());
      expect(decoded, key);
      expect(decoded.sha256, hasLength(64));
      expect(key.encode(), contains('elv4-node-v2'));
    });

    test('evaluation key embeds the logical tuple instead of concatenating ids',
        () {
      final node = _node('source-a');
      final key = PowerEvaluationKeyV2(
        nodeKey: node,
        evaluationId: 'eval/1|retry',
      );

      final decoded = PowerEvaluationKeyV2.decode(key.encode());
      expect(decoded.nodeKey, node);
      expect(decoded.evaluationId, 'eval/1|retry');
    });
  });

  group('P2 immutable evaluation evidence', () {
    test('dependencies are sorted unique and fingerprint is deterministic', () {
      final sourceA = _node('source-a');
      final sourceB = _node('source-b');
      final evidenceA = _evidence(
        dependencies: [sourceB, sourceA],
        assumptions: const ['temperature reviewed', 'radial topology'],
      );
      final evidenceB = _evidence(
        dependencies: [sourceA, sourceB],
        assumptions: const ['radial topology', 'temperature reviewed'],
      );

      expect(evidenceA.dependencies, [sourceA, sourceB]);
      expect(evidenceA.evidenceSha256, evidenceB.evidenceSha256);
      expect(evidenceA.key.encode(), contains('elv4-evaluation-v2'));
    });

    test('duplicate dependency is rejected instead of silently collapsed', () {
      final source = _node('source-a');
      expect(
        () => _evidence(dependencies: [source, source]),
        throwsArgumentError,
      );
    });

    test('pointer supports only CURRENT to STALE to guarded CURRENT', () {
      final first = _evidence(dependencies: const []);
      final pointer = PowerEvaluationPointer.firstPublication(first);
      expect(pointer.state, PowerPointerState.current);
      expect(pointer.generation, 1);

      final stale = pointer.markStale();
      expect(stale.state, PowerPointerState.stale);
      expect(stale.generation, 2);

      final next = PowerEvaluationEvidence(
        evaluationId: 'eval-2',
        nodeKey: first.nodeKey,
        algorithmVersion: 'algo-1',
        inputSchemaVersion: 'input-1',
        outputSchemaVersion: 'output-1',
        inputFingerprint:
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        status: PowerEvaluationStatus.fail,
        applicability: PowerEvaluationApplicability.applicable,
        inputs: const {'loadW': '25'},
        output: const {'capacityW': '20'},
      );
      final published = stale.publish(next);
      expect(published.state, PowerPointerState.current);
      expect(published.generation, 3);
      expect(published.evaluationId, 'eval-2');

      expect(pointer.markStale().markStale, throwsStateError);
    });
  });
}

PowerNodeKeyV2 _node(String subjectId) => PowerNodeKeyV2(
      revisionId: 'revision-1',
      scenarioId: 'scenario-1',
      scopeKind: PowerEvaluationScopeKind.segment,
      scopeId: 'segment-1',
      processCode: PowerProcessCode.pwr01,
      subjectKind: 'source',
      subjectId: subjectId,
    );

PowerEvaluationEvidence _evidence({
  required Iterable<PowerNodeKeyV2> dependencies,
  Iterable<String> assumptions = const [],
}) =>
    PowerEvaluationEvidence(
      evaluationId: 'eval-1',
      nodeKey: PowerNodeKeyV2(
        revisionId: 'revision-1',
        scenarioId: 'scenario-1',
        scopeKind: PowerEvaluationScopeKind.segment,
        scopeId: 'segment-1',
        processCode: PowerProcessCode.pwr02,
        subjectKind: 'capacity_group',
        subjectId: 'group-1',
      ),
      algorithmVersion: 'algo-1',
      inputSchemaVersion: 'input-1',
      outputSchemaVersion: 'output-1',
      inputFingerprint:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      status: PowerEvaluationStatus.pass,
      applicability: PowerEvaluationApplicability.applicable,
      inputs: const {'demandW': '10'},
      output: const {'availableW': '20'},
      dependencies: dependencies,
      quantities: const [
        {'code': 'DEMAND_W', 'value': '10'}
      ],
      arithmeticSteps: const [
        {'operation': 'COMPARE', 'left': '10', 'right': '20'}
      ],
      findings: [
        PowerEvaluationFinding(
          code: 'CAPACITY_OK',
          severity: 'info',
          message: 'Demand is within the declared capacity.',
        ),
      ],
      assumptions: assumptions,
    );
