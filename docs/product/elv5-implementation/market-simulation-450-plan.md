# ELV5 — 450-case market and engineer simulation plan

Status: DESIGN HARDENED / DESIGN SIMULATION ONLY / RUNTIME NOT STARTED  
Branch: `feat/flutter-elv5-power-topology-design`

## Purpose

This simulation is a pre-runtime engineering stress layer for ELV5. It asks a practical question: if an experienced electrical/ELV engineer builds projects using current classes of CCTV, LAN, access-control and fire-alarm equipment, do the P0–P9 contracts prevent the mistakes that repeatedly appear in real design work?

The simulation deliberately does **not** replace production Dart qualification. It does not claim jurisdictional compliance, certification or procurement correctness. It verifies that the specification has places to represent the facts, calculations, uncertainties, shared resources, failure modes, workflow protections and performance behavior needed by real projects.

Tracked machine sources:

- `market-simulation-requirements.json` — 12 mandatory simulation requirements;
- `market-simulation-catalog.json` — current-market evidence snapshot, market/synthetic archetypes, scale classes, process density and error taxonomy;
- `scripts/ci/check-elv5-market-simulation.py` — deterministic generator/validator for exactly 450 cases;
- CI artifact `elv5-market-simulation-${github.sha}` — exact-head generated matrix.

## Generated evidence semantics (result schema v2)

`electra.elv5-market-simulation-result.v2` distinguishes three independent layers:

- `vectorClass` / `plannedDisposition`: desired future runtime test class/outcome;
- `referenceComputation`: independent, synthetic scalar diagnostic, not the full
  input of that scenario and not a manufacturer fact;
- `referenceMarginCheck`: exact sign check of reported diagnostic margins only.
  Outcomes are `NEGATIVE_MARGIN`, `NONNEGATIVE_MARGINS`, or
  `NO_MARGIN_COMPARISON`; `fullProcessAssessment` is always `NOT_ASSESSED`.

The old `expectedDisposition` name is removed because it falsely suggested that
an algorithm had evaluated the accompanying data. For example, the independently
sampled ACS-05 diagnostic at index 15 has a -240 Wh margin even though its planned
vector class is POSITIVE. That row is not a passing battery calculation. Runtime
qualification must first construct coherent typed inputs for the planned vector,
compute an independent expected result, then execute the actual Dart/public path.

Every row carries `runtimeFixtureStatus=REQUIRES_CONSTRUCTION_AND_EXECUTION`,
`referenceComputationBasis=syntheticFixture` and its diagnostic role. The
archetype's `marketBasis=vendorFact` applies only to cited catalog observations,
never to invented scalar inputs. The artifact reports
`executedRuntimeScenarioCount=0` explicitly. The 450 count proves planned coverage
and diagnostic generation, not 450 successful engineering calculations.

Statements below about P0–P9 stress, prevention and workflow describe obligations
for future fixture construction/execution. The current generator does not run DB,
UI, topology, scheduling, fault injection or production process kernels.

## Market evidence policy

Three evidence classes are intentionally different:

```text
vendorFact
    exact fact from cited manufacturer documentation

marketEnvelope
    engineering range derived from current market observations
    NOT a manufacturer guarantee

syntheticFixture
    fictional deterministic value shaped like real equipment
    used only to stress algorithms/tests
```

A developer or engineer may never convert `marketEnvelope` or `syntheticFixture` into manufacturer-guaranteed evidence. Market examples never create ELV7 verified compliance or ELV8 SKU/BOM selection.

## Current market anchors

The tracked catalog uses manufacturer documentation retrieved on 2026-10-16. Examples include:

- Axis camera class with 1920×1080, up to 50/60 fps, H.264/H.265, multiple configurable streams and PoE Class 3;
- Cisco Catalyst 9200 classes spanning compact PoE and 24/48-port PoE systems with 600 W / 1000 W supply classes;
- Corning OS2 family data around 0.38 dB/km maximum attenuation at 1310 nm for the cited current family;
- ASSA ABLOY electric-strike examples at 24 V with approximately 88 mA, 100 mA, 370 mA and 560 mA current classes plus fail-safe/fail-secure behavior;
- HID current Mercury controller families and a two-reader M1 IO module class;
- Honeywell Fire-Lite 50 / 198 / 954 addressable-device panel classes and vendor tooling that explicitly includes battery, voltage-drop and line-loss calculations.

These anchors exist to make fixtures realistic, not to turn ELV5 into a vendor catalog.

## Matrix size and distribution

The source catalog deterministically produces exactly **450 combinations** across all **27 processes**.

Every non-core process receives 12 scenarios. The computational core receives 23 or 24 scenarios each:

```text
24: CCTV-02, CCTV-03, LAN-05, ACS-03, FA-05
23: LAN-01, ACS-04, ACS-05, FA-02, FA-04, FA-06
12: all remaining 16 processes
--------------------------------------------
total = 450
```

Every process contains all five scenario classes:

```text
POSITIVE
BOUNDARY
NEGATIVE_OR_UNSUPPORTED
ADVERSARIAL
CROSS_DISCIPLINE
```

The matrix rotates four scale profiles:

```text
S1-SMALL
  8 CCTV / 24 LAN endpoints / 4 ACS doors / ~50 fire points

S2-MEDIUM
  32 CCTV / 96 LAN endpoints / 16 ACS doors / ~198 fire points

S3-LARGE
  128 CCTV / 384 LAN endpoints / 64 ACS doors / ~500 fire points

S4-CAMPUS
  512 CCTV / 1500 LAN endpoints / 256 ACS doors / ~954 fire points
```

These numbers are simulation cardinalities, not product limits unless an exact source says otherwise.

# How the simulation traverses P0–P9

## P0 — baseline and ownership

Every market scenario first verifies that the required fact already has a canonical owner. A camera, switch port, cable, source, bank, route or revision is never silently re-owned by ELV5.

The simulation specifically looks for:

- duplicate cable/port/component/source/battery ownership;
- vendor capability authored twice in different layers;
- market fixture data accidentally replacing accepted ELV4 evidence;
- ELV6/ELV7/ELV8 claim leakage.

**Engineer benefit:** the engineer sees one source of truth instead of different numbers on different screens.

## P1 — engineering primitives and solver semantics

All scenarios exercise the need for:

- exact typed units;
- explicit Known/Missing/Unsupported/Unresolved state;
- evidence basis;
- uncertainty;
- operating case;
- transient/startup cases;
- canonical comparison and signed margin;
- governing case and limiting factor;
- deterministic trace.

Errors caught here include `dB` versus `dBm`, W versus Wh, A versus Ah, expected versus guaranteed and typical versus guaranteed.

**Engineer benefit:** fewer silent unit conversions and fewer optimistic assumptions hidden in spreadsheets.

## P2 — persistence, commands and revision safety

Simulation cases are required to remain representable through schema 24 and the fixed 16-operation public command surface. The same scenario is considered unsafe if it needs an undocumented DB mutation or UI-only side effect.

The matrix stresses:

- replay-first command handling;
- CAS/reviewed-impact conflict behavior;
- root/member atomic replacement;
- immutable evaluation history;
- pointer generation;
- short bulk capture and publish;
- restart/historical reconstruction.

**Engineer benefit:** reopening a project cannot silently change yesterday's engineering answer.

## P3 — CCTV

### CCTV-01 coverage geometry

Market simulation varies camera/lens/zone geometry, frame identity, unsupported fisheye models and horizon/parallel rays.

Errors prevented:

- using an FOV label without camera-frame provenance;
- treating geometric footprint as DORI/visibility/compliance proof;
- silently accepting unsupported lens models.

### CCTV-02 bandwidth/flow

Scenarios combine multiple encoded streams, unicast receivers, multicast trees, recorder paths, expected and peak bitrates.

Typical failure deliberately simulated:

```text
one 8 Mbps stream
3 unicast consumers
common edge

wrong spreadsheet answer: 8 Mbps
correct edge accounting: 24 Mbps
```

Another class checks that multicast is deduplicated only with explicit distribution-tree evidence.

**Engineer benefit:** reduces under-sized uplinks and unexplained recorder/network congestion.

### CCTV-03 recording storage

Scenarios vary:

- 7/14/30/60/90-day horizons;
- 8/12/24 h/day schedules;
- DST transitions;
- overlapping schedules;
- reserve 1.0–1.3;
- redundancy usable fractions;
- expected versus guaranteed bitrate bounds.

Required calculation order remains:

```text
expand schedule
→ UTC half-open intervals
→ union overlap
→ exact bitrate × time / 8
→ sum exact bytes
→ reserve once
→ ceil once
→ redundancy conversion
```

**Engineer benefit:** avoids both expensive over-sizing and dangerous retention shortfall caused by repeated rounding or missing schedule overlap.

### CCTV-04/05/06

Cases test shared PSE totals, recorder channel/ingress/storage dimensions, license-accounting basis, realized media/path and PoE applicability.

**Engineer benefit:** one failed dimension cannot hide behind enough channels or enough disk space elsewhere.

## P4 — LAN

### LAN-01 path length

The simulation deliberately creates permanent-link/channel boundaries, patch-cord additions, duplicate sections and service-loop double accounting.

**Engineer benefit:** installed path is counted once from actual route evidence rather than reconstructed independently in several worksheets.

### LAN-02/07 physical resource capacity

8/24/48-port classes stress occupied ports, spare policy, aliases, patch mappings and boundary `ceil` behavior.

**Engineer benefit:** prevents the classic “port exists in the table twice but physically only once” mistake.

### LAN-03 shared PoE

CCTV and LAN endpoints share one PSE. The scenario fails if a discipline filter removes loads from the physical total.

### LAN-04 weakest-section compatibility

A high-category main cable does not rescue an incompatible patch cord/interface/shielding section.

### LAN-05 optical budget

Current OS2 attenuation classes are combined with synthetic connector/splice and optic ranges. Every case evaluates:

```text
A→B sensitivity
A→B overload
B→A sensitivity
B→A overload
```

The simulation explicitly includes a case where sensitivity passes but receiver overload fails.

**Engineer benefit:** avoids the false confidence created by a single average-loss number.

### LAN-06 rack basis

RU/weight/depth demand is calculated, but actual cabinet fit remains ELV6 `NOT_ASSESSED`.

**Engineer benefit:** a capacity spreadsheet cannot falsely certify physical fit.

## P5 — access control

The current market snapshot intentionally includes very different 24 V strike currents. The same door count may therefore produce radically different electrical demand.

### ACS-01/02

Role alternatives and physical reader/relay/input pools are varied independently.

### ACS-03

Simulation ranges include low-current and high-current lock classes, trunk load, trunk resistance, branch resistance and startup/transient cases.

The independent reference fixture remains:

```text
24.00 V
- 0.8 A × 0.5 Ω
- 0.3 A × 0.3 Ω
= 23.51 V

margin against 22.00 V = +1.51 V
```

The matrix rejects a control relay as evidence of a conductive lock feed.

**Engineer benefit:** exposes doors that work on the bench but become unstable at the far end of a loaded trunk.

### ACS-04/05

Shared non-ACS loads remain in source/battery totals. Reserve/derating are applied once. Energy PASS cannot hide current/EOD failure.

### ACS-06

Each door is evaluated across:

```text
NORMAL_ACCESS
REQUEST_TO_EXIT
FIRE_RELEASE
EMERGENCY_BREAK_GLASS
POWER_FAILURE
```

Fail-safe/fail-secure/project-defined behavior must be explicit.

**Engineer benefit:** reduces expensive late-stage rewiring when emergency-release logic was never fully modelled.

## P6 — fire alarm

### FA-01 addresses/resources

Simulation covers 50/198/954-point market classes, multi-address devices, reserved ranges and duplicate claims.

**Engineer benefit:** catches address/resource collisions before programming and commissioning.

### FA-02 current

Standby and alarm states are independent. Missing alarm current cannot be hidden by a known standby subtotal.

### FA-03 electrical basis

Supported radial/one-control-point models may consume ELV4 voltage-drop evidence. A closed signal loop does not magically become a solved dual-fed electrical mesh.

### FA-04 source requirement

All panel/loop/module/notification/aux loads plus shared non-fire loads stay in the global source closure.

### FA-05 backup

Simulation varies standby duration, alarm duration, sequence demand and supported bank model. It intentionally includes nominal-Ah shortcut cases that must remain blocked.

### FA-06 notification circuits

Count, continuous/alarm current, startup and terminal voltage are independent dimensions. Acoustic coverage remains outside this electrical capacity result.

### FA-07 signal topology

Closed return, branch rules and address membership are checked on the signaling layer. Signal topology cannot override an unsupported power model.

### FA-08 cable policy/evidence

Technical project policy match stays separate from verified jurisdictional compliance.

**Engineer benefit:** reduces the dangerous class of “system looks connected on the drawing, therefore electrically and normatively it must be valid.”

# P7 — dependencies, incremental recalculation and workspace

The 450 scenarios also test the expected dependency behavior conceptually:

```text
edit one camera bitrate
→ CCTV-02
→ CCTV-03
→ CCTV-05

not:
→ recalculate every CCTV/LAN/ACS/Fire process
```

Shared source edits deliberately fan out across disciplines.

The generated matrix records the primary error class and remediation direction. The eventual workspace should surface this as stable structured findings, not vague red text.

**Engineer benefit:** after a design edit the application tells the engineer exactly what became stale and why, instead of forcing a manual audit of the whole project.

# P8 — qualification

The market matrix supplements, not replaces:

- 54 primary public process verticals;
- 135 mandatory dossier vectors;
- L0–L6 runtime qualification;
- failure/race/restart/migration suites;
- exact profile-mode performance evidence.

The 450 cases add market-shaped combination coverage over multiple project scales and error classes.

CI validates:

```text
exactly 450 scenarios
27/27 processes
5/5 vector classes for every process
P0..P9 aggregate coverage
all priority-core processes >=23 scenarios
all other processes =12 scenarios
vendorFact / marketEnvelope / syntheticFixture separation
>=18 engineering error classes covered
ACS-03 corrected arithmetic
current-market sanity anchors
```

# P9 — closure and engineer value

P9 must reconcile the market-simulation matrix with the accepted authority fingerprint and source SHA. It may not close a runtime stage because a design simulation passed.

The purpose of the matrix is to answer a stricter engineering question before runtime closure:

> Did Electra anticipate the combinations that cause experienced engineers to make costly mistakes when several otherwise-correct subsystem assumptions interact?

Expected error-reduction categories include:

1. duplicate physical resources;
2. units/dimensions mixed in one spreadsheet column;
3. typical value used as guaranteed value;
4. reserve/derating applied twice;
5. shared source filtered by discipline;
6. stale result published after project edit;
7. bitrate inferred from resolution/codec label;
8. multicast bandwidth undercount;
9. recording interval double count;
10. port/address alias overcount;
11. optical overload ignored;
12. optical budget mistaken for transmission reach;
13. RU capacity mistaken for rack fit;
14. dry relay contact mistaken for lock power feed;
15. startup/inrush ignored;
16. incomplete fail-safe release behavior;
17. battery Ah shortcut;
18. fire address overlap;
19. signal topology mistaken for electrical model;
20. technical policy match mistaken for legal compliance;
21. N+1 data capture making large projects unusable;
22. global Flutter rebuild causing engineering UI jank.

## Simulation acceptance

The simulation layer is acceptable for design entry only when its CI artifact reports:

```text
scenarioCount = 450
processCount = 27
packages = P0..P9
vectorClasses = 5 per process
marketRequirementCount = 12
claim = DESIGN_SIMULATION_ONLY_RUNTIME_NOT_EXECUTED
```

The matrix must remain deterministic. Any market-catalog, process, requirements, algorithm or simulation-rule change changes the exact-head evidence and requires regeneration.
