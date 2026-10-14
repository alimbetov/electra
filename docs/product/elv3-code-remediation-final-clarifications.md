# Electra — ELV3 Code Remediation Final Clarifications

Status: AUTHORITATIVE CODE REMEDIATION CLARIFICATION / CLOSED  
Branch: `feat/flutter-elv3-physical-routing-design`  
Refines: `docs/product/elv3-code-implementation-remediation-cr01-cr16.md`

This document closes ambiguities discovered while independently re-reviewing the CR-01…CR-16 remediation. It wins over earlier code-level wording on conflict.

## FC-01 — phase-specific write sessions

The common write-session contract MUST NOT require future-phase stores during P1.

Base transaction scope:

```dart
abstract interface class ElvWriteSession {
  ElvCommandLedgerStore get commandLedger;
}

abstract interface class ElvWriteUnitOfWork<S extends ElvWriteSession> {
  Future<T> run<T>(Future<T> Function(S session) action);
}
```

Phase-specific sessions extend the base only when their phase starts.

P1:

```dart
abstract interface class ElvCableWriteSession extends ElvWriteSession {
  ElvCableWriteStore get cables;
  ElvReferenceReadStore get references;
  ElvCableDependencyStore get cableDependencies;
}
```

P2:

```dart
abstract interface class ElvAllocationWriteSession extends ElvWriteSession {
  ElvAllocationWriteStore get allocations;
  ElvCableReadStore get cables;
  ElvEngineeringTopologyReadStore get topology;
  ElvReferenceReadStore get references;
}
```

P3:

```dart
abstract interface class ElvRoutingWriteSession extends ElvWriteSession {
  ElvDesignRevisionWriteStore get designRevisions;
  ElvCanonicalRunWriteStore get canonicalRuns;
  ElvReusableRouteWriteStore get routes;
  ElvLegacyElectricalRoutingReadStore get legacyElectricalRouting;
  ElvSnapshotReadStore get snapshotInputs;
}
```

P4/P5 define analogous phase-specific sessions when implemented.

Concrete implementations:

```text
DriftElvCableWriteUnitOfWork
DriftElvAllocationWriteUnitOfWork
DriftElvRoutingWriteUnitOfWork
...
```

Each opens exactly one `AppDatabase.transaction(...)` and supplies only stores backed by that transaction context. No future-phase interface/table is required to compile P1.

## FC-02 — command ledger replay semantics

`CommandExecutionRecords.outcome_kind` supports:

```text
SUCCESS
REJECTED
```

Persist:

- SUCCESS after canonical writes and logical result are ready to commit;
- deterministic application/domain rejection when command processing reached a stable semantic result and the transaction can commit the ledger-only rejection.

Do NOT persist:

- SQLite I/O failure;
- process crash;
- failure-injection exception;
- transaction-aborted state;
- any result for which the transaction did not commit.

Replay rule:

```text
same (projectId, commandId) + same payload hash
  -> return persisted SUCCESS or REJECTED logical outcome verbatim

same key + different payload hash
  -> ELV_IDEMPOTENCY_CONFLICT
```

A rejected command with an obsolete `expectedRevision` is intentionally stable under the same commandId. A caller wishing to retry against a new revision issues a new commandId and new expectedRevision.

## FC-03 — exact P6 separation persistence

P6 v1 MUST persist explicit numeric separation evidence. It is not an optional input-only concept.

Create in P6:

```text
RouteSeparationEvidence
```

Canonical Drift table:

```dart
@DataClassName('RouteSeparationEvidenceRow')
class RouteSeparationEvidenceRecords extends Table with GeometryAuditColumns {
  TextColumn get id => text()();
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get designRevisionId =>
      text().references(ProjectDesignRevisions, #id)();
  TextColumn get subjectAType => text()();
  TextColumn get subjectAId => text()();
  TextColumn get subjectBType => text()();
  TextColumn get subjectBId => text()();
  RealColumn get distanceMm => real()();
  TextColumn get evidenceKind => text()();
  TextColumn get sourceRef => text().nullable()();
  TextColumn get lifecycleState => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
```

Stable domain table name for documentation/API is `RouteSeparationEvidenceRecords` to avoid collision with the domain type `RouteSeparationEvidence`.

Rules:

- evidence belongs to one `ProjectDesignRevision`;
- writes require WORKING revision;
- frozen snapshot schema from P6 onward embeds active evidence rows used by calculations;
- distance is finite and >= 0;
- subject pair is canonicalized for uniqueness: `(type,id)` lower tuple first lexicographically;
- at most one ACTIVE evidence row per `(designRevisionId, canonicalSubjectA, canonicalSubjectB)`;
- lifecycle is ACTIVE -> ARCHIVED;
- P6 never derives arbitrary numeric separation without this evidence.

Required partial unique index:

```sql
CREATE UNIQUE INDEX IF NOT EXISTS ux_elv_separation_active_pair
ON route_separation_evidence_records(
  design_revision_id,
  subject_a_type,
  subject_a_id,
  subject_b_type,
  subject_b_id
)
WHERE lifecycle_state = 'ACTIVE' AND deleted_at IS NULL;
```

Stable conflict code:

```text
ELV_SEPARATION_EVIDENCE_CONFLICT
```

Migration baseline is therefore:

```text
P1 -> 18
P2 -> 19
P3 -> 20
P4 -> 21
P5 -> 22
P6 -> 23  (RouteSeparationEvidenceRecords)
P7-P9 -> no schema bump by default
```

If prior schema versions advance before implementation, rebase monotonically while preserving this relative order.

## FC-04 — exact CableResourceDefinition validation ownership

P1 validates the complete immutable resource graph before catalog publication.

Required rules:

```text
identity normalized and unique
WHOLE_CABLE identity reserved exactly as __WHOLE_CABLE__
parent/child references resolve inside same CableDefinition
parent-child relationship is reciprocal
resource graph is acyclic
atomic resource has no child resources
allocatable composite is allowed only if resolver can reduce it to >=1 atomic descendant
all groupMembership codes normalized
TerminationPolicy allowedRoles normalized and unique
```

`CableResourceResolver` in P2 may assume a published CableDefinition already satisfies these structural rules; it still verifies runtime selection legality.

## FC-05 — route edit legacy validation boundary

Legacy route validation during shared geometry mutation MUST use the same domain calculation/validation path as the currently shipped electrical routing feature, not a second reimplementation in ELV3.

Data/application adapter:

```dart
abstract interface class LegacyElectricalRouteImpactValidator {
  Future<List<ElvFailure>> validateCandidate({
    required String projectId,
    required CableRoute candidateRoute,
    required List<LegacyElectricalRunImpact> dependents,
  });
}
```

Concrete implementation loads the required legacy geometry/circuit/junction context and invokes existing `CableRouteValidator`/`RoutingJunctionValidator` behavior. ELV3 only translates failures into stable impact-blocking errors.

## Closure

```text
phase-specific UoW/session compile order      CLOSED
ledger replay semantics                       CLOSED
P6 separation persistence/schema             CLOSED
P1 resource graph publication validation      CLOSED
legacy route validation reuse                 CLOSED
```
