import 'package:electra_mobile/application/elv5/fire/fa04_source_requirement_contract.dart';
import 'package:electra_mobile/application/elv5/fire/fa04_source_requirement_contract_write.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/drift_power_runtime_store.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_elv4_current_evidence_source.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_elv5_fire_contract_mutation_coordinator.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/elv5_f2_fire_sources.dart';
import '../support/elv5_f2_power_publication.dart';
import '../support/elv5_f2_production_lifecycle.dart';

void main() {
  test(
    'F2 FA-04 production Q6/Q7/Q8 ELV4 CURRENT replacement, restart and freeze',
    () async {
      final lifecycle = Elv5F2ProductionLifecycle(
        process: Elv5ProcessCode.fa04,
        subjectKind: 'POWER_SOURCE',
        subjectId: 'psu-1',
      );
      late String fingerprint;
      await lifecycle.run(
        seed: (db) async {
          await seedF2FireTopology(db);
          await seedF2FireComponent(db, 'psu-1');
          final demand = aggregatePowerDemand([
            PowerDemandContribution(
              originId: 'fire-source-load',
              componentId: 'panel-1',
              inputPortId: 'panel-1-in',
              stateCode: 'NORMAL',
              demand: DcConstantPowerDemand(PowerRational.integer(30)),
            ),
          ]);
          final source = buildPowerDemandEvidence(
            evaluationId: 'demand',
            revisionId: 'd',
            scenarioId: 'NORMAL',
            segmentId: 'S1',
            subjectKind: 'SOURCE_AGGREGATE',
            subjectId: 'psu-1',
            demand: demand,
          );
          await publishF2PowerEvidence(
            db,
            node: source.nodeKey,
            edition: 'demand',
            inputs: source.inputs,
            output: source.output,
            status: source.status,
          );
          fingerprint = await _capacity(db, 40, 'normal');
          await _replace(db, fingerprint, await lifecycle.revision(), null);
        },
        mutate: (db) async {
          // Invalidation must occur at the upstream writer, before the contract
          // is repinned. A downstream contract write cannot hide a missing bridge.
          final source = DriftElv4CurrentEvidenceSource(db);
          final previous =
              (await source.loadCurrent(
                projectId: 'p',
                designRevisionId: 'd',
                processCode: PowerProcessCode.pwr02,
              )).single;
          await db.customStatement(
            "CREATE TRIGGER reject_power_projection_invalidation BEFORE UPDATE ON discipline_evaluation_pointers BEGIN SELECT RAISE(ABORT, 'POWER_PROJECTION_INVALIDATION_FAULT'); END",
          );
          await expectLater(
            _capacity(db, 32, 'reduced'),
            throwsA(
              predicate(
                (e) => e.toString().contains(
                  'POWER_PROJECTION_INVALIDATION_FAULT',
                ),
              ),
            ),
          );
          await db.customStatement(
            'DROP TRIGGER reject_power_projection_invalidation',
          );
          expect(
            (await source.loadCurrent(
              projectId: 'p',
              designRevisionId: 'd',
              processCode: PowerProcessCode.pwr02,
            )).single.evaluationId,
            previous.evaluationId,
          );
          expect((await lifecycle.pointer()).read<int>('generation'), 1);
          fingerprint = await _capacity(db, 32, 'reduced');
          expect(
            (await lifecycle.pointer()).read<String>('freshness'),
            'STALE',
          );
          expect((await lifecycle.pointer()).read<int>('generation'), 2);
          await _replace(db, fingerprint, await lifecycle.revision(), 1);
        },
        dependencyDomains: {
          'FA04_SOURCE_REQUIREMENT_SET',
          'ELV4_PWR01_CURRENT',
          'ELV4_PWR02_CURRENT',
        },
        initialOutput: (o) {
          expect(o['status'], 'pass');
          expect(
            (o['powerCases'] as List).single['marginW'],
            Elv5Rational.integer(4).toMap(),
          );
        },
        changedOutput: (o) {
          expect(o['status'], 'fail');
          expect(
            (o['powerCases'] as List).single['marginW'],
            Elv5Rational.integer(-4).toMap(),
          );
        },
        mutationAfterFreeze: (db) async {
          await expectLater(
            _replace(db, fingerprint, 4, 2),
            throwsA(
              predicate(
                (e) => e.toString().contains('FA04_DESIGN_REVISION_READ_ONLY'),
              ),
            ),
          );
          await expectLater(
            _capacity(db, 40, 'frozen'),
            throwsA(
              predicate(
                (e) =>
                    e is PowerRuntimeStorageException &&
                    e.code == 'ELV4_REVISION_NOT_WORKING',
              ),
            ),
          );
        },
      );
    },
  );
}

Future<String> _capacity(AppDatabase db, int available, String edition) async {
  await replaceF2PowerDefinition(
    db,
    componentId: 'psu-1',
    edition: edition,
    definition: {'nameplateW': PowerRational.integer(available).toMap()},
    capability: PowerComponentCapability.source,
  );
  final input = PowerCapabilityDimension(
    dimension: PowerQuantityDimension.watt,
    demand: PowerRational.integer(30),
    nameplate: PowerRational.integer(available),
    reserveMultiplier: PowerRational.parseDecimal('1.2'),
    deratingFactor: PowerRational.one,
  );
  final result = evaluateSupplyCapability(input);
  final source = buildPowerCapabilityEvidence(
    evaluationId: edition,
    revisionId: 'd',
    scenarioId: 'NORMAL',
    segmentId: 'S1',
    subjectKind: 'CAPACITY_GROUP',
    subjectId: 'psu-1',
    input: input,
    assessment: result,
  );
  return publishF2PowerEvidence(
    db,
    node: source.nodeKey,
    edition: edition,
    inputs: source.inputs,
    output: source.output,
    status: source.status,
  );
}

Future<void> _replace(
  AppDatabase db,
  String fingerprint,
  int revision,
  int? bindingRevision,
) => DriftElv5FireContractMutationCoordinator(
  db,
  originDeviceId: 'f2-fire',
  nowUtc: Elv5F2ProductionLifecycle.now,
).replaceFa04(
  ReplaceFa04SourceRequirementContractCommand(
    projectId: 'p',
    designRevisionId: 'd',
    bindingId: 'requirement',
    expectedBindingRevision: bindingRevision,
    expectedDesignRevision: revision,
    contract: Fa04SourceRequirementContract(
      sourceId: 'psu-1',
      sourceDefinitionContentHash: sha256HexUtf8('fictional-psu'),
      contributors: [
        Fa04RequirementContributorRef(
          contributorId: 'fire',
          disciplineCode: 'FIRE',
          policyCode: 'FIRE-PSU',
          editionId: 'fixture-v1',
          contentHash: sha256HexUtf8('fire requirement 36W'),
        ),
      ],
      cases: [
        Fa04SourceCaseContract(
          caseId: 'normal-w',
          scenarioId: 'NORMAL',
          segmentId: 'S1',
          dimension: Fa04SourceDimension.watt,
          pwr01SubjectKind: 'SOURCE_AGGREGATE',
          pwr01SubjectId: 'psu-1',
          pwr02SubjectKind: 'CAPACITY_GROUP',
          pwr02SubjectId: 'psu-1',
          expectedPwr02InputFingerprint: fingerprint,
        ),
      ],
    ),
  ),
);
