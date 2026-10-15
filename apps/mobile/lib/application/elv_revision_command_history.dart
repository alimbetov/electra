enum ElvRevisionHistoryState { applied, undone, redoAbandoned }

enum ElvRevisionHistoryExecutionKind { original, undo, redo }

/// Immutable business-aggregate evidence referenced by RM08 history rows.
/// Hash-only history is deliberately insufficient for replay verification.
final class ElvRevisionAggregateEvidence {
  ElvRevisionAggregateEvidence({
    required String evidenceRef,
    required String projectId,
    required String designRevisionId,
    required String aggregateKind,
    required String aggregateId,
    required String canonicalPayloadJson,
    required String payloadSha256,
  }) : evidenceRef = _text(evidenceRef, 'evidenceRef'),
       projectId = _text(projectId, 'projectId'),
       designRevisionId = _text(designRevisionId, 'designRevisionId'),
       aggregateKind = _text(aggregateKind, 'aggregateKind').toUpperCase(),
       aggregateId = _text(aggregateId, 'aggregateId'),
       canonicalPayloadJson = _text(
         canonicalPayloadJson,
         'canonicalPayloadJson',
       ),
       payloadSha256 = _sha256(payloadSha256, 'payloadSha256');

  final String evidenceRef;
  final String projectId;
  final String designRevisionId;
  final String aggregateKind;
  final String aggregateId;
  final String canonicalPayloadJson;
  final String payloadSha256;
}

/// Durable revision-local history operation. Both forward and inverse complete
/// canonical command payloads are retained so restart undo/redo never rebuilds
/// business intent from hashes or presentation state.
final class ElvRevisionCommandHistoryOperation {
  ElvRevisionCommandHistoryOperation({
    required String projectId,
    required String designRevisionId,
    required this.sequence,
    required String originalCommandId,
    required this.state,
    required String forwardCommandType,
    required String forwardCommandSchema,
    required String forwardCanonicalPayloadJson,
    required String forwardPayloadSha256,
    required String inverseCommandType,
    required String inverseCommandSchema,
    required String inverseCanonicalPayloadJson,
    required String inversePayloadSha256,
    required String beforeAggregateEvidenceRef,
    required String beforeAggregateHash,
    required String afterAggregateEvidenceRef,
    required String afterAggregateHash,
    required this.cursorGeneration,
    required Iterable<String> affectedIds,
  }) : projectId = _text(projectId, 'projectId'),
       designRevisionId = _text(designRevisionId, 'designRevisionId'),
       originalCommandId = _text(originalCommandId, 'originalCommandId'),
       forwardCommandType =
           _text(forwardCommandType, 'forwardCommandType').toUpperCase(),
       forwardCommandSchema = _text(
         forwardCommandSchema,
         'forwardCommandSchema',
       ),
       forwardCanonicalPayloadJson = _text(
         forwardCanonicalPayloadJson,
         'forwardCanonicalPayloadJson',
       ),
       forwardPayloadSha256 = _sha256(
         forwardPayloadSha256,
         'forwardPayloadSha256',
       ),
       inverseCommandType =
           _text(inverseCommandType, 'inverseCommandType').toUpperCase(),
       inverseCommandSchema = _text(
         inverseCommandSchema,
         'inverseCommandSchema',
       ),
       inverseCanonicalPayloadJson = _text(
         inverseCanonicalPayloadJson,
         'inverseCanonicalPayloadJson',
       ),
       inversePayloadSha256 = _sha256(
         inversePayloadSha256,
         'inversePayloadSha256',
       ),
       beforeAggregateEvidenceRef = _text(
         beforeAggregateEvidenceRef,
         'beforeAggregateEvidenceRef',
       ),
       beforeAggregateHash = _sha256(
         beforeAggregateHash,
         'beforeAggregateHash',
       ),
       afterAggregateEvidenceRef = _text(
         afterAggregateEvidenceRef,
         'afterAggregateEvidenceRef',
       ),
       afterAggregateHash = _sha256(afterAggregateHash, 'afterAggregateHash'),
       affectedIds = List.unmodifiable(
         affectedIds.map((value) => _text(value, 'affectedId')).toSet().toList()
           ..sort(),
       ) {
    if (sequence < 1) {
      throw ArgumentError.value(sequence, 'sequence', 'Must be >= 1.');
    }
    if (cursorGeneration < 1) {
      throw ArgumentError.value(
        cursorGeneration,
        'cursorGeneration',
        'Must be >= 1.',
      );
    }
    if (this.affectedIds.isEmpty) {
      throw ArgumentError('History operation requires affected ids.');
    }
  }

  final String projectId;
  final String designRevisionId;
  final int sequence;
  final String originalCommandId;
  final ElvRevisionHistoryState state;
  final String forwardCommandType;
  final String forwardCommandSchema;
  final String forwardCanonicalPayloadJson;
  final String forwardPayloadSha256;
  final String inverseCommandType;
  final String inverseCommandSchema;
  final String inverseCanonicalPayloadJson;
  final String inversePayloadSha256;
  final String beforeAggregateEvidenceRef;
  final String beforeAggregateHash;
  final String afterAggregateEvidenceRef;
  final String afterAggregateHash;
  final int cursorGeneration;
  final List<String> affectedIds;

  bool get undoEligible => state == ElvRevisionHistoryState.applied;
  bool get redoEligible => state == ElvRevisionHistoryState.undone;
}

final class ElvRevisionCommandHistoryCursor {
  ElvRevisionCommandHistoryCursor({
    required String projectId,
    required String designRevisionId,
    required this.generation,
    required this.headSequence,
    required String branchId,
  }) : projectId = _text(projectId, 'projectId'),
       designRevisionId = _text(designRevisionId, 'designRevisionId'),
       branchId = _text(branchId, 'branchId') {
    if (generation < 1) {
      throw ArgumentError.value(generation, 'generation', 'Must be >= 1.');
    }
    if (headSequence < 0) {
      throw ArgumentError.value(headSequence, 'headSequence', 'Must be >= 0.');
    }
  }

  final String projectId;
  final String designRevisionId;
  final int generation;
  final int headSequence;
  final String branchId;
}

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
