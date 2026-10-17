import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:electra_mobile/application/elv5/fire/fa03_terminal_voltage_contract.dart';
import 'package:electra_mobile/application/elv5/fire/fa03_terminal_voltage_contract_write.dart';
import 'package:electra_mobile/application/elv5/wire/elv5_wire_command.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/drift_power_publication_runtime.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_elv5_calculation_runtime.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_fa03_terminal_voltage_contract_store.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'F2 FA-03 Q6 qualifies persisted contract plus real PWR-03 CURRENT through production runtime',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'electra-f2-fa03-production-',
      );
      final file = File('${directory.path}/qualification.sqlite');
      addTearDown(() async {
        if (directory.existsSync()) {
          await directory.delete(recursive: true);
        }
      });

      final db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);
      await _seed(db);

      final powerInput = _powerInput();
      final contractStore = DriftFa03TerminalVoltageContractStore(
        db,
        originDeviceId: 'f2-fa03-production',
        nowUtc: _now,
      );
      await contractStore.replace(
        ReplaceFa03TerminalVoltageContractCommand(
          projectId: 'p',
          designRevisionId: 'd',
          bindingId: 'fa03-contract',
          expectedBindingRevision: null,
          expectedDesignRevision: 1,
          contract: _contract(powerInput.inputFingerprint),
        ),
      );

      final powerRuntime = DriftPowerPublicationRuntime(
        db,
        originDeviceId: 'f2-fa03-power',
        now: _now,
      );
      await _publishPwr03(powerRuntime, powerInput);

      final runtime = DriftElv5CalculationRuntime.create(
        db,
        originDeviceId: 'f2-fa03-production',
        nowUtc: _now,
      );
      final result = await runtime.service.execute(_command());
      expect(result.replayed, isFalse);

      final pointer =
          await db
              .customSelect(
                'SELECT freshness, generation, evaluation_id '
                'FROM discipline_evaluation_pointers '
                'WHERE project_id = ? AND design_revision_id = ? '
                'AND logical_node_key_sha256 = ?',
                variables: <Variable>[
                  Variable.withString('p'),
                  Variable.withString('d'),
                  Variable.withString(_nodeSha()),
                ],
              )
              .getSingle();
      expect(pointer.read<String>('freshness'), 'CURRENT');
      expect(pointer.read<int>('generation'), 1);
      final evaluationId = pointer.read<String>('evaluation_id');

      final evaluation =
          await db
              .customSelect(
                'SELECT execution, completion, assessment, input_fingerprint, '
                'output_sha256 FROM discipline_evaluation_records '
                'WHERE project_id = ? AND evaluation_id = ?',
                variables: <Variable>[
                  Variable.withString('p'),
                  Variable.withString(evaluationId),
                ],
              )
              .getSingle();
      expect(evaluation.read<String>('execution'), 'SUCCEEDED');
      expect(evaluation.read<String>('completion'), 'COMPLETE');
      expect(evaluation.read<String>('assessment'), 'PASS');
      expect(evaluation.read<String>('input_fingerprint'), hasLength(64));
      expect(evaluation.read<String>('output_sha256'), hasLength(64));

      final dependencies =
          await db
              .customSelect(
                'SELECT dependency_key FROM discipline_dependency_index '
                'WHERE project_id = ? AND design_revision_id = ? '
                'AND logical_node_key_sha256 = ?',
                variables: <Variable>[
                  Variable.withString('p'),
                  Variable.withString('d'),
                  Variable.withString(_nodeSha()),
                ],
              )
              .get();
      final dependencyText = dependencies
          .map((row) => row.read<String>('dependency_key'))
          .join('\n');
      expect(dependencyText, contains('FA03_TERMINAL_VOLTAGE_CONTRACT'));
      expect(dependencyText, contains('ELV4_PWR03_CURRENT'));
    },
  );
}

Fa03TerminalVoltageContract _contract(String pwr03InputFingerprint) =>
    Fa03TerminalVoltageContract(
      circuitId: 'fire-circuit-1',
      model: Fa03ContractModel.radialDc,
      minimumTerminalVoltageV: Elv5Rational.integer(22),
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

Future<void> _publishPwr03(
  DriftPowerPublicationRuntime runtime,
  PowerConsumedInput input,
) async {
  final node = PowerNodeKeyV2(
    revisionId: 'd',
    scenarioId: 'NORMAL',
    scopeKind: PowerEvaluationScopeKind.segment,
    scopeId: 'segment-1',
    processCode: PowerProcessCode.pwr03,
    subjectKind: 'DC_DOMAIN',
    subjectId: 'domain-1',
  );
  final capture = await runtime.captureForCalculation(
    projectId: 'p',
    designRevisionId: 'd',
    targetNodeKey: node,
    captureInput: () async => input,
  );
  final evidence = PowerEvaluationEvidence(
    evaluationId: 'pwr03-fa03-normal',
    nodeKey: node,
    algorithmVersion: input.algorithmVersion,
    inputSchemaVersion: input.inputSchemaVersion,
    outputSchemaVersion: 'electra.elv5-fa03-pwr03-fixture-output.v1',
    numericPolicyVersion: input.numericPolicyVersion,
    inputFingerprint: input.inputFingerprint,
    status: PowerEvaluationStatus.pass,
    applicability: PowerEvaluationApplicability.applicable,
    inputs: <String, Object?>{'dependencyKeys': input.dependencyKeys},
    output: <String, Object?>{
      'physicalComplete': true,
      'terminals': <Object?>[
        <String, Object?>{
          'loadId': 'load-1',
          'minimumV': PowerRational.parseDecimal('23.50').toMap(),
          'maximumV': PowerRational.parseDecimal('24.00').toMap(),
        },
      ],
      'sections': const <Object?>[],
    },
    dependencies: const <PowerNodeKeyV2>[],
  );
  await runtime.publishGuarded(
    capture: capture,
    evidence: evidence,
    operationId: 'op-pwr03-fa03-normal',
    commandFingerprint: sha256HexUtf8('op-pwr03-fa03-normal'),
    recaptureInput: () async => input,
  );
}

PowerConsumedInput _powerInput() => PowerConsumedInput(
  algorithmVersion: 'fa03-f2-power-fixture-v1',
  inputSchemaVersion: 'electra.elv5-fa03-power-fixture-input.v1',
  numericPolicyVersion: powerNumericPolicyVersion,
  facts: <PowerConsumedFact>[
    PowerConsumedFact.present(
      key: PowerDependencyKey(
        projectId: 'p',
        revisionId: 'd',
        kind: PowerDependencyKind.definition,
        entityId: 'physical-membership-1',
        purpose: 'FA03_PHYSICAL_CLOSURE',
      ),
      valueSchema: 'electra.elv5-fa03-power-fixture-fact.v1',
      value: const <String, Object?>{
        'circuitId': 'fire-circuit-1',
        'domainId': 'domain-1',
      },
    ),
  ],
);

Elv5WireCommandEnvelope _command() => Elv5WireCommandEnvelope(
  operation: 'CALCULATE_DISCIPLINE_PROCESS',
  projectId: 'p',
  designRevisionId: 'd',
  commandId: 'fa03-production-q6',
  expectedDesignRowRevision: 2,
  expectedRows: const <String, int>{},
  reviewedImpactFingerprint: _hash('9'),
  payload: <String, Object?>{
    'scope': <String, Object?>{
      'kind': 'DESIGN',
      'scopeId': 'd',
      'scenarioKey': 'NONE',
    },
    'processCodes': <String>[Elv5ProcessCode.fa03.wireCode],
    'subjects': const <Object?>[
      <String, Object?>{'kind': 'FIRE_CIRCUIT', 'id': 'fire-circuit-1'},
    ],
    'expectedPointerGenerations': <String, Object?>{_nodeSha(): 0},
  },
);

String _nodeSha() => const Elv5CanonicalJsonV1().sha256(
  Elv5EngineeringNodeKeyV3(
    designRevisionId: 'd',
    scope: Elv5ScopeRef(
      kind: Elv5ScopeKind.design,
      scopeId: 'd',
      scenarioKey: 'NONE',
    ),
    processCode: Elv5ProcessCode.fa03,
    subject: Elv5SubjectRef(kind: 'FIRE_CIRCUIT', id: 'fire-circuit-1'),
  ).toCanonicalValue(),
);

Future<void> _seed(AppDatabase db) async {
  final now = DateTime.utc(2026, 10, 17, 11);
  await db
      .into(db.projects)
      .insert(
        ProjectsCompanion.insert(
          id: 'p',
          name: 'F2 FA-03 production fixture',
          measurementSystem: 'metric',
          defaultStructuralHeightMm: 3000,
          defaultFinishedCeilingHeightMm: 2700,
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'f2-fa03-production',
        ),
      );
  await db
      .into(db.projectDesignRevisions)
      .insert(
        ProjectDesignRevisionsCompanion.insert(
          id: 'd',
          projectId: 'p',
          code: 'R1',
          sequence: 1,
          state: 'WORKING',
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'f2-fa03-production',
        ),
      );
}

DateTime _now() => DateTime.utc(2026, 10, 17, 12);
String _hash(String char) => List<String>.filled(64, char).join();
