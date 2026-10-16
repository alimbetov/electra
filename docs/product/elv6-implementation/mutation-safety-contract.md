# ELV6 — Placement and collection mutation safety contract

Status: **DESIGN HARDENED / RUNTIME NOT STARTED**  
Authority: `elv6-authoritative-spec-index.md` → code-level runtime contract → this safety contract → command registry/examples.

This document closes two mutation hazards that are easy to miss in a visual layout editor:

1. a client/widget must not author geometry that can be derived from canonical subject/surface facts;
2. replacement of a collection must not orphan active references.

The rules below are normative and fail closed.

---

## 1. Client authors placement intent; server owns derived geometry

Public `PLACE_LAYOUT_SUBJECT` and `MOVE_LAYOUT_SUBJECT` accept one strict `placementSpec` discriminated union. They do **not** accept `occupiedEnvelope`, `rackSpan`, `dinSpan` or `sourceProposalId`.

Reason: those values are derived/provenance facts. Accepting them from the client creates contradictory representations and lets a compromised/buggy widget under-report the physical envelope to bypass collision checking.

Stable rejection code for forbidden derived fields:

```text
ELV6_SERVER_DERIVED_GEOMETRY_ON_WIRE
```

Machine contract token: `SERVER_DERIVED_GEOMETRY`.

### 1.1 PlacementSpec closed union

Initial payload schema version 1 supports exactly:

```text
FREE_3D
RACK_U
DIN
SURFACE_2D
```

Unknown kind or unknown nested key fails before owner mutation.

#### FREE_3D

Use only on a surface/profile that explicitly permits free orthogonal placement.

```json
{
  "kind": "FREE_3D",
  "mountingSurfaceId": "backplate-01",
  "originUm": [100000, 200000, 30000],
  "orientation": "XYZ_POSITIVE"
}
```

The server resolves exact subject definition and derives canonical pose/body/service/protrusion envelopes.

#### RACK_U

```json
{
  "kind": "RACK_U",
  "mountingSurfaceId": "rack-front-rails",
  "firstU": 12,
  "lane": "FRONT",
  "selectedRailDepthUm": 650000
}
```

`heightU`, physical body envelope and connector/service protrusions come from the exact subject definition. Client cannot supply `heightU` to make the item smaller.

`selectedRailDepthUm` is allowed only when the mounting profile declares a user-selectable rail position/range; otherwise it is rejected as inapplicable.

#### DIN

```json
{
  "kind": "DIN",
  "mountingSurfaceId": "din-01",
  "position": 4
}
```

Module span/physical width comes from the exact subject definition. Client cannot supply width/module count.

#### SURFACE_2D

```json
{
  "kind": "SURFACE_2D",
  "mountingSurfaceId": "door-inner-01",
  "uUm": 120000,
  "vUm": 350000,
  "orientation": "ROTATE_90"
}
```

The server transforms the anchor through the canonical surface frame and derives occupied/service envelopes.

### 1.2 Server derivation order

For PLACE/MOVE, before persistence the semantic backend performs:

```text
1 resolve host owner/revision
2 resolve exact mounting surface
3 resolve exact immutable subject physical definition
4 decode strict placementSpec variant
5 validate variant is supported by surface + subject mounting modes
6 derive canonical pose
7 derive body occupied AABB
8 derive connector protrusion/service/removal/airflow envelopes
9 derive rack U / DIN interval when applicable
10 evaluate intrinsic preconditions required for mutation policy
11 resolve old/new dependency closures
12 persist canonical derived values atomically
```

The persisted placement may store derived pose/envelopes/spans for query speed and reproducibility, but they are **server-derived materialized facts** tied to:

```text
placementSpecHash
subjectDefinitionHash
surfaceFingerprint
geometryBackendVersion
```

A mismatch between stored derivation metadata and canonical recomputation is data corruption, not a new valid interpretation.

### 1.3 Proposal provenance

`sourceProposalId` is never accepted from a manual PLACE/MOVE payload.

It is written internally only by `ACCEPT_LAYOUT_PROPOSAL` for proposal items actually committed in that acceptance UoW. This prevents manual edits from impersonating solver-generated evidence.

---

## 2. Referenced collection member removal is fail-closed

Replacement commands operate on sets but must respect active references.

Stable rejection code:

```text
ELV6_REFERENCED_MEMBER_REMOVAL
```

Machine contract token: `REFERENCED_MEMBER_REMOVAL`.

### 2.1 REPLACE_MOUNTING_SURFACES

Removing/re-identifying a surface is rejected while any active placement, zone/feature attachment or proposal-current dependency refers to it, unless the change is part of one explicitly supported coordinated multi-owner UoW that remaps/releases every reference atomically.

The server compares old and new surface identity sets and calculates:

```text
removed = oldSurfaceIds - newSurfaceIds
referencedRemoved = removed ∩ activeReferenceSurfaceIds
```

`referencedRemoved != ∅` → reject before any write.

A client-provided “force” flag is not supported.

### 2.2 REPLACE_CABLE_ENTRIES

Removing an entry with an active cable-end assignment is rejected. Engineer must first release/remap the assignment, or use an explicitly qualified coordinated operation if one is introduced later.

```text
removedEntries = oldEntryIds - newEntryIds
assignedRemoved = removedEntries ∩ activeAssignedEntryIds
```

`assignedRemoved != ∅` → `ELV6_REFERENCED_MEMBER_REMOVAL`.

### 2.3 REPLACE_LAYOUT_ZONES

Zone replacement is identity-aware. Removal is allowed only if the zone is not a direct referenced target required by another canonical object. All old+new zone geometry participates in invalidation even when no FK reference exists.

### 2.4 Technical profile release

`RELEASE_LAYOUT_TECHNICAL_PROFILE` cannot remove a profile binding if active canonical state would become semantically undecodable or violate an invariant that requires an exact profile identity. The operation returns a structured blocked-reference set; it does not silently fall back to “latest” or defaults.

---

## 3. No client-authored materialized physical facts

The following categories are server-owned whenever derivable from canonical input:

```text
occupied body AABB
rack span length
DIN span length
connector protrusion world envelope
service/removal world envelope
airflow keepout world envelope
resolved physical subject definition hash
source proposal provenance
calculated collision set
calculated dependency closure
current-pointer generations after commit
```

Public commands may carry expected generations/revisions for CAS, but never the replacement value of these facts.

---

## 4. Strict nested codec behavior

Every `placementSpec` variant has an exact key set. Example:

```text
FREE_3D   = kind,mountingSurfaceId,originUm,orientation
RACK_U    = kind,mountingSurfaceId,firstU,lane,selectedRailDepthUm
DIN       = kind,mountingSurfaceId,position
SURFACE_2D= kind,mountingSurfaceId,uUm,vUm,orientation
```

Nullable keys are still schema-defined keys; omission versus explicit null is specified by the nested codec. Unknown keys are rejected so a typo cannot be silently ignored.

The exact nested schema is versioned independently from the top-level command envelope only when compatibility requires it. Initial implementation uses payload schema v1 and code-owned nested v1 codecs.

---

## 5. Required acceptance cases

P2/P8 must include at least:

```text
PLACE with forged occupiedEnvelope -> ELV6_SERVER_DERIVED_GEOMETRY_ON_WIRE
MOVE with forged rackSpan/dinSpan -> ELV6_SERVER_DERIVED_GEOMETRY_ON_WIRE
manual PLACE with sourceProposalId -> ELV6_SERVER_DERIVED_GEOMETRY_ON_WIRE
DIN placement width derived from subject definition
RACK placement heightU derived from subject definition
subject definition changes -> placement/evaluation stale through definition hash
surface removal while referenced -> ELV6_REFERENCED_MEMBER_REMOVAL
cable entry removal while assigned -> ELV6_REFERENCED_MEMBER_REMOVAL
successful removal after references released
replacement failure leaves old collection/references unchanged after reopen
proposal acceptance writes sourceProposalId internally only
```

These are runtime qualification requirements, not merely codec unit tests.
