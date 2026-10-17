import 'package:electra_mobile/application/elv5/fire/elv5_fire_mutation_service.dart';
import 'package:electra_mobile/application/elv5/fire/fa06_notification_contract.dart';
import 'package:electra_mobile/application/elv5/fire/fa06_notification_contract_write.dart';
import 'package:electra_mobile/application/elv5/wire/elv5_wire_command.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_elv5_fire_contract_mutation_coordinator.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_elv5_fire_write_unit_of_work.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/elv4_power_qualification_builder.dart';
import '../support/elv5_f2_fire_sources.dart';
import '../support/elv5_f2_power_publication.dart';
import '../support/elv5_f2_production_lifecycle.dart';

void main() {
  test(
    'F2 FA-06 production Q6/Q7/Q8 active and startup PWR01/PWR03, policy rollback, restart and freeze',
    () async {
      final lifecycle = Elv5F2ProductionLifecycle(
        process: Elv5ProcessCode.fa06,
        subjectKind: 'FIRE_NOTIFICATION_CIRCUIT',
        subjectId: 'nac-1',
      );
      await lifecycle.run(
        seed: (db) async {
          await seedF2FireTopology(db, notificationDevices: true);
          final builder = Elv4QualificationBuilder(
            db,
            projectId: 'p',
            revisionId: 'd',
            instant: Elv5F2ProductionLifecycle.now(),
          );
          await builder.topology.savePort(
            'p',
            builder.powerPort(
              'panel-1',
              'NAC-OUT',
              direction: PortDirection.output,
            ),
          );
          for (final id in ['d1', 'd2', 'd3']) {
            await builder.topology.savePort(
              'p',
              builder.powerPort(id, 'DC-IN'),
            );
          }
          await _circuit(db, 'notification-membership');
          await _replace(db, 2, null, '0.5');
          for (final e
              in {'NAC_ACTIVE': '0.1', 'NAC_STARTUP': '0.15'}.entries) {
            final demand = aggregatePowerDemand([
              for (final id in ['d1', 'd2', 'd3'])
                PowerDemandContribution(
                  originId: id,
                  componentId: id,
                  inputPortId: '$id-DC-IN',
                  stateCode: e.key == 'NAC_ACTIVE' ? 'ALARM' : 'STARTUP',
                  demand: DcConstantCurrentDemand(
                    PowerRational.parseDecimal(e.value),
                  ),
                ),
            ]);
            final evidence = buildPowerDemandEvidence(
              evaluationId: 'notification-${e.key}',
              revisionId: 'd',
              scenarioId: 'FIRE_ALARM',
              segmentId: e.key,
              subjectKind: 'NOTIFICATION_OUTPUT',
              subjectId: 'nac-1',
              demand: demand,
            );
            await publishF2PowerEvidence(
              db,
              node: evidence.nodeKey,
              edition: 'normal',
              inputs: evidence.inputs,
              output: evidence.output,
              status: evidence.status,
            );
            // Solve a real exact DC star; no independent expected voltages are
            // supplied to the upstream output. Physical refs remain fixture facts.
            final tree = solveDcConstantCurrentTree(
              DcTreeInput(
                sourceNodeId: 'source',
                sourceVoltage: PowerVoltageEnvelope(
                  currentKind: PowerCurrentKind.dc,
                  minV: _r('23'),
                  nominalV: _r('23.2'),
                  maxV: _r('23.4'),
                ),
                sections: [
                  for (final id in ['d1', 'd2', 'd3'])
                    DcSection.loopTotal(
                      sectionId: 'section-$id',
                      parentNodeId: 'source',
                      childNodeId: id,
                      loopResistanceOhm: _r('1'),
                      currentRatingA: _r('1'),
                      evidenceRef: 'fixture-section-$id',
                    ),
                ],
                loads: [
                  for (final id in ['d1', 'd2', 'd3'])
                    DcConstantCurrentLoad(
                      loadId: id,
                      nodeId: id,
                      currentA: _r(e.value),
                      allowedMinV: _r('22'),
                      allowedMaxV: _r('26'),
                    ),
                ],
              ),
            );
            await publishF2PowerEvidence(
              db,
              node: PowerNodeKeyV2(
                revisionId: 'd',
                scenarioId: 'FIRE_ALARM',
                scopeKind: PowerEvaluationScopeKind.segment,
                scopeId: e.key,
                processCode: PowerProcessCode.pwr03,
                subjectKind: 'DC_DOMAIN',
                subjectId: 'nac-domain-1',
              ),
              edition: 'normal',
              inputs: {
                'model': 'CONSTANT_CURRENT_TREE',
                'source': 'source',
                'currentA': _r(e.value).toMap(),
              },
              output: {
                'physicalComplete': true,
                'terminals': [
                  for (final t in tree.terminals)
                    {
                      'loadId': t.loadId,
                      'minimumV': t.minimumV.toMap(),
                      'nominalV': t.nominalV.toMap(),
                      'maximumV': t.maximumV.toMap(),
                    },
                ],
                'sections': [
                  for (final s in tree.sections) {'sectionId': s.sectionId},
                ],
              },
              status: tree.status,
            );
          }
        },
        mutate: (db) async {
          await db.customStatement(
            "CREATE TRIGGER reject_fa06_invalidation BEFORE UPDATE ON discipline_evaluation_pointers BEGIN SELECT RAISE(ABORT, 'FA06_INVALIDATION_FAULT'); END",
          );
          await expectLater(
            _replace(db, 3, 1, '0.4'),
            throwsA(
              predicate(
                (e) => e.toString().contains('FA06_INVALIDATION_FAULT'),
              ),
            ),
          );
          await db.customStatement('DROP TRIGGER reject_fa06_invalidation');
          expect(await lifecycle.revision(), 3);
          expect(
            (await lifecycle.pointer()).read<String>('freshness'),
            'CURRENT',
          );
          await _replace(db, 3, 1, '0.4');
        },
        dependencyDomains: {
          'FIRE_NOTIFICATION_CIRCUIT',
          'COMPONENT_REFERENCE_BINDING',
          'FA06_NOTIFICATION_CONTRACT',
          'ELV4_PWR01_CURRENT',
          'ELV4_PWR03_CURRENT',
        },
        initialOutput: (o) => _check(o, 'pass', '0.05'),
        changedOutput: (o) => _check(o, 'fail', '-0.05'),
        mutationAfterFreeze: (db) async {
          await expectLater(
            _replace(db, 5, 2, '0.5'),
            throwsA(
              predicate(
                (e) => e.toString().contains('FA06_DESIGN_REVISION_READ_ONLY'),
              ),
            ),
          );
          await expectLater(
            _circuit(db, 'frozen-membership'),
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

PowerRational _r(String v) => PowerRational.parseDecimal(v);
void _check(Map<String, dynamic> o, String status, String margin) {
  expect(o['status'], status);
  expect(o['activeDeviceCount'], 3);
  expect(o['deviceCountMargin'], 1);
  expect(o['acousticCoverageAssessed'], false);
  final cases = o['cases'] as Map;
  expect(cases.keys, containsAll(['activeNotification', 'startupInrush']));
  expect(
    cases['startupInrush']['currentMarginA'],
    Elv5Rational.parseDecimal(margin).toMap(),
  );
  expect(
    cases['startupInrush']['terminalVoltageLowerV'],
    Elv5Rational.parseDecimal('22.85').toMap(),
  );
  expect(
    cases['activeNotification']['terminalVoltageUpperV'],
    Elv5Rational.parseDecimal('23.3').toMap(),
  );
}

Future<void> _replace(
  AppDatabase db,
  int revision,
  int? bindingRevision,
  String limit,
) => DriftElv5FireContractMutationCoordinator(
  db,
  originDeviceId: 'f2-fire',
  nowUtc: Elv5F2ProductionLifecycle.now,
).replaceFa06(
  ReplaceFa06NotificationContractCommand(
    projectId: 'p',
    designRevisionId: 'd',
    bindingId: 'notification',
    expectedBindingRevision: bindingRevision,
    expectedDesignRevision: revision,
    contract: Fa06NotificationContract(
      circuitId: 'nac-1',
      deviceLimit: 4,
      outputCurrentLimitA: Elv5Rational.parseDecimal(limit),
      minimumTerminalVoltageV: Elv5Rational.integer(22),
      maximumTerminalVoltageV: Elv5Rational.integer(26),
      cases: [
        for (final e
            in {
              Fa06ContractCase.activeNotification: 'NAC_ACTIVE',
              Fa06ContractCase.startupInrush: 'NAC_STARTUP',
            }.entries)
          Fa06CaseContract(
            operatingCase: e.key,
            stateCode:
                e.key == Fa06ContractCase.activeNotification
                    ? 'ALARM'
                    : 'STARTUP',
            scenarioId: 'FIRE_ALARM',
            segmentId: e.value,
            pwr01SubjectKind: 'NOTIFICATION_OUTPUT',
            pwr01SubjectId: 'nac-1',
            pwr03SubjectKind: 'DC_DOMAIN',
            pwr03SubjectId: 'nac-domain-1',
          ),
      ],
      terminalLoadIdByDeviceId: const {'d1': 'd1', 'd2': 'd2', 'd3': 'd3'},
      supervision: Fa06SupervisionContract(
        required: false,
        modelSupported: false,
      ),
    ),
  ),
);
Future<void> _circuit(AppDatabase db, String commandId) async {
  final service = Elv5FireMutationService(
    unitOfWork: DriftElv5FireWriteUnitOfWork(db, originDeviceId: 'f2-fire'),
    originDeviceId: 'f2-fire',
    now: Elv5F2ProductionLifecycle.now,
  );
  final payload = <String, Object?>{
    'circuitId': 'nac-1',
    'outputRef': {'componentId': 'panel-1', 'portId': 'panel-1-NAC-OUT'},
    'policyRef': {
      'policyCode': 'FIRE-NAC',
      'editionId': 'fixture-v1',
      'contentHash': sha256HexUtf8('F2 explicit notification policy'),
    },
    'deviceAssignments': [
      for (final id in ['d1', 'd2', 'd3'])
        {
          'deviceId': id,
          'stateCurrentMa': {'ALARM': '100', 'STARTUP': '150'},
        },
    ],
  };
  final preview = await service.preview(
    projectId: 'p',
    designRevisionId: 'd',
    operation: 'REPLACE_NOTIFICATION_CIRCUIT_ASSIGNMENTS',
    payload: payload,
  );
  await service.execute(
    Elv5WireCommandEnvelope(
      operation: 'REPLACE_NOTIFICATION_CIRCUIT_ASSIGNMENTS',
      projectId: 'p',
      designRevisionId: 'd',
      commandId: commandId,
      expectedDesignRowRevision: preview.designRowRevision,
      expectedRows: preview.expectedRows,
      reviewedImpactFingerprint: preview.reviewedImpactFingerprint,
      payload: payload,
    ),
  );
}
