# Electra — ELV4 Power Topology Design Specification

Status: DESIGN DRAFT / IMPLEMENTATION NOT AUTHORIZED
Branch: `feat/flutter-elv4-power-topology-design`
Inspected baseline: `7f1c701cb4ba492589321f8f9827d20464ddaefb`
Entry point: [ELV4 index](elv4-authoritative-spec-index.md)
Plan: [P0–P9](elv4-p0-p9-delivery-plan.md)
Detailed interfaces: [coordinated P0–P9 contract](elv4-coordinated-p0-p9-contract.md)
Implementation detail: [ten package specifications and requirement ledger](elv4-implementation/README.md)

## 1. Purpose and scope

ELV4 adds reproducible physical power engineering to the existing ELV1 connectivity, ELV2 reference editions and ELV3 physical realization. It supplies typed common processes ELV-PWR-01…06. ELV5 owns discipline calculation policy; ELV7 owns verified jurisdictional compliance; ELV8 owns commercial product selection. This document specifies design, not an implemented capability or normative approval.

First release supports explicit radial AC/DC supply chains, converters, transformers, distribution/fused outputs, PSE/PD PoE, UPS, chargers and battery banks. A declared transfer device may select alternative supplies per operating scenario. Arbitrary parallel sources, load-sharing, backfeed and circulating-current networks remain unresolved and cannot receive a successful calculation. Closed fire signal loops are not automatically cyclic power networks.

## 2. Alignment with existing contracts

| Existing foundation | ELV4 use | Forbidden shortcut |
|---|---|---|
| One physical component and many system memberships | Add power capability to that same component | Clone a switch as a separate power device |
| EngineeringPort and EngineeringPortInstances | Bind typed power characteristics to existing port IDs | Second power endpoint identity/table of replacement ports |
| EngineeringConnection / exact compatibility profile | Project power, dataPower and signalPower layers | Infer supply from device label or Ethernet connectivity |
| ELV1 InternalConnectivity | Preserve passive continuity | Encode AC/DC conversion as a passive mapping |
| ELV2 immutable catalog editions and explicit adoption | Add typed power definition sections and exact bindings | Latest edition lookup or silently replacing frozen ports |
| CableAllocation and resource-selection/termination evidence | Resolve conducting resources on existing cables | Claim the same PoE cable twice for data and power |
| CanonicalCableRun and installed length | Use exact run/revision length in resistance basis | Derive electrical length from room distance |
| Reusable route graph/carriers | Read existing realization and affected dependencies | New geometry or power-owned route graph |
| ProjectDesignRevision / WORKING / FROZEN | One coordinated revision and versioned power snapshot section | Independent power revision counter or current-row fallback |
| CommandExecutionRecords / ElvCommandResult | Extend existing transaction/idempotency boundary | Memory-only replay or raw database errors |
| ProjectDerivedResults | Revision/scenario/process-scoped derived nodes | Separate uncoordinated calculation cache |

Current ELV1 types already include PortVoltageDomain, powerDirection, powerLimitW, powerDemandW, ConnectionLayer.power/dataPower/signalPower and TraceLayer.power. ELV4 refines these fields; it does not introduce power tracing as if no such layer existed.

## 3. Responsibilities and cardinalities

PowerTopology is a derived directed view of canonical port/connection identities plus explicit internal power-transfer relations. It is not a second externally wired graph.

| Contract | Responsibility / cardinality |
|---|---|
| PowerPortBinding | One current binding per powered port in WORKING context; exact profile edition and resolved characteristics |
| PowerComponentBinding | One binding per component; converter/source/store/distributor roles may coexist explicitly |
| PowerTransferDefinition | Component-local typed relation between owned input/output ports; one or more outputs, each with capacity group |
| PowerLoadProfile | Demand per consumer input, state and demand basis; distinguish component self-load from delivered downstream load |
| PowerCapacityGroup | Shared limit across outputs; output belongs to explicitly identified limiting groups |
| PowerOperatingScenario | Immutable scenario definition in revision context; selected sources, device states and simultaneous-load evidence |
| PowerSupplyRequirement | Consumer requirement: single feed or explicit alternative-feed policy, operating voltage and required modes |
| PoeDeliveryBinding | Combined connection plus PSE/PD ports, negotiated/declared profile and physical-path evidence |
| BackupAssembly | Existing component references for UPS/charger/bank, transfer relations and protected load group |
| BatteryBankDefinition | Explicit series/parallel string arrangement; per-unit exact battery edition, voltage and capacity |
| PowerTraceResult | Read-only path/evidence for one project, revision, scenario and direction |

Every relationship checks same project ownership. Bindings have stable IDs, row revision and exact reference provenance. Historical bindings are captured in frozen evidence. No opaque free-form property bag substitutes for typed required fields.

### PowerPortProfile

Fields: code, profile schema version, source reference; currentKind AC/DC; source/consumer/bidirectional role; minimum/nominal/maximum voltage; maximum continuous current/power; peak limit with duration when supplied; frequency range for AC where required; polarity/terminal mapping for DC; capacity group references; optional PSE/PD profile reference.

Direction of data and power are independent. A source's guaranteed operating range must fit the consumer's allowed range for the evaluated scenario; mere interval overlap is insufficient. Missing tolerance, polarity or required frequency is UNRESOLVED, not assumed compatible. Endpoint compatibility is necessary; evaluated load-terminal voltage also has to remain acceptable.

### PowerConversionProfile

Fields: exact input/output port roles, conversion kind TRANSFORMER/AC_DC/DC_DC/UPS/CHARGER/POE_PSE, output voltage range, efficiency basis, input own/idle consumption, derating curve or declared factor with provenance, continuous/peak capacities, capacity groups, allowed scenarios.

Declare the efficiency accounting convention. A loss-inclusive curve must not be combined with the same idle loss again. Passive mappings preserve domain; only explicit transfer definitions change domain. A relay/dry contact does not source power: switched supply terminals and control relation are separate.

### Load and scenario model

Demand is attached to consumer input ports, with a stated basis: watts, amps at declared voltage, or supported AC watts/VA/power factor. Own consumption is counted once per component. Zero is a valid declared state; missing is not zero.

NORMAL/STANDBY/ALARM/STARTUP/BACKUP are scenario roles, not globally exclusive component states. A BACKUP scenario can contain fire-panel standby and alarm time segments. STARTUP declares simultaneity, pulse duration and source peak capability; it is not averaged into continuous demand.

Each scenario freezes source selection, per-device state, simultaneity factors/group membership, duration segments and unavailable inputs. A consumer requiring two feeds must have an explicit supported selection policy. Simultaneous parallel sharing is deferred.

### PoE

PoE profile fields: versioned source/standard provenance, PSE or PD role, supported delivery profile, voltage/current limits, guaranteed PD power versus PSE output allocation, port limit, shared PSE output budget, own switch consumption, loss accounting basis, pair/resource semantics and path constraints.

One combined connection and one existing cable realization serve both projections. DATA-only continuity is not proof of PoE continuity. Passive patch stages require explicit compatible power passage evidence. Fiber does not carry PoE; an injector/media converter requires explicit powered component ports. Midspan input/output and source path are explicit.

No hard-coded standard table is introduced here. Verified standards data may be added with provenance; fictional fixtures are labelled as such. Do not subtract cable loss again when a guaranteed-PD-power profile already incorporates that loss allowance.

### Batteries and charging

Bank fields: technology, battery-unit voltage/Ah edition, cells/units per series string, parallel-string count, allowed arrangement and compatibility evidence, usable-capacity model, end-of-discharge voltage, temperature/aging/discharge-rate factors with applicability, discharge curve when used, charger compatibility and current limit.

Series increases voltage, not Ah; permitted identical parallel strings increase Ah. Mismatched units/strings are rejected or explicitly unresolved. Bidirectional charge/discharge ports are active only under scenario-specific transfer direction. Charging and discharging are not represented as an unconditional directed cycle. Charger input must cover connected operating load and selected charging demand without adding battery stored capacity as a load.

Autonomy is a physical estimate with assumptions, not fire compliance. Required hours/reserves come from explicit calling policy. Missing safety-critical policy produces BLOCKED.

## 4. Invariants

ELV4-INV-01: no cloned component, endpoint, external connection, cable, route or design revision.
ELV4-INV-02: only explicit compatible power layers and transfer definitions participate in supply tracing.
ELV4-INV-03: external edges remain binary; branching uses explicit distribution ports.
ELV4-INV-04: profile identity/version/hash is exact; adoption is explicit and dependency-aware.
ELV4-INV-05: no voltage/current-kind conversion without typed converter.
ELV4-INV-06: source, per-port and shared-group limits all apply; budget is not multiplied by branch count.
ELV4-INV-07: own loads and downstream loads are counted once at their declared boundary.
ELV4-INV-08: cycle detection runs on active scenario transfers; unsupported cycles block calculations.
ELV4-INV-09: wireless/logical adjacency is not conductive supply; unresolved external mains is visibly unresolved.
ELV4-INV-10: conducting resources, terminations and installed lengths retain ELV3 identity/provenance.
ELV4-INV-11: incomplete physical realization may be saved as a draft; installation feasibility is not CURRENT.
ELV4-INV-12: partial input never yields a complete safe result; show known subtotal and blocked remainder.
ELV4-INV-13: WORKING-only mutations; frozen graph/results use immutable revision evidence.
ELV4-INV-14: every mutation commits state, ledger, invalidation and applicable history together.
ELV4-INV-15: deleting an upstream source cannot leave silently valid dependent results.
ELV4-INV-16: a passive data path, control relay or capacity name does not imply a supply source.
ELV4-INV-17: common physical results do not claim jurisdictional compliance or auto-select products.
ELV4-INV-18: topology availability, capacity compatibility and autonomy are separate result dimensions.

## 5. Common calculation contracts

All engines are pure engineering_core functions over typed snapshots. They never query Drift. Internal units: V, A, W, VA, ohm, m, Ah, Wh and seconds; explicit conversions only. Reject nonfinite/negative invalid inputs and zero divisors. Internal precision, canonical serialization and output rounding are versioned; UI rounding cannot change feasibility.

| Process | Inputs | Outputs and blocking conditions |
|---|---|---|
| ELV-PWR-01 connected load | Active scenario graph, consumer states, own demand, source selection, efficiency | Per-port/group/source downstream and upstream demand; missing load or unsupported active cycle blocks full total |
| ELV-PWR-02 PSU basis | PWR-01 loads, declared reserve/derating, current/power/peak limits, charger demand | Required output capability, available derated capability, utilization/margin; absent policy remains unresolved |
| ELV-PWR-03 DC drop basis | Exact installed section length, resource/terminal mappings, operating current, loop resistance at declared temperature | Section drop and terminal voltage, current limits, worst affected loads; shared trunks use aggregate downstream current |
| ELV-PWR-04 battery basis | Protected load segments, durations, conversion losses, bank/usable-capacity model | Required/available Ah or Wh, physical autonomy estimate, assumptions and applicability limits |
| ELV-PWR-05 UPS loading | AC real/apparent power, PF when conversion needed, UPS W/VA limits, efficiency and backup model | Independent W and VA utilization, downstream protected loads and physical backup basis |
| ELV-PWR-06 PoE budget | PSE/PD exact profiles, state demand, per-port and shared budget, declared loss basis, cable continuity | PSE allocations, PD margin, port/group utilization, upstream switch input including own load |

Baseline formula conventions:

- A simple converter: inputW = outputW / efficiency + separately declared idleW, only when efficiency excludes that idle loss.
- Derated available output = nameplate output × applicable derating; reserve modifies required capability according to explicit policy, once.
- Simple DC section: dropV = currentA × loopResistanceOhm; loadV = sourceV − sum(section drops). loopResistance already includes forward and return; do not double it again. If inputs are per-conductor resistance/m, compute forward + return explicitly.
- Constant-current radial calculations are supported. Constant-power loads requiring iterative voltage/current solution must select a versioned convergent solver with bounds or return BLOCKED; do not silently approximate them as constant current.
- Mixed conductor paths, parallel conductors, contacts and temperature corrections require their typed evidence. Missing resistance does not become zero. Balanced-pair PoE resistance requires the actual profile/resource arrangement, not a generic two-wire assumption.
- Piecewise energy: requiredWh = sum(inputW(segment) × durationSeconds / 3600). Convert to Ah only with explicit supported voltage/model. Simple current/Ah basis is allowed only when its voltage/discharge assumptions apply.
- AC apparent power VA = W / PF when PF is supplied and valid. W and VA are never interchangeable.
- Available battery capacity applies only applicable factors once; capacity at a stated rate is not a universal autonomy curve.

Result identity:
projectId + designRevisionId + scenarioId + processCode + subjectId + algorithmVersion + inputSchemaVersion + outputSchemaVersion.

Persist inputFingerprint, frozen input/provenance refs, structured steps, dependency keys, quantity/unit, status and findings, calculatedAt and result schema version. Timestamp is audit metadata, excluded from deterministic numerical fingerprint. Freshness CURRENT/STALE is separate from completion COMPLETE/PARTIAL/BLOCKED, assessment PASS/FAIL/UNRESOLVED and finding severity. FAILED identifies calculation execution failure. A current complete calculation may correctly report an engineering overload. Evaluations are immutable evidence; a current pointer may advance in WORKING. Use ProjectDerivedResults and the existing dependency infrastructure.

## 6. Persistence and historical contract

Proposed additive roots, subject to P0/P2 SQL review:
PowerPortBindings; PowerComponentBindings; PowerTransferBindings; PowerLoadBindings;
PowerCapacityGroups and memberships; PowerSupplyRequirements; PowerOperatingScenarios and state/source selections;
PoeDeliveryBindings; BackupAssemblies; BatteryBankBindings.

These are typed aspects referencing existing identities, not replacements. Catalog definitions remain within ELV2 edition storage. Derived traces/findings/calculations remain projections/results. No second permanent calculation result database. The inspected adapter currently upserts one row per node and stores empty dependency lists; ELV4 must explicitly add immutable evaluation keys and mutable current-pointer keys within ProjectDerivedResults, with complete inputs/dependencies and optimistic publication checks. Existing behavior is not sufficient evidence of historical evaluation support.

Use project + design revision scoping for editable power aspects; stable logical aspect identity survives deterministic create-next materialization. Shared project components/ports remain project-owned. Mutable ELV1/ELV2 facts required by power must be frozen in the revision evidence and guarded on mutation.

Extend the existing coordinated freeze operation with a versioned power section stored as a companion snapshot and manifest under the same designRevisionId. Keep the existing snapshotHash as the physical hash; a separately versioned manifest binds physicalHash and powerHash. Freeze all records in one transaction, as detailed in the coordinated contract. Capture component/port profiles, connection layers, transfers, scenarios, capacity groups, bank data, exact cable/resource/termination/length facts and all current power evidence needed for replay. Retain old snapshot hashes. Historical pre-ELV4 snapshots return POWER_NOT_CAPTURED; never backfill from current tables. New WORKING revision may explicitly initialize power from a complete selected frozen section or an audited empty draft.

DB schema integers are chosen from actual migration order after P0; the inspected baseline is 21, not the schema 19/23 mentioned in historical plans. Snapshot payload version is distinct from Drift schemaVersion.

Unique/partial constraints enforce one current aspect per port/component/revision, group membership uniqueness, scenario identity and expected row revisions. Cross-project and cross-revision references are validated transactionally even when a single-column FK cannot express the full constraint. Deletion uses dependency guards, not hidden cascades.

## 7. Commands, concurrency and integration

Required command families:
Bind/Adopt/ReleasePowerProfile; SetPowerLoadProfile; ReplacePowerTransferSet;
ReplacePowerCapacityGroup; ReplacePowerSupplyRequirement; Create/Replace/ArchivePowerScenario;
Bind/ReplacePoeDelivery; ConfigureBackupAssembly; ReplaceBatteryBank;
ValidatePowerTopology; CalculatePowerProcess.
Existing ELV1 connection, ELV2 adoption, ELV3 routing/revision commands receive affected-power guards/invalidation rather than replacement versions.

Every mutation supplies projectId, explicit designRevisionId, commandId, canonical payload schema/hash and expected row revisions. Replay checks the committed ledger before current mutable preconditions; exact successful replay returns its original result after reopen. New commands reload WORKING state and all graph/profile dependencies in one transaction. A changed payload under the same command identity fails ELV_IDEMPOTENCY_CONFLICT.

Reject stale reviewed graph/impact fingerprint on profile adoption or shared changes. Include upstream/downstream fan-out across system memberships. FROZEN history remains intact when WORKING edits or source archives occur. No nested independent transaction may split canonical write and invalidation.

Stable failure families: ELV4_PROFILE_UNRESOLVED, ELV4_VOLTAGE_INCOMPATIBLE, ELV4_POWER_PATH_UNRESOLVED, ELV4_UNSUPPORTED_CYCLE, ELV4_CAPACITY_EXCEEDED, ELV4_POE_PATH_UNRESOLVED, ELV4_BANK_INCOMPATIBLE, ELV4_REQUIRED_POLICY_MISSING, ELV4_STALE_PRECONDITION, ELV4_POWER_NOT_CAPTURED. Reuse existing project/revision/idempotency error codes rather than invent aliases.

Reversible: unreferenced load/scenario edits and validated aspect-set replacements with exact inverse and precondition evidence. Freeze/adoption/history/archive remain irreversible where existing policy requires it. Undo/redo executes ordinary reauthorized commands and commits history state atomically.

## 8. Dependencies and change effects

| Change | Required affected set |
|---|---|
| Consumer demand/state | PWR-01, upstream PWR-02/05/06, protected PWR-04 |
| Cable reroute/resistance/termination | PWR-03 and dependent load feasibility, PoE delivery/backup basis |
| PSE port/group budget | PWR-06 plus upstream supply/UPS loading |
| Converter efficiency/self consumption | All upstream loads and protected backup estimates |
| Source removal/voltage change | Every downstream power path and all dependent process results |
| Battery bank/temperature/discharge policy | PWR-04 and UPS backup results; future fit/BOM dependencies |
| ELV2 explicit adoption | Exact bindings and only dependent power subgraph |
| Unrelated room label | No numerical power invalidation |
| Shared carrier facts alone | Only power results with explicit physical applicability dependency |

Voltage-drop/load feedback is solved inside a bounded process contract, not by introducing dependency cycles. Freeze rejects RUNNING evidence; incomplete designs may freeze with explicit BLOCKED/NOT_CALCULATED findings, but cannot claim successful engineering acceptance.

## 9. UI and vertical acceptance

One Power overlay in the shared editor. Progressive side panel:
consumer → supply path → profiles/modes → physical realization → capacities → backup → findings/explanation.
Inactive tools remain collapsed. Show exact revision and scenario; upstream/downstream trace is independent of signal trace. Permit viewing incomplete drafts; disable unsupported mutations with concrete reason. FROZEN is read-only. No widget multi-table writes.

Mandatory real-DB scenarios:
1. CCTV: external AC → UPS → PoE switch → Cat6 camera; own switch load counted once.
2. LAN: PSE → patching → outlet → PD; passive continuity explicit; fiber path with no injector is unresolved.
3. ACS: PSU/charger/bank → controller/reader/lock; control relay independent from power feed; shared DC trunk current correct.
4. Fire: PSU/charger/bank → panel/loop/notification loads; separate standby/alarm durations; no implicit normative hours.
5. Cross-system shared source: LAN and CCTV consume one PSE/UPS budget without double counting.
6. Negative and backup: missing source, wrong voltage, peak overload, active cycle, incompatible bank, missing loss/PF/policy inputs.
7. Historical: freeze R1, materialize R2, change profiles/routes/source/bank, reopen and reconstruct identical R1 power trace/results.

Fixtures are fictional product-neutral data. Each positive vertical must use public commands and real FK-valid SQLite state, not raw cardinality seeds or disabled foreign keys. P9 closes only after runtime, history and exact-head evidence; document completion never substitutes for it.

## 10. Cross-package implementation boundary

The [coordinated P0–P9 contract](elv4-coordinated-p0-p9-contract.md) specifies all ten packages together. Its P1 field matrix feeds P2 persistence/commands; P3 supplies the graph; P4/P5/P6 follow one acyclic evaluation pipeline; P7 consumes persisted dependencies and results; P8 verifies each producer/consumer boundary; P9 reconciles every obligation at the accepted source SHA.

Power is a typed root-catalog extension independent of existing discipline component-class validation. Generic source/converter/store capabilities bind existing placed component IDs without inventing a fifth discipline or impersonating a camera/controller class. Existing ELV2 and power binding ownership must agree before projection updates.

All participating canonical edits affecting power advance the coordinated design-revision row token inside the mutation transaction. Calculation captures a consistent snapshot, runs outside the write transaction and publishes only after token/fingerprint revalidation. Freeze captures all necessary canonical/profile/physical evidence and rejects stale publication. This requirement applies from P2, not only when P7 UI is implemented.

The initial nonlinear DC implementation may remain BLOCKED until a bounded versioned solver is implemented and tested. No runtime iteration through dependency invalidation may substitute for a solver. General parallel sources/mesh/shared-return analysis remains unsupported.

The implementation specification fixes the initial supported slice to radial constant-current DC and guaranteed-PD PoE accounting. Explicit-loss PoE/nonlinear DC require a reviewed implemented model extension before use. Generic draft profiles may record those model tags but evaluation must remain BLOCKED.
