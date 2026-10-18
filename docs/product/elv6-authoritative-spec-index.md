# Electra — ELV6 Authoritative Design Index

Status: **DESIGN HARDENED / RUNTIME NOT STARTED**  
Branch: `feat/flutter-elv6-enclosure-layout-design`  
Design upstream: `feat/flutter-elv5-power-topology-design`  
Pinned upstream design SHA: `ed7db01adb27ff184b0b8c91a710082fb9eafb9a`

ELV6 owns **constructible enclosure, cabinet, rack and internal mounting layout evidence**. It turns exact upstream equipment, cable-end, power/battery and discipline requirements into revisioned physical arrangement, intrinsic-fit evidence and deterministic engineer-assisted layout proposals.

It does not recompute ELV3 routing, ELV4 power, ELV5 discipline algorithms, ELV7 jurisdictional compliance or ELV8 manufacturer/commercial selection.

## Critical baseline correction

`PanelAssembly`, `PanelEnclosureGeometry`, `PanelMountingSection`, `DinRail`, `PanelModulePlacement`, terminal rails, cable ducts and reserved zones plus ADR-019 are an accepted **semantic/domain baseline**. They are not automatically treated as a qualified revisioned runtime source of truth merely because the classes/ADR exist.

P0 must separately prove persistence, public writer, revision identity, replay/history, freeze/create-next and concurrency integration. At the audited baseline, the domain classes do not themselves provide those guarantees.

If no accepted persisted panel-layout writer exists, ELV6 promotes the existing `PanelAssembly` semantics into the first revision-scoped runtime owner. It must not invent a parallel panel/DIN identity hierarchy. If an accepted writer is found, ELV6 adapts/reuses it instead.

## Entry documents

1. [ELV6 design specification](elv6-enclosure-layout-design-specification.md).
2. [ELV6 P0–P9 delivery plan](elv6-p0-p9-delivery-plan.md) — 80 stable requirements.
3. [Implementation design index](elv6-implementation/README.md).
4. [Code-level runtime contract](elv6-implementation/code-level-runtime-contract.md).
5. [Placement and collection mutation safety contract](elv6-implementation/mutation-safety-contract.md).
6. [Normative safety evidence contract](elv6-implementation/normative-safety-evidence-contract.md) — exact enclosure-integrity, clearance/creepage, hazardous-access, partition, environment/profile and historical-evidence projections required for downstream compliance evaluation.
7. [Safety standards readiness registry](elv6-implementation/safety-standards-registry.json) — machine-readable IEC/KZ/EU/discipline applicability and evidence-gap registry; design/readiness only, never a compliance ruleset.
8. [24-process machine registry](elv6-implementation/process-registry.json).
9. [21-command machine registry](elv6-implementation/command-registry.json).
10. [Canonical command examples](elv6-implementation/command-examples.json) — all 21 operations.
11. [Qualification manifest](elv6-implementation/qualification-manifest.json) — 72 POS/NEG/BLOCKED process oracles.
12. [Hard technical audit](../audit/elv6-hard-technical-audit.md) — initial 18 findings/remediations.
13. [Final architecture hardening](../audit/elv6-final-architecture-hardening.md) — findings 19–20.
14. [Normative safety readiness audit](../audit/elv6-normative-safety-readiness-audit.md) — standards-driven readiness analysis and eight mandatory safety-evidence gaps.
15. [ADR-019 physical panel layout](../adr/ADR-019-physical-panel-layout-editor.md) and `packages/engineering_core/lib/src/panel_assembly.dart` as semantic baseline inputs.
16. ELV5 authoritative/code-level/command contracts at the pinned upstream SHA.

## Authority hierarchy

When ELV6 artifacts disagree, use this order:

1. accepted ELV1–ELV5 runtime ownership/revision contracts and any P0-proven existing canonical writer;
2. this authoritative index;
3. `elv6-implementation/code-level-runtime-contract.md`, `mutation-safety-contract.md` and `normative-safety-evidence-contract.md`;
4. machine process/command registries, safety standards readiness registry and canonical command examples;
5. qualification manifest for required oracle identities/statuses;
6. ELV6 design specification and P0–P9 plan;
7. ADR-019 as semantic baseline and older architecture/product notes.

No package-local document may weaken replay/CAS, exact geometry, mutation safety, normative evidence provenance, claim boundaries or canonical ownership.

## Stage boundary

```text
ELV2 exact immutable technical definitions
    ↓
ELV3 realized cable/path/end facts
    ↓
ELV4 source/UPS/battery/electrical evidence
    ↓
ELV5 CCTV/LAN/ACS/Fire discipline calculations and demand basis
    ↓
ELV6 physical host/layout/constructability + exact safety evidence projections
    ↓
ELV7 normative/jurisdictional validation
    ↓
ELV8 manufacturer selection, BOM and deliverables
```

ELV6 may fail intrinsic physical impossibility: overlap, out-of-bounds, incompatible mounting interface, impossible rail depth, blocked service/removal/bend envelope, adopted support-load overload or explicit physical capacity overflow.

ELV6 must not infer normative compliance from intrinsic fit. Required clearance, creepage, accessible-part protection, segregation, temperature-rise, IP/IK, protective-bonding and similar rule claims are evaluated by ELV7 from exact ELV6 evidence unless the condition is an intrinsic adopted product capability rather than a normative requirement.

ELV6 nevertheless MUST capture enough exact evidence for ELV7 to make those decisions. “ELV7 owns compliance” is not permission to omit safety-relevant geometry/provenance.

## Safety evidence boundary

The following are mandatory cross-cutting evidence projections, even though they do not silently add new `LAY-*` process codes:

```text
enclosure integrity/openings/modifications/seals/glands
shortest air-clearance measurements
creepage surface-path measurements
hazardous/live region + barrier/access-state evidence
partition/form-of-separation geometry
insulation/material/environment context refs
rack/enclosure mechanical/environmental capability provenance
national/profile edition/effectivity provenance
freeze/replay hashes for every safety projection
```

If P0/P1 proves a projection requires independent execution/publication semantics, the 24-process registry must be explicitly reopened and all registry/qualification/CI counts changed together. A hidden “LAY-25 in a helper” is prohibited.

The KZ normative profile must distinguish at minimum `CURRENT_NATIONAL`, `ADOPTED_NOT_YET_INTRODUCED`, `WITHDRAWN`, `INTERNATIONAL_REFERENCE_ONLY` and `PROJECT_EXPLICIT_OVERRIDE`. A newer IEC/GOST edition discovered in a catalogue is not automatically effective for an existing Kazakhstan project.

## Non-negotiable technical decisions

- One active canonical writer per physical fact per design revision.
- `PanelAssembly` identity/terminology is preserved; runtime persistence is promoted only if P0 proves it is currently absent.
- New persisted mechanical geometry uses **signed integer micrometre fixed-point**, not binary `double`.
- Project integer-mm geometry converts exactly; legacy double dimensions are compatibility imports only.
- Canonical V1 layout uses host-local orthogonal 3D frames and half-open occupied volumes.
- Rack U/DIN intervals are discrete and coexist with exact physical envelopes; neither may hide a failure in the other.
- Body, connector protrusion, service, removal and airflow envelopes are separate physical facts.
- Door sweep, cable entry, bend/strain-relief space, internal wiring ducts, physical terminations, batteries, support load, mass/CoG, airflow/thermal inputs, observed segregation and bonding evidence are first-class.
- Enclosure openings/modifications, barrier/access states, conductive/live regions, creepage surfaces/paths and partitions are first-class safety evidence inputs/projections.
- Missing technical evidence yields BLOCKED/PARTIAL/UNRESOLVED, never guessed geometry or optimistic PASS.
- Evaluation preserves freshness, completion, assessment and execution independently.
- Auto-layout is deterministic proposal-only; hard constraints are never traded for a weighted score.
- Locked placements do not move until explicitly unlocked.
- Exact public mutation surface is the 21-operation `electra.elv6-layout-command.v1` registry.
- PLACE/MOVE wire payload carries only strict `placementSpec` intent; body envelopes, rack/DIN spans, service/protrusion envelopes and proposal provenance are server-derived.
- `sourceProposalId` is backend-owned and may be written only by actual proposal acceptance.
- Referenced mounting surfaces/cable entries cannot be removed by replacement commands; `ELV6_REFERENCED_MEMBER_REMOVAL` fails before write and no `force` bypass exists.
- Server resolves impact/dependencies; wire clients cannot author trusted invalidation sets.
- Replay precedes mutable preconditions; canonical state + invalidation + history + ledger/outbox commit atomically.
- Calculation/proposal/evidence execution follows capture → pure kernel/projection → guarded publication.
- ELV4 revision commands remain the only public freeze/create-next boundary.
- Historical snapshots return `ELV6_NOT_CAPTURED` when appropriate, never empty-valid/latest fallback.
- Safety projections participate in the same immutable freeze/replay and stale-publication guards as layout evidence.
- ELV6 does not reserve a migration number. This inspected design branch has schema 23; merged main has schema 24. Runtime P0 must reconcile the actual accepted source/migration path before enabling new writers.

## Closed design registries

Initial runtime has exactly **24 layout processes** `LAY-01…LAY-24` and exactly **21 ELV6 public command operations**. Unknown custom executable processes/operations fail closed. Data-driven technical profiles may supply parameters/evidence, never arbitrary executable formulas/scripts.

Each process has three required design-to-runtime oracle identities — POS, NEG and BLOCKED — for a total of **72 process oracles**. A NEG oracle is allowed to be `UNRESOLVED` for a basis/measurement process when absence of knowledge is the engineering truth; it must not be forced into FAIL merely to color a test red.

The complete original design audit contains **20 constructability/system findings**. The later normative safety readiness audit adds eight `NRG-*` safety-evidence gaps without renumbering the original `ELV6-AUD-*` set or changing its CI count.

## CI design gates

Before Flutter setup, the shared workflow verifies independently:

```text
ELV6 specification/process/80-requirement/20-finding guard
ELV6 safety standards/profile + mandatory evidence-readiness guard
ELV6 exact 21-command registry and server-derived-placement guard
ELV6 21 canonical command examples + 72-oracle qualification guard
```

A design guard proves internal consistency only. It never marks runtime requirements implemented or a project standards-compliant.

## Runtime entry gate

Runtime P0 starts only after all of the following are pinned at one source baseline:

- accepted upstream runtime/design SHA distinction;
- current Drift schema and supported migration origins;
- panel semantic/persistence/writer ownership matrix;
- revision/replay/history/UoW/freeze/create-next capabilities;
- exact upstream ELV3/ELV4/ELV5 physical evidence contracts;
- canonical geometry normalization/tolerance for legacy imports;
- one-owner matrix for every host/surface/placement/zone/entry/assignment fact;
- one-owner matrix for conductive/live regions, barriers/covers/partitions, enclosure modifications/openings, insulating surfaces/material refs and safety environment context;
- exact KZ/IEC/EU/discipline normative profile provenance model with national edition/effectivity state.

If ELV5 runtime is not yet accepted, ELV6 implementation remains blocked while ELV6 design may continue against the pinned ELV5 design contracts.

## Acceptance boundary

Runtime closure requires public-command/file-SQLite qualification of all 24 processes and all 21 command codecs, migrations, restart, replay, rollback, concurrency races, deterministic solver output, mutation-safety cases, mandatory normative safety evidence projections, freeze/create-next history and stable ELV7/ELV8 projections at one exact source SHA.

All ELV6 P0–P9 runtime packages remain `NOT_STARTED` until that evidence exists.


## Coordinated downstream contract

[ELV6–ELV8 integration agreement](elv-integration/README.md) is the shared
requirement/evidence, catalogue-adoption, owner-UoW, result-adapter and freeze/report
contract. It is replicated on the three stage branches with one agreement hash.
It does not grant runtime support or move product selection into ELV6.
