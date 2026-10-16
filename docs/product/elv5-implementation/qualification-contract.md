# ELV5 — Executable qualification, adversarial testing and closure contract

Status: DESIGN DRAFT / RUNTIME NOT STARTED  
Branch: `feat/flutter-elv5-power-topology-design`  
Authority: [P8 acceptance](p8-acceptance.md), [27 process contracts](process-contracts.md), [typed process API](typed-process-api.md), [engineering primitives](engineering-primitives-contract.md), [schema 24](persistence-schema-contract.md).

This document defines what must be executed to claim that ELV5 is implemented. It intentionally separates formula correctness, persistence correctness, public-command behavior, concurrency safety and engineering claim correctness. A green unit test for a formula is not ELV5 acceptance.

## 1. Test pyramid is mandatory, not optional

ELV5 runtime qualification has seven layers:

```text
L0  primitive / exact-numeric / canonical-hash tests
L1  pure typed process kernel tests
L2  strict wire codec / semantic validation tests
L3  repository + schema-24 migration + restart tests
L4  application service / UoW / replay / history tests
L5  public-command vertical process qualification
L6  concurrency / failure-injection / freeze / historical matrix
```

A process is runtime-qualified only when its relevant layers pass on the same exact source SHA used for P9 closure.

## 2. Planned source/test layout

Recommended implementation/test layout:

```text
packages/engineering_core/lib/src/elv5/
  numeric/
  evidence/
  canonical/
  processes/

packages/engineering_core/test/elv5/
  primitives/
  cctv/
  lan/
  acs/
  fire_alarm/
  registry/

apps/mobile/lib/application/elv5/
  wire/
  commands/
  calculation/
  workspace/

apps/mobile/lib/data/elv5/
  repositories/
  migration/
  projections/

apps/mobile/test/elv5/
  wire/
  persistence/
  commands/
  qualification/
  races/
  migration/
  freeze/
```

Tests may be split differently, but P9 evidence must identify the production source file and executed test file for every requirement/process/command.

## 3. Machine-readable qualification manifest

P8 MUST add:

```text
docs/product/elv5-implementation/qualification-manifest.json
```

Schema:

```text
electra.elv5-qualification-manifest.v1
```

Exactly 54 primary process entries are required: POS and NEG/UNSUPPORTED for each of 27 process codes.

Each entry contains:

```json
{
  "processCode": "CCTV-01",
  "oracleId": "CCTV-01-POS",
  "fixtureId": "fixture-cctv-coverage-v1",
  "setupCommandIds": ["..."],
  "calculationCommandId": "...",
  "scope": {"kind": "DESIGN", "scopeId": "...", "scenarioKey": "NONE"},
  "subject": {"kind": "...", "id": "..."},
  "operatingCaseId": "...",
  "requiredDimensions": ["..."],
  "expectedExecution": "SUCCEEDED",
  "expectedCompletion": "COMPLETE",
  "expectedAssessment": "PASS",
  "expectedDimensionStatuses": {},
  "expectedFindingCodes": [],
  "expectedAffectedProcessCodes": [],
  "expectedUnaffectedProcessCodes": [],
  "claimScope": "...",
  "sourceBasisExpectations": [],
  "publicSetupOnly": true
}
```

The manifest is test input. Runtime tests must reject a manifest/process-registry mismatch.

## 4. L0 — engineering primitive qualification

Required test groups:

```text
elv5_quantity_dimension_test.dart
elv5_rational_normalization_test.dart
elv5_decimal_codec_test.dart
elv5_interval_comparison_test.dart
elv5_evidence_basis_test.dart
elv5_canonical_json_test.dart
elv5_fingerprint_projection_test.dart
elv5_temporal_policy_test.dart
elv5_coordinate_frame_test.dart
elv5_finding_codec_test.dart
```

Minimum assertions:

- exact rational arithmetic has no binary floating drift;
- `dB` and `dBm` use separate types/operations;
- bit/s → byte capacity is exact until declared ceil;
- typical/estimated value cannot satisfy a guaranteed-bound requirement;
- reserve cannot change evidence basis;
- map/set insertion order cannot change canonical hash;
- ordered engineering path order does change canonical hash;
- output hash ignores evaluation ID/timestamp but changes on engineering output change;
- tzdb/DST policy is explicit and deterministic;
- mixed geometry frames reject without an exact transform.

## 5. L1 — typed kernel qualification

Every process gets at least:

```text
<process>_positive_test
<process>_negative_test
<process>_boundary_test
<process>_determinism_test
<process>_claim_scope_test
```

The registered POS/NEG oracle is not enough to replace boundary tests. Boundary categories include zero, exact limit, one-unit-over-limit, missing optional vs mandatory evidence, duplicate identities, empty sets, maximum supported exact values and unsupported model discriminator.

### 5.1 Metamorphic invariants

Where applicable, test relations rather than only fixed expected numbers:

- reordering an unordered membership set does not change output hash;
- reordering an ordered path changes the path fingerprint and may change output;
- increasing a nonnegative load cannot improve a capacity margin under the same model;
- increasing physical loss cannot improve optical sensitivity margin;
- increasing available capacity cannot turn PASS into FAIL if all other facts are identical;
- adding an unrelated subject cannot change an isolated node result;
- adding a relevant set member must invalidate/change the exact dependent node;
- splitting one recording interval into adjacent half-open intervals with the same union leaves storage result unchanged;
- duplicate interval overlap does not increase unique recorded time;
- converting equivalent exact units before typed resolution leaves the normalized result unchanged.

These are deterministic property loops over bounded fixtures; no uncontrolled randomness is needed in CI.

## 6. CCTV qualification matrix

### CCTV-01

Must prove:

- normal-incidence footprint and bounded H/V FOV;
- behind-plane/horizon ray rejection;
- mixed frame rejection;
- unsupported fisheye/distortion/occlusion model does not produce complete PASS;
- optional pixel-density technical output, when implemented, does not imply DORI recognition/identification compliance.

### CCTV-02

Must prove:

- expected and peak remain separate;
- two unicast receivers create two edge copies where paths overlap;
- multicast dedup only under registered multicast tree semantics;
- payload bitrate is not silently treated as wire bitrate when overhead/capacity comparison requires an overhead model;
- no duplicate encoded stream from repeated system membership.

### CCTV-03

Must prove:

- exact interval union;
- timezone recurrence expansion with pinned rules;
- pool-level one-time ceil;
- reserve applied once;
- redundancy usable fraction applied once;
- EXPECTED_ESTIMATE cannot claim guaranteed retention;
- guaranteed upper bound missing → unresolved claim dimension;
- duplicate `(stream,pool,copyRole)` rejected.

### CCTV-04

Must prove one immutable PWR-06 global evaluation is consumed and selected CCTV contribution is only a breakdown.

### CCTV-05

Must independently prove DEVICE, ENCODED_STREAM and LICENSE_CHANNEL accounting, ingress, codec compatibility and storage. A one-camera/two-stream fixture must produce different channel verdicts for DEVICE and ENCODED_STREAM accounting while ingress remains the sum of streams.

### CCTV-06

Must prove realized path only, correct powered-segment applicability and no room-distance estimation fallback.

## 7. LAN qualification matrix

### LAN-01

Permanent sections, patch sections and already-included service loops are counted exactly once. Exact-limit and one-unit-over-limit cases are required.

### LAN-02

Must prove unique physical ports, media/speed mismatch, spare ceiling and pre-reserved port accounting.

### LAN-03

Must share the same PWR-06 physical evidence as CCTV-04 when the PSE is common.

### LAN-04

Must prove path capability is limited by the weakest passive section. A correct cable with one incompatible patch/connector fails.

### LAN-05

Must prove both directions, sensitivity and overload independently, connector-pair identity, physical loss separate from design margin, signed dBm math and optional reach-profile claim separation.

### LAN-06

Must prove GROSS_WITH_EXCLUSIONS and NET_USABLE equivalence where they represent the same usable capacity. RU demand/capacity may PASS while actual ELV6 layout fit remains NOT_ASSESSED.

### LAN-07

Must prove unique panel-port occupancy, spare capacity and complete endpoint/destination mapping.

## 8. ACS qualification matrix

### ACS-01

Must prove role alternatives, multiplicity and prohibited role inference from labels.

### ACS-02

Reader/relay/input resource pools are independent. One pool failure cannot be masked by another pool margin.

### ACS-03

Must prove selected lock state, startup/holding distinction, shared trunk current, terminal voltage and dry-contact-vs-power-feed separation.

### ACS-04

Must prove reserve/derating is composed at the physical source requirement boundary once and all shared loads remain in the source demand.

### ACS-05

Must prove full protected sequence and non-ACS concurrent protected loads remain in the global bank requirement.

### ACS-06

Must execute a truth table containing at least:

```text
normalAccess
requestToExit
fireRelease
emergencyBreakGlass
powerFailure
```

for one fail-safe and one fail-secure/project-defined fixture. The test verifies technical path/evidence behavior only and asserts that verified egress/fire-code compliance is NOT claimed by ELV5.

## 9. Fire-alarm qualification matrix

### FA-01

Must prove physical device count and full expanded address set independently, including overlapping multi-address modules and reserved addresses.

### FA-02

Must prove standby/alarm cases, panel/module own-load accounting and partial result when one mandatory device state current is missing.

### FA-03

Must prove supported radial electrical model and reject an unsupported dual-feed/shared-return model without pretending that signal topology solves power flow.

### FA-04

Must include all fire and non-fire loads sharing the source and apply policy requirement once.

### FA-05

Must prove explicit ordered standby/alarm durations and bank model applicability; no default autonomy hours.

### FA-06

Must separately prove count, active/startup output current and terminal voltage. Acoustic/visual coverage remains out of claim.

### FA-07

Must prove signal closure, branch policy, address-topology consistency and that isolator presence alone is not survivability proof.

### FA-08

Must prove policy match/evidence completeness separately from verified compliance. FICTIONAL/PROJECT_AUTHORED policy cannot create VERIFIED_COMPLIANT.

## 10. L2 — wire/codec adversarial matrix

For every one of 16 commands execute:

```text
valid canonical payload
missing each required top-level field
one unknown top-level field
wrong top-level type
unsupported schema
unsupported operation
unsupported payloadSchemaVersion
missing each required payload field
one unknown payload field
wrong nested type
empty/oversized identity where prohibited
foreign-project identity
semantic duplicate identity
stale expected row revision
stale reviewed impact
same commandId/same request replay
same commandId/different request conflict
```

The 16 canonical examples in `command-examples.json` are seed fixtures, not the entire adversarial matrix.

## 11. L3 — schema 24 and restart matrix

Use a real temporary file SQLite database. In-memory SQLite alone cannot close P2/P8.

Required scenarios:

```text
fresh schema 24
23 -> 24
supported historical origin -> ... -> 23 -> 24
failed migration rollback
all ELV5 root/child sets close/reopen
immutable evaluation close/reopen
pointer generation close/reopen
reverse index close/reopen
snapshot discipline section close/reopen
legacy snapshot read
captured-empty snapshot read
```

After migration, compare exact accepted ELV3/ELV4 evidence hashes/row identities before and after. Migration success must not be inferred only from `user_version=24`.

## 12. L4 — command/UoW/history matrix

For every replacement command inject a failure at these ownership boundaries where applicable:

```text
after replay lookup
before root write
after root write
mid child replacement
after child replacement
mid dependency invalidation
after invalidation
before history append
after history append
before ledger save
after ledger save before commit
```

Every injected failure must leave the reopened database at the pre-command committed state. No hybrid old/new child set is permitted.

Undo/redo qualification proves complete forward/inverse payload after restart and history cursor conflict detection.

## 13. L5 — public vertical qualification

No primary POS/NEG process oracle may call `calculate()` directly as its only acceptance path. It must:

```text
strict public setup commands
  -> real persisted roots/canonical facts
  -> public CALCULATE_DISCIPLINE_PROCESS
  -> production capture resolver
  -> runtime registry typed definition
  -> pure kernel
  -> production guarded publish
  -> projection/read API
  -> close DB
  -> reopen DB
  -> verify immutable evidence + current pointer + explanation
```

Direct kernel tests remain L1 and are necessary but not sufficient.

## 14. L6 — deterministic concurrency matrix

Use two independent database connections or repository sessions against the same temporary file where the platform permits. Barriers must stop the first operation at known protocol points.

Required races:

| Race | Required outcome |
|---|---|
| capture vs relevant aspect edit | stale/conflict; no stale CURRENT publish |
| capture vs unrelated edit | publication may succeed if consumed fingerprint/generations unchanged |
| two publish attempts same pointer generation | at most one advances from the captured generation |
| capture vs policy adoption | stale if consumed policy binding/edition changed |
| capture vs shared ELV4 pointer generation | all exact wrappers consuming it stale/conflict |
| publish vs freeze | freeze winner prevents late CURRENT |
| replace vs replace same aggregate | one CAS/revision conflict; no hybrid members |
| undo/redo vs new edit | cursor-generation conflict handled deterministically |
| response loss after commit | same request replay returns stored logical result |
| create-next vs old-revision late publish | old late publisher cannot attach to new revision |

Tests must not use sleeps as the correctness synchronization mechanism; use explicit barriers/hooks/fakes around transaction protocol boundaries.

## 15. Cross-discipline integrated fixture

At least one P8 fixture contains:

```text
CCTV cameras + streams + recorder/storage
LAN switch + copper/fiber links + patch panel + rack demand
ACS controller + reader + lock + door release paths
FA loop + addressable devices + notification circuit
shared ELV4 DC supply/PSE where technically applicable
shared protected bank with composed sequence
realized ELV3 cable/resource paths
```

The purpose is to prove non-duplication and fan-out, not to pretend every discipline shares every physical source.

Assertions include:

- one physical source/bank evaluation identity per actual shared context;
- discipline-specific contribution views sum consistently with source membership;
- editing CCTV stream bitrate invalidates bandwidth/storage/recorder consumers but not door-role completeness;
- editing a shared source or bank fans out to all exact consumers;
- editing one fire address assignment does not invalidate unrelated optical budget;
- old frozen R1 remains byte/hash stable after R2 edits.

## 16. Engineering explanation qualification

Every process POS and NEG result is checked through the workspace/read projection for:

```text
process code + subject + scope + operating case
current/stale freshness
completion/assessment/execution axes
required dimensions
actual/required/margin values with canonical units
stable finding codes
calculation steps
policy edition/hash
source provenance
upstream immutable evidence refs
claim-scope limitations
```

A result that computes the right number but cannot identify why it passed/failed is not acceptable engineering evidence.

## 17. Golden engineering report contract

P8 SHOULD generate a machine comparison projection, not screenshot goldens, for at least one process per discipline:

```json
{
  "processCode": "LAN-05",
  "subject": {},
  "scope": {},
  "status": {},
  "dimensions": [],
  "steps": [],
  "findings": [],
  "provenance": []
}
```

Golden semantics compare canonical fields/hashes, not localized prose or UI pixel layout.

## 18. Performance and scale qualification

No arbitrary production performance claim is made before measurement. Nevertheless P8 must prevent accidental pathological algorithms with deterministic scale fixtures.

Minimum synthetic fixture sizes:

```text
1000 CCTV encoded streams
10000 recording schedule segments before interval union
5000 LAN port/patch assignments
2000 ACS door/resource assignments
10000 fire address claims
5000 dependency reverse-index edges
500 requested evaluation nodes in one workspace batch
```

Record elapsed time and peak memory as benchmark evidence, but do not set an engineering PASS threshold until representative target hardware and product SLO are formally selected. Functional tests must assert algorithmic termination and no recursion/SQL-variable-limit failure for supported batch chunking.

## 19. Security/robustness boundary tests

ELV5 is not a scripting engine. Tests must reject:

- executable formula/script fields in policy/process input;
- unknown polymorphic discriminator;
- oversized recursively nested command payload beyond the application codec limit;
- duplicate JSON object keys at the canonical parsing boundary;
- non-finite numeric text/host double values;
- path traversal or file paths in fields that accept only opaque IDs;
- localized number strings such as `1,25` at strict engineering codecs unless a UI parser converted them before the wire boundary.

These are input-integrity tests, not a substitute for a full application security review.

## 20. No-false-PASS sentinels

P8 must contain explicit sentinels proving that all of these remain impossible:

```text
unsupported model -> PASS
missing mandatory input -> PASS
stale old PASS displayed as current PASS
fictional/project-authored policy -> verified national compliance
LAN-06 RU basis -> actual rack fit PASS
FA-08 policy match -> certified fire compliance
CCTV geometry -> visibility through obstruction
CCTV pixel density -> DORI/legal identification claim
optical power budget -> reach/dispersion PASS without reach model
ACS technical release topology -> verified legal egress compliance
ELV5 contribution subtotal -> shared physical source total
ELV5 new revision -> retagged old immutable evaluation
legacy pre-ELV5 snapshot -> captured-empty/current PASS
```

Any one false-PASS sentinel failure is P0 severity for ELV5 closure.

## 21. P9 exact-head evidence ledger

P9 closure ledger must reconcile at one source SHA:

```text
80 stable requirements
27 process definitions
54 primary process oracle entries
16 public command codecs
16 canonical valid examples + deterministic rejection mutations
schema-24 migration matrix
primitive test inventory
race/failure matrix
source paths
executed test names
workflow run/job/artifact IDs
result/limitations
```

No evidence from a different SHA can silently close the current HEAD.

## 22. Runtime closure rule

ELV5 is runtime-acceptable only if:

```text
all structural design guards PASS
AND Flutter/Dart analyze PASS
AND all mobile/core tests PASS
AND schema-24 migration/reopen matrix PASS
AND 54 public process oracles PASS
AND all 16 command codecs pass adversarial/replay tests
AND failure injection shows atomic rollback
AND deterministic race matrix PASS
AND R1/R2 freeze/history immutability PASS
AND no BLOCKER/HIGH remains undisposed
AND P9 ledger points to the exact tested SHA
```

This specification itself remains design evidence and does not imply those runtime results have occurred.
