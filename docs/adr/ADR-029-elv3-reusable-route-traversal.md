# ADR-029: ELV3 reuses and evolves the existing routing graph through CableTraversal

## Status

Accepted

## Context

Electra already has a mature routing graph in `CableRoutes`, `CableRouteNodes`, `CableRouteSegments`, room/floor routing repositories and editors. Legacy electrical `CableRuns` currently own one `routeId`, and the old domain ties the run to an electrical circuit.

ELV3 requires a common physical model where one installed Cable has one active CableRun per design revision and the CableRun uses an ordered traversal chain over reusable route geometry. The project must avoid both a destructive rewrite of legacy electrical routing and a second parallel geometry engine.

## Decision

Electra keeps one routing kernel.

The existing route graph is evolved into reusable route/geometry infrastructure:

```text
CableRoute
  -> CableRouteNode[]
  -> CableRouteSegment[]
```

Canonical ELV3 cable usage is represented separately:

```text
Cable
  -> CableRun
      -> CableRunTraversal[]
           -> CableRouteSegment
```

`CableRunTraversal` carries ordered usage, direction and later carrier/compartment attachment facts. It does not copy segment geometry.

## Legacy coexistence

Existing electrical rows remain valid:

```text
legacy CableRun
  circuitId
  routeId
```

P3 provides an adapter that exposes the legacy private route as a traversal chain for read/validation purposes without requiring immediate data conversion.

New canonical ELV3 rows use `CableRunTraversals`. New ELV3 writes do not populate legacy `circuitId` ownership and do not introduce a second route graph.

## Reuse semantics

A `CableRouteSegment` may be referenced by zero or many `CableRunTraversal` rows. Shared geometry therefore represents a shared path, while each CableRun retains its own traversal ordering and direction.

Route geometry lifecycle is restrictive while any active traversal references it.

Two traversals are continuous only when:

1. previous end node == next start node; or
2. an explicit accepted handoff connects those endpoints.

Coordinate equality by itself never implies connectivity.

## Migration rules

P3 must preserve existing electrical regression tests before any schema cleanup.

Allowed sequence:

1. add canonical CableRun/CableRunTraversal capability;
2. add legacy adapter;
3. prove restart/regression;
4. optionally adopt selected legacy routes explicitly;
5. remove legacy ownership only in a later independently gated convergence effort.

Forbidden:

- a second ELV-only route graph;
- cloning complete route geometry per canonical CableRun;
- global destructive conversion of existing electrical routes;
- using circuit/network identity to prove physical route continuity.

## Consequences

Positive:

- one geometry kernel for electrical and ELV evolution;
- shared pathway geometry without duplicated coordinates;
- compatibility with current editors and routing tests;
- deterministic physical occupancy and length calculations;
- staged migration instead of all-or-nothing rewrite.

Trade-off:

- P3 needs a compatibility adapter while legacy `CableRuns.routeId` remains present.

This trade-off is intentional and bounded by ELV3 P8/P9 regression gates.
