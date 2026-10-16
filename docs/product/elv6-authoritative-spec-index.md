# Electra — ELV6 Authoritative Design Index

Status: DESIGN DRAFT / RUNTIME NOT STARTED
Branch: `feat/flutter-elv6-enclosure-layout-design`
Parent baseline: `feat/flutter-elv5-power-topology-design`
Pinned parent: `a20ae91ecbef1da0d16443201e48f7e1b99e8701`

ELV6 owns **enclosure, cabinet, rack and internal mounting layout**. It converts already-engineered equipment, power, battery, patching and capacity demand into a deterministic physical arrangement. It does not recompute ELV3 physical routing, ELV4 power, ELV5 discipline calculations, ELV7 jurisdictional compliance or ELV8 manufacturer/SKU selection.

## Entry documents

1. [ELV6 enclosure-layout design specification](elv6-enclosure-layout-design-specification.md).
2. [ELV6 P0–P9 delivery plan](elv6-p0-p9-delivery-plan.md).
3. Existing [ELV5 authoritative index](elv5-authoritative-spec-index.md) and code-level contracts are the pinned upstream calculation boundary.
4. Existing architecture and implementation blueprint remain authoritative for offline-first persistence, command/result semantics, revisioning, deterministic derived data and immutable publication.

## Authority hierarchy

When documents disagree, use this order:

1. accepted ELV1–ELV5 runtime identity/ownership/revision contracts;
2. this ELV6 authoritative index and ELV6 design specification;
3. ELV6 P0–P9 package plan;
4. architecture overview and legacy product notes.

ELV6 may add new typed enclosure/layout entities and command surfaces. It must not fork `Cable`, `CableRun`, `Route`, power evaluations, discipline evaluations, catalog identity, command history or design revision ownership.

## Stage boundary

```text
ELV2 exact definitions / editions
    ↓
ELV3 realized cables, routes, pathways and physical facts
    ↓
ELV4 power topology, source/UPS/battery evidence
    ↓
ELV5 discipline calculations and rack/capacity demand basis
    ↓
ELV6 enclosure/rack physical layout and fit
    ↓
ELV7 normative validation
    ↓
ELV8 manufacturer selection, BOM and deliverables
```

ELV6 is allowed to report intrinsic mechanical/geometric infeasibility such as overlap, out-of-bounds placement, impossible rack-unit occupation, inaccessible cable entry or battery envelope collision. A jurisdiction-specific clearance or installation rule remains an ELV7 rule and must arrive through a versioned normative profile rather than be hardcoded into ELV6.

## Non-negotiable decisions

- Layout is revision-scoped and offline-capable.
- All dimensions use canonical persisted millimetres; rack-unit/module abstractions also retain exact physical envelopes.
- Placement is explicit, normalized and addressable; no opaque layout JSON is the source of truth.
- Auto-layout produces a deterministic **proposal**, never silent mutation.
- User-locked placements are immutable to auto-layout until explicitly unlocked.
- Missing upstream evidence is `BLOCKED`/`UNRESOLVED`, never guessed.
- Stale upstream input marks affected layout evidence stale; historical frozen revisions are immutable.
- Battery fit, service access, cable-entry occupancy and mounting compatibility are first-class facts.
- Manufacturer/SKU-specific optimization belongs to ELV8 unless an exact adopted catalog definition already exists upstream as immutable technical input.

## Runtime entry gate

Implementation may start only after P0 confirms the exact accepted ELV5 source SHA, database schema baseline, existing command replay/UoW APIs, revision/freeze APIs and available upstream rack/battery/capacity facts. No ELV6 package may invent a duplicate upstream calculation to unblock itself.

All ELV6 P0–P9 runtime packages are currently `NOT_STARTED`. Design completion does not imply runtime qualification.