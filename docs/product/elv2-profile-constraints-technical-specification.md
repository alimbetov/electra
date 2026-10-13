# Electra — ELV2 Profile Constraints, Placement and Revision Adoption

Status: Draft 0.1 — implementation contract  
Implementation branch: `feat/flutter-elv2-profile-constraints`  
Related PR: #7  
Parent roadmap: `docs/product/elv-delivery-plan.md`  
Parent specification: `docs/product/elv-engineering-systems-specification.md`  
Scope: final vertical slice required to close ELV2 before ELV3

## 1. Purpose

This specification defines the remaining ELV2 work needed to turn canonical reference catalogs from passive dictionaries into enforceable engineering profiles that participate directly in placement, port instantiation and controlled catalog-edition migration.

The target vertical is:

```text
EngineeringReferenceCatalog
        │
        └── ComponentEngineeringProfile
                ├── characteristics
                ├── capabilities
                ├── ports
                ├── interfaces
                └── constraints
                     ├── mounting
                     ├── environment
                     └── topology
```

The editor workflow becomes:

```text
Editor palette
   ↓
choose discipline
   ↓
choose canonical profile
   ↓
show constraints BEFORE placement
   ↓
validate placement candidate
   ↓
place one physical component
   ↓
bind exact catalog/profile edition
   ↓
instantiate persisted ports
```

A later catalog edition must never mutate an existing project silently:

```text
Import candidate edition v2
   ↓
Preview impact against current project
   ├── affected components
   ├── affected persisted ports
   ├── affected connections
   ├── affected topology groups
   ├── placement violations
   └── removed/deprecated profiles
   ↓
engineer reviews consequences
   ↓
explicit adoption
   ↓
transactional revalidation / migration
```

This work closes ELV2. Cable definitions, cable allocation, CableRun and physical route compatibility remain ELV3 and are explicitly out of scope.

---

## 2. Engineering principles

The implementation MUST preserve the following rules.

1. **Canonical profile first.** Placement and connectivity are driven by a canonical `ComponentEngineeringProfile`, not a manufacturer SKU or display label.
2. **Constraints are engineering data.** Mounting, environment and topology constraints belong to the versioned profile and are not UI-only hints.
3. **Pre-placement validation.** The editor must expose relevant restrictions before committing geometry.
4. **One physical object.** A component participating in multiple engineering systems remains one placed geometry object.
5. **Exact edition provenance.** A binding preserves catalog id, catalog version, profile code and instantiated-port provenance.
6. **Immutable editions.** Imported catalog editions are immutable once identified by their edition identity.
7. **No silent latest-version adoption.** Importing v2 does not modify v1 bindings.
8. **Preview before mutation.** Project impact must be computed before adoption is permitted.
9. **Explainable incompatibility.** A rejected placement or adoption exposes the constraint/profile edition and affected objects.
10. **ELV1 graph remains authoritative.** Ports and connections are persisted graph objects; catalog profiles create and constrain them but do not replace them.
11. **No ELV3 leakage.** Mounting/environment constraints may describe whether a component can be installed in an environment, but cable/pathway/routing compatibility is not implemented here.

---

## 3. Scope

### 3.1 In scope

This delivery includes:

- integration of typed constraint profiles into `ComponentEngineeringProfile`;
- serialization/deserialization through `EngineeringReferenceCatalog` payloads;
- immutable snapshot preservation in `ComponentReferenceBinding`;
- mounting-surface constraints;
- mounting-method constraints;
- environmental constraints;
- topology-participation constraints;
- discipline-aware editor palette;
- canonical-profile selection before placement;
- pre-placement restriction display and validation;
- atomic placement + profile binding + port instantiation workflow;
- candidate catalog-edition comparison;
- project-specific impact preview;
- affected component/port/connection/topology-group resolution;
- placement revalidation against a candidate profile;
- explicit edition adoption workflow;
- backward-compatible reconstruction of earlier ELV2 snapshots;
- pure-domain, repository, persistence/restart and widget tests;
- four-discipline acceptance fixtures: CCTV, LAN, ACS, Fire.

### 3.2 Out of scope

The following MUST NOT be introduced in this work package:

- `CableDefinition`;
- cable manufacturer selection;
- `CableAllocation`;
- `CableRun` changes;
- route/pathway compatibility;
- tray/conduit fill;
- segregation rules between routed cables;
- bend-radius validation;
- PoE budget calculation;
- PSU/UPS/battery sizing;
- discipline calculation processes;
- full national normative rule packs;
- manufacturer-equipment BOM selection.

Those belong to ELV3–ELV8.

---

## 4. Canonical domain model

### 4.1 EngineeringReferenceCatalog

`EngineeringReferenceCatalog` remains the immutable edition aggregate.

Required conceptual structure:

```text
EngineeringReferenceCatalog
- id
- code
- version
- source
- jurisdiction?
- vocabulary
- profiles[]
```

Every `profiles[]` item MUST serialize the full canonical engineering contract required to reconstruct placement and port semantics deterministically.

### 4.2 ComponentEngineeringProfile

Target contract:

```text
ComponentEngineeringProfile
- code
- label
- discipline
- engineeringClass
- characteristics
- capabilities[]
- portTemplates[]
- portInterfaceCodes{}
- constraints
- deprecated
```

`constraints` MUST be part of the profile snapshot, not a separately mutable global lookup.

### 4.3 EngineeringProfileConstraints

Target structure:

```text
EngineeringProfileConstraints
├── mounting: MountingConstraintProfile
├── environment: EnvironmentConstraintProfile
└── topology: TopologyConstraintProfile
```

The contract must be independent from Flutter and Drift.

---

## 5. Mounting constraints

### 5.1 Installation surfaces

The model must support typed surfaces, initially including at least:

- wall;
- ceiling;
- floor;
- free-standing / equipment base where applicable;
- enclosure/rack internal placement where applicable.

The exact enum naming may follow current core conventions, but persisted values must be stable.

### 5.2 Mounting methods

Initial typed methods should cover at least:

- surface mounted;
- recessed/flush mounted;
- bracket mounted;
- pendant/suspended;
- pole mounted;
- rack mounted;
- DIN rail / internal enclosure mounting where relevant.

Not every profile needs every method. A camera, patch panel, reader and detector must be able to expose different allowed combinations.

### 5.3 MountingConstraintProfile

Minimum semantics:

```text
MountingConstraintProfile
- allowedSurfaces[]
- allowedMethods[]
- requiresEnclosure? / enclosureClass? when applicable
- notes/referenceCode? for explainability
```

Validation rules:

- lists must contain unique stable values;
- a newly published canonical profile cannot declare an empty allowed-surface set unless it is explicitly non-placeable;
- incompatible surface/method combinations must be representable without parsing labels;
- deprecated profiles remain readable;
- changing mounting constraints is classified as a placement-impacting revision.

---

## 6. Environmental constraints

### 6.1 Environment classes

The initial model must distinguish engineering environment from marketing descriptions. It should support at least the concepts needed to tell indoor, protected outdoor, exposed outdoor and technical/enclosure environments apart.

The core contract may use typed classes plus optional quantitative limits.

### 6.2 EnvironmentConstraintProfile

Minimum semantics:

```text
EnvironmentConstraintProfile
- allowedEnvironmentClasses[]
- minimumTemperatureC?
- maximumTemperatureC?
- minimumIpClass? or canonical protection reference?
- notes/referenceCode?
```

Quantities MUST be canonical engineering values, not localized text.

Validation rules:

- finite numeric values only;
- `minimumTemperatureC <= maximumTemperatureC`;
- duplicate environment classes are forbidden;
- a candidate environment outside the profile range produces a structured finding;
- changing environment constraints is classified as placement-impacting.

ELV2 does not implement a complete normative IP/IK engine. The profile only carries typed requirements needed for deterministic placement compatibility and later ELV7 validation.

---

## 7. Topology constraints

### 7.1 Purpose

Topology constraints express how a component profile may participate in the ELV1 logical graph. They do not define cable routes.

### 7.2 TopologyConstraintProfile

Minimum semantics:

```text
TopologyConstraintProfile
- allowedShapes[]
- participationRole
- branchingAllowed
- closedLoopRequired
- endpointAllowed
- intermediateNodeAllowed
- notes/referenceCode?
```

Where possible, topology roles should be typed and reusable instead of discipline-specific string flags.

### 7.3 Invariants

- `closedLoopRequired = true` is invalid unless an allowed topology shape supports loop semantics;
- a profile that can only be an endpoint cannot silently become an intermediate node;
- topology changes are classified as connection/topology impact;
- topology validation operates on explicit persisted ports/connections from ELV1;
- topology constraints may refine a system profile but cannot mutate an existing graph merely by being imported.

---

## 8. Catalog serialization and backward compatibility

### 8.1 New editions

All newly imported canonical profiles after this feature is enabled MUST carry a valid constraints object.

A newly imported profile with missing or invalid constraints MUST fail catalog validation before persistence.

### 8.2 Existing ELV2 snapshots

Previously persisted catalog editions and component bindings may not contain `constraints`.

They MUST remain readable and reproducible.

Backward compatibility must therefore use an explicit legacy representation, for example:

```text
constraintsState = LEGACY_UNSPECIFIED
```

or an equivalent typed model.

The implementation MUST NOT interpret missing historical constraints as silently equivalent to a newly authored unrestricted profile.

Required behavior for legacy profiles:

- existing bindings remain readable;
- existing ports/connections remain intact;
- reports/debug views can state that placement constraints were unspecified in that edition;
- a legacy profile cannot be adopted as a newly authored canonical edition without explicit normalization;
- importing a new complete edition enables normal revision comparison against the legacy snapshot.

No destructive database rewrite is required merely to add constraint fields if existing JSON snapshot columns already preserve catalog/profile payloads.

---

## 9. Placement context contract

Pre-placement validation requires an explicit engineering context independent from widgets.

Recommended contract:

```text
PlacementCandidateContext
- projectId
- roomId
- surfaceId
- installationSurface
- mountingMethod
- environmentClass
- ambientTemperatureC?
- enclosureContext?
```

The exact geometry identifiers may reuse existing geometry/kernel types.

The domain service must return a structured result:

```text
PlacementCompatibilityResult
- status: COMPATIBLE | WARNING | FORBIDDEN | UNRESOLVED
- profileCode
- catalogId
- catalogVersion
- findings[]
```

Each finding contains at minimum:

```text
PlacementFinding
- code
- severity
- dimension: MOUNTING | ENVIRONMENT | TOPOLOGY
- explanation
- expected/allowed value
- actual candidate value
- remediationHint?
```

No widget is allowed to duplicate these rules locally.

---

## 10. Editor palette requirements

### 10.1 Progressive engineering workflow

The editor palette must follow this order:

```text
1. Choose active EngineeringSystem / discipline
2. Show only relevant canonical profiles
3. Choose canonical profile
4. Inspect constraints and ports
5. Enter placement mode
6. Hover/select candidate surface/location
7. Evaluate placement compatibility
8. Commit placement only when policy allows
9. Bind exact profile edition
10. Instantiate persisted ports
```

This follows the product ergonomics rule that passive information should stay hidden until the active tool requires it.

### 10.2 Discipline filtering

At minimum:

- CCTV palette shows CCTV profiles;
- LAN palette shows LAN profiles;
- ACS palette shows ACS profiles;
- Fire palette shows Fire profiles.

Cross-discipline shared equipment can be shown only when its canonical profile explicitly supports the selected engineering context. No string-name heuristic is allowed.

### 10.3 Profile card

Before placement, the engineer must be able to inspect:

- canonical profile label and code;
- exact catalog/version;
- engineering class;
- capabilities;
- port templates/interfaces;
- allowed mounting surfaces;
- allowed mounting methods;
- environment restrictions;
- topology participation;
- lifecycle/deprecation state.

### 10.4 Placement feedback

Candidate geometry must expose state without opening a permanent information panel:

- compatible;
- warning;
- forbidden;
- unresolved.

The side panel can provide details on demand.

A forbidden placement cannot be committed unless the product explicitly introduces a future override mechanism with provenance. Such overrides are not part of this ELV2 slice.

---

## 11. Atomic placement, binding and port instantiation

The placement workflow must not leave partial engineering state.

Target transaction:

```text
validate project/system/profile/context
        ↓
create placed component geometry/domain instance
        ↓
create/confirm system membership
        ↓
create ComponentReferenceBinding snapshot
        ↓
instantiate persisted EngineeringPort instances
        ↓
commit
```

If any step fails, the transaction must roll back all changes created by the operation.

Invariants:

- no binding without a valid placed component;
- no profile binding to the wrong discipline system;
- no duplicate active binding for one component;
- no duplicate port identities;
- port instances retain exact template and interface provenance;
- retrying the same command must not create duplicate ports;
- manually authored conflicting ports must be explicitly resolved before binding;
- deprecation prevents new placement/binding but does not break existing snapshots.

---

## 12. Revision comparison model

### 12.1 ProfileRevisionImpact

The comparison engine must classify semantic changes rather than returning only raw JSON differences.

Minimum change kinds:

- discipline;
- engineering class;
- characteristics;
- capabilities;
- ports;
- interfaces;
- mounting constraints;
- environment constraints;
- topology constraints;
- lifecycle/deprecation.

Each change kind must declare impact dimensions:

```text
PLACEMENT
CONNECTIONS
TOPOLOGY
CALCULATION_INPUT_FUTURE
NONE/METADATA
```

For ELV2 closure, at minimum `affectsPlacement` and `affectsConnections` must be computable deterministically.

### 12.2 CatalogRevisionPreview

Comparing a candidate catalog edition to the project must resolve actual project objects.

Required output:

```text
CatalogRevisionPreview
- previousCatalogId/version
- candidateCatalogId/version
- addedProfileCodes[]
- removedProfileCodes[]
- changedProfiles[]
- affectedBindingCount
- bindingImpacts[]
- affectedPortIds[]
- affectedConnectionIds[]
- affectedTopologyGroupIds[]
- placementViolations[]
- unresolvedLegacyBindings[]
```

A binding impact includes:

```text
BindingRevisionImpact
- componentId
- componentName?
- roomName?
- currentProfileCode
- currentCatalogVersion
- candidateProfileCode/version
- profileImpact
- persistedPortIds[]
- affectedConnectionIds[]
- affectedTopologyGroupIds[]
- placementResult?
```

### 12.3 Removed profiles

If a bound profile is absent from the candidate edition:

- it must appear explicitly under `removedProfileCodes`;
- existing project state remains valid under its pinned old edition;
- automatic adoption is prohibited;
- the engineer must select a replacement profile explicitly before migration.

---

## 13. Placement revalidation during revision preview

The preview must not stop at port/connection differences.

For each affected bound component where placement context can be reconstructed, evaluate the current physical placement against the candidate profile.

Example:

```text
Candidate v2: CAMERA-DOME
mounting allowed: ceiling only

Project:
8 bindings using CAMERA-DOME
- 6 ceiling placements -> compatible
- 2 wall placements -> forbidden

Preview:
affected devices: 8
placement violations: 2
```

If required placement context cannot be reconstructed, return `UNRESOLVED`; do not assume compatibility.

---

## 14. Explicit adoption workflow

### 14.1 General rule

`importCatalog(v2)` only stores an immutable candidate edition. It MUST NOT mutate bindings.

Adoption is a separate command.

Recommended flow:

```text
import candidate edition
      ↓
compute preview
      ↓
review impacts
      ↓
select affected bindings / replacement mappings
      ↓
validate migration plan
      ↓
explicit adopt command
      ↓
transaction
      ↓
post-adoption revalidation
```

### 14.2 Adoption plan

Introduce an application-level contract equivalent to:

```text
CatalogEditionAdoptionPlan
- projectId
- sourceCatalogId/version
- targetCatalogId/version
- componentActions[]
```

Each component action is one of:

```text
KEEP_PINNED
ADOPT_SAME_PROFILE_CODE
ADOPT_REPLACEMENT_PROFILE
```

No implicit fallback to a similarly named profile is permitted.

### 14.3 Adoption safety

Before mutation, validate:

- candidate catalog is immutable and valid;
- target profile exists and is active;
- discipline/system membership remains compatible;
- current placement is compatible with target constraints;
- instantiated ports can be mapped safely;
- every connected port affected by a template/interface change is resolved explicitly;
- topology participation remains valid;
- removed profiles have explicit replacement or remain pinned.

### 14.4 Port identity policy

Port identity preservation follows this priority:

1. if a target template is semantically the same stable port, preserve the persisted port identity;
2. if the port is removed and unconnected, it may be retired explicitly;
3. if the port is removed or incompatible while connected, adoption is blocked until connection migration is resolved;
4. a newly introduced port receives a new persisted identity;
5. port code similarity alone is insufficient if interface semantics changed incompatibly.

This prevents project connections from being silently rewired by a catalog update.

---

## 15. Persistence requirements

The existing ELV2 snapshot approach should be retained unless implementation evidence proves a schema change is necessary.

Required persisted facts:

- complete catalog edition JSON, including constraints;
- complete component profile snapshot in binding;
- exact `catalogId`;
- exact `catalogVersion`;
- exact `profileCode`;
- exact persisted `portIds`;
- port template provenance;
- interface provenance;
- binding lifecycle/revision metadata.

Adoption MUST update binding state transactionally and preserve sufficient evidence to explain which edition was replaced.

If audit history cannot be reconstructed from existing rows, introduce the smallest additive persistence model needed for adoption history. Destructive schema changes are prohibited.

---

## 16. Application services

The final design should keep these responsibilities separate.

### 16.1 Reference repository

Responsible for:

- import immutable catalog edition;
- load/watch project catalogs and bindings;
- bind profile to an existing placed component;
- release binding under current safety rules.

### 16.2 Placement compatibility service

Pure/domain-oriented responsibility:

- evaluate candidate placement against profile constraints;
- produce structured findings;
- no persistence side effects.

### 16.3 Revision preview service

Application responsibility:

- compare candidate edition with bound profile snapshots;
- join binding `portIds` to actual ELV1 graph objects;
- resolve affected connections/groups;
- revalidate reconstructable placement contexts;
- produce `CatalogRevisionPreview`;
- no mutation.

### 16.4 Adoption service

Application/repository orchestration responsibility:

- validate adoption plan;
- execute explicit profile migration transactionally;
- preserve/retire/add port identities according to policy;
- reject unresolved connected-port incompatibilities;
- never select replacement profiles automatically.

---

## 17. UI: revision preview

The reference catalog UI must provide a clear candidate-edition comparison before adoption.

Suggested compact summary:

```text
Catalog ELV-CANONICAL
v1 → v2

Affected devices       8
Affected connections  11
Placement violations   2
Removed profiles       1
```

Then drill-down by profile/component:

```text
CAMERA-DOME
  placement changed
  ports unchanged
  5 bound devices
  2 wall placements become forbidden

SWITCH-24P
  interfaces changed
  3 bound devices
  11 affected connections

DETECTOR-LEGACY
  removed in v2
  1 device remains pinned until replacement is selected
```

The UI must distinguish:

- informational metadata changes;
- placement-impacting changes;
- connection/topology-impacting changes;
- blocking migration conditions.

The `Adopt edition` action is disabled while blocking conditions remain unresolved.

---

## 18. Required four-discipline fixtures

### 18.1 CCTV

Canonical PoE camera profile:

- wall/ceiling mounting;
- indoor/outdoor environment variant;
- Ethernet/PoE port;
- CCTV topology endpoint role.

Revision scenario:

- v2 removes wall mounting or changes Ethernet interface edition;
- preview identifies placement and/or connection impact.

### 18.2 LAN

Canonical data outlet or patch-panel profile:

- wall/rack mounting as appropriate;
- Cat6 interface semantics;
- LAN topology role.

Revision scenario:

- v2 changes interface/category semantics;
- bound LAN connections are identified.

### 18.3 Access control

Canonical reader/lock/controller profiles:

- wall/enclosure mounting distinctions;
- OSDP or power/contact ports;
- explicit endpoint/controller topology participation.

Revision scenario:

- v2 changes reader interface or mounting/environment restrictions;
- preview remains independent from CCTV/LAN assumptions.

### 18.4 Fire alarm

Canonical detector/loop-module profile:

- ceiling/wall constraints depending on profile;
- loop ports;
- loop topology participation.

Revision scenario:

- v2 changes loop participation or removes a legacy device profile;
- existing project remains pinned and migration is blocked until explicitly resolved.

---

## 19. Test specification

### 19.1 Pure engineering-core tests

Must cover:

- constraints serialization roundtrip;
- invalid mounting set;
- invalid temperature ranges;
- duplicate typed values;
- invalid closed-loop/topology combinations;
- deprecated profile read vs new-instantiation behavior;
- profile comparison: unchanged;
- profile comparison: mounting only;
- profile comparison: environment only;
- profile comparison: port/interface only;
- profile comparison: topology only;
- combined placement + connection impact;
- removed profile detection.

### 19.2 Catalog validation tests

Must cover:

- newly authored profile without valid constraints is rejected;
- legacy snapshot without constraints remains readable;
- immutable edition cannot be overwritten with different payload;
- new edition must have distinct immutable identity;
- display label changes do not alter engineering comparison unless engineering fields changed.

### 19.3 Placement service tests

Must cover:

- compatible surface/method;
- forbidden surface;
- forbidden mounting method;
- environment class mismatch;
- temperature mismatch;
- missing context -> unresolved rather than assumed valid;
- findings expose profile/catalog provenance.

### 19.4 Project revision-preview tests

Must cover:

- actual bound component resolved;
- persisted port IDs resolved;
- exact affected `EngineeringConnection` IDs resolved;
- exact affected `TopologyGroup` IDs resolved;
- unrelated connections excluded;
- removed profile surfaced;
- placement violations counted;
- legacy unresolved placement surfaced;
- candidate import itself leaves project bindings unchanged.

### 19.5 Adoption tests

Must cover:

- keep pinned;
- same-code safe adoption;
- replacement-profile adoption;
- preserve stable compatible port identity;
- introduce new port identity;
- retire unconnected removed port;
- block removal of connected port;
- block incompatible interface migration while connected;
- block incompatible current placement;
- transaction rollback on any failed migration action;
- retry does not duplicate ports/bindings.

### 19.6 Persistence/restart test

Required end-to-end sequence:

```text
create project
→ create CCTV/LAN/ACS/Fire systems
→ import catalog v1 with complete constraints
→ place one component from each discipline through canonical profiles
→ instantiate ports
→ create representative ELV1 connections/topology
→ close DB
→ reopen DB
→ verify exact bindings/profile constraints/port provenance
→ import v2
→ verify zero automatic mutations
→ compute revision preview
→ adopt selected safe bindings
→ close DB
→ reopen DB
→ verify exact adopted/pinned editions and stable connection identities
```

### 19.7 Widget tests

Must cover:

- discipline filter;
- profile details expose constraints before placement;
- deprecated profile cannot start new placement;
- incompatible candidate placement displays reason;
- candidate-edition summary counts;
- affected component/connection drill-down;
- removed-profile warning;
- adoption disabled when blockers exist.

---

## 20. Acceptance criteria

ELV2 is accepted only when all criteria below are met.

### AC-01 — Profile completeness

A canonical `ComponentEngineeringProfile` contains typed characteristics, capabilities, port templates, interface bindings and mounting/environment/topology constraints in one immutable edition snapshot.

### AC-02 — Deterministic persistence

After restart, the exact profile constraint payload and exact port/interface provenance are reconstructed without consulting a mutable global latest-version catalog.

### AC-03 — Pre-placement visibility

An engineer can select a discipline and canonical profile and inspect its mounting/environment/topology restrictions before placing the component.

### AC-04 — Pre-placement enforcement

An incompatible placement produces a structured explainable result and cannot be committed as a normal valid placement.

### AC-05 — Atomic creation

Successful placement creates one physical component, correct engineering-system membership/binding and persisted ports atomically. Failure leaves none of those partially created.

### AC-06 — Four disciplines

CCTV, LAN, ACS and Fire profiles all use the same generic workflow without hard-coded discipline branching in persistence or placement orchestration.

### AC-07 — Immutable import

Importing catalog v2 does not change any v1 binding, port, connection or placement.

### AC-08 — Semantic comparison

The system classifies candidate edition changes into at least placement-impacting and connection/topology-impacting categories.

### AC-09 — Project-specific impact

The preview resolves actual affected component IDs, persisted port IDs, connection IDs and topology-group IDs from the current project.

### AC-10 — Placement impact preview

If a new profile edition invalidates two existing placements, the preview reports those exact two placements rather than only stating that mounting rules changed.

### AC-11 — Removed profile safety

A profile removed from v2 remains valid for an existing v1-pinned project but cannot migrate automatically.

### AC-12 — Explicit adoption

Edition adoption occurs only through a dedicated explicit command/plan after preview.

### AC-13 — Connected-port protection

A catalog revision cannot silently remove or semantically replace a persisted port that participates in a connection.

### AC-14 — Port identity preservation

Compatible stable ports preserve their persisted identities across explicit adoption; newly introduced ports get new identities.

### AC-15 — Rollback

Any failed adoption leaves the project exactly on its previous pinned editions and graph state.

### AC-16 — Legacy compatibility

Pre-constraint ELV2 snapshots remain readable and are marked as legacy/unspecified rather than silently treated as fully unrestricted modern profiles.

### AC-17 — No ELV3 coupling

No cable allocation, CableRun or pathway compatibility logic is required to satisfy any ELV2 acceptance test.

### AC-18 — Exact-head gate

Formatting, static analysis, engineering-core tests, mobile tests and all relevant CI workflows pass on the exact PR head SHA before merge.

---

## 21. Definition of Done

The work package is done only when:

- [ ] constraints are part of canonical profile serialization;
- [ ] old catalog/binding snapshots remain readable;
- [ ] new incomplete canonical profiles are rejected;
- [ ] placement compatibility is a pure/testable domain capability;
- [ ] editor palette is discipline-aware;
- [ ] constraints are visible before placement;
- [ ] placement + binding + port instantiation is atomic;
- [ ] candidate edition import causes zero silent project mutation;
- [ ] semantic revision diff is complete for ELV2 profile fields;
- [ ] project preview identifies affected components/ports/connections/groups;
- [ ] existing placements are revalidated against candidate constraints;
- [ ] removed profiles are blocking/explicitly surfaced;
- [ ] adoption requires an explicit migration plan;
- [ ] connected incompatible ports block unsafe migration;
- [ ] port identity policy is covered by tests;
- [ ] CCTV/LAN/ACS/Fire fixtures pass;
- [ ] restart scenario passes before and after selective adoption;
- [ ] widget tests cover placement and revision UX;
- [ ] no ELV3 cable/routing implementation is pulled into the PR;
- [ ] exact-head CI is green;
- [ ] PR can be changed from Draft to Ready only after all acceptance evidence is recorded.

---

## 22. Recommended implementation sequence

Use small green gates rather than implementing the UI first.

```text
ELV2-P1  Profile persistence contract
  constraints embedded in ComponentEngineeringProfile
  + backward-compatible codec
  + domain tests

ELV2-P2  Placement compatibility engine
  PlacementCandidateContext
  + structured findings
  + pure tests

ELV2-P3  Discipline-aware palette
  choose system/discipline/profile
  + profile constraint inspection
  + widget tests

ELV2-P4  Atomic canonical placement
  placement + membership + binding + persisted ports
  + rollback/idempotency tests

ELV2-P5  Revision impact preview
  semantic diff
  + project graph join
  + current placement revalidation

ELV2-P6  Explicit adoption
  migration plan
  + port identity mapping
  + blocking conditions
  + transactional rollback

ELV2-P7  Four-discipline/restart acceptance
  CCTV + LAN + ACS + Fire
  + exact-SHA CI
  + ELV2 closure evidence
```

Do not begin ELV3 implementation until `ELV2-P7` is green.

---

## 23. Expected final engineer experience

The completed workflow should behave as follows.

### New placement

```text
Engineer activates CCTV
→ palette shows canonical CCTV profiles
→ selects CAMERA-DOME / ELV-CANONICAL v2
→ sees: wall/ceiling, bracket/surface, indoor/protected-outdoor, endpoint role
→ points at candidate wall
→ Electra validates candidate before commit
→ engineer places camera
→ exact profile edition is bound
→ ETH/PoE port is instantiated with exact interface provenance
```

### Catalog update

```text
Engineer imports ELV-CANONICAL v3
→ existing project remains unchanged
→ Electra computes impact preview

8 affected devices
11 affected connections
2 placement violations
1 removed profile

→ engineer opens affected devices
→ keeps one legacy detector pinned
→ selects explicit replacement for another profile
→ resolves incompatible connected port migration
→ adoption becomes available
→ transaction commits selected migrations
→ unaffected objects and connections keep their identities
```

That behavior is the completion criterion for ELV2 canonical profiles and reference catalogs.