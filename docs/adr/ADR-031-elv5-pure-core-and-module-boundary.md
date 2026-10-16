# ADR-031 — ELV5 pure-core and module boundary

Status: Accepted for ELV5 design entry  
Date: 2026-10-16

## Context

ELV5 introduces 27 discipline-specific calculation processes plus exact numeric/evidence primitives, while the existing `engineering_core` package historically exposes many source files through a relatively flat `lib/src` layout.

The ELV5 design also requires a strict separation between:

- pure engineering calculation semantics;
- application-layer capture/input resolution/orchestration;
- Drift persistence adapters;
- Flutter/UI projection.

Without an explicit decision, a nested `src/elv5/...` source layout could be mistaken for a new core package or for a filename-level engineering contract, and repository-aware input resolution could leak into the pure domain layer.

## Decision

ELV5 remains inside the existing `packages/engineering_core` package for pure engineering semantics, but uses a bounded-context source namespace:

```text
packages/engineering_core/lib/src/elv5/
  numeric/
  evidence/
  canonical/
  time/
  geometry/
  findings/
  processes/
    cctv/
    lan/
    acs/
    fire_alarm/
```

Application-owned ELV5 orchestration/resolution remains outside that package boundary:

```text
apps/mobile/lib/application/elv5/
  calculation/
  dependencies/
  commands/
  revision/
  query/
```

Persistence remains under the data layer, and UI remains under the UI layer.

The normative dependency direction is:

```text
Flutter/UI
  -> application orchestration / InputResolver
  -> repository interfaces / capture projections
  -> Drift adapters

application InputResolver
  -> immutable typed ELV5 input
  -> engineering_core pure ProcessDefinition / Kernel
  -> typed output / evaluation draft
  -> application guarded publication
```

`engineering_core` MUST NOT import Flutter, Drift/SQLite, repository implementations, workspace controllers or platform services for ELV5 calculation execution.

Repository-aware `resolveInput(...)` is not a method on the pure ELV5 process definition. Input resolution is application-owned.

## Source-path semantics

Public process codes, public/type symbols, semantic input/output contracts, layer ownership and dependency direction are architectural contracts.

Exact source filenames are **tracked implementation coordinates**, not engineering truth. A path-only move/rename is allowed only when:

1. public symbols and typed semantics remain unchanged;
2. layer ownership and dependency direction remain unchanged;
3. `implementation-binding-registry.json` is updated in the same change;
4. the ELV5 authority manifest/fingerprint is regenerated;
5. source/test/evidence mappings do not retain obsolete paths.

Moving a resolver into `engineering_core`, moving a kernel into data/UI, or changing semantic public symbols is not a path-only refactor; it requires architecture/specification review.

## Rationale

The nested bounded-context layout:

- prevents a flat 27-process namespace from becoming unmanageable;
- keeps exact engineering math reusable outside Flutter;
- makes repository/UI leakage mechanically reviewable;
- allows process-local helpers to remain private;
- preserves the existing package boundary instead of creating a second competing engineering core;
- keeps file organization evolvable without treating filenames as physical-engineering semantics.

## Consequences

Positive:

- P1–P6 implementations have a clear package/layer home;
- pure kernels can be tested as Dart without Flutter/SQLite;
- worker-isolate execution can operate on immutable sendable inputs;
- source layout can evolve through controlled registry updates;
- architecture is consistent with ELV5 implementation-binding/performance hardening.

Costs:

- application resolvers require explicit DTO/domain mapping;
- the implementation-binding registry must be maintained on path moves;
- cross-layer convenience imports are intentionally forbidden.

## Rejected alternatives

### Keep all ELV5 files flat under `engineering_core/lib/src`

Rejected because 27 process implementations plus shared primitives would produce poor ownership/navigation and increase accidental coupling.

### Create a second independent ELV5 core package

Rejected for the initial runtime because the existing `engineering_core` package is already the shared pure-domain foundation. A second core would create avoidable package-boundary duplication.

### Put repository-aware `resolveInput()` on `ProcessDefinition`

Rejected because it would either couple the pure definition to application/data abstractions or hide repository behavior behind a nominally pure interface.

### Freeze filenames as immutable engineering semantics

Rejected because engineering reproducibility depends on process/version/input/output/evidence/hash semantics, not repository paths. Paths are traceability coordinates and remain authority-fingerprinted through the binding registry.

## Verification

ELV5 CI must verify:

- pure process definitions/kernels have no DB/UI/platform dependency;
- application `InputResolver` owns input assembly;
- tracked definition/resolver paths match the implementation-binding registry when runtime source exists;
- path-only changes regenerate the authority fingerprint;
- source-path changes do not alter process identity or calculation hashes unless a semantic versioned change is intended.
