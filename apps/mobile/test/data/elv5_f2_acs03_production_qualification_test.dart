import 'dart:io';

import 'package:drift/native.dart';
import 'package:electra_mobile/application/elv5/acs/acs03_electrical_contract.dart';
import 'package:electra_mobile/application/elv5/acs/acs03_electrical_contract_write.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_acs03_electrical_contract_store.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'F2 ACS-03 Q6/Q7/Q8 qualifies durable contract CAS and frozen replay',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'electra-f2-acs03-',
      );
      final file = File('${directory.path}/qualification.sqlite');
      addTearDown(() async {
        if (directory.existsSync()) {
          await directory.delete(recursive: true);
        }
      });

      final firstDb = AppDatabase(NativeDatabase(file));
      await _seed(firstDb);
      final firstStore = _store(firstDb, 'writer-a');

      // Q6: persist the canonical ACS-03 electrical contract and advance the
      // design selector through the production immutable-evidence store.
      await firstStore.replace(
        ReplaceAcs03ElectricalContractCommand(
          projectId: 'p',
          designRevisionId: 'd',
          bindingId: 'acs03-binding-1',
          expectedBindingRevision: null,
          expectedDesignRevision: 1,
          contract: _contract(startupCurrent: '0.30'),
        ),
      );
      final first = await firstStore.loadActiveForDoor(
        projectId: 'p',
        designRevisionId: 'd',
        doorId: 'door-1',
      );
      expect(first, isNotNull);
      expect(first!.bindingRevision, 1);
      final firstEvidenceRef = first.evidenceRef;
      final firstContentHash = first.contentHash;
      await firstDb.close();

      // Q6/Q8 restart witness: a fresh database/runtime instance must recover
      // the exact immutable edition rather than recomputing or defaulting it.
      final restartedDb = AppDatabase(NativeDatabase(file));
      final restartedStore = _store(restartedDb, 'writer-restarted');
      final restarted = await restartedStore.loadActiveForDoor(
        projectId: 'p',
        designRevisionId: 'd',
        doorId: 'door-1',
      );
      expect(restarted, isNotNull);
      expect(restarted!.evidenceRef, firstEvidenceRef);
      expect(restarted.contentHash, firstContentHash);
      expect(restarted.bindingRevision, 1);
      expect(
        restarted.contract.events.last.lockCurrent.value,
        Elv5Rational.parseDecimal('0.30'),
      );

      // Q7: concurrent writers captured the same generation. Production CAS
      // permits exactly one selector transition and rejects the stale writer.
      final writerA = _store(restartedDb, 'writer-a');
      final writerB = _store(restartedDb, 'writer-b');
      final outcomes = await Future.wait<_WriteOutcome>([
        _attempt(
          writerA,
          ReplaceAcs03ElectricalContractCommand(
            projectId: 'p',
            designRevisionId: 'd',
            bindingId: 'acs03-binding-1',
            expectedBindingRevision: 1,
            expectedDesignRevision: 2,
            contract: _contract(startupCurrent: '0.35'),
          ),
        ),
        _attempt(
          writerB,
          ReplaceAcs03ElectricalContractCommand(
            projectId: 'p',
            designRevisionId: 'd',
            bindingId: 'acs03-binding-1',
            expectedBindingRevision: 1,
            expectedDesignRevision: 2,
            contract: _contract(startupCurrent: '0.40'),
          ),
        ),
      ]);
      expect(outcomes.where((value) => value.succeeded), hasLength(1));
      expect(outcomes.where((value) => !value.succeeded), hasLength(1));
      expect(
        outcomes.singleWhere((value) => !value.succeeded).error,
        isA<StateError>(),
      );

      final current = await restartedStore.loadActiveForDoor(
        projectId: 'p',
        designRevisionId: 'd',
        doorId: 'door-1',
      );
      expect(current, isNotNull);
      expect(current!.bindingRevision, 2);
      expect(current.evidenceRef, isNot(firstEvidenceRef));

      final evidenceCount = await restartedDb.customSelect(
        "SELECT COUNT(*) AS c FROM elv_revision_aggregate_evidence_records "
        "WHERE project_id = 'p' AND design_revision_id = 'd' "
        "AND aggregate_kind = 'ACS03_ELECTRICAL_CONTRACT' "
        "AND aggregate_id = 'door-1'",
      ).getSingle();
      expect(evidenceCount.read<int>('c'), 2);

      // Q8: freeze preserves the current edition as historical evidence and
      // rejects any subsequent mutation, including one carrying the latest CAS.
      await restartedDb.customUpdate(
        "UPDATE project_design_revisions SET state = 'FROZEN' "
        "WHERE project_id = 'p' AND id = 'd'",
      );
      final frozenEvidenceRef = current.evidenceRef;
      final frozenContentHash = current.contentHash;
      final frozenStartupCurrent = current.contract.events.last.lockCurrent.value;
      await restartedDb.close();

      final frozenDb = AppDatabase(NativeDatabase(file));
      addTearDown(frozenDb.close);
      final frozenStore = _store(frozenDb, 'writer-after-freeze');
      final frozen = await frozenStore.loadActiveForDoor(
        projectId: 'p',
        designRevisionId: 'd',
        doorId: 'door-1',
      );
      expect(frozen, isNotNull);
      expect(frozen!.evidenceRef, frozenEvidenceRef);
      expect(frozen.contentHash, frozenContentHash);
      expect(frozen.bindingRevision, 2);
      expect(
        frozen.contract.events.last.lockCurrent.value,
        frozenStartupCurrent,
      );

      await expectLater(
        frozenStore.replace(
          ReplaceAcs03ElectricalContractCommand(
            projectId: 'p',
            designRevisionId: 'd',
            bindingId: 'acs03-binding-1',
            expectedBindingRevision: 2,
            expectedDesignRevision: 3,
            contract: _contract(startupCurrent: '0.45'),
          ),
        ),
        throwsA(isA<StateError>()),
      );
    },
  );
}

DriftAcs03ElectricalContractStore _store(
  AppDatabase db,
  String originDeviceId,
) =>
    DriftAcs03ElectricalContractStore(
      db,
      originDeviceId: originDeviceId,
      nowUtc: () => DateTime.utc(2026, 10, 17, 12),
    );

Future<_WriteOutcome> _attempt(
  DriftAcs03ElectricalContractStore store,
  ReplaceAcs03ElectricalContractCommand command,
) async {
  try {
    await store.replace(command);
    return const _WriteOutcome.success();
  } catch (error) {
    return _WriteOutcome.failure(error);
  }
}

final class _WriteOutcome {
  const _WriteOutcome.success()
      : succeeded = true,
        error = null;

  const _WriteOutcome.failure(this.error) : succeeded = false;

  final bool succeeded;
  final Object? error;
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
) =>
    Acs03ElectricalEventContract(
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
) VALUES ('d', 'p', 'R1', 1, 'WORKING', 1, '$now', '$now', 'seed')
''');
  await db.customStatement('''
INSERT INTO component_instances (
  id, definition_id, definition_version, room_id, host_surface_patch_id,
  local_xmm, local_ymm, revision, created_at, updated_at, origin_device_id
) VALUES ('lock-1', 'lock-def', 1, 'room-1', 'patch-1',
  0, 0, 1, '$now', '$now', 'seed')
''');
  await db.customStatement('''
INSERT INTO door_calculation_bindings (
  project_id, design_revision_id, id, revision, created_at, updated_at,
  origin_device_id, door_assembly_id, topology_profile_ref_json, safety_mode
) VALUES ('p', 'd', 'door-binding-1', 1, '$now', '$now', 'seed',
  'door-1', '{}', 'FAIL_SAFE')
''');
  await db.customStatement('''
INSERT INTO door_role_assignments (
  project_id, design_revision_id, binding_id, component_id, role_code, slot
) VALUES ('p', 'd', 'door-binding-1', 'lock-1', 'LOCK', 0)
''');
}
