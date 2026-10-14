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

This prevents history rewriting and makes restart semantics deterministic.

## C4 — exact P5 project profile set

Replace any ambiguous per-role/implicit profile precedence with one explicit project-owned active profile set.

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
- sequence is stable presentation/evidence order, not rule precedence;
- profileContentHash uses SHA-256 over UTF-8 canonical JSON with schema marker `electra.physical-compatibility-profile.v1`;
- changing the active set is an explicit atomic command and invalidates dependent P5/P6 findings;
- evaluation considers every applicable profile in the active set.

Combination semantics are deterministic:

- categorical allowed sets combine by intersection;
- required minimum intrinsic values combine by maximum of minima;
- permitted maximum intrinsic values combine by minimum of maxima;
- any empty categorical intersection or irreconcilable typed rule combination produces `UNRESOLVED_PROFILE_CONFLICT`, never hidden priority;
- a direct intrinsic prohibition from any applicable profile yields FORBIDDEN if the rule inputs are complete;
- normative/jurisdictional rules are not accepted in this profile type and remain ELV7.

P5 persistence names are frozen:

```text
ProjectPhysicalCompatibilityProfileSets
ProjectPhysicalCompatibilityProfileRefs
```

## Closure

```text
C1 frozen revision write guard       CLOSED
C2 zero-length interface handoff      CLOSED
C3 immutable selection evidence       CLOSED
C4 deterministic P5 profile set       CLOSED
```
