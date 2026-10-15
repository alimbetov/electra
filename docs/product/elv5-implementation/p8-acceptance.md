# P8 — Integrated verification and qualification

Status: DESIGN DRAFT / RUNTIME NOT STARTED
Depends on: P0–P7 implemented prerequisites.
Parent: [ELV5 design](../elv5-discipline-calculations-design-specification.md); [process contracts](process-contracts.md).

## Requirements and planned proof

| Requirement | Required implementation behavior | Planned acceptance |
|---|---|---|
| ELV5-P8-001 | Implement one FK-valid public-command fixture per discipline plus shared-source project context | P8-T01 |
| ELV5-P8-002 | Exercise all 27 process positive/negative oracles with required dimension/claim-scope manifest | P8-T02 |
| ELV5-P8-003 | Prove exact snapshots/evaluations/policies/assignments after file-SQLite close/reopen | P8-T03 |
| ELV5-P8-004 | Freeze R1, create/remap R2, change profiles/routes/states and prove immutable R1 results | P8-T04 |
| ELV5-P8-005 | Inject owned durable failure checkpoints and verify same-open/reopened rollback including history/ledger | P8-T05 |
| ELV5-P8-006 | Prove response-loss replay/payload conflict and two-connection edit/publish/freeze/adoption races | P8-T06 |
| ELV5-P8-007 | Verify supported migration origins and mixed legacy/ELV3/ELV4/ELV5 result consumer isolation | P8-T07 |
| ELV5-P8-008 | Assert affected and unaffected process sets, exact arithmetic/bounds and no false compliance/layout claim | P8-T08 |

## Concrete contract

Positive/negative oracle IDs are processCode-POS/NEG in the registry; package test IDs add cross-cutting assertions. Before runtime P1/P8 freeze an executable qualification manifest with complete technical inputs, applicable scopes, required dimensions and exact expected statuses. Boundary examples alone do not qualify a public vertical. Missing a required positive or leaving its required dimension UNRESOLVED/BLOCKED fails qualification.

Use real FK-valid temporary file SQLite and public commands for current setup; raw SQL is allowed only for explicit historical migration seeds or read assertions. Failure probes cover assignment insert/old-set delete/new member, invalidation/history/ledger, snapshot section/manifest and pointer batch publication. Check every rollback after reopening.

Race barriers cover policy adoption versus reviewed preview, stream/route edits versus publication, shared-source membership changes, freeze versus publish, create-next/remapping and history cursor conflict. Keep immutable foreign-owner rows and old v1/v2 decoding stable during generic recalculation/manual/retirement.

## Exit

P8 runtime acceptance requires its numbered assertions at the same accepted source SHA and its prerequisite gates. This document is a design contract, not proof of source implementation.
