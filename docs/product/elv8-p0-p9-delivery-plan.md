# ELV8 — P0–P9 delivery plan

Status: DESIGN DRAFT / ALL RUNTIME PACKAGES OPEN
Branch: `feat/flutter-elv8-deliverables-design`
Pinned upstream ELV7: `6d7aef8349dc04526a3beba16b2e2483bec0009e`
Specification: [design](elv8-deliverables-design-specification.md).

| Package | Scope | Mandatory outputs | Depends on |
|---|---|---|---|
| P0 | Baseline and final-stage boundary | accepted ELV7 head/schema; upstream requirement/evidence projection matrix; export/file baseline | Accepted ELV1–ELV7 |
| P1 | Catalog and template editions | immutable manufacturer catalog/product/configuration identities; import schema; template editions; provenance/hash | P0 |
| P2 | Selection persistence and commands | request/constraint/candidate/decision schema; exact command registry; replay/UoW/history; stale/freeze hooks | P1 + shared runtime |
| P3 | Candidate filtering and ranking | hard filter; unknown semantics; configuration/accessory resolver; versioned explainable soft scoring | P1/P2 |
| P4 | Selection impact and revalidation | decision state machine; impact projection; upstream owner handoff; pending/stale/noncompliant/validated closure | P2/P3 + ELV4–ELV7 adapters |
| P5 | Canonical engineering outputs | equipment schedule, BOM quantities, cable schedule, layout/compliance sections, stable sorting/traceability | P2–P4 |
| P6 | Immutable bundles and exporters | canonical bundle snapshot/hash; template mapping; JSON/CSV/PDF exporter ports; artifact metadata | P5 + file/export adapters |
| P7 | Selection and deliverables workspace | candidate diagnostics/compare/impact/freeze; bundle readiness/preview/trace/export/history | P2–P6 |
| P8 | Integrated qualification | import trust, determinism, revalidation, replay/rollback/race/restart/freeze/export/performance evidence | P0–P7 |
| P9 | Final reconciliation/publication | exact-head requirement/code/test matrix; final ELV chain handoff; limitations and publication manifest | P8 |

## P0 — accepted baseline

Pin exact ELV7 accepted source, database migration origin and upstream projections. Enumerate every requirement/fact ELV8 may consume and every owner command that must be invoked when selection changes an assumption.

Also prove available local file/blob/export infrastructure. ELV8 must not start with an exporter that directly reads live widgets/providers.

## P1 — immutable catalogs and templates

Freeze:

- manufacturer/catalog/product/product-revision/configuration IDs;
- typed technical capability representation;
- compatibility/accessory graph semantics;
- import schema/version/unit normalization;
- catalog publication/retirement/historical-read rules;
- template edition/schema/version/hash;
- untrusted import and large vendor-document boundary.

Selection-critical values must be structured and typed; PDF prose is not sufficient evidence.

## P2 — selection storage and commands

Implement normalized request, constraints, candidate snapshot/results, decision/components, impact/revalidation refs and current guarded pointers. Freeze exact project command registry/codecs before P3.

All mutations use existing command replay/history/UoW. Completed decisions and candidate snapshots are immutable evidence; current selection pointers can move only with expected generation/revision checks.

## P3 — deterministic selection engine

Implement:

- hard constraint evaluation before ranking;
- `SATISFIED/VIOLATED/UNKNOWN/NOT_APPLICABLE`;
- no pass on missing hard facts;
- deterministic accessory/configuration closure and cycle rejection;
- explicit “no eligible candidate” diagnostics;
- versioned soft scoring and visible contribution breakdown;
- stable-ID tie-break independent of load order;
- canonical candidate/request hashes.

Black-box ML ranking is not an authoritative initial implementation path.

## P4 — impact and revalidation closure

Implement selection lifecycle:

`DRAFT → SELECTED_PENDING_IMPACT → [PENDING_REVALIDATION] → VALIDATED → FROZEN`, plus `NONCOMPLIANT_OVERRIDE`, `STALE`, `SUPERSEDED`.

Selection impact must identify physical, power, capacity and normative fact changes. Earlier stages are updated/recalculated only through their owner interfaces. No ELV8 repository writes into ELV2–ELV7 tables.

A product may not be normally frozen/finalized while required upstream revalidation remains stale or blocked.

## P5 — canonical schedules and BOM

Build deterministic data models for:

- equipment schedule;
- engineering BOM quantities/configuration components;
- cable schedule using ELV3 facts;
- enclosure/rack schedule using ELV6 facts;
- calculation references using ELV4/ELV5 evidence;
- compliance matrix using ELV7 evidence;
- selection rationale and source manifest.

Every line has stable identity/order and traceability. Engineering quantity remains independent of unit price/currency/vendor quote.

## P6 — immutable deliverable bundle and export

Assembler first creates/validates/persists an immutable canonical bundle and hash. Renderers then receive only that bundle.

Initial qualification path:

1. canonical JSON;
2. CSV BOM/schedules;
3. PDF adapter with structural/golden tests when implementation dependency is selected;
4. future XLSX/DXF/etc. adapters without changing engineering truth.

Generated files store path/object ref, MIME, size, artifact hash, exporter/version/options and source bundle hash. Renderer retry uses the same bundle snapshot.

## P7 — engineer workspace

Selection UI must show hard eligibility before score, constraint evidence, candidate comparison, configuration tree, impact preview and explicit pending/stale/noncompliant state.

Deliverables UI must show readiness blockers, exact template edition, canonical preview, row-to-source traceability, bundle history/diff, export artifacts and frozen historical view.

No green/final state while mandatory ELV7 validation or selection revalidation is blocked.

## P8 — integrated qualification

At one exact SHA record code/migration/test/CI evidence for:

- malformed/untrusted catalog import rejection;
- immutable catalog/template editions;
- hard filter and missing-data fail-closed behavior;
- deterministic candidate ordering/hash;
- accessory closure/cycle cases;
- no-candidate diagnostics;
- soft and noncompliant override semantics;
- impact and explicit upstream revalidation;
- stale propagation;
- replay/duplicate command/rollback/restart;
- concurrent selection/upstream mutation CAS rejection;
- R1 freeze → R2 catalog/project changes → historical R1 reproduction;
- deterministic BOM/schedules/bundle hash;
- artifact generation only from immutable bundle;
- JSON/CSV and implemented PDF qualification;
- file metadata/hash/missing-artifact handling;
- project-scale selection/bundle/export performance.

Planned fixture IDs are not evidence until executed.

## P9 — final ELV chain closure

Reconcile ELV8 requirements ↔ source projections ↔ code ↔ migrations ↔ tests ↔ CI at exact accepted SHA and publish:

- supported catalog/capability/selection matrix;
- unsupported/unknown/manual selection cases;
- exporter/template support matrix;
- final ELV2–ELV8 provenance chain;
- known limitations and future procurement/estimate boundary;
- accepted canonical bundle schema/version;
- accepted source SHA and evidence manifest.

## Current ledger

| Package | Design | Runtime | Evidence |
|---|---|---|---|
| P0 | DRAFT | NOT_STARTED | — |
| P1 | DRAFT | NOT_STARTED | — |
| P2 | DRAFT | NOT_STARTED | — |
| P3 | DRAFT | NOT_STARTED | — |
| P4 | DRAFT | NOT_STARTED | — |
| P5 | DRAFT | NOT_STARTED | — |
| P6 | DRAFT | NOT_STARTED | — |
| P7 | DRAFT | NOT_STARTED | — |
| P8 | DRAFT | NOT_STARTED | — |
| P9 | DRAFT | NOT_STARTED | — |

Default runtime sequence: P0 → P1 → P2 → P3 → P4 → P5 → P6 → P7 → P8 → P9. Export/template fixture design and UX prototyping may begin earlier, but production publication remains gated by accepted selection and validation dependencies.