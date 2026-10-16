# P6 — DC terminal voltage, chargers and battery backup

Status: IMPLEMENTATION RECONCILED / RUNTIME ACCEPTANCE PENDING — see [current P9 audit](../../audit/elv4-p9-reconciliation.md).
Consumes P3 radial graph, P4 protected/boundary demand, P5 delivery accounting and exact ELV3 path evidence.
Shared rules: [runtime contracts](shared-contracts.md).
Resolved audit decisions: [RM01–RM15](remediation-contract.md).

Core closure covers the pure engineering/runtime contract, typed consumed-input evidence and P4/PWR orchestration described below. Application publication/CAS, reverse dependency indexing, frozen-workspace behavior and editor/UI qualification remain P7/P8 responsibilities and are not claimed complete by this status.

Implemented process direction:

```text
CC:      leaf PWR-01(A) -> PWR-03 -> parent PWR-01 -> PWR-02
CP:      leaf PWR-01(W) -> PWR-03(interval) -> interval-aware PWR-02
charger: operating PWR-01 -> charger boundary PWR-01 -> parent PWR-01 -> PWR-02
backup:  ordered segment PWR-01 -> PWR-04 sequence
```

The constant-power path deliberately preserves its conservative source-demand interval instead of coercing it into the exact scalar P4 boundary. DC feeder loss and charger conversion/idle are owned exactly once before parent aggregation. PWR-04 consumes ordered segment membership/durations while dependency enumeration itself remains canonical and restart-stable.

## Required work and acceptance

| Requirement | Implementation obligation | Acceptance |
|---|---|---|
| ELV4-P6-001 | Build typed radial section resistance/current model from exact installed resources and terminations | P6-T01 resistance convention — implemented |
| ELV4-P6-002 | Solve constant-current trunks/branches and report every terminal/current limit at source bounds | P6-T02 radial golden — implemented |
| ELV4-P6-003 | Support CC trees and the bounded single-CP feeder; block all other nonlinear/mesh/shared-return domains | P6-T03 unsupported model — implemented |
| ELV4-P6-004 | Validate bank series/parallel compatibility, voltage, rating conditions and usable-capacity model | P6-T04 bank arrangement — implemented |
| ELV4-P6-005 | Compute piecewise protected energy and sequence margin with explicit duration/model/loss boundaries | P6-T05 standby/alarm energy — implemented |
| ELV4-P6-006 | Validate charge/discharge selection and charger operating plus recharge load | P6-T06 charger/interlock — implemented |
| ELV4-P6-007 | Distinguish required capacity, available capacity and supported autonomy estimate | P6-T07 autonomy applicability — implemented |
| ELV4-P6-008 | Persist complete arithmetic/model assumptions and target only affected dependencies | P6-T08 dependency/history — core evidence implemented; durable publication is P7 |

## Core operations

| Process | Implemented operation | Output |
|---|---|---|
| ELV-PWR-03 | `evaluateDcDomain(...)` over exact CC tree or RM06 single-CP feeder | Section I/R/drop/loss; terminal V bounds; findings; exact or interval source demand |
| ELV-PWR-04 | `evaluateBatterySequenceForBank(...)` / `evaluateBatterySequencePipeline(...)` | Protected required Wh; available capacity; sequence margin; optional supported duration |
| Supporting charge basis | `evaluateChargerForBank(...)` / `evaluateChargerToCapabilityPipeline(...)` | Operating output, recharge output, input demand, bank compatibility and upstream capability |

Each operation is pure. Snapshot includes units, source envelope, explicit forward/return model, terminal mapping and policy refs. Temperature correction is performed only from an applicable coefficient/model with reference temperature; missing material/temperature evidence is not replaced with a generic copper constant.

PWR-03 persisted-facing evidence records exact `elv4-dep-v1` dependencies for domain/section model, allocation, CableRun, traversal, installed resources, terminations, scenario/segment and consumed PWR-01 demand. Physical realization can therefore move from PRESENT/MISSING without reconstructing dependencies from display labels. PWR-04 records exact battery definition/bank arrangement, availability policy, ordered protected sequence and consumed segment evaluations. Charger evidence records bank compatibility, operating direction/state and transfer loss.

## DC section construction and algorithm

Section fields: sectionId, canonical connection/allocation/run/traversal refs, parent/child terminal IDs, lengthBasis, installedLengthM, resistanceModel tag, temperature evidence, forward/return/contact resistance, current rating and source/consumer applicability.

Resistance tags:

- LOOP_TOTAL_OHM: use declared loop resistance including its stated contacts/temperature basis; do not multiply by length or two.
- CONDUCTOR_OHM_PER_M: sum forwardRperM * forwardLength + returnRperM * returnLength plus separately declared contact values.
- Unsupported parallel/asymmetric/shared-return arrangements retain their exact evidence and return unsupported finding unless an explicit compatible model is implemented. Simple unequal forward/return resistances are supported when the same radial current path is explicit.

Missing contacts do not imply zero: use explicit included-in-rating evidence, explicitly declared zero for a justified fixture, or unresolved contribution. Service slack/reserve length included in installed run length must not be added again.

Solve postorder: section current is sum of active downstream constant currents and explicit local auxiliaries. Solve preorder: subtract I*Rloop from parent voltage. Compute I²R cable/contact loss for source-side power accounting; do not add that loss again when source power has already been computed from sourceV * sourceI. Report the conservation check as evidence.

At source minimum, evaluate terminal undervoltage; at maximum/minimum-load applicable state, evaluate overvoltage. Constant-current state assumptions must cover those bounds. A nominal-only source can produce a labelled nominal estimate, but cannot prove guaranteed voltage feasibility.

Fictional golden: 24V, .3A/.5A loads, .5ohm shared loop → .8A/.4V trunk drop. Branch .2ohm/.3ohm → 23.54V/23.45V terminals. Trunk loss .32W; branches .018W/.075W. Source 19.2W = delivered 18.787W + .413W loss. Domain conservation uses the same accounting boundary and numeric policy.

The acceptance chain additionally verifies the simpler exact boundary `24V × 2A = 48W`, with `44W` delivered and `4W` feeder loss. A parent with another `10W` direct load receives `58W`, not `62W`; the feeder loss is therefore demonstrably not counted twice.

## Supported solver boundary

First runtime implementation supports radial constant-current trees AND RM06 one-terminal constant-power unbranched feeders with an explicit quadratic-root/interval solver. Other nonlinear or voltage-dependent loads, shared-return meshes and parallel sources return `ELV4_UNSUPPORTED_ELECTRICAL_MODEL` as BLOCKED through the canonical P6 facade. A converter input behaving as constant power is never silently retyped as constant current.

For the bounded single-CP feeder, no feasible root returns `ELV4_NO_FEASIBLE_ELECTRICAL_SOLUTION`; failure to converge within the declared bound returns `ELV4_SOLVER_NOT_CONVERGED`. Successful source demand remains a `PowerInterval`; PWR-02 applies reserve/derating to that interval and uses conservative interval comparison. Overlap at the decision boundary remains `ELV4_NUMERIC_BOUNDARY_UNCERTAIN`, never an epsilon-based PASS.

A future solver extension must add an exact model version, lower/upper voltage/current bounds, iteration cap, convergence/residual rules, no-solution cases and physical validation tests before enabling its profile. The dependency engine must not iterate cached processes as an implicit numerical solver. Qualification requires COMPLETE/PASS on the fixed manifest dimensions; supported-scope limitations cannot waive a required positive case. General CP trees remain explicitly unsupported.

## Battery arrangement and usable model

For compatible identical units in supported rectangular series/parallel arrangement: bankV = seriesCount * unitV; bankAh = parallelCount * unitAh. Every unit/string must satisfy edition/technology/rating/arrangement compatibility. Mixed units or unequal strings reject the configuration or remain unresolved only where a well-formed draft explicitly lacks evidence. Counts <=0 are structural errors.

The implemented bank facade binds `BatteryWhAvailabilityModel` back to `BatteryBankBinding`: model voltage must equal the arranged bank voltage, Ah must equal the arranged bank Ah basis and the requested SOC window cannot exceed the unit usable-capacity envelope. This prevents an unrelated modelVoltage/bankAh pair from being evaluated next to a different bank arrangement.

Simple Wh model fields: modelVoltageV, ratedAh, initialSocFraction, minimumSocFraction, temperatureFactor, agingFactor, rateFactor, each with provenance/applicability. Usable SOC window = initialSoc-minimumSoc, required within [0,1]; availableWh = modelVoltage * bankAh * usableSOCWindow * applicable factors. Do not also apply a separate depth-of-discharge multiplier representing the same SOC window. Missing factors require explicit not-applicable/identity evidence, not silent 1.

Simple current/Ah mode is allowed only for an explicit constant-current and voltage-compatible sequence with applicable rating conditions. Do not sum unlike Ah bases or convert Wh by arbitrary nominal voltage. A discharge curve requires its own supported interpolation/domain model; outside its rate/temperature range is unresolved, never extrapolated automatically.

## Protected sequence and autonomy

At each segment, determine active protected outputs and selected discharge conversion path. Demand at bank boundary includes transfer losses once. RequiredWh = sum(bankInputW * seconds / 3600). If protected power varies with voltage and the simple model does not support it, block that model rather than treating a nominal sample as constant.

Fictional sequence: 20W for 2h, 40W for .5h → 60Wh output; backup eta .8 → 75Wh at bank. Two 12V/7Ah units series, model 24V, explicit usable factor .8 with all other conditions applicable → 134.4Wh available, 59.4Wh margin. Equivalent SOC window can encode .8; it must not be multiplied by another duplicate .8 DoD factor.

The core acceptance uses that same `24V × 7Ah × 0.8 = 134.4Wh` boundary and verifies it is not multiplied by the unit `.8` usable envelope a second time. PWR-04 fingerprints the ordered segment list including durations and demand; changing one duration invalidates only the `PROTECTED_SEQUENCE` dependency while unchanged bank facts remain stable.

This proves energy margin for the supplied sequence only. Autonomy duration requires an explicit extension policy: repeat sequence, continue a specified final state, or supported curve model. Without it, `estimatedAutonomySeconds` is absent and sequence margin remains valid. Missing required standby/alarm durations blocks required-capacity assessment. No discipline label supplies those durations.

Energy sufficiency does not prove bank voltage at end of discharge fits converter minimum input. Keep voltage, energy, current and charging assessments independent.

## Charging and backup state

An explicitly configured NORMAL/recharge scenario may select charging; an explicitly configured BACKUP scenario selects discharge and unavailable mains. Role labels alone never activate either direction. Operating outputW plus chargeVoltageV * selectedChargeCurrentA forms charger output demand. Compare charger combined/port limits, then apply conversion efficiency/own load once upstream.

Charge voltage and technology/unit count must be compatible. The core contract carries explicit `ChargerBankCompatibilityEvidence` tied to the bank series count instead of inferring compatibility from technology alone. Peak charge/discharge currents use applicable limits. Exact recharge-time prediction remains unsupported without acceptance/taper evidence; Ah/current may be displayed only as a labelled ideal lower-bound calculation when explicitly requested by policy, never a guaranteed ready time.

The charger acceptance verifies `20W + 27V × 2A = 74W` output and, with η=.8 plus 2W exclusive idle, `94.5W` upstream. Parent PWR-01 receives that `94.5W` once and does not reapply charger conversion or idle.

Exit: ACS shared-trunk and fire standby/alarm bases are explainable, scoped and reproducible; unsupported models never become successful physical feasibility.

## Supported backup solver and numerical evidence

RM06 supplies exact equation, root selection, preconditions, 128-iteration/1e-9V interval-bound termination, conservative rating checks and no-solution/nonconvergence outcomes. RM09 rational arithmetic prevents false limit verdicts. PWR-03 has SEGMENT scope; PWR-04 consumes the complete ordered SEQUENCE with exact segment evidence/durations, including source-side feeder losses once. Required positive bank/UPS tests provide source minimum/maximum/EOD/current and capacity-model applicability, not just nominal Ah or a boundary Wh oracle.

Targeted engineering-core qualification for this closure ran in GitHub Actions run `38727874673`: formatting, full `dart analyze`, P6 closure acceptance and adjacent P4/P5 regression tests all passed. The temporary gate was removed after success. This status does not claim that the latest full Flutter/mobile workflow has completed successfully.
