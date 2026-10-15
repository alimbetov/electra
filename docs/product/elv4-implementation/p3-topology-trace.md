# P3 — Scenario power graph, validation and trace

Status: IMPLEMENTATION DESIGN DRAFT
Consumes P1 typed inputs and P2 consistent reader. Supplies P4–P7.
Shared rules: [runtime contracts](shared-contracts.md).

## Required work and acceptance

| Requirement | Implementation obligation | Planned acceptance |
|---|---|---|
| ELV4-P3-001 | Build one deterministic derived graph per captured revision/scenario/segment from canonical identities | P3-T01 graph projection |
| ELV4-P3-002 | Resolve availability, alternative-feed selection and transfer direction before connectivity checks | P3-T02 selected backup |
| ELV4-P3-003 | Preserve passive continuity and independently validate power/data direction and domain | P3-T03 mixed-layer/relay |
| ELV4-P3-004 | Detect active cycles, reconvergent supply paths, ambiguous direction and unsupported returns | P3-T04 adversarial graphs |
| ELV4-P3-005 | Check voltage guarantees, AC frequency, DC polarity and supported transfer envelopes | P3-T05 compatibility bounds |
| ELV4-P3-006 | Trace ordered provenance to explicit source boundaries with unresolved frontiers | P3-T06 trace completeness |
| ELV4-P3-007 | Separate topology, realization, capacity and backup dimensions; retain missing-input dependencies | P3-T07 incomplete physical draft |
| ELV4-P3-008 | Read frozen trace entirely from verified captured evidence | P3-T08 R1 trace isolation |

## Core API and output

Proposed pure functions:

```dart
PowerGraphBuildResult buildPowerGraph(PowerInputSnapshot input);
PowerTopologyValidation validatePowerGraph(PowerGraphSnapshot graph);
PowerTraceResult tracePower(PowerGraphSnapshot graph, PowerTraceRequest request);
```

Build result includes graph, unresolved vertices/edges, findings and dependency keys. Validation cannot silently delete an invalid edge to manufacture a radial passing graph. Each edge records kind, source entity identity, input/output ports, active segment, transfer/profile provenance and physical-evidence references. Adjacency and output arrays use canonical identity ordering.

## Algorithm details

1. Validate scoped input capture; duplicate canonical identities with contradictory contents block graph construction.
2. Select conductive external edges with power/dataPower/signalPower layers. Wired does not prove realization; wireless/logical never supplies power.
3. Expand explicit passive mappings and component-local active transfers. Bidirectional port does not mean unconditional two directed active edges: resolve actual source/transfer direction first. Ambiguous direction remains unresolved.
4. Resolve selected alternative feeds and unavailable sources. A switch/UPS transfer must make nonselected feed inactive; merely marking a preferred path does not remove backfeed risk.
5. Validate source/consumer roles and local terminal ownership. Dry-contact control is excluded from supply unless an explicit switched-feed transfer and actual supply terminals exist.
6. Form directed adjacency. Run strongly connected component detection; any nontrivial SCC or self-loop in energized power transfers is unsupported. Passive reciprocal representation must first be interpreted as one physical continuity relation, not manufactured two-edge cycles.
7. In the remaining DAG, propagate capped supply-path multiplicity (0/1/many) and source provenance. Reconverging two paths from the same source remains unsupported radial reconvergence; different sources are unsupported sharing. Acyclic is necessary, not sufficient.
8. Resolve source boundary and guarantee propagation through passive stages and explicit conversion envelopes. Record consumer requirements that have zero or multiple supplies.
9. Attach realization frontiers and shared capacity/protected-output membership without running capacity math in graph validation.

Traversal complexity target O(V+E) per segment for graph build/validation, apart from sorting and retained path/output size. Upstream trace for a selected consumer is scoped to its reachable ancestry; do not enumerate every graph path on an ambiguous graph. Return compact ambiguity findings plus bounded witness paths.

## Compatibility contract

Require source guaranteed minV >= consumer allowed minV and source guaranteed maxV <= consumer allowed maxV. Interval overlap alone fails. Check AC/DC, required frequency bounds, DC polarity and terminal mapping. Explicit converter output envelope replaces its input domain only through the transfer definition.

A source voltage range that fits the port does not prove terminal voltage under load. P6 owns load-terminal feasibility. Missing tolerance/frequency/polarity is UNRESOLVED if required, not compatible by default. No voltage-domain conversion through passive patching.

Port compatibility checks preserve existing canonical connection constraints. Graph validation can identify a legacy incomplete state without making a rejected future connection legal.

## Trace contract

Request contains scoped revision/scenario/segment, subject and UPSTREAM/DOWNSTREAM/BOTH. Result contains source boundary, ordered edge/transfer IDs, component/input/output identities, physical refs, reason for active selection, findings and unresolved frontier. Cycles terminate with witnesses; missing source terminates explicitly.

Show one project graph with selected-system highlighting. Shared budgets and other-system consumers remain attached to source group evidence. Frozen trace verifies companion/manifest hashes and uses only captured canonical/profile/physical inputs; current mutable row deletion does not erase historical trace.

## Acceptance and work order

Implement scenario resolver → graph builder → direction/passive normalization → SCC/path multiplicity → compatibility → trace. P3-T04 includes a cycle, self-loop, same-source diamond, two-source feed and closed signal loop with radial power. P3-T05 uses source 22–26V versus consumer 23–25V to reject mere overlap; exact bound containment passes. P3-T07 preserves topology with missing cable and blocks physical delivery only. P3-T08 modifies R2/current catalog and proves identical R1 trace/provenance.

Exit: each consumer has an explained selected source or concrete unresolved/incompatible state, with graph facts shared identically by all six processes.
