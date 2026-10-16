# P7 — Incremental dependencies and engineer workspace

Status: DESIGN HARDENED / RUNTIME NOT STARTED
Depends on: Design begins P1/P2; complete integration P3–P6.
Parent: [ELV5 design](../elv5-discipline-calculations-design-specification.md); [process contracts](process-contracts.md); [engineering primitives](engineering-primitives-contract.md); [schema 24](persistence-schema-contract.md); [production source blueprint](production-source-blueprint.md).

Inherited implementation and mandatory new extensions: [baseline contract P7](implemented-baseline.md#p7); [pinned evidence](baseline.json).

## Requirements and planned proof

| Requirement | Required implementation behavior | Planned acceptance |
|---|---|---|
| ELV5-P7-001 | Encode owner/scope-aware typed dependency keys including missing identities, membership sets and exact immutable upstream evidence | P7-T01 |
| ELV5-P7-002 | Invalidate exact `union(oldClosure,newClosure)` across discipline/shared-source boundaries | P7-T02 |
| ELV5-P7-003 | Guard coherent multi-node publication with lifecycle/token/fingerprint, row/set versions and consumed pointer generations | P7-T03 |
| ELV5-P7-004 | Implement engineer process cards with exact revision/scope/operating-case/source provenance and four independent status axes | P7-T04 |
| ELV5-P7-005 | Show full shared-project physical totals and selected discipline contribution from one immutable source evidence | P7-T05 |
| ELV5-P7-006 | Route preview/commit/replay/undo/redo/conflict retention through application services, never UI-side engineering mutation | P7-T06 |
| ELV5-P7-007 | Implement frozen historical/NOT_CAPTURED projection and preserve originating revision/scope generation in async reads | P7-T07 |
| ELV5-P7-008 | Cover keyboard/focus/back/remediation plus stale-vs-failed-vs-technical-FAIL display semantics | P7-T08 |

## Typed dependency model

Internal runtime dependency keys are code-owned values, not arbitrary strings:

```text
FACT
SET
POLICY
EVAL
POINTER
MISSING
```

Canonical debug/string representation remains equivalent to:

```text
FACT/<owner>/<kind>/<id>/<field-or-membership>
SET/<owner>/<kind>/<scopeId>/<membershipKind>
POLICY/<policyCode>/<editionId>/<hash>
EVAL/<owner>/<nodeKey>/<evaluationId>/<outputHash>
POINTER/<owner>/<nodeKey>/<generation>
MISSING/<kind>/<expectedIdentity>
```

Every key has deterministic `electra.canonical-json.v1` bytes/hash. Free-text notes, labels and localized messages are never dependency identities.

## Why SET and MISSING are mandatory

Depending only on rows that currently exist creates an invalidation hole: insertion of a new member would not touch any old row dependency.

`SET` dependencies are mandatory where insertion/removal can change a result, including:

```text
camera stream/subscription sets
recording pool assignments/schedule segments
recorder assignments
link ordered-section sets
switch and patch-panel assignments
optical loss-event sets
rack equipment membership
door role + release truth-table sets
controller resource claims
fire loop device + expanded address claims
notification-circuit assignments
```

`MISSING` dependencies represent expected evidence that does not yet exist. If a result is BLOCKED because a required policy/profile/path/current is absent, later creation of that exact identity invalidates the blocked result automatically.

## Canonical input fingerprint

Technical fingerprint is the canonical consumed engineering semantics, not an arbitrary whole-project dump.

It includes where applicable:

```text
node/process/version identity
scope/subject/operating case
exact mutable root revisions
SET membership fingerprints
policy refs/hashes/applicability
canonical fact values + source/evidence basis
upstream immutable EVAL refs/output hashes
consumed POINTER generations
MISSING markers
timezone/tzdb policy
frame/transform identity
environment applicability
```

It excludes wall-clock capture time, DB query order, evaluation ID and UI selection state.

Two captures with semantically identical unordered sets must produce the same fingerprint. Reordering an engineering path/sequence where order is semantic must change it.

## Old + new invalidation

Every replacement command resolves dependency closure from server-side state both before and after validation of the proposed replacement:

```text
changedKeys = union(oldClosure, newClosure)
dependants = reverseIndex.lookup(changedKeys)
```

Affected pointers become STALE and their generation increments in the same atomic mutation UoW as root/member replacement, shared history and ledger write.

Examples:

- moving a CCTV subscription from edge A to edge B invalidates consumers of both A and B;
- replacing a fire address assignment invalidates consumers of the removed and added address claims;
- releasing/adopting a policy invalidates exact policy consumers;
- creating a previously missing bitrate/current/profile invalidates the old blocked node;
- unrelated room label or independent door remains unaffected negative control.

## Cross-owner ELV4 evidence

An ELV5 wrapper depending on ELV4 power evidence records the exact:

```text
ELV4 node key/scope/scenario
evaluationId
input/output hash
algorithm/numeric version
consumed pointer generation
physical source/segment/sequence context identity
```

It never records only `processCode=ELV-PWR-*` as sufficient evidence.

Cross-owner graph direction is one-way for numerical evidence: ELV5 may consume ELV4; ELV4 physical solving must not depend on ELV5 result pointers. Shared policy requirement inputs are composed before/at the physical owner boundary without a numerical feedback loop. Registry validation rejects cycles.

## Capture → pure run → coherent guarded publish

Every calculation request captures a coherent batch. Capture records lifecycle/token, exact row revisions, set fingerprints, immutable policy refs/hashes, canonical facts, upstream evaluation refs/pointer generations, target pointer generations and input fingerprints.

Pure run holds no SQLite write transaction.

Publication is a single short transaction for the complete requested batch:

```text
recheck revision remains WORKING + token unchanged
recheck every consumed row revision/set fingerprint
recheck every exact policy/evidence identity
recheck every upstream pointer generation
recompute/compare input fingerprint
verify every target pointer expected generation
insert all immutable evaluation records
replace all target reverse-index edges
update all target pointers CURRENT/generation+1
commit once
```

If any requested node fails revalidation, **none** of the requested batch becomes CURRENT. Partial coherent-batch publication is prohibited.

Freeze wins against a late publisher. A pure calculation started before freeze may finish in memory, but publication after freeze returns conflict and cannot revive/update pointers on the frozen revision.

## Pointer/status semantics

These axes remain independent in every workspace/read API:

```text
freshness: CURRENT | STALE
execution: SUCCEEDED | FAILED
completion: COMPLETE | PARTIAL | BLOCKED
assessment: PASS | FAIL | UNRESOLVED | NOT_ASSESSED
```

Consequences:

- `CURRENT` does not mean `PASS`;
- engineering threshold violation is normally `SUCCEEDED / COMPLETE / FAIL`;
- missing/unsupported evidence can be `SUCCEEDED / BLOCKED / UNRESOLVED` when that is a deterministic engineering outcome;
- storage/codec/runtime exception is execution failure, not technical FAIL;
- stale historical PASS displays as stale PASS evidence, not current success.

## Engineer workspace projection

The UI is a projection client, never an engineering authority.

Recommended process-card hierarchy:

```text
process + subject + revision/scope/scenario/operating case
CURRENT/STALE
execution/completion/assessment
required dimension table
limiting/worst dimension
actual / required / margin with canonical unit
selected inputs + evidence basis
how calculated / deterministic steps
policy edition/hash/source status
canonical fact/upstream evidence provenance
stable findings + structured remediation target
claim-scope / NOT_ASSESSED limitations
```

Localized prose is rendered from stable finding codes/parameters. UI must not parse prose to determine verdict or dependency behavior.

## Shared-source workspace cards

For a PSE/source/bank shared across disciplines, one card/evidence projection must be able to show:

```text
GLOBAL physical demand / required capability
GLOBAL available capability
GLOBAL margin
selected discipline contribution
other-system contribution
same immutable ELV4 evidence ID/hash
```

A visual filter may hide detail rows but cannot create a smaller recalculation and publish it as the physical total.

## Draft/conflict/async behavior

Preview/edit drafts remain application/UI state until a public mutation commits. On CAS/reviewed-impact conflict the user's draft is retained and refreshed against current authoritative state; runtime must not silently overwrite.

Async calculation/read result carries originating revision ID, scope/node identity and context generation. Navigation to another revision/subject cannot attach a late result to the new selection.

Back/keyboard/focus behavior follows shared editor conventions. Leaving a dirty draft requires the existing explicit discard/commit behavior; it must not auto-commit a calculation aspect.

## Historical projection

Frozen historical view reads the captured discipline snapshot section and exact immutable evaluation refs/hashes. It never reads latest working ELV5 rows as fallback.

Legacy pre-ELV5 snapshot returns:

```text
ELV5_NOT_CAPTURED
```

A new schema-24 snapshot with a deliberately empty ELV5 section is:

```text
CAPTURED_EMPTY
```

Those states are not interchangeable and neither implies PASS.

## P7 acceptance cases

Required tests include:

- missing policy/profile → blocked node → binding creation invalidates it;
- stream subscription move A→B invalidates old/new edge consumers;
- unrelated mutation leaves node CURRENT/generation unchanged;
- one shared PWR pointer generation change fans out to every exact ELV5 consumer;
- two publishers from same target generation: at most one advances from that generation;
- one multi-node batch target conflicts: zero requested nodes become CURRENT;
- capture → relevant edit → no stale publication;
- capture → unrelated edit → publish succeeds when consumed fingerprint/generations are unchanged;
- capture → freeze → late publish rejected;
- stale PASS, current FAIL, BLOCKED and execution failure render distinctly;
- legacy frozen snapshot reports NOT_CAPTURED; captured empty remains distinct;
- async result cannot jump revisions after UI navigation;
- close/reopen preserves pointer generations, reverse-index keys and explanation provenance.

## Exit

P7 runtime acceptance requires P7-T01…T08 at the same accepted source SHA and its prerequisite gates. It also requires exact affected/unaffected invalidation evidence in the P8 qualification manifest.

This document is a hardened design contract, not proof of source implementation.
