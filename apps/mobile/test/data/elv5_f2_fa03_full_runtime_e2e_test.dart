import 'package:electra_mobile/application/elv5/fire/fa03_terminal_voltage_contract.dart';
import 'package:electra_mobile/application/elv5/fire/fa03_terminal_voltage_contract_write.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_elv5_fire_contract_mutation_coordinator.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/elv5_f2_fire_sources.dart';
import '../support/elv5_f2_power_publication.dart';
import '../support/elv5_f2_production_lifecycle.dart';

void main() {
  test(
    'F2 FA-03 production Q6/Q7/Q8 real PWR03 policy invalidation, independent CAS, restart and freeze',
    () async {
      final lifecycle = Elv5F2ProductionLifecycle(
        process: Elv5ProcessCode.fa03,
        subjectKind: 'FIRE_CIRCUIT',
        subjectId: 'fire-circuit-1',
      );
      late String fingerprint;
      await lifecycle.run(
        seed: (db) async {
          await seedF2FireTopology(db);
          fingerprint = await publishF2PowerEvidence(
            db,
            node: PowerNodeKeyV2(
              revisionId: 'd',
              scenarioId: 'NORMAL',
              scopeKind: PowerEvaluationScopeKind.segment,
              scopeId: 'segment-1',
              processCode: PowerProcessCode.pwr03,
              subjectKind: 'DC_DOMAIN',
              subjectId: 'domain-1',
            ),
            edition: 'normal',
            inputs: {'physicalMembership': 'fire-circuit-1/domain-1'},
            output: {
              'physicalComplete': true,
              'terminals': [
                {
                  'loadId': 'load-1',
                  'minimumV': PowerRational.parseDecimal('23.50').toMap(),
                  'maximumV': PowerRational.integer(24).toMap(),
                },
              ],
              'sections': const <Object?>[],
            },
            status: PowerEvaluationStatus.pass,
          );
          await _replace(db, fingerprint, 1, null, false);
        },
        mutate: (db) => _replace(db, fingerprint, 2, 1, true),
        dependencyDomains: {
          'FA03_TERMINAL_VOLTAGE_CONTRACT',
          'ELV4_PWR03_CURRENT',
        },
        initialOutput: (o) => _check(o, 'pass', '1.5'),
        changedOutput: (o) => _check(o, 'fail', '-0.5'),
        mutationAfterFreeze: (db) async {
          await expectLater(
            _replace(db, fingerprint, 4, 2, false),
            throwsA(
              predicate(
                (e) => e.toString().contains('FA03_DESIGN_REVISION_READ_ONLY'),
              ),
            ),
          );
        },
      );
    },
  );
}

void _check(Map<String, dynamic> o, String status, String margin) {
  expect(o['status'], status);
  final t = (o['terminals'] as List).single as Map;
  expect(t['lowMarginV'], Elv5Rational.parseDecimal(margin).toMap());
  expect(t['highMarginV'], Elv5Rational.integer(4).toMap());
}

Future<void> _replace(
  AppDatabase db,
  String fingerprint,
  int revision,
  int? bindingRevision,
  bool changed,
) => DriftElv5FireContractMutationCoordinator(
  db,
  originDeviceId: 'f2-fire',
  nowUtc: Elv5F2ProductionLifecycle.now,
).replaceFa03(
  ReplaceFa03TerminalVoltageContractCommand(
    projectId: 'p',
    designRevisionId: 'd',
    bindingId: 'fa03-policy',
    expectedBindingRevision: bindingRevision,
    expectedDesignRevision: revision,
    contract: _contract(fingerprint, changed),
  ),
);
Fa03TerminalVoltageContract _contract(
  String pwr03InputFingerprint,
  bool changed,
) => Fa03TerminalVoltageContract(
  circuitId: 'fire-circuit-1',
  model: Fa03ContractModel.radialDc,
  minimumTerminalVoltageV: Elv5Rational.integer(changed ? 24 : 22),
  maximumTerminalVoltageV: Elv5Rational.integer(28),
  cases: <Fa03CaseContract>[
    Fa03CaseContract(
      caseId: 'normal',
      scenarioId: 'NORMAL',
      segmentId: 'segment-1',
      pwr03SubjectKind: 'DC_DOMAIN',
      pwr03SubjectId: 'domain-1',
      expectedPwr03InputFingerprint: pwr03InputFingerprint,
      terminalLoadIdByTerminalId: const <String, String>{
        'terminal-1': 'load-1',
      },
    ),
  ],
);
