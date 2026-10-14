# Electra — ELV3 Code Implementation Index

Status: CODE IMPLEMENTATION AUTHORITY / P1 AUTHORIZED / P2-P5 HARDENED  
Branch: `feat/flutter-elv3-physical-routing-design`

## 1. Purpose

This is the implementation entry point for ELV3. Architecture/process meaning remains governed by the ELV3 architecture authority chain. This index governs code structure, public types, command ownership, Drift schema, transaction/concurrency contracts and test placement.

General code remediation CR-01..CR-16 is closed. P2-P5 have now received a dedicated second implementation review and hardening pass.

Latest readiness evidence:

- `docs/audit/elv3-code-implementation-technical-rereview.md` — general code re-review PASS;
- `docs/audit/elv3-p2-p5-code-technical-review.md` — dedicated P2-P5 PASS.

## 2. Code-level authority order

1. `docs/product/elv3-code-p2-p5-hardening.md` — exact P2-P5 claims/termination/routing/pathway/profile semantics.
2. `docs/product/elv3-code-remediation-final-clarifications.md` — phase-specific UoW, ledger replay, exact P6 evidence, P1 graph validation, legacy-route validation reuse.
3. `docs/product/elv3-code-implementation-remediation-cr01-cr16.md` — closed CR-01..CR-16 remediation.
4. `docs/product/elv3-code-contract-p1-p3.md`.
5. `docs/product/elv3-code-contract-p4-p6.md`.
6. `docs/product/elv3-code-contract-p7-p9.md`.
7. `docs/product/elv3-dual-review-process-hardening.md`.
8. `docs/product/elv3-r2-execution-clarifications.md`.
9. `docs/product/elv3-r2-final-readiness-remediation.md`.
10. `docs/product/elv3-implementation-specification-v2.md`.
11. accepted ADR/P0 authority chain.

Earlier wording contradicted by items 1-3 is superseded.

## 3. Layer map

```text
engineering_core
  pure domain/value objects/validators/calculations/codecs

application
  commands/command services/query ports/workspace state/impact coordination

data/repositories
  Drift adapters/phase-specific UoW/transaction-bound stores/error translation

app_database.dart
  tables/indexes/migrations/FKs

presentation
  render + command dispatch only
```

Hard rules:

```text
engineering_core MUST NOT import Drift/Flutter
application MUST NOT depend on Drift row types
widgets MUST NOT own compound DB mutations
calculation engines MUST NOT query repositories
command services are the sole use-case orchestration owner
```

## 4. Phase resource ownership

```text
P1
  CableResourceKind
  TerminationPolicyMode
  TerminationPolicy
  CableResourceDefinition

P2
  CableResourceSelection
  WholeCableSelection
  ResourceSetSelection
  DefinitionGroupSelection
  ResolvedCableResourceSelection
  CableResourceResolver
  CableTerminationObligation
  CableTerminationObligationResolver
```

Every published CableDefinition contains exactly one `__WHOLE_CABLE__` resource. Runtime exclusivity is always resolved to atomic resources.

## 5. P2 frozen physical allocation semantics

Canonical claim uniqueness:

```text
UNIQUE(cable_id, resource_atom)
```

There is no architectural `claim_key` string identity.

Claim resolution and termination resolution are separate:

```text
selection -> atomic claim set
selection -> termination obligation set
```

Termination may target selected composite/group identity while resource exclusion remains atomic.

Lifecycle:

```text
DRAFT -> RESERVED -> ACTIVE -> RELEASED -> ARCHIVED
DRAFT -> ARCHIVED
RESERVED -> RELEASED
```

Complete-set termination replacement is allowed only in RESERVED/ACTIVE and increments allocation revision.

Releasing the final consuming allocation is blocked while current WORKING revision has an ACTIVE CanonicalCableRun for the Cable.

## 6. P2 topology integration

Reserve/termination/activate always reload the current `EngineeringPortConnection` endpoints.

`ElvConnectionPhysicalDependencyInspector` protects physical evidence from destructive/re-endpoint ELV1 topology mutation after P2 selection history exists.

## 7. P3 reusable routing hardening

Route/node/segment project identity is derived only through:

```text
CableRoute.roomId -> Room.floorId -> Floor.projectId
```

`RouteHandoff` v1 continuity accepts only:

```text
exact integer world-coordinate equality
OR
exact typed SurfaceAdjacency/interface evidence
```

No arbitrary geometry tolerance.

Shared route edit uses exact:

```text
CableRouteGeometryCandidate(route,nodes,segments)
```

and validates canonical ELV + legacy electrical dependents through the existing routing validators.

## 8. P4 frozen pathway/carrier semantics

Canonical lifecycle:

```text
PathwayContext ACTIVE -> ARCHIVED
PhysicalCarrier ACTIVE -> ARCHIVED
CarrierCompartment ACTIVE -> ARCHIVED
```

P4 command session materializes Project/Floor/Room/SpatialFeature/parent ownership transactionally and enforces same-project hosts.

Archive is dependency-blocked by active children/carriers/current WORKING traversal usage.

Factual compartment capacity invariant:

```text
sum(active compartment usableAreaMm2)
  <= carrier usableAreaMm2
```

No compartment packing geometry is inferred beyond this factual area check.

## 9. P5 exact profile and rule semantics

Profile:

```text
PhysicalCompatibilityProfile
  code
  label
  deprecated
  rules[]
```

Every rule contains an explicit typed selector. Selector dimensions are wildcard when empty, OR within one dimension, AND across dimensions.

P5 v1 rules are frozen for:

```text
allowed cable technical class
allowed carrier kind
allowed installation class
allowed environment dimension/value
maximum cable diameter
minimum carrier usable area
direct intrinsic prohibition
```

Profile combination is selector-aware and order-independent.

Engine version:

```text
elv.physical-compatibility.v1
```

Stable status order:

```text
FORBIDDEN
UNRESOLVED
WARNING
OK
```

Profile-set mutation requires one current WORKING ProjectDesignRevision once P3 exists.

## 10. Common ELV command result

All P1-P9 commands use:

```text
ElvCommandResult<T>
  ElvCommandSuccess<T>
  ElvCommandFailureResult<T>

ElvFailure
```

Raw Drift/SQLite exceptions never cross the application boundary.

## 11. Transaction and concurrency model

Use phase-specific write sessions over the common command ledger scope.

Correctness relies on:

```text
FKs
partial unique indexes
expectedRevision conditional updates
atomic Drift transaction
real two-connection SQLite race tests
```

not assumed application serialization.

## 12. Canonical tables by phase

```text
P1 / schema 18
  ElvCables
  CommandExecutionRecords

P2 / schema 19
  CableAllocations
  CableAllocationResourceSelections
  CableResourceClaims
  CableTerminationMappings

P3 / schema 20
  ProjectDesignRevisions
  DesignRevisionPhysicalSnapshots
  CanonicalCableRuns
  CableRunTraversals
  RouteHandoffs
  RouteBendEvidence
  LegacyRouteAdoptions

P4 / schema 21
  PathwayContexts
  PhysicalCarriers
  PhysicalCarrierCompartments

P5 / schema 22
  ProjectPhysicalCompatibilityProfileSets
  ProjectPhysicalCompatibilityProfileRefs

P6 / schema 23
  RouteSeparationEvidenceRecords
```

If branch schema advances before a phase starts, only monotonic number rebasing is allowed; ownership/order remains fixed.

## 13. Required phase gates

Every implementation phase includes format/analyze, core/mobile tests, Drift generation, migration/restart/failure tests, real race tests where applicable, command-contract matrix update and exact-SHA evidence.

Dedicated additions:

```text
P2
  whole/composite/group overlap
  termination obligation semantics
  allocation/run release dependency

P3
  route project isolation
  exact handoff proof
  canonical + legacy shared route regression

P4
  host project isolation
  archive dependency guards
  compartment aggregate capacity

P5
  selector/combiner order-independence
  exact ref/hash/deprecated validation
  WORKING revision guard
  engine-version/fingerprint restart equivalence
```

## 14. Current authorization

```text
P1 implementation                  AUTHORIZED
P2 code specification              HARDENED / PASS
P3 code specification              HARDENED / PASS
P4 code specification              HARDENED / PASS
P5 code specification              HARDENED / PASS

open BLOCKER P2-P5 findings        0
open HIGH P2-P5 findings           0
```

Implementation authorization remains sequential:

```text
P2 only after P1 exact-SHA gate
P3 only after P2 gate
P4 only after P3 gate
P5 only after P4 gate
```
