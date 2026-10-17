import 'dart:io';

import 'package:drift/native.dart';
import 'package:electra_mobile/application/elv5/environment/ampacity_section_contract.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_ampacity_section_contract_store.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'F2 AMPACITY_ROUTE_IZ Q6/Q7/Q8 qualifies durable CAS and frozen replay',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'electra-f2-ampacity-',
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

      // Q6: publish the initial immutable engineering basis through the real
      // Drift store and advance the design revision with CAS.
      await firstStore.replace(
        ReplaceElv5AmpacitySectionContractCommand(
          projectId: 'p',
          designRevisionId: 'd',
          expectedDesignRevision: 1,
          bindingId: 'ampacity-section',
          expectedBindingRevision: null,
          contract: _contract(factor: '0.90', seed: 'a'),
        ),
      );
      final first = await firstStore.loadActiveForSection(
        projectId: 'p',
        designRevisionId: 'd',
        routeSectionId: 'section-1',
      );
      expect(first, isNotNull);
      expect(first!.bindingRevision, 1);
      expect(
        first.contract.temperatureCorrection.factor,
        Elv5Rational.parseDecimal('0.90'),
      );
      final firstEvidenceRef = first.evidenceRef;
      final firstContentHash = first.contentHash;
      await firstDb.close();

      // Q6/Q8 restart witness: reopen the same durable SQLite file. The active
      // selector must reconstruct the exact immutable edition and hash.
      final restartedDb = AppDatabase(NativeDatabase(file));
      final restartedStore = _store(restartedDb, 'writer-restarted');
      final restarted = await restartedStore.loadActiveForSection(
        projectId: 'p',
        designRevisionId: 'd',
        routeSectionId: 'section-1',
      );
      expect(restarted, isNotNull);
      expect(restarted!.evidenceRef, firstEvidenceRef);
      expect(restarted.contentHash, firstContentHash);
      expect(restarted.bindingRevision, 1);

      // Q7: two writers race from the same design/binding generation. Exactly
      // one may advance the selector; the loser must fail closed via CAS.
      final writerA = _store(restartedDb, 'writer-a');
      final writerB = _store(restartedDb, 'writer-b');
      final outcomes = await Future.wait<_WriteOutcome>([
        _attempt(
          writerA,
          ReplaceElv5AmpacitySectionContractCommand(
            projectId: 'p',
            designRevisionId: 'd',
            expectedDesignRevision: 2,
            bindingId: 'ampacity-section',
            expectedBindingRevision: 1,
            contract: _contract(factor: '0.80', seed: 'b'),
          ),
        ),
        _attempt(
          writerB,
          ReplaceElv5AmpacitySectionContractCommand(
            projectId: 'p',
            designRevisionId: 'd',
            expectedDesignRevision: 2,
            bindingId: 'ampacity-section',
            expectedBindingRevision: 1,
            contract: _contract(factor: '0.70', seed: 'c'),
          ),
        ),
      ]);
      expect(outcomes.where((value) => value.succeeded), hasLength(1));
      expect(outcomes.where((value) => !value.succeeded), hasLength(1));
      expect(
        outcomes.singleWhere((value) => !value.succeeded).error,
        isA<StateError>(),
      );

      final current = await restartedStore.loadActiveForSection(
        projectId: 'p',
        designRevisionId: 'd',
        routeSectionId: 'section-1',
      );
      expect(current, isNotNull);
      expect(current!.bindingRevision, 2);
      expect(current.evidenceRef, isNot(firstEvidenceRef));

      final evidenceCount = await restartedDb.customSelect(
        "SELECT COUNT(*) AS c FROM elv_revision_aggregate_evidence_records "
        "WHERE project_id = 'p' AND design_revision_id = 'd' "
        "AND aggregate_kind = 'ELV5_AMPACITY_SECTION_CONTRACT' "
        "AND aggregate_id = 'section-1'",
      ).getSingle();
      expect(evidenceCount.read<int>('c'), 2);

      // Q8: freeze makes the historical selector read-only while preserving the
      // exact active edition for deterministic historical replay after restart.
      await restartedDb.customUpdate(
        "UPDATE project_design_revisions SET state = 'FROZEN' "
        "WHERE project_id = 'p' AND id = 'd'",
      );
      final frozenEvidenceRef = current.evidenceRef;
      final frozenContentHash = current.contentHash;
      await restartedDb.close();

      final frozenDb = AppDatabase(NativeDatabase(file));
      addTearDown(frozenDb.close);
      final frozenStore = _store(frozenDb, 'writer-after-freeze');
      final frozen = await frozenStore.loadActiveForSection(
        projectId: 'p',
        designRevisionId: 'd',
        routeSectionId: 'section-1',
      );
      expect(frozen, isNotNull);
      expect(frozen!.evidenceRef, frozenEvidenceRef);
      expect(frozen.contentHash, frozenContentHash);
      expect(frozen.bindingRevision, 2);

      await expectLater(
        frozenStore.replace(
          ReplaceElv5AmpacitySectionContractCommand(
            projectId: 'p',
            designRevisionId: 'd',
            expectedDesignRevision: 3,
            bindingId: 'ampacity-section',
            expectedBindingRevision: 2,
            contract: _contract(factor: '0.60', seed: 'd'),
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('ELV5_AMPACITY_DESIGN_REVISION_READ_ONLY'),
          ),
        ),
      );
    },
  );
}

DriftElv5AmpacitySectionContractStore _store(
  AppDatabase db,
  String originDeviceId,
) =>
    DriftElv5AmpacitySectionContractStore(
      db,
      originDeviceId: originDeviceId,
      nowUtc: () => DateTime.utc(2026, 10, 17, 12),
    );

Future<_WriteOutcome> _attempt(
  DriftElv5AmpacitySectionContractStore store,
  ReplaceElv5AmpacitySectionContractCommand command,
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

Future<void> _seed(AppDatabase db) async {
  await db.customStatement('PRAGMA foreign_keys = OFF');
  const now = '2026-10-17T00:00:00.000Z';
  await db.customStatement('''
INSERT INTO project_design_revisions (
  id, project_id, code, sequence, state, revision,
  created_at, updated_at, origin_device_id
) VALUES ('d', 'p', 'R1', 1, 'WORKING', 1, '$now', '$now', 'seed')
''');
}

Elv5AmpacitySectionContract _contract({
  required String factor,
  required String seed,
}) =>
    Elv5AmpacitySectionContract(
      routeSectionId: 'section-1',
      cableRunId: 'run-1',
      cableId: 'cable-1',
      expectedEnvironmentProfileId: 'ENV',
      expectedEnvironmentEditionId: 'env-$seed',
      expectedEnvironmentContentHash: _hash(seed),
      referenceRow: Elv5AmpacityReferenceRow(
        conductorCrossSectionMm2: Elv5Rational.parseDecimal('2.5'),
        conductorMaterialCode: 'CU',
        insulationSystemCode: 'PVC70',
        referenceAmbientTemperatureC: Elv5Rational.integer(30),
        installationMethodCode: 'B2',
        loadedConductors: 3,
        baseAllowableCurrentA: Elv5Rational.integer(30),
        evidenceRef: 'ROW:$seed',
        evidenceContentHash: _hash('r'),
      ),
      temperatureCorrection: Elv5AmpacityTemperatureCorrection(
        actualAmbientTemperatureC: Elv5Rational.integer(40),
        factor: Elv5Rational.parseDecimal(factor),
        evidenceRef: 'TEMP:$factor',
        evidenceContentHash: _hash('t'),
      ),
      groupingCorrection: Elv5AmpacityGroupingCorrection(
        groupedCableOrCircuitCount: 1,
        arrangementCode: 'SINGLE',
        factor: Elv5Rational.one,
        evidenceRef: 'GROUP:1',
        evidenceContentHash: _hash('g'),
      ),
    );

String _hash(String seed) {
  final char = seed.codeUnitAt(0).toRadixString(16).padLeft(2, '0')[0];
  return List<String>.filled(64, char).join();
}
