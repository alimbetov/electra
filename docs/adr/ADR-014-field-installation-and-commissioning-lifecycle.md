# ADR-014: Field Installation and Commissioning Lifecycle

## Status
Accepted

## Context

Electra must support not only design intent but also physical installation, as-built capture, testing and commissioning. A field electrician or installer needs to record what was actually installed, where it deviated from design, how cables were pulled and terminated, and what tests were performed before handover.

## Decision

Electra adopts an explicit engineering lifecycle:

```text
DESIGN
-> APPROVAL
-> INSTALLATION
-> AS_BUILT
-> TESTING
-> COMMISSIONING
-> MAINTENANCE
```

Design data and installation evidence are related but not conflated.

## Installation deviation and as-built

A designed route or component may differ from the installed result.

```text
DesignedRoute / DesignedPlacement
        -> InstallationDeviation
        -> AsBuiltRoute / AsBuiltPlacement
```

An installation deviation records at least:

- affected object;
- original design reference;
- actual geometry or property override;
- reason;
- timestamp;
- optional note/photo reference;
- responsible actor where identity is available.

As-built data must remain traceable to the approved design revision.

## Work packages

Field work is grouped into executable `WorkPackage` units. A work package may be scoped by floor, room, panel, route zone or system.

Representative checklist:

```text
WP-E-017 / Floor 02

[ ] install tray TR-04
[ ] install junction boxes JB-11..JB-14
[ ] pull cable C-017
[ ] terminate DB-02
[ ] terminate M-201
[ ] apply labels
[ ] perform tests
[ ] close as-built deviations
```

## Cable pulling

A `CablePull` records the physical installation event for a `CableRun`.

Representative data:

```text
cableRunId
sourceEndpointId
destinationEndpointId
plannedLengthMm
actualLengthMm
reserveAtStartMm
reserveAtEndMm
cableReelId?
installedAt?
status
```

Cable length derived from geometry remains the design basis. Actual pulled length is installation evidence and must not silently replace the designed route geometry.

## Cable reels and stock consumption

Industrial and larger commercial projects may track `CableReel` records:

```text
reelNumber
cableDefinitionId
initialLengthMm
remainingLengthMm
batch?
manufacturer?
```

Cable pulls may consume from a reel to support stock control and as-built quantities.

## Terminations

Electrical ports are expanded into physical termination semantics where required:

```text
EquipmentPort
-> TerminalBlock
-> Terminal
-> Termination
-> CableCore
```

This supports terminal plans, cable core schedules and panel wiring documentation.

## Identification and labels

Field-identifiable objects may carry stable tags:

- equipment tag;
- cable tag;
- core tag;
- terminal tag;
- panel tag;
- QR reference.

Identifiers must remain stable across printed documents and the mobile field workflow.

## Test records

`TESTED` is not only a status. Testing is represented through `TestRecord` entities.

Initial test types include:

```text
CONTINUITY
INSULATION_RESISTANCE
EARTH_CONTINUITY
POLARITY
LOOP_IMPEDANCE
RCD_TEST
PHASE_SEQUENCE
VOLTAGE
CURRENT
FUNCTIONAL_TEST
MOTOR_ROTATION
NETWORK_TEST
CUSTOM
```

Representative test data:

```text
objectId
testType
measuredValue?
unit?
result
performedAt
performedBy?
instrumentReference?
notes?
```

## Commissioning checklist

Complex equipment may define a commissioning template. A motor/VFD example may require:

```text
cable terminated
PE verified
insulation test passed
phase sequence checked
rotation direction checked
protection settings verified
VFD parameters verified
final load test passed
```

Only completed evidence should allow a workflow to advance to `COMMISSIONED` where the project policy requires it.

## Field issues

A `FieldIssue` may reference exact project, floor, room, surface, route or component context and carry severity, description, optional evidence and status.

Typical examples:

- route blocked by another discipline;
- tray capacity exhausted;
- component location inaccessible;
- drawing differs from site conditions;
- termination mismatch;
- failed test.

## Spatial constraints

Routing and installation may use `SpatialConstraintZone` definitions such as:

```text
ROUTING_ALLOWED
ROUTING_PREFERRED
ROUTING_FORBIDDEN
DRILLING_FORBIDDEN
SERVICE_CLEARANCE
FIRE_COMPARTMENT
HOT_ZONE
WET_ZONE
EMC_SENSITIVE
```

These zones constrain planning and validation without becoming part of the visible drawing unless enabled as an overlay.

## Penetrations, fire stopping and supports

Professional installation scope may include:

```text
Penetration
Sleeve
FirestopSystem
SupportRule
Support / Hanger / Bracket / Clamp / Anchor
```

Support rules may derive approximate quantities from route length and spacing, while actual installed supports may be captured independently in as-built data.

## Consequences

Electra can evolve from a design planner into an end-to-end field engineering workflow without corrupting the canonical design model. The initial MVP does not need to implement every field entity, but persistence and identifiers must leave room for these contracts.