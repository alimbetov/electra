import 'package:electra_mobile/application/elv5/calculation/elv5_calculation_runtime.dart';
import 'package:electra_mobile/application/elv5/lan/elv5_lan_persistence.dart';
import 'package:electra_mobile/application/elv5/lan/lan07_patch_contract.dart';
import 'package:electra_mobile/application/elv5/lan/lan07_runtime.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'LAN07 reference vector reports +1 spare headroom with complete mappings',
    () async {
      final payload = _payload(_assignments(5));
      final resolver = Lan07PersistedInputResolver(
        lanStore: _Store(payload),
        contractSource: _Contracts(_contract(payload)),
      );

      final result = await buildLan07Executor().execute(
        await resolver.capture(_request()),
      );

      expect(result.assessment, Elv5Assessment.pass);
      expect(result.output['occupied'], 5);
      expect(result.output['free'], 3);
      expect(result.output['requiredSpare'], 2);
      expect(result.output['spareHeadroom'], 1);
      expect(result.output['conflictingAssignmentIds'], isEmpty);
    },
  );

  test('LAN07 missing required source mapping stays unresolved', () async {
    final payload = _payload(_assignments(5));
    final resolver = Lan07PersistedInputResolver(
      lanStore: _Store(payload),
      contractSource: _Contracts(
        _contract(
          payload,
          requiredSources: const <String>{
            'term-1',
            'term-2',
            'term-3',
            'term-4',
            'term-5',
            'term-missing',
          },
        ),
      ),
    );

    final result = await buildLan07Executor().execute(
      await resolver.capture(_request()),
    );

    expect(result.assessment, Elv5Assessment.unresolved);
    expect(result.completion, Elv5Completion.partial);
    final mappings = result.output['mappings']! as List<Object?>;
    expect(
      mappings.whereType<Map<String, Object?>>().singleWhere(
        (item) => item['sourceEndpointId'] == 'term-missing',
      )['status'],
      'unresolved',
    );
  });

  test(
    'LAN07 duplicate physical port assignments fail instead of creating capacity',
    () async {
      final assignments = _assignments(4)..add(<String, Object?>{
        'panelPortId': 'p1',
        'terminationId': 'term-5',
        'linkId': 'link-5',
      });
      final payload = _payload(assignments);
      final resolver = Lan07PersistedInputResolver(
        lanStore: _Store(payload),
        contractSource: _Contracts(
          _contract(
            payload,
            requiredSources: const <String>{
              'term-1',
              'term-2',
              'term-3',
              'term-4',
              'term-5',
            },
          ),
        ),
      );

      final result = await buildLan07Executor().execute(
        await resolver.capture(_request()),
      );

      expect(result.assessment, Elv5Assessment.fail);
      expect(result.output['occupied'], 4);
      expect(
        (result.output['conflictingAssignmentIds']! as List<Object?>),
        hasLength(2),
      );
    },
  );
}

Elv5CalculationRequest _request() => Elv5CalculationRequest(
  projectId: 'project',
  designRevisionId: 'revision',
  scope: Elv5ScopeRef(
    kind: Elv5ScopeKind.design,
    scopeId: 'revision',
    scenarioKey: 'NONE',
  ),
  processCode: Elv5ProcessCode.lan07,
  subject: Elv5SubjectRef(kind: 'PATCH_PANEL', id: 'panel-1'),
  expectedPointerGeneration: 0,
);

List<Map<String, Object?>> _assignments(int count) => <Map<String, Object?>>[
  for (var i = 1; i <= count; i++)
    <String, Object?>{
      'panelPortId': 'p$i',
      'terminationId': 'term-$i',
      'linkId': 'link-$i',
    },
];

Map<String, Object?> _payload(List<Map<String, Object?>> assignments) =>
    <String, Object?>{
      'panelId': 'panel-1',
      'assignments': assignments,
      'sparePolicyRef': <String, Object?>{
        'policyCode': 'PATCH_SPARE_POLICY',
        'editionId': 'patch-policy-v1',
        'contentHash': _hash('d'),
      },
    };

Lan07PatchPanelContract _contract(
  Map<String, Object?> payload, {
  Set<String>? requiredSources,
}) => Lan07PatchPanelContract(
  panelId: 'panel-1',
  expectedAggregateFingerprint: lan07AggregateFingerprint(payload),
  policyRef: Lan07PolicyRef(
    policyCode: 'PATCH_SPARE_POLICY',
    editionId: 'patch-policy-v1',
    contentHash: _hash('d'),
  ),
  physicalPortIds: <String>[for (var i = 1; i <= 8; i++) 'p$i'],
  unavailablePortIds: const <String>[],
  requiredSourceEndpointIds:
      requiredSources ??
      const <String>{'term-1', 'term-2', 'term-3', 'term-4', 'term-5'},
  absoluteMinimumSpare: 2,
  spareRatio: Elv5Rational.zero,
  spareCombinerCode: 'MAX',
  panelEvidenceRef: 'CATALOG:panel-1',
  panelEvidenceContentHash: _hash('c'),
);

final class _Store implements Elv5LanFactStore {
  const _Store(this.payload);
  final Map<String, Object?> payload;

  @override
  Future<Elv5LanAggregateSnapshot?> load({
    required String projectId,
    required String designRevisionId,
    required String operation,
    required String subjectId,
  }) async => Elv5LanAggregateSnapshot(
    aggregateKind: 'LAN_PATCH_PANEL_ASSIGNMENTS',
    aggregateId: 'ELV5:LAN_PATCH_PANEL_ASSIGNMENTS:panel-1',
    subjectId: 'panel-1',
    revision: 4,
    payload: payload,
  );
}

final class _Contracts implements Lan07PatchPanelContractSource {
  const _Contracts(this.contract);
  final Lan07PatchPanelContract contract;

  @override
  Future<Lan07PatchPanelContractSnapshot?> loadActiveForPanel({
    required String projectId,
    required String designRevisionId,
    required String panelId,
  }) async => Lan07PatchPanelContractSnapshot(
    bindingId: 'lan07-binding',
    bindingRevision: 1,
    evidenceRef: 'LAN07:panel-1:${_hash('e')}',
    contentHash: _hash('e'),
    contract: contract,
  );
}

String _hash(String char) => List<String>.filled(64, char).join();
