# ELV1/ELV2 Pre-ELV3 Hardening — Implementation Evidence

Status: EXACT-SHA GATE PENDING
Baseline: `main@f05b1e558a93b40928429ca86d91f4daa0cf4ef0`
Branch: `feat/flutter-elv12-pre-elv3-hardening`

## H1 — roadmap/documentation synchronization

Implemented.

- `docs/product/elv-delivery-plan.md` now marks ELV1 and ELV2 closed and ELV3 ready for design/analysis.
- `docs/product/elv-canonical-discipline-model.md` now records the accepted ELV1/ELV2 architecture baseline and identifies ELV3-P0 as the next stage.
- Historical audit/closure evidence remains untouched.

## H2 — repository governance

External owner action remains required.

The connected GitHub integration can inspect branch-protection/ruleset state but cannot modify repository administration settings. The required controls and verification checklist are recorded in:

`docs/audit/elv12-pre-elv3-governance-checklist.md`

Observed baseline state before this hardening: `main` protection disabled and required checks not enforced by repository settings.

ELV3 implementation entry remains governance-pending until the repository owner confirms an equivalent protection/ruleset for `main`.

## H3 — Drift reverse-reference cleanup

Implemented without schema/data changes.

Added explicit relationship names for the six ambiguous foreign keys to `EngineeringPortInstances`:

- topology-group start port;
- topology-group end port;
- outgoing engineering connection;
- incoming engineering connection;
- outgoing internal mapping;
- incoming internal mapping.

Persisted column names are unchanged. `AppDatabase.schemaVersion` remains `17`.

## Bounded diff

Relative to the accepted baseline, intended persistent changes are limited to:

- `apps/mobile/lib/data/database/app_database.dart` — six `@ReferenceName` annotations only;
- `docs/product/elv-delivery-plan.md` — active roadmap metadata;
- `docs/product/elv-canonical-discipline-model.md` — active architecture metadata;
- `docs/product/elv12-pre-elv3-hardening-specification.md` — hardening contract;
- `docs/audit/elv12-pre-elv3-governance-checklist.md` — H2 external-governance handoff;
- this implementation-evidence document.

No ELV3 domain object, `CableRun` ownership change, cable allocation, pathway rule, or physical-routing compatibility logic is introduced here.

## Final acceptance gate

This document is intentionally committed before the final gate. The accepted hardening SHA must pass:

```text
tracked generated-artifact guard
Drift generation
mobile formatting
mobile analyze
mobile tests
engineering_core formatting
engineering_core analyze
engineering_core tests
```

Drift generation must no longer emit the targeted duplicate reverse-reference warnings for `EngineeringPortInstances`.

The exact SHA and run IDs belong in PR metadata after the gate; no repository commit may follow the accepted exact-SHA evidence without rerunning the gate.
