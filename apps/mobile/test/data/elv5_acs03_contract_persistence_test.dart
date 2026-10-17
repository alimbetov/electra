import 'package:drift/native.dart';
import 'package:electra_mobile/application/elv5/acs/acs03_electrical_contract.dart';
import 'package:electra_mobile/application/elv5/acs/acs03_electrical_contract_write.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_acs03_electrical_contract_store.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'keeps ACS-03 contract editions immutable and CAS-switches selector',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _seed(db);
      final store = DriftAcs03ElectricalContractStore(
        db,
        originDeviceId: 'test',
        nowUtc: () => DateTime.utc(2026, 10, 17, 12),
      );

      await store.replace(
        ReplaceAcs03ElectricalContractCommand(
          projectId: 'p',
          designRevisionId: 'd',
          bindingId: 'acs03-binding-1',
          expectedBindingRevision: null,
          expectedDesignRevision: 1,
          contract: _contract(startupCurrent: '0.30'),
        ),
      );

      final first = await store.loadActiveForDoor(
        projectId: 'p',
        designRevisionId: 'd',
        doorId: 'door-1',
      );
      expect(first, isNotNull);
      expect(first!.bindingRevision, 1);
      expect(
        first.contract.events.last.lockCurrent.value,
        Elv5Rational.parseDecimal('0.30'),
      );
      final firstEvidenceRef = first.evidenceRef;

      await store.replace(
        ReplaceAcs03ElectricalContractCommand(
          projectId: 'p',
          designRevisionId: 'd',
          bindingId: 'acs03-binding-1',
          expectedBindingRevision: 1,
          expectedDesignRevision: 2,
          contract: _contract(startupCurrent: '0.35'),
        ),
      );

      final second = await store.loadActiveForDoor(
        projectId: 'p',
        designRevisionId: 'd',
        doorId: 'door-1',
      );
      expect(second, isNotNull);
      expect(second!.bindingRevision, 2);
      expect(second.evidenceRef, isNot(firstEvidenceRef));
      expect(
        second.contract.events.last.lockCurrent.value,
        Elv5Rational.parseDecimal('0.35'),
      );

      final evidenceRows =
          await db
              .customSelect(
                "SELECT evidence_ref, payload_sha256 FROM elv_revision_aggregate_evidence_records "
                "WHERE aggregate_kind = 'ACS03_ELECTRICAL_CONTRACT' ORDER BY evidence_ref",
              )
              .get();
      expect(evidenceRows, hasLength(2));
      expect(
        evidenceRows.map((row) => row.read<String>('evidence_ref')),
        contains(firstEvidenceRef),
      );

      final revision =
          await db
              .customSelect(
                "SELECT revision FROM project_design_revisions WHERE id = 'd'",
              )
              .getSingle();
      expect(revision.read<int>('revision'), 3);
    },
  );
}

Acs03ElectricalContract _contract({required String startupCurrent}) =>
    Acs03ElectricalContract(
      doorId: 'door-1',
      lockId: 'lock-1',
      conductiveFeedPathId: 'feed-path-1',
      controlPathId: 'control-path-1',
      minimumTerminalVoltage: Voltage(Elv5Rational.integer(22)),
      maximumTerminalVoltage: Voltage(Elv5Rational.integer(28)),
      events: <Acs03ElectricalEventContract>[
        _event('holding', Acs03StateCode.holding, '0.10'),
        _event('active', Acs03StateCode.activeRelease, '0.20'),
        _event('startup', Acs03StateCode.startupInrush, startupCurrent),
      ],
    );

Acs03ElectricalEventContract _event(
  String id,
  Acs03StateCode state,
  String current,
) => Acs03ElectricalEventContract(
  eventId: id,
  state: state,
  durationMicroseconds: BigInt.from(1000000),
  scenarioId: 'scenario-${state.name}',
  segmentId: 'segment-${state.name}',
  domainId: 'domain-1',
  lockLoadOriginId: 'lock-origin-1',
  sharedTrunkSectionId: 'trunk-1',
  lockCurrent: Current(Elv5Rational.parseDecimal(current)),
);

Future<void> _seed(AppDatabase db) async {
  await db.customStatement('PRAGMA foreign_keys = OFF');
  const now = '2026-10-17T00:00:00.000Z';
  await db.customStatement('''
INSERT INTO project_design_revisions (
  id, project_id, code, sequence, state, revision,
  created_at, updated_at, origin_device_id
) VALUES ('d', 'p', 'R1', 1, 'WORKING', 1, '$now', '$now', 'test')
''');
  await db.customStatement('''
INSERT INTO component_instances (
  id, definition_id, definition_version, room_id, host_surface_patch_id,
  local_xmm, local_ymm, revision, created_at, updated_at, origin_device_id
) VALUES ('lock-1', 'lock-def', 1, 'room-1', 'patch-1',
  0, 0, 1, '$now', '$now', 'test')
''');
  await db.customStatement('''
INSERT INTO door_calculation_bindings (
  project_id, design_revision_id, id, revision, created_at, updated_at,
  origin_device_id, door_assembly_id, topology_profile_ref_json, safety_mode
) VALUES ('p', 'd', 'door-binding-1', 1, '$now', '$now', 'test',
  'door-1', '{}', 'FAIL_SAFE')
''');
  await db.customStatement('''
INSERT INTO door_role_assignments (
  project_id, design_revision_id, binding_id, component_id, role_code, slot
) VALUES ('p', 'd', 'door-binding-1', 'lock-1', 'LOCK', 0)
''');
}
