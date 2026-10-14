# Electra — ELV3 R2 Execution Clarifications

Status: AUTHORITATIVE R2 CLARIFICATION / CLOSED  
Branch: `feat/flutter-elv3-physical-routing-design`

This document removes the final execution ambiguities discovered while preparing the third adversarial audit. It refines `elv3-r2-final-readiness-remediation.md` and wins on conflict.

## C1 — frozen revision write guard

Any revision-scoped canonical entity (`CanonicalCableRun`, `CableRunTraversal` and revision-owned derived evidence) may be created or mutated only while its `ProjectDesignRevision.state == WORKING`.

After FROZEN:

- no reroute, traversal replacement, run supersede/archive or bend-evidence mutation may rewrite that frozen revision's canonical realization;
- historical reads use `DesignRevisionPhysicalSnapshot` as source-of-truth;
- edits proceed only after `CreateNextWorkingDesignRevision` establishes a new WORKING context.

Project-global current Cable/Allocation/Carrier facts may evolve for the new WORKING revision, but never alter the already persisted frozen snapshot.

## C2 — RouteHandoff is interface continuity, not hidden path length

A canonical `RouteHandoff` represents one physical interface between route graphs. Its endpoints MUST describe the same physical interface within the geometry tolerance or through an exact typed adjacency mapping that proves interface equivalence.

A handoff has zero design length. It MUST NOT bridge a measurable physical span. Vertical rise/drop, corridor distance, shaft travel and every other non-zero span require `CableRouteSegment` geometry. Therefore installed-length calculation never hides length inside handoff evidence.

## C3 — resource-selection evidence lifecycle

`CableAllocationResourceSelections` are created atomically by `ReserveCableResources` together with consuming `CableResourceClaims`.

Rules:

- DRAFT has no committed resource selection; it is only an allocation proposal identity;
- Reserve resolves the command selection against exact CableDefinition, persists immutable selection evidence + resolved atom hash, creates claims and transitions DRAFT -> RESERVED in one transaction;
- after RESERVED, selected resources cannot be replaced in-place;
- changing selected resources requires releasing the allocation and creating a new DRAFT allocation identity;
- RELEASED/ARCHIVED keeps selection evidence and terminations, but has zero consuming claims.

## C4 — exact P5 project profile set

P5 uses one explicit project-owned active profile set.

```text
ProjectPhysicalCompatibilityProfileSet {
  id
  projectId
  lifecycleState: ACTIVE | ARCHIVED
  revision
}

ProjectPhysicalCompatibilityProfileRef {
  setId
  sequence
  catalogId
  catalogVersion
  profileCode
  profileContentHash
}
```

Invariants:

- at most one ACTIVE set per project;
- refs resolve to exact same-project immutable ELV2 catalog editions;
- no implicit latest lookup;
- sequence is evidence/display order, not rule precedence;
- profileContentHash = SHA-256 over UTF-8 canonical JSON with marker `electra.physical-compatibility-profile.v1`;
- active-set change is explicit/atomic and invalidates dependent P5/P6 findings;
- every applicable profile participates.

Combination semantics:

- categorical allowed sets -> intersection;
- required minima -> maximum of minima;
- permitted maxima -> minimum of maxima;
- empty intersection/irreconcilable typed rules -> `UNRESOLVED_PROFILE_CONFLICT`;
- direct intrinsic prohibition -> FORBIDDEN when inputs are complete;
- normative/jurisdictional rules are rejected from this profile type and remain ELV7.

Persistence names:

```text
ProjectPhysicalCompatibilityProfileSets
ProjectPhysicalCompatibilityProfileRefs
```

## C5 — DesignRevisionPhysicalSnapshot wire/hash contract

```text
schema marker = "electra.design-revision-physical-snapshot.v1"
canonical value = {
  "schema": marker,
  "designRevisionId": <stable id>,
  "physicalState": <complete embedded snapshot payload>
}
canonical bytes = UTF-8(canonicalEngineeringJson(canonical value))
payloadSha256 = SHA-256(canonical bytes)
stored form = lowercase 64-character hexadecimal
```

Unordered collections are sorted by stable identity before serialization; ordered engineering sequences remain ordered. Restart recomputes the hash and blocks on mismatch. Schema marker changes require explicit versioned readers.

## C6 — resource-selection evidence hash

```text
schema marker = "electra.cable-resource-selection.v1"
canonical value = {
  "schema": marker,
  "cableDefinitionRef": <exact ref>,
  "selection": <typed selection>,
  "resolvedAtoms": <sorted atomic identities>
}
selectionSha256 = SHA-256(UTF-8(canonicalEngineeringJson(canonical value)))
```

Stored selection and resolved atoms are immutable after RESERVE. Restart re-resolves the immutable CableDefinition edition and must reproduce the same atom set/hash; mismatch is a blocking reconstruction/integrity failure.

## C7 — exact P1 CableDefinition semantic shape

P1 CableDefinition extends ELV2 reference data and MUST use canonical ELV2 dictionary codes instead of opaque project strings.

```text
CableDefinition {
  code
  label
  deprecated

  mediaCode
  categoryCode?
  conductorMaterialCode?
  shieldingCode?
  firePerformanceCode?
  environmentClassCodes[]
  installationClassCodes[]
  technicalClassCodes[]

  conductorCount?
  pairCount?
  fiberCount?
  conductorCrossSectionMm2?
  characteristicImpedanceOhm?
  dcResistanceOhmPerKm?
  capacitanceNfPerKm?
  inductanceMhPerKm?
  voltageRatingV?
  outerDiameterMm?
  occupiedAreaMm2?
  minimumBendRadiusMm?
  maximumPullingForceN?

  resourceDefinitions[]
}
```

Rules:

- `code` normalized/unique within exact catalog edition;
- `mediaCode` is required and resolves to ELV2 common signal/cable-media reference vocabulary; it is not a manufacturer SKU;
- optional category/material/shield/fire/environment/installation/technical-class codes resolve through accepted ELV2 reference dictionaries/vocabulary for that catalog/project context;
- counts are integers >= 0; at least one resource model consistent with media is declared;
- numeric physical facts must be finite and > 0 when present, except values whose physical domain explicitly permits zero;
- `occupiedAreaMm2` is required for non-circular constructions when P6 fill is expected; circular cable may derive area from `outerDiameterMm`;
- resourceDefinitions are the authoritative allocatable resource graph from R2-04;
- manufacturer products may map to this definition later in ELV8 but never replace its identity;
- P1 does not embed jurisdictional acceptance thresholds in CableDefinition.

This shape is aligned with `docs/product/elv-reference-data-catalogs.md` cable catalog attributes and reuses ELV2 governance rather than creating a new vocabulary.

## Closure

```text
C1 frozen revision write guard         CLOSED
C2 zero-length interface handoff        CLOSED
C3 immutable selection evidence         CLOSED
C4 deterministic P5 profile set         CLOSED
C5 snapshot wire/hash contract          CLOSED
C6 selection evidence hash              CLOSED
C7 CableDefinition semantic shape       CLOSED
```
