# ADR-004: Physical cable routing is modeled as a graph

## Status
Accepted

## Context
Electra must support cable routes with bends, vertical rises/drops, surface transitions, junction/distribution nodes, conduit requirements, shared conduits/trays and future routing recalculation.

A single `calculatedLength` value or opaque route JSON cannot represent these requirements reliably.

Electrical grouping, a physical cable instance, its spatial route and its protective conduit are different domain concepts.

## Decision

Model physical routing explicitly:

```text
Circuit
  -> CableRun
      -> Route
          -> RouteNode[]
          -> RouteSegment[]

ConduitRun
  -> CableRun[]
```

### RouteNode

Stores a 2.5D position in millimetres and semantic node type.

Initial node types:

- `ENDPOINT`
- `BEND`
- `JUNCTION`
- `TRANSITION`
- `ENTRY`
- `EXIT`
- `RISER`

### RouteSegment

Connects `fromNodeId` to `toNodeId` and describes one installation section. Laying method belongs to the segment because one cable can transition between tray, ceiling conduit, wall chase and other methods.

### Junctions

Branching/distribution semantics are first-class and must not be represented as ordinary bends.

### Conduit

A conduit or tray is a physical channel that may carry multiple cable runs. It is therefore modeled independently from the cable itself.

## Derived values

Cable length is calculated from route-segment geometry plus reserve and termination allowances. Vertical rises/drops are explicit geometric segments.

## Consequences

Positive:

- deterministic recalculation after moving devices or changing heights;
- support for bends, junctions and transitions;
- conduit fill calculations;
- shared-route optimization;
- accurate BOM generation;
- future automatic routing and collision checks;
- better technical drawings and documentation.

Trade-offs:

- more entities and relationships in SQLite/PostgreSQL;
- editor operations require graph-aware validation;
- topology tests become part of the engineering core acceptance gate.
