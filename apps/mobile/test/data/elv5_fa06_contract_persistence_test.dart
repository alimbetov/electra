import 'package:drift/native.dart';
import 'package:electra_mobile/application/elv5/fire/fa06_notification_contract.dart';
import 'package:electra_mobile/application/elv5/fire/fa06_notification_contract_write.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_fa06_notification_contract_store.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'keeps FA-06 notification editions immutable and CAS-switches selector',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _seed(db);
      final store = DriftFa06NotificationContractStore(
        db,
        originDeviceId: 'test',
        nowUtc: () => DateTime.utc(2026, 10, 17, 12),
      );

      await store.replace(
        ReplaceFa06NotificationContractCommand(
          projectId: 'p',
          designRevisionId: 'd',
          bindingId: 'fa06-binding-1',
          expectedBindingRevision: null,
          expectedDesignRevision: 1,
          contract: _contract(limitA: '0.5'),
        ),
      );
      final first = await store.loadActiveForCircuit(
        projectId: 'p',
        designRevisionId: 'd',
        circuitId: 'nac-1',
      );
      expect(first, isNotNull);
      expect(first!.bindingRevision, 1);
      final firstRef = first.evidenceRef;

      await store.replace(
        ReplaceFa06NotificationContractCommand(
          projectId: 'p',
          designRevisionId: 'd',
          bindingId: 'fa06-binding-1',
          expectedBindingRevision: 1,
          expectedDesignRevision: 2,
          contract: _contract(limitA: '0.6'),
        ),
      );
      final second = await store.loadActiveForCircuit(
        projectId: 'p',
        designRevisionId: 'd',
        circuitId: 'nac-1',
      );
      expect(second, isNotNull);
      expect(second!.bindingRevision, 2);
      expect(second.evidenceRef, isNot(firstRef));
      expect(
        second.contract.outputCurrentLimitA,
        Elv5Rational.parseDecimal('0.6'),
      );

      final evidence = await db
          .customSelect(
            "SELECT evidence_ref FROM elv_revision_aggregate_evidence_records "
            "WHERE aggregate_kind = 'FA06_NOTIFICATION_CONTRACT' ORDER BY evidence_ref",
          )
          .get();
      expect(evidence, hasLength(2));

      final revision = await db
          .customSelect(
            "SELECT revision FROM project_design_revisions WHERE id = 'd'",
          )
          .getSingle();
      expect(revision.read<int>('revision'), 3);
    },
  );
}

Fa06NotificationContract _contract({required String limitA}) =>
    Fa06NotificationContract(
      circuitId: 'nac-1',
      deviceLimit: 4,
      outputCurrentLimitA: Elv5Rational.parseDecimal(limitA),
      minimumTerminalVoltageV: Elv5Rational.integer(22),
      maximumTerminalVoltageV: Elv5Rational.integer(26),
      cases: <Fa06CaseContract>[
        Fa06CaseContract(
          operatingCase: Fa06ContractCase.activeNotification,
          stateCode: 'ALARM',
          scenarioId: 'FIRE_ALARM',
          segmentId: 'NAC_ACTIVE',
          pwr01SubjectKind: 'NOTIFICATION_OUTPUT',
          pwr01SubjectId: 'nac-1',
          pwr03SubjectKind: 'DC_DOMAIN',
          pwr03SubjectId: 'nac-domain-1',
        ),
      ],
      terminalLoadIdByDeviceId: const <String, String>{
        'horn-1': 'horn-1',
        'horn-2': 'horn-2',
        'horn-3': 'horn-3',
      },
      supervision: Fa06SupervisionContract(
        required: false,
        modelSupported: false,
      ),
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
