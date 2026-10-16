# P8 — Integrated verification and qualification

Status: DESIGN DRAFT / RUNTIME NOT STARTED
Depends on: P0–P7 implemented prerequisites.
Parent: [ELV5 design](../elv5-discipline-calculations-design-specification.md); [process contracts](process-contracts.md); [code-level runtime contract](code-level-runtime-contract.md).

Inherited implementation and mandatory new extensions: [baseline contract P8](implemented-baseline.md#p8); [pinned evidence](baseline.json). This contract supersedes the original design-only parent assumptions.

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

Positive/negative oracle IDs are `processCode-POS/NEG` in the registry; package test IDs add cross-cutting assertions. Before runtime P1/P8 freeze an executable qualification manifest with complete technical inputs, applicable scopes, required dimensions and exact expected statuses. Boundary examples alone do not qualify a public vertical. Missing a required positive or leaving its required dimension UNRESOLVED/BLOCKED fails qualification.

Use real FK-valid temporary file SQLite and public commands for current setup; raw SQL is allowed only for explicit historical migration seeds or read assertions. Failure probes cover assignment insert/old-set delete/new member, invalidation/history/ledger, snapshot section/manifest and pointer batch publication. Check every rollback after reopening.

Race barriers cover policy adoption versus reviewed preview, stream/route edits versus publication, shared-source membership changes, freeze versus publish, create-next/remapping and history cursor conflict. Keep immutable foreign-owner rows and old v1/v2 decoding stable during generic recalculation/manual/retirement.

### Qualification manifest

P8 MUST introduce a machine-readable manifest whose entries contain at least:

```text
processCode
oracleId
fixtureId
setupCommandIds
calculationCommandId
scope
subject
requiredDimensions
expectedCompletion
expectedAssessment
expectedExecution
expectedFindingCodes
expectedAffectedProcessCodes
expectedUnaffectedProcessCodes
claimScope
```

Every one of 27 process codes has both POS and NEG/unsupported entries. Tests read this manifest and fail if runtime registry membership, required dimensions or expected status inventory diverges.

### Exact wire/codec qualification

The initial ELV5 runtime has exactly 16 public discipline command codecs under `electra.elv5-discipline-command.v1`. P8 MUST prove:

1. one registered codec for every operation and no extra/missing codec;
2. valid canonical JSON example for every operation;
3. missing field, unknown field, wrong type and unsupported schema/operation/version rejection;
4. nested semantic rejection for duplicate/foreign identities;
5. reviewed impact is resolved server-side rather than trusted from payload;
6. same `(projectId,commandId,requestHash)` replay returns the original response after row revisions changed;
7. same command ID with different request hash returns `ELV5_COMMAND_PAYLOAD_CONFLICT`;
8. command failure leaves root/member rows, reverse dependencies, history cursor and ledger atomically unchanged after reopen.

### Public vertical fixtures

At least one integrated current-revision project contains all four disciplines and a genuinely shared physical ELV4 source/PSE/battery context. Setup uses the same public application/command services expected in production. The fixture must contain enough real FK-connected data to execute all relevant discipline calculations without replacing canonical ELV3/ELV4 facts by test-only ELV5 duplicates.

Qualification must demonstrate that CCTV/LAN shared PoE wrappers consume one exact physical PWR-06 evidence and expose different contribution breakdowns without reducing the global membership set. Fire/ACS shared backup scenarios likewise consume complete protected-load closure.

### Persistence/restart proof

After close/reopen assert exact preservation of:

- every ELV5 revision-scoped root and ordered child set;
- immutable policy edition references/hashes;
- command ledger request/response hashes;
- complete forward/inverse history and cursor;
- immutable evaluation output/input hashes;
- pointer generation/freshness/evaluation IDs;
- reverse dependency keys including SET/MISSING markers;
- snapshot discipline section and manifest `disciplineHash`.

No test may rely solely on an in-memory database for P2/P7/P8 acceptance.

### Publication and freeze races

Use deterministic barriers around capture and publish. Prove at minimum:

- capture → concurrent relevant edit → publish conflict/no CURRENT;
- capture → unrelated edit → publish allowed when consumed fingerprint/generations unchanged;
- capture → freeze → publish returns publish-after-freeze conflict;
- two calculations capturing same pointer generation cannot both advance the same pointer generation as if uncontended;
- shared-source pointer generation change invalidates all exact dependent wrappers;
- blocked result with `MISSING/...` dependency becomes stale when the missing fact is later created.

### Migration and owner isolation

Migration tests start from every supported origin, including real accepted v21/v22/v23-style seeds as governed by P0/P2. Historical legacy rows, ELV4 power rows and new ELV5 discipline rows coexist. Generic readers dispatch by explicit owner/schema and must not decode/retag one store as another.

Old snapshot without discipline section returns `ELV5_NOT_CAPTURED`. New snapshot with an intentionally empty discipline section returns CAPTURED_EMPTY. These are separate acceptance cases.

## Exit

P8 runtime acceptance requires its numbered assertions at the same accepted source SHA and its prerequisite gates. This document is a design contract, not proof of source implementation.

P8 cannot close from structural/specification validators. It closes only from executed public-command, file-SQLite, restart, race, migration and 27-process oracle evidence at one tested source SHA.

## Audit refinements

Audit regression oracles include sub-byte aggregate ceiling, expected-versus-guaranteed retention, two streams/one-camera recorder licence, optical overload with design reserve, overlapping module address sets, gross/net RU equivalence, unknown upstream process/scope and registry cycle. All are required design-to-runtime tests; no structural validator substitutes for executed public-command qualification.

Additional code-level regressions are mandatory: exact 16-codec registry, missing/extra codec rejection, stale reviewed-impact fingerprint, replay-first behavior after revision change, missing-input dependency invalidation, pointer generation CAS and freeze-winning publication race. No PASS may be asserted from unsupported model, absent required dimension, fictional-policy compliance or ELV6/ELV7/ELV8-owned conclusions.
