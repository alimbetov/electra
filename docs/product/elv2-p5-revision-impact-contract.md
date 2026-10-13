# Electra — ELV2-P5 Catalog Revision Impact Preview Contract

Status: implementation contract  
Branch: `feat/flutter-elv2-profile-constraints`  
Parent: `docs/product/elv2-profile-constraints-technical-specification.md`  
Predecessor: ELV2-P4 exact gate `ac612f52b4d2f1df3c76507b1cca300cf8c045ad`

## 1. Purpose

P5 turns catalog comparison into a project-specific, read-only engineering impact preview. It answers one question before P6 is allowed to mutate anything:

> What would this candidate catalog edition invalidate or require the engineer to review in the current project?

P5 does **not** adopt the candidate edition and does **not** migrate persisted ports.

## 2. Authoritative inputs

The preview is computed only from:

```text
ProjectEngineeringReferences
  ├── immutable catalog editions
  └── frozen ComponentReferenceBinding snapshots

ProjectEngineeringTopologySnapshot
  ├── persisted ports
  ├── connections
  └── topology groups

candidate EngineeringReferenceCatalog
```

For P4-created bindings, `ComponentReferenceBinding.placementCommand` contains the exact reviewed placement evidence after commit-boundary topology resolution. That frozen evidence is the P5 placement-revalidation input.

Historical/manual bindings may not contain reviewed placement evidence. Missing evidence is `UNRESOLVED`; it is never inferred or defaulted.

## 3. Binding impact identity

Every affected bound component is represented by one `BoundProfileRevisionImpact`.

The impact must retain:

```text
componentId
profileCode
previous catalog id/version
candidate catalog id/version
revision disposition: CHANGED | REMOVED
semantic ProfileRevisionImpact
bound portIds
connectionIds
topologyGroupIds
placement revalidation result, when applicable
placement blocker reason, when deterministic revalidation is impossible
```

A removed candidate profile is an affected binding. It must never disappear into a catalog-level `removedProfileCodes` list only.

## 4. Removed-profile rule

If a binding references profile `X` and the candidate edition no longer contains `X`:

- create a binding impact with disposition `REMOVED`;
- classify it as both placement-relevant and connection-relevant;
- preserve the binding's exact persisted `portIds`;
- join those ports to affected ELV1 connections and topology groups;
- mark adoption blocked;
- keep `X` in the deduplicated `removedProfileCodes` summary.

There is no candidate profile to run through P2, so the placement state is represented by an explicit blocker reason, not a fabricated compatible result.

## 5. Placement revalidation

For a non-removed profile whose semantic revision affects placement:

```text
frozen P4 placementCommand
        ↓
exact PlacementCandidateContext
        ↓
candidate profile
        ↓
PlacementCompatibilityEngine (P2)
        ↓
COMPATIBLE | WARNING | FORBIDDEN | UNRESOLVED
```

Rules:

1. `FORBIDDEN` blocks adoption.
2. `UNRESOLVED` blocks adoption.
3. `WARNING` remains explicit and requires P6 policy/review; P5 does not silently convert it to compatible.
4. `COMPATIBLE` is only valid when actual reviewed placement evidence exists.
5. If a placement-relevant revision has no frozen placement evidence, the binding impact is unresolved and blocks adoption.
6. Connection-only revisions do not invent a placement result.

P5 revalidates the profile constraints against the frozen reviewed evidence. P6 must still re-read current durable state before any mutation.

## 6. Candidate validity and lifecycle

The candidate catalog is previewed as an immutable proposed edition.

- `candidate.validateForPublication()` errors are retained in the preview and block adoption of the edition.
- a candidate profile that becomes deprecated is surfaced by lifecycle revision and P2 as non-placeable for placement-relevant bindings;
- invalid or legacy-unspecified candidate constraints are never treated as unrestricted.

## 7. ELV1 graph join

Affected graph objects are derived from the binding's exact persisted port identities:

```text
binding.portIds
   ├── EngineeringConnection.fromPortId / toPortId
   └── TopologyGroup.startPortId / endPortId
```

Results are deduplicated and deterministically sorted.

P5 does not inspect CableRun, CableDefinition, pathways or physical routes.

## 8. Preview-level decisions

`CatalogRevisionPreview` must expose at least:

```text
affectedBindingCount
affectedConnectionIds
affectedTopologyGroupIds
removedProfileCodes
candidateValidationErrors
affectsPlacement
affectsConnections
adoptionBlocked
```

`adoptionBlocked` is true when the candidate edition is publication-invalid or any bound impact is removed, forbidden, unresolved, or otherwise lacks evidence required for a placement-relevant revision.

## 9. Determinism

- impacts sorted by `componentId`, then `profileCode`;
- connection ids sorted;
- topology-group ids sorted;
- removed profile codes sorted;
- candidate validation errors retained deterministically;
- no timestamps or generated ids in preview output.

## 10. Mutation boundary

`previewCatalogRevision(...)` is pure application logic.

P5 must perform zero writes to:

- components;
- system memberships;
- reference bindings;
- ports;
- connections;
- topology groups;
- catalog editions;
- placement operation ledger.

All adoption/migration writes belong to P6.

## 11. Acceptance cases

P5 is complete when tests cover at minimum:

1. port/interface change joins exact bound component + connection/group ids;
2. removed profile produces an affected binding and adoption blocker;
3. placement constraint change revalidates frozen P4 evidence and can become FORBIDDEN;
4. placement-relevant change with historical binding and no evidence is UNRESOLVED/blocking;
5. connection-only revision does not fabricate placement compatibility;
6. deprecated/invalid candidate cannot appear safe;
7. unchanged bound profile produces no impact;
8. multiple bindings are deterministically ordered and graph ids deduplicated;
9. preview invocation mutates no project state by construction.

P6 may start only after this contract is green on exact-head CI.
