import 'package:electra_mobile/application/elv5/acs/acs02_resource_contract.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_elv5_acs_contract_mutation_coordinator.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/elv5_f2_acs_sources.dart';
import '../support/elv5_f2_production_lifecycle.dart';

void main() {
  test(
    'F2 ACS-02 production Q6/Q7/Q8 unavailable assigned relay, restart and freeze',
    () async {
      final lifecycle = Elv5F2ProductionLifecycle(
        process: Elv5ProcessCode.acs02,
        subjectKind: 'CONTROLLER',
        subjectId: 'controller-1',
      );
      late Map<String, Object?> payload;
      await lifecycle.run(
        seed: (db) async {
          await seedF2AcsTopology(db);
          await replaceF2AcsAggregate(
            db,
            operation: 'REPLACE_CONTROLLER_RESOURCE_ASSIGNMENTS',
            payload: f2AcsControllerPayload(),
            commandId: 'seed-controller',
          );
          payload = await loadF2AcsAggregate(
            db,
            operation: 'REPLACE_CONTROLLER_RESOURCE_ASSIGNMENTS',
            subjectId: 'controller-1',
          );
          await _replace(db, payload, 2, null, false);
        },
        mutate: (db) => _replace(db, payload, 3, 1, true),
        dependencyDomains: {
          'ACS_CONTROLLER_RESOURCES',
          'ACS02_RESOURCE_CONTRACT',
        },
        initialOutput: (o) {
          expect(o['status'], 'pass');
          expect(o['conflictingAssignmentIds'], isEmpty);
          final relay = (o['pools'] as List).singleWhere(
            (p) => p['resourceKind'] == 'relay',
          );
          expect(relay['available'], 2);
          expect(relay['headroom'], 0);
        },
        changedOutput: (o) {
          expect(o['status'], 'fail');
          expect(o['conflictingAssignmentIds'], isNotEmpty);
          final relay = (o['pools'] as List).singleWhere(
            (p) => p['resourceKind'] == 'relay',
          );
          expect(relay['available'], 1);
          expect(relay['occupied'], 1);
        },
        mutationAfterFreeze: (db) async {
          await expectLater(
            _replace(db, payload, 5, 2, false),
            throwsA(
              predicate(
                (e) => e.toString().contains('ACS02_DESIGN_REVISION_READ_ONLY'),
              ),
            ),
          );
          await expectLater(
            replaceF2AcsAggregate(
              db,
              operation: 'REPLACE_CONTROLLER_RESOURCE_ASSIGNMENTS',
              payload: f2AcsControllerPayload(),
              commandId: 'frozen-controller',
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
  Map<String, Object?> payload,
  int revision,
  int? bindingRevision,
  bool unavailable,
) => DriftElv5AcsContractMutationCoordinator(
  db,
  originDeviceId: 'f2-acs',
  nowUtc: Elv5F2ProductionLifecycle.now,
).replaceAcs02(
  ReplaceAcs02ResourceContractCommand(
    projectId: 'p',
    designRevisionId: 'd',
    bindingId: 'resource-policy',
    expectedBindingRevision: bindingRevision,
    expectedDesignRevision: revision,
    contract: _contract(payload, unavailable: unavailable),
  ),
);
Acs02ResourceContract _contract(
  Map<String, Object?> payload, {
  String policyEdition = 'spare-v1',
  bool unavailable = false,
}) => Acs02ResourceContract(
  controllerId: 'controller-1',
  expectedControllerAggregateFingerprint: const Elv5CanonicalJsonV1().sha256(
    payload,
  ),
  reservePolicy: Acs02PolicyIdentity(
    policyCode: 'ACS-CONTROLLER-SPARE',
    editionId: policyEdition,
    contentHash: f2AcsHash('b'),
  ),
  unavailableResourceIds: [if (unavailable) 'relay-1'],
  resources: <Acs02ResourceContractItem>[
    for (final id in const ['reader-1', 'reader-2', 'reader-3', 'reader-4'])
      Acs02ResourceContractItem(
        resourceId: id,
        resourceKindCode: 'READER_CHANNEL',
      ),
    for (final id in const ['relay-1', 'relay-2'])
      Acs02ResourceContractItem(
        resourceId: id,
        resourceKindCode: 'RELAY_OUTPUT',
      ),
    for (final id in const ['input-1', 'input-2'])
      Acs02ResourceContractItem(
        resourceId: id,
        resourceKindCode: 'SUPERVISED_INPUT',
      ),
    Acs02ResourceContractItem(resourceId: 'other-1', resourceKindCode: 'OTHER'),
  ],
  spareRules: <Acs02SpareRuleContract>[
    Acs02SpareRuleContract(
      resourceKindCode: 'READER_CHANNEL',
      absoluteMinimum: 1,
      ratio: Elv5Rational.zero,
    ),
    Acs02SpareRuleContract(
      resourceKindCode: 'RELAY_OUTPUT',
      absoluteMinimum: 0,
      ratio: Elv5Rational.zero,
    ),
    Acs02SpareRuleContract(
      resourceKindCode: 'SUPERVISED_INPUT',
      absoluteMinimum: 1,
      ratio: Elv5Rational.zero,
    ),
    Acs02SpareRuleContract(
      resourceKindCode: 'OTHER',
      absoluteMinimum: 0,
      ratio: Elv5Rational.zero,
    ),
  ],
);
