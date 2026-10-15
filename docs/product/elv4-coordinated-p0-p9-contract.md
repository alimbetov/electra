# Electra — ELV4 Coordinated P0–P9 Design Contract

Status: DESIGN DRAFT / REVIEW REQUIRED / RUNTIME NOT STARTED
Branch: `feat/flutter-elv4-power-topology-design`
Source baseline: `7f1c701cb4ba492589321f8f9827d20464ddaefb`
Design baseline: `29e0ad0`
Parent: [ELV4 specification](elv4-power-topology-design-specification.md)
Execution: [P0–P9 delivery plan](elv4-p0-p9-delivery-plan.md)

## 1. One design across ten packages

P0–P9 are ten coordinated work packages. All ten are designed together; runtime implementation remains dependency ordered. This contract fixes the interfaces between packages before coding. It does not certify runtime closure, product suitability or national-code compliance.

The governing specification defines domain semantics. This document refines those semantics into interfaces, transactions, evaluation order and acceptance obligations. The delivery plan owns sequencing. If a refinement conflicts with ELV1–ELV3 or the governing specification, revise the conflicting contracts together before implementation; package-local exceptions are forbidden.

| Package | Produces | Consumed by | Design exit artifact |
|---|---|---|---|
| P0 | Source map, baseline gaps, supported scope, fixture identities | All packages | Evidence and unresolved-entry ledger |
| P1 | Typed profiles, scenarios, accounting and serialization | P2–P8 | Versioned field/ownership contract |
| P2 | Atomic commands, persistence, snapshot and evaluation storage | P3–P9 | Command/read/write/failure matrix |
| P3 | Active graph, ordered transfers, supply resolution, trace | P4–P8 | Deterministic graph snapshot |
| P4 | Demand aggregation and converter/PSU/UPS loading | P5–P8 | Versioned arithmetic and boundary contract |
| P5 | PoE allocation and upstream input demand | P4/P6/P7/P8 | Delivery result consumed by the evaluation pipeline |
| P6 | DC terminal feasibility, charger and backup basis | P4/P7/P8 | Electrical solution and segment energy contract |
| P7 | Dependency orchestration and progressive workspace | P2–P6/P8 | Change/publication/UI matrix |
| P8 | Positive/negative/history/race/rollback proof | P0–P7/P9 | Executable acceptance manifest |
| P9 | Reconciliation and exact-head closure evidence | ELV5–ELV8 | Stage handoff and limitations |

P4/P5/P6 share mathematical inputs, not cyclic process execution. Section 6 defines their acyclic evaluation pipeline. P2 implements invalidation from the first mutation; P7 supplies the final UI and orchestrator. P8 acceptance design is available before P1 implementation.

## 2. P0 — Source integration and baseline decisions

### 2.1 Inspected integration map

Paths below exist at the source baseline. New filenames later in this contract are proposals, not existing runtime capabilities.

| Existing source | Integration responsibility |
|---|---|
| `packages/engineering_core/lib/src/engineering_topology.dart` | Preserve EngineeringPort/EngineeringConnection/InternalConnectivity IDs, existing power layers and independent power direction |
| `packages/engineering_core/lib/src/engineering_reference_catalog.dart` | Extend immutable catalog payloads and codecs; current discipline enum is CCTV/LAN/ACS/Fire |
| `packages/engineering_core/lib/src/elv_physical_snapshot.dart` | Preserve existing physical snapshot canonical hash algorithm; add a separate versioned power envelope through coordinated freeze |
| `apps/mobile/lib/data/database/app_database.dart` | Current schema 21; ProjectDerivedResults primary key is projectId/nodeKey; choose next schema from implementation base |
| `apps/mobile/lib/application/elv_design_revision_command.dart` | Extend existing freeze/create-next commands, without a second revision lifecycle |
| `apps/mobile/lib/data/repositories/drift_elv_design_revision_repository.dart` | One transaction for physical/power snapshot, lifecycle transition and ledger; current builder is `_buildP3Snapshot` |
| `apps/mobile/lib/data/repositories/drift_elv_physical_calculation_result_store.dart` | Current put uses upsert and empty dependency list; ELV4 needs explicit immutable evaluations and populated dependency keys |
| `apps/mobile/lib/application/elv_physical_calculation_nodes.dart` | Follow scoped key convention; do not collide with ELV3 node keys |
| `apps/mobile/lib/data/repositories/drift_elv_runtime_support.dart` | Reuse committed replay, stable result envelopes and command ledger conventions |
| `.github/workflows/flutter-local.yml` | Starting CI workflow; P9 records actual executed checks and run IDs rather than assuming historical gates |

P0 must inspect runtime equivalents beyond these entry points and reconcile ELV3 RC gates. A filename mismatch is not proof of missing behavior. The merged PR does not close an unverified gate.

### 2.2 Decisions fixed for all packages

- Power is an aspect of existing equipment, ports and connections. There is no duplicated equipment, cable or routing graph.
- Project is the budget boundary. A source shared by systems is aggregated once across all memberships; a discipline-filtered view must not recalculate a smaller source total.
- Supported supply graphs are radial with explicit selected alternative sources. Each energized consumer input has one supplying path. Parallel sources, shared return networks requiring mesh analysis and active power loops are unsupported.
- Passive continuity preserves current kind and voltage semantics. A passive splitter requires explicit branch terminals; external binary-connection cardinality is unchanged.
- External mains is an explicit boundary component with declared available voltage/frequency/capacity or unresolved fields. An unconstrained ideal source is allowed only in a labelled synthetic fixture.
- Readiness is separate from saveability: incomplete drafts may persist. Unsupported or incomplete engineering cannot be reported as passing.
- No new discipline enum is added for power. Reusable power definitions use a typed catalog extension associated with the root catalog edition, independent of discipline-specific component-class validation. Existing component classes and old payload bytes remain stable.
- Generic PSU/UPS/charger equipment binds the power extension to the existing placed component ID. It need not impersonate an ELV2 camera/controller class. Existing discipline binding and power binding may coexist, with one owner for each resolved port field.

### 2.3 P0 exit evidence

Record baseline commit, actual schema, migration origins supported by repository policy, source/test/CI references for each ELV3 gate, unresolved discrepancies, and exact ownership of legacy fields. BASE-01/02 remain runtime-entry blockers until proven or explicitly remediated in ELV3. BASE-03/04 require codec and snapshot integration review. Design of P1–P9 proceeds with these dependencies visible.

## 3. P1 — Shared typed data contract

### 3.1 Common identity and values

All mutable aspect records contain `id`, `projectId`, `designRevisionId`, `rowRevision`, lifecycle/audit fields and an exact edition reference where catalog-derived. A logical aspect ID is stable across create-next; storage keys include designRevisionId. All foreign references carry project/revision scope for validation. Scenario IDs are stable logical IDs, also revision scoped.

Exact edition reference: catalogId, catalogVersion, definitionCode, definitionVersion, definitionSchema, contentSha256, sourceRef. Normalize codes with the existing canonical normalizer. Hash technical values and units, not translated labels. Immutable definitions can be deprecated but cannot be overwritten.

Quantities use typed units and finite numbers. Null means absent; zero is an explicit value. V/A/W/VA/ohm/m/Ah/Wh/seconds are canonical units. Numeric comparisons use a versioned tolerance policy and unrounded values. Invalid negative capacity, efficiency outside `(0,1]`, PF outside `(0,1]`, or nonpositive required voltage/duration is rejected. Explicit zero-duration segments are omitted, not used to erase missing load evidence.

### 3.2 Field, owner and cardinality matrix

| Type | Required technical fields | Cardinality / owner |
|---|---|---|
| PowerPortBinding | existing portId, exact profile ref, current kind, power role, voltage min/nom/max, terminal roles, AC frequency if applicable | At most one active binding per revision/port; references existing port only |
| PowerComponentBinding | componentId, capability set, exact definitions, own-load accounting owner | One active binding per revision/component |
| PowerTransferBinding | componentId, owned input/output port IDs, kind, active-state selector, conversion model, input-demand owner | Multiple local relations allowed; one active transfer supplies a given output per segment |
| PowerLoadBinding | consumer inputPortId, state, demand union, continuous/peak distinction, duration, accounting kind | Unique revision/port/state/accounting kind; no duplicated component own load |
| PowerCapacityGroup | owner component, member output IDs, limit dimensions, applicability modes, derating basis | Output may belong to nested independent constraints; every constraint evaluated, loads counted once per group |
| PowerSupplyRequirement | input IDs, single/alternative feed selection, voltage/current kind, required segment states | One requirement per consumer supply set; simultaneous parallel mode unsupported |
| PowerOperatingScenario | role, ordered segments, per-device state, selected source per supply set, unavailable sources, policy refs | Immutable replacement payload with incremented rowRevision; no in-place segment edits |
| PoeDeliveryBinding | connection/path refs, PSE/PD ports, delivery definition, allocation boundary, conductor/resource mapping | One effective delivery per PD supply input/segment; reuse existing allocations |
| BackupAssembly | UPS/charger/bank component refs, protected outputs, transfer bindings, charge policy | Non-owning assembly; existing components cannot be deleted while referenced |
| BatteryBankBinding | unit edition, series count, parallel count, arrangement compatibility, usable model, SOC/EOD limits | One bank configuration per bank component/revision |

Terminals are roles of a canonical port and its existing resource termination mapping, not new independently connectable endpoints. A multi-terminal supply that needs independently wired branches uses distinct canonical ports.

Demand union: `DC_CONSTANT_CURRENT(A)`, `DC_CONSTANT_POWER(W)`, `AC_POWER(W, VA or PF)`. Explicitly supplying both VA and PF requires consistency within numeric tolerance. A nominal power label does not synthesize a current profile. Peak demand includes pulse duration and recurrence/simultaneity evidence; unsupported thermal/peak models block that assessment.

Own-load accounting kind is `CONSUMER_INPUT` or `TRANSFER_IDLE`. A component can have multiple documented auxiliary loads, each uniquely identified, but the same loss cannot appear in both kinds. Efficiency models declare `EXCLUDES_SEPARATE_IDLE` or `INCLUDES_IDLE`; the latter forbids an extra idle term for the same transfer.

### 3.3 Compatibility and legacy precedence

Typed bindings own the corresponding resolved canonical port fields. Existing ELV1 fields remain the compatibility projection; changing them directly while bound is rejected. A profile edit uses an explicit reviewed adoption command updating binding and projection together. Existing ELV2 profiles that also own a port must declare compatible shared provenance; contradictory owners reject binding, never last-write-win.

Legacy demandW/limitW may be displayed as legacy evidence but do not establish voltage tolerance, PF, efficiency, PoE negotiation or battery model. Explicit adoption either maps unambiguous values with provenance or leaves unresolved fields. Old catalog reimport must preserve old canonical bytes/hash; new power sections use a new schema decoder path. Unknown mandatory versions reject import; absent optional power extension preserves legacy behavior.

### 3.4 Scenario resolution

Resolve per segment: availability → explicit source selection → device state → transfer direction → demand/simultaneity. NORMAL and BACKUP are labels; no implicit device-state override follows from the label. Backup cannot select mains when mains is declared unavailable. Charge and discharge paths on the same bank are mutually exclusive in a segment. Restore/recharge is an explicit separate scenario.

Diversity is allowed only for a declared mutually exclusive/group policy. It cannot reduce a per-port guaranteed requirement or a safety-critical load without explicit applicable policy. Report demand, applied factor, reserve and capacity as distinct quantities.

## 4. P2 — Persistence, transactions and history

### 4.1 Proposed persistence mapping

Use the aspect names in section 3 as additive Drift roots and normalized child tables for transfer outputs, group membership, scenario segments/state/source selections and protected outputs. Persist typed JSON only for versioned immutable definitions/evidence, not for unchecked project/revision references. Supply requirements need their own scoped binding rows, not an omitted implicit JSON field.

All editable roots have composite scope uniqueness. Membership tables prevent duplicate members; ordinal segment constraints preserve ordering. Each command verifies the referenced component owns its ports and the revision belongs to its project. Where existing single-ID foreign keys cannot enforce scope, transactional guards plus adversarial fixtures are mandatory. Lifecycle tombstones preserve evidence; no destructive cascade into frozen or replay data.

Migration is additive from actual schema 21 or later implementation baseline. Do not preassign schema 22 in a design branch. Upgrade tests cover fresh, oldest supported, ELV1/ELV2 origins and schema 21 according to the actual migration policy. No automatic power synthesis or frozen hash rewrite occurs during migration.

### 4.2 Public mutation matrix

Each row below inherits projectId, designRevisionId, commandId, canonical payload schema/hash, expected design-revision rowRevision and expected revisions for affected existing roots. Create expects absence. Shared changes include a reviewedImpactFingerprint over the complete affected graph and exact editions.

| Command family | Reads / preconditions | Atomic writes | Invalidation / history |
|---|---|---|---|
| Bind/Adopt/ReleasePowerProfile | Port ownership, edition hashes, existing ELV2 ownership, impact | Component/port bindings, canonical field projections, revision token | Old and new graph closure; inverse only if reviewed old edition remains valid |
| SetPowerLoadProfile | Input ownership, scenario coverage, demand basis | Exact load set replacement, revision token | All upstream groups/sources/protected banks and terminal feasibility |
| ReplacePowerTransferSet | Owned terminals, active directions, affected scenarios | Entire local transfer set and memberships | Union of old/new connected closures; inverse validates current use |
| ReplacePowerCapacityGroup | Owner and scoped output set, units, nesting | Limits and membership set | Affected group, source and protected output evaluations |
| Create/Replace/ArchivePowerScenario | Scenario revision, reference use, all selections | Scenario root, segments and state/source choices | Scenario-specific nodes; archive retains historical result identity |
| Bind/ReplacePoeDelivery | Exact PSE/PD profiles, combined path, resource evidence | Delivery metadata only; canonical allocation remains owned by ELV3 | PD delivery, shared PSE group, upstream sources/backup |
| ConfigureBackupAssembly/ReplaceBatteryBank | Scoped existing components, compatibility, protected set | Assembly/bank/requirement membership sets | Backup and charger demand, upstream supply and protected paths |
| Existing connect/delete/adopt/reroute commands | Power dependency guards and revision token | Existing canonical writes plus invalidation and token | Old/new union, including disconnected/deleted edges |
| Existing Freeze/CreateNext | Full revision token and complete captured state | Coordinated snapshot/materialization, revision lifecycle, ledger | Freeze immutable; create-next marks inherited pointers stale until fingerprint verified |
| Undo/Redo | Exact history cursor and expected current after/before state | Ordinary validated inverse/forward command plus cursor | Same invalidation as original; no blind SQL restoration |

Command execution: open transaction → replay committed ledger → reload WORKING and expected tokens → validate scope/editions/impact → capture old dependency closure → write aggregate → compute new closure → mark current pointers stale → update revision token/history → persist result ledger → commit. SQLite busy/race is bounded-retried through a fresh transaction or returns a stable existing conflict error; no raw SQL exception reaches the workspace.

Successful exact replay returns the original response even if the revision is now frozen. Reusing a command ID with another payload conflicts. Rejected commands do not create successful ledger entries. Durable successful ledger and state must both survive lost responses.

Every participating ELV1/ELV2/ELV3 edit that affects power must advance the same design-revision row token inside its transaction. Per-row checks alone cannot prevent write-versus-freeze races or phantom graph reads. Non-power edits need not invalidate numerical power nodes.

### 4.3 Evaluation persistence without a second store

The baseline ProjectDerivedResults adapter upserts by nodeKey and writes `dependenciesJson: []`. This does not already implement append-only power evaluation history. P2 must extend the adapter explicitly:

- A logical node key is canonical encoded tuple `(elv4, revisionId, scenarioId, processCode, subjectKind, subjectId)` within project scope. Use a versioned tuple encoder, not delimiter concatenation of unrestricted IDs.
- Each immutable evaluation uses another nodeKey tuple `(elv4-evaluation, logicalNodeKey, evaluationId)`. Its inputsJson contains the complete resolved input snapshot or immutable content-addressed refs; dependenciesJson is populated, sorted and unique. No update/upsert overwrites this evaluation.
- The logical node row is the mutable current pointer and freshness state. It references an evaluation row. Invalidation updates this pointer only. Same-table evidence rows are not passed through blanket invalidation.
- Each evaluation records algorithm/input/output/numeric-policy versions, input fingerprint, quantities, arithmetic steps, findings, assumptions and applicability. Failure and blocked evaluations may also be recorded, without replacing a newer valid pointer under a stale input race.
- Capture input and revision token transactionally; calculate purely outside the write transaction; publish in a short transaction only if token and resolved input fingerprint still match. Otherwise discard publication and return stale/retry guidance. No late result resurrects CURRENT after an edit.
- Repeating an explicit Calculate request with the same command ID replays its committed evaluation response; reusing an input fingerprint may reuse immutable evidence only if all versions match. An old replay never advances a current pointer.

This is a deliberate storage design using existing infrastructure. Migration/index and codec details require P2 implementation review; planned reuse is not a claim that the baseline supports it already.

### 4.4 Coordinated freeze envelope

Preserve physical snapshot v1 bytes and hashes for historical revisions. Add a power snapshot record keyed by the same designRevisionId, with schema, payload, powerHash and physicalHash reference. A coordinated revision manifest identifies physicalHash and powerHash, with a separately versioned manifest hash. Do not reinterpret the existing `snapshotHash` as a combined hash; it retains its physical meaning for existing consumers.

Freeze transaction writes physical snapshot + power snapshot + manifest + revision transition + ledger. Power snapshot captures the complete resolved graph/profile/scenario/physical inputs, not merely references to mutable ports or latest catalog rows. It also captures current evaluation pointers and immutable evaluations with applicability/freshness. No RUNNING work is captured as success; a publisher racing freeze must fail token validation.

Old revisions without a power section return `ELV4_POWER_NOT_CAPTURED`. An initialized empty power design is `CAPTURED_EMPTY`, distinguishable from missing history. Create-next maps scoped records to the new revision with stable logical IDs, preserves source revision and exact edition refs, and never reuses a mutable R1 pointer in R2. No current-table fallback is permitted when reading frozen history.

## 5. P3 — Active graph, supply requirements and trace

Build `PowerGraphSnapshot` from one consistent revision/scenario input capture. Proposed pure core modules: `power_profiles.dart`, `power_scenario.dart`, `power_graph.dart`, `power_trace.dart`, `power_calculations.dart`, `power_snapshot.dart`. Split by responsibility during implementation; no package imports Drift or widget code.

Graph vertices reference canonical port IDs. Edges have typed provenance: external connection, passive mapping or active local transfer. Edge identity includes canonical source ID and segment. Collapse only explicitly lossless passive continuity for traversal; retain original mappings in evidence. Physical resistance/capacity is not erased by graph simplification.

Algorithm:

1. Select power/dataPower/signalPower conductive layers; exclude wireless/logical adjacency.
2. Apply state/source availability and alternative-feed selections per segment.
3. Expand explicit local transfers and passive mappings; validate owned ports and domains.
4. Reject active cycles and multiple simultaneously energized source paths into an unsupported supply set. A reconvergent diamond is not accepted merely because it is acyclic.
5. Resolve each consumer upstream to a declared source boundary; record missing and unavailable paths independently.
6. Validate guaranteed source range against allowed input range; passive continuity cannot change AC/DC/frequency/polarity. Final terminal voltage is evaluated in P6.
7. Retain shared group and protected-output membership for downstream calculations.

Trace result includes project/revision/scenario/segment, direction, ordered source IDs, converter boundaries, path evidence, unresolved frontiers and findings. Reachable does not imply compatible, physically realized or within capacity. Filtering to one discipline never drops shared consumers from capacity computation.

Draft connections may exist without installed cable data. Topological reachability can be established while physical delivery remains unresolved. The result explicitly reports separate topology, realization, capacity and backup dimensions.

## 6. P4/P5/P6 — One deterministic evaluation pipeline

### 6.1 Evaluation order and dependency-cycle prevention

| Step | Owner | Consumes | Produces |
|---|---|---|---|
| E0 | P3 | Captured inputs and segment selection | Validated radial graph and typed unresolved frontiers |
| E1 | P4 | Consumer demand/state and peak policy | Leaf demand records, with explicit electrical basis |
| E2 | P5 | PD demand and exact delivery profile/path | PSE-side port/group allocation and PD guaranteed margin |
| E3 | P6 | DC leaf behavior, physical sections, source boundaries | Solved section currents/terminal voltages and converter output demand |
| E4 | P4 | Solved demand, PSE input, converter/idle models and groups | Upstream source demand, PSU requirements, UPS W/VA loading |
| E5 | P6 | Per-segment protected input demand and selected bank/charger models | Energy/Ah capacity, charging demand and backup applicability |
| E6 | P7 | All findings and recorded dependencies | Atomic publication request and UI explanation |

E2 is used only at PoE boundaries. E3/E4 execute bottom-up within each supported radial voltage domain. A constant-power DC domain requires a coupled bounded solver; it cannot consume a cached E4 result and trigger repeated dependency invalidations until values happen to stabilize. Solver failure blocks affected upstream full totals while preserving labelled known subtotals. Charger demand in a recharge scenario is an E1 input derived from explicit charge-current policy; E5 does not recursively create new load in the same evaluation.

### 6.2 P4 arithmetic and ownership

For a simple transfer whose efficiency excludes idle, `inputW = deliveredW / efficiency + idleW`. For a loss-inclusive model, idle is already included. Multi-output transfer deliveredW is the sum of distinct output demands after scenario selection; own consumption enters once at its declared boundary.

Capacity checks cover each output, each shared group and upstream input. Nested groups constrain the same set without adding their totals again. Required output capability is demand times an explicitly declared reserve multiplier. Available capability is nameplate times the applicable derating model. Reserve is applied at the stated selection boundary only; it is not an upstream physical load unless policy explicitly defines real consumption.

UPS checks W and VA independently. Aggregate available apparent-power evidence using a declared conservative sum-of-VA model; do not assume cancellation or derive aggregate PF by averaging device PF. Missing VA/PF blocks the VA check while leaving a labelled W subtotal. AC input VA requires the converter input PF; output-side PF is not reused automatically.

Peak assessment records concurrent pulse loads, duration and source peak envelope. Incompatible duration/rate evidence is unresolved, even if continuous watts fit. End-of-discharge voltage and converter minimum input remain separate feasibility checks.

### 6.3 P5 PoE boundary contract

Each PoE delivery chooses one accounting mode:

- `GUARANTEED_PD`: edition declares guaranteed PD capability and reserved PSE allocation. Compare PD load against guarantee; aggregate reserved PSE allocations. Do not subtract the same cable-loss allowance again.
- `EXPLICIT_PATH_LOSS`: edition/resource model computes PSE output needed to deliver PD demand, with pair arrangement/resistance and voltage/current applicability. Missing or unsupported nonlinear behavior blocks this mode.

Allocation W, actual estimated W and worst-case reserved W are separate output fields. Shared budget compares the quantity specified by its profile. Upstream sizing uses declared conservative allocation or supported actual-load estimate, and records the chosen basis. It cannot silently mix them across ports.

PoE pass-through requires explicit power passage through each passive patch stage, compatible exact profiles, existing resource selections and termination evidence. The same canonical cable/resource claim is reused for data and power. No new ELV3 claim is created by binding PoE. PSE own consumption and conversion input loss are counted once upstream. A midspan has explicit data input, powered output and power input; its control/data adjacency is not its supply.

No IEEE class values are asserted by this design. Catalog fixtures must identify their values as fictional until an independently verified standard/manufacturer edition is supplied.

### 6.4 P6 DC solver and battery/charger contract

For constant-current radial sections, `I(section) = sum(active downstream load currents)`, including explicitly modelled local auxiliaries. `Rloop = Rforward + Rreturn + Rcontacts` at the stated temperature. `dropV = I × Rloop`; path drops subtract from source voltage. If resistance already represents the loop, never multiply by two again.

Report each section current against its rating and every terminal voltage against the consumer range, at the declared source envelope. Constant-current feasibility may use minimum source voltage for worst undervoltage; overvoltage uses maximum source voltage and appropriate minimum-load state. Never assume one operating point proves both bounds.

First runtime slice may block DC constant-power/nonlinear networks. If enabled, the selected versioned solver must declare voltage/current bounds, convergence tolerance, iteration cap, residual checks, no-solution behavior and validated golden cases. No approximate safe result on divergence. General shared returns, meshes and circulating paths remain unsupported even if a solver exists for radial trees.

Battery bank for compatible identical units: `bankV = unitV × seriesCount`; `bankAh = unitAh × parallelCount`. A simple Wh model is permitted only with an explicit applicability statement and model voltage. Apply usable factors once to the capacity side; do not inflate demand with those same factors. Initial SOC, allowed depth/EOD, temperature, aging and discharge-rate evidence are explicit. Voltage compatibility with transfer input is mandatory in addition to energy sufficiency.

Protected segment energy is `sum(protectedInputW × seconds / 3600)`. Include selected conversion losses exactly once. Report required energy for an explicit target duration separately from available capacity and estimated supported duration. A finite standby/alarm sequence does not define how to extrapolate autonomy; without an extension policy return capacity margin for that sequence only. No default fire standby/alarm hours.

Charger output must cover operating demand plus selected charge current at the charge voltage. Efficiency maps that output to input; a recharge-time estimate needs charge-acceptance/taper evidence or is explicitly unsupported. Nominal Ah divided by charger current is not a guaranteed full-charge time. Interlock prevents simultaneous bank charge/discharge in one segment.

## 7. P7 — Dependencies, publication and workspace

### 7.1 Dependency keys and fan-out

Use typed canonical keys for revision token, port binding, component own load, transfer, connection, passive mapping, supply selection, scenario segment, capacity group, cable resource/termination, installed run length, physical profile/resistance, bank, charge policy and algorithm version. Persist exact keys consumed by each evaluation, including missing required inputs: adding a previously missing profile must invalidate a BLOCKED result.

Compute invalidation using the union of old and new graph closures. Removing an edge must still invalidate formerly upstream/downstream nodes. A PSE/UPS group edit includes all memberships across systems. An unrelated room label is a negative control. Unsupported or missing evidence remains dependency-visible rather than dropping out of the graph silently.

| Edit | Required affected outputs | Required unaffected control |
|---|---|---|
| PD demand | PD margin, PSE group, upstream supply/UPS/bank | Another independent PSE/source |
| DC branch current | Shared trunk and all voltage-dependent terminals, upstream demand/backup | Disconnected radial source |
| Route length/termination | Matching DC/PoE path plus upstream loss-sensitive results | Other cable with unchanged evidence |
| Source selection | Old/new source closures and protected segments | Other scenario with unchanged selection |
| Battery model | Protected bank capacity/backup and explicit charging dependencies | Normal load result without bank/charging dependency |
| Catalog adoption | Exact changed bindings, old/new affected closure | Pinned unrelated edition and frozen R1 |

Process result rows are immutable facts; logical pointer validity is mutable. CURRENT means the input fingerprint is current, not that engineering passed. A CURRENT evaluation may contain an exceeded-capacity finding. `completion = COMPLETE/PARTIAL/BLOCKED`, `assessment = PASS/FAIL/UNRESOLVED` and finding severity are separate from `freshness = CURRENT/STALE`. FAILED denotes calculation execution failure, never a substitute for an engineering overload finding.

### 7.2 Workspace flow and command boundary

Shared editor toolbar exposes one power overlay and revision/scenario selector. Selected consumer opens one side card at a time: demand → upstream path → physical evidence → shared capacity → backup → findings/how-calculated. Back/forward card navigation retains selection and camera position. Inactive tools collapse; no permanent table of every property.

Every quantity shows units, source edition, selected state, accounting boundary and calculation steps on demand. Shared source cards show full project budget plus highlighted selected-system contribution. Unknown inputs show actionable findings; failed writes preserve the draft. Preview/adoption commits carry the reviewed fingerprint and reject stale review.

FROZEN disables mutation commands, supports exact historical trace and displays NOT_CAPTURED distinctly from empty captured design. Compact layouts use a drawer/sheet with the same card order. Keyboard/focus/back navigation and error-to-component selection are acceptance obligations, not decorative additions.

## 8. P8 — Acceptance manifest and reproducible examples

All values in this section are fictional fixture data, not equipment recommendations, standards limits or fire design policy. Pure arithmetic tests isolate boundaries; real command-based verticals additionally require FK-valid ports, physical realization and exact editions. Identifiers in fixtures are deterministic and revision scoped.

| Fixture / packages | Inputs and expected observations | Mandatory negative partner |
|---|---|---|
| V1 CCTV P1–P5/P7 | PD loads 10W and 15W; guaranteed-PD mode allocates 12W and 18W at PSE; group budget 35W → 30W reserved, 5W margin. PSE efficiency .9 excluding 5W idle → conservative upstream 38.333…W | Change budget to 29W → CURRENT complete evaluation with FAIL finding, not a stale or successful budget |
| V2 LAN P3/P5 | PSE → patch → outlet → PD with exact passive power continuity and one allocation path | Remove power passage while retaining data → data trace remains; power unresolved. Fiber-only path is unresolved |
| V3 ACS P3/P6 | Constant-current loads .3A/.5A, 24V source; shared loop .5ohm gives .4V drop; branch loops .2/.3ohm give terminals 23.54V/23.45V | Missing return resistance blocks terminal assessment; relay control adjacency alone never supplies lock |
| V4 Fire P4/P6 | Explicit protected output 20W × 2h + 40W × .5h = 60Wh; backup efficiency .8 → bank requirement 75Wh. Two 12V/7Ah units in series → 24V/7Ah; declared simple model with usable factor .8 gives 134.4Wh | Omit duration or usable-model applicability → BLOCKED; do not infer hours from fire discipline |
| V5 shared source P4/P5/P7 | V1 PDs belong to CCTV/LAN separately but one project PSE group still reserves 30W and counts 5W own load once | System filter must not reduce budget to 12W or 18W |
| V6 UPS P4/P6 | AC input load with explicit 38.333…W and input PF .8 → 47.9166…VA; compare independent 50W/45VA UPS limits → W passes, VA fails | Remove input PF/VA → W subtotal retained, VA UNRESOLVED, no W-to-VA equality |
| V7 history P2/P7 | Freeze R1, create R2, alter demand/route/edition/bank, close/reopen; exact R1 trace, profile hashes and evaluation evidence unchanged | Old pre-power R0 returns NOT_CAPTURED; latest edition must not fill it |
| V8 alternate supply P1/P3/P6 | Normal selects mains/charge direction; backup makes mains unavailable and selects bank/discharge | Select both or leave a charging loop active → unsupported source-path/cycle finding |

V4 reports sequence energy and margin only. It does not extrapolate an autonomy duration beyond the explicitly supplied sequence. V6 PF is explicit AC input evidence; it is not inferred from V1 converter efficiency.

### 8.1 Mutation proof matrix

Each public mutation family in section 4.2 requires: valid command, stale revision, cross-project/revision reference, frozen rejection, exact replay after restart, payload-conflict replay, response loss after commit, and rollback at every owned write boundary. Test public commands with real temporary file SQLite; inspect both same-open and closed/reopened state, foreign-key checks, ledger, pointer state and history cursor.

Extend failure probes for aspect insert, projection update, old-set deletion, membership insertion, scenario state/source selection, PoE bind, bank update, invalidation, history update, power snapshot, manifest insertion, revision transition and ledger-before-commit. These checkpoints refine the delivery-plan minimum list. A probe returning an exception cannot leave partial writes or a successful ledger entry.

Race pairs using two DB connections: edit/edit same aggregate; source/PD edit on shared budget; adoption/reviewed preview; reroute/calculate publish; freeze/edit; freeze/calculate publish; create-next/retry; undo/intervening edit. After serialization, exactly one winner or a valid sequential outcome with revalidation is allowed. No stale pointer may become CURRENT and no FROZEN payload may change.

### 8.2 Reproducibility and negative controls

Assert exact identity sets, source hashes, decoded quantities and dependency sets, not row counts alone. Permuting graph enumeration order must preserve numeric fingerprint and findings order. Timestamps and command IDs do not enter technical-input fingerprints. Scenario/algorithm/input-schema/numeric-policy differences do.

Tests explicitly cover missing values versus declared zero, overlap-only voltage mismatch, duplicated own losses, reserve double application, per-port versus aggregate overload, series/parallel traps, unsupported meshes, missing physical evidence, error translation and preservation of unrelated electrical/ELV1–ELV3 results.

## 9. P9 — Closure contract and future handoff

P9 checks every design row against source, command entry point, persisted schema, codec, test and CI evidence at one exact source SHA. Document-only checks can pass now; runtime gates remain open. No class-count or merge event substitutes for acceptance.

Required closure ledger columns: requirement ID, owning package, producer contract, consuming package(s), implementation path, test ID, exact tested SHA, workflow/run/artifact, status, limitation/disposition. P0 baseline blockers must be closed with evidence, not relabelled because ELV4 work is finished.

Final checks include actual Drift generation and generated-artifact guard, repository formatting, both analyzers, engineering_core and mobile suites, all P8 vertical/restart/race/rollback cases, migration matrix, exact dependency controls and frozen-history replay. Record actual commands/workflow IDs from the implementation environment. Any later source change requires renewed exact-head evidence.

Handoff:

| Next stage | Receives from ELV4 | Retains its own responsibility |
|---|---|---|
| ELV5 | Typed physical quantities, scenario results, assumptions and blocked inputs | Discipline policy, mandated state/duration/reserve selection |
| ELV6 | Existing enclosure/component IDs, bank dimensions when supplied, power topology | Cabinet/rack placement, fit, thermal/mechanical arrangement |
| ELV7 | Exact provenance and versioned calculation evidence | Verified jurisdictional profiles and compliance claims |
| ELV8 | Required capability, selected profile evidence and explicit margins | Manufacturer selection, BOM, schedules and deliverables |

All P0–P9 design sections are present in this revision. They remain DESIGN DRAFT pending review and baseline proof; runtime is NOT STARTED. Unsupported parallel/mesh power, unimplemented nonlinear solving, unsupported charging curves and unverified standard editions must remain visible limitations in the final handoff.
