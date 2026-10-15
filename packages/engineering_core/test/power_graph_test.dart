import 'package:engineering_core/engineering_core.dart';
import 'package:test/test.dart';

void main() {
  group('P3 radial graph and trace', () {
    test('one source powers one consumer and upstream trace reaches boundary', () {
      final result = buildPowerGraph(
        _input(
          ports: [
            _dcPort('source', PowerPortRole.source, source: true),
            _dcPort('load', PowerPortRole.consumer),
          ],
          edges: [_edge('feed', 'source', 'load')],
          requirements: [_singleRequirement('load', 'source')],
        ),
      );

      expect(result.blocked, isFalse);
      final validation = validatePowerGraph(result.graph!);
      expect(validation.status, PowerEvaluationStatus.pass);

      final trace = tracePower(
        result.graph!,
        PowerTraceRequest(
          portId: 'load',
          direction: PowerTraceDirection.upstream,
        ),
      );
      expect(trace.edgeIds, ['feed']);
      expect(trace.sourceBoundaryPortIds, ['source']);
      expect(trace.unresolvedFrontierPortIds, isEmpty);
    });

    test('explicit backup selection deactivates mains and selects backup', () {
      final result = buildPowerGraph(
        _input(
          ports: [
            _dcPort('mains', PowerPortRole.source, source: true),
            _dcPort('backup', PowerPortRole.source, source: true),
            _dcPort('load', PowerPortRole.consumer),
          ],
          edges: [
            _edge(
              'mains-feed',
              'mains',
              'load',
              supplySetId: 'PRIMARY',
              sourceBoundaryPortId: 'mains',
            ),
            _edge(
              'backup-feed',
              'backup',
              'load',
              supplySetId: 'PRIMARY',
              sourceBoundaryPortId: 'backup',
            ),
          ],
          requirements: [_alternativeRequirement('load')],
          selectedSources: const {'PRIMARY': 'backup'},
          unavailableSources: const ['mains'],
        ),
      );

      expect(result.graph!.activeEdges.map((edge) => edge.spec.edgeId), [
        'backup-feed',
      ]);
      expect(validatePowerGraph(result.graph!).status, PowerEvaluationStatus.pass);
    });

    test('missing direction stays unresolved instead of disappearing as valid', () {
      final result = buildPowerGraph(
        _input(
          ports: [
            _dcPort('source', PowerPortRole.source, source: true),
            _dcPort('load', PowerPortRole.consumer),
          ],
          edges: [
            _edge('feed', 'source', 'load', directionResolved: false),
          ],
          requirements: [_singleRequirement('load', 'source')],
        ),
      );

      expect(result.unresolvedEdgeIds, ['feed']);
      expect(
        result.findings.map((finding) => finding.code),
        contains('ELV4_POWER_GRAPH_DIRECTION_UNRESOLVED'),
      );
      expect(
        validatePowerGraph(result.graph!).status,
        PowerEvaluationStatus.unresolved,
      );
    });
  });

  group('P3 compatibility boundaries', () {
    test('overlapping voltage is rejected unless source guarantee is contained',
        () {
      final overlap = buildPowerGraph(
        _input(
          ports: [
            _dcPort(
              'source',
              PowerPortRole.source,
              source: true,
              minV: '22',
              maxV: '26',
            ),
            _dcPort(
              'load',
              PowerPortRole.consumer,
              minV: '23',
              maxV: '25',
            ),
          ],
          edges: [_edge('feed', 'source', 'load')],
          requirements: [_singleRequirement('load', 'source')],
        ),
      );
      final invalid = validatePowerGraph(overlap.graph!);
      expect(invalid.status, PowerEvaluationStatus.blocked);
      expect(
        invalid.findings.map((finding) => finding.code),
        contains('ELV4_POWER_VOLTAGE_GUARANTEE_MISMATCH'),
      );

      final contained = buildPowerGraph(
        _input(
          ports: [
            _dcPort(
              'source',
              PowerPortRole.source,
              source: true,
              minV: '24',
              maxV: '24',
            ),
            _dcPort(
              'load',
              PowerPortRole.consumer,
              minV: '23',
              maxV: '25',
            ),
          ],
          edges: [_edge('feed', 'source', 'load')],
          requirements: [_singleRequirement('load', 'source')],
        ),
      );
      expect(
        validatePowerGraph(contained.graph!).status,
        PowerEvaluationStatus.pass,
      );
    });

    test('passive AC/DC domain conversion is rejected', () {
      final result = buildPowerGraph(
        _input(
          ports: [
            _acPort('source', PowerPortRole.source, source: true),
            _dcPort('load', PowerPortRole.consumer),
          ],
          edges: [
            _edge(
              'passive',
              'source',
              'load',
              kind: PowerGraphEdgeKind.passiveContinuity,
            ),
          ],
          requirements: [_singleRequirement('load', 'source')],
        ),
      );

      final validation = validatePowerGraph(result.graph!);
      expect(validation.status, PowerEvaluationStatus.blocked);
      expect(
        validation.findings.map((finding) => finding.code),
        contains('ELV4_POWER_DOMAIN_MISMATCH'),
      );
    });

    test('DC terminal roles must match exactly in both directions', () {
      final result = buildPowerGraph(
        _input(
          ports: [
            _dcPort(
              'source',
              PowerPortRole.source,
              source: true,
              terminals: const ['PLUS'],
            ),
            _dcPort(
              'load',
              PowerPortRole.consumer,
              terminals: const ['PLUS', 'MINUS'],
            ),
          ],
          edges: [_edge('feed', 'source', 'load')],
          requirements: [_singleRequirement('load', 'source')],
        ),
      );

      expect(
        validatePowerGraph(result.graph!).findings.map((finding) => finding.code),
        contains('ELV4_POWER_DC_TERMINAL_MISMATCH'),
      );
    });
  });

  group('P3 adversarial radial validation', () {
    test('self-loop and active cycle are retained and blocked', () {
      final selfLoop = buildPowerGraph(
        _input(
          ports: [_dcPort('source', PowerPortRole.source, source: true)],
          edges: [_edge('loop', 'source', 'source')],
          requirements: const [],
        ),
      );
      final validation = validatePowerGraph(selfLoop.graph!);
      expect(validation.status, PowerEvaluationStatus.blocked);
      expect(
        validation.findings.map((finding) => finding.code),
        contains('ELV4_POWER_GRAPH_ACTIVE_CYCLE'),
      );
    });

    test('same-source diamond is radial reconvergence', () {
      final graph = buildPowerGraph(
        _input(
          ports: [
            _dcPort('source', PowerPortRole.source, source: true),
            _dcPort('a', PowerPortRole.passive),
            _dcPort('b', PowerPortRole.passive),
            _dcPort('load', PowerPortRole.consumer),
          ],
          edges: [
            _edge('s-a', 'source', 'a'),
            _edge('s-b', 'source', 'b'),
            _edge('a-l', 'a', 'load'),
            _edge('b-l', 'b', 'load'),
          ],
          requirements: [_singleRequirement('load', 'source')],
        ),
      ).graph!;

      final validation = validatePowerGraph(graph);
      expect(
        validation.findings.map((finding) => finding.code),
        contains('ELV4_POWER_RADIAL_RECONVERGENCE'),
      );
      expect(
        validation.findings.map((finding) => finding.code),
        isNot(contains('ELV4_POWER_MULTIPLE_SOURCES')),
      );
    });

    test('two source boundaries are classified as multiple sources', () {
      final graph = buildPowerGraph(
        _input(
          ports: [
            _dcPort('source-a', PowerPortRole.source, source: true),
            _dcPort('source-b', PowerPortRole.source, source: true),
            _dcPort('load', PowerPortRole.consumer),
          ],
          edges: [
            _edge('a-load', 'source-a', 'load'),
            _edge('b-load', 'source-b', 'load'),
          ],
          requirements: [
            PowerSupplyRequirement(
              id: 'REQ',
              consumerComponentId: 'component-load',
              supplySetId: 'PRIMARY',
              inputPortIds: const ['load'],
              selectionMode: PowerSupplySelectionMode.alternative,
              candidateSourceIds: const ['source-a', 'source-b'],
              requiredCurrentKind: PowerCurrentKind.dc,
              requiredStateCodes: const ['NORMAL'],
            ),
          ],
        ),
      ).graph!;

      final validation = validatePowerGraph(graph);
      expect(
        validation.findings.map((finding) => finding.code),
        contains('ELV4_POWER_MULTIPLE_SOURCES'),
      );
    });
  });
}

PowerGraphInput _input({
  required Iterable<PowerGraphPort> ports,
  required Iterable<PowerGraphEdgeSpec> edges,
  required Iterable<PowerSupplyRequirement> requirements,
  Map<String, String> selectedSources = const {},
  Iterable<String> unavailableSources = const [],
}) =>
    PowerGraphInput(
      revisionId: 'revision-1',
      scenarioId: 'scenario-1',
      segmentId: 'segment-1',
      ports: ports,
      edges: edges,
      supplyRequirements: requirements,
      selectedSourceBySupplySet: selectedSources,
      unavailableSourceIds: unavailableSources,
    );

PowerGraphEdgeSpec _edge(
  String id,
  String from,
  String to, {
  PowerGraphEdgeKind kind = PowerGraphEdgeKind.externalConnection,
  bool directionResolved = true,
  String? supplySetId,
  String? sourceBoundaryPortId,
}) =>
    PowerGraphEdgeSpec(
      edgeId: id,
      fromPortId: from,
      toPortId: to,
      kind: kind,
      layer: PowerGraphLayer.power,
      sourceEntityId: 'entity-$id',
      provenanceRef: 'fixture:$id',
      directionResolved: directionResolved,
      supplySetId: supplySetId,
      sourceBoundaryPortId: sourceBoundaryPortId,
    );

PowerGraphPort _dcPort(
  String id,
  PowerPortRole role, {
  bool source = false,
  String minV = '24',
  String maxV = '24',
  Iterable<String> terminals = const ['PLUS', 'MINUS'],
}) =>
    PowerGraphPort(
      portId: id,
      componentId: 'component-$id',
      role: role,
      envelope: PowerVoltageEnvelope(
        currentKind: PowerCurrentKind.dc,
        minV: _r(minV),
        nominalV: _r('24'),
        maxV: _r(maxV),
      ),
      terminalRoles: terminals,
      isExplicitSourceBoundary: source,
    );

PowerGraphPort _acPort(
  String id,
  PowerPortRole role, {
  bool source = false,
}) =>
    PowerGraphPort(
      portId: id,
      componentId: 'component-$id',
      role: role,
      envelope: PowerVoltageEnvelope(
        currentKind: PowerCurrentKind.ac,
        minV: _r('220'),
        nominalV: _r('230'),
        maxV: _r('240'),
        frequencyMinHz: _r('49'),
        frequencyMaxHz: _r('51'),
      ),
      terminalRoles: const ['L', 'N'],
      isExplicitSourceBoundary: source,
    );

PowerSupplyRequirement _singleRequirement(String inputPort, String sourceId) =>
    PowerSupplyRequirement(
      id: 'REQ-$inputPort',
      consumerComponentId: 'component-$inputPort',
      supplySetId: 'PRIMARY',
      inputPortIds: [inputPort],
      selectionMode: PowerSupplySelectionMode.single,
      candidateSourceIds: [sourceId],
      requiredCurrentKind: PowerCurrentKind.dc,
      requiredStateCodes: const ['NORMAL'],
    );

PowerSupplyRequirement _alternativeRequirement(String inputPort) =>
    PowerSupplyRequirement(
      id: 'REQ-$inputPort',
      consumerComponentId: 'component-$inputPort',
      supplySetId: 'PRIMARY',
      inputPortIds: [inputPort],
      selectionMode: PowerSupplySelectionMode.alternative,
      candidateSourceIds: const ['mains', 'backup'],
      requiredCurrentKind: PowerCurrentKind.dc,
      requiredStateCodes: const ['NORMAL'],
    );

PowerRational _r(String value) => PowerRational.fromWireDecimal(value);
