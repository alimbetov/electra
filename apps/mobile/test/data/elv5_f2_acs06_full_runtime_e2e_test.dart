import 'package:electra_mobile/application/elv5/acs/acs06_topology_contract.dart';
import 'package:electra_mobile/application/elv5/acs/acs06_topology_contract_write.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_elv5_acs_contract_mutation_coordinator.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/elv5_f2_acs_sources.dart';
import '../support/elv5_f2_production_lifecycle.dart';

void main() {
  test(
    'F2 ACS-06 production Q6/Q7/Q8 door release paths, fire release failure, restart and freeze',
    () async {
      final lifecycle = Elv5F2ProductionLifecycle(
        process: Elv5ProcessCode.acs06,
        subjectKind: 'DOOR',
        subjectId: 'door-1',
      );
      late String fingerprint;
      await lifecycle.run(
        seed: (db) async {
          await seedF2AcsTopology(db);
          await replaceF2AcsAggregate(
            db,
            operation: 'REPLACE_DOOR_ROLE_ASSIGNMENTS',
            payload: f2AcsDoorPayload(),
            commandId: 'seed-door',
          );
          fingerprint = const Elv5CanonicalJsonV1().sha256(
            await loadF2AcsAggregate(
              db,
              operation: 'REPLACE_DOOR_ROLE_ASSIGNMENTS',
              subjectId: 'door-1',
            ),
          );
          await _replace(db, fingerprint, 2, null, false);
        },
        mutate: (db) => _replace(db, fingerprint, 3, 1, true),
        dependencyDomains: {
          'ACS_DOOR_CALCULATION',
          'ACS06_TOPOLOGY_CONTRACT',
          'COMPONENT_REFERENCE_BINDING',
        },
        initialOutput: (o) {
          expect(o['status'], 'pass');
          final causes = o['causes'] as Map;
          expect(causes, hasLength(5));
          expect(causes['powerFailure']['modeledOutcome'], 'released');
          expect(causes['fireRelease']['status'], 'pass');
        },
        changedOutput: (o) {
          expect(o['status'], 'fail');
          final cause = (o['causes'] as Map)['fireRelease'] as Map;
          expect(cause['status'], 'fail');
          expect(cause['failedRequirementId'], 'FIRE_RELEASE-PATH');
        },
        mutationAfterFreeze: (db) async {
          await expectLater(
            _replace(db, fingerprint, 5, 2, false),
            throwsA(
              predicate(
                (e) => e.toString().contains('ACS06_DESIGN_REVISION_READ_ONLY'),
              ),
            ),
          );
          await expectLater(
            replaceF2AcsAggregate(
              db,
              operation: 'REPLACE_DOOR_ROLE_ASSIGNMENTS',
              payload: f2AcsDoorPayload(),
              commandId: 'frozen-door',
            ),
            throwsA(
              predicate(
                (e) => e.toString().contains('ELV5_DESIGN_REVISION_READ_ONLY'),
              ),
            ),
          );
        },
      );
    },
  );
}

Future<void> _replace(
  AppDatabase db,
  String fingerprint,
  int revision,
  int? bindingRevision,
  bool broken,
) => DriftElv5AcsContractMutationCoordinator(
  db,
  originDeviceId: 'f2-acs',
  nowUtc: Elv5F2ProductionLifecycle.now,
).replaceAcs06(
  ReplaceAcs06TopologyContractCommand(
    projectId: 'p',
    designRevisionId: 'd',
    bindingId: 'release-topology',
    expectedBindingRevision: bindingRevision,
    expectedDesignRevision: revision,
    contract: _contract(fingerprint, broken: broken),
  ),
);
Acs06TopologyContract _contract(
  String aggregateFingerprint, {
  bool broken = false,
}) => Acs06TopologyContract(
  doorId: 'door-1',
  expectedDoorAggregateFingerprint: aggregateFingerprint,
  topologyProfile: Acs06TopologyProfileIdentity(
    profileCode: 'ACS-DOOR-SINGLE',
    editionId: 'v1',
    contentHash: f2AcsHash('a'),
  ),
  componentNodeIdByComponentId: const <String, String>{
    'reader': 'reader-node',
    'rte': 'rte-node',
    'fire': 'fire-node',
    'breakglass': 'breakglass-node',
    'contact': 'contact-node',
    'lock': 'lock-node',
  },
  edges: <Acs06TopologyEdgeContract>[
    Acs06TopologyEdgeContract(
      edgeId: 'reader-control',
      fromNodeId: 'reader-node',
      toNodeId: 'lock-node',
      kindCode: 'CONTROL',
    ),
    Acs06TopologyEdgeContract(
      edgeId: 'rte-control',
      fromNodeId: 'rte-node',
      toNodeId: 'lock-node',
      kindCode: 'CONTROL',
    ),
    Acs06TopologyEdgeContract(
      edgeId: 'fire-release',
      fromNodeId: 'fire-node',
      toNodeId: 'lock-node',
      kindCode: broken ? 'CONTROL' : 'RELEASE',
    ),
    Acs06TopologyEdgeContract(
      edgeId: 'breakglass-release',
      fromNodeId: 'breakglass-node',
      toNodeId: 'lock-node',
      kindCode: 'RELEASE',
    ),
    Acs06TopologyEdgeContract(
      edgeId: 'contact-monitor',
      fromNodeId: 'contact-node',
      toNodeId: 'lock-node',
      kindCode: 'MONITOR',
    ),
    Acs06TopologyEdgeContract(
      edgeId: 'psu-feed',
      fromNodeId: 'psu-node',
      toNodeId: 'lock-node',
      kindCode: 'POWER_FEED',
    ),
  ],
  causeProfiles: <Acs06CauseProfileContract>[
    _cause('NORMAL_ACCESS', 'reader-node', 'CONTROL'),
    _cause('REQUEST_TO_EXIT', 'rte-node', 'CONTROL'),
    _cause('FIRE_RELEASE', 'fire-node', 'RELEASE'),
    _cause('EMERGENCY_BREAK_GLASS', 'breakglass-node', 'RELEASE'),
    Acs06CauseProfileContract(
      causeCode: 'POWER_FAILURE',
      requiredPaths: const <Acs06PathRequirementContract>[],
      outcomeWhenSatisfiedCode: 'UNLOCKED',
      requiresConductiveFeed: false,
      requiresSupervision: false,
    ),
  ],
);

Acs06CauseProfileContract _cause(String code, String source, String kind) =>
    Acs06CauseProfileContract(
      causeCode: code,
      requiredPaths: <Acs06PathRequirementContract>[
        Acs06PathRequirementContract(
          requirementId: '$code-PATH',
          fromNodeId: source,
          toNodeId: 'lock-node',
          allowedKindCodes: <String>[kind],
        ),
      ],
      outcomeWhenSatisfiedCode: 'UNLOCKED',
      requiresConductiveFeed: false,
      requiresSupervision: false,
    );
