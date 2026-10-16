# P7 — Incremental dependencies and engineer workspace

Status: DESIGN DRAFT / RUNTIME NOT STARTED
Depends on: Design begins P1/P2; complete integration P3–P6.
Parent: [ELV5 design](../elv5-discipline-calculations-design-specification.md); [process contracts](process-contracts.md); [code-level runtime contract](code-level-runtime-contract.md).

Inherited implementation and mandatory new extensions: [baseline contract P7](implemented-baseline.md#p7); [pinned evidence](baseline.json). This contract supersedes the original design-only parent assumptions.

## Requirements and planned proof

| Requirement | Required implementation behavior | Planned acceptance |
|---|---|---|
| ELV5-P7-001 | Encode owner/scope-aware consumed dependency keys including missing inputs and membership sets | P7-T01 |
| ELV5-P7-002 | Invalidate exact old+new closures across discipline/shared-source boundaries | P7-T02 |
| ELV5-P7-003 | Guard publication with lifecycle/token/fingerprint and consumed pointer generation checks | P7-T03 |
| ELV5-P7-004 | Implement progressive per-discipline calculation cards with exact revision/scope/source provenance | P7-T04 |
| ELV5-P7-005 | Show full shared-project totals and selected discipline contribution without recalc filtering | P7-T05 |
| ELV5-P7-006 | Route preview/commit/replay/undo/redo and failed-draft retention through application services | P7-T06 |
| ELV5-P7-007 | Implement frozen historical/NOT_CAPTURED comparison and preserve scope-context generation in async reads | P7-T07 |
| ELV5-P7-008 | Cover compact/keyboard/focus/back/finding remediation and stale-versus-failed display | P7-T08 |

## Concrete contract

Technical fingerprint is the canonical consumed facts map, not the full captured project. A missing profile produces a dependency marker so later binding invalidates the blocked result. New set membership and disconnection use set keys and old closure, avoiding phantom/missing invalidation. Unrelated room labels and independent doors/links are required negative controls.

Canonical dependency families are code-owned and equivalent to:

```text
FACT/<owner>/<kind>/<id>/<field-or-membership>
SET/<owner>/<kind>/<scopeId>/<membershipKind>
POLICY/<policyCode>/<editionId>/<hash>
EVAL/<owner>/<nodeKey>/<evaluationId>/<outputHash>
POINTER/<owner>/<nodeKey>/<generation>
MISSING/<kind>/<expectedIdentity>
```

The runtime may encode these as typed values instead of strings, but canonical serialization must be deterministic for hashing/debugging. Free-text notes are never dependency keys.

`SET` dependencies are mandatory wherever insertion/removal can affect a result: stream subscriptions, recorder/recording membership, link sections, switch/panel ports, door roles, controller resources, fire loop devices/addresses and notification-circuit assignments. Depending only on currently present row IDs is insufficient because a newly inserted member would otherwise fail to invalidate a prior CURRENT/BLOCKED result.

Cross-owner ELV4 evidence dependencies store exact immutable evaluation ID, ELV4 node key/scope, input/output hash, algorithm/numeric version and consumed pointer generation. A discipline wrapper never records only `processCode=ELV-PWR-*` without the exact evidence identity used.

Registry DAG evaluation has no physical numerical feedback loop; it delegates bounded physical solving to ELV4. ELV5 results may depend on ELV4 evidence, but ELV4 source solving must not depend on ELV5 result pointers. Any proposed cross-owner edge that creates a cycle is rejected during registry validation.

### Capture and publication guard

Every long-running calculation uses the code-level `capture → pure run → guarded publish` contract.

Capture records:

- revision lifecycle/token;
- exact row revisions and set fingerprints;
- exact immutable policy editions;
- upstream evaluation IDs/hashes;
- consumed pointer generations;
- canonical input fingerprint.

Publish rechecks all of them. Any change yields `ELV5_CAPTURE_STALE` / pointer-generation conflict and does not write CURRENT. Evaluation insert, pointer batch CAS and reverse-index update are one short transaction.

Freeze wins against a late publisher. A process started before freeze may finish its pure calculation but publication after freeze returns conflict and cannot revive a pointer on the frozen working revision.

### Workspace projection

Card sequence: process summary → selected inputs/policy → affected equipment/path → calculation steps → findings → before/after. Retain viewport/selection/draft during navigation and conflicts. UI selects subject/scope; it does not mutate static canonical port values or calculate a smaller source budget.

Each process card consumes a projection that contains independent freshness/completion/assessment/execution state, required dimension results, exact scope/revision, structured steps/findings and provenance. A stale prior PASS must display as STALE PASS evidence, not as current success. An execution failure is distinct from current engineering FAIL.

Shared-source cards always display the full physical project total plus the selected discipline contribution from the same immutable ELV4 evidence. UI filtering may hide unrelated lines visually but cannot trigger a reduced source calculation and publish it as global evidence.

Frozen historical views use captured discipline section/evaluation refs. Pre-ELV5 snapshot returns `ELV5_NOT_CAPTURED`; it is never converted into CAPTURED_EMPTY/PASS. Async reads preserve the originating revision/scope generation so navigation cannot attach late results to another selected context.

## Exit

P7 runtime acceptance requires its numbered assertions at the same accepted source SHA and its prerequisite gates. This document is a design contract, not proof of source implementation.

## Audit refinements

Execution graph consumes structured `upstreamProcesses` only. Registered scope/subject binders resolve exact compatible physical/policy contexts, including complete segment sets for DESIGN consumers. Unknown process/binder, invalid scope or cycle rejects registry publication. Dependency notes are explanatory text and cannot be parsed as code.

P7 proof must include negative controls for unrelated mutations, missing-input-to-present-input invalidation, old+new replacement closure, shared-source fan-out and freeze/publication races using real pointer generations.
