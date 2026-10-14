# ELV2-P4 implementation closure audit

Status: **implementation complete, exact-SHA gate pending**  
Branch: `feat/flutter-elv2-profile-constraints`  
Normative contract: `docs/product/elv2-p4-atomic-placement-contract.md` v1.3

## 1. Executive resolution

The branch now implements the complete P4 durable placement vertical rather than only P4.4.

The effective transaction is:

```text
PlaceEngineeringProfileCommand
        ↓
operation/fingerprint conflict check
        ↓
exact hierarchy + system/family + catalog/profile resolution
        ↓
commit-time PlacementCandidateContext reconstruction
        ↓
P2 revalidation
        ↓
BEGIN AppDatabase.transaction
        ↓
canonical ComponentInstance
        ↓
DEVICE EngineeringSystemComponentMembership
        ↓
profile-derived EngineeringPort set
        ↓
frozen ComponentReferenceBinding
        ↓
aggregate postconditions
        ↓
COMPLETED EngineeringPlacementOperation
        ↓
COMMIT
        ↓
one session history entry
```

No independently committing `saveComponent()`, `assign()`, `bind()` or `savePort()` method is composed into the P4 write path.

## 2. P4.1–P4.13 coverage

| Step | Resolution | Evidence in implementation |
| --- | --- | --- |
| P4.1 command contract | COMPLETE | immutable command/result/failure model, DEVICE role, canonical fingerprint v1 |
| P4.2 transaction owner | COMPLETE | `DriftEngineeringPlacementRepository` owns the top-level Drift transaction and operation ledger |
| P4.3 component | COMPLETE | canonical `system-elv-canonical-device / v1`, hierarchy and physical placement validation |
| P4.4 membership | COMPLETE | transaction-scoped insert-only DEVICE membership with project/family/discipline guards |
| P4.5 frozen binding | COMPLETE | exact catalog/version/profile snapshot plus reviewed placement command and exact port ids |
| P4.6 persisted ports | COMPLETE | profile-template instantiation with template/interface provenance and exact ids |
| P4.7 commit P2 | COMPLETE | durable state reloaded, pinned topology resolved, P2 rerun, non-compatible states rejected |
| P4.8 rollback | COMPLETE | test seam covers all durable failure points; table-state equality proves rollback |
| P4.9 idempotency/concurrency | COMPLETE | durable ledger replay/conflict/UNDONE policy and concurrent same-operation convergence |
| P4.10 undo/redo | COMPLETE | aggregate soft-retirement/reactivation, audit revisions, history conflict guards, exact-id redo |
| P4.11 four disciplines | COMPLETE | CAMERA, OUTLET, READER/LOCK and DETECTOR share one discipline-agnostic path |
| P4.12 restart | COMPLETE | four-discipline SQLite close/reopen plus same-operation replay without duplicates |
| P4.13 exact-SHA CI | PENDING | final user-authored closure head must pass both push and PR workflows |

## 3. Contract invariants verified

The implementation now enforces the following before a successful commit:

1. exact active project/floor/room/SurfacePatch ownership;
2. exact EngineeringSystem and pinned family edition;
3. profile discipline compatible with the selected engineering-system family;
4. exact catalog id + catalog version + profile code, with no `latest` fallback;
5. canonical physical definition `system-elv-canonical-device / ELV_CANONICAL_DEVICE / 1`;
6. canonical membership role `DEVICE`;
7. P2 result must be `COMPATIBLE`; deprecated, legacy-unresolved, forbidden and unresolved states do not commit;
8. one active component and one active membership for the placement aggregate;
9. exact profile-template port count, ids, codes and interface/template provenance;
10. one frozen binding whose catalog/profile snapshot and `portIds` match persisted ports;
11. aggregate postconditions execute before the operation ledger is completed;
12. the `COMPLETED` operation result points to the same component, binding and port identities.

## 4. Rollback and history assurance

Failure injection exists at:

```text
afterOperationCheck
afterComponent
afterMembership
beforePort
afterPort
afterBinding
beforeOperationComplete
beforeCommit
```

The acceptance suite compares actual aggregate tables before/after failures rather than relying on SQLite change counters.

Undo is blocked when later engineering connections, internal mappings, topology groups, assemblies or other active component ownership would make retirement unsafe. Redo re-resolves current durable state and reruns P2 before reactivating the original identities.

## 5. Four-discipline and restart acceptance

The table-driven path covers:

```text
CCTV  -> CAMERA
LAN   -> OUTLET
ACS   -> READER (plus LOCK coverage)
FIRE  -> DETECTOR
```

For every canonical scenario the tests assert physical definition, DEVICE membership, frozen profile binding, exact port set/provenance and idempotent replay. The restart fixture closes the SQLite database, reopens it, compares the exact aggregate and then retries the same commands with zero duplicate mutation.

## 6. Defects found during closure audit

### C1 — CI analyzer blocker — FIXED

`apps/mobile/test/data/engineering_placement_repository_test.dart` retained an unused Drift import after P4 test extraction. The preceding head failed `flutter analyze` on that warning. The stale import has been removed without changing the test corpus.

### C2 — PR status text lag — DOCUMENTATION ONLY

PR #7 still describes P4.4 as NEXT even though the branch implementation has advanced through P4.12. This does not affect runtime behavior; PR metadata should be updated only after the final exact-SHA gate so it does not disturb the branch head.

### C3 — non-blocking editor wording

The P3/P4 feedback panel still uses the sentence `Preview only · no project changes saved.` even when the P4 placement action is available. The statement is true before confirmation but is less precise than `Nothing is saved until Place profile is confirmed.` This is a UX wording cleanup, not an engineering integrity blocker, and must not expand P4 scope.

## 7. Scope guard

No ELV3 cable/pathway/route behavior is introduced by P4. Existing routing code remains outside the canonical placement transaction.

Catalog revision impact/adoption/migration remains P5/P6.

## 8. Closure gate

P4 may be marked COMPLETE only when the final branch head produced by this closure work passes both normal workflow triggers on the same SHA:

```text
Drift generation              PASS
Mobile formatting             PASS
Mobile analyze                PASS
Mobile tests                  PASS
Engineering core formatting   PASS
Engineering core analyze      PASS
Engineering core tests        PASS
```

After that gate no branch commit is allowed before recording P4 as complete. PR metadata/comments may then be updated without changing the branch SHA.
