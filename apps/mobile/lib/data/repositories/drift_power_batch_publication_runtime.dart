import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core.dart';

import '../database/app_database.dart';
import 'drift_power_publication_runtime.dart';
import 'drift_power_runtime_store.dart';

final class PowerBatchTargetPlan {
  PowerBatchTargetPlan({
    required this.nodeKey,
    required String evaluationId,
    required this.consumedInput,
  }) : evaluationId = _text(evaluationId, 'evaluationId');

  final PowerNodeKeyV2 nodeKey;
  final String evaluationId;
  final PowerConsumedInput consumedInput;
}

final class PowerBatchTargetCapture {
  const PowerBatchTargetCapture({
    required this.plan,
    required this.pointerState,
    required this.pointerGeneration,
    required this.pointerEvaluationId,
    required this.externalConsumedPointers,
  });

  final PowerBatchTargetPlan plan;
  final PowerPointerState? pointerState;
  final int? pointerGeneration;
  final String? pointerEvaluationId;
  final List<PowerConsumedPointerCapture> externalConsumedPointers;
}

final class PowerBatchCalculationCapture {
  const PowerBatchCalculationCapture({
    required this.projectId,
    required this.designRevisionId,
    required this.revisionToken,
    required this.targets,
  });

  final String projectId;
  final String designRevisionId;
  final int revisionToken;
  final List<PowerBatchTargetCapture> targets;
}

final class PowerBatchPublishedItem {
  const PowerBatchPublishedItem({
    required this.nodeKey,
    required this.evaluationId,
    required this.generation,
    required this.storedEvidenceSha256,
  });

  final PowerNodeKeyV2 nodeKey;
  final String evaluationId;
  final int generation;
  final String storedEvidenceSha256;

  Map<String, Object?> toMap() => {
        'logicalNodeKey': nodeKey.toTuple(),
        'evaluationId': evaluationId,
        'generation': generation,
        'storedEvidenceSha256': storedEvidenceSha256,
      };
}

final class PowerBatchPublicationReceipt {
  const PowerBatchPublicationReceipt({
    required this.items,
    required this.replayed,
  });

  final List<PowerBatchPublishedItem> items;
  final bool replayed;

  Map<String, Object?> toMap() => {
        'schema': 'electra.elv4-batch-publication-receipt.v1',
        'items': items.map((value) => value.toMap()).toList(growable: false),
      };

  factory PowerBatchPublicationReceipt.fromMap(
    Map<String, Object?> map, {
    required bool replayed,
  }) {
    final values = map['items'];
    if (values is! List) {
      throw const FormatException('Batch publication receipt lacks items.');
    }
    return PowerBatchPublicationReceipt(
      items: List.unmodifiable(
        values.map((value) {
          final item = (value as Map).cast<String, Object?>();
          final keyValue = item['logicalNodeKey'];
          if (keyValue is! List) {
            throw const FormatException('Batch receipt item lacks node key.');
          }
          return PowerBatchPublishedItem(
            nodeKey: PowerNodeKeyV2.decode(
              canonicalEngineeringJsonV1(keyValue),
            ),
            evaluationId: item['evaluationId']! as String,
            generation: item['generation']! as int,
            storedEvidenceSha256: item['storedEvidenceSha256']! as String,
          );
        }),
      ),
      replayed: replayed,
    );
  }
}

/// Atomic multi-node P7 publication for process chains such as
/// PWR-01 -> PWR-02. Internal batch dependencies reference planned immutable
/// evaluation ids/fingerprints and become visible only when the whole batch
/// commits.
final class DriftPowerBatchPublicationRuntime {
  DriftPowerBatchPublicationRuntime(
    this.database, {
    required this.originDeviceId,
    DateTime Function()? now,
  })  : now = now ?? DateTime.now,
        schemaRuntime = DriftPowerPublicationRuntime(
          database,
          originDeviceId: originDeviceId,
          now: now,
        );

  final AppDatabase database;
  final String originDeviceId;
  final DateTime Function() now;
  final DriftPowerPublicationRuntime schemaRuntime;

  Future<PowerBatchCalculationCapture> captureBatch({
    required String projectId,
    required String designRevisionId,
    required Future<Iterable<PowerBatchTargetPlan>> Function() capturePlans,
  }) async {
    await schemaRuntime.ensureRuntimeSchema();
    return database.transaction(() async {
      final revision = await _requireWorkingRevision(
        projectId: projectId,
        designRevisionId: designRevisionId,
      );
      final plans = (await capturePlans()).toList()
        ..sort((a, b) => a.nodeKey.compareTo(b.nodeKey));
      if (plans.isEmpty) {
        throw ArgumentError('Power batch cannot be empty.');
      }
      final byNode = <String, PowerBatchTargetPlan>{};
      final evaluationIds = <String>{};
      for (final plan in plans) {
        if (plan.nodeKey.revisionId != designRevisionId) {
          throw const PowerRuntimeStorageException(
            'ELV4_POINTER_REVISION_MISMATCH',
          );
        }
        if (byNode.putIfAbsent(plan.nodeKey.encode(), () => plan) != plan) {
          throw ArgumentError('Power batch target nodes must be unique.');
        }
        if (!evaluationIds.add(plan.evaluationId)) {
          throw ArgumentError('Power batch evaluation ids must be unique.');
        }
      }
      _assertBatchDag(plans, byNode);

      final captures = <PowerBatchTargetCapture>[];
      for (final plan in plans) {
        final baseline = await _loadTargetPointer(
          projectId: projectId,
          designRevisionId: designRevisionId,
          nodeKey: plan.nodeKey,
        );
        if (baseline != null && baseline.state == PowerPointerState.current) {
          throw PowerRuntimeStorageException(
            'ELV4_POINTER_ALREADY_CURRENT',
            {'nodeKeySha256': plan.nodeKey.sha256},
          );
        }
        final external = <PowerConsumedPointerCapture>[];
        for (final reference in plan.consumedInput.evaluations) {
          final dependencyNode = PowerNodeKeyV2.decode(reference.logicalNodeKey);
          final internal = byNode[dependencyNode.encode()];
          if (internal != null) {
            if (internal.evaluationId != reference.evaluationId ||
                internal.consumedInput.inputFingerprint !=
                    reference.inputFingerprint) {
              throw const PowerRuntimeStorageException(
                'ELV4_BATCH_INTERNAL_DEPENDENCY_MISMATCH',
              );
            }
            continue;
          }
          external.add(
            await _requireCurrentDependency(
              projectId: projectId,
              designRevisionId: designRevisionId,
              nodeKey: dependencyNode,
              expectedEvaluationId: reference.evaluationId,
              expectedInputFingerprint: reference.inputFingerprint,
            ),
          );
        }
        external.sort((a, b) => a.nodeKey.compareTo(b.nodeKey));
        captures.add(
          PowerBatchTargetCapture(
            plan: plan,
            pointerState: baseline?.state,
            pointerGeneration: baseline?.generation,
            pointerEvaluationId: baseline?.evaluationId,
            externalConsumedPointers: List.unmodifiable(external),
          ),
        );
      }
      return PowerBatchCalculationCapture(
        projectId: _text(projectId, 'projectId'),
        designRevisionId: _text(designRevisionId, 'designRevisionId'),
        revisionToken: revision.revision,
        targets: List.unmodifiable(captures),
      );
    });
  }

  Future<PowerBatchPublicationReceipt> publishBatchGuarded({
    required PowerBatchCalculationCapture capture,
    required Iterable<PowerEvaluationEvidence> evaluations,
    required String operationId,
    required String commandFingerprint,
    required Future<Iterable<PowerBatchTargetPlan>> Function() recapturePlans,
  }) async {
    await schemaRuntime.ensureRuntimeSchema();
    final normalizedFingerprint =
        _sha256(commandFingerprint, 'commandFingerprint');
    return database.transaction(() async {
      final replay = await _loadReplay(
        capture: capture,
        operationId: operationId,
        commandFingerprint: normalizedFingerprint,
      );
      if (replay != null) return replay;

      final revision = await _requireWorkingRevision(
        projectId: capture.projectId,
        designRevisionId: capture.designRevisionId,
        inputChanged: true,
      );
      if (revision.revision != capture.revisionToken) {
        _inputChanged('DESIGN_TOKEN_CHANGED');
      }

      final recaptured = (await recapturePlans()).toList()
        ..sort((a, b) => a.nodeKey.compareTo(b.nodeKey));
      _verifyRecapturedPlans(capture, recaptured);
      final capturedByNode = {
        for (final target in capture.targets) target.plan.nodeKey.encode(): target,
      };
      final recapturedByNode = {
        for (final target in recaptured) target.nodeKey.encode(): target,
      };
      _assertBatchDag(recaptured, {
        for (final target in recaptured) target.nodeKey.encode(): target,
      });

      for (final target in capture.targets) {
        await _verifyTargetBaseline(
          capture: capture,
          target: target,
        );
        for (final expected in target.externalConsumedPointers) {
          final current = await _requireCurrentDependency(
            projectId: capture.projectId,
            designRevisionId: capture.designRevisionId,
            nodeKey: expected.nodeKey,
            expectedEvaluationId: expected.evaluationId,
            expectedInputFingerprint: expected.inputFingerprint,
          );
          if (current.generation != expected.generation) {
            _inputChanged('CONSUMED_POINTER_GENERATION_CHANGED');
          }
        }
      }

      final evidenceByNode = <String, PowerEvaluationEvidence>{};
      for (final evidence in evaluations) {
        if (evidenceByNode.putIfAbsent(evidence.nodeKey.encode(), () => evidence) !=
            evidence) {
          throw ArgumentError('Batch evaluation nodes must be unique.');
        }
      }
      if (evidenceByNode.length != capturedByNode.length ||
          !capturedByNode.keys.every(evidenceByNode.containsKey)) {
        _inputChanged('BATCH_EVALUATION_SET_CHANGED');
      }

      final stored = <String, _StoredBatchEvaluation>{};
      for (final key in capturedByNode.keys.toList()..sort()) {
        final target = capturedByNode[key]!;
        final plan = recapturedByNode[key]!;
        final evidence = evidenceByNode[key]!;
        _validateEvaluation(plan, evidence);
        final envelope = {
          'schema': 'electra.elv4-published-evaluation.v1',
          'evidence': evidence.toMap(),
          'consumedInput': plan.consumedInput.fingerprintPayload,
          'dependencyKeys': plan.consumedInput.dependencyKeys,
        };
        final json = canonicalEngineeringJsonV1(envelope);
        final sha = sha256HexUtf8(json);
        await _appendEvaluation(
          projectId: capture.projectId,
          designRevisionId: capture.designRevisionId,
          evidence: evidence,
          storedJson: json,
          storedSha256: sha,
        );
        stored[key] = _StoredBatchEvaluation(
          target: target,
          plan: plan,
          evidence: evidence,
          storedSha256: sha,
        );
      }

      final items = <PowerBatchPublishedItem>[];
      for (final key in stored.keys.toList()..sort()) {
        final item = stored[key]!;
        final generation = await _publishPointer(
          capture: capture,
          target: item.target,
          evidence: item.evidence,
          storedSha256: item.storedSha256,
        );
        await _replaceIndex(
          projectId: capture.projectId,
          designRevisionId: capture.designRevisionId,
          nodeKey: item.evidence.nodeKey,
          generation: generation,
          consumedInput: item.plan.consumedInput,
        );
        items.add(
          PowerBatchPublishedItem(
            nodeKey: item.evidence.nodeKey,
            evaluationId: item.evidence.evaluationId,
            generation: generation,
            storedEvidenceSha256: item.storedSha256,
          ),
        );
      }
      items.sort((a, b) => a.nodeKey.compareTo(b.nodeKey));
      final receipt = PowerBatchPublicationReceipt(
        items: List.unmodifiable(items),
        replayed: false,
      );
      final instant = now().toUtc();
      await database.customStatement(
        'INSERT INTO power_operation_records '
        '(project_id, design_revision_id, operation_id, command_type, '
        'payload_schema, command_fingerprint, status, result_json, created_at, '
        'committed_at, origin_device_id) '
        "VALUES (?, ?, ?, 'CALCULATE_POWER_BATCH', "
        "'electra.elv4-calculate-power-batch.v1', ?, 'COMMITTED', ?, ?, ?, ?)",
        [
          Variable.withString(capture.projectId),
          Variable.withString(capture.designRevisionId),
          Variable.withString(_text(operationId, 'operationId')),
          Variable.withString(normalizedFingerprint),
          Variable.withString(canonicalEngineeringJsonV1(receipt.toMap())),
          Variable<DateTime>(instant),
          Variable<DateTime>(instant),
          Variable.withString(originDeviceId),
        ],
      );
      return receipt;
    });
  }

  Future<PowerBatchPublicationReceipt?> _loadReplay({
    required PowerBatchCalculationCapture capture,
    required String operationId,
    required String commandFingerprint,
  }) async {
    final row = await database.customSelect(
      'SELECT command_fingerprint, status, result_json '
      'FROM power_operation_records WHERE project_id = ? '
      'AND design_revision_id = ? AND operation_id = ?',
      variables: [
        Variable.withString(capture.projectId),
        Variable.withString(capture.designRevisionId),
        Variable.withString(_text(operationId, 'operationId')),
      ],
    ).getSingleOrNull();
    if (row == null) return null;
    if (row.read<String>('command_fingerprint') != commandFingerprint) {
      throw const PowerRuntimeStorageException(
        'ELV4_OPERATION_FINGERPRINT_CONFLICT',
      );
    }
    final resultJson = row.readNullable<String>('result_json');
    if (row.read<String>('status') != 'COMMITTED' || resultJson == null) {
      throw const PowerRuntimeStorageException(
        'ELV4_OPERATION_INCOMPLETE_REPLAY',
      );
    }
    return PowerBatchPublicationReceipt.fromMap(
      (jsonDecode(resultJson) as Map).cast<String, Object?>(),
      replayed: true,
    );
  }

  void _verifyRecapturedPlans(
    PowerBatchCalculationCapture capture,
    List<PowerBatchTargetPlan> recaptured,
  ) {
    final oldByNode = {
      for (final target in capture.targets) target.plan.nodeKey.encode(): target.plan,
    };
    final newByNode = {
      for (final target in recaptured) target.nodeKey.encode(): target,
    };
    if (oldByNode.length != newByNode.length ||
        !oldByNode.keys.every(newByNode.containsKey)) {
      _inputChanged('BATCH_TARGET_SET_CHANGED');
    }
    for (final key in oldByNode.keys) {
      final oldPlan = oldByNode[key]!;
      final newPlan = newByNode[key]!;
      if (oldPlan.evaluationId != newPlan.evaluationId ||
          oldPlan.consumedInput.inputFingerprint !=
              newPlan.consumedInput.inputFingerprint) {
        _inputChanged('TECHNICAL_FINGERPRINT_CHANGED');
      }
    }
  }

  Future<void> _verifyTargetBaseline({
    required PowerBatchCalculationCapture capture,
    required PowerBatchTargetCapture target,
  }) async {
    final current = await _loadTargetPointer(
      projectId: capture.projectId,
      designRevisionId: capture.designRevisionId,
      nodeKey: target.plan.nodeKey,
    );
    if (target.pointerState == null) {
      if (current != null) _inputChanged('TARGET_POINTER_CREATED');
      return;
    }
    if (current == null ||
        current.state != PowerPointerState.stale ||
        current.generation != target.pointerGeneration ||
        current.evaluationId != target.pointerEvaluationId) {
      _inputChanged('TARGET_POINTER_CHANGED');
    }
  }

  Future<_BatchPointer?> _loadTargetPointer({
    required String projectId,
    required String designRevisionId,
    required PowerNodeKeyV2 nodeKey,
  }) async {
    final row = await database.customSelect(
      'SELECT logical_node_key_json, state, generation, evaluation_id '
      'FROM power_evaluation_pointers WHERE project_id = ? '
      'AND design_revision_id = ? AND logical_node_key_sha256 = ?',
      variables: [
        Variable.withString(projectId),
        Variable.withString(designRevisionId),
        Variable.withString(nodeKey.sha256),
      ],
    ).getSingleOrNull();
    if (row == null) return null;
    final decoded = PowerNodeKeyV2.decode(
      row.read<String>('logical_node_key_json'),
    );
    if (decoded != nodeKey) {
      throw const PowerRuntimeStorageException('ELV4_POINTER_HASH_COLLISION');
    }
    return _BatchPointer(
      state: _pointerState(row.read<String>('state')),
      generation: row.read<int>('generation'),
      evaluationId: row.readNullable<String>('evaluation_id'),
    );
  }

  Future<PowerConsumedPointerCapture> _requireCurrentDependency({
    required String projectId,
    required String designRevisionId,
    required PowerNodeKeyV2 nodeKey,
    required String expectedEvaluationId,
    required String expectedInputFingerprint,
  }) async {
    final row = await database.customSelect(
      'SELECT p.state, p.generation, p.evaluation_id, r.input_fingerprint '
      'FROM power_evaluation_pointers p '
      'JOIN power_evaluation_records r '
      'ON r.design_revision_id = p.design_revision_id '
      'AND r.logical_node_key_sha256 = p.logical_node_key_sha256 '
      'AND r.evaluation_id = p.evaluation_id '
      'WHERE p.project_id = ? AND p.design_revision_id = ? '
      'AND p.logical_node_key_sha256 = ?',
      variables: [
        Variable.withString(projectId),
        Variable.withString(designRevisionId),
        Variable.withString(nodeKey.sha256),
      ],
    ).getSingleOrNull();
    if (row == null ||
        row.read<String>('state') != 'CURRENT' ||
        row.readNullable<String>('evaluation_id') != expectedEvaluationId ||
        row.read<String>('input_fingerprint') != expectedInputFingerprint) {
      _inputChanged('CONSUMED_POINTER_CHANGED');
    }
    return PowerConsumedPointerCapture(
      nodeKey: nodeKey,
      generation: row!.read<int>('generation'),
      evaluationId: expectedEvaluationId,
      inputFingerprint: expectedInputFingerprint,
    );
  }

  Future<int> _publishPointer({
    required PowerBatchCalculationCapture capture,
    required PowerBatchTargetCapture target,
    required PowerEvaluationEvidence evidence,
    required String storedSha256,
  }) async {
    if (target.pointerState == null) {
      await database.customStatement(
        'INSERT INTO power_evaluation_pointers '
        '(project_id, design_revision_id, logical_node_key_json, '
        'logical_node_key_sha256, state, generation, evaluation_id, '
        'evidence_sha256, updated_at, origin_device_id) '
        "VALUES (?, ?, ?, ?, 'CURRENT', 1, ?, ?, ?, ?)",
        [
          Variable.withString(capture.projectId),
          Variable.withString(capture.designRevisionId),
          Variable.withString(evidence.nodeKey.encode()),
          Variable.withString(evidence.nodeKey.sha256),
          Variable.withString(evidence.evaluationId),
          Variable.withString(storedSha256),
          Variable<DateTime>(now().toUtc()),
          Variable.withString(originDeviceId),
        ],
      );
      return 1;
    }
    final generation = target.pointerGeneration!;
    final updated = await database.customUpdate(
      'UPDATE power_evaluation_pointers '
      "SET state = 'CURRENT', generation = generation + 1, evaluation_id = ?, "
      'evidence_sha256 = ?, updated_at = ?, origin_device_id = ? '
      'WHERE project_id = ? AND design_revision_id = ? '
      'AND logical_node_key_sha256 = ? AND generation = ? '
      "AND state = 'STALE'",
      variables: [
        Variable.withString(evidence.evaluationId),
        Variable.withString(storedSha256),
        Variable<DateTime>(now().toUtc()),
        Variable.withString(originDeviceId),
        Variable.withString(capture.projectId),
        Variable.withString(capture.designRevisionId),
        Variable.withString(evidence.nodeKey.sha256),
        Variable.withInt(generation),
      ],
    );
    if (updated != 1) _inputChanged('TARGET_POINTER_CAS_LOST');
    return generation + 1;
  }

  Future<void> _appendEvaluation({
    required String projectId,
    required String designRevisionId,
    required PowerEvaluationEvidence evidence,
    required String storedJson,
    required String storedSha256,
  }) async {
    final existing = await database.customSelect(
      'SELECT evidence_sha256 FROM power_evaluation_records '
      'WHERE design_revision_id = ? AND logical_node_key_sha256 = ? '
      'AND evaluation_id = ?',
      variables: [
        Variable.withString(designRevisionId),
        Variable.withString(evidence.nodeKey.sha256),
        Variable.withString(evidence.evaluationId),
      ],
    ).getSingleOrNull();
    if (existing != null) {
      if (existing.read<String>('evidence_sha256') == storedSha256) return;
      throw const PowerRuntimeStorageException(
        'ELV4_EVALUATION_IDENTITY_CONFLICT',
      );
    }
    await database.customStatement(
      'INSERT INTO power_evaluation_records '
      '(project_id, design_revision_id, logical_node_key_json, '
      'logical_node_key_sha256, evaluation_id, scope_kind, scope_id, '
      'process_code, subject_kind, subject_id, input_fingerprint, status, '
      'applicability, evidence_json, evidence_sha256, created_at, '
      'origin_device_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        Variable.withString(projectId),
        Variable.withString(designRevisionId),
        Variable.withString(evidence.nodeKey.encode()),
        Variable.withString(evidence.nodeKey.sha256),
        Variable.withString(evidence.evaluationId),
        Variable.withString(evidence.nodeKey.scopeKind.name.toUpperCase()),
        Variable.withString(evidence.nodeKey.scopeId),
        Variable.withString(_processCode(evidence.nodeKey.processCode)),
        Variable.withString(evidence.nodeKey.subjectKind),
        Variable.withString(evidence.nodeKey.subjectId),
        Variable.withString(evidence.inputFingerprint),
        Variable.withString(evidence.status.name.toUpperCase()),
        Variable.withString(evidence.applicability.name.toUpperCase()),
        Variable.withString(storedJson),
        Variable.withString(storedSha256),
        Variable<DateTime>(now().toUtc()),
        Variable.withString(originDeviceId),
      ],
    );
  }

  Future<void> _replaceIndex({
    required String projectId,
    required String designRevisionId,
    required PowerNodeKeyV2 nodeKey,
    required int generation,
    required PowerConsumedInput consumedInput,
  }) async {
    await database.customUpdate(
      'DELETE FROM power_dependency_index_records '
      'WHERE project_id = ? AND design_revision_id = ? '
      'AND logical_node_key_sha256 = ?',
      variables: [
        Variable.withString(projectId),
        Variable.withString(designRevisionId),
        Variable.withString(nodeKey.sha256),
      ],
    );
    final refs = <PowerDependencyRef>[
      for (final fact in consumedInput.facts)
        PowerDependencyRef(
          type: PowerDependencyRefType.fact,
          encodedRef: fact.key.encode(),
        ),
      for (final evaluation in consumedInput.evaluations)
        PowerDependencyRef(
          type: PowerDependencyRefType.evaluation,
          encodedRef: evaluation.logicalNodeKey,
        ),
    ];
    for (final ref in refs) {
      await database.customStatement(
        'INSERT INTO power_dependency_index_records '
        '(project_id, design_revision_id, dependency_ref_type, '
        'dependency_ref_json, dependency_ref_sha256, logical_node_key_json, '
        'logical_node_key_sha256, pointer_generation, updated_at, '
        'origin_device_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          Variable.withString(projectId),
          Variable.withString(designRevisionId),
          Variable.withString(
            ref.type == PowerDependencyRefType.fact ? 'FACT' : 'EVALUATION',
          ),
          Variable.withString(ref.encodedRef),
          Variable.withString(ref.sha256),
          Variable.withString(nodeKey.encode()),
          Variable.withString(nodeKey.sha256),
          Variable.withInt(generation),
          Variable<DateTime>(now().toUtc()),
          Variable.withString(originDeviceId),
        ],
      );
    }
  }

  Future<_RevisionToken> _requireWorkingRevision({
    required String projectId,
    required String designRevisionId,
    bool inputChanged = false,
  }) async {
    final row = await database.customSelect(
      'SELECT state, revision FROM project_design_revisions '
      'WHERE id = ? AND project_id = ? AND deleted_at IS NULL',
      variables: [
        Variable.withString(designRevisionId),
        Variable.withString(projectId),
      ],
    ).getSingleOrNull();
    if (row == null || row.read<String>('state') != 'WORKING') {
      if (inputChanged) _inputChanged('REVISION_NOT_WORKING');
      throw const PowerRuntimeStorageException('ELV4_REVISION_NOT_WORKING');
    }
    return _RevisionToken(revision: row.read<int>('revision'));
  }
}

final class _BatchPointer {
  const _BatchPointer({
    required this.state,
    required this.generation,
    required this.evaluationId,
  });

  final PowerPointerState state;
  final int generation;
  final String? evaluationId;
}

final class _RevisionToken {
  const _RevisionToken({required this.revision});

  final int revision;
}

final class _StoredBatchEvaluation {
  const _StoredBatchEvaluation({
    required this.target,
    required this.plan,
    required this.evidence,
    required this.storedSha256,
  });

  final PowerBatchTargetCapture target;
  final PowerBatchTargetPlan plan;
  final PowerEvaluationEvidence evidence;
  final String storedSha256;
}

void _validateEvaluation(
  PowerBatchTargetPlan plan,
  PowerEvaluationEvidence evidence,
) {
  if (evidence.nodeKey != plan.nodeKey ||
      evidence.evaluationId != plan.evaluationId ||
      evidence.algorithmVersion != plan.consumedInput.algorithmVersion ||
      evidence.inputSchemaVersion != plan.consumedInput.inputSchemaVersion ||
      evidence.numericPolicyVersion != plan.consumedInput.numericPolicyVersion ||
      evidence.inputFingerprint != plan.consumedInput.inputFingerprint) {
    _inputChanged('BATCH_EVIDENCE_INPUT_MISMATCH');
  }
  final evidenceDependencies =
      evidence.dependencies.map((value) => value.encode()).toList()..sort();
  final consumedDependencies = plan.consumedInput.evaluations
      .map((value) => value.logicalNodeKey)
      .toList()
    ..sort();
  if (canonicalEngineeringJsonV1(evidenceDependencies) !=
      canonicalEngineeringJsonV1(consumedDependencies)) {
    _inputChanged('EVALUATION_DEPENDENCY_SET_MISMATCH');
  }
}

void _assertBatchDag(
  Iterable<PowerBatchTargetPlan> plans,
  Map<String, PowerBatchTargetPlan> byNode,
) {
  final visiting = <String>{};
  final visited = <String>{};

  void visit(String node) {
    if (visiting.contains(node)) {
      throw const PowerRuntimeStorageException('ELV4_DEPENDENCY_CYCLE');
    }
    if (!visited.add(node)) return;
    visiting.add(node);
    final plan = byNode[node]!;
    for (final reference in plan.consumedInput.evaluations) {
      final dependency = PowerNodeKeyV2.decode(reference.logicalNodeKey).encode();
      if (byNode.containsKey(dependency)) visit(dependency);
    }
    visiting.remove(node);
  }

  for (final plan in plans) {
    visit(plan.nodeKey.encode());
  }
}

PowerPointerState _pointerState(String value) => switch (value) {
      'CURRENT' => PowerPointerState.current,
      'STALE' => PowerPointerState.stale,
      _ => throw const PowerRuntimeStorageException(
          'ELV4_POINTER_STATE_CORRUPT',
        ),
    };

String _processCode(PowerProcessCode value) => switch (value) {
      PowerProcessCode.pwr01 => 'ELV-PWR-01',
      PowerProcessCode.pwr02 => 'ELV-PWR-02',
      PowerProcessCode.pwr03 => 'ELV-PWR-03',
      PowerProcessCode.pwr04 => 'ELV-PWR-04',
      PowerProcessCode.pwr05 => 'ELV-PWR-05',
      PowerProcessCode.pwr06 => 'ELV-PWR-06',
    };

Never _inputChanged(String reason) => throw PowerRuntimeStorageException(
      'ELV4_RESULT_INPUT_CHANGED',
      {'reason': reason},
    );

String _text(String value, String field) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, field, 'Must not be empty.');
  }
  return normalized;
}

String _sha256(String value, String field) {
  final normalized = _text(value, field).toLowerCase();
  if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(normalized)) {
    throw ArgumentError.value(value, field, 'Expected lowercase SHA-256.');
  }
  return normalized;
}
