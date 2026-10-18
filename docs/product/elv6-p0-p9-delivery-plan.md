# ELV6 — P0–P9 executable delivery plan

Status: **DESIGN HARDENED / ALL RUNTIME PACKAGES OPEN**  
Branch: `feat/flutter-elv6-enclosure-layout-design`  
Pinned design upstream ELV5: `ed7db01adb27ff184b0b8c91a710082fb9eafb9a`  
Specification: [ELV6 design](elv6-enclosure-layout-design-specification.md)  
Code contract: [runtime contract](elv6-implementation/code-level-runtime-contract.md)

This plan contains **80 stable requirements: 8 per package P0–P9**. A package closes only when every requirement has source/test/exact-SHA evidence. Design text, screenshots and structural JSON validators do not count as runtime proof.

## Package map

| Package | Engineering responsibility | Primary runtime output |
|---|---|---|
| P0 | Baseline/ownership/upstream entry | evidenced owner/capability matrix and accepted entry SHA |
| P1 | Exact domain/numeric/registry model | fixed geometry + typed identities + 24 process definitions |
| P2 | Persistence/public mutation/revision | additive Drift schema + 21 strict commands + snapshots/history |
| P3 | Geometric and mounting kernels | host/surface/containment/collision/rack/DIN fit |
| P4 | Constructability-specialized kernels | service/door/cable/wiring/battery/load/mass/thermal/bonding |
| P5 | Deterministic auto-layout | immutable proposals + score vector + CAS acceptance |
| P6 | Cross-stage integration/invalidation | exact ELV3/4/5 adapters + targeted dependency closure |
| P7 | Engineer workspace | serious panel/rack editing and explainability UX |
| P8 | Integrated qualification | public-command/file-SQLite/race/migration/process evidence |
| P9 | Closure/handoff | exact-head reconciliation + ELV7/ELV8 projection contracts |

---

# P0 — baseline, ownership and runtime-entry audit

### ELV6-P0-001 — Pin exact upstream and branch ancestry
Record current ELV6 head, accepted/runtime ELV5 SHA separately from design-only upstream SHA, merged ELV4 prerequisite, current DB schema and supported migration origins. Design SHA must never be mislabeled runtime acceptance.

Acceptance: `P0-T01` asserts exact SHAs/schema in machine baseline manifest.

### ELV6-P0-002 — Classify every legacy panel capability
For `PanelAssembly`, enclosure geometry, mounting sections, DIN rails, placements, terminal rails, ducts and zones record semantic model, persistence, public writer, revision integration, replay/history, freeze/create-next and runtime qualification independently.

Acceptance: `P0-T02` owner matrix has no `UNKNOWN`/assumed rows.

### ELV6-P0-003 — Prove one canonical writer per fact kind
Inventory all tables/repositories/services/widgets/importers that can mutate panel/rack-like physical facts. Resolve duplicate writers before implementation.

Acceptance: `P0-T03` no fact kind has two active canonical writers.

### ELV6-P0-004 — Decide panel persistence mode
Choose exactly one: `REUSE_ACCEPTED_PANEL_WRITER` or `PROMOTE_PANEL_SEMANTIC_BASELINE`. Promotion preserves existing IDs/terminology and does not create parallel generic-panel truth.

Acceptance: `P0-T04` decision is backed by source paths and compatibility tests.

### ELV6-P0-005 — Pin numeric compatibility boundary
Inventory project integer-mm geometry, legacy panel/catalog doubles and all serialization/hash paths. Freeze fixed-point µm import/export rules, magnitude bounds and legacy normalization tolerance.

Acceptance: `P0-T05` boundary fixtures include sub-mm dimensions, integer-mm round trip, NaN/infinity rejection and deterministic canonical text/hash.

### ELV6-P0-006 — Inventory exact upstream physical evidence
Map ELV3 cable/end/path facts, ELV4 battery/power evidence, ELV5 rack/patch/capacity facts and immutable technical-definition sources to ELV6 adapters, including missing capability gaps.

Acceptance: `P0-T06` every consumed fact has owner/path/version/fingerprint semantics.

### ELV6-P0-007 — Pin shared runtime protocols
Prove actual `ElvCommandResult`, command ledger/replay, UoW, history undo/redo, row revisions/CAS, freeze, create-next, snapshot and outbox capabilities to reuse.

Acceptance: `P0-T07` capability matrix links implemented source/tests, not architecture prose.

### ELV6-P0-008 — Produce runtime-entry verdict
Record `READY`, `BLOCKED_UPSTREAM`, or `BLOCKED_FOUNDATION` with explicit unresolved prerequisites. No later package may silently implement around a P0 blocker.

Acceptance: `P0-T08` machine baseline manifest and human audit agree.

**P0 exit:** exact baseline and ownership are proven. Runtime P1 is forbidden before P0 exit.

---

# P1 — exact domain, geometry, identities and registries

### ELV6-P1-001 — Implement fixed-point mechanical primitives
Implement signed integer-µm point/size/AABB/frame/discrete-span values with validation and canonical codecs independent of Flutter/Drift.

Acceptance: `P1-T01` exact arithmetic/boundary/hash tests.

### ELV6-P1-002 — Freeze coordinate and occupancy semantics
Implement one right-handed host frame, orthogonal V1 orientations and half-open AABB/U/DIN interval semantics. Front/rear UI is projection only.

Acceptance: `P1-T02` touching-face, one-µm overlap and front/rear transform oracles.

### ELV6-P1-003 — Implement typed owner/host/subject identities
Freeze host owner kind, host/logical IDs, design revision, row revision, typed immutable subject refs and installation-role cardinality.

Acceptance: `P1-T03` unknown owner/kind, cross-revision misuse and duplicate active subject placement are rejected.

### ELV6-P1-004 — Implement mounting surface/capability model
Define DIN/rack/shelf/backplate/door/terminal/battery-tray/custom surfaces with exact frames, usable envelopes, mounting modes and optional load/rack profile capability.

Acceptance: `P1-T04` missing capability remains unknown, never unlimited.

### ELV6-P1-005 — Implement physical subject definition
Separate body, mounting requirements, connector protrusions, service/removal/airflow envelopes, mass/CoG, heat loss and supported orientations with immutable definition hash.

Acceptance: `P1-T05` partial definitions affect only dependent result dimensions.

### ELV6-P1-006 — Implement positioned zones/entries/duct/bond basis
Model positioned layout zones, cable entries, internal ducts, termination positions and physical bonding points/links with typed identity/provenance.

Acceptance: `P1-T06` width-only legacy zone cannot produce geometry PASS until positioned.

### ELV6-P1-007 — Register exactly 24 layout processes
Compile code-owned definitions for `LAY-01…LAY-24`, exact algorithm/input/output versions, scopes, required dimensions and dependency DAG matching `process-registry.json`.

Acceptance: `P1-T07` registry rejects missing/extra/unknown/cycle/scope mismatch.

### ELV6-P1-008 — Freeze four-axis result semantics
Implement freshness/current-pointer, completion, assessment and execution independently; define stable finding codes/order.

Acceptance: `P1-T08` FAIL/PARTIAL/BLOCKED/STALE/execution failure cannot collapse to one state.

**P1 exit:** core package can represent every required physical fact without persistence/UI dependencies.

---

# P2 — persistence, commands, revision lifecycle and publication

### ELV6-P2-001 — Implement additive normalized persistence
Add only P0-approved panel promotion/reuse tables plus ELV6 rack/surface/placement/zone/entry/bond/proposal/evaluation/dependency roots with revision/logical IDs and row revisions.

Acceptance: `P2-T01` fresh-schema introspection proves PK/FK/UNIQUE/index contract and no duplicate owner.

### ELV6-P2-002 — Implement strict 21-operation wire registry
Register exactly the operations/payload key sets in `command-registry.json` under `electra.elv6-layout-command.v1`; unknown/missing fields and unknown version fail before mutation.

Acceptance: `P2-T02` codec registry totality and rejection matrix.

### ELV6-P2-003 — Implement server-side semantic/impact adapter
Wire payload never supplies trusted dependency closure. Server reloads owner rows, resolves old/new impact, validates expected rows and reviewed-impact fingerprint.

Acceptance: `P2-T03` forged client impact cannot suppress invalidation.

### ELV6-P2-004 — Implement replay-first atomic mutation
Ledger replay/payload conflict occurs before mutable preconditions; canonical state, dependency invalidation, full forward/inverse history, ledger response and outbox commit one UoW.

Acceptance: `P2-T04` response-loss replay and injected rollback after reopen.

### ELV6-P2-005 — Implement immutable evaluations/current pointers
Persist immutable layout evaluations and generation-guarded current pointers keyed by `layout-node-v1`; publish PASS/FAIL/PARTIAL/BLOCKED only from current capture.

Acceptance: `P2-T05` stale publisher cannot replace current evidence.

### ELV6-P2-006 — Implement proposal persistence and CAS lifecycle
Persist immutable generated proposals/items/score vectors/input hashes; acceptance rechecks all owner/dependency generations atomically; rejection never mutates layout.

Acceptance: `P2-T06` stale concurrent owner edit rejects proposal acceptance and retains draft/proposal evidence.

### ELV6-P2-007 — Extend coordinated freeze/create-next
Add versioned ELV6 snapshot section/hash and typed create-next remapping while preserving existing ELV3/4/5 section semantics. Pre-ELV6 snapshots return `ELV6_NOT_CAPTURED`.

Acceptance: `P2-T07` R1/R2 historical exactness and no latest fallback.

### ELV6-P2-008 — Implement migration matrix
Resolve target schema only after accepted ELV5 runtime schema; test fresh DB plus every supported predecessor, restart, failed migration rollback and old result isolation.

Acceptance: `P2-T08` migration fixtures at exact source SHA.

**P2 exit:** every canonical write has a public replay-safe transaction path; no widget writes Drift directly.

---

# P3 — core geometry and mounting kernels

### ELV6-P3-001 — LAY-01 host envelope
Implement positive/valid outer+usable geometry, containment and provenance evaluation.

Acceptance: `LAY-01-POS/NEG/BLOCKED`.

### ELV6-P3-002 — LAY-02 mounting surface capability
Resolve frames, usable surface envelopes, mounting modes and known/unknown load capability independently.

Acceptance: `LAY-02-POS/NEG/BLOCKED`.

### ELV6-P3-003 — LAY-03 placement containment
Transform body AABB into host frame and evaluate host/surface/depth containment exactly.

Acceptance: one-µm boundary oracles and missing-depth partial case.

### ELV6-P3-004 — LAY-04 volumetric collision
Evaluate active placement and blocking-zone intersections using half-open semantics and stable conflict ordering.

Acceptance: face-touch PASS, positive-volume overlap FAIL, old/new move closure.

### ELV6-P3-005 — LAY-05 rack U occupancy
Evaluate usable U, front/rear lane semantics, explicit reservations and exact used/free/reserved accounting.

Acceptance: overlapping U, out-of-range, double-reserve and front/rear fixtures.

### ELV6-P3-006 — LAY-06 rack rail/depth fit
Evaluate rail depth range, mounting mode, body depth and connector protrusions separately from U count.

Acceptance: U PASS + depth FAIL counterexample required.

### ELV6-P3-007 — LAY-07 DIN interval/physical width
Evaluate module interval and physical rail length independently when available, with explicit reservations.

Acceptance: module-count PASS + physical-mm FAIL counterexample required.

### ELV6-P3-008 — LAY-08 surface mounting fit
Evaluate shelf/backplate/door mounting mode, footprint and orientation support.

Acceptance: geometric fit + mounting-mode incompatibility FAIL.

**P3 exit:** core placement can prove body-level fit for panels and racks without specialized service/cable/thermal logic.

---

# P4 — constructability-specialized kernels

### ELV6-P4-001 — LAY-09 service/removal
Evaluate service, connector and removal envelopes independently of body containment.

Acceptance: body PASS + service FAIL and missing-envelope partial cases.

### ELV6-P4-002 — LAY-10 door sweep/access
Implement versioned conservative door swept-envelope evaluation including door-mounted devices.

Acceptance: closed PASS + opening collision FAIL.

### ELV6-P4-003 — LAY-11/12 entry and bend constructability
Evaluate entry uniqueness/capacity/opening geometry plus adopted cable bend/connector/strain envelope.

Acceptance: duplicate cable end, capacity overflow, missing bend fact and collision fixtures.

### ELV6-P4-004 — LAY-13/14 internal wiring/termination capacity
Evaluate duct used/free physical basis and terminal/patch physical positions without hidden fill factors or logical-port substitution.

Acceptance: missing conductor area unresolved; duplicate physical position FAIL.

### ELV6-P4-005 — LAY-15 battery physical fit
Consume ELV4 battery identity and exact physical definition; evaluate body/orientation/terminal/handling dimensions without recalculating runtime.

Acceptance: electrical evidence PASS + physical FAIL counterexample.

### ELV6-P4-006 — LAY-16/17 support, mass and CoG basis
Use integer grams and exact gram·µm moments; keep missing mass partial; report physical basis without seismic/anti-tip compliance claim.

Acceptance: exact mass/CoG oracle, support overload and missing-mass fixtures.

### ELV6-P4-007 — LAY-18/19 ventilation/thermal-input basis
Evaluate physical opening/airflow keepouts and build reproducible heat-loss/surface/partition basis from exact technical facts; never substitute electrical load as heat loss.

Acceptance: blocked inlet FAIL; missing heat loss PARTIAL; no temperature-rise compliance claim.

### ELV6-P4-008 — LAY-20/21/22 reserve, segregation and bonding basis
Implement disjoint reserve accounting, observed segregation geometry and physical bonding evidence while preserving ELV7 normative claim boundary.

Acceptance: double-reserve prevention, missing segregation geometry and incomplete bond-basis fixtures.

**P4 exit:** layout is constructability-grade rather than just visually non-overlapping.

---

# P5 — deterministic auto-layout and aggregate validation

### ELV6-P5-001 — Implement immutable layout problem capture
Capture one canonical host snapshot, placements/locks, subject definitions, zones/entries and versioned solver policy with exact fingerprint.

Acceptance: canonical ordering/hash invariant under DB retrieval order.

### ELV6-P5-002 — Separate hard constraints from optimization
Hard intrinsic fit constraints cannot be traded for score. Solver returns unresolved subjects when infeasible.

Acceptance: no proposal places an item by violating a hard constraint.

### ELV6-P5-003 — Implement lexicographic score vector
Use the specified ordered objective vector and stable-ID final tie-break; no hidden weighted float score/randomness/time input.

Acceptance: controlled tie fixtures choose deterministic IDs.

### ELV6-P5-004 — Preserve locks/manual intent
Locked placements never move. Existing manual positions are preserved ahead of lower-priority optimization when feasible.

Acceptance: solver golden includes locked/manual preservation.

### ELV6-P5-005 — Implement byte-stable proposal canonicalization
Same canonical input + algorithm/profile version produces byte-identical proposal payload/hash.

Acceptance: repeated/in-memory/reopened DB generation equality.

### ELV6-P5-006 — Implement owner-targeted proposal items
Every proposed mutation names exact canonical owner/host/surface/placement target and required expected revision.

Acceptance: no generic proposal item can write an ambiguous owner.

### ELV6-P5-007 — Implement stale-safe acceptance/rejection
Acceptance recaptures owner/dependencies and is atomic; stale proposal fails without partial writes; rejection changes no canonical layout.

Acceptance: two-connection race and rejection fixtures.

### ELV6-P5-008 — Implement LAY-23 and LAY-24
Publish deterministic solver evidence and aggregate intrinsic layout verdict without converting ELV7 dimensions to PASS.

Acceptance: complete positive host, intrinsic FAIL host and mandatory-missing host.

**P5 exit:** auto-layout is explainable/reproducible and cannot silently corrupt manual engineering intent.

---

# P6 — upstream adapters, dependency DAG and downstream projections

### ELV6-P6-001 — ELV3 cable/end adapter
Resolve exact cable/run/end/termination refs needed for entry/bend/termination layout without taking cable ownership.

Acceptance: cable re-end/reassign invalidates exact affected layout closure only.

### ELV6-P6-002 — ELV4 battery/power physical adapter
Resolve exact battery/bank/source physical evidence consumed by layout; no ELV4 formula copy.

Acceptance: battery electrical change affecting physical requirement invalidates fit; unrelated power evidence does not.

### ELV6-P6-003 — ELV5 discipline/rack/patch adapter
Resolve exact ELV5 physical demand/capacity evidence and fingerprints; do not read UI-selected/latest result opportunistically.

Acceptance: stale/missing ELV5 evidence becomes blocked/unresolved with dependency marker.

### ELV6-P6-004 — Implement dependency reverse index
Persist typed old/new dependency refs including set membership and missing sentinels; calculate invalidation as union(old,new).

Acceptance: add/remove/move and missing→present transitions invalidate correct pointers.

### ELV6-P6-005 — Prove negative invalidation controls
Unrelated recording policy, unrelated door, unrelated room label and unrelated rack must not stale layout evidence.

Acceptance: explicit unaffected-set assertions.

### ELV6-P6-006 — Implement ELV7 projection v1
Publish owner-neutral exact physical evidence with schema/version/hash and no embedded compliance verdict.

Acceptance: equivalent canonical state has stable projection/hash across restart.

### ELV6-P6-007 — Implement ELV8 substitution impact contract
Map changed physical facts from selected product definition to exact ELV6 dependency keys/processes.

Acceptance: dimension/mass/heat/mounting/protrusion substitutions stale only required evidence.

### ELV6-P6-008 — Guard cross-stage cycles
ELV6 dependency graph may consume ELV3/4/5 evidence and export to ELV7/8 but cannot create numerical feedback cycles to upstream owners within one evaluation.

Acceptance: registry/runtime graph rejects illegal cycle/owner edge.

**P6 exit:** targeted recalculation is precise across stage boundaries.

---

# P7 — engineer workspace

### ELV6-P7-001 — Unified owner-aware host navigation
Show panel/rack hosts uniformly while diagnostics expose canonical owner/revision; selection survives view changes.

Acceptance: panel and rack fixtures use same workspace without copied truth.

### ELV6-P7-002 — Technical multi-view canvas
Support front/rear/side/section projections, rack U/DIN rulers and layers from one canonical 3D layout.

Acceptance: changing view never mutates canonical pose.

### ELV6-P7-003 — Precision editing beyond drag/drop
Provide exact numeric editor, keyboard nudge and U/DIN/grid/anchor snapping; drag is preview-only until command success.

Acceptance: keyboard/numeric edits go through same public command path as pointer gestures.

### ELV6-P7-004 — Engineer constraints and locks
Expose lock/unlock, multi-select, group move preview, reserve/service/entry layers and pre-commit “why not here?” diagnostics.

Acceptance: invalid preview never writes canonical state; conflict retains draft.

### ELV6-P7-005 — Capacity/provenance inspector
Show used/free/reserved U/DIN/termination/entry basis, mass/support and upstream evidence provenance with source navigation.

Acceptance: displayed totals derive from query/evaluation results, not widget recomputation.

### ELV6-P7-006 — Explain four-axis states
Visually distinguish current/stale, complete/partial/blocked, pass/fail/unresolved/not-assessed and runtime failure.

Acceptance: no single red/green status hides state axis information in detailed view.

### ELV6-P7-007 — Proposal diff and score diagnostics
Show before/after owner-targeted items, unresolved subjects, findings and full lexicographic score vector; accept/reject explicit.

Acceptance: stale acceptance leaves proposal/draft inspectable.

### ELV6-P7-008 — Historical/compact/accessibility behavior
Frozen revisions read-only; compact mode preserves selection/draft; keyboard focus/back semantics and scalable technical layers are qualified.

Acceptance: UI tests cover desktop/compact/keyboard/frozen/conflict flows.

**P7 exit:** workspace is usable for engineering production, not only demos.

---

# P8 — integrated public-path qualification

### ELV6-P8-001 — Build FK-valid multi-host qualification project
Use public commands to create at least one panel, one wall cabinet and one floor rack with cross-stage evidence. Raw SQL only for historical migration seeds/read assertions.

Acceptance: `P8-T01` fixture builds on file SQLite.

### ELV6-P8-002 — Execute all 24 process oracle sets
Every process gets POS/NEG/BLOCKED where applicable, exact required dimensions and claim-boundary assertions.

Acceptance: `P8-T02`; no missing positive case may be replaced by unsupported/blocked.

### ELV6-P8-003 — Qualify all 21 command codecs
Test valid command, missing/extra/wrong-type payload, unknown version/op, expected-row conflict, stale reviewed impact and exact replay semantics.

Acceptance: `P8-T03` complete command matrix.

### ELV6-P8-004 — Qualify persistence/migrations/restart
Fresh DB + accepted predecessor(s), close/reopen exact rows/results/proposals, failed migration rollback and old-stage isolation.

Acceptance: `P8-T04` after reopen, not same-connection only.

### ELV6-P8-005 — Qualify revision history
Freeze R1, create/remap R2, modify layout/definitions, prove immutable historical R1 and `ELV6_NOT_CAPTURED` for pre-stage seeds.

Acceptance: `P8-T05` snapshot/hash/remap assertions.

### ELV6-P8-006 — Qualify replay/rollback/concurrency
Response-loss replay, commandId conflict, owned failure checkpoints, two-connection edit/accept race, freeze/publish race and history cursor race.

Acceptance: `P8-T06` no partial writes after reopen.

### ELV6-P8-007 — Qualify deterministic numeric/solver behavior
Fixed-point boundaries, legacy import normalization, half-open geometry, exact mass moments and byte-stable repeated solver proposal/hash.

Acceptance: `P8-T07` platform-supported deterministic fixtures.

### ELV6-P8-008 — Qualify performance and targeted invalidation
Run controlled workload-scale host layouts and assert affected/unaffected process sets plus benchmark limits on a pinned runner class.

Acceptance: `P8-T08` evidence includes workload definition and runner metadata.

**P8 exit:** all runtime evidence at one exact SHA; design validators are supplemental only.

---

# P9 — architecture reconciliation and handoff

### ELV6-P9-001 — Reconcile 80 requirements to source/tests/evidence
Every requirement links implemented source, exact test ID, tested SHA and CI artifact/run.

Acceptance: `P9-T01` machine ledger has zero orphan requirement.

### ELV6-P9-002 — Reconcile 24 process registry to runtime registry
Algorithm/input/output versions, dimensions, dependencies and process claims match implemented definitions exactly.

Acceptance: `P9-T02` no design/runtime registry drift.

### ELV6-P9-003 — Reconcile 21 command registry to semantic codecs
Exactly one codec per command and no extra public mutation bypass; ELV4 revision command boundary unchanged.

Acceptance: `P9-T03` startup/CI registry-totality evidence.

### ELV6-P9-004 — Re-audit canonical ownership
Prove no duplicate panel/rack/placement/zone/cable/upstream result truth after final migrations and UI integration.

Acceptance: `P9-T04` owner matrix updated from P0 and zero unresolved conflict.

### ELV6-P9-005 — Run exact-head full gates
Generation, formatting, mobile/core analyzers/tests, ELV5 inherited design gates and all ELV6 qualification gates run on one final SHA.

Acceptance: `P9-T05` final workflow evidence.

### ELV6-P9-006 — Disposition all findings/limitations
Zero open BLOCKER/HIGH. Lower findings have owner/disposition. Unsupported dimensions are explicit and never converted to PASS.

Acceptance: `P9-T06` audit ledger.

### ELV6-P9-007 — Freeze ELV7/ELV8 handoff
Publish exact projection schema/hash and substitution impact contract; later stages cannot mutate ELV6 truth implicitly.

Acceptance: `P9-T07` downstream contract fixtures.

### ELV6-P9-008 — Separate design closure, runtime acceptance, merge and roadmap closure
Record these as distinct evidenced events. A merge commit alone is not acceptance.

Acceptance: `P9-T08` closure record.

**P9 exit:** ELV6 may be marked CLOSED only with all gates above and zero open BLOCKER/HIGH.

---

## Current ledger

| Package | Design | Runtime | Current design artifact |
|---|---|---|---|
| P0 | HARDENED | NOT_STARTED | ownership/baseline audit contract |
| P1 | HARDENED | NOT_STARTED | exact geometry + process registry |
| P2 | HARDENED | NOT_STARTED | strict command/persistence protocol |
| P3 | HARDENED | NOT_STARTED | core geometry process contracts |
| P4 | HARDENED | NOT_STARTED | constructability process contracts |
| P5 | HARDENED | NOT_STARTED | deterministic solver contract |
| P6 | HARDENED | NOT_STARTED | dependency/downstream projection contract |
| P7 | HARDENED | NOT_STARTED | engineer workspace contract |
| P8 | HARDENED | NOT_STARTED | integrated qualification contract |
| P9 | HARDENED | NOT_STARTED | exact-head closure contract |

Default runtime sequence:

```text
P0 → P1 → P2 → P3/P4 → P5 → P6 → P7 → P8 → P9
```

P5/P6/P7/P8 fixture/interface design starts earlier, but runtime acceptance follows dependency order.


## Coordinated ELV6 / ELV7 / catalogue / ELV8 delivery

Use [the shared agreement](elv-integration/README.md) as a mandatory interface
amendment. P0 reconciles schema/source and exact owner APIs; P1 freezes separate
layout requirement/evidence adapters; P2 supplies same-UoW owner participants;
P4/P5 capture catalogue definition hashes and scoped invalidation; P8/P9 qualify
candidate-versus-committed evidence, shared freeze and all cross-stage oracles.
These are design obligations; all ELV6 runtime packages remain NOT_STARTED.
