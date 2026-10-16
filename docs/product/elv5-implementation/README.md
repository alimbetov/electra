# ELV5 — Implementation design index

Status: DESIGN HARDENED / RUNTIME NOT STARTED
Branch: `feat/flutter-elv5-power-topology-design`
Parent source/design: ELV4 `31581aa6c396d5ebd6cdf1985c53719d9d05e12a`.

ELV5 registers 27 discipline processes and consumes shared ELV3/ELV4 facts. It does not duplicate power topology or create a separate project/revision/history platform. [Governing design](../elv5-discipline-calculations-design-specification.md) defines shared extensions and stage boundaries.

## Mandatory code-level contracts

The runtime specification is intentionally split by concern:

- [Code-level runtime contract](code-level-runtime-contract.md): base runtime model, `engineering-node-v3`, status axes, strict ELV5 wire envelope, replay-first protocol, dependencies and guarded publication.
- [Engineering primitives](engineering-primitives-contract.md): dimension-safe exact quantities, evidence basis/applicability, operating cases, deterministic time/frames and `electra.canonical-json.v1` hashing.
- [Typed process API](typed-process-api.md): concrete Dart input/output semantics for all 27 process definitions.
- [Drift schema 24 contract](persistence-schema-contract.md): concrete persistence/migration/root/member/evaluation/pointer/index/snapshot design.
- [Code-level hardening amendments](code-level-hardening-amendments.md): later normative reconciliation of wire/storage details; where conflicting detailed wording exists, the amendment governs.
- [Executable qualification contract](qualification-contract.md): L0–L6 proof model, 54 primary process verticals, command adversarial tests, failure/race/restart/migration/freeze and false-PASS sentinels.

The machine wire authority remains [command-registry.json](command-registry.json), with exactly 16 operations; [command-examples.json](command-examples.json) must match its exact key sets.

| Package | Specification | Outcome |
|---|---|---|
| P0 | [Baseline and stage integration](p0-baseline.md) | Pin actual parent source/design SHA, inherited schema/capabilities and migration origins |
| P1 | [Typed discipline profiles and process registry](p1-profiles-registry.md) | Register exactly 27 stable process codes and implement shared engineering primitives + typed definitions |
| P2 | [Persistence, command boundaries and revision evidence](p2-persistence-commands.md) | Implement the exact 16-operation wire family, additive schema 24, revision-scoped aspects and isolated evaluation/pointer storage |
| P3 | [CCTV calculation implementation](p3-cctv.md) | Implement CCTV-01…06 with deterministic geometry/time/bandwidth/storage/source-evidence semantics |
| P4 | [LAN and structured-cabling implementation](p4-lan.md) | Implement LAN-01…07 including ordered path, optical two-direction budget and ELV6-safe rack demand basis |
| P5 | [Access-control implementation](p5-acs.md) | Implement ACS-01…06 including typed resources, power wrappers and release truth-table behavior |
| P6 | [Fire-alarm implementation](p6-fire.md) | Implement FA-01…08 including full address claims, state currents, supported electrical models and claim-scope separation |
| P7 | [Incremental dependencies and engineer workspace](p7-dependencies-workspace.md) | Encode owner/scope-aware dependency keys, missing/set markers, canonical fingerprints and guarded coherent publication |
| P8 | [Integrated verification and qualification](p8-acceptance.md) | Execute 54 primary POS/NEG public-command verticals plus command/restart/failure/race/migration/freeze matrices |
| P9 | [Architecture reconciliation and stage handoff](p9-closure.md) | Reconcile 80 requirements, 27 definitions, 16 codecs, schema 24 and executable evidence to one exact source SHA |

[Process contracts](process-contracts.md) and [process registry](process-registry.json) cover CCTV6/LAN7/ACS6/Fire8. [Requirement ledger](requirements.json) contains 80 stable package requirements. Every runtime evidence field is intentionally empty until implementation evidence exists.

ELV4 is an implemented, runtime-accepted and merged prerequisite. Reuse its dedicated power persistence, reviewed writers, captured facts and numerical kernels under the [implemented baseline contract](implemented-baseline.md). ELV5 schema 24 is additive and must not reinterpret or duplicate ELV3/ELV4 canonical ownership.

The [initial technical audit](../../audit/elv5-technical-audit.md) resolved 8 discipline-contract findings in specification. The [second-pass engineering/architecture audit](../../audit/elv5-engineering-architecture-hardening-audit.md) resolved a further 14 design findings. Runtime remains NOT STARTED; 22 specification resolutions are not runtime fixes.

## Design-to-runtime consistency gate

Before an implementation package can claim completion, these inventories must agree exactly:

1. **27** process codes/scopes/dependencies/required dimensions in registry, process contracts and typed runtime definitions.
2. Engineering quantity/evidence/time/frame/hash semantics in primitives and production codecs/kernels.
3. **16** command operations and their exact payload key sets in registry, examples and runtime semantic codecs.
4. Hardened camera subscriptions, recording temporal/reserve/redundancy basis and ACS release truth table across wire → persistence → typed resolver.
5. Drift **schema 24** tables/indexes/migration and ownership map.
6. **54** primary POS/NEG entries in the executable qualification manifest and the L0–L6 acceptance inventory.
7. P0–P9 evidence at the exact tested source SHA.

Any mismatch is a specification/runtime defect and must not be resolved by ad-hoc fallback, label inference, latest-definition lookup or package-local formula override.
