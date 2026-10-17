import 'package:drift/native.dart';
import 'package:electra_mobile/application/elv5/calculation/elv5_calculation_runtime.dart';
import 'package:electra_mobile/application/elv5/calculation/elv5_calculation_service.dart';
import 'package:electra_mobile/application/elv5/commands/elv5_replacement_command_runner.dart';
import 'package:electra_mobile/application/elv5/persistence/elv5_runtime_persistence.dart';
import 'package:electra_mobile/application/elv5/wire/elv5_wire_command.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_elv5_calculation_write_unit_of_work.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/elv5_f2_qualification_harness.dart';

void main() {
  test(
    'F2 FA-03 Q6/Q7/Q8 qualifies publication CAS, restart and frozen replay',
    () async {
      const harness = Elv5F2QualificationHarness();
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _seed(db);

      final firstAdapter = _Fa03FixtureAdapter();
      final firstService = _service(db, firstAdapter);
      final command = _command(commandId: 'cmd-fa03-1', expectedGeneration: 0);

      final first = await firstService.execute(command);
      expect(first.replayed, isFalse);
      expect(firstAdapter.captureCount, 1);

      final uow = DriftElv5CalculationWriteUnitOfWork(
        db,
        originDeviceId: 'f2-fa03-q7',
      );
      final persistedPointers = await uow.run(
        (session) => session.pointers.loadPointersBulk(
          projectId: 'project-1',
          designRevisionId: 'rev-1',
          logicalNodeKeySha256s: <String>{_nodeSha()},
        ),
      );
      final published = persistedPointers[_nodeSha()]!;
      expect(published.freshness, Elv5PointerFreshness.current);
      expect(published.generation, 1);
      expect(published.evaluationId, isNotNull);
      expect(published.outputSha256, isNotNull);
      final committedSnapshot = _snapshot(published, first.logicalResultJson);

      // Q7: another writer that captured generation 0 cannot overwrite CURRENT.
      final competing = _command(
        commandId: 'cmd-fa03-2',
        expectedGeneration: 0,
      );
      await harness.expectQ7StaleWriter('FA-03', () async {
        await firstService.execute(competing);
      });

      // Freeze the exact historical revision after the successful publication.
      await db.customUpdate(
        "UPDATE project_design_revisions SET state = 'FROZEN', revision = revision + 1 "
        "WHERE project_id = 'project-1' AND id = 'rev-1'",
      );

      // Q8/restart: a fresh service over the same durable DB replays the historical
      // command before any recapture and therefore preserves the exact result.
      final restartedAdapter = _Fa03FixtureAdapter();
      final restartedService = _service(db, restartedAdapter);
      final replay = await restartedService.execute(command);
      expect(replay.replayed, isTrue);
      expect(replay.logicalResultJson, first.logicalResultJson);
      expect(restartedAdapter.captureCount, 0);
      harness.assertQ7Replay(
        'FA-03',
        committedSnapshot,
        _snapshot(published, replay.logicalResultJson),
      );
      harness.assertQ8Replay(
        'FA-03',
        committedSnapshot,
        _snapshot(published, replay.logicalResultJson),
      );

      // A new calculation on the frozen revision is forbidden even when it knows
      // the latest pointer generation. Historical replay and new mutation are kept
      // deliberately separate.
      await harness.expectQ8ReadOnly('FA-03', () async {
        await restartedService.execute(
          _command(
            commandId: 'cmd-fa03-after-freeze',
            expectedGeneration: 1,
            expectedDesignRowRevision: 2,
          ),
        );
      }, operation: 'new calculation');
    },
  );
}

Elv5F2PublicationSnapshot _snapshot(
  Elv5PersistedPointer pointer,
  String logicalResultJson,
) => Elv5F2PublicationSnapshot(
  generation: pointer.generation,
  evaluationId: pointer.evaluationId!,
  freshness:
      pointer.freshness == Elv5PointerFreshness.current ? 'CURRENT' : 'STALE',
  execution: 'SUCCEEDED',
  completion: 'COMPLETE',
  inputFingerprint: _hash('1'),
  logicalResultJson: logicalResultJson,
);

Elv5CalculationService _service(AppDatabase db, _Fa03FixtureAdapter adapter) =>
    Elv5CalculationService(
      registry: Elv5ProcessCalculationRegistry(<Elv5ProcessCalculationAdapter>[
        adapter,
      ]),
      publicationUnitOfWork: DriftElv5CalculationWriteUnitOfWork(
        db,
        originDeviceId: 'f2-fa03-q7',
      ),
      originDeviceId: 'f2-fa03-q7',
      now: () => DateTime.utc(2026, 10, 17, 12),
    );

Elv5WireCommandEnvelope _command({
  required String commandId,
  required int expectedGeneration,
  int expectedDesignRowRevision = 1,
}) => Elv5WireCommandEnvelope(
  operation: 'CALCULATE_DISCIPLINE_PROCESS',
  projectId: 'project-1',
  designRevisionId: 'rev-1',
  commandId: commandId,
  expectedDesignRowRevision: expectedDesignRowRevision,
  expectedRows: const <String, int>{},
  reviewedImpactFingerprint: _hash('9'),
  payload: <String, Object?>{
    'scope': <String, Object?>{
      'kind': 'DESIGN',
      'scopeId': 'rev-1',
      'scenarioKey': 'NONE',
    },
    'processCodes': <String>[Elv5ProcessCode.fa03.wireCode],
    'subjects': <Object?>[
      <String, Object?>{'kind': 'FIRE_CIRCUIT', 'id': 'fire-circuit-1'},
    ],
    'expectedPointerGenerations': <String, Object?>{
      _nodeSha(): expectedGeneration,
    },
  },
);

String _nodeSha() {
  final node = Elv5EngineeringNodeKeyV3(
    designRevisionId: 'rev-1',
    scope: Elv5ScopeRef(
      kind: Elv5ScopeKind.design,
      scopeId: 'rev-1',
      scenarioKey: 'NONE',
    ),
    processCode: Elv5ProcessCode.fa03,
    subject: Elv5SubjectRef(kind: 'FIRE_CIRCUIT', id: 'fire-circuit-1'),
  );
  return const Elv5CanonicalJsonV1().sha256(node.toCanonicalValue());
}

final class _Fa03FixtureAdapter implements Elv5ProcessCalculationAdapter {
  int captureCount = 0;

  @override
  Elv5ProcessCode get processCode => Elv5ProcessCode.fa03;

  @override
  Elv5WorkloadClass get workloadClass =>
      Elv5ProcessCatalog.require(processCode).baseWorkloadClass;

  @override
  Future<Elv5CapturedProcess> capture(Elv5CalculationRequest request) async {
    captureCount++;
    return Elv5CapturedProcess(
      request: request,
      opaqueInput: request,
      inputFingerprint: _hash('1'),
      captureRevision: request.designRevisionId == 'rev-1' ? 1 : 0,
    );
  }

  @override
  Future<Elv5ProcessEvaluationCandidate> execute(
    Elv5CapturedProcess input,
  ) async {
    final descriptor = Elv5ProcessCatalog.require(processCode);
    return Elv5ProcessEvaluationCandidate(
      nodeKey: input.request.nodeKey,
      algorithmVersion: descriptor.versions.algorithmVersion,
      inputSchemaVersion: descriptor.versions.inputSchemaVersion,
      outputSchemaVersion: descriptor.versions.outputSchemaVersion,
      numericBackendVersion: descriptor.versions.numericBackendVersion,
      canonicalEncoderVersion: Elv5RuntimeContract.canonicalEncoderVersion,
      inputFingerprint: input.inputFingerprint,
      policyFingerprint: _hash('2'),
      execution: Elv5Execution.succeeded,
      completion: Elv5Completion.complete,
      assessment: Elv5Assessment.pass,
      output: <String, Object?>{
        'schema': 'electra.elv5-fa03-output.v1',
        'status': 'pass',
      },
      evidence: <String, Object?>{
        'schema': 'electra.elv5-fa03-evidence.v1',
        'fixture': 'F2_Q6_Q7_Q8_PUBLICATION',
      },
      dependencies: const <Never>[],
      completedAtUtc: DateTime.utc(2026, 10, 17, 12),
    );
  }
}

Future<void> _seed(AppDatabase db) async {
  final now = DateTime.utc(2026, 10, 17, 11);
  await db
      .into(db.projects)
      .insert(
        ProjectsCompanion.insert(
          id: 'project-1',
          name: 'F2 FA-03 concurrency fixture',
          measurementSystem: 'metric',
          defaultStructuralHeightMm: 3000,
          defaultFinishedCeilingHeightMm: 2700,
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'f2-fa03-q7',
        ),
      );
  await db
      .into(db.projectDesignRevisions)
      .insert(
        ProjectDesignRevisionsCompanion.insert(
          id: 'rev-1',
          projectId: 'project-1',
          code: 'R1',
          sequence: 1,
          state: 'WORKING',
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'f2-fa03-q7',
        ),
      );
}

String _hash(String char) => List<String>.filled(64, char).join();
