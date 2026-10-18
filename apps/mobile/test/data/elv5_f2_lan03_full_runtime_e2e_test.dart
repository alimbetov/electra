import 'package:electra_mobile/application/elv5/lan/lan03_poe_contract.dart';
import 'package:electra_mobile/application/power_mutation_command.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/drift_power_command_service.dart';
import 'package:electra_mobile/data/repositories/drift_power_runtime_store.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_elv5_lan_contract_mutation_coordinator.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/elv5_f2_lan_sources.dart';
import '../support/elv5_f2_power_publication.dart';
import '../support/elv5_f2_production_lifecycle.dart';

void main() {
  test(
    'F2 LAN-03 production Q6/Q7/Q8 global PWR06 closure rejects subset budgeting through restart and freeze',
    () async {
      final lifecycle = Elv5F2ProductionLifecycle(
        process: Elv5ProcessCode.lan03,
        subjectKind: 'PSE',
        subjectId: 'pse-1',
      );
      late Map<String, String> fingerprints;
      await lifecycle.run(
        seed: (db) async {
          await seedF2LanTopology(db);
          fingerprints = await _publish(db, 35, 'normal');
          await _replace(db, fingerprints, await lifecycle.revision(), null);
        },
        mutate: (db) async {
          fingerprints = await _publish(db, 27, 'reduced');
          expect(
            (await lifecycle.pointer()).read<String>('freshness'),
            'STALE',
          );
          expect((await lifecycle.pointer()).read<int>('generation'), 2);
          await _replace(db, fingerprints, await lifecycle.revision(), 1);
        },
        dependencyDomains: {
          'LAN03_POE_PROJECTION_CONTRACT',
          'ELV4_PWR06_CURRENT',
        },
        initialOutput: (o) => _check(o, 'pass', 5, 35),
        changedOutput: (o) => _check(o, 'fail', -3, 27),
        mutationAfterFreeze: (db) async {
          await expectLater(
            _replace(db, fingerprints, 7, 2),
            throwsA(
              predicate(
                (e) => e.toString().contains('LAN03_DESIGN_REVISION_READ_ONLY'),
              ),
            ),
          );
          await expectLater(
            _publish(db, 35, 'frozen'),
            throwsA(
              isA<PowerRuntimeStorageException>().having(
                (e) => e.code,
                'code',
                'ELV4_REVISION_NOT_WORKING',
              ),
            ),
          );
        },
      );
    },
  );
}

void _check(Map<String, dynamic> o, String status, int margin, int available) {
  expect(o['status'], status);
  expect(o['globalDemandW'], _r(30));
  expect(o['globalMarginW'], _r(margin));
  expect(o['availableCapabilityW'], _r(available));
  expect(o['lanContributionW'], _r(18));
}

Map<String, Object?> _r(int n) => PowerRational.integer(n).toMap();
List<Map<String, Object?>> _members() => [
  {'originId': 'lan-load', 'portId': 'pse-1-p1', 'reservedW': _r(18)},
  {'originId': 'cctv-load', 'portId': 'pse-1-p2', 'reservedW': _r(12)},
];
Future<Map<String, String>> _publish(
  AppDatabase db,
  int available,
  String edition,
) async {
  final revision = (await db
          .customSelect(
            "SELECT revision FROM project_design_revisions WHERE id = 'd'",
          )
          .getSingle())
      .read<int>('revision');
  await DriftPowerCommandService(
    db,
    originDeviceId: 'f2-lan',
    now: Elv5F2ProductionLifecycle.now,
  ).execute(
    BindPowerComponentCommand(
      operationId: 'pse-budget-$edition',
      projectId: 'p',
      designRevisionId: 'd',
      expectedRevision: revision,
      changedDependencies: [
        for (final id in ['lan-delivery', 'cctv-delivery'])
          PowerDependencyKey(
            projectId: 'p',
            revisionId: 'd',
            kind: PowerDependencyKind.definition,
            entityId: id,
            purpose: 'F2_EXPLICIT_PWR06_POWER_FIXTURE',
          ),
      ],
      bindingId: 'pse-source',
      binding: PowerComponentBinding(
        componentId: 'pse-1',
        capabilities: [PowerComponentCapability.poeSource],
        definitionRefs: [
          PowerDefinitionRef(
            catalogId: 'f2-poe',
            catalogVersion: edition,
            definitionKind: PowerDefinitionKind.component,
            definitionCode: 'PSE-BUDGET',
            definitionVersion: edition,
            definitionSchema: 'electra.f2-poe-budget.v1',
            contentSha256: sha256HexUtf8(
              canonicalEngineeringJsonV1({'availableW': _r(available)}),
            ),
            sourceRef: 'Fictional exact shared PSE vector',
          ),
        ],
      ),
    ),
  );
  final assessment = evaluateSupplyCapability(
    PowerCapabilityDimension(
      dimension: PowerQuantityDimension.watt,
      demand: PowerRational.integer(30),
      nameplate: PowerRational.integer(available),
      reserveMultiplier: PowerRational.one,
      deratingFactor: PowerRational.one,
    ),
  );
  final result = <String, String>{};
  for (final id in ['lan-delivery', 'cctv-delivery']) {
    result[id] = await publishF2PowerEvidence(
      db,
      node: PowerNodeKeyV2(
        revisionId: 'd',
        scenarioId: 'scenario-1',
        scopeKind: PowerEvaluationScopeKind.segment,
        scopeId: 'segment-1',
        processCode: PowerProcessCode.pwr06,
        subjectKind: 'POE_DELIVERY',
        subjectId: id,
      ),
      edition: edition,
      inputs: {'availableW': _r(available)},
      output: {
        'deliveryId': id,
        'groupId': 'pse-1',
        'groupReservedW': assessment.required.toMap(),
        'groupMarginW': assessment.margin.toMap(),
      },
      status:
          available >= 30
              ? PowerEvaluationStatus.pass
              : PowerEvaluationStatus.fail,
      additionalFacts: [
        PowerConsumedFact.present(
          key: PowerDependencyKey(
            projectId: 'p',
            revisionId: 'd',
            kind: PowerDependencyKind.groupMembership,
            entityId: 'pse-1',
            purpose: 'POE_MEMBERSHIP',
          ),
          valueSchema: 'electra.elv4.poe-membership.v1',
          value: _members(),
        ),
      ],
    );
  }
  return result;
}

Future<void> _replace(
  AppDatabase db,
  Map<String, String> fingerprints,
  int revision,
  int? bindingRevision,
) => DriftElv5LanContractMutationCoordinator(
  db,
  originDeviceId: 'f2-lan',
  nowUtc: Elv5F2ProductionLifecycle.now,
).replaceLan03(
  ReplaceLan03PoeProjectionContractCommand(
    projectId: 'p',
    designRevisionId: 'd',
    bindingId: 'poe-policy',
    expectedBindingRevision: bindingRevision,
    expectedDesignRevision: revision,
    contract: Lan03PoeProjectionContract(
      pseId: 'pse-1',
      scenarioId: 'scenario-1',
      segmentId: 'segment-1',
      expectedClosureFingerprint: lan03Pwr06ClosureFingerprint(
        pseId: 'pse-1',
        members: _members(),
      ),
      expectedInputFingerprintByDeliveryId: fingerprints,
      lanLoadIds: const ['lan-load'],
    ),
  ),
);
