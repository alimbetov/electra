# Electra — ELV3 Runtime Closure P3–P9 Delivery Plan

Status: EXECUTION PLAN  
Branch: `feat/elv3-runtime-closure`  
Specification: `docs/product/elv3-runtime-closure-specification.md`

## 1. Goal

Close ELV3 as a proven local-first runtime subsystem before ELV4 starts.

Canonical sequence:

```text
RC0 Baseline + executable audit
 ↓
RC1 P3 persistence
 ↓ exact-SHA
RC2 P3 revision/freeze/reroute verticals
 ↓ exact-SHA
RC3 P4 carrier/pathway persistence
 ↓ exact-SHA
RC4 P5 profile-set/findings persistence
 ↓ exact-SHA
RC5 P6 calculation/evidence persistence
 ↓ exact-SHA
RC6 P7 concrete workspace/trace/history
 ↓ exact-SHA
RC7 P8 five real restart verticals
 ↓
RC8 P8 failure/idempotency/frozen-history matrix
 ↓ exact-SHA
RC9 P9 final architecture-vs-runtime audit
 ↓
ELV3 CLOSED / ACCEPTED
 ↓
ELV4 AUTHORIZED
```

No stage may claim acceptance from design/contracts alone.

---

## RC0 — Freeze runtime-closure baseline

### Work

- record base `main` SHA;
- refresh implementation inventory against branch start;
- enumerate current Drift schema version/tables/indexes;
- enumerate P3–P9 repository/service ports already present;
- enumerate public ELV3 commands and current tests;
- add a runtime-closure checklist or machine structural guard;
- verify legacy electrical routing baseline before new migrations.

### Evidence

```text
baseline inventory
schema inventory
command inventory
test inventory
legacy electrical baseline
```

### Exit gate

No ambiguity remains about what is implemented versus planned.

---

## RC1 — P3 schema and Drift repositories

### Work

Persist:

```text
ProjectDesignRevisions
DesignRevisionPhysicalSnapshots
CanonicalCableRuns
CableRunTraversals
RouteHandoffs
RouteBendEvidence
```

Implement concrete repositories and mappers.

Add sequential migration from current P1/P2 schema.

### Mandatory tests

```text
fresh DB latest schema
old schema → latest
P1/P2 rows survive migration
legacy electrical CableRuns survive unchanged
ProjectDesignRevision CRUD/state constraints
CableRun/traversal round-trip
RouteHandoff/BendEvidence round-trip
close/reopen exact values
```

### Exit gate

`P3 persistence GREEN` on exact SHA.

---

## RC2 — P3 command verticals

### Work

Make concrete transactional commands green:

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

### Mandatory invariants

```text
one WORKING revision/project
all physical writes require WORKING
FROZEN immutable
deterministic create-next materialization
shared route edit uses explicit impact set
no legacy CableRun reinterpretation
```

### Failure tests

```text
P3_FREEZE_AFTER_SNAPSHOT_INSERT
P3_CREATE_NEXT_AFTER_REVISION_INSERT
P3_REROUTE_AFTER_DELETE_OLD_CHAIN
P3_ADOPT_AFTER_CABLE_CREATE
```

Each test asserts same-open-DB rollback + post-reopen rollback.

### Exit gate

Freeze/reopen, create-next, reroute and legacy regression all green on one SHA.

---

## RC3 — P4 carrier/pathway runtime

### Work

Persist and implement:

```text
PathwayContexts
PhysicalCarriers
PhysicalCarrierCompartments
TraversalCarrierAssignments
```

### Required behavior

- strict project/revision ownership;
- ACTIVE→ARCHIVED lifecycle;
- archive dependency guards;
- host containment validation;
- compartment factual capacity;
- traversal attachment/detachment;
- carrier edits invalidate all dependent runs/results.

### Failure test

```text
P4_ATTACH_CARRIER_AFTER_TRAVERSAL_UPDATE
```

### Exit gate

Complete carrier/pathway graph survives reopen exactly; failure injection rolls back exactly.

---

## RC4 — P5 physical compatibility runtime

### Work

Persist:

```text
PhysicalProfileSets
PhysicalProfileSetEntries
PhysicalCompatibilityFindings
```

Store exact ELV2 reference/version/hash used by project revision.

### Required behavior

```text
typed selector applicability
deterministic order-independent combination
stable status order:
FORBIDDEN → UNRESOLVED → WARNING → OK
engine version = explicit
no latest lookup for FROZEN
no jurisdictional compliance conclusion
```

### Mandatory tests

```text
same profiles different order → same result
profile update in current catalog does not change frozen revision
restart reconstructs exact profile set/findings
cross-revision isolation
```

### Exit gate

P5 persisted deterministic evidence green on exact SHA.

---

## RC5 — P6 calculation/evidence runtime

### Work

Persist revision-scoped results for:

```text
ELV-ROUTE-01 installed length
ELV-ROUTE-02 carrier fill basis
ELV-ROUTE-03 segregation evidence
ELV-ROUTE-04 bend-radius basis
ELV-ROUTE-05 congestion basis
ELV-ROUTE-06 reserve allowance
```

### Required persisted provenance

```text
projectId
designRevisionId
processCode
subject identity
inputFingerprint
engineVersion
profile-set identity/hash when applicable
result payload
unit/status
evidence refs
calculatedAt
```

### Required tests

```text
same inputs → same fingerprint/result
route mutation → affected result stale/replaced only in WORKING
carrier mutation → fan-out invalidation
frozen result remains stable
no cross-revision cache collision
close/reopen exact result/evidence
```

### Exit gate

All six process codes are reconstructable after reopen and isolated by revision.

---

## RC6 — P7 concrete workspace, trace and history

### Work

Implement concrete persisted adapters for:

```text
ElvPhysicalRoutingWorkspaceService
ElvPhysicalTraceService
ElvCommandHistoryRepository
ElvCommandHistoryService
```

### Required workspace stages

```text
1 Connection
2 Cable
3 Allocation/resources
4 Terminations
5 Run/traversal
6 Carrier/pathway
7 Findings/calculations
```

### Required UX/runtime behavior

```text
WORKING → editable according to command permission
FROZEN → read-only, fully traceable
no widget multi-table write
trace from WORKING reads canonical current state
trace from FROZEN reads historical snapshot/revision evidence
```

### Undo/redo

Persist enough evidence for reversible commands.

Required reversible proof:

```text
RerouteCableRun
ReplaceCableTerminationSet
AttachTraversalToCarrier
DetachTraversalFromCarrier
```

Irreversible history must never expose active Undo.

### Exit gate

Concrete workspace + trace + undo/redo survive restart.

---

## RC7 — Five real P8 discipline verticals

All verticals use a real temp SQLite DB and explicit close/reopen.

### CCTV

```text
Camera
→ connection
→ Cat6 Cable
→ WHOLE_CABLE allocation
→ terminations
→ run
→ >=3 traversals
→ carrier/compartment
→ findings/calculations
→ freeze
→ reopen
```

### LAN

```text
outlet REAR
→ permanent-link Cable
→ patch-panel REAR
```

Passive internal connectivity remains separate.

### ACS

```text
one 8-core Cable
├ Reader 1,2
├ Contact 3,4
├ REX 5,6
└ Lock 7,8
```

Occupancy counts one physical cable.

### Fire

Logical loop identity remains distinct from explicit physical cable sections.

No ELV7 compliance claim.

### Fiber

```text
12 fibers
allocation A = 1,2
allocation B = 3,4
overlap on 2 = rejected
```

### Exit gate

All five exact persisted traces/ids/hashes survive reopen.

---

## RC8 — P8 failure, idempotency and historical reconstruction

### Failure matrix

Execute all stable failure points against real SQLite transactions:

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

### Idempotency matrix

For every replayable public command:

```text
success
→ lose response
→ reopen
→ replay same command/payload
→ same logical result, no duplicates

same commandId + different payload
→ ELV_IDEMPOTENCY_CONFLICT
```

### Frozen historical reconstruction

```text
build R1 WORKING
freeze R1
record trace/hash
create R2
mutate allocations/routes/carriers/profile/current results
reopen
load R1
assert original trace/hash/evidence unchanged
```

### Exit gate

P8 exact-SHA gate requires all three matrices green together.

---

## RC9 — P9 final closure

### Audit work

Refresh:

```text
docs/audit/elv3-implementation-inventory.md
docs/audit/elv3-command-contract-matrix.md
```

Create final Runtime Closure audit containing:

```text
schema reality
migration evidence
repository reality
command coverage
runtime forbidden-shortcut coverage
five vertical results
rollback matrix
idempotency matrix
frozen-history proof
legacy electrical regression
CI exact SHA
open findings
```

### Required runtime shortcut assertions

Must prove impossible:

```text
Connection persisted as Cable
exclusive connection consuming two physical cables
ACS resource overlap
FROZEN mutation
shared route/carrier edit without fan-out
bend radius inferred merely from angle
physical cable occupancy double counted by allocation
ELV3 jurisdiction-compliance result
silent legacy-electrical migration
latest profile used for frozen revision
calculation identity missing designRevisionId
```

### Final gate

```text
BLOCKER = 0
HIGH = 0
RC1–RC8 = PASS
final exact branch SHA = GREEN
ELV3 = CLOSED / ACCEPTED
ELV4 = AUTHORIZED
```

---

# Merge strategy

Recommended commits/PR checkpoints:

```text
Checkpoint A: RC0–RC2  P3 runtime
Checkpoint B: RC3      P4 runtime
Checkpoint C: RC4–RC5  compatibility + calculations
Checkpoint D: RC6      workspace/history
Checkpoint E: RC7–RC8  vertical/failure proof
Checkpoint F: RC9      final audit only
```

Do not combine unproven later-stage implementation into an earlier exact-SHA gate.

# CI policy

Every checkpoint runs:

```text
flutter pub get --enforce-lockfile
Drift generation
dart format --set-exit-if-changed
flutter analyze
flutter test
engineering_core format/analyze/test
ELV structural guards
phase-specific migration/restart/failure tests
legacy electrical routing regression from RC1 onward
```

The final RC9 SHA must have no subsequent source commit before merge authorization.

# Progress status template

Use this table during execution:

| Closure item | Status | Exact SHA | Evidence |
|---|---|---|---|
| RC0 baseline | OPEN | — | — |
| RC1 P3 persistence | OPEN | — | — |
| RC2 P3 commands | OPEN | — | — |
| RC3 P4 runtime | OPEN | — | — |
| RC4 P5 runtime | OPEN | — | — |
| RC5 P6 runtime | OPEN | — | — |
| RC6 P7 workspace | OPEN | — | — |
| RC7 five verticals | OPEN | — | — |
| RC8 failure/idempotency/history | OPEN | — | — |
| RC9 final audit | OPEN | — | — |
