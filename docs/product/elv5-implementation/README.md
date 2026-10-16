# ELV5 — Implementation design index

Status: DESIGN HARDENED / RUNTIME NOT STARTED
Branch: `feat/flutter-elv5-power-topology-design`
Parent source/design: ELV4 `31581aa6c396d5ebd6cdf1985c53719d9d05e12a`.

ELV5 registers 27 discipline processes and consumes shared ELV3/ELV4 facts. It does not duplicate power topology or create a separate project/revision/history platform. [Governing design](../elv5-discipline-calculations-design-specification.md) defines shared extensions and stage boundaries.

## Mandatory code-level contracts

The runtime specification is intentionally split by concern, with explicit precedence defined by the [authoritative index](../elv5-authoritative-spec-index.md):

- [Code-level runtime contract](code-level-runtime-contract.md): base runtime model, `engineering-node-v3`, status axes, strict ELV5 wire envelope, replay-first protocol, dependencies and guarded publication.
- [Engineering primitives](engineering-primitives-contract.md): dimension-safe exact quantities, evidence basis/applicability, operating cases, deterministic time/frames and `electra.canonical-json.v1` hashing.
- [Typed process API](typed-process-api.md): concrete Dart input/output semantics for all 27 process definitions.
- [Drift schema 24 contract](persistence-schema-contract.md): concrete persistence/migration/root/member/evaluation/pointer/index/snapshot design.
- [Code-level hardening amendments](code-level-hardening-amendments.md): normative reconciliation of wire/storage details.
- [Third-pass code-level engineering hardening](code-level-hardening-v2.md): highest-priority ELV5 amendment for strongly typed identities, explicit field-resolution semantics, bounded exact arithmetic, legal quantity algebra, captured timezone-rule evidence, measurement uncertainty, deterministic policy composition, transient simultaneity, ACS release completeness, fire supervision/fault states, selector invalidation, bounded atomic publication and result/review separation.
- [Executable qualification contract](qualification-contract.md): L0–L6 proof model, 54 primary process verticals, command adversarial tests, failure/race/restart/migration/freeze and false-PASS sentinels. Third-pass focused suites are additional mandatory evidence.

The machine wire authority remains [command-registry.json](command-registry.json), with exactly 16 operations; [command-examples.json](command-examples.json) must match its exact key sets. The third-pass amendment does not change that count or the fixed 27-process inventory.

| Package | Specification | Outcome |
|---|---|---|
| P0 | [Baseline and stage integration](p0-baseline.md) | Pin actual parent source/design SHA, inherited schema/capabilities and migration origins; generate/verify authoritative contract manifest |
| P1 | [Typed discipline profiles and process registry](p1-profiles-registry.md) | Register exactly 27 stable process codes; implement strongly typed identities, bounded engineering primitives, evidence/time/requirement algebra and typed definitions |
| P2 | [Persistence, command boundaries and revision evidence](p2-persistence-commands.md) | Implement the exact 16-operation wire family, additive schema 24, strict resource bounds, revision-scoped aspects and isolated evaluation/pointer storage |
| P3 | [CCTV calculation implementation](p3-cctv.md) | Implement CCTV-01…06 with deterministic geometry/time/bandwidth/storage/source-evidence semantics and captured timezone-rule reproduction |
| P4 | [LAN and structured-cabling implementation](p4-lan.md) | Implement LAN-01…07 including ordered path, optical two-direction budget and ELV6-safe rack demand basis |
| P5 | [Access-control implementation](p5-acs.md) | Implement ACS-01…06 including typed resources, transient/startup composition, power wrappers and five-cause release truth-table behavior |
| P6 | [Fire-alarm implementation](p6-fire.md) | Implement FA-01…08 including full address claims, state currents, supported electrical models, supervision/fault-state behavior where selected and claim-scope separation |
| P7 | [Incremental dependencies and engineer workspace](p7-dependencies-workspace.md) | Encode owner/scope-aware dependency keys, missing/set/selector markers, canonical fingerprints and bounded guarded coherent publication |
| P8 | [Integrated verification and qualification](p8-acceptance.md) | Execute 54 primary POS/NEG public-command verticals plus command/resource-limit/restart/failure/selector/race/migration/freeze and third-pass hardening matrices |
| P9 | [Architecture reconciliation and stage handoff](p9-closure.md) | Reconcile 80 requirements, 27 definitions, 16 codecs, schema 24, contract manifest and executable evidence to one exact source SHA |

[Process contracts](process-contracts.md) and [process registry](process-registry.json) cover CCTV6/LAN7/ACS6/Fire8. [Requirement ledger](requirements.json) contains 80 stable package requirements. Every runtime evidence field is intentionally empty until implementation evidence exists.

ELV4 is an implemented, runtime-accepted and merged prerequisite. Reuse its dedicated power persistence, reviewed writers, captured facts and numerical kernels under the [implemented baseline contract](implemented-baseline.md). ELV5 schema 24 is additive and must not reinterpret or duplicate ELV3/ELV4 canonical ownership.

The [initial technical audit](../../audit/elv5-technical-audit.md) resolved 8 discipline-contract findings in specification. The [second-pass engineering/architecture audit](../../audit/elv5-engineering-architecture-hardening-audit.md) resolved a further 14 design findings. The [third-pass production-readiness audit](../../audit/elv5-third-pass-production-readiness-audit.md) resolves 15 more design findings. Runtime remains NOT STARTED; **37 specification resolutions are not runtime fixes**.

## Design-to-runtime consistency gate

Before an implementation package can claim completion, these inventories must agree exactly:

1. **27** process codes/scopes/dependencies/required dimensions in registry, process contracts and typed runtime definitions.
2. Strongly typed subject/scope identities and explicit known/missing/N-A/unsupported/unresolved field semantics at the domain/kernel boundary.
3. Engineering quantity/evidence/measurement/time/frame/hash semantics in primitives and production codecs/kernels, including captured timezone-rule evidence and code-owned legal quantity algebra.
4. **16** command operations and their exact payload key sets in registry, examples and runtime semantic codecs.
5. Hardened camera subscriptions, recording temporal/reserve/redundancy basis and ACS release truth table across wire → persistence → typed resolver.
6. Deterministic requirement-merger and simultaneity/transient policies where required; no intuitive policy winner or hidden steady-state approximation.
7. Drift **schema 24** tables/indexes/migration and ownership map.
8. Selector/set/missing dependency capture invalidates on old/new closure and on creation of newly matching facts.
9. Coherent batch publication remains all-or-nothing while respecting explicit target/resource/SQL bounds.
10. **54** primary POS/NEG entries in the executable qualification manifest plus the third-pass focused suites and L0–L6 acceptance inventory.
11. Generated contract manifest/fingerprint and P0–P9 evidence at the exact tested source SHA.

Any mismatch is a specification/runtime defect and must not be resolved by ad-hoc fallback, label inference, latest-definition lookup, `null` convention, package-local formula override or engineer waiver that mutates an immutable technical result.
