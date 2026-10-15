# P6 — DC terminal voltage, chargers and battery backup

Status: IMPLEMENTATION DESIGN DRAFT
Consumes P3 radial graph, P4 protected/boundary demand, P5 delivery accounting and exact ELV3 path evidence.
Shared rules: [runtime contracts](shared-contracts.md).

## Required work and acceptance

| Requirement | Implementation obligation | Planned acceptance |
|---|---|---|
| ELV4-P6-001 | Build typed radial section resistance/current model from exact installed resources and terminations | P6-T01 resistance convention |
| ELV4-P6-002 | Solve constant-current trunks/branches and report every terminal/current limit at source bounds | P6-T02 radial golden |
| ELV4-P6-003 | Block nonlinear/mesh/shared-return models outside the supported first slice | P6-T03 unsupported model |
| ELV4-P6-004 | Validate bank series/parallel compatibility, voltage, rating conditions and usable-capacity model | P6-T04 bank arrangement |
| ELV4-P6-005 | Compute piecewise protected energy and sequence margin with explicit duration/model/loss boundaries | P6-T05 standby/alarm energy |
| ELV4-P6-006 | Validate charge/discharge selection and charger operating plus recharge load | P6-T06 charger/interlock |
| ELV4-P6-007 | Distinguish required capacity, available capacity and supported autonomy estimate | P6-T07 autonomy applicability |
| ELV4-P6-008 | Persist complete arithmetic/model assumptions and target only affected dependencies | P6-T08 dependency/history |

## Core operations

| Process | Proposed operation | Output |
|---|---|---|
| ELV-PWR-03 | solveRadialConstantCurrent(DcDomainInput) | Section I/R/drop/loss; terminal V bounds; rating findings; resolved source demand |
| ELV-PWR-04 | evaluateBatterySequence(BackupSequenceInput) | Protected/bank required Wh or supported Ah; available capacity; sequence margin; optional supported duration |
| Supporting charge basis | evaluateChargerDemand(ChargerScenarioInput) | Operating output, charging output, input demand and current/voltage compatibility |

Each operation is pure. Snapshot includes units, source envelope, explicit forward/return model, terminal mapping and policy refs. Temperature correction is performed only from an applicable coefficient/model with reference temperature; missing material/temperature evidence is not replaced with a generic copper constant.

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

## Supported solver boundary

First runtime implementation supports radial constant-current DC only. DC constant-power or voltage-dependent loads, shared-return meshes and parallel source networks return ELV4_UNSUPPORTED_ELECTRICAL_MODEL. A converter input behaving as constant power cannot be silently retyped as constant current.

A future solver extension must add an exact model version, lower/upper voltage/current bounds, iteration cap, convergence/residual rules, no-solution cases and physical validation tests before enabling its profile. The dependency engine must not iterate cached processes as an implicit numerical solver. Initial ELV4 may close with this explicitly supported-scope limitation if all required acceptance cases use supported models and do not claim unsupported safety results.

## Battery arrangement and usable model

For compatible identical units in supported rectangular series/parallel arrangement: bankV = seriesCount * unitV; bankAh = parallelCount * unitAh. Every unit/string must satisfy edition/technology/rating/arrangement compatibility. Mixed units or unequal strings reject the configuration or remain unresolved only where a well-formed draft explicitly lacks evidence. Counts <=0 are structural errors.

Simple Wh model fields: modelVoltageV, ratedAh, initialSocFraction, minimumSocFraction, temperatureFactor, agingFactor, rateFactor, each with provenance/applicability. Usable SOC window = initialSoc-minimumSoc, required within [0,1]; availableWh = modelVoltage * bankAh * usableSOCWindow * applicable factors. Do not also apply a separate depth-of-discharge multiplier representing the same SOC window. Missing factors require explicit not-applicable/identity evidence, not silent 1.

Simple current/Ah mode is allowed only for an explicit constant-current and voltage-compatible sequence with applicable rating conditions. Do not sum unlike Ah bases or convert Wh by arbitrary nominal voltage. A discharge curve requires its own supported interpolation/domain model; outside its rate/temperature range is unresolved, never extrapolated automatically.

## Protected sequence and autonomy

At each segment, determine active protected outputs and selected discharge conversion path. Demand at bank boundary includes transfer losses once. RequiredWh = sum(bankInputW * seconds / 3600). If protected power varies with voltage and the simple model does not support it, block that model rather than treating a nominal sample as constant.

Fictional sequence: 20W for 2h, 40W for .5h → 60Wh output; backup eta .8 → 75Wh at bank. Two 12V/7Ah units series, model 24V, explicit usable factor .8 with all other conditions applicable → 134.4Wh available, 59.4Wh margin. Equivalent SOC window can encode .8; it must not be multiplied by another duplicate .8 DoD factor.

This proves energy margin for the supplied sequence only. Autonomy duration requires an explicit extension policy: repeat sequence, continue a specified final state, or supported curve model. Without it, `estimatedAutonomySeconds` is absent and sequence margin remains valid. Missing required standby/alarm durations blocks required-capacity assessment. No discipline label supplies those durations.

Energy sufficiency does not prove bank voltage at end of discharge fits converter minimum input. Keep voltage, energy, current and charging assessments independent.

## Charging and backup state

NORMAL/recharge selects charger and bank charge direction; BACKUP selects bank discharge and makes the relevant mains path unavailable. Operating outputW plus chargeVoltageV * selectedChargeCurrentA forms charger output demand. Compare charger combined/port limits, then apply conversion efficiency/own load once upstream.

Charge voltage and technology/unit count must be compatible. Peak charge/discharge currents use applicable limits. Exact recharge-time prediction remains unsupported without acceptance/taper evidence; Ah/current may be displayed only as a labelled ideal lower-bound calculation when explicitly requested by policy, never a guaranteed ready time.

Exit: ACS shared-trunk and fire standby/alarm bases are explainable, scoped and reproducible; unsupported models never become successful physical feasibility.
