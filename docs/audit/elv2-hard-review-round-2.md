# ELV2 Hard Review — Round 2

Status: remediation complete — final exact-SHA gate pending  
Original ELV2 closure SHA: `179f11d8afcbcf433466f4cdb34b60a993a13167`  
Audit branch: `audit/elv2-hard-review-round-2`  
Source PR: #7  
Remediation specification: `docs/product/elv2-round2-remediation-specification.md`

## Purpose

Round 2 treated the P1–P7 closure as an assertion to disprove. Confirmed defects were required to receive regression evidence, a bounded remediation, targeted verification, and a final full exact-SHA gate. ELV3 remained out of scope throughout.

## Final finding ledger

| ID | Severity | Resolution |
| --- | --- | --- |
| R2-001 | HIGH | CLOSED — tracked `.dart_tool/**` / `build/**` removed; ignore policy and tracked-path CI guard added |
| R2-002 | HIGH | CLOSED — one canonical engineering code identity now governs catalog/profile/port/interface/P5/P6 matching |
| R2-003 | HIGH | CLOSED — P6 topology validation snapshot now resolves inside the owning adoption transaction |
| R2-004 | MEDIUM | CLOSED — ambiguous normalized explicit port mappings are rejected before Map collapse |
| R2-005 | MEDIUM | CLOSED — P5 exposes deterministic internal mapping dependency IDs and counts them as project-graph impact |
| R2-006 | HIGH | CLOSED — P6 now proves current and candidate durable catalog row/payload/frozen-binding provenance symmetry; same-edition exact aggregate is zero-write no-op |

Open severity after remediation:

```text
BLOCKER  0
HIGH     0
MEDIUM   0
LOW      0
```

## Regression-first evidence

### R2-001 — repository hygiene

Regression commit: `04cd3d4c89f1d7dd7260b2d85c3a50c530ec5996`  
Regression run: `38505562299` — `Reject tracked generated artifacts` failed on the polluted baseline as intended.

Remediation:

- root `.gitignore` rejects transient Flutter/Dart state;
- `scripts/ci/check-no-generated-artifacts.sh` checks Git-tracked paths, not filesystem existence;
- `apps/mobile/.dart_tool/**` and `apps/mobile/build/**` removed from source history on the remediation branch;
- source-controlled Drift generated code under `lib/**` remains intentional.

### R2-002 — canonical engineering identity

Regression: `engineering_reference_identity_round2_test.dart` exposed profile aliases such as `CAMERA` / ` camera `.

Remediation commits include:

- `8147524717030abacdc81806b1fba3a08dc426b6` — canonical profile identity and lookup;
- `c8229989f0771868e204d560a84f82851094278d` — identity symmetry across catalog code, profile code, port template code, interface-binding keys, P5 matching and P6 command identity.

Invariant:

```text
normalizeEngineeringReferenceCode(value) = value.trim().toUpperCase()
```

New publishable editions must use canonical logical codes; historical serialized payloads are not silently rewritten.

### R2-004 — explicit migration mapping ambiguity

Regression: `engineering_reference_adoption_command_round2_test.dart` proves aliases such as `eth` and ` ETH ` cannot silently collapse.

Remediation commit: `0980c79b5d2e0d1f3bdbb620d11882c37f3f45e4`.

The command validates raw source/target entries before constructing the immutable normalized mapping and rejects duplicate canonical source or target codes.

### R2-005 — P5 internal dependency visibility

Regression: `engineering_reference_revision_preview_round2_test.dart` covers an internal-mapping-only dependency.

Remediation commit: `28bdded1d8b4b51de97acf01fce2461ef13b4247`.

P5 now exposes:

```text
internalMappingIds
affectedInternalMappingIds
```

and `affectsProjectGraph` is true for connections, topology groups, or internal mappings.

### R2-003 — P6 transaction-owned graph truth

Regression: `engineering_reference_adoption_transaction_boundary_round2_test.dart` asserts that the topology validation snapshot is not loaded before the owner transaction.

Targeted verification run: `38506630642` — transaction boundary, connection safety, stale review, rollback points, four disciplines and SQLite restart passed.

Commit-time sequence is now:

```text
BEGIN transaction
  -> read current binding/catalog/system/ports/graph
  -> compute current graph fingerprint
  -> reject stale review
  -> build/load validation topology inside the same owning transaction
  -> P2 + migration + graph compatibility validation
  -> mutate ports/binding/ledger
  -> postconditions
COMMIT
```

### R2-006 — current/candidate provenance and same-edition semantics

Baseline regression proved that corrupting the current durable catalog row version could previously allow adoption.

Regression: `engineering_reference_adoption_provenance_round2_test.dart`.

Remediation commit: `54b5792a711d02ceb1355ad746870a0bbb0cb630`.

Targeted provenance/adoption suite passed 16/16 cases, including:

- current durable row/version drift rejects with zero mutation;
- candidate row/payload provenance symmetry;
- exact frozen profile equality against immutable current catalog payload;
- same exact edition + exact aggregate => deterministic zero-write no-op;
- connected reused-port incompatibility;
- reviewed v2 cannot silently switch to later imported v3;
- transaction-owned topology validation;
- all adoption rollback failure points;
- CCTV/LAN/ACS/FIRE adoption and SQLite restart.

## R2.2 — P2 adversarial re-review

Result: **NO NEW FINDING**.

Existing tests prove:

- one engine for CCTV/LAN/ACS/FIRE;
- `ERROR > UNRESOLVED > WARNING > COMPATIBLE` behavior;
- missing required evidence remains unresolved;
- malformed/non-finite placement evidence fails closed;
- exact mounting-pair semantics;
- legacy and malformed-defined constraints do not become compatible;
- IP classes containing unknown `X` evidence remain unresolved when needed;
- topology pre-placement scope is intentionally shape/role only.

Real degree/branch/loop/order constraints remain persisted-graph responsibilities by contract.

## R2.3 — P3 stale UI/evidence re-review

Result: **NO NEW SAFETY FINDING**.

Evidence:

- palette selection is read-only;
- exact project/system/catalog/profile editions are pinned;
- missing exact topology edition is unresolved;
- geometry/surface changes invalidate candidate facts;
- legacy/deprecated profiles cannot bypass P4 commit-time validation;
- P4 independently reloads durable project/room/surface/system/catalog state and reruns compatibility.

UI preview remains advisory; durable state is authoritative.

## R2.4 — P4 atomic placement/history/idempotency re-review

Result: **NO NEW FINDING**.

Evidence already covers:

- same-operation concurrency convergence;
- durable replay after SQLite reopen;
- fault injection rollback at all aggregate checkpoints;
- downstream topology dependency blocks undo;
- redo revalidates current durable placement context;
- placement/adoption ledger namespaces remain distinct.

### P4 history after P6 adoption

Classified **REJECTED as a defect**.

`_historyTransition()` reconstructs the current aggregate and canonical-compares it to the exact P4 `aggregateSnapshot` stored in the operation ledger before performing undo/redo. A successful P6 adoption changes binding/port provenance, so the comparison fails with `historyConflict`; history cannot silently restore stale pre-adoption engineering provenance.

## Open target classification

All Round-2 targets are now classified:

1. **Catalog soft-delete / immutable-edition lifecycle — REJECTED as current defect.** No public catalog delete/archive workflow exists; import is immutable. Re-audit when catalog archival is introduced.
2. **Normalized catalog/interface/protocol identity symmetry — CLOSED by R2-002 hardening.** Catalog/profile/port/interface-binding codes use one canonical identity policy; reference-vocabulary families already validate canonical code syntax.
3. **P4/P6 same-operation concurrency — REJECTED as unresolved defect.** P4 concurrent same-operation test converges; P6 durable ledger provides restart/replay idempotency and SQLite transaction serialization.
4. **P4 history after P6 adoption — REJECTED as defect.** Exact aggregate snapshot comparison fails closed with `historyConflict` after adoption changes provenance.
5. **Candidate/current catalog row-vs-payload provenance — CONFIRMED as R2-006 and CLOSED.**
6. **P5 assembly dependency completeness — REJECTED as current port-migration defect.** `ComponentAssembly` members reference component identity/role, not ELV port identity; current P6 port migration cannot create a dangling assembly-port reference.
7. **Remote endpoint mutation with stable connection ID — REJECTED as defect.** P5/P6 graph fingerprints serialize full connection payload, so endpoint/profile mutation under a stable ID changes the reviewed fingerprint.
8. **P6 same-edition no-op semantics — CLOSED by R2-006.** Exact aggregate returns zero-write deterministic result; provenance/port drift rejects.
9. **Stale/unresolved P5/P6 UI presentation — REJECTED as merge-blocking safety defect.** No UI state is trusted at commit; P4/P6 repositories re-read durable state and fail closed. A future richer revision/adoption UI remains product work, not an ELV2 persistence-safety gap.
10. **Restart test independence — REJECTED as defect.** P4/P6 acceptance closes and reopens SQLite persistence and reconstructs repositories; no global engineering-state cache participates in correctness.
11. **Generated-source policy / CI guard authenticity — CLOSED by R2-001.** Guard checks tracked Git paths before toolchain generation; transient outputs may exist in CI workspace without becoming source history.

## R2.7 — four-discipline re-acceptance

The Round-2 targeted suites preserve the existing four-discipline acceptance:

| Discipline | Canonical profile | Placement | Frozen binding | Ports | P5/P6 | Restart |
| --- | --- | --- | --- | --- | --- | --- |
| CCTV | CAMERA | PASS | PASS | ETH | PASS | PASS |
| LAN | OUTLET | PASS | PASS | ETH | PASS | PASS |
| ACS | READER | PASS | PASS | BUS | PASS | PASS |
| FIRE | DETECTOR | PASS | PASS | IN + OUT | PASS | PASS |

No Round-2 remediation introduces ELV3 routing, cable-run, pathway, tray/conduit or physical-route semantics.

## Final acceptance gate

Repository remediation is complete. This document is intentionally committed **before** the final gate so that no documentation-only commit invalidates the evidence SHA afterward.

Round-2 becomes accepted for merge only when:

```text
final audit head
   -> generated-artifact guard PASS
   -> Drift generation PASS
   -> mobile formatting PASS
   -> mobile analyze PASS
   -> full mobile tests PASS
   -> engineering_core formatting PASS
   -> engineering_core analyze PASS
   -> full engineering_core tests PASS
   -> fast-forward feat/flutter-elv2-profile-constraints
   -> normal push workflow GREEN on exact feat SHA
   -> normal PR-triggered workflow GREEN on the same feat SHA
```

The final run IDs and exact merge SHA are recorded in PR #7 metadata after the gate; the repository is not modified after that SHA is accepted.
