import 'package:electra_mobile/application/elv5/fire/fa05_autonomy_contract.dart';
import 'package:electra_mobile/application/elv5/fire/fa05_autonomy_contract_write.dart';
import 'package:electra_mobile/data/database/app_database.dart';
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
    'F2 FA-05 production Q6/Q7/Q8 PWR04 consumed sequence and PWR01 provenance survive restart and freeze',
    () async {
      final lifecycle = Elv5F2ProductionLifecycle(
        process: Elv5ProcessCode.fa05,
        subjectKind: 'POWER_BANK',
        subjectId: 'bank-1',
      );
      late String fingerprint;
      await lifecycle.run(
        seed: (db) async {
          await seedF2FireTopology(db);
          final demand = aggregatePowerDemand([
            for (final e in {'acs-lock': '10', 'fire-loop': '9.2'}.entries)
              PowerDemandContribution(
                originId: e.key,
                componentId: e.key,
                inputPortId: '${e.key}-in',
                stateCode: 'STANDBY',
                demand: DcConstantPowerDemand(
                  PowerRational.parseDecimal(e.value),
                ),
              ),
          ]);
          final evidence = buildPowerDemandEvidence(
            evaluationId: 'source',
            revisionId: 'd',
            scenarioId: 'BACKUP',
            segmentId: 'standby',
            subjectKind: 'BACKUP_SEGMENT',
            subjectId: 'standby-demand',
            demand: demand,
          );
          await publishF2PowerEvidence(
            db,
            node: evidence.nodeKey,
            edition: 'demand',
            inputs: evidence.inputs,
            output: evidence.output,
            status: evidence.status,
          );
          fingerprint = await _battery(
            db,
            'normal',
            PowerRational.parseDecimal('0.8'),
          );
          await _replace(db, fingerprint, 1, null);
        },
        mutate: (db) async {
          fingerprint = await _battery(
            db,
            'degraded',
            PowerRational.parseDecimal('0.1'),
          );
          expect(
            (await lifecycle.pointer()).read<String>('freshness'),
            'STALE',
          );
          expect((await lifecycle.pointer()).read<int>('generation'), 2);
          await _replace(db, fingerprint, 2, 1);
        },
        dependencyDomains: {
          'FA05_AUTONOMY_CONTRACT',
          'ELV4_PWR01_CURRENT',
          'ELV4_PWR04_CURRENT',
        },
        initialOutput: (o) => _check(o, 'pass', '134.4', '115.2'),
        changedOutput: (o) => _check(o, 'fail', '16.8', '-2.4'),
        mutationAfterFreeze: (db) async {
          await expectLater(
            _replace(db, fingerprint, 4, 2),
            throwsA(
              predicate(
                (e) => e.toString().contains('FA05_DESIGN_REVISION_READ_ONLY'),
              ),
            ),
          );
        },
      );
    },
  );
}

void _check(
  Map<String, dynamic> o,
  String status,
  String available,
  String margin,
) {
  expect(o['status'], status);
  expect(
    o['globalRequiredEnergyWh'],
    Elv5Rational.parseDecimal('19.2').toMap(),
  );
  expect(o['availableEnergyWh'], Elv5Rational.parseDecimal(available).toMap());
  expect(o['energyMarginWh'], Elv5Rational.parseDecimal(margin).toMap());
  expect(
    o['fireContributionEnergyWh'],
    Elv5Rational.parseDecimal('9.2').toMap(),
  );
}

Future<String> _battery(
  AppDatabase db,
  String edition,
  PowerRational factor,
) async {
  final pwr01 =
      (await DriftElv4CurrentEvidenceSource(db).loadCurrent(
        projectId: 'p',
        designRevisionId: 'd',
        processCode: PowerProcessCode.pwr01,
        scenarioId: 'BACKUP',
        scopeId: 'standby',
      )).single;
  final sequence = BackupEnergySegment(
    segmentId: 'standby',
    durationSeconds: PowerRational.integer(3600),
    bankInputW: PowerRational.parseDecimal('19.2'),
  );
  final result = evaluateBatterySequence(
    segments: [sequence],
    extensionPolicy: PowerExtensionPolicy.none,
    availability: BatteryWhAvailabilityModel(
      modelVoltageV: PowerRational.integer(24),
      bankAh: PowerRational.integer(7),
      initialSocFraction: PowerRational.one,
      minimumSocFraction: PowerRational.zero,
      temperatureFactor: factor,
      agingFactor: PowerRational.one,
      rateFactor: PowerRational.one,
    ),
  );
  return publishF2PowerEvidence(
    db,
    node: PowerNodeKeyV2(
      revisionId: 'd',
      scenarioId: 'BACKUP',
      scopeKind: PowerEvaluationScopeKind.sequence,
      scopeId: 'BACKUP',
      processCode: PowerProcessCode.pwr04,
      subjectKind: 'BATTERY_BANK',
      subjectId: 'bank-1',
    ),
    edition: edition,
    inputs: {'sequenceId': 'sequence-1', 'bankId': 'bank-1'},
    output: {
      'requiredWh': result.requiredWh.toMap(),
      'availableWh': result.availableWh.toMap(),
      'marginWh': result.marginWh.toMap(),
      'sequenceDurationSeconds': result.sequenceDurationSeconds.toMap(),
      'estimatedAutonomySeconds': result.estimatedAutonomySeconds?.toMap(),
    },
    status: result.status,
    additionalFacts: [
      PowerConsumedFact.present(
        key: PowerDependencyKey(
          projectId: 'p',
          revisionId: 'd',
          kind: PowerDependencyKind.backupSequence,
          entityId: 'sequence-1',
          purpose: 'PROTECTED_SEQUENCE',
        ),
        valueSchema: 'electra.elv4.backup-sequence.v1',
        value: {
          'segments': [
            {
              'segmentId': 'standby',
              'durationSeconds': PowerRational.integer(3600).toMap(),
              'bankInputW': PowerRational.parseDecimal('19.2').toMap(),
            },
          ],
          'extensionPolicy': 'NONE',
        },
      ),
    ],
    evaluations: [
      PowerConsumedEvaluationRef(
        logicalNodeKey: pwr01.nodeKey.encode(),
        evaluationId: pwr01.evaluationId,
        inputFingerprint: pwr01.inputFingerprint,
      ),
    ],
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
).replaceFa05(
  ReplaceFa05AutonomyContractCommand(
    projectId: 'p',
    designRevisionId: 'd',
    bindingId: 'autonomy',
    expectedBindingRevision: bindingRevision,
    expectedDesignRevision: revision,
    contract: Fa05AutonomyContract(
      bankId: 'bank-1',
      scenarioId: 'BACKUP',
      sequenceId: 'sequence-1',
      expectedPwr04InputFingerprint: fingerprint,
      segments: [
        Fa05SequenceSegmentContract(
          segmentId: 'standby',
          durationMicroseconds: BigInt.from(3600000000),
        ),
      ],
      globalProtectedLoadIds: const {'acs-lock', 'fire-loop'},
      fireProtectedLoadIds: const {'fire-loop'},
    ),
  ),
);
