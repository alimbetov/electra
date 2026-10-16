# ELV5 — Project-wide alignment hardening v1

Status: DESIGN FROZEN / PROJECT ALIGNMENT CLOSED IN ELV5 / RUNTIME NOT STARTED

This amendment closes contradictions found by the project-wide architecture/developer/system-analysis/electrical-engineering review after the sixth implementation-binding pass. It is deliberately narrow: it reconciles active authority, code-layer ownership, canonical engineering oracles, schema/version precedence and downstream handoff. It does not add new process codes or change the physical mathematics of the 27 calculations.

Where this file explicitly conflicts with older ELV5 prose, this file governs. It is subordinate only to accepted ELV1–ELV4 runtime ownership/facts and to a future explicit ELV5 erratum/amendment that names the affected clause.

## 1. Authority-chain closure

The active human-readable authority chain MUST expose the same constraints already present in the machine manifest. The active ELV5 authority therefore includes:

- `implementation-binding-hardening-v1.md`;
- `implementation-binding-registry.json`;
- `repository-contract-registry.json`;
- `runtime-version-registry.json`;
- `algorithm-performance-registry.json`;
- `finding-trace-code-registry.json`;
- the 1500-case combinatorial requirements/plan/constraint/3-wise/system inventories;
- fifth-, sixth- and seventh-pass audits;
- this project-alignment amendment and `downstream-handoff-registry.json`.

A machine authority included in the exact-head manifest but omitted from the human authority map is a specification defect.

## 2. Resolver ownership

Repository-aware input resolution belongs to the application layer. `engineering_core` owns only pure process metadata, typed contracts, calculation/evaluation logic and deterministic engineering primitives.

Normative pipeline:

```text
short capture scope
  -> application InputResolver
  -> immutable sendable typed input
  -> pure engineering_core ProcessDefinition/Kernel
  -> typed output/evaluation draft
  -> guarded application publication
```

Any older example that places `resolveInput(...)` on `Elv5TypedProcessDefinition` is superseded. Pure definitions/kernels must not access DB/Drift/UI/platform state.

## 3. Source-layout policy

Public symbols, process identities, semantic types, layer ownership and dependency direction are frozen. Exact filenames are tracked implementation coordinates, not engineering truth.

A filename/path-only change is permitted with synchronized implementation-binding registry + authority manifest update and unchanged layer ownership/public semantics. Moving a resolver into `engineering_core`, moving a kernel into the data layer, or changing a public symbol/contract is an architecture/specification change.

The nested `engineering_core/lib/src/elv5/...` layout is an accepted bounded-context organization inside the existing package; it is not a new core package or duplicated domain ownership.

## 4. ACS-03 canonical oracle

The only valid frozen positive arithmetic oracle for the stated fixture is:

```text
source = 24.00 V
shared trunk current = 0.30 A + 0.50 A = 0.80 A
shared trunk resistance = 0.50 ohm
shared trunk drop = 0.40 V
branch origin = 23.60 V
lock branch current = 0.30 A
lock branch resistance = 0.30 ohm
lock branch drop = 0.09 V
lock terminal = 23.51 V
minimum terminal requirement = 22.00 V
headroom = +1.51 V
```

`23.45 V` / `+1.45 V` is invalid for these exact inputs. Process contracts, ACS dossier, errata and future executable fixtures must agree on `23.51 V / +1.51 V`. ELV5 still consumes exact ELV4 PWR-03 evidence in production rather than duplicating the physical solver.

## 5. Database schema precedence

The initial ELV5 additive database target is frozen at **schema 24** by `runtime-version-registry.json` and `persistence-schema-contract.md`.

This explicitly supersedes earlier baseline language saying to choose an arbitrary additive version `>23` at implementation time. Schema 24 is an implementation-entry contract, not a suggestion. Future change requires synchronized migration/runtime-version/manifest review.

## 6. Legacy design-version labels

Legacy `1-design` labels and `DESIGN DRAFT` markers in older inventory artifacts are provenance/status history only when a later frozen runtime registry or amendment exists. They cannot authorize production result versions, schema choice or runtime codec versions.

Human-readable indexes must state this mapping so developers do not treat old design labels as competing runtime versions.

## 7. Project roadmap status

Project-level roadmap/status text must distinguish historical planning from current accepted baselines. For the ELV5 branch, the governing reality is:

```text
ELV1 CLOSED / ACCEPTED
ELV2 CLOSED / ACCEPTED
ELV3 merged/accepted prerequisite inherited by ELV4
ELV4 implemented, runtime accepted and merged to main d2b059d4c11a284cdd32965140f6df3c40020c8d
ELV5 DESIGN HARDENED / PROJECT ALIGNMENT CLOSED / RUNTIME NOT STARTED
ELV6–ELV8 design branches exist but require downstream reconciliation to the accepted/final ELV5 authority before runtime entry
```

Older roadmap labels such as “ELV4 blocked” or “ELV5 planned” are historical and must not be used as current authorization state.

## 8. Downstream handoff

`downstream-handoff-registry.json` is the machine contract for ELV5 -> ELV6/ELV7/ELV8.

No downstream runtime may start from an old ELV5 design SHA alone. At downstream reconciliation it must pin:

- the accepted ELV5 runtime/source SHA when available;
- the exact accepted ELV5 authority fingerprint;
- database schema/version contracts actually implemented;
- stable projection/evidence schemas consumed by that stage;
- claim boundaries preventing recomputation of upstream truth.

Existing ELV6/ELV7/ELV8 design branches remain useful design work, but their older pinned ELV5 ancestors are explicitly `RECONCILIATION_REQUIRED_BEFORE_RUNTIME`.

## 9. Stage claim boundaries

The downstream contract remains:

```text
ELV5 -> ELV6: demand/basis/evidence only; ELV6 owns physical layout/fit/constructability
ELV5 -> ELV7: technical evidence only; ELV7 owns verified jurisdictional compliance/applicability
ELV5 -> ELV8: engineered requirements/evidence only; ELV8 owns product selection/BOM/deliverables
```

Examples:

- LAN-06 PASS cannot imply rack fit;
- FA-08 technical policy match cannot imply verified compliance;
- positive optical budget cannot imply ELV8 product suitability;
- equipment selection cannot rewrite historical ELV5 results.

## 10. CI closure sentinels

The exact-head project-alignment gate must fail when any of the following reappears:

- authority index omits the binding/1500/seventh-pass authority layer;
- typed process definition owns repository-aware `resolveInput`;
- pure-kernel/application resolver boundary is weakened;
- source paths are treated as engineering semantics rather than tracked coordinates;
- ACS-03 active process contract/dossier contains the invalid `23.45/+1.45` oracle;
- runtime database version differs from frozen schema 24 without explicit reviewed migration change;
- downstream handoff lacks exact authority-fingerprint pinning requirement;
- downstream runtime is allowed before ELV5 runtime/authority reconciliation;
- roadmap current-state text regresses to ELV4 blocked / ELV5 planned;
- seventh-pass alignment findings are reopened.

## Closure

This amendment closes ELV5-side project-alignment ambiguity. It does **not** claim ELV5 production runtime exists and it does **not** silently rewrite the separate ELV6/ELV7/ELV8 branches. Those branches must consume this handoff contract before their runtime entry gates can open.