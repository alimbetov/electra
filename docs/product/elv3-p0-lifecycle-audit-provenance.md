# Electra — ELV3 P0.5 Lifecycle, Deletion, Audit and Provenance Contract

Status: DESIGN CONTRACT / P0.5  
Branch: `feat/flutter-elv3-physical-routing-design`  
Depends on: P0.1–P0.4  
Implementation status: NOT STARTED

## 1. Purpose

P0.5 freezes lifecycle, deletion, audit and provenance semantics for ELV3 physical-routing entities before schema design.

The design must guarantee that physical identity and engineering evidence survive restart, that destructive operations cannot silently orphan topology, and that later ELV7 normative evaluation can distinguish persisted facts from rules.

## 2. Lifecycle states

Canonical lifecycle state for project-owned ELV3 records:

```text
ACTIVE
ARCHIVED
```

Hard deletion is permitted only for records that are both unreferenced and not required for historical/audit reconstruction.

No generic `deleted=true` field is required by this contract; implementation may use archival timestamps/state if it preserves these semantics.

## 3. Deletion policy matrix

| Entity | Delete/archive rule |
|---|---|
| `EngineeringConnection` | deletion blocked while active `CableAllocation` references it |
| `CableAllocation` | may be deleted/archived independently if no downstream immutable audit requires retention |
| `Cable` | deletion blocked while active allocations or runs exist |
| `CableRun` | may be removed only together with its owned `CableRoute` in one transaction |
| `CableRoute` | cannot be deleted independently while owned by a run |
| `RouteNode`/`RouteSegment` | route-owned; replaced/deleted only through route mutation transaction |
| `PhysicalChannel` | deletion blocked while active route segments reference it |
| `CableDefinition` edition | immutable and not deletable while any cable references it |
| channel factual profile/source | immutable or versioned while referenced by persisted engineering evidence |

## 4. Referential invariants

The persistence layer MUST enforce or transactionally guarantee:

```text
CableAllocation.connectionId -> existing active EngineeringConnection
CableAllocation.cableId      -> existing active Cable
CableRun.cableId              -> existing active Cable
CableRun.routeId              -> exactly one owned CableRoute
RouteSegment.channelId        -> null or existing active PhysicalChannel
Cable.definitionRef           -> exact immutable CableDefinition edition
```

No cascade may erase project evidence beyond the aggregate boundary explicitly defined above.

## 5. Atomic operations

The following are mandatory transactional boundaries:

### Create routed cable section

```text
create CableRun
create CableRoute
create nodes
create segments
validate geometry
commit all-or-nothing
```

### Delete routed cable section

```text
verify no handoff/junction dependency requiring explicit detach
remove dependent handoff/junction endpoint references
remove segments/nodes/route
remove run
commit all-or-nothing
```

### Create cable allocation

```text
load exact CableDefinition resource namespace
load all active allocations for cable
validate selector
validate overlap / WHOLE_CABLE exclusivity
insert allocation
commit all-or-nothing
```

This boundary is required to prevent concurrent double allocation.

## 6. Audit fields

Every ELV3 project-owned mutable record SHOULD have, directly or through shared metadata:

```text
createdAt
createdBy
updatedAt
updatedBy
archivedAt?
archivedBy?
revision/version token
```

For offline/mobile concurrency the repository must support optimistic conflict detection or an equivalent deterministic retry contract.

## 7. Provenance

### 7.1 Cable provenance

`Cable` must persist exact definition identity, not only a human-readable name:

```text
catalog/profile id
edition/version id
immutable content identity/hash if available
```

A later catalog update MUST NOT silently change an installed cable.

### 7.2 PhysicalChannel provenance

Dimensions/environment facts may originate from:

```text
MANUAL
MEASURED
IMPORTED
CATALOG_DERIVED
MODEL_DERIVED
```

Where available, persist source reference and source revision.

### 7.3 Derived results

Derived values such as route length and fill are not authoritative editable facts. If cached/persisted later, they must retain input revision/hash and rule/profile identity sufficient to detect staleness.

## 8. Restart contract

After database close/reopen the application must reconstruct exactly:

- Cable identity and exact definition binding;
- every active allocation selector and sequence;
- Cable -> CableRun order/continuity;
- CableRun -> CableRoute identity;
- route nodes/segments and channel references;
- channel dimensions/compartments/environment facts;
- audit/provenance fields;
- handoff/junction endpoint fingerprints independent of electrical circuit ownership.

Restart MUST NOT depend on in-memory generated defaults.

## 9. Mutation/staleness rules

Changes to any of the following invalidate downstream physical compatibility results:

```text
CableDefinition edition/facts
CableAllocation selector
CableRun reserve/allowance
CableRoute geometry
RouteSegment laying method/channel
PhysicalChannel dimensions/compartments/environment facts
```

Changing an upstream logical connection endpoint invalidates or blocks affected allocations; it MUST NOT silently retarget them.

## 10. Project isolation

All project-owned records must be derivably scoped to exactly one project. Cross-project references are forbidden even if UUIDs happen to exist.

Repository APIs must validate project ownership at transaction boundaries.

## 11. Failure behaviour

On validation or storage failure:

```text
no partial CableAllocation
no orphan CableRun
no orphan CableRoute
no partial route node/segment chain
no dangling PhysicalChannel reference
```

The caller receives a structured failure; retries must not duplicate records when the same command/idempotency identity is replayed.

## 12. P0.5 acceptance gate

- [x] delete/archive behaviour is explicit for all canonical ELV3 entities;
- [x] CableRun/CableRoute mutation is atomic;
- [x] allocation overlap check is transactional;
- [x] exact cable-definition provenance survives restart;
- [x] channel factual provenance is separated from normative rules;
- [x] project isolation is mandatory;
- [x] downstream results have explicit staleness triggers;
- [x] failure cannot leave partial routing state.
