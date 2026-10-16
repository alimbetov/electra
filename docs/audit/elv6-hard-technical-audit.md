# ELV6 — hard technical audit and design remediation

Date: 2026-10-16  
Branch: `feat/flutter-elv6-enclosure-layout-design`  
Audit target before remediation: `f5cc382942225d340b54461f37a9efd8d280f814`  
Latest design upstream merged into branch: ELV5 `ed7db01adb27ff184b0b8c91a710082fb9eafb9a`.

Status: **DESIGN REMEDIATION IN PROGRESS / RUNTIME NOT STARTED**.

The review was performed as a combined constructability, electrical-engineering, data-ownership, deterministic-computation and offline-runtime audit. The goal is not to maximize the number of fields. The goal is to make it impossible for runtime implementation to hide an unsupported engineering assumption behind a green UI card.

## Audit lenses

1. **Constructability** — can a panel/rack actually be assembled, wired, serviced and modified from the data model?
2. **Electrical engineer workflow** — DIN/U occupation, terminals, cable entries, bend space, batteries, PE/bonding basis, reserve, thermal preparation.
3. **Mechanical reality** — sub-millimetre interfaces, body/protrusion/service envelopes, depth, mass, support load, CoG, door sweep.
4. **System architecture** — one owner, immutable identities, revision-scoped state, no duplicated upstream facts.
5. **Runtime correctness** — strict wire codecs, replay-first mutation, CAS, rollback, restart and freeze/create-next.
6. **Determinism** — exact geometry, canonical hashes, stable findings and solver tie-breaks.
7. **Stage separation** — intrinsic physical fit in ELV6, normative compliance in ELV7, commercial product selection in ELV8.

## External engineering references used as design boundary checks

These references inform the shape of the data/evidence model. They are **not** hardcoded ELV6 compliance rules:

- IEC 61439-1:2020 — low-voltage switchgear/controlgear assembly general construction/verification framework;
- IEC TR 60890:2022 — temperature-rise calculation method and the physical/thermal input categories it needs;
- IEC 60297-3-100:2008 — 482.6 mm (19 in) mechanical structure basic dimensions;
- IEC 60529 consolidated edition — enclosure IP classification concept.

ELV7 owns project/jurisdiction applicability and compliance claims.

---

## Findings

### ELV6-AUD-01 — BLOCKER: panel runtime ownership was asserted without runtime evidence

**Observed:** the initial authoritative index called the panel-layout model an accepted physical source of truth. Repository evidence proves `PanelAssembly`, `DinRail`, `PanelModulePlacement`, ducts/zones as domain classes and ADR-019 as accepted design, but the audited search did not prove a revision-scoped Drift owner/public writer/history/freeze chain for these objects.

**Risk:** ELV6 could either create shadow tables or call nonexistent “existing canonical commands”. Both paths produce architecture by assumption.

**Resolution:** distinguish semantic baseline from runtime capability. P0 records independent states `semanticModelOnly / persisted / publicWriter / revisionIntegrated / qualified`. If persistence/writer is absent, ELV6 promotes the existing semantics into the first revision-scoped runtime owner. If an accepted writer is discovered, it is adapted/reused.

**Required proof:** path-level source/test evidence for every claimed owner/writer capability; no statement “already accepted runtime owner” without it.

Status: `SPEC_RESOLVED / RUNTIME_OPEN`.

### ELV6-AUD-02 — HIGH: ELV6 pinned an obsolete ELV5 design baseline

**Observed:** ELV6 pinned `a20ae91...`; ELV5 subsequently added its exact code-level runtime contract, closed 16-command registry, canonical examples and CI gates through `ed7db01...`.

**Risk:** ELV6 could build command/status/publication semantics on an old upstream contract.

**Resolution:** merge current ELV5 design head into ELV6 with a real two-parent merge commit; pin ELV6 design docs to `ed7db01...` until a newer explicitly audited upstream is adopted.

Status: `RESOLVED_BY_BASELINE_MERGE`.

### ELV6-AUD-03 — HIGH: binary `double` was treated as future canonical layout geometry

**Observed:** legacy `PanelAssembly` uses `double` dimensions while project persisted floor geometry already has integer-mm primitives. Rack and enclosure mechanics also require sub-mm values.

**Risk:** either precision loss from integer mm or non-canonical floating hashes/tolerance ambiguity from double.

**Resolution:** new persisted ELV6 geometry uses integer micrometres. Integer project-mm converts exactly. Legacy doubles are compatibility input only, decoded under a versioned decimal-normalization/tolerance contract and never binary-hashed.

Status: `SPEC_RESOLVED / RUNTIME_OPEN`.

### ELV6-AUD-04 — HIGH: legacy zones and ducts cannot express their location

**Observed:** `PanelReservedZone` has width/height but no anchor; `PanelCableDuct` has width/length/orientation but no position.

**Risk:** ADR-019 asks for forbidden-zone and duct-aware placement, but runtime geometry cannot prove collision with an unlocated rectangle.

**Resolution:** positioned 3D layout zones/duct bodies are required. Legacy size-only objects import as `UNLOCATED_LEGACY_ZONE` and cannot contribute to a geometry PASS until anchored.

Status: `SPEC_RESOLVED / RUNTIME_OPEN`.

### ELV6-AUD-05 — HIGH: placement identity is too weak for revision/history/replay

**Observed:** legacy `PanelModulePlacement` has `componentDefinitionId`, position and width but no placement ID, design revision, logical ID, row revision or immutable subject fingerprint.

**Risk:** move/undo/remap/concurrency cannot identify “the same physical placement” robustly.

**Resolution:** every runtime placement has stable revision-local ID + cross-revision logical ID + typed subject ref + installation role + row revision + source proposal ID + exact host/surface identity.

Status: `SPEC_RESOLVED / RUNTIME_OPEN`.

### ELV6-AUD-06 — HIGH: 2D front elevation alone is insufficient

**Observed:** initial spec discussed footprint + depth but did not freeze a full deterministic occupancy model.

**Risk:** front view can pass while rear connector, shelf, door device, battery or opposing front/rear device physically collides.

**Resolution:** host-local 3D orthogonal frame and half-open AABB occupancy are canonical V1 geometry. Front/rear/side views are projections, not separate truth.

Status: `SPEC_RESOLVED / RUNTIME_OPEN`.

### ELV6-AUD-07 — HIGH: service/removal/connector access was under-modelled

**Observed:** initial spec named service envelope, but no typed subject physical definition separated body, connector protrusion, service and removal volumes.

**Risk:** a design is geometrically packed but impossible to terminate, unplug, remove or maintain.

**Resolution:** body, connector protrusions, service envelopes, removal envelopes and airflow keepouts are separate exact physical features and independent result dimensions.

Status: `SPEC_RESOLVED / RUNTIME_OPEN`.

### ELV6-AUD-08 — HIGH: rack U fit could hide rail-depth incompatibility

**Observed:** initial rack model focused on U span and rough depth.

**Risk:** a server/device fits in U count but cannot mount to the rail depth/interface or collides at rear/front.

**Resolution:** rack profile, front/rear/four-post mounting mode, rail depth range, equipment mounting depth and connector protrusions are first-class. `LAY-05` U occupancy and `LAY-06` rail/depth fit are separate.

Status: `SPEC_RESOLVED / RUNTIME_OPEN`.

### ELV6-AUD-09 — HIGH: cable entry was not constructability-complete

**Observed:** cable entry was an anchor/capacity concept; bend radius, approach direction, connector protrusion, gland/knockout physical occupancy and strain relief were not complete contracts.

**Risk:** a cabinet has a theoretical opening but the cable cannot enter/turn/terminate without impossible curvature or collision.

**Resolution:** exact entry geometry + exclusive cable-end assignment + approach direction + termination target + adopted technical bend/strain envelope. Missing bend fact is unresolved, never guessed.

Status: `SPEC_RESOLVED / RUNTIME_OPEN`.

### ELV6-AUD-10 — HIGH: internal wiring space and termination physical capacity were incomplete

**Observed:** initial design had cable ducts and patch anchors, but no explicit separation of physical termination positions, conductor bundle area basis and logical capacity.

**Risk:** LAN/ACS/Fire calculations pass while the cabinet cannot be wired physically.

**Resolution:** `LAY-13` wiring-duct capacity basis and `LAY-14` terminal/patch physical capacity. ELV6 measures physical used/free/reserved basis. Normative fill factors remain ELV7.

Status: `SPEC_RESOLVED / RUNTIME_OPEN`.

### ELV6-AUD-11 — HIGH: mass/support/CoG engineering was missing

**Observed:** initial spec mentioned weight comparison but did not make host/shelf loading and aggregate CoG first-class.

**Risk:** a rack passes RU/depth but overloads a shelf or becomes mechanically problematic; downstream anchorage/stability checks lack evidence.

**Resolution:** integer-gram masses, exact gram·µm moments, support capability margin and physical CoG basis. Seismic/anti-tip compliance remains downstream.

Status: `SPEC_RESOLVED / RUNTIME_OPEN`.

### ELV6-AUD-12 — HIGH: thermal design was too easy to postpone

**Observed:** ventilation envelope existed as a collision concept, but dense panels/racks need a reproducible thermal-input basis before later normative verification.

**Risk:** layout fills all cooling paths and loses heat-source data; later verification cannot reproduce inputs.

**Resolution:** `LAY-18` ventilation/airflow physical envelope and `LAY-19` thermal-input basis capture openings, fans, airflow direction, heat-loss facts, surface/partition basis and spatial source distribution. No universal temperature-rise formula is silently embedded.

Status: `SPEC_RESOLVED / RUNTIME_OPEN`.

### ELV6-AUD-13 — HIGH: status model collapsed engineering and execution states

**Observed:** initial ELV6 prose used PASS/FAIL/UNRESOLVED/NOT_APPLICABLE but did not preserve freshness, completion and execution independently.

**Risk:** stale, blocked, partial and runtime failure are displayed/handled as equivalent.

**Resolution:** ELV6 reuses the proven four-axis model: freshness CURRENT/STALE, completion COMPLETE/PARTIAL/BLOCKED, assessment PASS/FAIL/UNRESOLVED/NOT_ASSESSED, execution SUCCEEDED/FAILED.

Status: `SPEC_RESOLVED / RUNTIME_OPEN`.

### ELV6-AUD-14 — HIGH: public command surface was conceptual, not executable

**Observed:** Create/Update/Place/etc. names were examples without schema/version/exact payload keys or codec-totality rule.

**Risk:** UI/application/runtime teams invent incompatible APIs; impact data can leak from client into trusted mutation logic.

**Resolution:** strict `electra.elv6-layout-command.v1`, exact ten-field envelope, exactly 21 initial operations, code-owned codecs and server-resolved impact. ELV4 freeze/create-next remains the only public revision boundary.

Status: `SPEC_RESOLVED / RUNTIME_OPEN`.

### ELV6-AUD-15 — HIGH: solver priorities were not mathematically closed

**Observed:** initial auto-layout listed priorities but did not define whether they are hard constraints, weights or tie-breaks.

**Risk:** implementation chooses arbitrary floating weights; solver output changes with iteration order or tuning.

**Resolution:** hard feasibility is non-negotiable; optimization uses an explicit lexicographic score vector and stable-ID tie-break. Same canonical input/version must produce byte-identical proposal/hash.

Status: `SPEC_RESOLVED / RUNTIME_OPEN`.

### ELV6-AUD-16 — MEDIUM: physical segregation facts and normative minimums were mixed conceptually

**Observed:** segregation is important to an electrician but hardcoding distances in ELV6 would duplicate ELV7.

**Resolution:** ELV6 exports observed intersections/shortest-distance geometry and provenance. ELV7 applies required minimums from the selected normative profile.

Status: `SPEC_RESOLVED / RUNTIME_OPEN`.

### ELV6-AUD-17 — MEDIUM: protective bonding physical evidence was absent

**Observed:** rack/panel body, door, mounting plate, rail and PE bar physical bonding points are useful constructability evidence even when sizing/rules belong elsewhere.

**Resolution:** ELV6 records physical bond points/declared links; does not claim protective-conductor compliance.

Status: `SPEC_RESOLVED / RUNTIME_OPEN`.

### ELV6-AUD-18 — HIGH: acceptance matrix was prose-only

**Observed:** 16 broad acceptance bullets did not force one positive/negative/blocked oracle per process, exact command-codec coverage or machine validation.

**Resolution:** closed 24-process and 21-command registries, independent CI design guards, and P8 requirement for public-command/file-SQLite qualification, migration/restart/replay/rollback/races/freeze/create-next/hash evidence.

Status: `SPEC_RESOLVED / RUNTIME_OPEN`.

---

## Engineering verdict after remediation

The original ELV6 direction was sound but **not implementation-safe**. Its strongest decision — do not duplicate upstream engineering — was correct. Its weakest assumption was treating an ADR/domain class as if that already proved a revisioned runtime source of truth.

The hardened design now requires:

```text
semantic baseline
    + exact ownership proof
    + exact fixed-point geometry
    + constructability envelopes
    + machine process registry
    + strict command registry
    + deterministic solver
    + revision/replay/publication protocol
    + executable qualification
```

Only after P0 produces the runtime ownership matrix and accepted upstream runtime SHA may source implementation begin. Design completion alone is not runtime acceptance.
