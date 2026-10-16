import 'package:engineering_core/engineering_core.dart';
import 'package:test/test.dart';

void main() {
  group('P3 graph readiness dimensions', () {
    test('valid topology stays usable while physical realization is unresolved',
        () {
      final readiness = assessPowerGraphReadiness(
        topology: const PowerTopologyValidation(
          status: PowerEvaluationStatus.pass,
          findings: [],
        ),
        missingRealizationDependencyKeys: const [
          'route:cable-1',
          'cable-run:cable-1',
        ],
        capacityDependencyKeys: const ['pwr02:psu-1'],
        backupDependencyKeys: const ['pwr06:ups-1'],
      );

      expect(readiness.topologyUsable, isTrue);
      expect(readiness.fullyResolved, isFalse);
      expect(
        readiness[PowerGraphReadinessDimension.topology].status,
        PowerEvaluationStatus.pass,
      );
      expect(
        readiness[PowerGraphReadinessDimension.realization].status,
        PowerEvaluationStatus.unresolved,
      );
      expect(
        readiness[PowerGraphReadinessDimension.realization].dependencyKeys,
        ['cable-run:cable-1', 'route:cable-1'],
      );
      expect(
        readiness[PowerGraphReadinessDimension.capacity].status,
        PowerEvaluationStatus.unresolved,
      );
      expect(
        readiness[PowerGraphReadinessDimension.backup].status,
        PowerEvaluationStatus.unresolved,
      );
    });

    test(
        'topology failure does not erase independent capacity and backup state',
        () {
      final readiness = assessPowerGraphReadiness(
        topology: PowerTopologyValidation(
          status: PowerEvaluationStatus.blocked,
          findings: [
            PowerGraphFinding(
              code: 'ELV4_POWER_GRAPH_ACTIVE_CYCLE',
              status: PowerEvaluationStatus.blocked,
              subjectId: 'segment-1',
              message: 'cycle',
            ),
          ],
        ),
        capacityStatus: PowerEvaluationStatus.fail,
        backupStatus: PowerEvaluationStatus.pass,
      );

      expect(readiness.topologyUsable, isFalse);
      expect(
        readiness[PowerGraphReadinessDimension.topology].findingCodes,
        ['ELV4_POWER_GRAPH_ACTIVE_CYCLE'],
      );
      expect(
        readiness[PowerGraphReadinessDimension.capacity].status,
        PowerEvaluationStatus.fail,
      );
      expect(
        readiness[PowerGraphReadinessDimension.backup].status,
        PowerEvaluationStatus.pass,
      );
    });

    test('dimension collection is canonical and complete', () {
      final readiness = PowerGraphReadiness([
        PowerGraphDimensionResult(
          dimension: PowerGraphReadinessDimension.backup,
          status: PowerEvaluationStatus.pass,
        ),
        PowerGraphDimensionResult(
          dimension: PowerGraphReadinessDimension.capacity,
          status: PowerEvaluationStatus.pass,
        ),
        PowerGraphDimensionResult(
          dimension: PowerGraphReadinessDimension.realization,
          status: PowerEvaluationStatus.pass,
        ),
        PowerGraphDimensionResult(
          dimension: PowerGraphReadinessDimension.topology,
          status: PowerEvaluationStatus.pass,
        ),
      ]);

      expect(
        readiness.dimensions.map((value) => value.dimension),
        PowerGraphReadinessDimension.values,
      );
      expect(readiness.fullyResolved, isTrue);
    });
  });
}
