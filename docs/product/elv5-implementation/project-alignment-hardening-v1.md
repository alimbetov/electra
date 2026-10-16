# ELV5 — Project-wide alignment hardening v1

Status: DESIGN READY FOR DEVELOPMENT / PROJECT ALIGNMENT CLOSED IN ELV5 / RUNTIME NOT STARTED

This amendment closes contradictions found by the project-wide architecture/developer/system-analysis/electrical-engineering review after the sixth implementation-binding pass and the subsequent implementation-readiness audit. It reconciles active authority, code-layer ownership, canonical engineering oracles, schema/version precedence, P2/P3 implementation identities and downstream handoff. It does not add new process codes or change the physical ownership boundary established by ELV1–ELV4.

Where this file explicitly conflicts with older ELV5 prose, this file governs. It is subordinate only to accepted ELV1–ELV4 runtime ownership/facts and to a future explicit ELV5 erratum/amendment that names the affected clause.

## 1. Authority-chain closure

The active human-readable authority chain MUST expose the same constraints already present in the machine manifest. The active ELV5 authority therefore includes:

- `implementation-binding-hardening-v1.md`;
- `implementation-binding-registry.json`;
- `repository-contract-registry.json`;
- `runtime-version-registry.json`;
- `algorithm-performance-registry.json`;
- `finding-trace-code-registry.json`;
- `development-readiness-registry.json`;
- the 1500-case combinatorial requirements/plan/constraint/3-wise/system inventories;
- fifth-, sixth-, seventh- and eighth-pass closure evidence;
- this project-alignment amendment and `downstream-handoff-registry.json`.

A machine authority included in the exact-head manifest or transitively pinned by a manifest authority but omitted from the human authority map is a specification defect.

## 2. Resolver ownership

Repository-aware input resolution belongs to the application layer. `engineering_core` owns only pure process metadata, typed contracts, calculation/evaluation logic and deterministic engineering primitives.

Normative pipeline:

```text
short capture scope
  -> application InputResolver
  -> immutable sendable typed input
  -> pure engineering_core ProcessDefinition/Kernel
  -> typed output/evaluation draft
  -> guarded application publication
```

Any older example that places `resolveInput(...)` on `Elv5TypedProcessDefinition` is superseded. Pure definitions/kernels must not access DB/Drift/UI/platform state.

## 3. Source-layout policy

Public symbols, process identities, semantic types, layer ownership and dependency direction are frozen. Exact filenames are tracked implementation coordinates, not engineering truth.

A filename/path-only change is permitted with synchronized implementation-binding registry + authority manifest update and unchanged layer ownership/public semantics. Moving a resolver into `engineering_core`, moving a kernel into the data layer, or changing a public symbol/contract is an architecture/specification change.

The nested `engineering_core/lib/src/elv5/...` layout is an accepted bounded-context organization inside the existing package; it is not a new core package or duplicated domain ownership.

## 4. ACS-03 canonical oracle

The only valid frozen positive arithmetic oracle for the stated fixture is:

```text
source = 24.00 V
shared trunk current = 0.30 A + 0.50 A = 0.80 A
shared trunk resistance = 0.50 ohm
shared trunk drop = 0.40 V
branch origin = 23.60 V
lock branch current = 0.30 A
lock branch resistance = 0.30 ohm
lock branch drop = 0.09 V
lock terminal = 23.51 V
minimum terminal requirement = 22.00 V
headroom = +1.51 V
```

`23.45 V` / `+1.45 V` is invalid for these exact inputs. Process contracts, ACS dossier, errata and future executable fixtures must agree on `23.51 V / +1.51 V`. ELV5 still consumes exact ELV4 PWR-03 evidence in production rather than duplicating the physical solver.

## 5. Database schema precedence

The initial ELV5 additive database target is frozen at **schema 24** by `runtime-version-registry.json` and `persistence-schema-contract.md`.

This explicitly supersedes earlier baseline language saying to choose an arbitrary additive version `>23` at implementation time. Schema 24 is an implementation-entry contract, not a suggestion. Future change requires synchronized migration/runtime-version/manifest review.

## 6. Legacy design-version labels and canonical version encoding

Legacy `1-design` labels and `DESIGN DRAFT` markers in older inventory artifacts are provenance/status history only when a later frozen runtime registry or amendment exists. They cannot authorize production result versions, schema choice or runtime codec versions.

`runtime-version-registry.json` stores `inputSchemaVersion` and `outputSchemaVersion` as positive JSON integers for compact machine inventory. The Dart/runtime contracts use strings. The canonical bridge is mandatory:

```text
registry integer 1 -> canonical runtime/hash string "1"
registry integer N -> base-10 canonical runtime/hash string decimal(N)
```

No leading zero, sign, locale, whitespace or alternate numeric representation is legal. A fingerprint MUST NOT distinguish registry `1` from runtime `"1"` after this canonicalization, and it MUST NOT accept an uncanonical representation as a second version identity.

## 7. Project roadmap status

Project-level roadmap/status text must distinguish historical planning from current accepted baselines. For the ELV5 branch, the governing reality is:

```text
ELV1 CLOSED / ACCEPTED
ELV2 CLOSED / ACCEPTED
ELV3 merged/accepted prerequisite inherited by ELV4
ELV4 implemented, runtime accepted and merged to main d2b059d4c11a284cdd32965140f6df3c40020c8d
ELV5 DESIGN READY FOR DEVELOPMENT / RUNTIME NOT STARTED
ELV6–ELV8 design branches exist but require downstream reconciliation to the accepted/final ELV5 authority before runtime entry
```

Older roadmap labels such as “ELV4 blocked”, “ELV5 planned” or “ELV5 design only / not ready” are historical and must not be used as current authorization state.

## 8. Downstream handoff

`downstream-handoff-registry.json` is the machine contract for ELV5 -> ELV6/ELV7/ELV8.

No downstream runtime may start from an old ELV5 design SHA alone. At downstream reconciliation it must pin:

- the accepted ELV5 runtime/source SHA when available;
- the exact accepted ELV5 authority fingerprint;
- database schema/version contracts actually implemented;
- stable projection/evidence schemas consumed by that stage;
- claim boundaries preventing recomputation of upstream truth.

Existing ELV6/ELV7/ELV8 design branches remain useful design work, but their older pinned ELV5 ancestors are explicitly `RECONCILIATION_REQUIRED_BEFORE_RUNTIME`.

## 9. Stage claim boundaries

The downstream contract remains:

```text
ELV5 -> ELV6: demand/basis/evidence only; ELV6 owns physical layout/fit/constructability
ELV5 -> ELV7: technical evidence only; ELV7 owns verified jurisdictional compliance/applicability
ELV5 -> ELV8: engineered requirements/evidence only; ELV8 owns product selection/BOM/deliverables
```

Examples:

- LAN-06 PASS cannot imply rack fit;
- FA-08 technical policy match cannot imply verified compliance;
- positive optical budget cannot imply ELV8 product suitability;
- equipment selection cannot rewrite historical ELV5 results.

## 10. CI closure sentinels

The exact-head project-alignment gate must fail when any of the following reappears:

- authority index omits the binding/1500/seventh/eighth-pass authority layer;
- typed process definition owns repository-aware `resolveInput`;
- pure-kernel/application resolver boundary is weakened;
- source paths are treated as engineering semantics rather than tracked coordinates;
- ACS-03 active process contract/dossier contains the invalid `23.45/+1.45` oracle;
- runtime database version differs from frozen schema 24 without explicit reviewed migration change;
- downstream handoff lacks exact authority-fingerprint pinning requirement;
- downstream runtime is allowed before ELV5 runtime/authority reconciliation;
- roadmap current-state text regresses from `DESIGN READY FOR DEVELOPMENT / RUNTIME NOT STARTED`;
- any of ELV5-R8-01…ELV5-R8-10 loses its machine/human closure.

## 11. Eighth-pass implementation-readiness closure

The following rules close the ten findings recorded in `development-readiness-registry.json`. They are implementation-entry rules and explicitly supersede any lower-authority schematic snippet that disagrees.

### 11.1 CCTV-02 subscription and multicast identity — ELV5-R8-01

The effective typed subscription contract is:

```dart
final class CctvFlowSubscription {
  final String subscriptionId;
  final String streamId;
  final String receiverId;
  final List<String> orderedNetworkEdgeIds;
  final CctvDeliveryMode deliveryMode; // UNICAST | MULTICAST
  final String? multicastGroupId;
  final CctvMulticastTree? multicastTree;
}

final class CctvMulticastTree {
  final String treeId;
  final Set<String> edgeIds;
}
```

Rules:

- `subscriptionId` is mandatory and unique inside one camera replacement aggregate;
- `UNICAST` requires `multicastGroupId == null` and `multicastTree == null`;
- `MULTICAST` requires non-empty `multicastGroupId` and a non-empty canonical tree;
- every subscription for the same `(streamId,multicastGroupId)` must carry the same canonical tree hash;
- unicast copy identity is `(streamId,subscriptionId,edgeId)`;
- multicast de-dup identity is `(streamId,multicastGroupId,edgeId)`;
- a multicast label without an exact tree is semantic rejection/BLOCKED evidence, never an inferred de-duplication.

Persistence may keep the tree inline with each subscription or normalize it into a group/tree table, but the canonical group/tree identity and equality rules above are mandatory.

### 11.2 CCTV-03 assignment/schedule ownership — ELV5-R8-02

Every `CctvRecordingAssignment` has mandatory `scheduleProfileId`. Every recording schedule segment has the same mandatory `scheduleProfileId`.

```text
recording identity = (encodedStreamId,poolId,copyRole)
schedule selection = assignment.scheduleProfileId
```

The resolver selects only segments with the assignment's profile, expands them deterministically under the captured temporal policy, then unions overlaps for that recording identity. There is **no implicit pool-wide schedule inheritance**. Multiple assignments may intentionally reference the same profile ID.

The schema-24 child model must persist that relation explicitly, whether as `scheduleProfileId` columns on both member tables or an equivalent normalized FK.

### 11.3 Globally unique evaluation identity — ELV5-R8-03

`evaluationId` is the global immutable evaluation identity for ELV5. Schema 24 MUST enforce:

```sql
UNIQUE(evaluation_id)
```

or use `evaluation_id` as the global primary key while retaining node/revision indexes. The existing schematic composite PK does not by itself satisfy this rule.

`loadEvaluationsByIdsBulk` and pointer/evidence references therefore resolve one row per evaluation ID. If an implementation intentionally moves to a composite public identity, that is a new reviewed contract version, not an implementation choice.

### 11.4 One active aggregate root per canonical subject — ELV5-R8-04

For replacement-command aggregates, schema 24 MUST enforce one active root per `(designRevisionId, canonicalSubjectId)` using a partial unique index or equivalent transactionally proven constraint.

Required subjects:

```text
RecordingPoolBindings          -> poolId
RecorderCapacityBindings       -> recorderId
LinkCompositionBindings        -> linkId
PortCapacityBindings           -> switchId
OpticalLinkBindings            -> linkId
RackCapacityBindings           -> rackId
PatchPanelBindings             -> panelId
DoorCalculationBindings        -> doorAssemblyId
ControllerResourceBindings     -> controllerId
FireLoopBindings               -> loopId
NotificationCircuitBindings    -> circuitId
```

An arbitrary binding row ID never permits two simultaneously active roots for the same canonical subject.

### 11.5 CCTV-03 reserve semantics — ELV5-R8-05

`reserveMultiplier` is an exact dimensionless ratio with mandatory domain:

```text
reserveMultiplier >= 1
```

`1` means no additional reserve. Values below `1` are semantic command rejection and must never reduce calculated storage. This rule supersedes older wording saying only “nonnegative ratio”.

Reserve remains separate from evidence uncertainty, redundancy usable fraction and compression/bitrate evidence.

### 11.6 Machine-frozen nested command codecs — ELV5-R8-06

`command-registry.json` is the machine authority for both top-level payload keys and nested schemas. It now contains:

```text
nestedSchemaRegistryVersion
nestedSchemas
commandNestedBindings
semanticConstraints
```

Every one of the 16 operations is bound to its applicable nested schemas. Unknown/missing nested keys and wrong scalar/container types fail closed. `command-examples.json` is recursively validated against these bindings by `check-elv5-project-alignment.py`.

A developer is not permitted to invent nested wire DTO shape during implementation.

### 11.7 CCTV-05 storage-pool identity — ELV5-R8-07

Every recorder assignment carries mandatory `storagePoolId` from public command through persistence and resolver to `CctvRecorderAssignment`.

Effective typed member:

```dart
final class CctvRecorderAssignment {
  final String recorderId;
  final String cameraId;
  final String encodedStreamId;
  final String licenseChannelId;
  final String storagePoolId;
}
```

CCTV-05 selects CCTV-03 storage evidence by that exact pool identity. No “first pool”, recorder-wide implicit pool or UI-selected pool is permitted.

### 11.8 Version encoding — ELV5-R8-08

The canonical integer-to-string bridge in section 6 is part of the input/output/result identity and fingerprint policy. Runtime implementations must test `1 -> "1"` and reject noncanonical aliases.

### 11.9 Fire address claim scope — ELV5-R8-09

The governing uniqueness scope is:

```text
UNIQUE(designRevisionId, addressDomain, address)
```

across all active bindings in the same physical address domain. It is **not** “within one loop binding”. Different physical address domains and different design revisions may reuse the integer address.

### 11.10 LAN-06 dimensional mass — ELV5-R8-10

The effective primitive layer includes:

```dart
typedef Mass = Elv5Quantity<MassDim>;
```

LAN-06 uses:

```dart
Elv5EngineeringValue<Mass>? weight;
Mass? declaredWeightCapacity;
Mass? totalWeight;
```

rather than a dimensionless `Elv5Rational` named `weightKg`. Display conversion to kilograms is presentation only. The ELV6 handoff preserves the `MassDim` quantity and provenance.

## 12. Development-readiness registry and transitive authority pin

`development-readiness-registry.json` is the machine record for ELV5-R8-01…R8-10 and the per-package readiness gate.

Its exact SHA-256 is pinned by `command-registry.json` as `developmentReadinessRegistrySha256`. Because `command-registry.json` is already an exact-head manifest authority and `check-elv5-project-alignment.py` verifies the referenced file hash, the readiness registry is transitively bound into the accepted authority fingerprint.

The human audit is `docs/audit/elv5-eighth-pass-development-readiness-audit.md`; its hash is itself pinned by the readiness registry and verified by CI.

## 13. Implementation-entry decision

After the eighth-pass closure:

```text
P0  GO
P1  GO
P2  READY FOR IMPLEMENTATION
P3  READY FOR IMPLEMENTATION
P4  READY FOR IMPLEMENTATION
P5  READY FOR IMPLEMENTATION
P6  READY FOR IMPLEMENTATION
P7  READY FOR IMPLEMENTATION
P8  ACCEPTANCE DESIGN READY
P9  CLOSURE DESIGN READY
```

`READY FOR DEVELOPMENT` means the specification no longer leaves an implementation choice for the ten audited contract gaps. It does **not** claim that ELV5 production Dart/Drift runtime, migration 24, 27 kernels, 16 codecs, worker runtime or P8/P9 runtime evidence already exist.

## Closure

This amendment closes ELV5-side project-alignment and implementation-entry ambiguity. ELV5 specification status is **READY FOR DEVELOPMENT** while runtime remains **NOT STARTED**. ELV6/ELV7/ELV8 runtime entry remains separately blocked until they reconcile to the accepted ELV5 runtime/source/fingerprint handoff.
