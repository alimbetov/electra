# Electra — ELV3 P2-P5 Code Technical Review

Status: P2-P5 CODE TECHNICAL REVIEW / PASS  
Branch: `feat/flutter-elv3-physical-routing-design`  
Hardening: `docs/product/elv3-code-p2-p5-hardening.md`

## 1. Objective

Review P2-P5 independently after the general CR-01..CR-16 code remediation. The goal is to find phase-local implementation ambiguities that could still produce incompatible Dart/Drift implementations even though P1 is ready.

Review dimensions:

```text
compile/type ownership
public command semantics
DB constraint identity
transaction and race behavior
cross-phase dependency guards
legacy routing coexistence
project isolation
lifecycle/archive semantics
profile applicability/combination
restart/reproducibility
```

PASS requires zero open BLOCKER/HIGH findings after hardening.

## 2. P2 findings and closure

### Finding P2-A — claim identity and WHOLE_CABLE conflict were under-specified

Earlier contract used a generic `claim_key`, leaving its construction implementation-defined and making a sentinel WHOLE_CABLE claim potentially non-conflicting with child resources.

Resolution:

```text
claim identity = (cableId, atomicResourceIdentity)
UNIQUE(cable_id, resource_atom)
```

`WholeCableSelection` resolves `__WHOLE_CABLE__` to all atomic descendants. Partial/composite/group selections resolve to the same atom namespace. Therefore every overlap reaches the same DB uniqueness backstop.

State: CLOSED.

### Finding P2-B — termination identity was conflated with atomic claim identity

A group-level termination, pair termination or whole-cable connector cannot always be represented by an atomic claim identity.

Resolution: independent `CableTerminationObligationResolver`. Claims are atomic; termination obligations may target the selected composite/group resource. Exact one-/two-ended/optional/group rules are frozen.

State: CLOSED.

### Finding P2-C — lifecycle mutation guards incomplete

Resolution:

```text
Draft create          -> DRAFT
Reserve               -> DRAFT -> RESERVED
Replace terminations  -> RESERVED|ACTIVE only
Activate              -> RESERVED -> ACTIVE
Release               -> RESERVED|ACTIVE -> RELEASED
Archive               -> DRAFT|RELEASED -> ARCHIVED only
```

Every mutation increments allocation revision.

State: CLOSED.

### Finding P2-D — releasing final allocation could orphan an active run

Resolution: final consuming allocation release is blocked while current WORKING revision contains an ACTIVE canonical run for the Cable. Releasing one of several allocations remains valid.

State: CLOSED.

### Finding P2-E — ELV1 endpoint changes could invalidate persisted termination evidence

Resolution: all reserve/termination/activate transactions reload exact connection endpoints; `ElvConnectionPhysicalDependencyInspector` is the integration port for destructive/re-endpoint topology mutations once P2 exists.

State: CLOSED.

P2 result: **PASS AT CODE-SPEC LEVEL**.

## 3. P3 findings and closure

### Finding P3-A — route project identity is indirect in current schema

Existing route tables are room-owned. A developer could incorrectly infer project from UI context or Cable.

Resolution:

```text
CableRoute.roomId -> Room.floorId -> Floor.projectId
```

Exact `ElvRouteProjectResolver` is required for route/node/segment project checks.

State: CLOSED.

### Finding P3-B — handoff geometric tolerance was unspecified

Resolution: P3 v1 uses no arbitrary numeric tolerance. Handoff requires exact integer world-coordinate equality or exact typed adjacency evidence. Directionality is explicit.

State: CLOSED.

### Finding P3-C — public candidate geometry was open-ended

Resolution: exact `CableRouteGeometryCandidate(route,nodes,segments)` and reuse of current `CableRouteValidator` path.

State: CLOSED.

### Finding P3-D — run/allocation reverse dependency

Resolution: P2 release rule plus P3 CreateCableRun prerequisite form one bidirectional invariant. Active run cannot become detached from the final consuming allocation.

State: CLOSED.

P3 result: **PASS AT CODE-SPEC LEVEL**.

## 4. P4 findings and closure

### Finding P4-A — persisted lifecycle existed but public domain lifecycle was incomplete

Resolution: exact ACTIVE/ARCHIVED lifecycle enums for PathwayContext, PhysicalCarrier and CarrierCompartment.

State: CLOSED.

### Finding P4-B — host IDs could pass shape validation without project-safe materialization

Resolution: P4 write session loads Project/Floor/Room/SpatialFeature/parent context and verifies exact same-project ownership. Vertical host requires two distinct same-project floors.

State: CLOSED.

### Finding P4-C — archive dependency behavior was not executable

Resolution:

```text
context archive blocked by active children/carriers
carrier archive blocked by current WORKING traversal usage
compartment archive blocked by current WORKING traversal usage
```

Frozen historical snapshots do not block forward archive.

State: CLOSED.

### Finding P4-D — compartment factual capacity lacked aggregate invariant

Resolution: exact cross-sectional area formulas and `sum(active compartment usable areas) <= carrier usable area` required before create/update commit.

State: CLOSED.

### Finding P4-E — old repository mutation API conflicted with common command-service ownership

Resolution: P4 mutation owner is `ElvPathwayCommandService` / `ElvPhysicalCarrierCommandService`; repositories are read/query ports and transaction-bound stores live behind P4 UoW.

State: CLOSED.

P4 result: **PASS AT CODE-SPEC LEVEL**.

## 5. P5 findings and closure

### Finding P5-A — profile itself lacked exact public shape

Resolution: `PhysicalCompatibilityProfile(code,label,rules,deprecated)` with canonical code/hash/codec rules.

State: CLOSED.

### Finding P5-B — rule applicability was implicit

Resolution: every rule carries typed `PhysicalCompatibilitySelector`. Empty selector dimension means wildcard; non-empty values OR within dimension; dimensions AND together.

State: CLOSED.

### Finding P5-C — several rule semantics were still interpretable differently

Resolution: exact semantics frozen for allowed cable technical classes, carrier kind, installation class, environment dimension, maximum diameter, minimum usable area and direct intrinsic prohibition.

State: CLOSED.

### Finding P5-D — combination API/result was not explicit

Resolution: `PhysicalCompatibilityProfileCombiner` + `CombinedPhysicalCompatibilityRules`, combination after selector filtering, no profile order precedence.

State: CLOSED.

### Finding P5-E — engine version/severity ordering missing

Resolution:

```text
engine = elv.physical-compatibility.v1
status order = FORBIDDEN, UNRESOLVED, WARNING, OK
```

Engine version participates in fingerprints/results.

State: CLOSED.

### Finding P5-F — profile-set mutation during no-WORKING gap was possible by omission

Resolution: after P3 every profile-set mutation requires current WORKING PhysicalDesignContext; FROZEN snapshot preserves exact refs.

State: CLOSED.

### Finding P5-G — duplicate/deprecated/foreign refs were not fully enumerated

Resolution: activation validates unique exact refs, same project, exact content hashes, non-deprecated profiles and supported schemas.

State: CLOSED.

P5 result: **PASS AT CODE-SPEC LEVEL**.

## 6. Cross-phase checks

PASS:

```text
P2 resource claims do not depend on P3 tables to compile
P3 extends dependency adapters without changing P2 public commands
P4 introduces no P5 persistence early
P5 write session does not require P6 separation persistence
P2-P5 all use common ElvCommandResult/ElvFailure
P2-P5 all use phase-specific UoW sessions
P2-P5 preserve design-revision WORKING write guard once P3 exists
legacy electrical route graph remains shared and protected
```

## 7. Mandatory implementation gates by phase

### P2 gate additions

```text
atomic overlap races through two SQLite connections
WHOLE/composite/group overlap fixtures
termination-obligation fixtures
release-vs-active-run dependency test once P3 adapter exists
restart with immutable selection/termination evidence
```

### P3 gate additions

```text
route ownership cross-project rejection
exact-coordinate/adjacency handoff tests
shared canonical+legacy route edit regression
run/allocation cross-phase dependency test
```

### P4 gate additions

```text
host project-isolation tests
archive dependency tests
compartment aggregate capacity tests
carrier fan-out tests
```

### P5 gate additions

```text
selector semantics
rule codec unknown-kind rejection
combiner order independence
profile ref/hash/project/deprecation validation
WORKING revision mutation guard
engine-version/fingerprint restart equivalence
```

## 8. Final verdict

```text
P2 code specification                         PASS
P3 code specification                         PASS
P4 code specification                         PASS
P5 code specification                         PASS

P2-P5 compile ownership                       PASS
P2-P5 DB/concurrency invariants                PASS
P2-P5 transaction/lifecycle semantics          PASS
P2-P5 cross-phase dependency semantics         PASS
P2-P5 project isolation                        PASS
P5 deterministic profile/rule semantics        PASS

open BLOCKER findings                          0
open HIGH findings                             0
```

Authorization remains sequential:

```text
P1 is AUTHORIZED now
P2 becomes implementation-authorized only after P1 exact-SHA gate
P3 only after P2 gate
P4 only after P3 gate
P5 only after P4 gate
```

`PASS` here means each future phase is sufficiently specified at code level and should not need another architectural design decision when its implementation gate opens.
