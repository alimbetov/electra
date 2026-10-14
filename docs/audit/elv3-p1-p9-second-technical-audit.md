# Electra — ELV3 P1–P9 Second Technical Readiness Audit

Status: ADVERSARIAL IMPLEMENTATION AUDIT / READINESS REOPENED  
Branch: `feat/flutter-elv3-physical-routing-design`  
Audited authority: `docs/product/elv3-authoritative-spec-index.md` and `docs/product/elv3-implementation-specification-v2.md`

## 1. Objective

Re-audit every P1–P9 gate against the current project code and persistence model, specifically looking for places where two independent implementation teams could still produce incompatible behavior, where a required calculation cannot be produced from persisted facts, or where historical/restart semantics are not reproducible.

This audit does not challenge the remediated ELV3 domain direction unless the implementation contract proves inconsistent with it.

## 2. Executive verdict

```text
ELV3 canonical architecture                 PASS
ELV1 / ELV2 / ELV3 ownership boundaries    PASS
P1–P9 phase direction                       PASS
implementation determinism                  PARTIAL
historical revision reproducibility         FAIL
calculation input completeness              FAIL
P1 execution authorization                  HOLD
READY FOR EXECUTION                         REOPENED
```

The branch remains a strong architecture specification, but the second audit found two BLOCKER findings and several HIGH findings that must be remediated before implementation starts.

## 3. Findings

| ID | Phase | Severity | Finding | Required decision |
|---|---|---:|---|---|
| TA2-01 | P3/P8 | BLOCKER | FROZEN `ProjectDesignRevision` is not reproducible while `Cable`, `CableAllocation` and terminations remain globally mutable | freeze/snapshot or mutation-lock the revision-sensitive physical realization graph |
| TA2-02 | P5/P6 | BLOCKER | current route geometry stores sharp point nodes only; actual bend radius cannot be derived deterministically | add explicit bend geometry/radius evidence or remove bend-radius calculation until such evidence exists |
| TA2-03 | P2 | HIGH | composite cable resource atomization is under-specified in v2 | freeze atom/composite expansion for PAIR/CORE_GROUP/CONDUCTOR and overlap rules |
| TA2-04 | P2 | HIGH | activation-time termination completeness is undefined for whole cable, pairs, shields, drain/PE and asymmetric terminations | add definition-owned termination requirement policy and exact activation rule |
| TA2-05 | P3 | HIGH | traversal continuity references an “accepted handoff” but no canonical handoff identity exists for `CanonicalCableRuns` | define canonical RouteHandoff/SurfaceAdjacency usage and persistence/reference rules |
| TA2-06 | P3 | HIGH | `ProjectDesignRevision` lifecycle has states but no complete application command/process contract | define create/freeze/new-working/supersede/archive commands and atomic transitions |
| TA2-07 | P1 | HIGH | `CableDefinitionRef.definitionContentHash` says deterministic hash but does not freeze canonical serialization + hash algorithm | freeze exact canonical JSON/hash algorithm and compatibility key names |
| TA2-08 | P1/P5 | HIGH | P1 catalog shape persists `physicalCompatibilityProfiles[]`, leaking a P5 canonical capability into P1 | P1 must persist only cable-definition extension; add physical profiles at P5 or explicitly gate empty/non-authoritative payload |
| TA2-09 | P3 | HIGH | v2 says canonical P3 table names may still be selected although the authoritative index freezes names | remove the conflicting wording from v2; exact names are `ProjectDesignRevisions`, `CanonicalCableRuns`, `CableRunTraversals`, `LegacyRouteAdoptions` |
| TA2-10 | P6 | HIGH | installed-length and fill formulas are not exact enough for independent implementations | freeze formula/order/rounding/units and occupancy area derivation |
| TA2-11 | P6 | HIGH | occupancy granularity is ambiguous: whole-carrier distinct Cable count overcounts partial/shared path use | calculate occupancy per traversed carrier/compartment path segment or another explicitly frozen spatial bucket |
| TA2-12 | P4 | MEDIUM | `parentContextId` has no acyclic containment invariant and no exact allowed parent matrix | define parent compatibility, project equality and cycle prevention |
| TA2-13 | P8 | MEDIUM | failure injection points are listed but not mapped to exact commands/expected pre/post state | add command-by-command fault matrix |
| TA2-14 | P9 | MEDIUM | exact-SHA is process policy only; branch currently has no mandatory protection/status checks | keep as governance risk or enforce through repository ruleset |

## 4. P1 audit — Cable identity / exact CableDefinitionRef / ELV2 extension

### PASS

The decision to reuse `EngineeringReferenceCatalogs` is correct. Current repository behavior already treats catalog identity/payload as immutable: re-import of the same id with different project or payload is rejected. This is aligned with exact CableDefinition provenance.

The existing component binding is correctly not reused for Cable.

### TA2-07 — hash contract is not exact enough

`CableDefinitionRef` stores:

```text
catalogId
catalogVersion
definitionCode
definitionContentHash
```

but the specification does not freeze:

- canonical serialization function/version;
- cryptographic/non-cryptographic algorithm;
- text encoding;
- whether list order is semantic for resources/technical classes;
- normalization before hashing;
- compatibility behavior if canonical serializer changes later.

The repository already has `canonicalEngineeringJson`, which sorts object/map keys but preserves list order. P1 should explicitly reuse a versioned canonical representation and freeze an algorithm such as SHA-256 over UTF-8 canonical JSON.

### Catalog backward compatibility gap

Current `EngineeringReferenceCatalog` serializes existing component profiles under the key `profiles` and validation requires at least one profile. v2 conceptually renames this to `componentProfiles[]` and adds Cable definitions. P1 must freeze wire compatibility:

```text
existing key `profiles` remains readable/writable for component profiles
add `cableDefinitions`
P1 does not rename historical payload keys
catalog validity = at least one supported definition/profile family, not necessarily a component profile
```

Otherwise a cable-only catalog or old project can be interpreted differently by independent implementations.

### TA2-08 — phase leakage

P1 currently shows `physicalCompatibilityProfiles[]` inside the persisted ELV2 catalog shape although P5 owns that capability. This conflicts with the phase rule prohibiting future-phase canonical persistence early. P1 should add only CableDefinition support; P5 adds `physicalCompatibilityProfiles` under its own gate.

## 5. P2 audit — allocation / resource claims / A-B terminations

### PASS

The strict lifecycle and atomic `claim_key` direction are sound. WHOLE_CABLE exclusivity and same-connection one-Cable restriction are also clear.

### TA2-03 — resource atomization

The remediated P0 model described parent/group semantics more explicitly than authoritative v2. The current v2 does not fully determine whether a PAIR is an atom, a composite of conductors, or both when conductors are independently addressable.

Required frozen model:

```text
CableResourceDefinition
  identity
  kind
  allocatable
  atomic
  children[] / parent?
  groupMembership[]
  terminationPolicy

resolve(selection) -> Set<atomic resource identity>
```

Rules must explicitly state, for example:

- pair-only definition: PAIR may itself be atomic;
- independently addressable pair conductors: selecting PAIR expands to its conductor atoms;
- selecting conductor 1 conflicts with later selection of its pair;
- CORE_GROUP always expands to finite atoms;
- WHOLE_CABLE uses reserved global atom/exclusion semantics.

### TA2-04 — termination completeness

`ActivateCableAllocation` requires “structurally valid required terminations”, but the exact requirement is not derivable for all resources.

Examples:

- whole Cat6: terminate whole cable or every pair/conductor?
- shield/drain: one-end bonding may be valid;
- PE/functional earth: asymmetric termination can be intentional;
- fiber duplex: each selected fiber normally needs A and B mappings.

The exact CableDefinition must expose a typed termination requirement/policy. Activation must evaluate that policy, not hard-code “every atom has both A/B” globally.

## 6. P3 audit — design revision / canonical CableRun / traversal / coexistence

### TA2-01 — FROZEN revision reproducibility is not guaranteed

ADR-030 states that FROZEN revisions are immutable baselines. However:

- Cable is project-global and can conceptually change definition through an explicit command;
- CableAllocation is project-global and can transition/release/archive;
- termination mappings can be replaced;
- CableRun references the design revision, but allocation/termination meaning is not revision-scoped or snapshotted.

Therefore this sequence is currently possible at specification level:

```text
R1 WORKING
  Cable C1
  Allocation A1 resources 1,2
  Terminations T1
  CableRun CR1
freeze R1

later:
  release A1 / replace termination / change Cable definition under revalidation
```

Reopening R1 no longer reconstructs the physical realization that was frozen.

P3 must choose one exact strategy before implementation:

A. freeze locks every revision-sensitive Cable/Allocation/Termination mutation referenced by FROZEN revisions; later changes require versioned replacement identities, or

B. FROZEN ProjectDesignRevision owns an immutable physical-realization snapshot/version graph referenced by exact ids/revisions.

A derived calculation cache alone is not sufficient because canonical source facts themselves must remain reconstructable.

### TA2-05 — handoff identity

Current `FloorRoutingHandoffs` references legacy `CableRuns` (`fromRunId`/`toRunId`). It cannot directly serve as a generic canonical route-segment handoff for `CanonicalCableRuns`.

P3 must define exactly which object proves continuity across two route graphs:

```text
RouteHandoff(fromRouteNodeId, toRouteNodeId, adjacency/spatial evidence)
```

or explicitly define how existing `SurfaceAdjacency` is sufficient. A run-specific legacy handoff cannot be the canonical reusable route handoff.

### TA2-06 — missing revision commands

Required process contracts are missing for:

```text
BootstrapProjectDesignRevision
FreezeProjectDesignRevision
CreateNextWorkingDesignRevision
SupersedeProjectDesignRevision
ArchiveProjectDesignRevision
```

Their transaction boundaries, optimistic revisions, uniqueness handling and effects on active CableRuns must be frozen.

### TA2-09 — table-name contradiction

The authoritative index freezes:

```text
ProjectDesignRevisions
CanonicalCableRuns
CableRunTraversals
LegacyRouteAdoptions
```

but v2 still states that canonical tables “may use exact final names selected to avoid collision”. Because v2 outranks other documents, this reintroduces choice. v2 must state the exact frozen names.

## 7. P4 audit — PathwayContext / PhysicalCarrier / compartments

The carrier-vs-context separation remains correct and the sealed host mapping is materially better than the first design.

### TA2-12 — context containment

`parentContextId` requires invariants:

- parent belongs to same project;
- parent chain is acyclic;
- child/parent kind combinations are explicitly allowed;
- a context cannot parent itself directly or transitively;
- archive is blocked by active child contexts unless they are reparented/archived atomically.

Without this, restart can reconstruct structurally invalid pathway trees.

P0 cross-section semantics (`RECTANGULAR`, `CIRCULAR`, `CUSTOM usableArea`) remain compatible and should be lifted explicitly into the implementation spec rather than left implicit.

## 8. P5 audit — technical physical compatibility

The ELV3/ELV7 boundary remains PASS.

### TA2-02 — bend-radius input cannot currently be produced

Current route geometry stores points/nodes and straight segments. A bend is represented as a node between straight segments. It does not store an arc radius, bend fitting, tangent length, installed bend radius or equivalent curvature evidence.

Therefore the specification cannot deterministically evaluate:

```text
actual bend radius >= CableDefinition.minimumBendRadiusMm
```

from current canonical geometry.

P5/P6 must either:

1. introduce explicit bend evidence such as `RouteBendGeometry(radiusMm, ...)` / bend fitting identity / installed radius fact, with persistence and editor semantics; or
2. remove actual bend-radius compliance from ELV3 until the geometry model supports it and report `UNRESOLVED` whenever no bend-radius evidence exists.

It must not infer a radius from three polyline points without a defined geometric construction.

## 9. P6 audit — physical calculations/evidence

### TA2-10 — formulas must be frozen

The current legacy routing engine calculates:

```text
cableLength = geometricLength * (1 + reservePercent/100)
              + terminationAllowanceMm
```

The v2 specification only states “geometry + allowances”. Independent implementations could apply percentage after termination allowance, apply allowance per end, or round at different stages.

P6 must freeze:

- millimetres as canonical calculation unit;
- exact formula/order;
- whether terminationAllowanceMm is total or per-end;
- floating-point/rounding contract for report values;
- invalid/non-finite behavior.

Carrier fill basis must similarly freeze area derivation:

```text
round cable area = pi * OD^2 / 4
carrier gross/usable area source
custom cable section handling
missing OD -> BLOCKED/UNRESOLVED
```

### TA2-11 — occupancy spatial granularity

A Cable that uses only one portion of a long/shared carrier must not be counted against every other portion merely because the carrier id matches.

Occupancy/fill evidence should be keyed by the actual traversed carrier section, normally at least:

```text
(routeSegmentId, physicalCarrierId, compartmentId?)
```

or another explicitly frozen spatial bucket. Whole-carrier aggregation may be provided as a conservative summary but cannot be the only factual basis for segment-level fill/congestion.

## 10. P7 audit — engineer workspace

PASS WITH DEPENDENCIES.

The progressive workflow, command boundary and no-per-discipline-editor rule are sound. P7 remains blocked by P2/P3/P4 contracts above because the UI must render their exact state model.

Before P7 implementation, route geometry editing must dispatch an application/domain command boundary compatible with existing routing repository behavior; widgets must not become the only place where reusable route integrity is enforced.

## 11. P8 audit — restart / rollback / idempotency / fixtures

The five-fixture requirement remains strong.

### TA2-13 — fault matrix

P8 should freeze command-specific expectations, for example:

| Command | Inject after | Expected state |
|---|---|---|
| CreateCable | Cable insert | no Cable/effect after rollback |
| ReserveCableResources | first claim row | DRAFT allocation, zero claims |
| ActivateCableAllocation | before state update | RESERVED unchanged |
| RerouteCableRun | old traversal deletion/first new row | original traversal chain intact |
| CreateNextWorkingDesignRevision | new revision insert | previous revision state unchanged on rollback |
| AdoptLegacyElectricalRoute | Cable creation | no Cable/Run/adoption evidence |

This removes ambiguity around what “no partial canonical state” means per command.

## 12. P9 audit — architecture-vs-code / exact-SHA

The rejection list and final CI evidence are strong.

Repository governance remains a process risk: the branch is not protected and mandatory status checks are not mechanically enforced. This does not invalidate the domain specification but exact-SHA closure must be proven by captured workflow status for the final SHA.

## 13. Remediation gate

Before P1 implementation, close at least:

```text
R2-01 frozen design revision source-of-truth strategy
R2-02 bend-radius evidence strategy
R2-03 exact CableDefinition canonical hash/wire compatibility
R2-04 resource atom/composite expansion contract
R2-05 termination requirement policy
R2-06 canonical reusable route handoff identity
R2-07 ProjectDesignRevision command/state process
R2-08 remove P1->P5 catalog phase leakage
R2-09 remove P3 table-name contradiction
R2-10 exact P6 formulas and occupancy granularity
R2-11 PathwayContext containment invariants
R2-12 P8 failure matrix
```

Then rerun this audit against the corrected authoritative documents.

## 14. Final verdict

```text
Architecture direction        PASS
P1                         HOLD
P2                         HOLD
P3                         HOLD / BLOCKER
P4                         CONDITIONAL
P5                         HOLD / BLOCKER
P6                         HOLD
P7                         BLOCKED BY P2-P6
P8                         SPEC HARDENING REQUIRED
P9                         GOOD CLOSURE FRAMEWORK

READY FOR EXECUTION           NO — REOPENED
```

The second audit did not find a reason to redesign the fundamental ELV3 entity chain. It did find implementation-level integrity gaps significant enough that coding should not start until the R2 remediation set is closed.