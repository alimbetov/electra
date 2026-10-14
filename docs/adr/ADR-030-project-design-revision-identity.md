# ADR-030: Project design revisions use stable identities separate from optimistic revision counters

## Status

Accepted

## Context

ELV3 requires reproducible CableRun realizations across engineering design revisions. The current `Projects.revision` field is an optimistic-concurrency counter. It changes when project state changes and therefore cannot serve as a stable engineering revision identity.

Future installation/as-built/commissioning workflows also require design evidence to remain traceable to an immutable design context.

## Decision

Electra introduces a stable project design revision aggregate:

```text
ProjectDesignRevision {
  id
  projectId
  code
  sequence
  state
  basedOnRevisionId?
  revision
  createdAt
  updatedAt
}
```

State machine:

```text
WORKING -> FROZEN -> SUPERSEDED -> ARCHIVED
```

A WORKING revision may also be archived if abandoned before freeze.

## Invariants

1. `id` is stable and is the only FK identity used by revision-sensitive domain records.
2. `code` is human-visible, normalized and unique inside the project.
3. `sequence` is monotonic inside the project and is display/order metadata, not identity.
4. a project has exactly one current WORKING revision.
5. FROZEN revisions are immutable as design baselines.
6. creating a new WORKING revision may reference `basedOnRevisionId`.
7. `Projects.revision` remains an optimistic-lock counter and is never substituted for `ProjectDesignRevision.id`.
8. `CableRun` permits at most one ACTIVE realization per `(cableId, designRevisionId)`.
9. freezing/superseding a project design revision does not mutate Cable identity or ELV2 CableDefinition provenance.

## Persistence

P3 introduces:

```text
ProjectDesignRevisions
- id PK
- project_id FK -> Projects.id
- code
- sequence
- state
- based_on_revision_id? FK -> ProjectDesignRevisions.id
- revision
- created_at
- updated_at
- archived_at?
- origin_device_id
```

Required constraints:

```text
UNIQUE(project_id, code)
UNIQUE(project_id, sequence)
```

The single-WORKING invariant must be transactionally enforced by repository/application logic and, where SQLite schema support permits without harming portability, a supporting partial unique index.

## Bootstrap

When an existing project without design revisions is first opened after P3 migration, create exactly one deterministic bootstrap WORKING revision through migration/repository bootstrap semantics. Reopening the same database must not create another revision.

Bootstrap revision identity must be persisted; it must not be regenerated from project name, timestamp or mutable project revision.

## Consequences

Positive:

- reproducible CableRun history;
- no conflation of business revision identity with optimistic locking;
- clear path to approved/as-built traceability;
- deterministic restart semantics.

Trade-off:

- P3 adds one project-level aggregate and bootstrap migration before canonical CableRun persistence.

The trade-off is accepted because omitting stable revision identity would make historical routing semantics ambiguous.
