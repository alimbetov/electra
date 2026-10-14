# Electra — ELV3 P0.8 Persistence / Schema Proposal

Status: DESIGN PROPOSAL / P0.8  
Branch: `feat/flutter-elv3-physical-routing-design`  
Depends on: P0.1–P0.7  
Implementation status: NOT STARTED

## 1. Purpose

P0.8 translates the frozen ELV3 domain contracts into a persistence proposal. This is not yet a migration implementation. It defines tables, keys, indexes, ownership and transaction boundaries that P1–P4 must follow.

## 2. New canonical tables

### 2.1 CableDefinitions

```text
id
project_or_catalog_scope
code
name
medium
construction
pair_count
conductor_count
fiber_count
outer_diameter_mm
minimum_bend_radius_mm
fire_performance_class
environment_class
catalog_id
edition_id
content_hash
created_at
```

Rules:

- immutable exact-edition identity;
- referenced editions cannot be mutated in place;
- project Cable references exact row/revision.

### 2.2 CableDefinitionCoreGroups

```text
id
cable_definition_id
code
resource_kind
member_indexes_serialized_or_child_rows
```

Prefer normalized child rows if selector membership must be queried frequently.

### 2.3 Cables

```text
id
project_id
label
name
cable_definition_id
state
created_at
created_by
updated_at
updated_by
archived_at?
revision
```

Constraints:

```text
UNIQUE(project_id, label) WHERE active
FK cable_definition_id -> CableDefinitions
```

### 2.4 CableAllocations

```text
id
project_id
engineering_connection_id
cable_id
resource_kind
sequence_no
role
state
created_at
created_by
updated_at
updated_by
revision
```

Selectors are persisted separately; no free-form selector string is canonical.

### 2.5 CableAllocationResources

Canonical normalized representation:

```text
allocation_id
resource_kind
resource_index
```

Examples:

```text
PAIR 1
CONDUCTOR 3
FIBER 12
```

For `WHOLE_CABLE`, store the allocation kind and zero child resources.

For `CORE_GROUP`, persist both group identity/provenance and resolved atomic members sufficient to enforce overlap deterministically.

Recommended columns:

```text
allocation_id
group_code?
resolved_resource_kind
resource_index
```

Unique/index strategy must allow overlap detection inside one Cable transaction.

### 2.6 CableRuns

Target canonical shape:

```text
id
project_id
room_id_or_spatial_context
name
cable_id
route_id
sequence_no
reserve_percent
termination_allowance_mm
state
created_at
created_by
updated_at
updated_by
revision
```

Legacy `circuit_id` remains transitional only during P3 migration and is not part of final canonical identity.

Constraints:

```text
FK cable_id -> Cables
UNIQUE(route_id)
INDEX(cable_id, sequence_no)
```

### 2.7 PhysicalChannels

Current table is extended or migrated toward:

```text
id
project_id
name
kind
spatial_context_type
room_id?
floor_id?
riser_or_shaft_id?
width_mm?
height_mm?
diameter_mm?
usable_area_mm2?
environment_class?
installation_class?
source_type?
source_ref?
source_revision?
state
revision
```

At least one valid spatial context must be present according to kind/context rules. `room_id` is not universally mandatory.

### 2.8 PhysicalChannelCompartments

```text
id
physical_channel_id
code
width_mm?
height_mm?
usable_area_mm2?
sequence_no
```

RouteSegment may eventually bind to a specific compartment rather than only parent channel.

### 2.9 Route segment channel binding

Preferred target:

```text
CableRouteSegments.physical_channel_id nullable
CableRouteSegments.physical_channel_compartment_id nullable
```

Invariant:

- compartment, if present, belongs to referenced channel;
- segment may have neither for surface/chase/free routing;
- no segment references two channels.

## 3. Existing tables retained

The mature geometry foundation remains:

```text
CableRoutes
CableRouteNodes
CableRouteSegments
SurfacePatches
SurfaceEdges
SurfaceAdjacencies
Openings
SpatialFeatures
RoutingJunctions
FloorRoutingHandoffs
```

P0.8 does not authorize a route-geometry rewrite.

## 4. Transitional migration columns/tables

During P3:

```text
CableRuns.cable_id       nullable initially
CableRuns.circuit_id     retained temporarily
JunctionConnections.circuit_id retained as provenance
```

Recommended migration mapping table:

```text
Elv3MigrationMappings {
  source_type
  source_id
  target_type
  target_id
  status = RESOLVED | REVIEW_REQUIRED
  reason?
  created_at
}
```

Unique source identity prevents duplicate rerun creation.

## 5. Foreign-key and deletion rules

Use restrictive semantics by default:

```text
CableDefinition <- Cable          RESTRICT
Cable <- CableAllocation          RESTRICT
Cable <- CableRun                 RESTRICT
CableRun <-> CableRoute           aggregate-controlled
PhysicalChannel <- RouteSegment   RESTRICT
EngineeringConnection <- Allocation RESTRICT
```

Cascade is acceptable only inside strict route-owned child tables:

```text
CableRoute -> RouteNodes
CableRoute -> RouteSegments
CableAllocation -> selector child rows
PhysicalChannel -> compartment rows only when channel deletion itself is allowed
```

## 6. Allocation overlap enforcement

SQLite/Drift cannot express all selector-overlap semantics as simple foreign keys.

Required repository transaction:

```text
BEGIN
  load cable + exact definition
  load active allocations/selectors for cable
  resolve requested selector -> atomic resource set
  reject WHOLE_CABLE conflict
  reject set intersection
  insert allocation + selector rows
COMMIT
```

If concurrent writers are possible, repository serialization/optimistic revision retry must guarantee that two successful transactions cannot claim the same atomic resource.

A database uniqueness strategy on normalized atomic resources should be added where feasible:

```text
UNIQUE(cable_id, resolved_resource_kind, resource_index)
```

This requires materializing cable_id on allocation-resource rows or equivalent indexed projection.

## 7. Required indexes

At minimum:

```text
Cables(project_id, state)
Cables(project_id, label)
CableAllocations(cable_id, state)
CableAllocations(engineering_connection_id, state)
CableAllocationResources(allocation_id)
CableAllocationResources(cable_id, resolved_resource_kind, resource_index)
CableRuns(cable_id, sequence_no)
CableRuns(project_id, room/spatial-context)
CableRouteSegments(physical_channel_id)
PhysicalChannels(project_id, spatial context)
```

## 8. Revision/staleness

Canonical mutable roots carry `revision`.

Compatibility input fingerprint should be derived from exact revisions/identities of:

```text
Cable.definition edition
CableAllocation selector
CableRun
CableRoute geometry
PhysicalChannel / compartment
selected engineering profile
```

Persisted compatibility results, if introduced, are cache/evidence records and never source-of-truth facts.

## 9. Repository transaction boundaries

Mandatory application operations:

```text
createCable
archiveCable
allocateCableResources
releaseCableAllocation
createRunWithRoute
replaceRunRoute
removeRunWithRoute
create/update PhysicalChannel facts
attach/detach RouteSegment channel
migrateLegacyRun
```

Each command validates project isolation and relevant revisions before commit.

## 10. Schema-version execution order

Recommended delivery, not final version numbers:

```text
P1 schema A
  CableDefinition + Cable

P2 schema B
  CableAllocation + resources + overlap guards

P3 schema C
  CableRun.cable_id + migration mapping + dual-read transition

P4 schema D
  PhysicalChannel facts + compartments

P8 cleanup schema
  remove legacy circuit ownership after migration closure
```

This prevents a monolithic schema change and preserves bisectability.

## 11. P0.8 acceptance gate

- [x] tables reflect P0.1/P0.2 cardinalities;
- [x] selectors are normalized and not free-form strings;
- [x] CableRun canonical FK targets Cable;
- [x] PhysicalChannel supports non-room spatial context;
- [x] restrictive FK policy prevents silent evidence loss;
- [x] route geometry tables are retained;
- [x] migration can run incrementally;
- [x] indexes exist for allocation, run and channel hot paths;
- [x] exact edition/revision provenance can survive restart.
