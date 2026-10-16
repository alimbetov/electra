# Electra — ELV8 Authoritative Design Index

Status: DESIGN DRAFT / RUNTIME NOT STARTED
Branch: `feat/flutter-elv8-deliverables-design`
Parent branch: `feat/flutter-elv7-normative-validation-design`
Pinned parent: `6d7aef8349dc04526a3beba16b2e2483bec0009e`

ELV8 owns **manufacturer catalog editions, explainable equipment/configuration selection, engineering BOM/schedules and immutable deliverable assembly/export**. It consumes requirements and evidence from ELV2–ELV7 and must never silently modify those stages to make a candidate fit.

## Entry documents

1. [ELV8 equipment-selection and deliverables design specification](elv8-deliverables-design-specification.md).
2. [ELV8 P0–P9 delivery plan](elv8-p0-p9-delivery-plan.md).
3. [ELV7 authoritative index](elv7-authoritative-spec-index.md) and [ELV7 normative design](elv7-normative-validation-design-specification.md) define the verified-compliance boundary.
4. [ELV6 enclosure/layout design](elv6-enclosure-layout-design-specification.md) defines physical-fit evidence consumed by selection and deliverables.

## Authority hierarchy

1. accepted ELV1–ELV7 project identities, engineering facts, validation and revision evidence;
2. this ELV8 index and ELV8 design specification;
3. ELV8 P0–P9 plan;
4. architecture overview and legacy report/BOM notes.

ELV8 may bind a project requirement to an exact catalog product/configuration edition. It may not rewrite the upstream requirement that produced the selection.

## Stage boundary

```text
ELV2–ELV6 engineered requirements and physical evidence
    +
ELV7 exact normative outcomes/constraints
    ↓
ELV8 selection request
    ↓
versioned manufacturer catalog/configuration candidates
    ↓
hard-constraint filter → explainable soft ranking
    ↓
explicit selection + impact/revalidation closure
    ↓
frozen selection snapshot
    ↓
canonical deliverable bundle
    ↓
PDF / CSV / JSON / future exporter adapters
```

## Non-negotiable decisions

- Exact catalog edition is pinned; historical selection never follows mutable/current catalog data.
- Hard requirements are filtered before scoring. A higher soft score can never compensate for a hard technical violation.
- Candidate ranking is deterministic and explainable, with versioned scoring policy.
- “No candidate” is a valid diagnostic result, not permission to weaken constraints silently.
- A manual noncompliant override is visibly noncompliant and requires explicit disposition/revalidation; it never becomes compliant by label.
- Product selection that changes dimensions, power, topology or other upstream facts enters `PENDING_REVALIDATION`; no recursive hidden recalculation or silent layout rewrite is allowed.
- Engineering quantities/BOM are separate from prices, quotes, procurement and commercial estimate.
- Deliverable exporters read an immutable canonical `DeliverableBundle`, never mutable Flutter provider/widget state.
- Every deliverable row/item remains traceable to project entities, revision, upstream evidence, selected catalog/profile/template editions and canonical bundle hash.
- Large generated files and vendor documents live in file/blob storage; relational storage keeps metadata, refs and hashes.
- Templates are versioned data, not arbitrary executable scripts.

## Runtime entry gate

P0 must pin the accepted ELV7 head and verify exact upstream projections, schema/migration baseline, existing snapshot/freeze APIs and local file/export capabilities. P1/P2 must freeze catalog identity, selection state machine and canonical deliverable snapshot semantics before product ranking or PDF work begins.

All ELV8 P0–P9 runtime packages are currently `NOT_STARTED`. Design completion does not mean any manufacturer catalog, selection result or project deliverable has been qualified.