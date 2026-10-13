# ADR-028: Engineering systems foundation and additive ELV migration

## Status
Accepted for ELV0. Source specification baseline: `b3f314d01f3cfdbcc78784b548fe250a0d595213` on `docs/elv-engineering-systems-spec`.
Implementation branch: `feat/flutter-engineering-systems-foundation`.

## Decision
Adopt the eight ELV specification documents as the extension requirements. Preserve the electrical FL0–FL15 baseline and introduce systems without recreating physical objects or replacing electrical circuits with generic ELV entities.

The first vertical owns only system classification and participation:

| Contract | Responsibility | Persistence |
|---|---|---|
| EngineeringSystemFamily | Immutable, source-bearing catalog edition with extensible technical code and routing classification | engineering_family_definitions |
| EngineeringSystem | Project network instance with project-unique code and pinned family edition; optional exact profile references | project_engineering_systems |
| ComponentSystemMembership | Non-owning participation role between a system and an existing placed component identity | component_engineering_memberships |
| EngineeringProfileReference | Profile identity plus edition; records design intent, not an approved or executable rule pack | System payload |

One physical device can belong to multiple project systems. Component IDs remain the existing `ComponentInstance` IDs. Project scope is derived from room/floor/project ownership, and assignments require all parents and placement to be active. No new physical component table or competing geometry model is introduced.

Family editions cannot be edited in place. System code uniqueness is case-insensitive by canonical uppercase codes, including tombstones; restoring a system reuses its original ID. Changing a family edition with active participants is blocked pending explicit detachment/migration. Archiving a system with participants is blocked; membership removal is audited soft deletion and does not delete placement. Unavailable component placements remain visible as unavailable participants so the engineer can detach them explicitly.

SQLite upgrade 13→14 is additive. Existing projects, loads, circuits, protection requirements, SKU snapshots, routing and generated panels retain their identities. Existing physical objects are not implicitly assigned to a new network. ELV0 membership changes do not add dependencies to the FL12 numerical graph: classification is not yet a discipline calculation.

## Deliberate scope limits
ELV0 does not implement persisted ports/connections, typed discipline parameter catalogs, cable allocations, common cable-run adaptation, assemblies, enclosure layouts or ELV formulas. Participation roles and routing class codes are classification metadata, not inputs to a generic formula engine. Profile references are not validated against an approved ELV rules registry and cannot enable compliance claims.

The next design/implementation gate must settle `TopologyGroup`, `InternalConnectivity`, `ComponentAssembly`, explicit port compatibility, cable resource allocation and legacy Circuit/CableRun mapping using all four scenarios. The more detailed scenario and normative documents supersede the original specification's unresolved design questions.

Standards-driven calculations remain disabled until their specific rule packs have verified editions/status, typed parameters, provenance, tests and migration behavior as required by the standards audit. No national engineering threshold or full standards text is seeded by this foundation.

## Consequences
The application can create multiple CCTV/LAN/ACS/fire/custom network instances and assign one existing physical object to several systems. System-specific device palettes, editor visibility and trace/connectivity are delivered subsequently; the current discipline enum remains an editor compatibility adapter rather than the extensibility mechanism.
