# ELV6 — final architecture hardening addendum

Date: 2026-10-16  
Branch: `feat/flutter-elv6-enclosure-layout-design`  
Status: **DESIGN RESOLVED / RUNTIME OPEN**.

This addendum records two findings discovered only after the initial 18-finding hard audit had already produced a green 24-process/80-requirement/21-command design gate. They are kept separate so the audit history remains honest rather than rewriting the earlier review retroactively.

## ELV6-AUD-19 — HIGH: public placement payload trusted client-derived geometry and solver provenance

**Observed:** the first exact command registry allowed `PLACE_LAYOUT_SUBJECT`/`MOVE_LAYOUT_SUBJECT` to carry `occupiedEnvelope`, `rackSpan`, `dinSpan` and `sourceProposalId` from the wire client.

**Why this is dangerous:** those values are derived from the selected subject definition, mounting surface and placement intent. A buggy or malicious client could under-report its occupied envelope, use a smaller DIN/rack span than the technical definition, or impersonate proposal provenance. This creates two competing truths inside the same command payload.

**Resolution:** public placement commands now carry only a strict `placementSpec` intention. The semantic backend resolves the exact immutable subject definition and surface/profile and derives:

```text
canonical pose
occupied body AABB
rack/DIN span
connector protrusions
service/removal/airflow envelopes
derivation fingerprints
```

`sourceProposalId` is backend-owned and can be written only by `ACCEPT_LAYOUT_PROPOSAL` for actual accepted proposal items.

Forbidden client-derived placement fields fail closed. Runtime qualification must attempt forged `occupiedEnvelope`, `rackSpan`, `dinSpan` and manual `sourceProposalId` payloads.

Specification authority: `docs/product/elv6-implementation/mutation-safety-contract.md`.

Status: `SPEC_RESOLVED / RUNTIME_OPEN`.

## ELV6-AUD-20 — HIGH: replacement commands could orphan referenced collection members

**Observed:** `REPLACE_MOUNTING_SURFACES` and `REPLACE_CABLE_ENTRIES` originally froze exact payload keys but did not explicitly forbid removing an item that an active placement/assignment still references.

**Why this matters:** set-replacement APIs are especially prone to “delete old then insert new” implementations. Without a pre-write reference closure check, a surface/entry rename or removal can temporarily or durably orphan placements/cable ends, break replay/history, and turn a clean referential error into downstream missing-data noise.

**Resolution:** replacement semantics are identity-aware and fail before write when removed members are still referenced:

```text
removedSurfaces ∩ activeReferencedSurfaces != ∅
    -> ELV6_REFERENCED_MEMBER_REMOVAL

removedEntries ∩ activeAssignedEntries != ∅
    -> ELV6_REFERENCED_MEMBER_REMOVAL
```

No client `force` flag exists. The engineer must release/remap dependents first or use a future explicitly qualified coordinated multi-owner operation. Failed replacement leaves the old collection/references intact after reopen.

The same principle applies to technical-profile release when an active canonical state would become undecodable or lose a required exact profile identity: fail with structured references rather than silently selecting defaults/latest.

Specification authority: `docs/product/elv6-implementation/mutation-safety-contract.md`.

Status: `SPEC_RESOLVED / RUNTIME_OPEN`.

## Updated audit verdict

The complete ELV6 design audit now contains **20 findings**:

```text
18 initial hard-audit findings
+ 2 final command/mutation safety findings
= 20 design findings
```

All 20 are resolved at specification level. None is runtime evidence.
