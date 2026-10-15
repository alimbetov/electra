# Electra — ELV Calculation Processes

Status: Draft 0.1  
Branch: `docs/elv-engineering-systems-spec`  
Scope: canonical calculation pipeline for low-voltage engineering systems

Current ELV5 implementation authority: [ELV5 design index](../product/elv5-authoritative-spec-index.md). This older overview is background; its mixed status list and duration examples are not wire/runtime contracts. ELV5 separates freshness/completion/assessment/execution, integrates the unique recording horizon once, and delegates physical power to ELV4 with exact evidence/policy scope. Later-stage compliance/layout claims stay outside ELV5.

## 1. Purpose

Electra must provide dedicated calculation processes for ELV disciplines. Shared infrastructure such as dependency tracking, execution orchestration, result storage, diagnostics and reporting may be generic, but the actual engineering calculations must be discipline-specific and explicitly named.

The core rule is:

> **One calculation platform, multiple canonical engineering calculation processes.**

The application must never reduce ELV engineering to a generic formula engine with arbitrary user-defined properties.

## 2. Calculation architecture

A canonical calculation flow is:

```text
Project Model
   │
   ├── reference-data snapshot
   ├── topology snapshot
   ├── equipment snapshot
   ├── route/cable snapshot
   └── normative profile snapshot
          │
          ▼
CalculationProcess
          │
          ├── validate inputs
          ├── resolve dependencies
          ├── execute engineering algorithm
          ├── produce CalculationResult
          ├── produce findings
          └── publish derived values
```

A `CalculationProcess` is identified by stable code, discipline, algorithm version and input/output contract version.

## 3. Calculation process contract

Conceptual contract:

```text
CalculationProcessDefinition
- code
- discipline
- algorithmVersion
- inputSchemaVersion
- outputSchemaVersion
- requiredReferenceProfiles
- dependencyTypes
- executionMode
- severityPolicy
```

Each execution creates an immutable run/result record containing:

- process code
- algorithm version
- project revision
- reference-data/profile versions
- input fingerprint
- start/end timestamps
- status
- calculated values
- warnings/errors
- affected objects
- provenance/explanation

A calculated result must be reproducible from a frozen project revision and frozen reference snapshot.

## 4. Shared calculation kernel

The shared kernel owns only cross-cutting behavior:

- process registry
- dependency graph
- dirty-object detection
- incremental recalculation
- execution ordering
- cancellation
- result persistence
- stale-result marking
- diagnostics
- calculation trace
- unit conversion
- result provenance
- deterministic rounding policy
- report integration

It does not own discipline formulas.

## 5. CCTV calculation processes

### CCTV-01 — Camera coverage geometry

Inputs:

- camera position/orientation
- sensor geometry
- lens/focal-length profile
- mounting height
- target plane/zone
- obstructions where supported

Outputs:

- horizontal/vertical field of view
- coverage polygon/frustum
- near/far coverage boundaries
- uncovered zones

This process may later grow into DORI-style quality assessment, but initial geometry must remain deterministic and explainable.

### CCTV-02 — Stream bandwidth

Inputs:

- camera stream profile
- codec
- resolution
- frame rate
- bitrate mode/profile
- number of streams

Outputs:

- per-camera bitrate
- aggregate switch/uplink bitrate
- recorder ingress bandwidth

### CCTV-03 — Recording storage

Inputs:

- bitrate
- recording schedule
- motion/event factor where configured
- retention days
- stream count
- reserve factor

Canonical base formula for continuous recording:

```text
storageBytes = bitrateBitsPerSecond / 8
             × recordingSeconds
             × retentionDays
             × reserveFactor
```

Outputs:

- required usable storage
- recommended raw storage after redundancy profile
- storage reserve

### CCTV-04 — PoE power budget

Inputs:

- powered device demand
- PoE class/profile
- switch per-port capacity
- switch total PoE budget
- reserve factor

Outputs:

- port utilization
- total budget utilization
- insufficient-budget findings

### CCTV-05 — NVR/VMS capacity

Checks:

- channel count
- ingress bandwidth
- storage capacity
- supported codec/resolution profiles

### CCTV-06 — CCTV cable/link validation

Checks:

- medium compatibility
- copper/fiber link length
- path constraints
- PoE path feasibility
- cable category

## 6. LAN / structured cabling calculation processes

### LAN-01 — Permanent-link/channel length

Calculates and validates:

- permanent-link length
- patch-cord allowance
- total channel length
- service-loop allowance

The applicable limits come from a versioned structured-cabling profile.

### LAN-02 — Switch port capacity

Inputs:

- endpoint assignments
- switch port inventory
- reserved spare ratio
- media/speed requirements

Outputs:

- used ports
- free ports
- reserve percentage
- incompatible assignments

### LAN-03 — PoE budget

Shared physical calculation with CCTV but executed in LAN equipment context where appropriate.

### LAN-04 — Copper compatibility

Checks:

- category
- shielding
- connector class
- speed profile
- length

### LAN-05 — Fiber loss budget

Inputs:

- fiber type
- fiber length
- connector count
- splice count
- transmitter/receiver optical budget
- reference attenuation values

Outputs:

- estimated loss
- available margin
- pass/fail

### LAN-06 — Rack utilization

Calculates:

- used rack units
- reserved units
- free units
- weight where data is available
- equipment depth conflicts
- optional thermal/power indicators

### LAN-07 — Patch-panel utilization

Calculates:

- occupied ports
- free ports
- reserve
- mapping completeness

## 7. Access-control calculation processes

### ACS-01 — Door equipment completeness

For each `ComponentAssembly` representing an access-controlled door, validate required roles according to the selected door topology profile.

Example roles:

- entry reader
- exit reader or exit button
- lock
- door contact
- controller channel
- emergency release interface where required

### ACS-02 — Controller capacity

Calculates:

- occupied reader channels
- occupied relay outputs
- occupied supervised inputs
- free capacity
- reserve

### ACS-03 — Lock power demand

Inputs:

- lock operating current
- holding current
- inrush current where relevant
- duty model
- cable length/resistance

Outputs:

- design current
- voltage at load
- voltage-drop finding

### ACS-04 — PSU sizing

Aggregates connected ACS loads by operating mode and applies configured reserve/derating.

### ACS-05 — Battery autonomy

Inputs:

- standby load
- alarm/active load
- required autonomy profile
- battery technology
- aging/temperature/derating factors

Outputs:

- minimum required capacity
- selected battery capacity
- reserve/margin

### ACS-06 — Door topology validation

Checks:

- compatible interfaces
- lock control path
- reader-controller path
- monitored inputs
- emergency release dependencies

## 8. Fire-alarm calculation processes

Fire-alarm calculations are safety-critical and must be isolated into explicit versioned processes.

### FA-01 — Loop device capacity

Calculates:

- total devices per loop
- device-type counts
- address consumption
- reserved capacity
- panel/module limits

### FA-02 — Loop current

Aggregates device current by operating state.

At minimum:

- standby current
- alarm current

### FA-03 — Loop electrical limits

Where applicable, calculates/checks:

- conductor resistance
- total loop length
- voltage drop
- device operating voltage margins
- manufacturer loop limits

### FA-04 — PSU sizing

Aggregates panel, loop, module, notification and auxiliary loads according to the fire calculation profile.

### FA-05 — Battery autonomy

Uses explicitly selected fire-alarm autonomy policy.

Conceptual model:

```text
requiredCapacity =
    standbyCurrent × standbyHours
  + alarmCurrent × alarmHours
```

Then applies profile-defined aging, temperature, reserve and discharge factors.

The factors must not be hidden constants.

### FA-06 — Notification circuit capacity

Checks:

- sounder/beacon count
- circuit current
- voltage drop
- output-module capacity

### FA-07 — Loop topology integrity

Checks:

- required loop closure
- illegal branches where prohibited
- isolator placement policy where configured
- duplicate/missing addresses
- disconnected segments

### FA-08 — Fire cable compliance

Checks selected cable classes against the project normative profile and route environment.

## 9. Common ELV power calculations

Several disciplines reuse physical power calculations, but results remain attached to the calling engineering context.

Canonical processes:

- `ELV-PWR-01` connected load
- `ELV-PWR-02` PSU sizing
- `ELV-PWR-03` DC voltage drop
- `ELV-PWR-04` battery autonomy
- `ELV-PWR-05` UPS loading
- `ELV-PWR-06` PoE budget

The formula kernel may be shared; discipline profiles determine policy and required reserves.

## 10. Common route and cable calculations

Canonical processes:

- `ELV-ROUTE-01` cable length
- `ELV-ROUTE-02` carrier fill
- `ELV-ROUTE-03` cable separation
- `ELV-ROUTE-04` bend-radius compliance
- `ELV-ROUTE-05` route congestion
- `ELV-ROUTE-06` service-loop allowance

A route change invalidates only affected cable/run and dependent calculations.

## 11. Dependency graph

Typical dependency chain:

```text
Component placement
    ↓
Route / CableRun
    ↓
Cable length
    ↓
Voltage drop / link validation
    ↓
PSU / PoE / battery calculations
    ↓
Equipment selection
    ↓
BOM / reports
```

Another example:

```text
Camera stream profile
    ↓
Bandwidth
    ├── switch/uplink capacity
    └── storage requirement
            ↓
        NVR/storage selection
```

The dependency engine must mark downstream results stale rather than recomputing the entire project blindly.

## 12. Calculation states

Recommended states:

- `NOT_CALCULATED`
- `CURRENT`
- `STALE`
- `RUNNING`
- `WARNING`
- `FAILED`
- `BLOCKED`

`BLOCKED` means the process cannot run because required topology/reference/input data is incomplete.

## 13. Findings

Every calculation process may generate findings.

A finding contains:

- severity
- process code
- rule/profile code
- message
- affected object ids
- input values
- threshold/limit
- remediation hint

Example:

```text
ERROR LAN-01
Channel length = 107.4 m
Allowed = 100.0 m
Profile = LAN-CAT6-CHANNEL-v3
```

## 14. Explainability

For any important calculated value the UI must provide “How calculated”.

Example:

```text
Battery required: 17.8 Ah

Standby: 0.62 A × 24 h = 14.88 Ah
Alarm:   1.20 A × 1 h  =  1.20 Ah
Subtotal                  16.08 Ah
Reserve factor             1.10
Result                    17.69 Ah
Rounded recommendation    18 Ah+
Profile: FA-BAT-KZ-2026-v1
```

The calculation trace must be generated from structured calculation steps, not handcrafted report text.

## 15. Automatic equipment selection

Selection is a downstream process, not part of the raw engineering formula.

Example:

```text
Calculated PoE demand
       ↓
Selection constraints
       ↓
Manufacturer catalog candidates
       ↓
Ranked compatible equipment
```

Selection must preserve the difference between:

- minimum technically valid selection;
- preferred manufacturer selection;
- economically optimized selection;
- user-forced selection.

## 16. Recalculation triggers

Examples:

Changing camera bitrate invalidates:

- CCTV bandwidth
- storage
- recorder capacity

Changing cable route invalidates:

- cable length
- voltage drop
- route fill
- link-length checks

Changing battery product invalidates:

- available capacity comparison
- cabinet fit where modeled
- BOM

Changing a reference profile version invalidates all results that depend on that profile, but only after explicit project profile migration.

## 17. Determinism and rounding

All engineering processes must define:

- internal calculation precision
- output precision
- rounding strategy
- units
- conversion rules

UI formatting must not affect calculation results.

## 18. Initial delivery priority

Recommended implementation order:

### Foundation

1. Calculation process registry
2. versioned result/provenance model
3. dependency invalidation
4. reference-profile snapshotting
5. structured calculation trace

### First ELV vertical slice

1. cable length
2. DC voltage drop
3. PoE budget
4. LAN link length
5. switch port capacity
6. CCTV bandwidth
7. CCTV storage

### Second vertical slice

1. ACS controller capacity
2. ACS PSU sizing
3. ACS battery autonomy
4. access-door completeness

### Third vertical slice

1. fire loop capacity
2. fire standby/alarm current
3. fire PSU sizing
4. fire battery autonomy
5. fire topology integrity

## 19. Acceptance criteria

The ELV calculation architecture is acceptable when:

1. Calculation processes have stable codes and explicit versions.
2. Each result records the reference/profile versions used.
3. A route change invalidates only dependent results.
4. CCTV, LAN, ACS and fire alarm each expose discipline-specific calculation processes.
5. Shared formulas do not erase discipline semantics.
6. Calculation traces explain inputs, formulas, factors and outputs.
7. Critical thresholds are reference/profile data, not magic constants.
8. Existing projects remain reproducible after catalogs evolve.
9. Automatic equipment selection consumes calculation results instead of embedding calculations inside catalog filtering.
10. Reports use stored/reproducible calculation results from the same domain model.
