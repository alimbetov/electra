# Electra — ELV6 Authoritative Design Index

Status: DESIGN DRAFT / RUNTIME NOT STARTED
Branch: `feat/flutter-elv6-enclosure-layout-design`
Parent baseline: `feat/flutter-elv5-power-topology-design`
Pinned parent: `a20ae91ecbef1da0d16443201e48f7e1b99e8701`

ELV6 owns **enclosure, cabinet, rack and internal mounting layout**. It converts already-engineered equipment, power, battery, patching and capacity demand into deterministic physical arrangement evidence. It does not recompute ELV3 physical routing, ELV4 power, ELV5 discipline calculations, ELV7 jurisdictional compliance or ELV8 manufacturer/SKU selection.

The accepted physical panel model is already present: `PanelAssembly`, `PanelEnclosureGeometry`, `PanelMountingSection`, `DinRail`, `PanelModulePlacement`, cable ducts/reserved zones and ADR-019. ELV6 **reuses and extends that source of truth**. It must not introduce a second panel/DIN/placement model merely to make ELV6 naming uniform. New ELV6-owned enclosure identities are limited to enclosure kinds with no accepted canonical owner, such as ELV/telecom rack hosts.

## Entry documents

1. [ELV6 enclosure-layout design specification](elv6-enclosure-layout-design-specification.md).
2. [ELV6 P0–P9 delivery plan](elv6-p0-p9-delivery-plan.md).
3. Existing [ELV5 authoritative index](elv5-authoritative-spec-index.md) and code-level contracts are the pinned upstream calculation boundary.
4. [ADR-019 physical panel layout](../adr/ADR-019-physical-panel-layout-editor.md) and `packages/engineering_core/lib/src/panel_assembly.dart` are mandatory P0 baseline inputs.
5. Existing architecture and implementation blueprint remain authoritative for offline-first persistence, command/result semantics, revisioning, deterministic derived data and immutable publication.

## Authority hierarchy

When documents disagree, use this order:

1. accepted ELV1–ELV5 runtime identity/ownership/revision contracts and accepted existing panel-layout ownership;
2. this ELV6 authoritative index and ELV6 design specification;
3. ELV6 P0–P9 package plan;
4. architecture overview and legacy product notes.

ELV6 may add owner-neutral layout projections, proposals/evaluations, extension metadata and new non-panel rack entities. It must not fork existing panel enclosure/DIN/module placement truth, `Cable`, `CableRun`, `Route`, power evaluations, discipline evaluations, catalog identity, command history or design revision ownership.

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
ELV6 existing-panel reuse + ELV rack physical layout and fit
    ↓
ELV7 normative validation
    ↓
ELV8 manufacturer selection, BOM and deliverables
```

ELV6 may report intrinsic mechanical/geometric infeasibility such as overlap, out-of-bounds placement, impossible rack/DIN occupation, inaccessible cable entry or battery envelope collision. Jurisdiction-specific clearance/installation requirements remain ELV7 rules and arrive through a versioned normative profile rather than being hardcoded into ELV6.

## Non-negotiable decisions

- Existing `PanelAssembly`/DIN/module identity is reused until a separately qualified migration/generalization replaces it.
- One physical enclosure/placement has one active canonical owner in one revision.
- Layout is revision-scoped and offline-capable.
- New geometry follows the accepted project millimetre/numeric convention; ELV6 does not create an incompatible integer-mm fork.
- Auto-layout produces a deterministic **proposal**, never silent mutation.
- User-locked placements are immutable to auto-layout until explicitly unlocked.
- Missing upstream evidence is `BLOCKED`/`UNRESOLVED`, never guessed.
- Stale upstream input marks affected layout evidence stale; historical frozen revisions are immutable.
- Battery fit, service access, cable-entry occupancy and mounting compatibility are first-class facts.
- Manufacturer/SKU-specific optimization belongs to ELV8 unless an exact adopted technical definition already exists upstream.

## Runtime entry gate

Implementation may start only after P0 inventories the current panel domain/schema/write APIs/validation behavior, pins the accepted geometry scalar convention, confirms the exact accepted ELV5 source SHA, existing replay/UoW/revision/freeze APIs and available upstream rack/battery/capacity facts. No package may duplicate an existing panel object or upstream calculation to unblock itself.

All ELV6 P0–P9 runtime packages are currently `NOT_STARTED`. Design completion does not imply runtime qualification.