import 'dart:convert';

import 'package:engineering_core/engineering_core_elv5.dart';

import '../../elv_write_unit_of_work.dart';
import '../commands/elv5_replacement_command_runner.dart';
import '../persistence/elv5_runtime_persistence.dart';
import '../wire/elv5_wire_command.dart';
import 'elv5_calculation_persistence.dart';
import 'elv5_calculation_runtime.dart';
import 'elv5_qualification_identity_source.dart';

final class Elv5CalculationResult {
  const Elv5CalculationResult({
    required this.replayed,
    required this.logicalResultJson,
  });

  final bool replayed;
  final String logicalResultJson;
}

/// P2 orchestration for CALCULATE_DISCIPLINE_PROCESS.
///
/// Capture and pure computation happen outside the publication transaction.
/// Publication is a short all-or-nothing transaction over immutable
/// evaluations, dependency markers, pointer CAS and the shared command ledger.
final class Elv5CalculationService {
  Elv5CalculationService({
    required this.registry,
    required this.publicationUnitOfWork,
    required this.originDeviceId,
    this.qualificationIdentitySource,
    DateTime Function()? now,
  }) : _now = now ?? (() => DateTime.now().toUtc());

  final Elv5ProcessCalculationRegistry registry;
  final Elv5CalculationWriteUnitOfWork publicationUnitOfWork;
  final String originDeviceId;
  final Elv5QualificationIdentitySource? qualificationIdentitySource;
  final DateTime Function() _now;

  Future<Elv5CalculationResult> execute(Elv5WireCommandEnvelope command) async {
    if (command.operation != 'CALCULATE_DISCIPLINE_PROCESS') {
      throw FormatException(
        'Unsupported calculation operation: ${command.operation}.',
      );
    }

    final preflightReplay = await publicationUnitOfWork.run(
      (session) =>
          session.commandLedger.find(command.projectId, command.commandId),
    );
    if (preflightReplay != null) {
      _verifyReplay(command, preflightReplay);
      return Elv5CalculationResult(
        replayed: true,
        logicalResultJson: preflightReplay.logicalResultJson,
      );
    }

    final requests = _requests(command);
    final captured = <Elv5CapturedProcess>[];
    final captureRevisions = <String, int>{};
    for (final request in requests) {
      final adapter = registry.require(request.processCode);
      final input = await adapter.capture(request);
      captured.add(input);
      captureRevisions[input.request.nodeKey.toCanonicalValue().toString()] =
          input.captureRevision;
    }

    final evaluations = <Elv5ProcessEvaluationCandidate>[];
    for (final input in captured) {
      final adapter = registry.require(input.request.processCode);
      var result = await adapter.execute(input);
      if (_nodeHash(result.nodeKey) != _nodeHash(input.request.nodeKey)) {
        throw StateError('ELV5_CALCULATION_NODE_IDENTITY_CHANGED');
      }
      if (result.inputFingerprint != input.inputFingerprint) {
        throw StateError('ELV5_CALCULATION_INPUT_FINGERPRINT_CHANGED');
      }
      final identity = qualificationIdentitySource?.forProcess(
        input.request.processCode,
      );
      if (identity != null) {
        result = result.withQualificationIdentity(identity);
      }
      evaluations.add(result);
    }
    evaluations.sort((a, b) => a.nodeKeySha256.compareTo(b.nodeKeySha256));

    return publicationUnitOfWork.run((session) async {
      final replay = await session.commandLedger.find(
        command.projectId,
        command.commandId,
      );
      if (replay != null) {
        _verifyReplay(command, replay);
        return Elv5CalculationResult(
          replayed: true,
          logicalResultJson: replay.logicalResultJson,
        );
      }

      final guard = await session.publicationGuards.loadRevision(
        projectId: command.projectId,
        designRevisionId: command.designRevisionId,
      );
      if (guard == null || !guard.working) {
        throw const Elv5ReplacementCommandException(
          'ELV5_DESIGN_REVISION_READ_ONLY',
        );
      }
      if (guard.rowRevision != command.expectedDesignRowRevision) {
        throw Elv5ReplacementCommandException('ELV5_DESIGN_REVISION_CONFLICT', {
          'expected': command.expectedDesignRowRevision,
          'actual': guard.rowRevision,
        });
      }
      for (final input in captured) {
        if (input.captureRevision != guard.rowRevision) {
          throw const Elv5ReplacementCommandException(
            'ELV5_CAPTURE_REVISION_STALE',
          );
        }
      }

      for (final input in captured) {
        if (!await session.publicationGuards.upstreamStillCurrent(
          projectId: command.projectId,
          designRevisionId: command.designRevisionId,
          generations: input.upstreamPointerGenerations,
        )) {
          throw const Elv5ReplacementCommandException(
            'ELV5_UPSTREAM_GENERATION_CONFLICT',
          );
        }
      }

      final pointerKeys = evaluations.map((e) => e.nodeKeySha256).toSet();
      final existingPointers = await session.pointers.loadPointersBulk(
        projectId: command.projectId,
        designRevisionId: command.designRevisionId,
        logicalNodeKeySha256s: pointerKeys,
      );
      for (final evaluation in evaluations) {
        final expected = _expectedPointerGeneration(
          command,
          evaluation.nodeKeySha256,
        );
        final actual =
            existingPointers[evaluation.nodeKeySha256]?.generation ?? 0;
        if (expected != actual) {
          throw Elv5ReplacementCommandException(
            'ELV5_POINTER_GENERATION_CONFLICT',
            {
              'node': evaluation.nodeKeySha256,
              'expected': expected,
              'actual': actual,
            },
          );
        }
      }

      for (final evaluation in evaluations) {
        await session.evaluations.appendEvaluation(
          evaluation.toRecord(projectId: command.projectId),
        );
        await session.dependencies.replaceNodeDependencies(
          projectId: command.projectId,
          designRevisionId: command.designRevisionId,
          logicalNodeKeySha256: evaluation.nodeKeySha256,
          markers: [
            ...evaluation.dependencies,
            _inputSelector(command, evaluation),
          ],
        );
      }

      for (final evaluation in evaluations) {
        if (evaluation.nodeKey.scope.scenarioKey != 'NONE') continue;
        final expected = _expectedPointerGeneration(
          command,
          evaluation.nodeKeySha256,
        );
        final published = await session.pointers.compareAndSet(
          Elv5PointerWrite(
            projectId: command.projectId,
            designRevisionId: command.designRevisionId,
            logicalNodeKeyJson: evaluation.nodeKeyJson,
            logicalNodeKeySha256: evaluation.nodeKeySha256,
            freshness: Elv5PointerFreshness.current,
            expectedGeneration: expected,
            evaluationId: evaluation.evaluationId,
            inputFingerprint: evaluation.inputFingerprint,
            outputSha256: evaluation.outputSha256,
            updatedAtUtc: _now(),
          ),
        );
        if (!published) {
          throw const Elv5ReplacementCommandException(
            'ELV5_POINTER_PUBLICATION_CAS_FAILED',
          );
        }
      }

      final logical = _logicalResult(command, evaluations);
      final committedAt = _now();
      await session.commandLedger.save(
        ElvCommandLedgerEntry(
          projectId: command.projectId,
          commandId: command.commandId,
          commandType: command.operation,
          payloadSchemaVersion: command.payloadSchemaVersion,
          normalizedPayloadSha256: command.normalizedRequestSha256,
          outcomeKind: 'SUCCESS',
          logicalResultJson: logical,
          createdAt: committedAt,
          committedAt: committedAt,
          originDeviceId: originDeviceId,
        ),
      );
      return Elv5CalculationResult(replayed: false, logicalResultJson: logical);
    });
  }

  Elv5DependencyMarker _inputSelector(
    Elv5WireCommandEnvelope command,
    Elv5ProcessEvaluationCandidate evaluation,
  ) {
    final key = <String, Object?>{
      'schema': 'electra.elv5-dependency-key.v1',
      'relationKind': 'SET',
      'domain': 'PROCESS_INPUT_SELECTOR',
      'subjectId':
          '${evaluation.nodeKey.processCode.wireCode}:${evaluation.nodeKey.subject.id}',
    };
    const encoder = Elv5CanonicalJsonV1();
    return Elv5DependencyMarker(
      projectId: command.projectId,
      designRevisionId: command.designRevisionId,
      dependencyKey: utf8.decode(encoder.encode(key)),
      dependencyKeySha256: encoder.sha256(key),
      logicalNodeKeySha256: evaluation.nodeKeySha256,
      relationKind: 'SET',
      updatedAtUtc: _now(),
    );
  }

  List<Elv5CalculationRequest> _requests(Elv5WireCommandEnvelope command) {
    final scopeMap = Map<String, Object?>.from(
      command.payload['scope']! as Map,
    );
    final scopeKind = Elv5ScopeKind.values.byName(
      (scopeMap['kind']! as String).toLowerCase(),
    );
    final scope = Elv5ScopeRef(
      kind: scopeKind,
      scopeId: scopeMap['scopeId']! as String,
      scenarioKey: scopeMap['scenarioKey']! as String,
    );
    final processCodes =
        (command.payload['processCodes']! as List)
            .cast<String>()
            .map(Elv5ProcessCode.parse)
            .toList();
    final subjects =
        (command.payload['subjects']! as List)
            .cast<Map>()
            .map(
              (value) => Elv5SubjectRef(
                kind: value['kind']! as String,
                id: value['id']! as String,
              ),
            )
            .toList();
    final requests = <Elv5CalculationRequest>[];
    for (final processCode in processCodes) {
      final descriptor = Elv5ProcessCatalog.require(processCode);
      if (!descriptor.legalScopes.contains(scope.kind)) {
        throw FormatException(
          '${processCode.wireCode} does not support ${scope.kind.name}.',
        );
      }
      for (final subject in subjects) {
        final node = Elv5EngineeringNodeKeyV3(
          designRevisionId: command.designRevisionId,
          scope: scope,
          processCode: processCode,
          subject: subject,
        );
        final nodeHash = _nodeHash(node);
        requests.add(
          Elv5CalculationRequest(
            projectId: command.projectId,
            designRevisionId: command.designRevisionId,
            scope: scope,
            processCode: processCode,
            subject: subject,
            expectedPointerGeneration: _expectedPointerGeneration(
              command,
              nodeHash,
            ),
          ),
        );
      }
    }
    requests.sort(
      (a, b) => _nodeHash(a.nodeKey).compareTo(_nodeHash(b.nodeKey)),
    );
    return requests;
  }

  int _expectedPointerGeneration(
    Elv5WireCommandEnvelope command,
    String nodeHash,
  ) {
    final generations = Map<String, Object?>.from(
      command.payload['expectedPointerGenerations']! as Map,
    );
    final value = generations[nodeHash];
    if (value is! int || value < 0) {
      throw FormatException(
        'Missing expected pointer generation for $nodeHash.',
      );
    }
    return value;
  }

  void _verifyReplay(
    Elv5WireCommandEnvelope command,
    ElvCommandLedgerEntry replay,
  ) {
    if (replay.commandType != command.operation ||
        replay.payloadSchemaVersion != command.payloadSchemaVersion ||
        replay.normalizedPayloadSha256 != command.normalizedRequestSha256) {
      throw Elv5ReplacementCommandException(
        'ELV5_COMMAND_ID_PAYLOAD_CONFLICT',
        {'commandId': command.commandId},
      );
    }
  }

  String _logicalResult(
    Elv5WireCommandEnvelope command,
    List<Elv5ProcessEvaluationCandidate> evaluations,
  ) {
    const encoder = Elv5CanonicalJsonV1();
    return utf8.decode(
      encoder.encode({
        'operation': command.operation,
        'evaluationCount': evaluations.length,
        'evaluations': [
          for (final evaluation in evaluations)
            {
              'nodeKeySha256': evaluation.nodeKeySha256,
              'evaluationId': evaluation.evaluationId,
              'evaluationIdentitySchema': evaluation.evaluationIdentitySchema,
              'qualificationIdentitySha256':
                  evaluation.qualificationIdentity?.canonicalSha256(),
              'outputSha256': evaluation.outputSha256,
              'assessment': evaluation.assessment.name.toUpperCase(),
              'completion': evaluation.completion.name.toUpperCase(),
              'execution': evaluation.execution.name.toUpperCase(),
              'publishedCurrent':
                  evaluation.nodeKey.scope.scenarioKey == 'NONE',
            },
        ],
      }),
      allowMalformed: false,
    );
  }

  String _nodeHash(Elv5EngineeringNodeKeyV3 key) =>
      const Elv5CanonicalJsonV1().sha256(key.toCanonicalValue());
}
