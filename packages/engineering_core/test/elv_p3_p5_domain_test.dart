import 'package:engineering_core/engineering_core.dart';
import 'package:test/test.dart';

void main() {
  test('P3 design revision state machine preserves frozen history direction', () {
    expect(
      ProjectDesignRevisionStateMachine.canTransition(
        ProjectDesignRevisionState.working,
        ProjectDesignRevisionState.frozen,
      ),
      isTrue,
    );
    expect(
      ProjectDesignRevisionStateMachine.canTransition(
        ProjectDesignRevisionState.frozen,
        ProjectDesignRevisionState.working,
      ),
      isFalse,
    );
  });

  test('P3 traversal sequence must be gap-free and 1-based', () {
    final errors = validateTraversalChain([
      const CableRunTraversal(
        id: 't1',
        cableRunId: 'run-1',
        sequence: 1,
        routeSegmentId: 's1',
        direction: CableTraversalDirection.forward,
      ),
      const CableRunTraversal(
        id: 't2',
        cableRunId: 'run-1',
        sequence: 3,
        routeSegmentId: 's2',
        direction: CableTraversalDirection.forward,
      ),
    ]);
    expect(errors, contains(contains('gap-free')));
  });

  test('P4 pathway hierarchy rejects cycles', () {
    final a = PathwayContext(
      id: 'a',
      projectId: 'p',
      kind: PathwayContextKind.floorCommon,
      host: const FloorHost('f1'),
      lifecycleState: PathwayContextLifecycleState.active,
      revision: 1,
      parentContextId: 'b',
    );
    final b = PathwayContext(
      id: 'b',
      projectId: 'p',
      kind: PathwayContextKind.projectShared,
      host: const ProjectHost('p'),
      lifecycleState: PathwayContextLifecycleState.active,
      revision: 1,
      parentContextId: 'a',
    );
    expect(
      PathwayContextValidator.validate(
        context: a,
        projectContexts: {'a': a, 'b': b},
      ),
      contains(contains('acyclic')),
    );
  });

  test('P4 carrier compartments cannot exceed usable carrier area', () {
    final carrier = PhysicalCarrier(
      id: 'c',
      projectId: 'p',
      pathwayContextId: 'ctx',
      code: 'TRAY-1',
      name: 'Tray',
      kind: PhysicalCarrierKind.tray,
      crossSection: const RectangularCarrierCrossSection(widthMm: 100, heightMm: 10),
      environmentFacts: const CarrierEnvironmentFacts(),
      installationFacts: const CarrierInstallationFacts(),
      lifecycleState: PhysicalCarrierLifecycleState.active,
      revision: 1,
    );
    final errors = validateCarrierCompartments(
      carrier: carrier,
      compartments: [
        const PhysicalCarrierCompartment(
          id: 'x',
          carrierId: 'c',
          code: 'A',
          sequence: 1,
          crossSection: RectangularCarrierCrossSection(widthMm: 80, heightMm: 10),
          lifecycleState: CarrierCompartmentLifecycleState.active,
          revision: 1,
        ),
        const PhysicalCarrierCompartment(
          id: 'y',
          carrierId: 'c',
          code: 'B',
          sequence: 2,
          crossSection: RectangularCarrierCrossSection(widthMm: 80, heightMm: 10),
          lifecycleState: CarrierCompartmentLifecycleState.active,
          revision: 1,
        ),
      ],
    );
    expect(errors, contains(contains('exceeds')));
  });

  test('P5 engine returns forbidden for cable diameter above profile limit', () {
    final selector = PhysicalCompatibilitySelector(mediaCodes: const ['COPPER']);
    final findings = PhysicalCompatibilityEngine.evaluate(
      PhysicalCompatibilityInput(
        subjectIds: const ['cable-1', 'carrier-1'],
        mediaCode: 'COPPER',
        cableCategoryCode: 'CAT6',
        cableTechnicalClassCodes: const ['DATA'],
        cableOuterDiameterMm: 8,
        carrierKind: 'CONDUIT',
        carrierUsableAreaMm2: 100,
        installationClassCode: 'CONDUIT',
        environmentCodes: const {},
        pathwayKind: 'ROOM_LOCAL',
        profileRefs: const [],
        rules: [MaximumCableDiameterRule(selector, 6.5)],
        inputFingerprint: 'fp',
      ),
    );
    expect(findings.first.status, PhysicalCompatibilityStatus.forbidden);
    expect(findings.first.code, 'ELV_PHYS_CABLE_DIAMETER_EXCEEDED');
  });
}
