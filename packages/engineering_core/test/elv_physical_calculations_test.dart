import 'package:engineering_core/engineering_core.dart';
import 'package:test/test.dart';

void main() {
  test(
      'installed length applies reserve before run-total termination allowance',
      () {
    const run = CanonicalCableRun(
      id: 'RUN-1',
      projectId: 'PRJ-1',
      cableId: 'CABLE-1',
      designRevisionId: 'REV-1',
      state: CanonicalCableRunState.active,
      reservePercent: 10,
      terminationAllowanceMm: 500,
      revision: 1,
    );
    final result = calculateInstalledLength(
      run: run,
      traversals: const [
        CableRunTraversalGeometry(
          traversalId: 'TRV-1',
          routeSegmentId: 'SEG-1',
          lengthMm: 1000,
          geometryRevision: 1,
        ),
        CableRunTraversalGeometry(
          traversalId: 'TRV-2',
          routeSegmentId: 'SEG-2',
          lengthMm: 2000,
          geometryRevision: 1,
        ),
      ],
      inputFingerprint: 'fp',
    );
    expect(result.state, ElvCalculationState.current);
    expect(result.value, closeTo(3800, 0.0001));
  });

  test('carrier occupancy deduplicates repeated allocations by cable id', () {
    const key = CarrierUsageKey(
      routeSegmentId: 'SEG-1',
      physicalCarrierId: 'CARRIER-1',
    );
    final evidence = calculateCarrierOccupancy(
      usages: const [
        CableCarrierUsage(key: key, cableId: 'CABLE-1', occupiedAreaMm2: 20),
        CableCarrierUsage(key: key, cableId: 'CABLE-1', occupiedAreaMm2: 20),
        CableCarrierUsage(key: key, cableId: 'CABLE-2', occupiedAreaMm2: 30),
      ],
      usableAreaByKey: const {key: 100},
    ).single;
    expect(evidence.cableIds, ['CABLE-1', 'CABLE-2']);
    expect(evidence.occupiedAreaMm2, 50);
    expect(evidence.factualFillRatio, 0.5);
  });

  test('bend evidence never invents a radius when evidence is absent', () {
    final result = evaluateBendRadiusEvidence(
      routeNodeId: 'NODE-1',
      minimumRadiusMm: 30,
      evidence: null,
    );
    expect(result.blocked, isTrue);
    expect(result.actualRadiusMm, isNull);
    expect(result.blockingCode, 'ELV_BEND_EVIDENCE_MISSING');
  });
}
