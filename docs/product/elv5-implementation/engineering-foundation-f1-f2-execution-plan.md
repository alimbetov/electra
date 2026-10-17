# ELV5 Engineering Foundation — F1/F2 execution process

Status: **ACTIVE / ACCEPTANCE NOT CLAIMED**  
Branch: `feat/flutter-elv5-power-topology-design`  
Parent authority: `engineering-calculation-simulation-foundation.md`  
Machine status: `engineering-foundation-f1-f2-status.json`

## 1. Purpose

This execution plan turns Foundation v1 from an authority/design contract into an evidence-backed implementation program. It does not create a new ELV5 process code and does not replace the 27-process runtime rollout.

Two workstreams run in parallel:

```text
TRACK A — ELV5 runtime completion
  21/27 production adapters integrated at the adoption baseline
  -> finish remaining LAN/CCTV verticals

TRACK B — Foundation adoption
  F1 shared primitives reconciliation
  -> F2 five-pilot qualification
  -> only then evidence-backed QUALIFIED lifecycle claims
```

`RUNTIME_INTEGRATED` is not `QUALIFIED`. `QUALIFIED` is not `ACCEPTED`.

## 2. Source-backed lifecycle rule

Every process/foundation primitive uses:

```text
DESIGNED
-> KERNEL_IMPLEMENTED
-> RUNTIME_INTEGRATED
-> QUALIFIED
-> ACCEPTED
```

A lifecycle promotion requires exact evidence. Old prose such as `RUNTIME NOT STARTED` is historical if source/runtime already exists. Conversely, source files and unit tests alone never justify `QUALIFIED` or `ACCEPTED`.

Minimum runtime-status evidence:

```text
source
+ kernel tests
+ persistence/runtime binding where applicable
+ application adapter
+ qualification evidence
+ exact source SHA
```

## 3. F1 — Shared Primitives Reconciliation

F1 is an audit-and-reconciliation phase first. Do not build a universal framework when existing ELV4/ELV5 primitives already satisfy the invariant.

### F1.1 Quantity inventory and dimension safety

Inventory existing public engineering quantities in `engineering_core` and application contracts against:

```text
Current
Voltage
Resistance
Power
ApparentPower
Energy
Charge/Ah
Length
Area
CrossSectionArea
Temperature
Duration
DataRate
StorageCapacity
Attenuation
OpticalPower
Mass
HeatPower
Ratio
Frequency
```

For every dimension classify the canonical arithmetic representation:

```text
INTEGER_CANONICAL_BASE_UNIT
RATIONAL
FIXED_DECIMAL
INTERVAL
FLOATING_ONLY_WHEN_REQUIRED
```

Deliverable: a reconciliation matrix `existing type -> canonical dimension -> arithmetic -> gaps -> migration action`.

Gate F1-QTY:
- no public engineering PASS/FAIL boundary depends on an unqualified binary `double` when an exact/bounded representation is practical;
- unit normalization is deterministic;
- presentation rounding is outside engineering verdict logic;
- tolerance/rounding policy is explicit where exact comparison is impossible.

### F1.2 Typed evidence

Reconcile existing evidence records to states:

```text
VERIFIED
DECLARED
DERIVED
ASSUMED
UNKNOWN
```

Substantial evidence must carry stable identity/provenance including evidence/source identity, edition/revision, content hash, applicability and value/reference. `ASSUMED` must expose reason, scope and author/source and can never satisfy `VERIFIED_ONLY` automatically.

Gate F1-EVIDENCE: no pilot may synthesize stronger evidence state than its captured source supports.

### F1.3 Unknown/fail-closed audit

Search production resolvers/kernels for engineering-significant fallback patterns such as:

```text
value ?? 0
value ?? 1
implicit material
implicit ambient temperature
implicit grouping factor
implicit installation method
implicit efficiency/resistance/current rating/reserve/overhead/loss/battery data
```

Each finding must be classified as:

```text
VALID_DOMAIN_INVARIANT
EXPLICIT_VERSIONED_DEFAULT
BLOCKED/PARTIAL/UNRESOLVED_REQUIRED
DEFECT_FIXED
```

Mandatory unknown input must never become silent PASS.

### F1.4 Provenance graph

Define/reconcile a common minimal trace graph:

```text
SOURCE_FACT / EXTERNAL_EVIDENCE
  -> DERIVED_INPUT
  -> ALGORITHM
  -> SCENARIO
  -> RESULT
  -> FINDING
```

Use stable IDs and immutable hashes. Do not embed entire source aggregates into every result.

Result trace must answer:
- why this value;
- which source facts/evidence;
- which algorithm/version;
- which project revision/scenario;
- which governing case/section;
- which authority/ruleset where applicable.

### F1.5 Calculation identity and canonicalization

Reconcile accepted evaluation identity to include at minimum:

```text
processCode
processVersion
algorithmId
algorithmVersion
inputSchemaVersion
resultSchemaVersion
rulesetVersion
projectRevisionId
subject/scope
scenarioId
sourceSha
authorityFingerprint
inputFingerprint
outputFingerprint
```

Determinism gates:
- map/set insertion order cannot alter unordered results/hashes;
- repository row order cannot alter results;
- worker/isolate scheduling cannot alter results;
- physically ordered routes/sequences remain explicitly order-sensitive;
- decimal/unit/enum/null canonicalization is stable.

### F1.6 Independent result axes

Preserve independent axes:

```text
Freshness  CURRENT | STALE
Completion COMPLETE | PARTIAL | BLOCKED
Assessment PASS | FAIL | UNRESOLVED | NOT_ASSESSED
Execution  SUCCEEDED | FAILED
```

No adapter may collapse execution failure into engineering FAIL, or normative unresolved into technical PASS.

### F1.7 Governing result

For multi-case/section processes expose typed deterministic governing evidence:

```text
governingScenarioId
governingSectionId
governingValue
governingMargin
governingReason
tieBreakRule
```

Tie-break must be code-owned and deterministic.

### F1.8 Shared qualification support

Create test/support-only reusable primitives for:

```text
reference vectors
independent oracle comparison
boundary triplets
property tests
metamorphic tests
scenario fixtures
provenance assertions
determinism assertions
replay assertions
```

No production dependency on a test framework.

### F1 exit gate

F1 may be marked complete only when:
1. inventory matrices are source-backed;
2. critical silent-default findings are closed or explicitly blocked;
3. common evidence/provenance/identity/status contracts are implemented or existing equivalents formally mapped;
4. deterministic canonicalization tests exist;
5. shared qualification support is executable;
6. exact source SHA is recorded.

## 4. F2 — Pilot Qualification

Pilots:

```text
AMPACITY_ROUTE_IZ
FA-03
ACS-03
CCTV-03
LAN-05
```

Every pilot executes the same profile:

```text
Q0 contract/schema/inventory
Q1 mathematical reference vectors
Q2 independent oracle
Q3 boundary qualification
Q4 property/metamorphic qualification
Q5 realistic scenario/combinatorial qualification
Q6 persistence/replay/invalidation/publication
Q7 failure/concurrency/restart
Q8 freeze/historical determinism
Q9 performance bounds where applicable
```

A pilot stays below `QUALIFIED` until every applicable mandatory Q gate has exact-SHA evidence.

## 5. Pilot-specific additions

### AMPACITY_ROUTE_IZ

Retain ownership boundaries:

```text
ELV3 physical cable/route facts
shared/ELV4 physical electrical basis
ELV7 jurisdictional ampacity rules/evidence
ELV8 exact SKU selection
```

Required model supports at least:

```text
crossSection
conductorMaterial
insulation/temperature class
installationMethod
ambientTemperature
grouping
numberOfLoadedConductors
routeSections
parallelConductors
referenceAmpacity + evidence
correctionFactors
designCurrent Ib
protectiveDeviceCurrent In when applicable
```

Core relation:

```text
Iz_section = Iz_reference * k_temperature * k_grouping * k_installation * ...
Iz_route = min(Iz_section...)
```

Persist governing section. If coordination applies, qualify `Ib <= In <= Iz` without issuing ELV7 normative PASS unless normative evidence is resolved. A physically complete Iz result with unresolved normative profile may legitimately be `COMPLETE + UNRESOLVED`.

Mandatory boundaries/properties include below/equal/above Iz, protective-current boundaries, correction-factor boundaries, mixed route sections, shared route, parallel conductors, monotonic cross-section/correction behavior, route-minimum property and permutation invariance for independent unordered section sets.

### FA-03

Adopt foundation without rewriting a verified kernel unnecessarily. Qualify source voltage, route resistance, current, terminal voltage, shared trunk current and worst endpoint. Independently verify:

```text
dU = I * Rloop
Uload = Usource - sum(dU)
```

and prove the resistance convention does not double-count forward/return resistance.

### ACS-03

Preserve the canonical reference oracle when applicable:

```text
23.51 V
+1.51 V margin
```

Do not edit expected values to fit implementation. Production/oracle disagreement beyond the declared tolerance blocks qualification. Include exact boundary, below/above, cable-resistance, route-length, current, missing-evidence, replay and ordering/worker vectors.

### CCTV-03

Use as the time-integration/storage pilot. Qualification must cover bitrate, stream count, schedule, retention duration, reserve multiplier and codec/profile evidence when applicable. Storage arithmetic, schedule ownership and temporal boundary behavior must be independently oracle-checked.

### LAN-05

Use as the logarithmic/interval optical pilot. Qualification must preserve independent optical budget derivation, exact/interval loss provenance, boundary margin behavior and deterministic path/event ordering.

## 6. Fixed execution order (2026-10-17)

The following order supersedes the earlier parallel development order. A later
step must not promote qualification before its preceding gate is satisfied.

1. Fix the formatter diff blocking FA-03 production qualification.
2. Obtain `flutter analyze` and `flutter test` PASS on the exact source commit.
3. Only after that PASS, promote FA-03 Q6 to `PASS_PRODUCTION_PATH`.
4. Connect CCTV-03, LAN-05 and ACS-03 to `Elv5F2QualificationHarness`.
5. Migrate the remaining processes in waves to the same Q6/Q7/Q8 lifecycle.
6. Close the automatic witness matrix and provenance.
7. Run the common rollback/CAS/restart/freeze/fault suite.
8. Obtain final exact-SHA CI PASS.
9. Only then, after every acceptance gate is satisfied, claim `ELV5 = ACCEPTED`.

### FA-03 Q6 verified checkpoint

At this historical FA-03 checkpoint, steps 1–3 were complete. The current
production-wave checkpoint below supersedes that progress position.

- Verified source commit: `f9def8bbad951ccc6bef7b576600a459a05862d0`.
- [Flutter Local Foundation run 39046456889](https://github.com/alimbetov/electra/actions/runs/39046456889): PASS.
- Mobile formatter and analyze: PASS; mobile tests: 454 passed, 1 skipped.
- Core formatter and analyze: PASS; core tests: 484 passed.
- FA-03 production witness: `apps/mobile/test/data/elv5_f2_fa03_production_runtime_e2e_test.dart`.
- Verification log artifact: `12106376397`.
- Q6 promotion is evidence for the verified source commit, not a claim that
  the status-recording commit or future source changes have passed CI.
- The skipped historical migration matrix remains a separate execution
  obligation in step 7.
- Full process qualification, automatic provenance and ELV5 acceptance remain
  pending. This checkpoint does not satisfy those gates.

### Production qualification wave checkpoint

The baseline harness is integrated. FA-08 Q6/Q7/Q8/Q9 are verified on
`0f7e9a9d78be11629793c33f470b723c1e98f8a6` by
[run 39054479428](https://github.com/alimbetov/electra/actions/runs/39054479428).
Both formatters/analyzers pass; mobile: 457 passed, 1 skipped; core: 485 passed.
Verification logs: artifact `12109445841`. The historical migration skip is
still an explicit global-suite obligation.

| Wave | Processes | Current gate |
| --- | --- | --- |
| 0 | CCTV-03, LAN-05, ACS-03, FA-03 | Baseline harness integrated; final reconciliation/seal pending |
| 1 | FA-08 | Production Q6–Q9 CI verified; full qualification/seal pending |
| 2 | FA-01, FA-02, FA-04, FA-05, FA-06, FA-07 | Q6–Q8 source witnesses exact-SHA CI verified; full qualification/seal pending |
| 3 | ACS-01, ACS-02, ACS-04, ACS-05, ACS-06 | Q6–Q8 source witnesses exact-SHA CI verified; full qualification/seal pending |
| 4 | LAN-01, LAN-02, LAN-03, LAN-04, LAN-06, LAN-07 | NEXT — ACS exact-SHA barrier passed |
| 5 | CCTV-01, CCTV-02, CCTV-04, CCTV-05, CCTV-06 | Pending LAN exact-SHA barrier |

These are 27 distinct process codes. Each wave requires its own complete
exact-SHA CI barrier. After all witnesses exist, reconcile all 27 records,
generate the execution-backed witness matrix, seal provenance, run the global
rollback/CAS/restart/freeze/fault suite, then require final exact-SHA CI before
acceptance. Q0–Q5 and automatic provenance remain pending for FA-08; this record
is not a `QUALIFIED` or `ACCEPTED` claim. The status-recording commit seals the
already-tested source commit and is not itself represented as verified code.

## 7. Current adoption baseline

At the baseline when this execution process was introduced:

```text
ELV5 process codes:       27 fixed
Production adapters:      21 / 27
ACS runtime:              6 / 6
Fire runtime:             8 / 8
LAN runtime:              5 / 7
CCTV runtime:             2 / 6
Remaining runtime:        6

Foundation F0:            DESIGNED / authority established
Foundation F1:            IN PROGRESS / not qualified
Foundation F2:            NOT QUALIFIED; pilot implementation partially exists
ELV5 acceptance:          NOT CLAIMED
```

Remaining runtime verticals:

```text
LAN-06
LAN-07
CCTV-01
CCTV-04
CCTV-05
CCTV-06
```

This baseline is descriptive, not a permanent truth. Machine status must be updated from source/test/persistence/application/qualification evidence on the exact branch HEAD.

## 8. Reporting rule

Every development status report must separately state:

```text
runtime integration count
lifecycle by process/pilot
F1 gate status
F2 Q0-Q9 status
exact HEAD SHA
CI/analyze/test evidence actually executed
known blockers/debts
```

Never report `PASS`, `QUALIFIED`, `ACCEPTED` or CI success merely because code/tests were committed.

## FIRE lifecycle checkpoint — FA-01 / FA-02 / FA-07

Source `a30cdded0cb745140bab7a4ac25320ce0254ff05` passed complete
Flutter Local Foundation run `39065428504`, artifact `12112709305`:
460 mobile tests passed, one historical-migration test skipped by its dedicated
suite contract, 485 engineering-core tests passed, both analyzers and formatters
passed. The logs explicitly execute all three production witnesses.

FA-01 and FA-07 exercise complete PASS→FAIL republication; FA-02 deliberately
retains COMPLETE / NOTASSESSED because exact current aggregation has no capacity
authority. Its witness verifies all three operating cases, an authoritative
load-profile replacement, invalidation/recalculation, independent-connection CAS,
restart and frozen replay. Lifecycle PASS must not invent a capacity verdict.

Q6/Q7/Q8 coverage is now 8/27. Q0–Q5/Q9 reconciliation, automatic matrix and
provenance seal remain open; qualified stays 0/27 and ELV5 is not ACCEPTED.
FA-04/05/06 form the next FIRE mini-wave with a separate exact-SHA barrier.

## FIRE mini-wave checkpoint — FA-04 / FA-05 / FA-06

Source `35e5e38b779cae91e1e9e78b9fc61a379bd11384` passed complete
Flutter Local Foundation run `39067220413`, artifact `12113837997`:
464 mobile tests passed, one dedicated historical-migration skip, 485 core tests
passed, both analyzers and formatters passed. All three named production
lifecycle witnesses execute successfully in the preserved logs.

FA-04 consumes PWR01/PWR02 CURRENT and changes +4 W to -4 W margin. Its fault
at ELV5 invalidation rolls back the public ELV4 definition replacement, its
design CAS and pointer transition. FA-05 consumes a real published PWR04 chain
including its consumed PWR01 identity and persisted backup-sequence fact;
energy margin changes +115.2 Wh to -2.4 Wh. FA-06 consumes active/startup PWR01
and exactly solved PWR03 terminal envelopes; startup current margin changes
+0.05 A to -0.05 A, with rollback of a failed contract invalidation.

Both ELV4 mutation implementations propagate STALE to exact ELV5 consumers in
the same transaction. Guarded republication preserves that invalidation without
double-incrementing an already STALE consumer. Database reopen no longer tries
INSERT OR IGNORE for already seeded catalog rows; a SQL fault regression proves
reopen remains read-only for initialized catalogs while the existing two-SQLite
connection allocation race remains enabled.

Lifecycle coverage is 11/27, qualified remains 0/27. This is a Q6–Q8 checkpoint;
Q0–Q5/Q9 reconciliation, global reliability, automatic matrix/provenance and
final acceptance remain open. The next ordered wave is ACS-01/02/04/05/06.

## ACS wave checkpoint

Source `da9d34abb25ca57fbf7e1a6d45ddc30965a0ba8c` passed complete
Flutter Local Foundation run `39068040087`, artifact `12114187319`:
469 mobile tests passed, one dedicated historical-migration skip, 485 core tests
passed, both analyzers and formatters passed. Preserved logs explicitly execute
ACS-01/02/04/05/06 production witnesses through the common lifecycle harness.

ACS-01 changes the exact mandatory-lock role count from satisfied to deficient,
with a failed-invalidation transaction rollback. ACS-02 marks an assigned relay
unavailable and fails on the physical assignment conflict without inventing
capacity. ACS-04/05 project the shared verified CURRENT power/energy chain and
preserve its global requirement and consumed provenance. ACS-06 changes an
actual persisted contract edge so the required fire-release path fails while
the complete five-cause model remains present. All five assert independent
SQLite CAS, durable restart, exact frozen replay and source read-only rejection.

The atomic ACS contract coordinator persists each edition/design CAS and its
old consumed evidence-reference invalidation in one SQLite transaction.
Lifecycle coverage is 16/27, qualified remains 0/27. Q0–Q5/Q9 reconciliation,
automatic provenance, global reliability and acceptance remain open. The next
ordered wave is LAN-01/02/03/04/06/07; CCTV follows its exact-SHA barrier.


## LAN wave checkpoint

Source `685c0df22b3b5c8d762ef6e71b2e55c72a006fc3` passed complete
Flutter Local Foundation run `39069134142`, artifact `12115165171`:
475 mobile tests passed, one dedicated historical-migration skip, 485 core tests
passed, both analyzers and formatters passed. Preserved logs explicitly execute
LAN-01/02/03/04/06/07 production witnesses through the common lifecycle harness.

LAN-01 consumes exact persisted ELV3 geometry and authoritative composition;
COMPLETE / NOTASSESSED is retained because numeric threshold authority is absent.
LAN-02 rejects an assigned endpoint above its port speed. LAN-03 projects the
complete PWR06 LAN+CCTV closure: 30 W global demand, 18 W LAN contribution,
and global margin +5 W to -3 W. LAN-04 rejects an incompatible section mode.
LAN-06 reads the actual rack write unit of work and changes RU margin +2 to -1;
layout remains unassessed, owned by ELV6. LAN-07 changes spare port margin +1
to -1 when two unused ports become unavailable. All six cover independent
SQLite CAS, durable restart, exact frozen replay and source read-only rejection.

The LAN rack calculation adapter now dispatches to its actual rack persistence
boundary. Atomic LAN contract replacement invalidates consumers of the previous
immutable policy edition in the same transaction as source/design CAS.
Lifecycle coverage is 22/27, qualified remains 0/27. The next remaining wave is
CCTV-01/02/04/05/06; its source is committed and its own exact-SHA CI is pending.
Q0–Q5/Q9 reconciliation, automatic provenance, global reliability and final
acceptance remain open. ELV5 is not ACCEPTED.


## CCTV wave and FA-03 production lifecycle checkpoint

Source `03de876b063a9db4f290f3c10f54f9481c008e02` passed complete
Flutter Local Foundation run `39070036186`, artifact `12114309867`:
484 mobile tests passed, one dedicated historical-migration skip, 485 core tests
passed, both analyzers and formatters passed. Preserved logs explicitly execute
CCTV-01/02/04/05/06 and the new full-production FA-03 lifecycle witness.

CCTV-01 uses persisted integer geometry and immutable exact orthonormal frames;
a focal-length replacement changes full coverage to exactly 3/16. CCTV-02 uses
public streams and explicit recorder assignment, doubles exact ingress, and
retains COMPLETE / NOTASSESSED without capacity authority. CCTV-04 projects the
shared 30 W PWR06 closure, including LAN demand, and fails its -3 W global margin.
CCTV-05 consumes real CURRENT results calculated and published by CCTV-02/03;
storage changes from +70.4 GB to -29.6 GB without reserve being applied again.
CCTV-06 verifies the exact 1 m ELV3 link at its inclusive limit, then fails at
an explicit 0.5 m maximum. FA-03 now covers independent SQLite CAS, durable
restart and frozen replay through its real registry, plus atomic invalidation
when terminal-voltage policy changes. The old adapter-based witness is retained
as lower-level regression evidence, not the production Q7/Q8 witness.

CCTV-05 exposed a production read-model defect: canonical persisted NOTASSESSED
was rejected even though the runtime writes it. The reader now accepts this
and historical NOT_ASSESSED, preserves the original persisted spelling, and
continues rejecting unknown vocabulary; three regression cases pass in CI.

Q6/Q7/Q8 production lifecycle coverage is now 27/27. This completes the process
wave stage only: qualified stays 0/27, Q0–Q5/Q9 reconciliation remains open,
and automatic execution-backed matrix/provenance is the next fixed stage.
Global rollback/CAS/restart/freeze/fault qualification, final exact-SHA CI and
ELV5 acceptance are still pending. ELV5 is not ACCEPTED.
