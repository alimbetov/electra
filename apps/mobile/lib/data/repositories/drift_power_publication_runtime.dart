import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core.dart';

import '../database/app_database.dart';
import '../database/drift_raw_statement.dart';
import 'drift_power_runtime_store.dart';
import 'drift_power_snapshot_facts.dart';

enum PowerDependencyRefType { fact, evaluation }

enum PowerRevisionReadKind { working, captured, capturedEmpty, notCaptured }

final class PowerDependencyRef {
  PowerDependencyRef({required this.type, required String encodedRef})
    : encodedRef = _text(encodedRef, 'encodedRef'),
      sha256 = sha256HexUtf8(_text(encodedRef, 'encodedRef'));

  final PowerDependencyRefType type;
  final String encodedRef;
  final String sha256;
}

final class PowerConsumedPointerCapture {
  const PowerConsumedPointerCapture({
    required this.nodeKey,
    required this.generation,
    required this.evaluationId,
    required this.inputFingerprint,
  });

  final PowerNodeKeyV2 nodeKey;
  final int generation;
  final String evaluationId;
  final String inputFingerprint;
}

final class PowerCalculationCapture {
  const PowerCalculationCapture({
    required this.projectId,
    required this.designRevisionId,
    required this.revisionToken,
    required this.targetNodeKey,
    required this.targetPointerState,
    required this.targetPointerGeneration,
    required this.targetEvaluationId,
    required this.inputFingerprint,
    required this.consumedPointers,
  });

  final String projectId;
  final String designRevisionId;
  final int revisionToken;
  final PowerNodeKeyV2 targetNodeKey;
  final PowerPointerState? targetPointerState;
  final int? targetPointerGeneration;
  final String? targetEvaluationId;
  final String inputFingerprint;
  final List<PowerConsumedPointerCapture> consumedPointers;

  bool get firstPublication => targetPointerState == null;
}

final class PowerPublicationReceipt {
  const PowerPublicationReceipt({
    required this.nodeKey,
    required this.evaluationId,
    required this.generation,
    required this.storedEvidenceSha256,
    required this.replayed,
  });

  final PowerNodeKeyV2 nodeKey;
  final String evaluationId;
  final int generation;
  final String storedEvidenceSha256;
  final bool replayed;

  Map<String, Object?> toMap() => {
    'schema': 'electra.elv4-publication-receipt.v1',
    'logicalNodeKey': nodeKey.toTuple(),
    'evaluationId': evaluationId,
    'generation': generation,
    'storedEvidenceSha256': storedEvidenceSha256,
  };

  factory PowerPublicationReceipt.fromMap(
    Map<String, Object?> map, {
    required bool replayed,
  }) {
    final keyValue = map['logicalNodeKey'];
    if (keyValue is! List) {
      throw const FormatException(
        'Publication receipt lacks logical node key.',
      );
    }
    return PowerPublicationReceipt(
      nodeKey: PowerNodeKeyV2.decode(canonicalEngineeringJsonV1(keyValue)),
      evaluationId: map['evaluationId']! as String,
      generation: map['generation']! as int,
      storedEvidenceSha256: map['storedEvidenceSha256']! as String,
      replayed: replayed,
    );
  }
}

final class PowerInvalidationReceipt {
  const PowerInvalidationReceipt({
    required this.previousRevisionToken,
    required this.currentRevisionToken,
    required this.invalidatedNodeKeys,
  });

  final int previousRevisionToken;
  final int currentRevisionToken;
  final List<PowerNodeKeyV2> invalidatedNodeKeys;
}

final class PowerRevisionReadSnapshot {
  const PowerRevisionReadSnapshot({
    required this.kind,
    required this.lifecycleState,
    required this.mutationAllowed,
    required this.pointerStates,
    required this.capturedPayload,
    required this.reasonCode,
  });

  final PowerRevisionReadKind kind;
  final String lifecycleState;
  final bool mutationAllowed;
  final Map<String, PowerPointerState> pointerStates;
  final Map<String, Object?>? capturedPayload;
  final String? reasonCode;
}

/// P7 storage/runtime layer for dependency indexing, invalidation and guarded
/// publication. Immutable evaluations remain the evidence source of truth;
/// `power_dependency_index_records` is only an index of CURRENT pointers.
final class DriftPowerPublicationRuntime {
  DriftPowerPublicationRuntime(
    this.database, {
    required this.originDeviceId,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  final AppDatabase database;
  final String originDeviceId;
  final DateTime Function() now;

  Future<void> ensureRuntimeSchema() async {
    await runRawStatement(
      database,
      'CREATE TABLE IF NOT EXISTS power_dependency_index_records ('
      'project_id TEXT NOT NULL, '
      'design_revision_id TEXT NOT NULL, '
      'dependency_ref_type TEXT NOT NULL, '
      'dependency_ref_json TEXT NOT NULL, '
      'dependency_ref_sha256 TEXT NOT NULL, '
      'logical_node_key_json TEXT NOT NULL, '
      'logical_node_key_sha256 TEXT NOT NULL, '
      'pointer_generation INTEGER NOT NULL, '
      'updated_at INTEGER NOT NULL, '
      'origin_device_id TEXT NOT NULL, '
      'PRIMARY KEY (design_revision_id, dependency_ref_type, '
      'dependency_ref_sha256, logical_node_key_sha256), '
      "CHECK (dependency_ref_type IN ('FACT','EVALUATION')), "
      'CHECK (pointer_generation > 0), '
      'FOREIGN KEY (design_revision_id) REFERENCES project_design_revisions(id)'
      ')',
    );
    await runRawStatement(
      database,
      'CREATE INDEX IF NOT EXISTS idx_power_dependency_reverse '
      'ON power_dependency_index_records('
      'design_revision_id, dependency_ref_type, dependency_ref_sha256)',
    );
    await runRawStatement(
      database,
      'CREATE INDEX IF NOT EXISTS idx_power_dependency_node '
      'ON power_dependency_index_records('
      'design_revision_id, logical_node_key_sha256)',
    );
  }

  /// Capture runs inside one consistent read transaction. [captureInput] must
  /// read its facts through the same database transaction zone.
  Future<PowerCalculationCapture> captureForCalculation({
    required String projectId,
    required String designRevisionId,
    required PowerNodeKeyV2 targetNodeKey,
    required Future<PowerConsumedInput> Function() captureInput,
  }) async {
    await ensureRuntimeSchema();
    return database.transaction(() async {
      final revision = await _requireRevision(
        projectId: projectId,
        designRevisionId: designRevisionId,
        requireWorking: true,
      );
      _requireNodeRevision(targetNodeKey, designRevisionId);
      final target = await _loadPointer(
        projectId: projectId,
        designRevisionId: designRevisionId,
        nodeKey: targetNodeKey,
      );
      if (target != null && target.state == PowerPointerState.current) {
        throw PowerRuntimeStorageException('ELV4_POINTER_ALREADY_CURRENT', {
          'nodeKeySha256': targetNodeKey.sha256,
        });
      }

      final input = await captureInput();
      final consumed = <PowerConsumedPointerCapture>[];
      for (final reference in input.evaluations) {
        final nodeKey = PowerNodeKeyV2.decode(reference.logicalNodeKey);
        _requireNodeRevision(nodeKey, designRevisionId);
        if (nodeKey == targetNodeKey) {
          throw const PowerRuntimeStorageException('ELV4_DEPENDENCY_CYCLE');
        }
        consumed.add(
          await _requireConsumedCurrentPointer(
            projectId: projectId,
            designRevisionId: designRevisionId,
            nodeKey: nodeKey,
            expectedEvaluationId: reference.evaluationId,
            expectedInputFingerprint: reference.inputFingerprint,
          ),
        );
      }
      consumed.sort((a, b) => a.nodeKey.encode().compareTo(b.nodeKey.encode()));

      return PowerCalculationCapture(
        projectId: _text(projectId, 'projectId'),
        designRevisionId: _text(designRevisionId, 'designRevisionId'),
        revisionToken: revision.revision,
        targetNodeKey: targetNodeKey,
        targetPointerState: target?.state,
        targetPointerGeneration: target?.generation,
        targetEvaluationId: target?.evaluationId,
        inputFingerprint: input.inputFingerprint,
        consumedPointers: List.unmodifiable(consumed),
      );
    });
  }

  /// Pure calculation happens before this call. Publication reopens a short
  /// transaction, re-captures exact consumed facts and verifies lifecycle,
  /// design token, target pointer generation and all consumed pointer
  /// generations before changing any durable state.
  Future<PowerPublicationReceipt> publishGuarded({
    required PowerCalculationCapture capture,
    required PowerEvaluationEvidence evidence,
    required String operationId,
    required String commandFingerprint,
    required Future<PowerConsumedInput> Function() recaptureInput,
  }) async {
    await ensureRuntimeSchema();
    final normalizedCommandFingerprint = _sha256(
      commandFingerprint,
      'commandFingerprint',
    );
    return database.transaction(() async {
      final replay = await _loadPublicationReplay(
        capture: capture,
        operationId: operationId,
        commandFingerprint: normalizedCommandFingerprint,
      );
      if (replay != null) return replay;

      final revision = await _requireRevision(
        projectId: capture.projectId,
        designRevisionId: capture.designRevisionId,
        requireWorking: true,
        inputChangedOnMismatch: true,
      );
      if (revision.revision != capture.revisionToken) {
        _inputChanged('DESIGN_TOKEN_CHANGED');
      }
      if (evidence.nodeKey != capture.targetNodeKey) {
        _inputChanged('TARGET_NODE_CHANGED');
      }

      final recaptured = await recaptureInput();
      _validateEvidenceConsumedInput(evidence, recaptured);
      if (recaptured.inputFingerprint != capture.inputFingerprint) {
        _inputChanged('TECHNICAL_FINGERPRINT_CHANGED');
      }

      await _verifyConsumedPointers(capture);
      await _verifyTargetPointerBaseline(capture);

      final envelope = _publicationEnvelope(evidence, recaptured);
      final envelopeJson = canonicalEngineeringJsonV1(envelope);
      final envelopeSha256 = sha256HexUtf8(envelopeJson);
      await _appendImmutableEvaluation(
        projectId: capture.projectId,
        designRevisionId: capture.designRevisionId,
        evidence: evidence,
        storedJson: envelopeJson,
        storedSha256: envelopeSha256,
      );

      final generation = await _publishPointer(
        capture: capture,
        evidence: evidence,
        storedSha256: envelopeSha256,
      );
      await _replaceReverseIndex(
        projectId: capture.projectId,
        designRevisionId: capture.designRevisionId,
        nodeKey: evidence.nodeKey,
        generation: generation,
        consumedInput: recaptured,
      );

      final receipt = PowerPublicationReceipt(
        nodeKey: evidence.nodeKey,
        evaluationId: evidence.evaluationId,
        generation: generation,
        storedEvidenceSha256: envelopeSha256,
        replayed: false,
      );
      final instant = now().toUtc();
      await runRawStatement(
        database,
        'INSERT INTO power_operation_records '
        '(project_id, design_revision_id, operation_id, command_type, '
        'payload_schema, command_fingerprint, status, result_json, created_at, '
        'committed_at, origin_device_id) '
        "VALUES (?, ?, ?, 'CALCULATE_POWER', "
        "'electra.elv4-calculate-power.v1', ?, 'COMMITTED', ?, ?, ?, ?)",
        [
          Variable.withString(capture.projectId),
          Variable.withString(capture.designRevisionId),
          Variable.withString(_text(operationId, 'operationId')),
          Variable.withString(normalizedCommandFingerprint),
          Variable.withString(canonicalEngineeringJsonV1(receipt.toMap())),
          Variable<DateTime>(instant),
          Variable<DateTime>(instant),
          Variable.withString(originDeviceId),
        ],
      );
      return receipt;
    });
  }

  /// Executes the canonical edit and invalidation in one transaction. The edit
  /// must advance the WORKING design revision token exactly once. [oldClosure]
  /// is captured before the edit; [captureNewClosure] runs after the edit.
  Future<PowerInvalidationReceipt> mutateAndInvalidate({
    required String projectId,
    required String designRevisionId,
    required Iterable<PowerDependencyKey> oldClosure,
    required Future<void> Function() applyMutation,
    required Future<Iterable<PowerDependencyKey>> Function() captureNewClosure,
  }) async {
    await ensureRuntimeSchema();
    return database.transaction(() async {
      final before = await _requireRevision(
        projectId: projectId,
        designRevisionId: designRevisionId,
        requireWorking: true,
      );
      final oldKeys = oldClosure.map((value) => value.encode()).toSet();
      await applyMutation();
      final newKeys = (await captureNewClosure())
          .map((value) => value.encode())
          .toSet();
      final after = await _requireRevision(
        projectId: projectId,
        designRevisionId: designRevisionId,
        requireWorking: true,
      );
      if (after.revision != before.revision + 1) {
        throw PowerRuntimeStorageException('ELV4_DESIGN_TOKEN_NOT_ADVANCED', {
          'before': before.revision,
          'after': after.revision,
        });
      }
      final refs = {...oldKeys, ...newKeys}.toList()..sort();
      final invalidated = await _invalidateDependencyClosure(
        projectId: projectId,
        designRevisionId: designRevisionId,
        changedFactRefs: refs,
      );
      return PowerInvalidationReceipt(
        previousRevisionToken: before.revision,
        currentRevisionToken: after.revision,
        invalidatedNodeKeys: invalidated,
      );
    });
  }

  Future<PowerRevisionReadSnapshot> readRevision({
    required String projectId,
    required String designRevisionId,
  }) async {
    final revision = await _requireRevision(
      projectId: projectId,
      designRevisionId: designRevisionId,
      requireWorking: false,
    );
    if (revision.state == 'WORKING') {
      final rows = await database
          .customSelect(
            'SELECT logical_node_key_json, state FROM power_evaluation_pointers '
            'WHERE project_id = ? AND design_revision_id = ? '
            'ORDER BY logical_node_key_json',
            variables: [
              Variable.withString(projectId),
              Variable.withString(designRevisionId),
            ],
          )
          .get();
      final states = <String, PowerPointerState>{};
      for (final row in rows) {
        states[row.read<String>('logical_node_key_json')] = _pointerState(
          row.read<String>('state'),
        );
      }
      return PowerRevisionReadSnapshot(
        kind: PowerRevisionReadKind.working,
        lifecycleState: revision.state,
        mutationAllowed: true,
        pointerStates: Map.unmodifiable(states),
        capturedPayload: null,
        reasonCode: null,
      );
    }

    final snapshot = await database
        .customSelect(
          'SELECT payload_json, power_sha256, physical_sha256 FROM design_revision_power_snapshots '
          'WHERE project_id = ? AND design_revision_id = ?',
          variables: [
            Variable.withString(projectId),
            Variable.withString(designRevisionId),
          ],
        )
        .getSingleOrNull();
    if (snapshot == null) {
      return PowerRevisionReadSnapshot(
        kind: PowerRevisionReadKind.notCaptured,
        lifecycleState: revision.state,
        mutationAllowed: false,
        pointerStates: const {},
        capturedPayload: null,
        reasonCode: 'ELV4_POWER_NOT_CAPTURED',
      );
    }
    final payloadJson = snapshot.read<String>('payload_json');
    if (sha256HexUtf8(payloadJson) != snapshot.read<String>('power_sha256')) {
      throw const PowerRuntimeStorageException(
        'ELV4_FROZEN_POWER_SNAPSHOT_HASH_MISMATCH',
      );
    }
    final manifest = await database
        .customSelect(
          'SELECT manifest_sha256, physical_sha256, power_sha256 FROM design_revision_snapshot_manifests '
          'WHERE project_id = ? AND design_revision_id = ?',
          variables: [
            Variable.withString(projectId),
            Variable.withString(designRevisionId),
          ],
        )
        .getSingleOrNull();
    if (manifest == null ||
        manifest.read<String>('power_sha256') !=
            snapshot.read<String>('power_sha256') ||
        manifest.read<String>('physical_sha256') !=
            snapshot.read<String>('physical_sha256') ||
        sha256HexUtf8(
              canonicalEngineeringJsonV1({
                'schema': 'electra.elv4-snapshot-manifest.v1',
                'physicalSha256': manifest.read<String>('physical_sha256'),
                'powerSha256': manifest.read<String>('power_sha256'),
              }),
            ) !=
            manifest.read<String>('manifest_sha256')) {
      throw const PowerRuntimeStorageException(
        'ELV4_FROZEN_MANIFEST_HASH_MISMATCH',
      );
    }
    await _verifyPhysicalSection(
      projectId,
      designRevisionId,
      snapshot.read<String>('physical_sha256'),
    );
    final payload = (jsonDecode(snapshot.read<String>('payload_json')) as Map)
        .cast<String, Object?>();
    final pointerValues = payload['pointers'];
    final pointers = pointerValues is List ? pointerValues : const <Object?>[];
    return PowerRevisionReadSnapshot(
      kind:
          pointers.isEmpty &&
              !powerAspectTables.any(
                (table) => capturedPowerRows(payload, table).isNotEmpty,
              )
          ? PowerRevisionReadKind.capturedEmpty
          : PowerRevisionReadKind.captured,
      lifecycleState: revision.state,
      mutationAllowed: false,
      pointerStates: const {},
      capturedPayload: Map.unmodifiable(payload),
      reasonCode: null,
    );
  }

  /// Builds and persists the immutable power section that a power-aware freeze
  /// transaction can include before the WORKING -> FROZEN lifecycle CAS.
  /// This method does not perform the revision transition by itself.
  Future<String> captureCommittedPowerSectionForFreeze({
    required String projectId,
    required String designRevisionId,
    required int expectedRevisionToken,
    required String physicalSha256,
  }) => database.transaction(() async {
    final revision = await _requireRevision(
      projectId: projectId,
      designRevisionId: designRevisionId,
      requireWorking: true,
    );
    if (revision.revision != expectedRevisionToken) {
      throw const PowerRuntimeStorageException('ELV4_STALE_PRECONDITION');
    }
    await _verifyPhysicalSection(projectId, designRevisionId, physicalSha256);
    final existing = await database
        .customSelect(
          'SELECT power_sha256 FROM design_revision_power_snapshots '
          'WHERE design_revision_id = ?',
          variables: [Variable.withString(designRevisionId)],
        )
        .getSingleOrNull();
    if (existing != null) {
      return existing.read<String>('power_sha256');
    }
    final pointerRows = await database
        .customSelect(
          'SELECT logical_node_key_json, state, generation, evaluation_id, '
          'evidence_sha256 FROM power_evaluation_pointers '
          'WHERE project_id = ? AND design_revision_id = ? '
          'ORDER BY logical_node_key_json',
          variables: [
            Variable.withString(projectId),
            Variable.withString(designRevisionId),
          ],
        )
        .get();
    final payload = <String, Object?>{
      'schema': 'electra.elv4-power-freeze-section.v2',
      'facts': await DriftPowerSnapshotFacts(database)
          .capture(projectId, designRevisionId),
      'revisionToken': expectedRevisionToken,
      'pointers': [
        for (final row in pointerRows)
          {
            'logicalNodeKey': jsonDecode(
              row.read<String>('logical_node_key_json'),
            ),
            'state': row.read<String>('state'),
            'generation': row.read<int>('generation'),
            'evaluationId': row.readNullable<String>('evaluation_id'),
            'evidenceSha256': row.readNullable<String>('evidence_sha256'),
          },
      ],
    };
    final payloadJson = canonicalEngineeringJsonV1(payload);
    final powerSha256 = sha256HexUtf8(payloadJson);
    final normalizedPhysicalSha256 = _sha256(physicalSha256, 'physicalSha256');
    final manifestPayload = <String, Object?>{
      'schema': 'electra.elv4-snapshot-manifest.v1',
      'physicalSha256': normalizedPhysicalSha256,
      'powerSha256': powerSha256,
    };
    final manifestSha256 = sha256HexUtf8(
      canonicalEngineeringJsonV1(manifestPayload),
    );
    final instant = now().toUtc();
    await runRawStatement(
      database,
      'INSERT INTO design_revision_power_snapshots '
      '(design_revision_id, project_id, section_schema, capture_kind, '
      'payload_json, power_sha256, physical_sha256, created_at, '
      'origin_device_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        Variable.withString(designRevisionId),
        Variable.withString(projectId),
        Variable.withString('electra.elv4-power-freeze-section.v2'),
        Variable.withString('FREEZE'),
        Variable.withString(payloadJson),
        Variable.withString(powerSha256),
        Variable.withString(normalizedPhysicalSha256),
        Variable<DateTime>(instant),
        Variable.withString(originDeviceId),
      ],
    );
    await runRawStatement(
      database,
      'INSERT INTO design_revision_snapshot_manifests '
      '(design_revision_id, project_id, manifest_schema, manifest_sha256, '
      'physical_sha256, power_sha256, created_at, origin_device_id) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [
        Variable.withString(designRevisionId),
        Variable.withString(projectId),
        Variable.withString('electra.elv4-snapshot-manifest.v1'),
        Variable.withString(manifestSha256),
        Variable.withString(normalizedPhysicalSha256),
        Variable.withString(powerSha256),
        Variable<DateTime>(instant),
        Variable.withString(originDeviceId),
      ],
    );
    return powerSha256;
  });

  Future<void> _verifyPhysicalSection(
    String projectId,
    String revisionId,
    String expectedSha,
  ) async {
    final row =
        await (database.select(database.designRevisionPhysicalSnapshots)..where(
              (r) =>
                  r.projectId.equals(projectId) &
                  r.designRevisionId.equals(revisionId),
            ))
            .getSingleOrNull();
    if (row == null || row.payloadSha256 != expectedSha) {
      throw const PowerRuntimeStorageException(
        'ELV4_FROZEN_PHYSICAL_SNAPSHOT_HASH_MISMATCH',
      );
    }
    try {
      final payload = jsonDecode(row.payloadJson);
      if (payload is! Map<String, dynamic> ||
          DesignRevisionPhysicalSnapshot(
                designRevisionId: revisionId,
                projectId: projectId,
                schemaVersion: row.schemaVersion,
                payload: payload,
              ).contentSha256 !=
              expectedSha) {
        throw const PowerRuntimeStorageException(
          'ELV4_FROZEN_PHYSICAL_SNAPSHOT_HASH_MISMATCH',
        );
      }
    } on FormatException {
      throw const PowerRuntimeStorageException(
        'ELV4_FROZEN_PHYSICAL_SNAPSHOT_HASH_MISMATCH',
      );
    }
  }

  Future<List<PowerNodeKeyV2>> _invalidateDependencyClosure({
    required String projectId,
    required String designRevisionId,
    required Iterable<String> changedFactRefs,
  }) async {
    final affected = <String, PowerNodeKeyV2>{};
    final queue = <PowerNodeKeyV2>[];

    Future<void> discover(PowerDependencyRef ref) async {
      final rows = await database
          .customSelect(
            'SELECT logical_node_key_json FROM power_dependency_index_records '
            'WHERE project_id = ? AND design_revision_id = ? '
            'AND dependency_ref_type = ? AND dependency_ref_sha256 = ?',
            variables: [
              Variable.withString(projectId),
              Variable.withString(designRevisionId),
              Variable.withString(_dependencyRefType(ref.type)),
              Variable.withString(ref.sha256),
            ],
          )
          .get();
      for (final row in rows) {
        final key = PowerNodeKeyV2.decode(
          row.read<String>('logical_node_key_json'),
        );
        final encoded = key.encode();
        if (!affected.containsKey(encoded)) {
          affected[encoded] = key;
          queue.add(key);
        }
      }
    }

    for (final encoded in changedFactRefs.toSet()) {
      await discover(
        PowerDependencyRef(
          type: PowerDependencyRefType.fact,
          encodedRef: encoded,
        ),
      );
    }
    var index = 0;
    while (index < queue.length) {
      final changedNode = queue[index++];
      await discover(
        PowerDependencyRef(
          type: PowerDependencyRefType.evaluation,
          encodedRef: changedNode.encode(),
        ),
      );
    }

    final keys = affected.values.toList()..sort();
    final actuallyInvalidated = <PowerNodeKeyV2>[];
    for (final key in keys) {
      final updated = await database.customUpdate(
        'UPDATE power_evaluation_pointers '
        "SET state = 'STALE', generation = generation + 1, updated_at = ?, "
        'origin_device_id = ? '
        'WHERE project_id = ? AND design_revision_id = ? '
        'AND logical_node_key_sha256 = ? AND state = ?',
        variables: [
          Variable<DateTime>(now().toUtc()),
          Variable.withString(originDeviceId),
          Variable.withString(projectId),
          Variable.withString(designRevisionId),
          Variable.withString(key.sha256),
          Variable.withString('CURRENT'),
        ],
      );
      if (updated == 1) actuallyInvalidated.add(key);
      await database.customUpdate(
        'DELETE FROM power_dependency_index_records '
        'WHERE project_id = ? AND design_revision_id = ? '
        'AND logical_node_key_sha256 = ?',
        variables: [
          Variable.withString(projectId),
          Variable.withString(designRevisionId),
          Variable.withString(key.sha256),
        ],
      );
    }
    return List.unmodifiable(actuallyInvalidated);
  }

  Future<void> _replaceReverseIndex({
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
      await runRawStatement(
        database,
        'INSERT INTO power_dependency_index_records '
        '(project_id, design_revision_id, dependency_ref_type, '
        'dependency_ref_json, dependency_ref_sha256, logical_node_key_json, '
        'logical_node_key_sha256, pointer_generation, updated_at, '
        'origin_device_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          Variable.withString(projectId),
          Variable.withString(designRevisionId),
          Variable.withString(_dependencyRefType(ref.type)),
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

  Future<PowerPublicationReceipt?> _loadPublicationReplay({
    required PowerCalculationCapture capture,
    required String operationId,
    required String commandFingerprint,
  }) async {
    final row = await database
        .customSelect(
          'SELECT command_fingerprint, status, result_json '
          'FROM power_operation_records WHERE project_id = ? '
          'AND design_revision_id = ? AND operation_id = ?',
          variables: [
            Variable.withString(capture.projectId),
            Variable.withString(capture.designRevisionId),
            Variable.withString(_text(operationId, 'operationId')),
          ],
        )
        .getSingleOrNull();
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
    return PowerPublicationReceipt.fromMap(
      (jsonDecode(resultJson) as Map).cast<String, Object?>(),
      replayed: true,
    );
  }

  Future<void> _verifyConsumedPointers(PowerCalculationCapture capture) async {
    for (final expected in capture.consumedPointers) {
      final current = await _requireConsumedCurrentPointer(
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

  Future<void> _verifyTargetPointerBaseline(
    PowerCalculationCapture capture,
  ) async {
    final current = await _loadPointer(
      projectId: capture.projectId,
      designRevisionId: capture.designRevisionId,
      nodeKey: capture.targetNodeKey,
    );
    if (capture.targetPointerState == null) {
      if (current != null) _inputChanged('TARGET_POINTER_CREATED');
      return;
    }
    if (current == null ||
        current.state != PowerPointerState.stale ||
        current.generation != capture.targetPointerGeneration ||
        current.evaluationId != capture.targetEvaluationId) {
      _inputChanged('TARGET_POINTER_CHANGED');
    }
  }

  Future<int> _publishPointer({
    required PowerCalculationCapture capture,
    required PowerEvaluationEvidence evidence,
    required String storedSha256,
  }) async {
    if (capture.firstPublication) {
      await runRawStatement(
        database,
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
    final expectedGeneration = capture.targetPointerGeneration!;
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
        Variable.withInt(expectedGeneration),
      ],
    );
    if (updated != 1) _inputChanged('TARGET_POINTER_CAS_LOST');
    return expectedGeneration + 1;
  }

  Future<void> _appendImmutableEvaluation({
    required String projectId,
    required String designRevisionId,
    required PowerEvaluationEvidence evidence,
    required String storedJson,
    required String storedSha256,
  }) async {
    final existing = await database
        .customSelect(
          'SELECT evidence_sha256 FROM power_evaluation_records '
          'WHERE design_revision_id = ? AND logical_node_key_sha256 = ? '
          'AND evaluation_id = ?',
          variables: [
            Variable.withString(designRevisionId),
            Variable.withString(evidence.nodeKey.sha256),
            Variable.withString(evidence.evaluationId),
          ],
        )
        .getSingleOrNull();
    if (existing != null) {
      if (existing.read<String>('evidence_sha256') == storedSha256) return;
      throw const PowerRuntimeStorageException(
        'ELV4_EVALUATION_IDENTITY_CONFLICT',
      );
    }
    await runRawStatement(
      database,
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

  Future<PowerConsumedPointerCapture> _requireConsumedCurrentPointer({
    required String projectId,
    required String designRevisionId,
    required PowerNodeKeyV2 nodeKey,
    required String expectedEvaluationId,
    required String expectedInputFingerprint,
  }) async {
    final row = await database
        .customSelect(
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
        )
        .getSingleOrNull();
    if (row == null ||
        row.read<String>('state') != 'CURRENT' ||
        row.readNullable<String>('evaluation_id') != expectedEvaluationId ||
        row.read<String>('input_fingerprint') != expectedInputFingerprint) {
      _inputChanged('CONSUMED_POINTER_CHANGED');
    }
    return PowerConsumedPointerCapture(
      nodeKey: nodeKey,
      generation: row.read<int>('generation'),
      evaluationId: expectedEvaluationId,
      inputFingerprint: expectedInputFingerprint,
    );
  }

  Future<_StoredPointer?> _loadPointer({
    required String projectId,
    required String designRevisionId,
    required PowerNodeKeyV2 nodeKey,
  }) async {
    final row = await database
        .customSelect(
          'SELECT logical_node_key_json, state, generation, evaluation_id '
          'FROM power_evaluation_pointers WHERE project_id = ? '
          'AND design_revision_id = ? AND logical_node_key_sha256 = ?',
          variables: [
            Variable.withString(projectId),
            Variable.withString(designRevisionId),
            Variable.withString(nodeKey.sha256),
          ],
        )
        .getSingleOrNull();
    if (row == null) return null;
    final decoded = PowerNodeKeyV2.decode(
      row.read<String>('logical_node_key_json'),
    );
    if (decoded != nodeKey) {
      throw const PowerRuntimeStorageException('ELV4_POINTER_HASH_COLLISION');
    }
    return _StoredPointer(
      state: _pointerState(row.read<String>('state')),
      generation: row.read<int>('generation'),
      evaluationId: row.readNullable<String>('evaluation_id'),
    );
  }

  Future<_RevisionToken> _requireRevision({
    required String projectId,
    required String designRevisionId,
    required bool requireWorking,
    bool inputChangedOnMismatch = false,
  }) async {
    final row = await database
        .customSelect(
          'SELECT state, revision FROM project_design_revisions '
          'WHERE id = ? AND project_id = ? AND deleted_at IS NULL',
          variables: [
            Variable.withString(designRevisionId),
            Variable.withString(projectId),
          ],
        )
        .getSingleOrNull();
    if (row == null) {
      if (inputChangedOnMismatch) _inputChanged('REVISION_MISSING');
      throw const PowerRuntimeStorageException('ELV4_REVISION_NOT_FOUND');
    }
    final state = row.read<String>('state');
    if (requireWorking && state != 'WORKING') {
      if (inputChangedOnMismatch) _inputChanged('REVISION_NOT_WORKING');
      throw PowerRuntimeStorageException('ELV4_REVISION_NOT_WORKING', {
        'state': state,
      });
    }
    return _RevisionToken(state: state, revision: row.read<int>('revision'));
  }
}

final class _StoredPointer {
  const _StoredPointer({
    required this.state,
    required this.generation,
    required this.evaluationId,
  });

  final PowerPointerState state;
  final int generation;
  final String? evaluationId;
}

final class _RevisionToken {
  const _RevisionToken({required this.state, required this.revision});

  final String state;
  final int revision;
}

Map<String, Object?> _publicationEnvelope(
  PowerEvaluationEvidence evidence,
  PowerConsumedInput consumedInput,
) => {
  'schema': 'electra.elv4-published-evaluation.v1',
  'evidence': evidence.toMap(),
  'consumedInput': consumedInput.fingerprintPayload,
  'dependencyKeys': consumedInput.dependencyKeys,
};

void _validateEvidenceConsumedInput(
  PowerEvaluationEvidence evidence,
  PowerConsumedInput consumedInput,
) {
  if (evidence.algorithmVersion != consumedInput.algorithmVersion ||
      evidence.inputSchemaVersion != consumedInput.inputSchemaVersion ||
      evidence.numericPolicyVersion != consumedInput.numericPolicyVersion ||
      evidence.inputFingerprint != consumedInput.inputFingerprint) {
    _inputChanged('EVIDENCE_CONSUMED_INPUT_MISMATCH');
  }
  final evidenceDependencies =
      evidence.dependencies.map((value) => value.encode()).toList()..sort();
  final consumedDependencies =
      consumedInput.evaluations.map((value) => value.logicalNodeKey).toList()
        ..sort();
  if (canonicalEngineeringJsonV1(evidenceDependencies) !=
      canonicalEngineeringJsonV1(consumedDependencies)) {
    _inputChanged('EVALUATION_DEPENDENCY_SET_MISMATCH');
  }
}

void _requireNodeRevision(PowerNodeKeyV2 nodeKey, String designRevisionId) {
  if (nodeKey.revisionId != designRevisionId) {
    throw const PowerRuntimeStorageException('ELV4_POINTER_REVISION_MISMATCH');
  }
}

Never _inputChanged(String reason) => throw PowerRuntimeStorageException(
  'ELV4_RESULT_INPUT_CHANGED',
  {'reason': reason},
);

PowerPointerState _pointerState(String value) => switch (value) {
  'CURRENT' => PowerPointerState.current,
  'STALE' => PowerPointerState.stale,
  _ => throw const PowerRuntimeStorageException('ELV4_POINTER_STATE_CORRUPT'),
};

String _dependencyRefType(PowerDependencyRefType value) => switch (value) {
  PowerDependencyRefType.fact => 'FACT',
  PowerDependencyRefType.evaluation => 'EVALUATION',
};

String _processCode(PowerProcessCode value) => switch (value) {
  PowerProcessCode.pwr01 => 'ELV-PWR-01',
  PowerProcessCode.pwr02 => 'ELV-PWR-02',
  PowerProcessCode.pwr03 => 'ELV-PWR-03',
  PowerProcessCode.pwr04 => 'ELV-PWR-04',
  PowerProcessCode.pwr05 => 'ELV-PWR-05',
  PowerProcessCode.pwr06 => 'ELV-PWR-06',
};

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
