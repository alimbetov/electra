import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value, Variable;
import 'package:drift/native.dart';
import 'package:electra_mobile/application/elv5/lan/lan05_optical_section_evidence.dart';
import 'package:electra_mobile/application/elv5/wire/elv5_wire_command.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_elv5_calculation_runtime.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_elv5_lan_write_unit_of_work.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_lan05_optical_section_evidence_source.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/elv5_f2_qualification_harness.dart';

void main() {
  test(
    'F2 LAN-05 Q6/Q7/Q8 qualifies exact ELV3 length, optical evidence invalidation, restart and freeze',
    () async {
      const harness = Elv5F2QualificationHarness();
      final directory = await Directory.systemTemp.createTemp(
        'electra-f2-lan05-full-runtime-',
      );
      final file = File('${directory.path}/qualification.sqlite');
      addTearDown(() async {
        if (directory.existsSync()) {
          await directory.delete(recursive: true);
        }
      });

      var db = AppDatabase(NativeDatabase(file));
      await _seedProjectAndRealizedSection(db);
      await _persistLanFacts(db);

      var evidenceWriter = _evidenceWriter(db);
      await evidenceWriter.replace(
        ReplaceLan05OpticalSectionEvidenceCommand(
          projectId: 'p',
          designRevisionId: 'd',
          bindingId: 'composition-1',
          expectedBindingRevision: 1,
          expectedDesignRevision: 1,
          evidence: _sectionEvidence(
            forwardDbPerKm: '0.35',
            reverseDbPerKm: '0.25',
            edition: 'normal',
          ),
        ),
      );

      // Q6: production registry captures both persisted LAN aggregates, the
      // exact/conservative ELV3 realized length and typed attenuation evidence.
      var runtime = DriftElv5CalculationRuntime.create(
        db,
        originDeviceId: 'f2-lan05',
        nowUtc: _now,
      );
      final firstCommand = _calculationCommand(
        commandId: 'lan05-calc-1',
        expectedPointerGeneration: 0,
        expectedDesignRevision: 2,
      );
      final first = await runtime.service.execute(firstCommand);
      expect(first.replayed, isFalse);

      final firstPointer = await _pointer(db);
      expect(firstPointer.freshness, 'CURRENT');
      expect(firstPointer.generation, 1);
      expect(firstPointer.evaluationId, isNotNull);
      final firstEvaluation = await _evaluation(db, firstPointer.evaluationId!);
      expect(firstEvaluation.execution, 'SUCCEEDED');
      expect(firstEvaluation.completion, 'COMPLETE');
      expect(firstEvaluation.assessment, 'PASS');
      expect(firstEvaluation.inputFingerprint, hasLength(64));
      final firstSnapshot = _snapshot(
        firstPointer,
        firstEvaluation,
        first.logicalResultJson,
      );
      harness.assertQ6Initial('LAN-05', firstSnapshot);

      final dependencyRows =
          await db
              .customSelect(
                'SELECT dependency_key FROM discipline_dependency_index '
                'WHERE project_id = ? AND design_revision_id = ? '
                'AND logical_node_key_sha256 = ? ORDER BY dependency_key',
                variables: <Variable>[
                  Variable.withString('p'),
                  Variable.withString('d'),
                  Variable.withString(_nodeSha()),
                ],
              )
              .get();
      final dependencies =
          dependencyRows
              .map((row) => jsonDecode(row.read<String>('dependency_key')))
              .whereType<Map>()
              .map((value) => Map<String, Object?>.from(value))
              .toList();
      expect(
        dependencies.any(
          (value) => value['domain'] == 'ELV3_REALIZED_LINK_SECTION',
        ),
        isTrue,
      );
      expect(
        dependencies
            .where((value) => value['domain'] == 'LAN_OPTICAL_SECTION_EVIDENCE')
            .length,
        2,
      );

      // Q6 invalidation: replacing authoritative attenuation evidence must make
      // the already-published CURRENT result stale atomically. High loss then
      // forces a deterministic FAIL on recalculation rather than retaining PASS.
      await evidenceWriter.replace(
        ReplaceLan05OpticalSectionEvidenceCommand(
          projectId: 'p',
          designRevisionId: 'd',
          bindingId: 'composition-1',
          expectedBindingRevision: 2,
          expectedDesignRevision: 2,
          evidence: _sectionEvidence(
            forwardDbPerKm: '200',
            reverseDbPerKm: '200',
            edition: 'degraded',
          ),
        ),
      );
      final stale = await _pointer(db);
      expect(stale.freshness, 'STALE');
      expect(stale.generation, 2);
      expect(stale.evaluationId, firstPointer.evaluationId);

      final secondCommand = _calculationCommand(
        commandId: 'lan05-calc-2',
        expectedPointerGeneration: 2,
        expectedDesignRevision: 3,
      );
      final second = await runtime.service.execute(secondCommand);
      expect(second.replayed, isFalse);
      final secondPointer = await _pointer(db);
      expect(secondPointer.freshness, 'CURRENT');
      expect(secondPointer.generation, 3);
      expect(secondPointer.evaluationId, isNot(firstPointer.evaluationId));
      final secondEvaluation = await _evaluation(
        db,
        secondPointer.evaluationId!,
      );
      expect(secondEvaluation.execution, 'SUCCEEDED');
      expect(secondEvaluation.completion, 'COMPLETE');
      expect(secondEvaluation.assessment, 'FAIL');
      expect(
        secondEvaluation.inputFingerprint,
        isNot(firstEvaluation.inputFingerprint),
      );
      final secondSnapshot = _snapshot(
        secondPointer,
        secondEvaluation,
        second.logicalResultJson,
      );
      harness.assertQ6Republished('LAN-05', firstSnapshot, secondSnapshot);

      // Q7: reconstruct the complete production registry and evidence readers
      // from the durable SQLite file. Ledger replay must not republish.
      final secondLogicalResult = second.logicalResultJson;
      await db.close();
      db = AppDatabase(NativeDatabase(file));
      runtime = DriftElv5CalculationRuntime.create(
        db,
        originDeviceId: 'f2-lan05-restarted',
        nowUtc: _now,
      );
      evidenceWriter = _evidenceWriter(db);
      final replay = await runtime.service.execute(secondCommand);
      expect(replay.replayed, isTrue);
      expect(replay.logicalResultJson, secondLogicalResult);
      final restartedPointer = await _pointer(db);
      expect(restartedPointer.generation, 3);
      expect(restartedPointer.evaluationId, secondPointer.evaluationId);
      harness.assertQ7Replay(
        'LAN-05',
        secondSnapshot,
        _snapshot(restartedPointer, secondEvaluation, replay.logicalResultJson),
      );

      // Q7 stale writer: a client still holding generation 2 cannot overwrite
      // the generation-3 CURRENT pointer after restart.
      await harness.expectQ7StaleWriter('LAN-05', () async {
        await runtime.service.execute(
          _calculationCommand(
            commandId: 'lan05-stale-writer',
            expectedPointerGeneration: 2,
            expectedDesignRevision: 3,
          ),
        );
      });

      // Q8: historical result/command replay remains available after freeze,
      // while both new calculation and optical evidence mutation fail closed.
      await db.customUpdate(
        "UPDATE project_design_revisions SET state = 'FROZEN', revision = 4 "
        "WHERE project_id = 'p' AND id = 'd'",
      );
      final frozenReplay = await runtime.service.execute(secondCommand);
      expect(frozenReplay.replayed, isTrue);
      expect(frozenReplay.logicalResultJson, secondLogicalResult);
      final frozenReplayPointer = await _pointer(db);
      harness.assertQ8Replay(
        'LAN-05',
        secondSnapshot,
        _snapshot(
          frozenReplayPointer,
          secondEvaluation,
          frozenReplay.logicalResultJson,
        ),
      );

      await harness.expectQ8ReadOnly('LAN-05', () async {
        await runtime.service.execute(
          _calculationCommand(
            commandId: 'lan05-after-freeze',
            expectedPointerGeneration: 3,
            expectedDesignRevision: 4,
          ),
        );
      }, operation: 'new calculation');
      await expectLater(
        evidenceWriter.replace(
          ReplaceLan05OpticalSectionEvidenceCommand(
            projectId: 'p',
            designRevisionId: 'd',
            bindingId: 'composition-1',
            expectedBindingRevision: 3,
            expectedDesignRevision: 4,
            evidence: _sectionEvidence(
              forwardDbPerKm: '0.20',
              reverseDbPerKm: '0.20',
              edition: 'forbidden',
            ),
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.toString(),
            'message',
            contains('LAN05_DESIGN_REVISION_READ_ONLY'),
          ),
        ),
      );

      final frozenPointer = await _pointer(db);
      expect(frozenPointer.freshness, 'CURRENT');
      expect(frozenPointer.generation, 3);
      expect(frozenPointer.evaluationId, secondPointer.evaluationId);
      await db.close();
    },
  );
}

Elv5F2PublicationSnapshot _snapshot(
  _PointerRow pointer,
  _EvaluationRow evaluation,
  String logicalResultJson,
) => Elv5F2PublicationSnapshot(
  generation: pointer.generation,
  evaluationId: pointer.evaluationId!,
  freshness: pointer.freshness,
  execution: evaluation.execution,
  completion: evaluation.completion,
  inputFingerprint: evaluation.inputFingerprint,
  logicalResultJson: logicalResultJson,
);

DriftLan05OpticalSectionEvidenceWriter _evidenceWriter(AppDatabase db) =>
    DriftLan05OpticalSectionEvidenceWriter(
      db,
      originDeviceId: 'f2-lan05',
      nowUtc: _now,
    );

Lan05OpticalFiberEvidenceDocument _sectionEvidence({
  required String forwardDbPerKm,
  required String reverseDbPerKm,
  required String edition,
}) => Lan05OpticalFiberEvidenceDocument(
  realizedSectionId: 'traversal-1',
  attenuationProfiles: <Lan05OpticalAttenuationProfile>[
    Lan05OpticalAttenuationProfile(
      wavelengthNm: Elv5Rational.integer(1310),
      attenuationDbPerKm: Lan05LossInterval.exact(
        LossDb(Elv5Rational.parseDecimal(forwardDbPerKm)),
      ),
      evidenceRef: 'FIBER:$edition:1310',
    ),
    Lan05OpticalAttenuationProfile(
      wavelengthNm: Elv5Rational.integer(1550),
      attenuationDbPerKm: Lan05LossInterval.exact(
        LossDb(Elv5Rational.parseDecimal(reverseDbPerKm)),
      ),
      evidenceRef: 'FIBER:$edition:1550',
    ),
  ],
);

Future<void> _persistLanFacts(AppDatabase db) async {
  final uow = DriftElv5LanWriteUnitOfWork(db, originDeviceId: 'f2-lan05');
  await uow.run(
    (session) => session.lan.replace(
      projectId: 'p',
      designRevisionId: 'd',
      operation: 'REPLACE_LINK_COMPOSITION',
      subjectId: 'link-1',
      bindingId: 'composition-1',
      expectedRootRevision: null,
      payload: <String, Object?>{
        'linkId': 'link-1',
        'orderedSections': <Object?>[
          <String, Object?>{
            'ordinal': 0,
            'realizedSectionId': 'traversal-1',
            'classification': 'FIBER',
          },
        ],
        'policyBindingId': 'lan05-policy-1',
      },
      updatedAtUtc: _now(),
    ),
  );
  await uow.run(
    (session) => session.lan.replace(
      projectId: 'p',
      designRevisionId: 'd',
      operation: 'REPLACE_OPTICAL_LINK_ASSIGNMENTS',
      subjectId: 'link-1',
      bindingId: 'optical-1',
      expectedRootRevision: null,
      payload: <String, Object?>{
        'linkId': 'link-1',
        'forwardOptics': _optics(wavelengthNm: '1310'),
        'reverseOptics': _optics(wavelengthNm: '1550'),
        'connectorEvents': <Object?>[
          <String, Object?>{
            'eventId': 'connector-a',
            'lossMinDb': '0.20',
            'lossMaxDb': '0.40',
          },
          <String, Object?>{
            'eventId': 'connector-b',
            'lossMinDb': '0.20',
            'lossMaxDb': '0.40',
          },
        ],
        'spliceEvents': const <Object?>[],
      },
      updatedAtUtc: _now(),
    ),
  );
}

Map<String, Object?> _optics({required String wavelengthNm}) =>
    <String, Object?>{
      'wavelengthNm': wavelengthNm,
      'txMinDbm': '-3',
      'txMaxDbm': '-1',
      'receiverSensitivityDbm': '-20',
      'receiverOverloadDbm': '-1',
      'requiredSensitivityMarginDb': '3',
    };

Elv5WireCommandEnvelope _calculationCommand({
  required String commandId,
  required int expectedPointerGeneration,
  required int expectedDesignRevision,
}) => Elv5WireCommandEnvelope(
  operation: 'CALCULATE_DISCIPLINE_PROCESS',
  projectId: 'p',
  designRevisionId: 'd',
  commandId: commandId,
  expectedDesignRowRevision: expectedDesignRevision,
  expectedRows: const <String, int>{},
  reviewedImpactFingerprint: _hash('9'),
  payload: <String, Object?>{
    'scope': <String, Object?>{
      'kind': 'DESIGN',
      'scopeId': 'd',
      'scenarioKey': 'NONE',
    },
    'processCodes': <String>[Elv5ProcessCode.lan05.wireCode],
    'subjects': <Object?>[
      <String, Object?>{'kind': 'LINK', 'id': 'link-1'},
    ],
    'expectedPointerGenerations': <String, Object?>{
      _nodeSha(): expectedPointerGeneration,
    },
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
    processCode: Elv5ProcessCode.lan05,
    subject: Elv5SubjectRef(kind: 'LINK', id: 'link-1'),
  ).toCanonicalValue(),
);

Future<_PointerRow> _pointer(AppDatabase db) async {
  final row =
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
  return _PointerRow(
    freshness: row.read<String>('freshness'),
    generation: row.read<int>('generation'),
    evaluationId: row.readNullable<String>('evaluation_id'),
  );
}

Future<_EvaluationRow> _evaluation(AppDatabase db, String evaluationId) async {
  final row =
      await db
          .customSelect(
            'SELECT execution, completion, assessment, input_fingerprint '
            'FROM discipline_evaluation_records '
            'WHERE project_id = ? AND evaluation_id = ?',
            variables: <Variable>[
              Variable.withString('p'),
              Variable.withString(evaluationId),
            ],
          )
          .getSingle();
  return _EvaluationRow(
    execution: row.read<String>('execution'),
    completion: row.read<String>('completion'),
    assessment: row.read<String>('assessment'),
    inputFingerprint: row.read<String>('input_fingerprint'),
  );
}

final class _PointerRow {
  const _PointerRow({
    required this.freshness,
    required this.generation,
    required this.evaluationId,
  });

  final String freshness;
  final int generation;
  final String? evaluationId;
}

final class _EvaluationRow {
  const _EvaluationRow({
    required this.execution,
    required this.completion,
    required this.assessment,
    required this.inputFingerprint,
  });

  final String execution;
  final String completion;
  final String assessment;
  final String inputFingerprint;
}

Future<void> _seedProjectAndRealizedSection(AppDatabase db) async {
  final now = _now();
  await db
      .into(db.projects)
      .insert(
        ProjectsCompanion.insert(
          id: 'p',
          name: 'F2 LAN05 runtime qualification',
          measurementSystem: 'metric',
          defaultStructuralHeightMm: 3000,
          defaultFinishedCeilingHeightMm: 2700,
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'f2-lan05',
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
          revision: const Value(1),
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'f2-lan05',
        ),
      );

  await db.customStatement('PRAGMA foreign_keys = OFF');
  await db.customStatement(
    "INSERT INTO rooms (id,floor_id,name,room_type,room_category,width_mm,depth_mm,structural_height_mm_override,finished_ceiling_height_mm_override,revision,created_at,updated_at,deleted_at,origin_device_id) "
    "VALUES ('room-1','floor-x','Telecom room','technical','technical',4000,4000,NULL,NULL,1,'${now.toIso8601String()}','${now.toIso8601String()}',NULL,'f2-lan05')",
  );
  await db
      .into(db.cableRoutes)
      .insert(
        CableRoutesCompanion.insert(
          id: 'route-1',
          roomId: 'room-1',
          name: 'Fiber route',
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'f2-lan05',
        ),
      );
  await db
      .into(db.cableRouteNodes)
      .insert(
        CableRouteNodesCompanion.insert(
          id: 'node-a',
          routeId: 'route-1',
          sequence: 1,
          kind: 'POINT',
          patchId: 'patch-1',
          localXmm: 0,
          localYmm: 0,
          worldXmm: 0,
          worldYmm: 0,
          worldZmm: 0,
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'f2-lan05',
        ),
      );
  await db
      .into(db.cableRouteNodes)
      .insert(
        CableRouteNodesCompanion.insert(
          id: 'node-b',
          routeId: 'route-1',
          sequence: 2,
          kind: 'POINT',
          patchId: 'patch-1',
          localXmm: 100000,
          localYmm: 0,
          worldXmm: 100000,
          worldYmm: 0,
          worldZmm: 0,
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'f2-lan05',
        ),
      );
  await db
      .into(db.cableRouteSegments)
      .insert(
        CableRouteSegmentsCompanion.insert(
          id: 'segment-1',
          routeId: 'route-1',
          sequence: 1,
          fromNodeId: 'node-a',
          toNodeId: 'node-b',
          surfacePatchId: 'patch-1',
          layingMethod: 'TRAY',
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'f2-lan05',
        ),
      );
  await db
      .into(db.canonicalCableRuns)
      .insert(
        CanonicalCableRunsCompanion.insert(
          id: 'run-1',
          projectId: 'p',
          cableId: 'fiber-1',
          designRevisionId: 'd',
          lifecycleState: 'ACTIVE',
          reservePercent: const Value(0),
          terminationAllowanceMm: const Value(0),
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'f2-lan05',
        ),
      );
  await db
      .into(db.cableRunTraversals)
      .insert(
        CableRunTraversalsCompanion.insert(
          id: 'traversal-1',
          cableRunId: 'run-1',
          sequence: 1,
          routeSegmentId: 'segment-1',
          direction: 'FORWARD',
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'f2-lan05',
        ),
      );
  await db.customStatement('PRAGMA foreign_keys = ON');
}

DateTime _now() => DateTime.utc(2026, 10, 17, 14);
String _hash(String char) => List<String>.filled(64, char).join();
