# Electra — Development roadmap

The detailed scope and evidence live in [Flutter delivery plan](flutter-delivery-plan.md).
Electrical delivery branch: `feat/flutter-routing-cablerun`.
Current ELV design branch: `feat/flutter-elv3-physical-routing-design`.
Accepted ELV1/ELV2 baseline: `main@786a28ac6e4b532b1e7ac2083502799935ca51ed`.
Delivery is incremental: each baseline has an exact-commit Flutter/core CI gate.

| Milestone | Outcome | Status |
|---|---|---|
| FL0–2 | Flutter, SQLite, project/floor/room hierarchy | Implemented foundation |
| FL3–6 | Geometry kernel, room editor, surface navigation, component placement | Baseline closed |
| FL7–8 | Explicit electrical loads, circuits and design current | Baseline closed |
| FL9–11 | Surface routes, CableRun, junctions and floor topology | Baseline closed |
| FL12–13 | Dependency recalculation, protection requirements and normative catalog | Baseline closed |
| FL14 | Manufacturer catalogs, strict matching and preserved SKU selections | Baseline closed |
| FL15 | Generate panel structure from consumption groups; incoming protection, phase/reserve proposal | Baseline closed |
| FL16 | Enclosure and DIN-row layout, terminals/ducts/zones, module/mm capacity checks | Next |
| FL17 | Traceable BOM by project/floor/room/system and manufacturer mapping | Planned |
| FL18 | Versioned price books and labor/material estimates | Planned |
| FL19 | Offline PDF reports: drawings, schedules, BOM/estimate and engineering evidence | Planned |
| FL20 | Offline installation, deviations/as-built, tests and commissioning evidence | Planned |

## Next vertical acceptance: FL16

The editor reports module/mm overflow and represents the exact physical row arrangement of a generated panel.
Recommended enclosure width, height and depth must account for device dimensions, DIN rails, terminals, cable ducts, clearances and reserved space.
FL15 already supplies preliminary occupied/spare/total module capacity. This is not a physical enclosure dimension.
Normative requirements, manufacturer selection and physical placement remain separate concerns.

## ELV extension track

The [ELV delivery plan](elv-delivery-plan.md) is the active product roadmap. Historical requirements from `docs/elv-engineering-systems-spec` were incorporated into the accepted ELV1/ELV2 implementation and retained in Git history; that branch is no longer an active delivery baseline.

| Stage | Outcome | Status |
|---|---|---|
| ELV0 | Systems, sixteen family editions, shared device participation | Baseline closed |
| ELV1 | Ports, connections, topology, passive mappings and assemblies | CLOSED / ACCEPTED |
| ELV2 | Canonical discipline profiles, versioned catalogs, placement and explicit adoption | CLOSED / ACCEPTED |
| ELV3 | Cable resources, allocation/termination, cable-run traversal, reusable routing/carriers/pathways and physical compatibility | FINAL SPEC HARDENED / READY FOR EXECUTION — P1 NEXT |
| ELV4 | Power, PoE, PSU, UPS, converters and backup graph | Planned |
| ELV5 | Versioned CCTV/LAN/ACS/fire calculations | Planned |
| ELV6 | Racks, cabinets, patching and physical capacity | Planned |
| ELV7 | Jurisdiction profiles, normative rule packs and findings | Planned |
| ELV8 | Manufacturer selection, snapshots, BOM and deliverables | Planned |

ELV3-P0 was reopened after a project-wide system-architecture audit found conflicts in the first closure. P0-R1 through P0-R10 remediated those conflicts. A later adversarial implementation review found seven remaining specification ambiguities; PRE-P1 hardening closed them and a final audit now authorizes P1.

The single execution entry point is `docs/product/elv3-authoritative-spec-index.md`.

Authoritative implementation documents:

- `docs/product/elv3-implementation-specification-v2.md`;
- `docs/product/elv3-pre-p1-final-hardening.md`;
- `docs/adr/ADR-029-elv3-reusable-route-traversal.md`;
- `docs/adr/ADR-030-project-design-revision-identity.md`;
- `docs/audit/elv3-implementation-spec-readiness-audit.md`.

The first `docs/product/elv3-implementation-specification.md` is SUPERSEDED and must not be implemented.

The accepted ELV3 physical direction is:

```text
EngineeringConnection
  -> CableAllocation
      -> CableResourceSelection
      -> CableTerminationMapping[]
  -> Cable
      -> exact CableDefinitionRef
  -> one active CableRun per ProjectDesignRevision
  -> ordered CableRunTraversal[]
  -> existing/evolved reusable CableRouteSegment geometry
  -> optional PhysicalCarrier/compartment
  -> sealed PathwayContext host
```

Frozen clarifications before execution:

```text
CableDefinition provenance
  = catalogId + catalogVersion + definitionCode + contentHash
  using existing ELV2 EngineeringReferenceCatalog governance

CableAllocation lifecycle
  = strict DRAFT -> RESERVED -> ACTIVE -> RELEASED -> ARCHIVED

one continuous EngineeringConnection
  = at most one RESERVED/ACTIVE physical Cable in ELV3 P1-P9

routing
  = one existing/evolved CableRoute graph; no second ELV route graph

design revision identity
  = ProjectDesignRevision.id, never Projects.revision

PathwayContext
  = sealed Room/Floor/SurfaceVoid/Vertical/Project host model

P5 profiles
  = exact ELV2 PhysicalCompatibilityProfile editions

P6 segregation
  = factual evidence; ELV7 owns jurisdictional thresholds/compliance
```

Legacy electrical routing remains valid through coexistence/adoption semantics; physical Cable identity is never invented from `ElectricalCircuit` alone.

ELV3 implementation sequence is fixed as:

```text
P1 Cable identity / exact ELV2 CableDefinitionRef
P2 Allocation / resources / A-B terminations
P3 ProjectDesignRevision / CableRun / traversal / legacy coexistence
P4 sealed PathwayContext / PhysicalCarrier
P5 Technical physical compatibility
P6 Common physical evidence/calculations
P7 Engineer workflow
P8 Restart / rollback / idempotency verticals
P9 Hard audit / exact-SHA closure
```

Every phase closes on its own exact branch SHA before the next phase begins.

All four discipline fixtures plus a fiber fixture remain required throughout the track. National rule packs require verified sources and provenance. FL16 and ELV6 share enclosure infrastructure; ELV8 reuses electrical BOM/reporting foundations.

## Parallel baseline extensions

- shared room placement transforms, measured floor geometry, inter-room segments and risers;
- complete verified regulatory datasets by jurisdiction and edition, plus additional protection roles/criteria;
- sourced manufacturer datasets and vendor import adapters; no fabricated SKU specifications;
- device-port binding, physical channel fill/capacity and fuller cable/protection coordination;
- complete decision history, broader discipline support and larger-project rendering/performance.

These extensions have separate acceptance criteria. Baseline closure does not claim that all future domain capabilities are complete.

## Validation at FL15

Engineering implementation gate: `af08e7bba4094bd96b5650fafc175cc7e2deddaf`.
58 mobile tests and 102 pure-Dart core tests; format, Drift generation and analyzers passed.
Final branch-head commits are checked by the same CI workflow.
FL15 baseline: one generated panel per floor, common explicit outgoing protection conditions and preserved proposals; detailed boundaries are in the delivery plan.
