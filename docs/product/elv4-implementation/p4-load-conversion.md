# P4 — Demand, converters, PSU and UPS loading

Status: IMPLEMENTATION DESIGN DRAFT
Consumes P3 graph, P1 loads and boundary outputs from P5/P6. Supplies source sizing and backup energy.
Shared rules: [runtime contracts](shared-contracts.md).

## Required work and acceptance

| Requirement | Implementation obligation | Planned acceptance |
|---|---|---|
| ELV4-P4-001 | Resolve leaf state demands into typed contribution records without missing-to-zero coercion | P4-T01 leaf/missing demand |
| ELV4-P4-002 | Aggregate distinct contributions per output/group/source across all system memberships | P4-T02 shared/deduplicated accounting |
| ELV4-P4-003 | Apply transfer efficiency and own loss at one declared boundary | P4-T03 conversion/idle golden |
| ELV4-P4-004 | Compute PSU required/available margins with independent reserve and derating policy | P4-T04 reserve/derating |
| ELV4-P4-005 | Assess UPS W and VA independently using explicit input PF/VA basis | P4-T05 W-pass/VA-fail |
| ELV4-P4-006 | Assess peak duration/simultaneity separately from continuous demand | P4-T06 peak envelope |
| ELV4-P4-007 | Emit deterministic arithmetic trace, applicability and per-dimension result | P4-T07 reproducible evaluation |
| ELV4-P4-008 | Integrate P5/P6 through one bottom-up evaluator, with no process dependency cycle | P4-T08 mixed-domain pipeline |

## Processes and proposed functions

| Process | Proposed pure operation | Required result fields |
|---|---|---|
| ELV-PWR-01 | aggregatePowerDemand(graph, resolvedBoundaryDemands) | Contribution list; output/group/source demand in W/A/VA where supported; known subtotal and unresolved remainder |
| ELV-PWR-02 | evaluateSupplyCapability(demand, capability, policy) | Required capability, derated available capability, signed margin, utilization, violated dimension |
| ELV-PWR-05 | evaluateUpsLoading(protectedLoad, upsProfile, scenario) | Protected output W/VA, independent utilization/margins, input demand through selected UPS transfer, backup applicability |

Each records algorithm/input/output/numeric versions and the exact scenario segment. No storage read inside core. Application orchestrator builds physical-domain subproblems, gets PoE/DC boundary demand and evaluates parent conversions in reverse topological order.

## Leaf and aggregation algorithm

Resolve state-specific load; explicit inactive zero is valid only if declared by scenario/profile. If a consumer is active but its demand is absent, retain an unresolved contribution. Aggregate sorted unique origin IDs. A component belonging to CCTV and LAN contributes once; two physically distinct equal loads contribute twice.

DC constant-current watts require solved terminal voltage when physical delivered power is reported. Do not multiply by nominal voltage and call it a solved value. Source-side power includes cable dissipation where the supported physical model supplies it. DC constant-power demand remains typed and blocks coupled domains until supported.

For each converter, evaluate delivered outputs once and map to input demand. With idle-exclusive efficiency eta, inputW = sum(outputW)/eta + idleW. Idle-inclusive model forbids adding the same idle separately. A generic transformer additionally requires a supported rating/loss/PF model; its label alone cannot synthesize AC input VA.

Capacity groups are constraints on distinct member output demand. Group totals are not added again as loads to parent ports. Keep per-port and shared-source constraints even when one passes and another fails. Unknown branches make a total partial, not complete.

## Reserve, derating and capability

Reserve policy v1 chooses a multiplier >=1 at an explicit selection boundary. `required = demand * multiplier`; `available = nameplate * derating`, derating in `(0,1]`. Signed margin = available-required; utilization = required/available where available >0. If declared zero available capacity, utilization is undefined with a zero-capacity finding, not division by zero.

PWR-01 physical upstream demand does not automatically increase by a PSU selection reserve. Example fictional basis: demand 30W, reserve 1.2, nameplate 50W, derating .8 → required 36W, available 40W, margin 4W; physical output load remains 30W. Missing required reserve policy blocks sizing assessment but may leave demand complete.

Port current and W constraints are both checked when the model supports the conversion; no W-to-A conversion without applicable voltage/behavior. Peak rating cannot satisfy a continuous limit.

## AC/UPS apparent power

Use supplied VA, or VA=W/PF with valid explicit PF. If both are supplied, validate consistency via numeric policy. Independent loads use explicit conservative sum-of-VA aggregation; cancellation, harmonics and phase-vector analysis are unsupported unless a future model explicitly adds them.

UPS output ratings constrain protected output W and VA, not upstream UPS input after losses. The next upstream source consumes UPS inputW and inputVA, with UPS input PF evidence separate from downstream PF. Backup battery energy uses the selected backup conversion path; never count both mains and battery as simultaneous supply.

Fictional check: protected 38.333…W at PF .8 needs 47.9166…VA. A 50W/45VA UPS fails VA despite passing W. Missing PF retains known W and unresolved VA.

## Peak and explanation

Peak record contains pulse W/A/VA, durationSeconds, simultaneous group and recurrence/applicability when required. Compare against a declared source peak envelope at the same duration. Unsupported duration/interpolation yields UNRESOLVED; do not average into steady watts. Safety-critical diversity requires explicit applicable policy.

Each arithmetic step lists operation, input quantity refs, output quantity/unit, origin boundary and source definition. Calculation enumeration order must not affect fingerprint or sorted findings. Trace can explain leaf → cable losses → transfer losses → source without reconstructing from UI labels.

Exit: P5/P6 can consume explicit demand and loss boundaries without applying reserve, conversion or own consumption a second time.
