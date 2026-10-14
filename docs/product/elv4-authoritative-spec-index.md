# Electra — ELV4 Authoritative Design Index

Status: DESIGN DRAFT / IMPLEMENTATION NOT AUTHORIZED
Branch: `feat/flutter-elv4-power-topology-design`
Inspected baseline: `7f1c701cb4ba492589321f8f9827d20464ddaefb`

## Entry documents

1. [Power topology specification](elv4-power-topology-design-specification.md): identities, responsibilities, typed profiles, invariants, calculations, persistence, commands, dependencies and acceptance.
2. [Expanded P0–P9 delivery plan](elv4-p0-p9-delivery-plan.md): subpackages, sequencing, tests and exact-head gates.
3. [Baseline alignment audit](../audit/elv4-baseline-alignment-audit.md): inspected ELV1–ELV3 facts and unresolved entry evidence.

## Authority and conflict handling

Existing accepted ELV1/ELV2 and ELV3 domain/ownership contracts remain authoritative for their entities. ELV4 adds typed power semantics and explicitly coordinated extensions. It cannot silently override allocation exclusivity, component/port identity, reusable routing, catalog editions or frozen revision history.

For ELV3, enter through elv3-authoritative-spec-index.md and elv3-code-implementation-index.md, including later accepted runtime remediation. Historical status labels are not proof of final runtime completion. New design details in this index do not repair or accept ELV3 runtime gaps.

Within ELV4, the specification governs semantics; the delivery plan governs package sequencing and proof. A semantic conflict requires explicit contract revision before implementation, never retrospective acceptance in P9.

## Stage boundaries

ELV4: shared physical load/conversion/PoE/DC-drop/UPS/battery basis.
ELV5: discipline-specific engineering policy/processes.
ELV6: cabinet/rack placement and battery fit.
ELV7: verified jurisdictional rule packs/compliance.
ELV8: manufacturer selection/BOM/deliverables.

## Current status

The branch contains design documentation only. All ELV4 P0–P9 runtime packages remain unstarted.
Merged ELV3 PR #10 is the starting source baseline; ELV3 final closure evidence must be reconciled in ELV4-P0.
