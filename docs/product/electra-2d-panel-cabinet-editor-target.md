# Electra — 2D Panel & Cabinet Editor Target

Status: **TARGET / NORTH STAR / NOT IMPLEMENTATION / NOT ACCEPTANCE**

Parent target: `electra-professional-electrical-platform-target.md`

Related: CAP-05, CAP-06, CAP-16, CAP-17, CAP-19, CAP-21, ELV6, ELV8, K0, K2, K7 and the identification/cabinet-entry/simulation addendum.

## 1. Purpose

Electra requires a first-class **2D engineering editor for switchboards, distribution boards, MCCs and automation/control cabinets**.

The editor is not a freehand CAD application and does not own a second panel database. It is a structured view/editor of the canonical engineering model.

Canonical rule:

```text
CANONICAL PANEL MODEL
        │
        ├── K0 automatic synthesis
        ├── 2D panel/cabinet editor
        ├── SLD
        ├── panel schedule
        ├── terminal plan
        ├── cable-entry plan
        ├── wiring/label projections
        ├── BOM
        └── commissioning evidence
```

A graphical edit changes typed placement/routing facts, triggers dependency invalidation and re-runs applicable engineering validation. Drawing pixels never become engineering truth.

---

## 2. Initial supported panel classes

The 2D editor shall support the physical-layout requirements of at least:

- DISTRIBUTION_BOARD;
- FLOOR_DISTRIBUTION_BOARD;
- MCC;
- AUTOMATION_PANEL;
- PLC_PANEL;
- MIXED_CONTROL_POWER_PANEL;
- CUSTOM_PANEL where required facts are available.

The first implementation is front-view 2D. Photorealistic rendering and full 3D cabinet CAD are explicitly deferred.

---

## 3. Coordinate and geometry model

Canonical geometry is physical, not screen-relative.

Required principles:

- millimetres are the canonical physical coordinate system for enclosure geometry;
- DIN-module coordinates may be used for DIN-mounted equipment but must resolve to physical geometry;
- zoom/pan transforms affect only presentation;
- placement snapping is deterministic;
- all generated/exported geometry is reproducible from the same frozen revision and catalog/layout versions.

Representative primitives:

```text
Panel2DLayout
CabinetSection2D
MountingSurface2D
DinRailPlacement2D
DevicePlacement2D
TerminalBlockPlacement2D
BusbarPlacement2D
NeutralBarPlacement2D
PeBarPlacement2D
WiringDuctPlacement2D
CableEntryZonePlacement2D
GlandPlatePlacement2D
LabelPlacement2D
```

Representative placement contract:

```text
DevicePlacement2D
- placementId
- panelId
- deviceRef
- sectionId
- mountingSurfaceId
- mountingType
- xMm
- yMm
- widthMm
- heightMm
- depthMm?
- dinRailId?
- startModule?
- moduleSpan?
- orientation
- locked
- revision
```

For DIN devices, `dinRailId + startModule + moduleSpan` is authoritative where applicable; arbitrary screen coordinates must not bypass DIN occupancy rules.

---

## 4. Required editor views

The editor shall provide coordinated layers/views over one model.

### 4.1 PHYSICAL

Shows at least:

- enclosure outline and sections;
- mounting plate/surfaces;
- DIN rails;
- protective devices and other equipment;
- terminals;
- busbars;
- N/PE bars;
- wiring ducts/routes;
- cable-entry zones;
- gland plates/openings;
- reserve/spare zones.

### 4.2 ELECTRICAL

Overlays logical electrical relationships:

- incomer;
- buses;
- branch protection;
- outgoing circuits;
- phase assignment;
- source/load relationship;
- circuit/device identity.

This view is derived from the electrical topology and must not create parallel connections.

### 4.3 WIRING

Shows structured termination and internal-wiring relationships:

```text
Device terminal
   ↓
Internal wire/channel
   ↓
Terminal block
   ↓
Cable core
   ↓
External cable
```

The initial release may use simplified orthogonal routes; visual simplification must not change termination truth.

### 4.4 CABLE ENTRY / ROUTING

Shows:

- TOP/BOTTOM/LEFT/RIGHT/CUSTOM entry zones;
- assigned incoming/outgoing cables;
- gland/gland-plate position where known;
- internal cable route to terminal/device;
- bend-radius and segregation findings;
- route congestion/capacity findings.

### 4.5 VALIDATION

Overlay for:

- hard blockers;
- unresolved facts;
- warnings;
- module/space occupancy;
- reserve capacity;
- route conflicts;
- clearance conflicts;
- thermal evidence when a qualified model exists.

The editor shall never paint PASS without a supporting validator result.

---

## 5. Editing operations

P0 interaction set:

- select one/many objects;
- pan/zoom;
- drag device;
- deterministic DIN snap;
- move between compatible rails/sections;
- reorder devices on a rail;
- place/move terminal blocks;
- create/move cable-entry zones where enclosure policy permits;
- place/move wiring ducts;
- reserve free modules/physical zones;
- lock placement;
- undo/redo within a working revision;
- compare candidate layout with current accepted layout;
- accept/reject K0-generated candidate layout.

Manual edits remain candidate changes until validation/publication rules allow them to become current.

---

## 6. K0 automatic synthesis integration

K0 shall be able to produce `Panel2DLayoutCandidate` objects rather than only a list of devices.

Target workflow:

```text
circuits / requirements
        ↓
K0 SYNTHESIS
        ↓
validated candidate set
        ↓
2D PREVIEW
        ↓
engineer moves / groups / reserves
        ↓
LIVE REVALIDATION
        ↓
ACCEPT / REGENERATE / REJECT
```

Candidate variants may include COMPACT, BALANCED and EXPANDABLE subject to the K0 contract.

The editor must preserve the synthesis trace and distinguish:

- AUTO_SELECTED;
- USER_SELECTED;
- USER_OVERRIDE.

A manual move must not erase why the original candidate was chosen.

---

## 7. Equipment geometry and catalog integration

The editor consumes physical equipment facts from the generic engineering definition and, when selected, exact ELV8/catalog SKU.

Typical physical facts:

```text
mountingType
moduleWidthUnits?
widthMm
heightMm
depthMm
requiredClearanceMm?
heatDissipationW?
terminalLocations?
accessoryZones?
compatibleRailOrMountingSystem?
```

Unknown exact SKU geometry may use an explicitly identified generic engineering envelope only when permitted by the applicable workflow. It must not masquerade as manufacturer-verified fit.

Changing selected SKU invalidates physical-fit/layout results when dimensions, mounting, terminal or accessory facts differ.

---

## 8. Mandatory layout checks

Where required evidence exists, the 2D editor validation pipeline shall cover at least:

- enclosure boundary fit;
- DIN/module occupancy;
- overlapping placements;
- mounting compatibility;
- mandatory device/accessory adjacency;
- physical clearance;
- reserve policy;
- terminal capacity;
- cable-entry capacity;
- internal wiring-duct capacity where modeled;
- cable bend radius where modeled;
- power/control/ELV segregation where applicable;
- N/PE termination availability;
- service/maintenance accessibility where rules exist;
- impossible internal route;
- catalog compatibility;
- applicable normative rule findings.

Hard-constraint violation blocks publication of a layout as valid.

---

## 9. Cable, terminal and marking integration

The editor shall display the same canonical identities used elsewhere in Electra.

Example:

```text
QF17
  ↓
X1:24
  ↓
DB01-LGT-017 / L
```

A selected cable can be traced from external route through cabinet entry to internal termination.

Label/QR projection is derived from the same objects and shall not be manually re-keyed independently in the 2D editor.

Target outputs include:

- panel front/layout drawing;
- DIN rail layout;
- cable-entry plan;
- terminal plan;
- wiring/termination schedule;
- cable/core/device labels;
- panel schedule;
- BOM references;
- commissioning reference IDs.

---

## 10. SLD relationship

The SLD and 2D panel editor are two views of the same project model.

```text
                 CANONICAL MODEL
                 /             \
                /               \
              SLD            2D PANEL
```

Changing a protective-device engineering fact in an authorized workflow must invalidate/update both views and all dependent schedules. The 2D editor must not create an electrical connection that is absent from the canonical topology.

---

## 11. Performance and interaction targets

The editor shall be designed for offline Flutter/mobile/desktop usage without requiring a cloud round trip for ordinary editing.

Target design principles:

- viewport virtualization/culling for large panels;
- cached immutable geometry projections;
- incremental validation of affected dependency closure;
- deterministic hit testing and snapping;
- no engineering recalculation on every paint frame;
- expensive validation scheduled from committed model edits, not pointer-move noise.

Exact performance thresholds must be frozen by a later qualification contract against representative 12/24/36/72+ circuit boards and larger automation panels.

---

## 12. Revision, replay and collaboration semantics

- FROZEN panel layouts are immutable.
- Editing requires a WORKING revision/candidate.
- create-next materializes the accepted physical/layout state deterministically.
- undo/redo is workspace behavior and must not rewrite frozen history.
- same frozen revision + same layout/catalog/ruleset versions => same deterministic 2D projection/fingerprint.
- collaboration must not silently merge conflicting device placements; conflicts require explicit resolution.

---

## 13. Delivery priority

Recommended sequence:

```text
PANEL2D-01 canonical 2D geometry/placement contracts
PANEL2D-02 enclosure + DIN rail + generic device rendering
PANEL2D-03 deterministic drag/snap/reorder + undo/redo
PANEL2D-04 terminal/N/PE/busbar/duct placements
PANEL2D-05 cable-entry zones + internal route visualization
PANEL2D-06 live physical validation overlays
PANEL2D-07 K0 candidate preview/compare/apply
PANEL2D-08 labels/QR/terminal/cable schedule projections
PANEL2D-09 ELV8 exact SKU geometry/accessory integration
PANEL2D-10 qualification, replay, frozen-history and workload gates
```

### P0 for first professional panel workflow

- front-view 2D enclosure;
- DIN rails;
- breakers/devices;
- terminals;
- N/PE bars;
- wiring ducts;
- cable-entry zones;
- deterministic drag/snap;
- capacity/overlap/fit validation;
- K0 candidate preview/edit/revalidate;
- deterministic PDF/layout export.

### P1

- detailed internal wire/core routing;
- richer terminal geometry;
- thermal/segregation overlays where qualified;
- catalog accessory placement;
- advanced label placement.

### P2/P3

- manufacturer visual skins/front faces;
- advanced industrial mounting plates;
- 3D enclosure/collision/cable-bend visualization.

---

## 14. Acceptance principles

The 2D editor may reach ACCEPTED only when qualification proves at least:

1. deterministic projection and snapping;
2. no overlap/occupancy bypass through UI edits;
3. manual override triggers correct dependency invalidation;
4. K0 candidate → edit → validate → accept preserves trace;
5. top/bottom/mixed cable entry remains reproducible;
6. cable/terminal identities remain consistent across editor, SLD, schedules and labels;
7. frozen revision replay reproduces identical layout fingerprint;
8. persistence restart does not change placement;
9. representative large-panel workload remains within declared performance bounds;
10. no freehand drawing state can claim engineering validity outside canonical typed objects.

## 15. Non-goals for first release

Not required initially:

- full general-purpose CAD;
- photorealistic device rendering;
- 3D cabinet authoring;
- automatic mechanical fabrication drawings;
- electromagnetic thermal CFD;
- manufacturer-specific editor lock-in.

The first release optimizes for **engineering correctness, rapid editing, deterministic auto-layout review and constructible panel documentation**.