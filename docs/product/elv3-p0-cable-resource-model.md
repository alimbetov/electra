# Electra — ELV3 P0.3 Cable Resource and Termination Model

Status: REMEDIATED DESIGN CONTRACT / P0-R3 + P0-R4 + P0-R6  
Branch: `feat/flutter-elv3-physical-routing-design`  
Authoritative parent: `docs/product/elv3-p0-system-architecture-remediation.md`  
Implementation status: HOLD UNTIL P0-R10

## 1. Purpose

This document defines the corrected cable-resource model used by `CableAllocation` and aligns it with the accepted ELV2 reference architecture.

It supersedes the first P0.3 where that document treated `CableDefinition` as a potentially independent ELV3 catalog/versioning subsystem or treated the fixed resource enum as exhaustive.

## 2. Reference architecture boundary

`CableDefinition` is a typed engineering profile/definition consumed through ELV2 reference governance.

Canonical identity:

```text
ReferenceSnapshot / project binding
  -> exact CableDefinition/Profile edition
  -> Cable
```

ELV3 MUST NOT create a parallel catalog lifecycle, latest-version mechanism, deprecation policy or project-binding subsystem.

ELV2 remains authoritative for:

- exact catalog/profile edition identity;
- immutability/versioning;
- project pinning/binding;
- provenance/source identity;
- deprecation/retirement;
- explicit adoption/migration.

ELV3 owns physical resource semantics exposed by that exact definition.

## 3. CableResourceDefinition

A cable definition exposes an ordered deterministic resource namespace.

Conceptually:

```text
CableResourceDefinition {
  code
  kind
  index?
  groupCode?
  parentResourceCode?
  allocatable
  terminationRoleHints[]
}
```

Core resource kinds required initially:

```text
WHOLE_CABLE
PAIR
CONDUCTOR
FIBER
CORE_GROUP
SHIELD
DRAIN
PROTECTIVE_EARTH
FUNCTIONAL_EARTH
```

The model is extensible by typed definition-owned resource codes. Runtime arbitrary free-text resource types are prohibited.

## 4. Resource semantics

### WHOLE_CABLE

Consumes the complete cable as one resource. It is mutually exclusive with every partial allocation.

### PAIR

Consumes a definition-declared pair as one atomic allocatable resource unless that exact definition explicitly exposes lower-level independent conductor addressability.

### CONDUCTOR

Consumes one or more individually addressable cores/conductors.

### FIBER

Consumes individually addressable optical fibers.

### CORE_GROUP

A named group declared by the exact definition. It must resolve deterministically to finite atomic resources and cannot be created ad hoc by project/runtime input.

### SHIELD / DRAIN / EARTH resources

These resources are modeled only when the exact cable definition exposes them as engineering-relevant termination resources. Their presence does not imply that they must always be independently allocated.

## 5. CableResourceSelection

`CableAllocation` uses typed resource selection.

Conceptual contract:

```text
sealed CableResourceSelection

WholeCableSelection

IndexedResourceSelection {
  resourceKind
  indexes[]
}

NamedResourceSelection {
  resourceCodes[]
}

DeclaredGroupSelection {
  groupCode
}
```

Canonical state MUST NOT use strings such as:

```text
"1,2,4-6"
"blue/white + blue"
"pair A"
```

as resource identity.

Human labels may exist only as display/report metadata.

## 6. Atomic overlap model

Every selection resolves through the exact definition to a canonical set of resource atoms:

```text
resolve(definitionEdition, selection) -> Set<CableResourceAtom>
```

Overlap is forbidden when two resource-consuming active allocations on the same Cable intersect.

```text
A.atoms ∩ B.atoms != empty
  -> RESOURCE_OVERLAP
```

`WHOLE_CABLE` conflicts with every other active allocation.

Only explicit definition/profile semantics may permit shared signaling. Such a future exception must be typed and versioned; it cannot be inferred from matching labels or discipline.

## 7. CableAllocation contract

```text
CableAllocation {
  id
  projectId
  engineeringConnectionId
  cableId
  resourceSelection
  transitionRef?          // required only for multi-cable continuity
  lifecycleStatus
  revision
}
```

The previous `sequence` field may be retained as ordering metadata for explicit transition chains, but sequence alone never proves continuity.

## 8. CableTerminationMapping

Resource consumption and physical termination are separate concerns.

A complete allocation may require explicit termination mapping:

```text
CableTerminationMapping {
  allocationId
  cableResourceRef
  endpointPortId
  endpointTerminalOrContactRef?
  end: A | B | INTERMEDIATE
  role?
}
```

Examples:

```text
CONDUCTOR:1 -> CTRL.INPUT-01 terminal A
CONDUCTOR:2 -> READER.DATA-A
SHIELD      -> enclosure functional-earth point
```

Termination mapping MUST NOT invent component ports or electrical semantics. Endpoint references must resolve to persisted ELV1 component/port/terminal identities available in the project model.

## 9. Multi-cable realization

Default invariant:

```text
one continuous wired EngineeringConnection
  -> one active CableAllocation
  -> one Cable
```

Multiple cables for one logical connection are allowed only when an explicit physical transition exists and is modeled.

Examples:

- splice;
- terminal block;
- connector/patch boundary;
- explicit junction/termination object.

Where a media converter introduces different ports/media, ELV1 normally creates separate EngineeringConnections rather than one multi-cable connection.

## 10. Structural validity versus engineering compatibility

Structural validity blocks commit:

- definition edition exists and is bound through ELV2;
- resource selection resolves exactly;
- resource atom exists and is allocatable;
- no resource overlap;
- project isolation holds;
- required termination mapping references valid endpoints;
- multi-cable chain has explicit transition evidence.

Engineering compatibility is evaluated later:

- endpoint/media compatibility;
- shielding/fire/environment suitability;
- installation method;
- physical carrier/pathway compatibility;
- bend-radius basis;
- technical fill/segregation basis.

Normative/jurisdictional acceptance remains ELV7.

## 11. Concurrency invariant

Resource allocation must be atomic at repository/persistence level.

Two concurrent commands cannot both commit the same resource atom.

Implementation must use a proven mechanism such as normalized resource rows with uniqueness, serialized cable transaction, optimistic revision retry, or equivalent.

UI-only/domain-only overlap checks are insufficient.

## 12. Four-discipline examples

### CCTV

```text
CAMERA ETH/PoE connection
  -> WHOLE_CABLE
```

### LAN

```text
Outlet rear -> patch-panel rear
  -> WHOLE_CABLE Cat6 permanent-link cable
```

Fiber backbone may allocate explicit fibers from one multi-fiber cable.

### ACS

```text
Cable ACS-001 / 8 conductors
Reader        -> 1,2
Door contact  -> 3,4
REX           -> 5,6
Lock          -> 7,8
```

Termination mapping records where each used conductor terminates.

### Fire

A definition may expose WHOLE_CABLE or indexed conductors. Fire-loop semantics remain ELV1/TopologyGroup semantics; resource model does not own loop identity.

### Fiber genericity fixture

```text
12-fiber cable
Link A -> fibers 1,2
Link B -> fibers 3,4
```

Overlapping use of fiber 2 must fail.

## 13. P0-R3/R4/R6 acceptance

- [x] CableDefinition consumes ELV2 reference/version governance.
- [x] no second ELV3 catalog lifecycle exists.
- [x] resource model is typed and extensible.
- [x] WHOLE_CABLE remains exclusive.
- [x] overlap is atom-based and deterministic.
- [x] termination mapping is first-class.
- [x] multi-cable continuity requires an explicit transition.
- [x] sequence metadata alone does not establish continuity.
- [x] CCTV/LAN/ACS/Fire plus fiber fit the model.

These remediation points are CLOSED subject to P0-R10.