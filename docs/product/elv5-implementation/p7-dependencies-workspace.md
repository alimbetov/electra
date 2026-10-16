# P7 — Incremental dependencies and engineer workspace

Status: DESIGN DRAFT / RUNTIME NOT STARTED
Depends on: Design begins P1/P2; complete integration P3–P6.
Parent: [ELV5 design](../elv5-discipline-calculations-design-specification.md); [process contracts](process-contracts.md).

Inherited implementation and mandatory new extensions: [baseline contract P7](implemented-baseline.md#p7); [pinned evidence](baseline.json). This contract supersedes the original design-only parent assumptions.

## Requirements and planned proof

| Requirement | Required implementation behavior | Planned acceptance |
|---|---|---|
| ELV5-P7-001 | Encode owner/scope-aware consumed dependency keys including missing inputs and membership sets | P7-T01 |
| ELV5-P7-002 | Invalidate exact old+new closures across discipline/shared-source boundaries | P7-T02 |
| ELV5-P7-003 | Guard publication with lifecycle/token/fingerprint and consumed pointer generation checks | P7-T03 |
| ELV5-P7-004 | Implement progressive per-discipline calculation cards with exact revision/scope/source provenance | P7-T04 |
| ELV5-P7-005 | Show full shared-project totals and selected discipline contribution without recalc filtering | P7-T05 |
| ELV5-P7-006 | Route preview/commit/replay/undo/redo and failed-draft retention through application services | P7-T06 |
| ELV5-P7-007 | Implement frozen historical/NOT_CAPTURED comparison and preserve scope-context generation in async reads | P7-T07 |
| ELV5-P7-008 | Cover compact/keyboard/focus/back/finding remediation and stale-versus-failed display | P7-T08 |

## Concrete contract

Technical fingerprint is the canonical consumed facts map, not the full captured project. A missing profile produces a dependency marker so later binding invalidates the blocked result. New set membership and disconnection use set keys and old closure, avoiding phantom/missing invalidation. Unrelated room labels and independent doors/links are required negative controls.

Registry DAG evaluation has no physical numerical feedback loop; it delegates bounded physical solving to ELV4. Batch result publication is coherent with its immutable inputs. RUNNING is transient workspace state and freeze captures committed facts; late publisher cannot revive CURRENT.

Card sequence: process summary → selected inputs/policy → affected equipment/path → calculation steps → findings → before/after. Retain viewport/selection/draft during navigation and conflicts. UI selects subject/scope; it does not mutate static canonical port values or calculate a smaller source budget.

## Exit

P7 runtime acceptance requires its numbered assertions at the same accepted source SHA and its prerequisite gates. This document is a design contract, not proof of source implementation.

## Audit refinements

Execution graph consumes structured upstreamProcesses only. Registered scope/subject binders resolve exact compatible physical/policy contexts, including complete segment sets for DESIGN consumers. Unknown process/binder, invalid scope or cycle rejects registry publication. Dependency notes are explanatory text and cannot be parsed as code.
