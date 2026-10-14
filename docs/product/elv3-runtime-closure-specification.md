# Electra — ELV3 Runtime Closure P3–P9 Specification

Status: EXECUTION SPECIFICATION  
Branch: `feat/elv3-runtime-closure`  
Base: `main@5a139ed64585c0df8d52e4da270417453f93e2af`  
Scope: close the gap between accepted ELV3 architecture/domain contracts and proven local-first runtime behavior.

## 1. Purpose

This specification does not redesign ELV3. The ELV3 architecture, ownership boundaries, command semantics and P1/P2 persistence baseline remain authoritative.

The purpose of Runtime Closure is to prove that P3–P9 behave as one deterministic local-first subsystem:

```text
Domain model
  ↓
Application command/service
  ↓
Repository contract
  ↓
Drift transaction
  ↓
SQLite persisted state
  ↓
close process / reopen database
  ↓
exact reconstruction
  ↓
continued mutation without corrupting frozen history
  ↓
rollback / replay / idempotency proof
  ↓
final architecture-vs-code audit
```

ELV4 MUST NOT start before this specification reaches `CLOSED / ACCEPTED`.

## 2. Existing accepted baseline

Runtime Closure starts from the current implementation inventory:

- P1 Cable identity and P1 resource definitions are implemented;
- P2 allocation, immutable selection evidence, atomic resource claims, terminations and command idempotency ledger have canonical Drift persistence;
- P3–P6 domain/application contracts exist;
- P7 workspace/history contracts exist;
- P8 deterministic fixtures/failure probe infrastructure exists;
- P9 inventory and structural audit foundation exists.

Current persisted ELV baseline is schema version 19.

The following are explicitly NOT considered closed at Runtime Closure start:

- P3 canonical persistence;
- P4 canonical pathway/carrier persistence;
- P5 exact project profile-set persistence;
- P6 revision-scoped physical calculation/evidence persistence;
- P7 concrete workspace/trace/history adapters;
- P8 five real SQLite restart verticals;
- P3/P4 rollback verticals;
- post-reopen command replay/conflict matrix;
- frozen revision reconstruction after later WORKING mutation;
- P9 final exact-SHA closure.

## 3. Non-negotiable architectural rules

### RC-INV-01 — one physical design context

After P3 every physical mutation executes against one explicit `PhysicalDesignContext` containing at least:

```text
projectId
designRevisionId
revisionStatus
```

No repository may silently infer the editable revision from latest row order.

### RC-INV-02 — exactly one editable revision

At most one `WORKING` ProjectDesignRevision may exist per project.

All writes to revision-scoped ELV3 physical facts require that revision to be `WORKING`.

`FROZEN`, `SUPERSEDED` and `ARCHIVED` revisions are read-only.

### RC-INV-03 — frozen history is self-contained

A FROZEN revision MUST reconstruct from frozen snapshot/evidence captured for that revision.

It MUST NOT query current mutable P3/P4/P5/P6 rows to fill missing historical values.

### RC-INV-04 — reusable route graph remains shared infrastructure

Existing `CableRoutes`, `CableRouteNodes` and `CableRouteSegments` remain the only route geometry graph.

ELV3 MUST NOT create a second geometry graph.

### RC-INV-05 — ELV CanonicalCableRun remains distinct from legacy electrical CableRun

No migration may reinterpret legacy electrical `CableRuns` as canonical ELV3 runs.

Adoption is explicit and audited.

### RC-INV-06 — immutable evidence versus mutable ownership

Historical selection/evidence rows are append/immutable unless the accepted contract explicitly defines archival/versioning semantics.

Temporary exclusive claims are lifecycle state and may be released.

### RC-INV-07 — every public mutation is transactional

A public ELV3 command either commits all canonical state + command ledger + dependency invalidation/history evidence, or commits nothing.

Widgets never orchestrate multi-table writes.

### RC-INV-08 — persisted idempotency survives restart

`commandId + payload fingerprint` remains authoritative after DB reopen.

Exact replay returns the same logical result; changed payload with same commandId returns `ELV_IDEMPOTENCY_CONFLICT`.

### RC-INV-09 — calculations are revision scoped

Every P5/P6 persisted result key includes `projectId` and `designRevisionId` plus the process/result identity required to prevent cross-revision collisions.

### RC-INV-10 — no ELV7 leakage

ELV3 persists physical compatibility facts and evidence only.

Jurisdiction-specific compliance conclusions remain ELV7 responsibility.

---

# 4. P3 Runtime Closure — Design revisions, cable runs and traversal

## 4.1 Required persisted model

Introduce canonical schema version 20 or the next available sequential migration with equivalent versioning semantics.

Required persisted roots:

```text
ProjectDesignRevisions
DesignRevisionPhysicalSnapshots
CanonicalCableRuns
CableRunTraversals
RouteHandoffs
RouteBendEvidence
```

Exact names may differ only if the P9 schema audit records an approved equivalent.

### ProjectDesignRevisions

Minimum fields:

```text
id
projectId
status
basedOnRevisionId?
createdAt
updatedAt
frozenAt?
supersededAt?
archivedAt?
revisionNumber or deterministic ordering identity
snapshotSchemaVersion?
snapshotHash?
```

Constraints:

```text
one WORKING per project
basedOnRevisionId belongs to same project
FROZEN revision cannot return to WORKING
```

### CanonicalCableRuns

Minimum identity:

```text
id
projectId
designRevisionId
cableId
activeAllocationId
basedOnCableRunId?
status
createdAt
updatedAt
archivedAt?
```

No legacy `circuitId` ownership is permitted.

### CableRunTraversals

Traversal must reference existing reusable route geometry, not copy it.

Minimum identity:

```text
id
cableRunId
designRevisionId
routeId
sequence
entryNodeId?
exitNodeId?
handoffInId?
handoffOutId?
createdAt
updatedAt
```

Deterministic sequence is mandatory.

## 4.2 Required command verticals

Runtime closure must implement and persist at least:

```text
BootstrapProjectDesignRevision
FreezeProjectDesignRevision
CreateNextWorkingDesignRevision
SupersedeProjectDesignRevision
ArchiveProjectDesignRevision
CreateCableRun
RerouteCableRun
ArchiveCableRun
EditReusableRouteGeometry
AdoptLegacyElectricalRoute
```

Each command MUST define:

```text
read set
validation set
write set
state transition
dependency invalidations
idempotency behavior
rollback postcondition
stable error codes
```

## 4.3 Freeze transaction

Canonical freeze flow:

```text
validate WORKING revision
↓
materialize complete physical snapshot
↓
persist snapshot + schema version
↓
compute canonical snapshot hash
↓
mark revision FROZEN
↓
persist command success
↓
commit
```

Failure at `P3_FREEZE_AFTER_SNAPSHOT_INSERT` MUST roll back both snapshot and state transition.

## 4.4 Create-next transaction

`CreateNextWorkingDesignRevision` MUST materialize the new revision deterministically from the selected FROZEN baseline.

Lazy inheritance is forbidden.

After creation:

```text
old FROZEN rows remain immutable
new WORKING state is complete
all ids/references are deterministic according to contract
```

## 4.5 Reroute transaction

Canonical reroute:

```text
load current WORKING context
validate run + allocation + cable
validate route project ownership
capture inverse/precondition state
replace traversal chain atomically
persist dependency invalidation/history
persist command result
commit
```

Failure at `P3_REROUTE_AFTER_DELETE_OLD_CHAIN` MUST restore the exact old chain after rollback and reopen.

## 4.6 P3 acceptance gate

P3 closes only when all are green:

```text
schema migration
repository tests
command tests
freeze/reopen reconstruction
create-next deterministic materialization
reroute/reopen
failure-probe rollback
legacy electrical routing regression
exact-SHA CI
```

---

# 5. P4 Runtime Closure — Pathways, carriers and compartments

## 5.1 Required persisted model

Introduce schema version 21 or next sequential equivalent.

Required roots:

```text
PathwayContexts
PhysicalCarriers
PhysicalCarrierCompartments
TraversalCarrierAssignments
```

The persisted model must preserve factual physical infrastructure, not jurisdictional requirements.

### PathwayContext

Represents bounded physical routing context and host/project ownership.

Minimum identity:

```text
id
projectId
designRevisionId
hostKind
hostId
status
createdAt
updatedAt
archivedAt?
```

### PhysicalCarrier

Minimum fields:

```text
id
projectId
designRevisionId
pathwayContextId
carrierType
geometry/ref identity
physical dimensions/facts
status
createdAt
updatedAt
archivedAt?
```

### Compartments

Compartment is a first-class factual sub-capacity boundary.

It MUST NOT be represented only as string metadata on traversal.

## 5.2 Mutation guards

Required rules:

```text
host belongs to same project
carrier belongs to current WORKING revision
compartment belongs to carrier
assignment references traversal in same WORKING revision
archiving carrier/context blocked while active dependencies exist
carrier edits invalidate all dependent runs/results
```

## 5.3 Failure proof

`P4_ATTACH_CARRIER_AFTER_TRAVERSAL_UPDATE` MUST prove atomic rollback:

```text
before command == after failed command == after reopen
```

## 5.4 P4 acceptance gate

```text
carrier/context create-update-archive lifecycle PASS
compartment persistence PASS
traversal assignment PASS
fan-out invalidation PASS
archive dependency guards PASS
restart round-trip PASS
failure-probe rollback PASS
exact-SHA CI PASS
```

---

# 6. P5 Runtime Closure — Exact physical compatibility profile sets

## 6.1 Required persisted model

Introduce schema version 22 or next sequential equivalent.

Persist the exact project/revision selection of intrinsic physical compatibility profiles.

Required roots:

```text
PhysicalProfileSets
PhysicalProfileSetEntries
PhysicalCompatibilityFindings
```

Reference catalog profile definitions remain ELV2-owned; ELV3 stores exact selection/version/hash/reference required for reconstruction.

## 6.2 Determinism

Profile applicability and combination MUST remain:

```text
typed
deterministic
order independent
engine versioned
```

Stable status precedence:

```text
FORBIDDEN
UNRESOLVED
WARNING
OK
```

No latest-profile lookup during frozen reconstruction.

## 6.3 Required evidence

Every persisted finding must be attributable to:

```text
projectId
designRevisionId
profileSet identity/version/hash
engineVersion
subject ids
input fingerprint
rule/profile ids
status
structured evidence
createdAt
```

## 6.4 P5 acceptance gate

```text
exact profile-set persistence PASS
profile order independence PASS
frozen profile resolution PASS
current profile changes do not mutate old revision PASS
restart PASS
exact-SHA CI PASS
```

---

# 7. P6 Runtime Closure — Revision-scoped physical calculations and evidence

## 7.1 Required persisted outputs

Processes remain:

```text
ELV-ROUTE-01 installed length
ELV-ROUTE-02 carrier fill basis
ELV-ROUTE-03 segregation evidence
ELV-ROUTE-04 bend-radius basis
ELV-ROUTE-05 congestion basis
ELV-ROUTE-06 reserve allowance
```

Every persisted calculation must record enough provenance to explain and reproduce the result.

Minimum result identity:

```text
projectId
designRevisionId
processCode
subjectType
subjectId
inputFingerprint
engineVersion
profileSetHash?
result payload
unit/typed quantity
status
evidence refs
calculatedAt
```

## 7.2 Stale/recompute contract

Mutation of route/carrier/cable/allocation/profile dependencies MUST invalidate only affected P5/P6 results.

Manual historical/frozen evidence is never overwritten.

## 7.3 Frozen result behavior

FROZEN revision calculation/evidence reconstruction reads only revision-scoped persisted result/snapshot evidence.

Current mutable result rows are not acceptable fallback.

## 7.4 P6 acceptance gate

```text
all six process codes persisted PASS
revision-scoped key collision tests PASS
dependency invalidation PASS
recompute idempotence PASS
frozen/current isolation PASS
restart reconstruction PASS
exact-SHA CI PASS
```

---

# 8. P7 Runtime Closure — Concrete engineer workspace

## 8.1 Required concrete adapters

Implement real adapters for:

```text
ElvPhysicalRoutingWorkspaceService
ElvPhysicalTraceService
ElvCommandHistoryRepository / Service
```

They MUST query persisted state; no fixture/in-memory aggregate is accepted as production evidence.

## 8.2 Workspace progression

One shared workspace, no per-discipline editors:

```text
1 Connection
2 Cable
3 Allocation/resources
4 Terminations
5 Run/traversal
6 Carrier/pathway
7 Findings/calculations
```

`canEdit` derives from current `PhysicalDesignContext` and command permissions only.

FROZEN context is fully inspectable but mutation controls are disabled.

## 8.3 Trace reconstruction

Trace from WORKING:

```text
Connection
→ Cable
→ Allocation
→ ResourceSelection
→ Terminations
→ CableRun
→ Traversals
→ Route/Handoff/Bend evidence
→ Carrier/Pathway
→ Findings
→ Calculations
```

Trace from FROZEN resolves historical snapshot/revision-scoped evidence and MUST remain unchanged after later WORKING edits.

## 8.4 Undo/redo

Persisted command history must classify:

```text
reversible
irreversibleHistory
```

Undo of reversible commands requires precondition fingerprint match.

Irreversible history commands never expose enabled undo.

## 8.5 P7 acceptance gate

```text
real workspace query PASS
WORKING mutation path PASS
FROZEN read-only path PASS
working trace PASS
frozen trace PASS
persisted undo/redo PASS
restart with history PASS
widget/application acceptance PASS
exact-SHA CI PASS
```

---

# 9. P8 Runtime Closure — Restart, rollback, idempotency and five real verticals

## 9.1 Five mandatory real SQLite verticals

The following fixtures MUST execute against a real temp SQLite database and survive close/reopen:

```text
CCTV
LAN
ACS
Fire
Fiber
```

Fixture-contract tests alone do not satisfy P8.

## 9.2 CCTV vertical

Minimum flow:

```text
Camera ETH/PoE port
→ EngineeringConnection
→ Cat6 Cable
→ WHOLE_CABLE allocation
→ terminations
→ CanonicalCableRun
→ >=3 traversals
→ carrier/compartment assignment
→ physical findings/calculations
→ freeze
→ close DB
→ reopen
→ exact trace/hash/ids
```

No ELV4 PoE budget calculation is permitted.

## 9.3 LAN vertical

Prove:

```text
outlet rear port → patch panel rear port
one Cat6 permanent-link Cable
internal patch-panel connectivity remains logical/passive mapping
restart exact reconstruction
```

## 9.4 ACS vertical

One 8-core Cable serves four allocations:

```text
Reader        cores 1,2
Door contact  cores 3,4
REX           cores 5,6
Lock          cores 7,8
```

Assertions:

```text
1 Cable
4 allocations
8 unique conductor atoms
carrier occupancy counts physical Cable once
restart exact
```

## 9.5 Fire vertical

Prove separation between logical fire loop topology and explicit physical cable sections.

No ELV7 normative compliance claim is allowed.

## 9.6 Fiber vertical

12-fiber Cable, duplex allocations:

```text
A → fibers 1,2
B → fibers 3,4
```

Overlap attempt on fiber 2 fails atomically before and after reopen.

## 9.7 Failure matrix

At minimum execute real rollback tests for:

```text
P1_CREATE_CABLE_AFTER_INSERT
P2_RESERVE_AFTER_FIRST_CLAIM
P2_REPLACE_TERMINATION_AFTER_DELETE
P2_ACTIVATE_BEFORE_STATE_UPDATE
P3_FREEZE_AFTER_SNAPSHOT_INSERT
P3_CREATE_NEXT_AFTER_REVISION_INSERT
P3_REROUTE_AFTER_DELETE_OLD_CHAIN
P4_ATTACH_CARRIER_AFTER_TRAVERSAL_UPDATE
P3_ADOPT_AFTER_CABLE_CREATE
```

Protocol:

```text
open DB
establish canonical baseline
arm failure
execute command
assert failure
assert same-open-DB rollback
close
reopen
assert exact baseline
assert command ledger does not claim success
```

## 9.8 Idempotency matrix

For every replayable public command:

```text
execute success
lose response
close/reopen
replay same commandId + same payload
→ same logical result, no duplicate rows

same commandId + changed payload
→ ELV_IDEMPOTENCY_CONFLICT
```

## 9.9 Frozen reconstruction proof

```text
build WORKING
freeze R1
record full trace/hash
create R2 WORKING
mutate route/carrier/allocation/profile/current calculations
close/reopen
load R1
assert exact old trace/hash/evidence
```

## 9.10 P8 acceptance gate

P8 is closed only when all five discipline verticals, failure matrix, idempotency matrix and frozen reconstruction tests are green on one exact SHA.

---

# 10. P9 Runtime Closure — Final architecture-vs-runtime gate

## 10.1 Refresh implementation inventory

Update `docs/audit/elv3-implementation-inventory.md` so it reports source reality after closure.

No planned item may be counted as implemented.

## 10.2 Complete command contract matrix

Every public ELV3 mutation from P1–P8 must have one row with:

```text
command
input identity
PhysicalDesignContext requirement
read set
validation set
write set
state transition
dependency invalidations
idempotency class
rollback postcondition
undo class
restart assertion
stable errors
implementation file
test file
```

Missing command row = P9 failure.

## 10.3 Forbidden-shortcut tests

Runtime tests MUST fail if implementation permits any of the following:

```text
Connection serialized as Cable
second consuming Cable for one exclusive connection
ACS resource overlap
FROZEN mutation
shared route edit without impact fan-out
carrier edit without impact fan-out
bend radius inferred only from angle
carrier occupancy double-counting one physical Cable
ELV3 jurisdiction-compliance finding
legacy electrical route silently migrated to ELV3 Cable
latest-profile lookup for frozen revision
calculation cache key without designRevisionId
```

## 10.4 Exact-SHA closure record

Create or update final audit with:

```text
final branch SHA
base main SHA
schema version
migration tests
Drift generation
mobile format/analyze/test
engineering_core format/analyze/test
P3 gate
P4 gate
P5 gate
P6 gate
P7 gate
five real verticals
failure matrix
idempotency/reopen matrix
frozen reconstruction
legacy electrical regression
command matrix audit
forbidden-shortcut audit
open BLOCKER/HIGH findings
```

Any code commit after the recorded SHA invalidates closure evidence and requires rerun.

## 10.5 Final P9 verdict

Required final state:

```text
open BLOCKER findings = 0
open HIGH findings    = 0
all P3-P8 runtime gates = PASS
exact final SHA = GREEN
ELV3 = CLOSED / ACCEPTED
ELV4 implementation = AUTHORIZED
```

---

# 11. Persistence migration strategy

Migrations MUST be sequential and support direct upgrade from supported historical schemas.

Conceptual progression:

```text
v19 P1/P2 baseline
 ↓
v20 P3 revision/run/snapshot
 ↓
v21 P4 pathway/carrier
 ↓
v22 P5 profile-set/findings
 ↓
v23 P6 calculation/evidence/history if required
```

The exact integer may change if unrelated schema migrations land first, but semantic phase ordering MUST remain.

Migration tests must include:

```text
v19 → latest
v20 → latest
v21 → latest
v22 → latest
fresh DB → latest
```

Existing P1/P2 and legacy electrical data must survive unchanged.

# 12. Repository and transaction boundaries

Expected repository families:

```text
ProjectDesignRevisionRepository
CanonicalCableRunRepository
PhysicalSnapshotRepository
PathwayContextRepository
PhysicalCarrierRepository
PhysicalProfileSetRepository
PhysicalFindingRepository
PhysicalCalculationRepository
ElvPhysicalTraceRepository or query service
ElvCommandHistoryRepository
```

A repository may combine closely coupled tables internally, but public command transaction boundaries belong to application services/write-unit-of-work.

No repository API should require Flutter widget types.

# 13. Observability and stable diagnostics

Runtime closure must preserve stable error codes rather than relying on exception text.

Every command failure should be attributable to:

```text
commandId
commandType
projectId
designRevisionId?
stable error code
subject ids
failure point if injected test
```

No sensitive payload logging is required for closure.

# 14. Test pyramid

Required layers:

```text
engineering_core unit tests
  ↓
application service/command tests
  ↓
Drift repository/migration tests
  ↓
transaction/failure tests
  ↓
real SQLite restart verticals
  ↓
workspace/widget acceptance
  ↓
P9 structural/runtime audit
```

A higher layer does not replace lower-layer deterministic tests.

# 15. Definition of Done

Runtime Closure P3–P9 is DONE only when:

1. P3–P6 canonical persistence exists and is migration tested;
2. all physical mutations require explicit valid WORKING context;
3. FROZEN reconstruction is self-contained and exact after later mutation;
4. shared route/carrier changes invalidate all dependent ELV3 results/runs correctly;
5. P5/P6 results are revision scoped and provenance rich;
6. P7 workspace/trace/history use concrete persisted adapters;
7. undo/redo is persisted and precondition safe;
8. CCTV/LAN/ACS/Fire/Fiber real DB restart verticals pass;
9. all mandatory failure probes prove exact rollback before and after reopen;
10. replayable commands are idempotent across restart;
11. conflict replay returns stable `ELV_IDEMPOTENCY_CONFLICT`;
12. legacy electrical routing regression remains green;
13. P9 inventory and command matrix match source reality;
14. forbidden-shortcut runtime assertions are green;
15. zero open BLOCKER/HIGH implementation deviations remain;
16. one final exact branch SHA passes every required gate;
17. development roadmap is updated to `ELV3 CLOSED / ACCEPTED` only after the final gate.

# 16. Explicit non-goals

Runtime Closure MUST NOT introduce:

- ELV4 PoE/PSU/UPS calculations;
- ELV5 CCTV/LAN/ACS/Fire discipline calculations beyond ELV3 physical processes;
- ELV7 jurisdiction-specific compliance packs;
- ELV8 manufacturer/SKU selection or BOM;
- backend/cloud dependency for core behavior;
- a second route geometry graph;
- discipline-specific duplicate physical routing editors.

These remain later stages.