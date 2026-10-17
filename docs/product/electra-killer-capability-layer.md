# Electra — Killer Capability Layer K0–K12

Status: **TARGET / NORTH STAR / NOT IMPLEMENTATION / NOT ACCEPTANCE**

Parent target: `electra-professional-electrical-platform-target.md`

## 1. Purpose

This document defines the differentiating capability layer that should make Electra materially more valuable than a collection of electrical calculators, CAD helpers or manufacturer-specific sizing tools.

The mandatory professional capability map (`CAP-01…CAP-21`) remains the product foundation. The capabilities in this document are a higher orchestration layer. They combine trusted electrical topology, calculations, normative validation, geometry, equipment data, revision semantics and project evidence into workflows that save engineering time or expose risks that are difficult to see manually.

A Killer Capability MUST NOT bypass engineering contracts. AI, heuristics or optimization may propose alternatives, but production acceptance requires deterministic validation by the applicable engineering kernels and rulesets.

Canonical principle:

```text
FOUNDATION / CAPABILITIES
        ↓
DETERMINISTIC ENGINEERING FACTS
        ↓
KILLER CAPABILITY ORCHESTRATION
        ↓
CANDIDATE DESIGN / FINDING / LAYOUT
        ↓
ENGINEERING VALIDATION
        ↓
EXPLAINABLE RESULT
        ↓
USER ACCEPT / EDIT / REJECT
```

## 2. Killer Capability inventory

Exactly thirteen target killer capabilities are defined in this version:

- K0 — Automatic Switchboard Synthesis
- K1 — Project Autopilot
- K2 — Engineering Audit + Auto-Fix
- K3 — Failure X-Ray
- K4 — Revision Impact Intelligence
- K5 — Multi-Objective Design Optimizer
- K6 — Critical Power Simulator
- K7 — As-Built / Commissioning Twin
- K8 — Vendor-Neutral Equipment Optimizer
- K9 — Company Engineering Rules
- K10 — Brownfield Reconstruction
- K11 — Explainable Engineering Copilot
- K12 — Smart Room Electrical Layout

A future capability MUST receive a new identity. Existing K-identities MUST NOT be silently repurposed.

---

## K0 — Automatic Switchboard Synthesis

### User promise

Given a finalized set of circuits and a target switchboard, Electra can generate one or more valid board configurations, select the required device classes, balance phases, size the enclosure, reserve spare capacity and produce a physical/logical device layout.

### Required inputs

- target board identity and supply system;
- assigned outgoing circuits;
- calculated `Ib`, cable `Iz`, voltage-drop and short-circuit facts;
- protection requirements;
- phase/pole requirements;
- criticality/emergency semantics;
- board/environment constraints;
- reserve policy;
- optional manufacturer/catalog profile.

### Required synthesis steps

```text
circuits
  ↓
protection requirements
  ↓
phase allocation / balancing
  ↓
incomer requirements
  ↓
mandatory auxiliary devices
  ↓
DIN / physical footprint
  ↓
N / PE / terminal requirements
  ↓
separation / grouping constraints
  ↓
reserve capacity
  ↓
enclosure candidates
  ↓
layout candidates
  ↓
validated board variants
```

### Target variants

- COMPACT;
- BALANCED;
- EXPANDABLE;
- CUSTOM_POLICY.

### Mandatory explanation

For every selected or rejected candidate Electra shall be able to explain the governing constraint, such as:

- insufficient module capacity;
- insufficient reserve;
- phase imbalance;
- breaking-capacity mismatch;
- incompatible device family;
- thermal/layout constraint;
- normative separation rule.

### Acceptance principle

No generated board may be labelled valid until all applicable electrical, physical and normative checks pass.

---

## K1 — Project Autopilot

### User promise

Given a project structure, loads, locations, available sources and engineering policies, Electra can generate a candidate electrical distribution architecture instead of requiring the engineer to manually create every feeder and board.

### Target scope

- propose board hierarchy;
- group loads by location/function/criticality;
- allocate normal/emergency supplies;
- create candidate circuits;
- assign circuits to boards;
- propose source paths;
- trigger cable/protection calculations;
- invoke K0 for switchboard synthesis;
- generate SLD candidate;
- expose all assumptions and unresolved inputs.

### Hard rule

Project Autopilot generates **candidate engineering designs**, never an unexplained final truth.

The engineer MUST be able to:

```text
PREVIEW
COMPARE
EDIT
VALIDATE
ACCEPT
REJECT
```

### Dependencies

Primary: CAP-02, CAP-03, CAP-04, CAP-05, CAP-07, CAP-08, CAP-15, CAP-17, K0.

---

## K2 — Engineering Audit + Auto-Fix

### User promise

Electra not only finds project defects but also generates one or more validated remediation alternatives and shows the consequences before the engineer accepts a change.

### Example

```text
CRITICAL EL-184
Cable C-184 overload

Ib = 47.2 A
Iz = 43.1 A

FIX A
6 mm² → 10 mm²
Result: PASS
Cost impact: +...

FIX B
Move load to DB-03
Length: 74 m → 31 m
Result: PASS
```

### Required behavior

- classify root cause;
- generate bounded candidate fixes;
- simulate each fix in an isolated candidate revision;
- recalculate impacted dependency closure;
- reject invalid fixes;
- rank valid fixes by explicit objectives;
- never mutate the current accepted revision until user acceptance.

### Fix classes

Target classes include:

- cable section/type;
- protective device rating/type;
- source/board reassignment;
- phase reassignment;
- circuit split/merge where permitted;
- equipment substitution;
- reserve/load-shedding policy;
- layout correction.

### Dependencies

CAP-18 plus the applicable engineering capability that produced the finding.

---

## K3 — Failure X-Ray

### User promise

Select any source, breaker, feeder, cable, board, UPS, ATS or critical asset and immediately see the deterministic downstream functional/electrical consequences of its loss.

### Target interaction

```text
select asset
   ↓
SIMULATE FAILURE
   ↓
affected topology closure
   ↓
lost / retained sources
   ↓
affected loads
   ↓
affected ELV functions
   ↓
criticality impact
   ↓
recovery / alternate path
```

### Required output

- directly affected assets;
- transitively affected assets;
- critical loads lost;
- life-safety functions affected;
- alternate/backup supply status;
- degraded vs unavailable state;
- SPOF indication;
- trace explaining why each asset is affected.

### Dependencies

CAP-02, CAP-03, CAP-13, CAP-14, CAP-12.

---

## K4 — Revision Impact Intelligence

### User promise

For any project edit or revision comparison, Electra shows the **engineering impact**, not merely changed database rows or drawing objects.

### Target diff classes

- topology changes;
- load/demand changes;
- source-loading changes;
- cable/protection recalculation;
- short-circuit impact;
- board capacity/phase-balance impact;
- ELV process invalidation;
- normative finding changes;
- BOM changes;
- stale deliverables;
- newly introduced/resolved critical findings.

### Example

```text
Revision 28 vs 27

+3 circuits
-1 circuit
7 cable sections changed
4 protective devices changed
Connected load: 412 → 438 kW
Generator load: 176 → 201 kW

NEW WARNING
Generator reserve < 10%
```

### Dependencies

CAP-01 plus dependency/provenance/invalidation contracts from the shared foundation.

---

## K5 — Multi-Objective Design Optimizer

### User promise

Electra can enumerate or search valid design alternatives and expose a Pareto set rather than pretending there is one universally optimal electrical design.

### Typical objectives

- minimum CAPEX;
- minimum enclosure/space;
- minimum losses;
- minimum phase imbalance;
- minimum cable length;
- minimum device count;
- minimum operational risk;
- maximum reserve;
- maximum maintainability;
- maximum reliability.

### Hard constraints

Applicable engineering and normative constraints always dominate optimization objectives.

An inexpensive design that fails protection, thermal, topology or normative checks is not an optimization candidate.

### Target result modes

```text
CHEAPEST
BALANCED
RESILIENT
COMPACT
EXPANDABLE
CUSTOM
```

### Explainability

Each candidate shall expose:

- objective vector;
- constraints satisfied;
- governing constraints;
- meaningful differences from other Pareto candidates;
- exact project/ruleset/catalog versions used.

---

## K6 — Critical Power Simulator

### User promise

Electra can show the time-ordered behavior of normal and emergency electrical supply for scenarios such as grid loss, generator start, ATS transfer, UPS ride-through and load shedding.

### Target scenario timeline

```text
t = 0.0 s   GRID OFF
t = 0.0 s   UPS ON
t = 1.2 s   ATS detects failure
t = 3.0 s   GEN START
t = 8.4 s   GEN READY
t = 9.1 s   ATS TRANSFER
t = 9.3 s   EMERGENCY BUS ON
```

### Required model families

- source availability;
- start/ready delay;
- transfer device state;
- UPS autonomy/ride-through;
- critical load priorities;
- deterministic load shedding;
- staged motor/load starting where modelled;
- generator loading and reserve;
- recovery/retransfer sequence.

### Hard rule

Where transient physical behavior is outside Electra's qualified model, the simulator MUST clearly distinguish discrete operating-state simulation from unsupported electromagnetic/transient claims.

---

## K7 — As-Built / Commissioning Twin

### User promise

The same project used for design becomes a field-verification model that can distinguish intended design, installed condition and commissioned evidence.

### Canonical states

```text
DESIGNED
INSTALLED
VERIFIED
COMMISSIONED
```

### Target field workflow

- open/scan asset by QR/link;
- view design requirement;
- record installed equipment/cable;
- capture measured values;
- record photos/files/notes;
- detect design-vs-installed deviation;
- recalculate applicable engineering consequences;
- approve/reject deviation;
- preserve revision history.

### Example

```text
DESIGNED:  C32 / 6 kA
INSTALLED: C40 / 10 kA

DEVIATION
Protection coordination recalculation required.
```

### Dependencies

CAP-20, CAP-21, CAP-01, CAP-07, CAP-08.

---

## K8 — Vendor-Neutral Equipment Optimizer

### User promise

Electra derives an engineering requirement first and then compares valid manufacturer/SKU candidates without allowing the vendor catalog to redefine the engineering requirement.

### Canonical pipeline

```text
EngineeringRequirement
       ↓
compatible candidate set
       ↓
electrical validation
       ↓
physical validation
       ↓
normative/profile validation
       ↓
commercial/availability data
       ↓
ranked candidates
```

### Target ranking dimensions

- technical validity;
- selectivity/coordination compatibility;
- physical fit;
- cost;
- availability;
- preferred vendor policy;
- spare/commonality policy;
- maintainability.

### Hard rule

Unknown commercial data MUST NOT invalidate engineering correctness; unknown engineering data MUST NOT be replaced by price-based assumptions.

---

## K9 — Company Engineering Rules

### User promise

An engineering company can encode its internal design policies so Electra generates and audits projects according to the company's approved practice in addition to applicable normative profiles.

### Example policy dimensions

- minimum board reserve;
- minimum breaking capacity;
- preferred conductor material;
- preferred device vendors;
- naming conventions;
- emergency/life-safety separation policy;
- spare circuit policy;
- standard design patterns;
- preferred equipment families;
- documentation templates.

### Precedence

```text
PHYSICAL TRUTH
   ↓
APPLICABLE NORMATIVE RULES
   ↓
COMPANY ENGINEERING POLICY
   ↓
PROJECT-SPECIFIC PREFERENCE
```

A company rule may be more conservative than a normative minimum but MUST NOT silently relax an applicable mandatory rule.

### Commercial value

This capability turns Electra into a carrier of organizational engineering knowledge and increases repeatability, onboarding speed and switching cost.

---

## K10 — Brownfield Reconstruction

### User promise

Electra can reconstruct a trustworthy editable electrical model of an existing installation from partial legacy evidence instead of requiring a greenfield project.

### Target evidence inputs

- XLSX/CSV schedules;
- existing SLD data/import boundary;
- equipment lists;
- panel schedules;
- field survey data;
- photos/files as evidence references;
- manually captured topology.

### Evidence states

Every reconstructed fact must retain an evidence state such as:

```text
VERIFIED
DECLARED
DERIVED
INFERRED
UNKNOWN
```

`INFERRED` and `UNKNOWN` MUST be visible and MUST NOT masquerade as verified engineering facts.

### Target workflow

```text
IMPORT / SURVEY
      ↓
RECONSTRUCT CANDIDATE MODEL
      ↓
IDENTIFY GAPS / CONTRADICTIONS
      ↓
FIELD VERIFY
      ↓
AUDIT EXISTING INSTALLATION
```

---

## K11 — Explainable Engineering Copilot

### User promise

Natural-language assistance can query, explain and orchestrate Electra, while deterministic engineering kernels remain the source of calculation truth.

### Allowed roles

- explain calculation/finding;
- locate affected assets;
- summarize revision impact;
- prepare candidate commands;
- compare validated alternatives;
- guide the user to missing inputs;
- generate human-readable dossier commentary;
- invoke deterministic simulations/queries.

### Forbidden authority

The copilot MUST NOT:

- invent missing engineering facts;
- claim a PASS not produced by applicable validators;
- substitute an LLM result for a qualified calculation kernel;
- silently change a project;
- hide assumptions.

Canonical rule:

> **AI explains and orchestrates. Engineering kernels decide.**

---

## K12 — Smart Room Electrical Layout

### User promise

Given room geometry, openings, room type and design intent, Electra can provide subtle visual guides and generate editable, proportionally arranged electrical-device layouts for lighting, sockets, switches and related room electrical elements.

This capability is a **geometry-aware, rule-driven placement engine**, not arbitrary AI drawing.

### K12.1 Guide layer

Electra shall support lightweight non-intrusive guides that act as visual references without dominating the drawing.

Guide families:

- horizontal room center line;
- vertical room center line;
- room centroid/reference point;
- wall center lines;
- one-third / one-quarter proportional wall guides where useful;
- door center/edge guides;
- window center/edge guides;
- usable-wall segment guides;
- optional functional-zone axes.

UI behavior:

- guides are subtle and low-contrast at rest;
- active/snap candidate guides become more visible during placement;
- guides are hideable;
- guides are not exported as engineering devices;
- snapping must be deterministic and reversible.

### K12.2 Geometry primitives

Target primitives:

```text
RoomGeometry
WallSegment
DoorOpening
WindowOpening
UsableWallSegment
ReferenceAxis
FunctionalZone
PlacementAnchor
```

Openings are semantic placement constraints, not merely drawing holes.

### K12.3 Room semantics

Target room-type profiles include at least:

- BEDROOM;
- LIVING_ROOM;
- KITCHEN;
- BATHROOM;
- CORRIDOR;
- OFFICE;
- TECHNICAL_ROOM;
- GENERIC.

A room profile defines available placement patterns and rule defaults, but applicable normative validation remains a separate authority.

### K12.4 Placement pattern engine

Canonical target patterns:

```text
CENTERED_SINGLE
CENTERED_PAIR
SYMMETRIC_PAIR
EVEN_DISTRIBUTION
ALONG_LONG_AXIS
ALONG_SHORT_AXIS
PERIMETER
BETWEEN_WINDOWS
CENTERED_ON_WALL
ABOVE_WORKTOP
AROUND_BED
AROUND_MIRROR
DOOR_ENTRY_CONTROL
CUSTOM_ANCHOR_SEQUENCE
```

For proportional placement, generated coordinates must derive from explicit usable geometry and pattern parameters, not hard-coded screen pixels.

### K12.5 Supported device families

Initial target:

- ceiling luminaires;
- spot/downlights;
- linear luminaires;
- LED strips/profiles;
- wall lights/sconces;
- sockets/outlets;
- switches;
- multi-gang switch/socket groups;
- emergency-lighting points where applicable.

Future extensions may include sensors, thermostats or other electrical controls if they remain within Electra's product boundary.

### K12.6 Generation strategies

The Wizard may expose design-intent presets such as:

```text
MINIMAL
BALANCED
COMFORT
EXTENDED
CUSTOM
```

These presets influence quantity/layout proposals but MUST NOT silently claim normative compliance.

### K12.7 Human-in-the-loop workflow

Required lifecycle:

```text
GENERATE
   ↓
PREVIEW
   ↓
MANUAL ADJUST
   ↓
VALIDATE
   ↓
ACCEPT / REGENERATE / REJECT
```

Manual movement remains first-class. After editing, Electra shall be able to detect broken symmetry/alignment, clearance conflicts, invalid opening proximity or other applicable placement constraints.

### K12.8 Integration with electrical design

Accepted room layout objects must become real project-model consumers, not decorative symbols.

Examples:

```text
Luminaire
  ↓
ElectricalLoad
  ↓
Circuit
  ↓
Switchboard
```

```text
SocketGroup
  ↓
Circuit
  ↓
Protection
  ↓
Cable
```

Thus K12 feeds downstream load, circuit, cable, protection, board, SLD, BOM and audit workflows.

### K12.9 Relationship to existing stages

- geometry/reference axes may reuse ELV1–ELV3 geometry foundations;
- enclosure/device physical-fit concepts may reuse proven ELV6 primitives where semantically valid;
- normative placement checks belong to ELV7/shared normative profiles;
- exact luminaires/sockets/switch SKUs belong to ELV8/shared equipment selection;
- K12 itself owns room-level placement synthesis/orchestration.

K12 MUST NOT rewrite ownership of existing accepted stage capabilities.

---

## 3. Cross-cutting killer-capability invariants

All K0–K12 capabilities shall converge on the following rules.

### KC-01 Candidate before mutation

Generated designs/fixes/layouts are candidates until explicitly accepted.

### KC-02 Deterministic validation

No heuristic, optimizer or AI output can bypass the applicable deterministic engineering validators.

### KC-03 Explainability

Every selected result must expose why it was selected and why materially different candidates were rejected where practical.

### KC-04 Provenance

Generated outputs bind to project revision, input fingerprint, ruleset version, algorithm version and relevant catalog/evidence versions.

### KC-05 Unknowns fail visibly

Missing required engineering evidence produces BLOCKED/PARTIAL/UNRESOLVED semantics, never a fabricated PASS.

### KC-06 Human authority

The engineer can inspect, edit, accept or reject generated candidates.

### KC-07 No fake optimum

Multi-objective results must expose the objective set/trade-offs. Electra must not call one result globally "optimal" without a declared objective function and constraints.

### KC-08 Revision safety

Accepted generation creates explicit project changes/revisions. Historical/frozen revisions are not silently mutated.

### KC-09 Offline determinism

Core generation/validation that is declared offline-capable must not depend on cloud-only hidden state.

### KC-10 Normative separation

Physical feasibility, engineering quality, company policy and jurisdictional compliance remain distinct result axes.

## 4. Recommended delivery order

Killer capabilities should be introduced only after their prerequisites are sufficiently stable.

Recommended dependency-aware sequence:

```text
FOUNDATION + CAP-01…CAP-21
        ↓
K4 Revision Impact Intelligence
        ↓
K3 Failure X-Ray
        ↓
K0 Automatic Switchboard Synthesis
        ↓
K12 Smart Room Electrical Layout
        ↓
K2 Audit + Auto-Fix
        ↓
K8 Vendor-Neutral Equipment Optimizer
        ↓
K5 Multi-Objective Design Optimizer
        ↓
K6 Critical Power Simulator
        ↓
K7 As-Built / Commissioning Twin
        ↓
K9 Company Engineering Rules
        ↓
K10 Brownfield Reconstruction
        ↓
K1 Project Autopilot
        ↓
K11 Explainable Engineering Copilot
```

This is a dependency suggestion, not a mandatory calendar schedule.

K11 may be introduced earlier as a read-only explanatory shell, but any action-taking/engineering recommendation mode must respect the mature deterministic capabilities below it.

## 5. Killer-capability market test

A killer capability is not considered MARKET_VALIDATED merely because it works technically.

For each K capability, future market evidence should answer:

1. Does it save measurable engineering time?
2. Does it catch or prevent costly errors?
3. Does it reduce tool switching (Excel/CAD/vendor calculators/manual checks)?
4. Do users repeatedly invoke it on real projects?
5. Would users pay or upgrade for it?
6. Does it preserve or increase professional trust?

Suggested success evidence:

- real-project usage;
- before/after task time;
- accepted-vs-rejected generated candidates;
- defect-prevention evidence;
- user retention;
- willingness-to-pay / paid conversion.

## 6. Product positioning enabled by K0–K12

Target product statement:

> **Electra can help create a valid electrical design, prove why it is valid, show what fails when the system changes, optimize alternatives, generate physical layouts, and carry the same model through documentation and commissioning.**

The differentiating system is therefore:

```text
CREATE
  K1 / K0 / K12
    ↓
VERIFY
  K2 / CAP-18
    ↓
UNDERSTAND
  K3 / K4 / K11
    ↓
OPTIMIZE
  K5 / K8 / K9
    ↓
SIMULATE
  K6
    ↓
RECONSTRUCT / DELIVER / VERIFY
  K10 / K7
```

The objective is not maximum feature count. The objective is maximum reduction of manual engineering work while preserving deterministic, auditable engineering trust.
