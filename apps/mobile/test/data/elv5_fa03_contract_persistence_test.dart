import 'package:drift/native.dart';
import 'package:electra_mobile/application/elv5/fire/fa03_terminal_voltage_contract.dart';
import 'package:electra_mobile/application/elv5/fire/fa03_terminal_voltage_contract_write.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_fa03_terminal_voltage_contract_store.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps FA-03 editions immutable and CAS-switches selector', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await _seed(db);
    final store = DriftFa03TerminalVoltageContractStore(
      db,
      originDeviceId: 'test',
      nowUtc: () => DateTime.utc(2026, 10, 17, 12),
    );

    await store.replace(
      ReplaceFa03TerminalVoltageContractCommand(
        projectId: 'p',
        designRevisionId: 'd',
        bindingId: 'fa03-binding-1',
        expectedBindingRevision: null,
        expectedDesignRevision: 1,
        contract: _contract(_hash('a'), minimumV: 22),
      ),
    );
    final first = await store.loadActiveForCircuit(
      projectId: 'p',
      designRevisionId: 'd',
      circuitId: 'fire-circuit-1',
    );
    expect(first, isNotNull);
    expect(first!.bindingRevision, 1);
    final firstRef = first.evidenceRef;

    await store.replace(
      ReplaceFa03TerminalVoltageContractCommand(
        projectId: 'p',
        designRevisionId: 'd',
        bindingId: 'fa03-binding-1',
        expectedBindingRevision: 1,
        expectedDesignRevision: 2,
        contract: _contract(_hash('b'), minimumV: 21),
      ),
    );
    final second = await store.loadActiveForCircuit(
      projectId: 'p',
      designRevisionId: 'd',
      circuitId: 'fire-circuit-1',
    );
    expect(second, isNotNull);
    expect(second!.bindingRevision, 2);
    expect(second.evidenceRef, isNot(firstRef));
    expect(second.contract.minimumTerminalVoltageV, Elv5Rational.integer(21));

    final evidence = await db
        .customSelect(
          "SELECT evidence_ref FROM elv_revision_aggregate_evidence_records "
          "WHERE aggregate_kind = 'FA03_TERMINAL_VOLTAGE_CONTRACT' ORDER BY evidence_ref",
        )
        .get();
    expect(evidence, hasLength(2));

    final revision = await db
        .customSelect(
          "SELECT revision FROM project_design_revisions WHERE id = 'd'",
        )
        .getSingle();
    expect(revision.read<int>('revision'), 3);
  });
}

Fa03TerminalVoltageContract _contract(
  String pwr03Input, {
  required int minimumV,
}) => Fa03TerminalVoltageContract(
  circuitId: 'fire-circuit-1',
  model: Fa03ContractModel.radialDc,
  minimumTerminalVoltageV: Elv5Rational.integer(minimumV),
  maximumTerminalVoltageV: Elv5Rational.integer(26),
  cases: <Fa03CaseContract>[
    Fa03CaseContract(
      caseId: 'alarm',
      scenarioId: 'FIRE_ALARM',
      segmentId: 'FIRE_SEGMENT',
      pwr03SubjectKind: 'DC_DOMAIN',
      pwr03SubjectId: 'fire-domain-1',
      expectedPwr03InputFingerprint: pwr03Input,
      terminalLoadIdByTerminalId: const <String, String>{
        'last-device': 'load-3',
      },
    ),
  ],
);

Future<void> _seed(AppDatabase db) async {
  await db.customStatement('PRAGMA foreign_keys = OFF');
  const now = '2026-10-17T00:00:00.000Z';
  await db.customStatement('''
INSERT INTO projects (
  id, name, measurement_system, default_structural_height_mm,
  default_finished_ceiling_height_mm, created_at, updated_at, origin_device_id
) VALUES ('p', 'Project', 'METRIC', 3000, 2700, '$now', '$now', 'test')
''');
  await db.customStatement('''
INSERT INTO project_design_revisions (
  id, project_id, code, sequence, state, revision,
  created_at, updated_at, origin_device_id
) VALUES ('d', 'p', 'R1', 1, 'WORKING', 1, '$now', '$now', 'test')
''');
}

String _hash(String char) => List<String>.filled(64, char).join();
