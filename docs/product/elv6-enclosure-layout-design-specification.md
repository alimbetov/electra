# Electra — ELV6 Enclosure, Rack and Constructability Design Specification

Status: **DESIGN HARDENED / RUNTIME NOT STARTED**  
Branch: `feat/flutter-elv6-enclosure-layout-design`  
Pinned design upstream ELV5: `ed7db01adb27ff184b0b8c91a710082fb9eafb9a`  
Entry: [authoritative index](elv6-authoritative-spec-index.md)  
Runtime detail: [code-level contract](elv6-implementation/code-level-runtime-contract.md)

## 1. Engineering purpose

ELV6 answers the question an experienced design/installation engineer actually asks after electrical and ELV calculations are complete:

> **Can the selected technical functions be physically assembled, wired, accessed, cooled, maintained and reproduced inside the proposed panel/rack without inventing missing facts?**

For every host ELV6 must make the following explicit and reproducible:

- host/enclosure identity and exact usable geometry;
- mounting surfaces and interfaces;
- exact position/orientation of placed subjects;
- rack U and DIN occupation;
- physical body/depth and front/rear protrusions;
- service/removal/connector envelopes;
- door-mounted equipment and swept access envelope;
- cable entry/gland/knockout assignments;
- cable approach/bend/strain-relief space where exact technical facts exist;
- internal wiring duct and physical termination capacity basis;
- battery body/orientation/service/handling fit;
- local support load, total mass and centre-of-gravity basis;
- ventilation openings, fan/airflow physical facts and heat-loss input basis;
- observed physical segregation geometry;
- physical protective-bonding points/declared links;
- reserve/spare physical capacity;
- exact reason for every intrinsic FAIL, unresolved dimension or stale result;
- deterministic proposal explaining why the solver placed or could not place each item.

ELV6 is **not** an equipment selector, power calculator, cable routing engine or normative compliance engine.

---

## 2. Corrected baseline and ownership model

### 2.1 What already exists

The repository has an accepted semantic model and ADR vocabulary:

```text
PanelAssembly
PanelEnclosureGeometry
PanelMountingSection
DinRail
PanelModulePlacement
PanelTerminalRail
PanelCableDuct
PanelReservedZone
ADR-019 physical panel layout
```

This vocabulary is preserved. However, a domain class or accepted ADR does not by itself prove persisted revision-scoped ownership.

### 2.2 What P0 must prove

For each physical fact family P0 creates a row in the ownership matrix:

```text
factKind
semanticOwner
runtimeTable/path
publicWriter
revisionIdentity
rowCAS
replayLedger
historyUndoRedo
freezeSection
createNextRemap
qualificationEvidence
status
```

Status is one of:

```text
SEMANTIC_ONLY
PERSISTED
PUBLIC_WRITER
REVISION_INTEGRATED
QUALIFIED
ABSENT
```

No later package may write a new table merely because a P0 owner is inconvenient.

### 2.3 Promotion rule

If the current repository has no persisted runtime owner for `PanelAssembly` physical layout, ELV6 implements the first persisted owner **using the existing semantic identity**, not a second generic-panel model. If an accepted writer exists, ELV6 routes through it.

The normalized workspace can unify panel and rack views through adapters while preserving the canonical writer underneath.

---

## 3. Upstream contract

| Owner | ELV6 consumes | ELV6 must not duplicate |
|---|---|---|
| ELV2 | immutable selected/adopted technical definitions and physical data | product selection, latest-edition fallback |
| ELV3 | cable/run/end/termination/path identities and exact physical facts | route topology, cable allocation, installed length |
| ELV4 | source/UPS/battery identities and immutable evidence | load/source/battery runtime sizing |
| ELV5 | discipline results, rack/patch/capacity demand facts and exact evidence refs | CCTV/LAN/ACS/Fire calculations |
| shared runtime | design revision, command result, ledger/history/UoW/freeze/create-next | parallel revision/history system |

Every consumed upstream row/evaluation is pinned by immutable identity/fingerprint. “Current selected UI object” is never sufficient provenance.

---

## 4. Stage claim boundary

### ELV6 may conclude intrinsic `FAIL` when exact facts prove:

- body outside usable enclosure;
- occupied-volume collision;
- rack U conflict;
- rail-depth or mounting-interface incompatibility;
- DIN interval/physical-width overflow;
- service/removal/door-sweep collision;
- cable-entry exclusive conflict or explicit physical capacity overflow;
- adopted technical bend envelope collision;
- physical termination count overflow;
- battery physical/orientation incompatibility;
- adopted shelf/surface static-load overload;
- intrinsic airflow keepout blocked.

### ELV6 must not conclude normative compliance/non-compliance for:

- IEC 61439 assembly conformity;
- project/jurisdiction minimum clearances or segregation;
- temperature-rise conformity;
- IP degree after openings/glands/modifications;
- protective-bonding conductor sizing/mandatory topology;
- seismic/anchorage/anti-tip compliance;
- manufacturer/SKU suitability as a purchasing decision.

ELV6 exports the physical evidence needed by ELV7. ELV8 later selects products against ELV6 technical requirements and must trigger revalidation when selected physical facts change.

---

## 5. Canonical mechanical geometry

### 5.1 Fixed-point units

New persisted ELV6 mechanical geometry uses exact integer micrometres (`µm`).

```text
1 mm = 1000 µm
```

Why this is mandatory:

- project persisted floor geometry is integer millimetres and converts exactly;
- rack mechanics can contain sub-mm dimensions;
- deterministic hashing/replay cannot depend on binary floating formatting/tolerance;
- collision boundaries must have one exact interpretation.

Legacy `double` values are compatibility inputs only and pass through a versioned normalizer with explicit import tolerance.

### 5.2 Canonical host frame

```text
+X: left → right when viewed from front
+Y: bottom → top
+Z: front → rear
```

All persisted V1 placement transforms are orthogonal. Front/rear/side/section UI views derive from this frame.

### 5.3 Occupancy math

AABB uses half-open bounds:

```text
[minX,maxX) × [minY,maxY) × [minZ,maxZ)
```

Containment:

```text
host.minAxis <= item.minAxis
item.maxAxis <= host.maxAxis
for X,Y,Z
```

Two occupied AABBs overlap iff all three axis intersections have positive length:

```text
max(a.minX,b.minX) < min(a.maxX,b.maxX)
and same for Y,Z
```

Touching faces are not collision by body geometry. A required service/clearance envelope can still collide.

---

## 6. Host model

### 6.1 Host kinds

```text
PANEL_ASSEMBLY
ELV_WALL_CABINET
ELV_FLOOR_RACK
ELV_FLOOR_CABINET
BOX
CUSTOM
```

Panel identity remains `PanelAssembly`. Non-panel telecom/ELV hosts are ELV6-owned.

### 6.2 Host required facts

```text
id + logicalId
projectId + designRevisionId
ownerKind + hostKind
outer AABB
usable AABB
locationRef
mounting surfaces
rack profile if applicable
technicalDefinitionRef if adopted
rowRevision + fingerprint
```

Optional technical facts are independent: environmental/IP claim refs, material/surface refs, static load capability, ventilation openings, door mechanics, grounding/bond points. Missing optional facts block only dependent processes.

---

## 7. Mounting surfaces

Supported initial kinds:

```text
DIN_RAIL
FRONT_RACK_RAILS
REAR_RACK_RAILS
FOUR_POST_RACK_RAILS
SHELF
BACKPLATE
DOOR_INNER
DOOR_OUTER
TERMINAL_RAIL
BATTERY_TRAY
CUSTOM_PLANE
```

A surface is not just a label. It has host-local frame, usable envelope and typed capabilities.

Unknown capability is `UNRESOLVED`, not unlimited.

---

## 8. Rack engineering

### 8.1 Rack profile

Rack interface dimensions come from an adopted versioned technical profile. The engine must not assume every rack is a universal “19 inch” host.

A profile includes:

```text
rackUnitPitchUm
frontInterfaceWidthUm
rearInterfaceWidthUm?
railDepthRange
mountingModes
sourceRef/hash
```

IEC 60297-3-100 may be a source for a profile, but the project ruleset/applicability is not encoded as an ELV6 global constant.

### 8.2 U interval

```text
span = [firstU, firstU + heightU)
```

Utilization:

```text
occupiedU = cardinality(union(active exclusive U positions))
reservedU = cardinality(explicit reserve set not already occupied)
freeU = usableU - occupiedU - reservedU
```

Do not sum overlapping reservations twice.

### 8.3 Front/rear/depth

U PASS does not imply mountability. Rail-depth/mounting mode/body/protrusion checks are independent.

---

## 9. DIN engineering

Legacy concepts remain recognizable:

```text
position
moduleWidthUnits
modulePitch
physicalWidth
railLength
```

But runtime placement gains stable identity/revision and exact geometry.

DIN interval:

```text
[position, position + moduleWidthUnits)
```

If both discrete module and physical-width bases exist, both must pass. A module-count PASS cannot hide millimetre overflow.

Reserved modules are explicit reservations, not fake devices.

---

## 10. Physical subject definition

Every placed item resolves an immutable physical definition with independent facts:

```text
body envelope
allowed mounting modes
supported orientations
connector protrusions
service envelopes
removal envelopes
airflow keepouts
mass
local center of gravity
heat loss
```

This prevents a common engineering error: equating “device footprint fits” with “device can be wired and maintained”.

A missing heat-loss fact does not erase valid placement geometry; it makes the thermal basis partial.

---

## 11. Serviceability and door mechanics

Service/removal envelopes are first-class geometry. Typical examples:

- front access needed to replace an MCB/relay/module;
- rear space to disconnect a server/patch lead;
- battery lift/remove path;
- plug/terminal screwdriver/access volume;
- fan/filter maintenance access.

Door model stores hinge axis, closed frame and allowed opening range. V1 uses a versioned conservative swept-envelope backend. Door-mounted devices participate in the sweep.

---

## 12. Cable entry and internal wiring

### 12.1 Cable entry

Entry types include gland, gland plate, knockout, brush panel, floor/roof/side/rear opening and custom.

Assignment identity is the exact cable end, not a cable label. Exclusive cable end may not be simultaneously assigned to two physical entries in one revision.

### 12.2 Bend/strain envelope

When exact cable/connector technical facts give minimum bend or protrusion/strain requirements, ELV6 evaluates them geometrically. It never invents a generic bend multiplier.

### 12.3 Internal wiring duct

For each positioned duct ELV6 can store:

```text
body geometry
usable cross-sectional area
usable length
assigned bundle/conductor refs
observed area/volume basis
```

ELV6 does not hardcode a regulatory fill percentage. It exports used/free physical basis to ELV7.

### 12.4 Terminations and patching

Physical positions are separate from ELV5 logical port counts. ELV6 checks exact assignment uniqueness, physical position capacity and adopted interface facts.

---

## 13. Battery constructability

Battery physical fit consumes exact ELV4 battery/bank identity but does not recalculate runtime/capacity.

Independent dimensions:

```text
body containment
orientation
terminal access
handling/removal envelope
surface/support load
contribution to total host mass/CoG
thermal contribution only when exact heat-loss fact exists
```

Electrical battery PASS never implies physical PASS.

---

## 14. Mass and centre of gravity

Mass is integer grams. Exact moments:

```text
Mx = Σ(m_i * x_i)
My = Σ(m_i * y_i)
Mz = Σ(m_i * z_i)
M  = Σ(m_i)
CoG = (Mx/M, My/M, Mz/M)
```

Moments are integer gram·µm; division yields an exact rational/bounded persisted result according to the numeric codec.

If one required mass is unknown, aggregate CoG is partial/unresolved rather than computed from the known subset and mislabeled complete.

---

## 15. Ventilation and thermal preparation

ELV6 must preserve the data that later thermal verification needs:

- declared equipment heat losses;
- positioned heat-source distribution;
- enclosure dimensions/surfaces/material technical refs when available;
- ventilation openings and free areas;
- fans, positions, directions and adopted ratings;
- partitions;
- blocked airflow keepouts;
- adjacent-wall/exposed-surface facts where modelled.

Heat loss sum:

```text
P_loss_declared = Σ exact adopted subject heatLoss
```

A device supply/load wattage is not substituted for heat loss without an exact model.

IEC TR 60890:2022 demonstrates why enclosure geometry, power-loss distribution, ventilation, material/surface and adjacency facts matter, but ELV6 produces only a thermal-input basis. ELV7/rules profiles own method applicability and compliance conclusions.

---

## 16. Environmental/IP evidence boundary

ELV6 may store the selected enclosure protection claim/reference and the physical openings/glands/doors that can affect that evidence. It must not recalculate or guarantee an IP code from geometry alone.

IEC 60529 is therefore an ELV7/reference concern; ELV6 supplies exact physical modification/provenance facts.

---

## 17. Segregation and bonding

### Segregation

ELV6 measures observed intersection/shortest-distance geometry between declared groups/zones. Required minimum values belong to ELV7 unless they are an intrinsic manufacturer constraint.

### Bonding

ELV6 records physical bond points/links for host body, door, plate, rail, PE bar/rack frame where provided. It does not size protective conductors or declare electrical-safety compliance.

---

## 18. Process architecture

The runtime closed registry contains exactly 24 codes `LAY-01…LAY-24`; see `elv6-implementation/process-registry.json`.

Processes are separated deliberately so one successful subtotal cannot hide another engineering failure. Examples:

- U fit and rail-depth fit are different results;
- body containment and serviceability are different results;
- battery electrical evidence and physical battery fit are different stages;
- airflow physical clearance and thermal verification are different claims;
- observed segregation and normative required segregation are different stages.

The aggregate `LAY-24` may PASS only if all applicable required intrinsic dimensions are complete/pass. Later-stage normative dimensions remain explicitly `NOT_ASSESSED`.

---

## 19. Evaluation states

ELV6 uses four axes:

```text
Freshness:  CURRENT | STALE
Completion: COMPLETE | PARTIAL | BLOCKED
Assessment: PASS | FAIL | UNRESOLVED | NOT_ASSESSED
Execution:  SUCCEEDED | FAILED
```

Examples:

- body collision: `SUCCEEDED / COMPLETE / FAIL`;
- missing depth, known width/height: `SUCCEEDED / PARTIAL / UNRESOLVED`;
- unsupported mechanical model: `SUCCEEDED / BLOCKED / UNRESOLVED`;
- exception/invalid engine state: `FAILED`;
- upstream changed after publication: pointer `STALE`, immutable record unchanged.

---

## 20. Deterministic auto-layout

Auto-layout is an engineer assistant, never an auto-commit engine.

### Hard constraints

Cannot be traded for score:

```text
host/surface bounds
exclusive collision
mounting compatibility
locked placements
rack/DIN discrete capacity
required intrinsic service/bend/door constraints
explicit support-load capability
```

### Lexicographic optimization vector

After feasibility:

1. preserve existing manual placement;
2. reduce unresolved service/access/bend conflicts;
3. minimize exact physical affinity cost where evidence exists;
4. reduce fragmentation;
5. preserve declared reserve;
6. stable readable ordering;
7. stable-ID lexical tie-break.

No random seed, timestamp, DB ordering, hash-map iteration or widget position may affect output.

Proposal is immutable and stores exact capture fingerprint, solver version, policy version, item mutations, unresolved subjects, findings and complete score vector.

Acceptance is CAS-guarded and atomic across all targeted owners.

---

## 21. Public command and wire architecture

Strict schema:

```text
electra.elv6-layout-command.v1
```

Exactly 21 initial operations are registered in `elv6-implementation/command-registry.json`. The same ten-field strict envelope pattern used by ELV4/ELV5 is retained.

Client-provided dependency closures or impact lists are untrusted. Server re-resolves old/new impact before mutation.

Replay rules, row CAS, reviewed impact, history, ledger/outbox and invalidation are one atomic transaction.

ELV4 `FREEZE_DESIGN_REVISION` and `CREATE_NEXT_WORKING_DESIGN_REVISION` remain the only public revision boundary; ELV6 adds its snapshot/remap participant internally.

---

## 22. Persistence and migration

Current repository schema at design time is 23. ELV5 runtime migration is not yet finalized, therefore ELV6 does not reserve schema 24 in advance.

At implementation entry:

```text
ELV6 migration origin = exact accepted ELV5 runtime schema
ELV6 target = additive migration(s) above that schema
```

Required normalized roots are defined in the code-level contract. P0 decides whether panel-layout tables are promotion of currently semantic-only identity or adapters to existing accepted persistence.

All mutable layout roots are revision-scoped with logical IDs, row revisions and typed provenance.

Opaque JSON cannot be the sole mutable placement truth.

---

## 23. Freeze and create-next

Freeze captures canonical layout plus selected immutable proposal/evaluation evidence and adds a versioned `elv6Layout` section/hash without rewriting existing ELV3/4/5 hashes.

Historical pre-ELV6 revision:

```text
ELV6_NOT_CAPTURED
```

not empty/pass and not latest fallback.

Create-next uses typed logical mappings for every layout-owned ID. Old revision evidence is immutable.

---

## 24. Engineer workspace

Minimum serious engineering UX:

- host tree/list with owner and revision;
- front/rear/side/section projections;
- rack U and DIN rulers;
- exact numeric inspector and direct coordinate/span editing;
- keyboard nudge plus optional drag;
- U/DIN/grid/anchor snapping modes;
- multi-select and group-move preview;
- explicit lock/unlock;
- equipment/zones/ducts/entries/service/removal/airflow/segregation/bonding layers;
- “why not here?” pure-validator diagnostic before commit;
- capacity summaries for U/DIN/termination/entry/reserve/mass;
- exact source/provenance navigation;
- stale versus FAIL versus BLOCKED display;
- proposal diff with solver score vector;
- conflict retains draft;
- frozen read-only historical mode.

Drag/drop is never the only editing method.

---

## 25. ELV7 handoff

ELV6 produces a versioned immutable validation projection with:

```text
host/owner identity
exact geometry and placements
mounting capabilities
zones/ducts/entries
rack/DIN/termination capacity basis
service/removal/door/bend envelopes
battery/mass/CoG basis
ventilation/heat-loss physical facts
observed segregation geometry
bonding physical evidence
intrinsic findings
consumed upstream fingerprints
canonical hash
```

ELV7 can change normative profile and recompute compliance without changing ELV6 physical truth.

---

## 26. ELV8 handoff

ELV8 consumes technical envelope/mounting/load/thermal/connection requirements. Product substitution emits targeted impact keys. If selected dimensions or mounting facts change, affected ELV6 evidence becomes stale and must be recomputed/revalidated.

ELV8 cannot silently rearrange a host.

---

## 27. Runtime qualification

P8 must execute at one exact source SHA:

- all `LAY-01…24` positive/negative/blocked cases;
- all 21 command codecs through the public semantic adapter;
- panel-layout owner promotion/reuse proof;
- fresh DB + accepted migration origin;
- file-SQLite close/reopen;
- exact fixed-point/hash tests;
- legacy double normalization boundaries;
- response-loss replay and payload conflict;
- failure-injection rollback at every multi-table checkpoint;
- two-connection edit/proposal acceptance races;
- freeze/publication race;
- R1 freeze → R2 create-next/remap → immutable R1 read;
- targeted old+new invalidation plus unrelated negative controls;
- deterministic proposal byte/hash proof;
- ELV7 projection hash proof;
- workload-scale benchmark on a pinned CI benchmark class.

A design validator or green unrelated Flutter test never substitutes for this qualification.

---

## 28. Explicit non-goals

ELV6 does not own:

- electrical protection/source calculations;
- CCTV/LAN/ACS/Fire engineering algorithms;
- external cable route design;
- product procurement/price/BOM selection;
- national/jurisdictional compliance;
- manufacturer-certification claims;
- photorealistic rendering;
- arbitrary free-angle/full-solid CAD.

Those boundaries are deliberate. The goal of ELV6 is a **deterministic, constructability-grade physical engineering model**, not an unbounded CAD package.
