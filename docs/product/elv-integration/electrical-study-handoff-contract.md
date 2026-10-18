# Electrical Study Handoff Contract — ELV6 / ELV7 / ELV8

Status: **DESIGN INTERFACE / PRODUCER NOT IMPLIED / RUNTIME NOT CLAIMED / ACCEPTANCE NOT CLAIMED**

Agreement ID: `electra.electrical-study-handoff.v1`.

This contract is replicated on ELV6, ELV7 and ELV8 design branches. It defines how qualified electrical-study results enter downstream physical, normative and deliverable stages without duplicating electrical physics.

## 1. Producer ownership

The canonical study producer belongs to the shared professional electrical calculation/scenario layer (CAP-07/CAP-08/CAP-13 and future ELEC4/ELEC8 implementations).

ELV6, ELV7 and ELV8 are consumers:

```text
Electrical Study Producer
        ↓
ElectricalStudyRef
   ┌────┼────┐
   ↓    ↓    ↓
 ELV6  ELV7  ELV8
layout rules reports
```

No downstream stage may implement a hidden competing short-circuit, voltage-disturbance, motor-start or source-transfer engine.

## 2. Study types

Initial target study types:

```text
STEADY_STATE
SHORT_CIRCUIT
EARTH_FAULT
VOLTAGE_DISTURBANCE
MOTOR_START
SOURCE_TRANSFER
CRITICAL_POWER_SCENARIO
```

Detailed waveform EMT, arc flash and advanced harmonics are separate future programs and are not implied by this interface.

## 3. Reference contract

Representative immutable projection:

```text
ElectricalStudyRef
- studyId
- studyType
- subjectRef
- scenarioRef?
- sourceProjectRevisionId
- algorithmId
- algorithmVersion
- inputFingerprint
- resultFingerprint
- rulesetOrMethodRef?
- evidenceRefs[]
- completion
- assessment
- freshness
- createdFromFrozenRevision
```

Allowed quality axes follow the shared calculation foundation:

```text
completion: COMPLETE | PARTIAL | BLOCKED
assessment: PASS | FAIL | UNRESOLVED | NOT_ASSESSED
freshness: CURRENT | STALE
```

A downstream consumer MUST NOT reinterpret `PARTIAL`, `BLOCKED`, `UNRESOLVED` or `STALE` as PASS.

## 4. Short-circuit result boundary

A short-circuit study may expose, where its method supports them:

```text
fault location
fault class
Ik max
Ik min
source contributions
method/version
input/result fingerprint
```

The following claims are independent:

```text
FAULT_CURRENT_CALCULATED
BREAKING_CAPACITY_ADEQUATE
TRIP_CONDITION_PROVEN
SELECTIVITY_PROVEN
FAULT_CLEARING_PROVEN
THERMAL_WITHSTAND_PROVEN
```

Presence of one MUST NOT imply another.

## 5. Fault classes

Target fault classes, subject to system applicability:

```text
THREE_PHASE
PHASE_PHASE
PHASE_NEUTRAL
PHASE_PE_EARTH
```

## 6. Voltage/disturbance types

Target disturbance identities:

```text
UNDERVOLTAGE
OVERVOLTAGE
VOLTAGE_DIP
SOURCE_LOSS
SOURCE_TRANSFER
LOAD_REJECTION
NEUTRAL_LOSS
MOTOR_START
```

A qualified result may include pre-event voltage, min/max event voltage, timing/bounds, affected assets and source/protection actions only when owned by the actual algorithm/scenario model.

## 7. Motor-start methods

The shared producer may evaluate:

```text
DOL
STAR_DELTA
SOFT_STARTER
VFD
```

A downstream stage consumes the result; it does not infer detailed electromechanical acceleration unless such a model is separately qualified.

## 8. Source-transfer / critical-power scenarios

A study may expose deterministic event timelines for qualified source models, e.g.:

```text
GRID_LOST
UPS_SUPPORT
GENERATOR_START
GENERATOR_READY
ATS_TRANSFER
EMERGENCY_BUS_AVAILABLE
```

Supported state claims must be explicit and versioned. Unsupported transient behavior remains outside scope.

## 9. Downstream use

ELV6 may use study refs for panel/context overlays, stale-state indication and physical decisions that explicitly depend on qualified upstream facts.

ELV7 may assess applicable normative rules against qualified study facts and must preserve source provenance.

ELV8 may render study summaries, scenario matrices and evidence traces without recalculating physics during report generation.

## 10. Invalidation

At minimum, dependent study refs become stale when relevant source facts change, including:

- topology/path;
- source/transformer/generator model;
- cable/conductor impedance facts;
- protection device/settings;
- load/motor/start method;
- operating scenario;
- algorithm/method version;
- required evidence/ruleset where part of the study input.

A stale study may remain historical evidence but cannot support a CURRENT acceptance claim.

## 11. Determinism and history

Same frozen revision + same immutable inputs + same algorithm/method versions SHALL reproduce the same result fingerprint.

Historical frozen study references remain immutable. Recalculation produces a new study/result identity rather than mutating accepted history.
