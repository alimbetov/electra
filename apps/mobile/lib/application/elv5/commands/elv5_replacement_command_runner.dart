import 'dart:convert';

import 'package:engineering_core/engineering_core_elv5.dart';

import '../../elv_write_unit_of_work.dart';
import '../persistence/elv5_replacement_persistence.dart';
import '../wire/elv5_wire_command.dart';

final class Elv5ReplacementCommandException implements Exception {
  const Elv5ReplacementCommandException(this.code, [this.details = const {}]);

  final String code;
  final Map<String, Object?> details;

  @override
  String toString() => 'Elv5ReplacementCommandException($code, $details)';
}

final class Elv5PreparedReplacement {
  Elv5PreparedReplacement({
    required Map<String, int> actualRowRevisions,
    required this.reviewedImpactFingerprint,
    required Set<String> staleNodeKeySha256s,
    required Iterable<String> affectedIds,
    required this.beforeAggregate,
    required this.inverseCommandType,
    required this.inverseCommandSchema,
    required this.inverseCanonicalPayloadJson,
    required this.inversePayloadSha256,
  }) : actualRowRevisions = Map.unmodifiable(actualRowRevisions),
       staleNodeKeySha256s = Set.unmodifiable(staleNodeKeySha256s),
       affectedIds = List.unmodifiable(affectedIds.toSet());

  final Map<String, int> actualRowRevisions;
  final String reviewedImpactFingerprint;
  final Set<String> staleNodeKeySha256s;
  final List<String> affectedIds;
  final Elv5AggregateEvidenceDraft beforeAggregate;
  final String inverseCommandType;
  final String inverseCommandSchema;
  final String inverseCanonicalPayloadJson;
  final String inversePayloadSha256;
}

final class Elv5AppliedReplacement {
  const Elv5AppliedReplacement({
    required this.logicalResultJson,
    required this.afterAggregate,
  });

  final String logicalResultJson;
  final Elv5AggregateEvidenceDraft afterAggregate;
}

final class Elv5ReplacementRunResult {
  const Elv5ReplacementRunResult({
    required this.logicalResultJson,
    required this.replayed,
  });

  final String logicalResultJson;
  final bool replayed;
}

typedef Elv5PrepareReplacement<S extends Elv5ReplacementWriteSession> =
    Future<Elv5PreparedReplacement> Function(
      S session,
      Elv5WireCommandEnvelope command,
    );

typedef Elv5ApplyReplacement<S extends Elv5ReplacementWriteSession> =
    Future<Elv5AppliedReplacement> Function(
      S session,
      Elv5WireCommandEnvelope command,
      Elv5PreparedReplacement prepared,
    );

/// Shared execution protocol for the 15 ELV5 replacement/mutation operations.
///
/// Strict decoding happens before this runner. Everything from durable replay
/// lookup through revision CAS, invalidation, history and ledger persistence is
/// executed inside one transaction owned by [unitOfWork].
final class Elv5ReplacementCommandRunner<
  S extends Elv5ReplacementWriteSession
> {
  Elv5ReplacementCommandRunner({
    required this.unitOfWork,
    required this.originDeviceId,
    DateTime Function()? now,
  }) : _now = now ?? (() => DateTime.now().toUtc());

  final ElvWriteUnitOfWork<S> unitOfWork;
  final String originDeviceId;
  final DateTime Function() _now;

  Future<Elv5ReplacementRunResult> run(
    Elv5WireCommandEnvelope command, {
    required Elv5PrepareReplacement<S> prepare,
    required Elv5ApplyReplacement<S> apply,
  }) => unitOfWork.run((session) async {
    final requestHash = command.normalizedRequestSha256;
    final replay = await session.commandLedger.find(
      command.projectId,
      command.commandId,
    );
    if (replay != null) {
      if (replay.commandType != command.operation ||
          replay.payloadSchemaVersion != command.payloadSchemaVersion ||
          replay.normalizedPayloadSha256 != requestHash) {
        throw Elv5ReplacementCommandException(
          'ELV5_COMMAND_ID_PAYLOAD_CONFLICT',
          {'commandId': command.commandId},
        );
      }
      return Elv5ReplacementRunResult(
        logicalResultJson: replay.logicalResultJson,
        replayed: true,
      );
    }

    final revision = await session.revisions.load(
      projectId: command.projectId,
      designRevisionId: command.designRevisionId,
    );
    if (revision == null) {
      throw Elv5ReplacementCommandException('ELV5_DESIGN_REVISION_NOT_FOUND', {
        'designRevisionId': command.designRevisionId,
      });
    }
    if (!revision.working) {
      throw Elv5ReplacementCommandException('ELV5_DESIGN_REVISION_READ_ONLY', {
        'designRevisionId': command.designRevisionId,
        'state': revision.state,
      });
    }
    if (revision.rowRevision != command.expectedDesignRowRevision) {
      throw Elv5ReplacementCommandException('ELV5_DESIGN_REVISION_CONFLICT', {
        'expected': command.expectedDesignRowRevision,
        'actual': revision.rowRevision,
      });
    }

    final prepared = await prepare(session, command);
    if (!_sameIntMap(command.expectedRows, prepared.actualRowRevisions)) {
      throw Elv5ReplacementCommandException('ELV5_EXPECTED_ROWS_CONFLICT', {
        'expected': command.expectedRows,
        'actual': prepared.actualRowRevisions,
      });
    }
    if (prepared.reviewedImpactFingerprint !=
        command.reviewedImpactFingerprint) {
      throw const Elv5ReplacementCommandException(
        'ELV5_REVIEWED_IMPACT_CONFLICT',
      );
    }

    final applied = await apply(session, command, prepared);

    if (prepared.staleNodeKeySha256s.isNotEmpty) {
      await session.pointers.markStaleBulk(
        projectId: command.projectId,
        designRevisionId: command.designRevisionId,
        logicalNodeKeySha256s: prepared.staleNodeKeySha256s,
        updatedAtUtc: _now(),
      );
    }

    final revisionAdvanced = await session.revisions.compareAndBump(
      projectId: command.projectId,
      designRevisionId: command.designRevisionId,
      expectedRevision: command.expectedDesignRowRevision,
      updatedAtUtc: _now(),
    );
    if (!revisionAdvanced) {
      throw const Elv5ReplacementCommandException(
        'ELV5_DESIGN_REVISION_COMMIT_CAS_FAILED',
      );
    }

    const encoder = Elv5CanonicalJsonV1();
    final forwardCanonical = utf8.decode(
      encoder.encode(command.toMap()),
      allowMalformed: false,
    );
    await session.history.appendOriginal(
      Elv5HistoryAppend(
        projectId: command.projectId,
        designRevisionId: command.designRevisionId,
        originalCommandId: command.commandId,
        forwardCommandType: command.operation,
        forwardCommandSchema: command.schema,
        forwardCanonicalPayloadJson: forwardCanonical,
        forwardPayloadSha256: requestHash,
        inverseCommandType: prepared.inverseCommandType,
        inverseCommandSchema: prepared.inverseCommandSchema,
        inverseCanonicalPayloadJson: prepared.inverseCanonicalPayloadJson,
        inversePayloadSha256: prepared.inversePayloadSha256,
        before: prepared.beforeAggregate,
        after: applied.afterAggregate,
        affectedIds: prepared.affectedIds,
        createdAtUtc: _now(),
      ),
    );

    final committedAt = _now();
    await session.commandLedger.save(
      ElvCommandLedgerEntry(
        projectId: command.projectId,
        commandId: command.commandId,
        commandType: command.operation,
        payloadSchemaVersion: command.payloadSchemaVersion,
        normalizedPayloadSha256: requestHash,
        outcomeKind: 'SUCCESS',
        logicalResultJson: applied.logicalResultJson,
        createdAt: committedAt,
        committedAt: committedAt,
        originDeviceId: originDeviceId,
      ),
    );

    return Elv5ReplacementRunResult(
      logicalResultJson: applied.logicalResultJson,
      replayed: false,
    );
  });

  bool _sameIntMap(Map<String, int> left, Map<String, int> right) {
    if (left.length != right.length) return false;
    for (final entry in left.entries) {
      if (right[entry.key] != entry.value) return false;
    }
    return true;
  }
}
