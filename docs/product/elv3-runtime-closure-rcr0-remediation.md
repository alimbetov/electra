# Electra — ELV3 Runtime Closure RCR-0 Remediation

Status: AUTHORITATIVE RUNTIME-CLOSURE AMENDMENT / REQUIRED BEFORE RC0  
Branch: `feat/elv3-runtime-closure`  
Applies to: `docs/product/elv3-runtime-closure-specification.md` and `docs/product/elv3-runtime-closure-delivery-plan.md`  
Parent authority: existing ELV3 code-level contracts P1–P9 and dual-review process hardening.

## 1. Purpose and precedence

This amendment closes the project-consistency findings RC-A01…RC-A07 found during the post-merge Runtime Closure alignment review.

Runtime Closure remains an implementation-closure track, not a redesign track.

Where this amendment conflicts with either Runtime Closure document, this amendment wins. Where the Runtime Closure documents conflict with the already accepted ELV3 code-level contracts, the accepted code-level contracts win unless a new ADR/amendment is approved before implementation.

Authority order for Runtime Closure execution is therefore:

```text
ELV3 architecture/process authority
  ↓
ELV3 code-level contracts P1–P9
  ↓
this RCR-0 amendment
  ↓
Runtime Closure specification
  ↓
Runtime Closure delivery plan
  ↓
implementation
```

No implementation may use P9 as a post-facto mechanism to legitimize a contract deviation that was known before coding.

---

## 2. RCR-01 — P4 ownership: PathwayContext and PhysicalCarrier are project-owned physical facts

Finding closed: `RC-A01 BLOCKER`.

The Runtime Closure wording that places `designRevisionId` directly on the canonical identity of `PathwayContext`, `PhysicalCarrier`, or `PhysicalCarrierCompartment` is superseded.

Canonical ownership remains exactly as defined by the P4 code contract:

```text
Project
├ PathwayContext
│  └ PhysicalCarrier
│     └ PhysicalCarrierCompartment
└ ProjectDesignRevision
   └ revision-scoped CableRun/Traversal use + snapshot/evidence
```

Canonical P4 rows are shared project physical facts. Design revisions capture their use/state through revision-scoped traversal evidence, derived-result identity and immutable frozen snapshots.

Do not clone canonical carriers/pathway contexts solely because a new design revision is created.

Required invariant:

```text
carrier/pathway canonical identity         = project owned
run/traversal use                          = design-revision scoped
frozen historical representation          = captured by snapshot/evidence
current mutable carrier/pathway facts      != frozen historical source of truth
```

A P4 command still executes under an explicit WORKING `PhysicalDesignContext` when the mutation affects revision-scoped physical design. The context is a write authorization/impact boundary; it does not redefine carrier/pathway canonical ownership.

---

## 3. RCR-02 — No new TraversalCarrierAssignments aggregate/table

Finding closed: `RC-A02 HIGH`.

Runtime Closure MUST NOT introduce a second carrier-association model named `TraversalCarrierAssignments` unless a separate pre-implementation ADR proves the accepted P4 traversal-reference model cannot be implemented.

The accepted P4 model remains authoritative:

```text
CableRunTraversal
├ physicalCarrierId?
└ carrierCompartmentId?
```

or the exact already-approved persisted equivalent in the P4 code contract.

Attach/detach operations update the traversal’s carrier references transactionally and increment/invalidate the owning revision-scoped run as already specified.

Hard rule:

```text
one association source of truth only
```

P9 must fail if both traversal carrier columns and a second canonical assignment table coexist for the same semantic relation.

---

## 4. RCR-03 — Restore typed P4 host columns and real foreign keys

Finding closed: `RC-A03 HIGH`.

Generic authoritative host identity such as:

```text
hostKind + hostId
```

is prohibited for `PathwayContext` persistence.

Use the accepted typed host matrix and concrete foreign keys:

```text
kind
host_type
room_id?
floor_id?
from_floor_id?
to_floor_id?
spatial_feature_id?
parent_context_id?
```

Required mapping examples:

```text
ROOM_LOCAL / room host       -> room_id
FLOOR_COMMON / floor host    -> floor_id
SURFACE_VOID                 -> floor_id + spatial_feature_id
RISER / VERTICAL             -> from_floor_id + to_floor_id (+ optional spatial_feature_id)
PROJECT_SHARED               -> project_id
```

The repository must validate the kind/host matrix and project ownership transactionally.

No `hostJson`, generic polymorphic host key or equivalent untyped authoritative identity is permitted.

---

## 5. RCR-04 — Restore exact P5 persistence ownership and names

Finding closed: `RC-A04 BLOCKER`.

The Runtime Closure generic names:

```text
PhysicalProfileSets
PhysicalProfileSetEntries
PhysicalCompatibilityFindings
```

are superseded.

The accepted P5 canonical tables remain:

```text
ProjectPhysicalCompatibilityProfileSets
ProjectPhysicalCompatibilityProfileRefs
```

They persist the project-selected exact profile-set identity and exact ELV2 profile references/version/hash.

Physical compatibility findings are NOT a new canonical business table.

They remain revision-scoped derived/cache state stored through the existing `ProjectDerivedResults` infrastructure unless a separately approved pre-implementation amendment proves that infrastructure cannot represent the required typed payload/state.

Canonical P5 derived-result node key remains based on the accepted form:

```text
elv3:<designRevisionId>:P5:<subjectType>:<subjectId>
```

The input fingerprint must include every exact profile/reference revision/hash and all physical facts used by evaluation.

For FROZEN reconstruction, current/latest catalog lookup is forbidden; frozen snapshot/evidence and exact references are authoritative.

---

## 6. RCR-05 — P6 MUST reuse ProjectDerivedResults by default

Finding closed: `RC-A05 HIGH`.

P6 Runtime Closure MUST persist ELV-ROUTE-01…06 through the existing dependency/recalculation result infrastructure:

```text
ProjectDerivedResults
```

with revision-scoped deterministic node keys and typed result JSON/state.

A family of new process-specific canonical tables is prohibited by default.

Required identity includes at minimum:

```text
projectId
designRevisionId
processCode
subject identity
inputFingerprint
algorithm/engineVersion
result state/payload
evidence/trace
```

Preferred node-key pattern:

```text
elv3:<designRevisionId>:ELV-ROUTE-01:cable-run:<runId>
elv3:<designRevisionId>:ELV-ROUTE-02:carrier-usage:<segment>/<carrier>/<compartment-or-none>
...
```

A new calculation-result table may be introduced only after a pre-implementation audited exception demonstrates that `ProjectDerivedResults` cannot carry the required semantics. The exception must be documented before code is written, not approved retrospectively by P9.

---

## 7. RCR-06 — Exact names/contracts are frozen before implementation

Finding closed: `RC-A06 MEDIUM`.

Runtime Closure language allowing exact persisted names to differ if P9 later records an “approved equivalent” is narrowed as follows:

```text
already frozen by authoritative code contract
    -> use exact contract name/shape

not frozen by authoritative contract
    -> Runtime Closure may define it

need to deviate from frozen contract
    -> amend authority BEFORE implementation
```

P9 is an audit gate, not a mechanism for post-facto architecture approval.

The following are specifically frozen for Runtime Closure:

```text
P4:
  PathwayContexts
  PhysicalCarriers
  PhysicalCarrierCompartments

P5:
  ProjectPhysicalCompatibilityProfileSets
  ProjectPhysicalCompatibilityProfileRefs

P5/P6 derived results:
  ProjectDerivedResults

shared route geometry:
  CableRoutes
  CableRouteNodes
  CableRouteSegments
```

P3 exact persisted names follow the accepted P1–P3 code contract and its authoritative amendments.

---

## 8. RCR-07 — RC1 and RC2 exact-SHA evidence are independent gates

Finding closed: `RC-A07 MEDIUM`.

Checkpoint A may still be delivered in one PR, but RC1 and RC2 remain separate evidence gates.

Required sequence:

```text
RC1 implementation
→ commit SHA A
→ full RC1 gate GREEN
→ record SHA A/evidence

then and only then

RC2 implementation
→ commit SHA B
→ full RC2 gate GREEN
→ record SHA B/evidence
```

A single final RC2 green SHA does not substitute for the RC1 phase gate.

The same principle applies to every later exact-SHA boundary in the Runtime Closure delivery plan.

---

## 9. Corrected RC3–RC5 execution model

### RC3 / P4

Persist/close runtime using the accepted model:

```text
PathwayContexts
PhysicalCarriers
PhysicalCarrierCompartments
+ carrier/compartment refs on revision-scoped traversal evidence
```

Do NOT add revision ownership to carrier/pathway roots and do NOT add a second association aggregate.

### RC4 / P5

Persist:

```text
ProjectPhysicalCompatibilityProfileSets
ProjectPhysicalCompatibilityProfileRefs
```

Evaluate deterministic intrinsic physical compatibility and persist findings via revision-scoped `ProjectDerivedResults`.

### RC5 / P6

Persist all six process results via revision-scoped `ProjectDerivedResults`, including complete fingerprint/provenance/trace needed for restart reconstruction and frozen-history proof.

---

## 10. Additional P9 forbidden-shortcut assertions

P9 must now also fail on:

```text
PathwayContext or PhysicalCarrier cloned solely per design revision
canonical TraversalCarrierAssignments introduced alongside traversal carrier refs
generic hostKind+hostId used as authoritative PathwayContext host identity
canonical PhysicalCompatibilityFindings table introduced without approved amendment
P5/P6 result storage bypasses ProjectDerivedResults without approved exception
post-facto P9 approval used to justify known pre-implementation contract deviation
RC2 starts without recorded green RC1 exact SHA
```

---

## 11. Closure of review findings

| Finding | Severity | Resolution |
|---|---:|---|
| RC-A01 | BLOCKER | CLOSED by RCR-01 |
| RC-A02 | HIGH | CLOSED by RCR-02 |
| RC-A03 | HIGH | CLOSED by RCR-03 |
| RC-A04 | BLOCKER | CLOSED by RCR-04 |
| RC-A05 | HIGH | CLOSED by RCR-05 |
| RC-A06 | MEDIUM | CLOSED by RCR-06 |
| RC-A07 | MEDIUM | CLOSED by RCR-07 |

After this amendment is present, Runtime Closure may proceed to RC0 provided a re-review confirms no contradictory execution instruction remains.
