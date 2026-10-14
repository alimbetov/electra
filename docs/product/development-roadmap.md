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
| ELV3 | Cable resources, allocation/termination, cable-run traversal, reusable routing/carriers/pathways and physical compatibility | CODE-LEVEL SPEC READY / DUAL-REVIEW PASS / P1 CODE AUTHORIZED |
| ELV4 | Power, PoE, PSU, UPS, converters and backup graph | Planned |
| ELV5 | Versioned CCTV/LAN/ACS/fire calculations | Planned |
| ELV6 | Racks, cabinets, patching and physical capacity | Planned |
| ELV7 | Jurisdiction profiles, normative rule packs and findings | Planned |
| ELV8 | Manufacturer selection, snapshots, BOM and deliverables | Planned |

ELV3-P0 is architecturally remediated and accepted. PRE-P1 and R2 hardening closed successive implementation ambiguities. A two-role review validated both project-wide architecture consistency and command/process-flow consistency. The specification is now additionally translated into code-level contracts tied to the actual repository layers, Dart type boundaries, Drift schema ownership, transaction shapes, test locations and exact-SHA gates.

Architecture/process execution authority:

- `docs/product/elv3-authoritative-spec-index.md`;
- `docs/product/elv3-dual-review-process-hardening.md`;
- `docs/product/elv3-r2-execution-clarifications.md`;
- `docs/product/elv3-r2-final-readiness-remediation.md`;
- `docs/product/elv3-implementation-specification-v2.md`.

Code implementation entry point:

- `docs/product/elv3-code-implementation-index.md`;
- `docs/product/elv3-code-contract-p1-p3.md`;
- `docs/product/elv3-code-contract-p4-p6.md`;
- `docs/product/elv3-code-contract-p7-p9.md`.

Latest readiness evidence:

- `docs/audit/elv3-macro-architecture-consistency-audit.md`;
- `docs/audit/elv3-process-flow-consistency-audit.md`;
- `docs/audit/elv3-dual-review-reconciliation-audit.md`;
- `docs/audit/elv3-code-level-readiness-audit.md`.

Older readiness audits remain historical evidence but are not the latest authorization source.

The accepted ELV3 physical direction is:

```text
EngineeringConnection
  -> CableAllocation
      -> immutable resource-selection evidence
      -> temporary RESERVED/ACTIVE resource claims
      -> CableTerminationMapping[]
  -> Cable
      -> exact CableDefinitionRef
  -> one active CanonicalCableRun per ProjectDesignRevision
  -> ordered CableRunTraversal[]
  -> existing/evolved reusable CableRouteSegment geometry
  -> zero-length RouteHandoff where route graphs meet
  -> optional PhysicalCarrier/compartment
  -> sealed PathwayContext host
```

Code-layer structure is frozen as:

```text
engineering_core
  -> pure domain/value objects/validators/calculations

apps/mobile/lib/application
  -> commands/services/repository ports/workspace state

apps/mobile/lib/data/repositories
  -> Drift adapters/transactions/error translation

app_database.dart
  -> canonical tables/indexes/migrations

presentation
  -> command dispatch/rendering only
```

Canonical code/persistence groups include:

```text
P1  ElvCables + CommandExecutionRecords
P2  CableAllocations + immutable selection evidence + temporary claims + terminations
P3  ProjectDesignRevisions + frozen snapshots + CanonicalCableRuns + traversals + handoffs + bend evidence
P4  PathwayContexts + PhysicalCarriers + compartments
P5  exact project physical compatibility profile set/refs
P6  revision-scoped derived calculation/evidence keys
P7  one Physical Routing workspace
P8  deterministic failure probes/restart verticals
P9  implementation inventory + command-contract matrix + architecture-vs-code audit
```

Additional frozen implementation rules:

```text
new WORKING revision
  = deterministic materialization from verified frozen snapshot

physical writes after P3
  = require exactly one WORKING ProjectDesignRevision

RerouteCableRun
  = traversal-chain change only

EditReusableRouteGeometry
  = separate shared-infrastructure command + impact fingerprint

shared carrier/pathway mutation
  = impact-preview/fan-out discipline

CableDefinitionRef
  = immutable after resource-selection evidence/canonical run history exists

termination replacement
  = complete set-atomic replacement

command idempotency
  = persisted (projectId, commandId) + canonical payload hash + logical result

errors
  = typed/deterministic; raw Drift/SQLite failures do not cross application boundary

undo/redo
  = reversible command history only; freeze/revision/history operations move forward
```

Legacy electrical routing remains valid through coexistence/adoption semantics; physical Cable identity is never invented from `ElectricalCircuit` alone.

ELV3 implementation sequence remains fixed:

```text
P1 Cable identity / exact ELV2 CableDefinitionRef
  ↓ exact-SHA
P2 Allocation / resource selections + atomic claims / A-B terminations
  ↓ exact-SHA
P3 ProjectDesignRevision / frozen snapshot / deterministic revision fork / CanonicalCableRun / traversal / handoff / legacy coexistence
  ↓ exact-SHA
P4 sealed PathwayContext / PhysicalCarrier / compartments
  ↓ exact-SHA
P5 exact technical physical compatibility profile set / findings
  ↓ exact-SHA
P6 revision-scoped reproducible physical evidence/calculations
  ↓ exact-SHA
P7 Engineer Physical Routing workspace
  ↓ exact-SHA
P8 Restart / rollback / failure injection / persisted idempotency verticals
  ↓ exact-SHA
P9 Architecture-vs-code hard audit / command-matrix audit / final exact-SHA closure
```

Every P1-P8 phase must maintain its command-contract matrix with inputs, expected revisions, state, read/write sets, validations, transition, invalidation keys, idempotency, rollback postcondition, undo class, restart assertion, error codes and implementation/test locations. P9 audits that matrix against code.

P1 code implementation is authorized. P2 may begin only after P1 closes on an exact branch SHA with required green CI evidence; the same sequencing rule applies through P9.

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