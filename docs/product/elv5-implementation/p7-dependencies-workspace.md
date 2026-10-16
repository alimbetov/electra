# P7 — Incremental dependencies, calculation scheduler and engineer workspace

Status: DESIGN HARDENED / RUNTIME NOT STARTED
Depends on: Design begins P1/P2; complete integration P3–P6.
Parent: [ELV5 design](../elv5-discipline-calculations-design-specification.md); [process contracts](process-contracts.md); [engineering primitives](engineering-primitives-contract.md); [schema 24](persistence-schema-contract.md); [production source blueprint](production-source-blueprint.md); [Flutter performance contract](flutter-performance-contract.md).

Inherited implementation and mandatory new extensions: [baseline contract P7](implemented-baseline.md#p7); [pinned evidence](baseline.json).

## Requirements and planned proof

| Requirement | Required implementation behavior | Planned acceptance |
|---|---|---|
| ELV5-P7-001 | Encode owner/scope-aware typed dependency keys including missing identities, membership sets/selectors and exact immutable upstream evidence | P7-T01 |
| ELV5-P7-002 | Invalidate exact `union(oldClosure,newClosure)` and newly matching selector closure across discipline/shared-source boundaries | P7-T02 |
| ELV5-P7-003 | Build deterministic affected-node DAG, coalesce superseded work and execute only the required transitive closure | P7-T03 |
| ELV5-P7-004 | Guard coherent multi-node publication with lifecycle/token/fingerprint, row/set versions, consumed pointer generations and cancellation epoch | P7-T04 |
| ELV5-P7-005 | Implement engineer process cards with exact revision/scope/case/provenance, governing/limiting factor and four independent status axes | P7-T05 |
| ELV5-P7-006 | Show full shared-project physical totals and selected discipline contribution from one immutable source evidence | P7-T06 |
| ELV5-P7-007 | Route preview/commit/replay/undo/redo/conflict retention through application services and keep heavy calculation/workspace projection out of widget `build()` | P7-T07 |
| ELV5-P7-008 | Implement frozen historical/NOT_CAPTURED projection, async revision safety, targeted rebuild/virtualization and stale-vs-failed-vs-technical-FAIL UI semantics | P7-T08 |

## Typed dependency model

Dependency keys are code-owned values, not arbitrary strings:

```text
FACT
SET
SELECTOR
POLICY
EVAL
POINTER
MISSING
```

Canonical debug/string representation is equivalent to:

```text
FACT/<owner>/<kind>/<id>/<field-or-membership>
SET/<owner>/<kind>/<scopeId>/<membershipKind>
SELECTOR/<owner>/<kind>/<scopeId>/<predicateCode>/<predicateFingerprint>
POLICY/<policyCode>/<editionId>/<hash>
EVAL/<owner>/<nodeKey>/<evaluationId>/<outputHash>
POINTER/<owner>/<nodeKey>/<generation>
MISSING/<kind>/<expectedIdentity>
```

Every key has deterministic `electra.canonical-json.v1` bytes/hash. Labels, localized messages and display ordering are never dependency identities.

## Why SET, SELECTOR and MISSING are mandatory

Depending only on rows that currently exist creates two invalidation holes:

1. inserting a new member touches no previously consumed row;
2. inserting a new fact that newly satisfies a predicate/selector also touches no old member.

Therefore `SET`/`SELECTOR` dependencies are mandatory for stream/subscription membership, recording assignments/schedules, recorder assignments, link sections, switch/panel resources, optical loss events, rack equipment, door roles/release rows, controller claims, fire devices/addresses and notification assignments.

`MISSING` represents expected evidence that does not exist. Creation of the missing identity invalidates the previously BLOCKED result automatically.

## Canonical input fingerprint

Fingerprint contains only consumed engineering semantics:

```text
node/process/version identity
scope/subject/operating cases
exact mutable root revisions
SET/SELECTOR fingerprints
policy refs/hashes/applicability
canonical fact values + evidence/uncertainty
upstream EVAL refs/output hashes
consumed POINTER generations
MISSING markers
timezone captured-rules evidence
frame/transform identity
environment applicability
authority/algorithm/numeric versions where required by cache key
```

It excludes wall-clock capture time, DB row/query order, evaluation ID, worker ID and UI selection state. Semantically identical unordered sets produce the same fingerprint; ordered engineering paths/sequences remain order-sensitive.

## Old + new + selector invalidation

Every replacement resolves server-side closure before and after the proposed mutation:

```text
changedKeys = union(oldClosure, newClosure, affectedSelectorKeys)
direct = reverseIndex.lookup(changedKeys)
affected = transitiveCurrentDependants(direct)
```

Affected pointers become STALE/generation+1 atomically with the mutation/history/ledger transaction. Examples:

- subscription A→B invalidates consumers of removed and added edges;
- new camera stream matching a recorder/pool selector invalidates that derived set even though stream did not previously exist;
- new missing current/profile invalidates blocked node;
- unrelated room label leaves engineering closure unchanged.

## Cross-owner ELV4 evidence

ELV5 wrappers record exact ELV4 node key/scope/scenario, evaluation ID, input/output hash, algorithm/numeric version, consumed pointer generation and physical source/segment/sequence context.

Cross-owner numerical direction remains one-way: ELV5 consumes ELV4; ELV4 physical solving does not depend on ELV5 result pointers. Shared requirement inputs compose at the physical owner boundary without feedback cycle.

## Incremental affected-node planner

The reverse dependency index is a correctness feature and the primary performance mechanism.

`Elv5AffectedNodePlanner` MUST:

1. resolve directly affected CURRENT/STALE nodes from changed dependency keys;
2. traverse process-to-process dependencies iteratively with cycle protection;
3. deduplicate by `Elv5EngineeringNodeKeyV3`;
4. include prerequisites needed to recompute an affected downstream node when their current result is absent/stale;
5. preserve unaffected current nodes as cache/evidence inputs without recomputing them;
6. emit one deterministic DAG/topological-level plan;
7. enforce node/edge/batch resource bounds before execution.

Production fallback `recalculate every ELV5 node after any edit` is prohibited.

## Deterministic scheduling and coalescing

`Elv5CalculationScheduler` consumes the deterministic plan and workload metadata from P1.

```text
mutation gen 10 -> X10 pending
mutation gen 11 -> X11 pending before X10 starts
=> X10 is dropped/coalesced

X10 already running, then gen11 arrives
=> X10 cancellation/supersession token prevents publish
=> exact result may enter immutable fingerprint cache only if fully completed
```

Rules:

- queue is bounded;
- pending work coalesces by canonical node/request generation;
- topological prerequisites execute before dependants;
- independent nodes may run concurrently;
- worker completion order never defines canonical output order;
- newer official work outranks obsolete official work; bounded what-if work cannot starve official calculation;
- cancellation is checked only at safe boundaries so no partial arithmetic object leaks.

## Capture → worker run → coherent guarded publish

Each request follows:

```text
short consistent CAPTURE
  -> deterministic affected-node plan
  -> pure calculation through Elv5CalculationExecutor
  -> canonical batch aggregation
  -> short guarded PUBLISH
```

Capture records lifecycle/token, exact row revisions, sets/selectors, policies, canonical facts, upstream evaluation/pointer generations, target pointer generations and input fingerprints. It uses bounded bulk queries and closes before worker calculation.

Publication transaction:

```text
recheck WORKING + revision token
recheck consumed row/set/selector fingerprints
recheck policy/evidence identity
recheck upstream pointer generations
recheck input fingerprints / cancellation epoch
verify every target pointer expected generation
insert all immutable evaluations/trace evidence
replace reverse-index edges in bounded bulk form
advance all requested pointers atomically
update snapshot/history/ledger where required
commit once
```

If any requested node fails revalidation, none of the coherent requested batch becomes CURRENT. Freeze always wins against late worker completion.

## Semantic result reuse

A deterministic evaluation may be reused only under the full semantic key defined by the performance contract, including process/algorithm/input/output/numeric versions, authority fingerprint and canonical input fingerprint.

Cache hit cannot bypass lifecycle/pointer publication guards. Eviction affects performance only. Policy/timezone/frame/evidence/upstream hash changes must cause miss.

## Pointer/status semantics

Axes remain independent:

```text
freshness:  CURRENT | STALE
execution:  SUCCEEDED | FAILED
completion: COMPLETE | PARTIAL | BLOCKED
assessment: PASS | FAIL | UNRESOLVED | NOT_ASSESSED
```

Thus CURRENT ≠ PASS, technical threshold violation is normally SUCCEEDED/COMPLETE/FAIL, and storage/codec/worker exception is execution failure rather than technical FAIL.

## Engineer workspace projection

UI is a projection client. A process card includes:

```text
process / subject / revision / scope / operating case
CURRENT/STALE + execution/completion/assessment
governing case + limiting factor
required dimension table
actual / required / signed margin / canonical unit
inputs + evidence basis/uncertainty
lazy calculation trace / “how calculated”
policy edition/hash/source status
canonical fact/upstream provenance
stable findings + remediation targets
claim scope / NOT_ASSESSED boundaries
```

Localized prose is generated from stable codes/parameters. UI never parses prose for verdict/dependency behavior and never performs engineering arithmetic in `build()`.

## Flutter targeted projection

Workspace queries return immutable card-sized VMs keyed by engineering node/dimension/finding identity. State listeners/selectors are scoped so one pointer/result update does not rebuild the entire workspace.

Large collections use lazy/virtualized rendering:

- process/findings/member lists via builder/sliver/pagination equivalent;
- trace detail materialized only when opened;
- no giant `Column` of thousands of hidden children;
- no DB query directly from widget `build()`;
- no eager localization/formatting of every hidden trace row.

Performance acceptance measures rebuild scope and frame timing in profile mode.

## Shared-source workspace cards

For one PSE/source/bank shared across disciplines, card can show:

```text
GLOBAL physical demand / required capability
GLOBAL available capability
GLOBAL margin
selected discipline contribution
other-system contribution
same immutable ELV4 evidence ID/hash
```

Visual filtering may hide rows but cannot create/publish a reduced physical recalculation.

## Draft/conflict/async behavior

Drafts remain UI/application state until public mutation commits. CAS/reviewed-impact conflict retains draft and refreshes authoritative comparison; no silent overwrite.

Async calculation/read result carries originating revision, node/scope and context generation. Navigation cannot attach a late old result to a new revision/subject. Superseded worker result cannot become CURRENT.

## Historical projection

Frozen view reads captured discipline snapshot and exact immutable evaluation refs/hashes; no latest-working fallback.

```text
legacy pre-ELV5 snapshot -> ELV5_NOT_CAPTURED
schema24 deliberately empty ELV5 section -> CAPTURED_EMPTY
```

Neither implies PASS.

## P7 acceptance cases

Required tests include:

- missing evidence → BLOCKED → creation invalidates through MISSING;
- new selector-matching member invalidates prior set-derived result;
- subscription move A→B invalidates old/new edge consumers;
- unrelated mutation leaves pointer generation/current result unchanged and triggers zero kernel recomputations;
- shared PWR pointer generation fans out only to exact consumers;
- affected planner returns exact expected node set/transitive closure;
- queue gen10→gen11 coalesces old pending work;
- running old generation cannot publish after supersession;
- workerCount 1/N and opposite completion orders yield identical canonical results;
- two publishers from same pointer generation: at most one advances;
- one target conflict in coherent batch: zero requested pointers advance;
- capture→relevant edit rejects publish; unrelated edit permits publish when fingerprints unchanged;
- capture→freeze rejects late publish;
- semantic cache hits identical input and misses changed policy/time/frame/evidence/upstream hash;
- stale PASS/current FAIL/BLOCKED/execution failure render distinctly;
- one changed process card does not rebuild whole workspace;
- large trace/finding lists instantiate visible/lazy rows only;
- async result cannot jump revisions;
- close/reopen preserves generations, reverse-index keys, governing/limiting/trace provenance.

## Exit

P7 runtime acceptance requires P7-T01…T08 at the same accepted source SHA/authority fingerprint, exact affected/unaffected/recomputed-node evidence in P8, scheduler/worker determinism and targeted profile-mode workspace performance evidence.

This document is a hardened design contract, not proof of source implementation.
