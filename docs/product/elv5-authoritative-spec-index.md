# Electra — ELV5 Authoritative Design Index

Status: DESIGN HARDENED / RUNTIME NOT STARTED
Branch: `feat/flutter-elv5-power-topology-design`
Parent branch: `feat/flutter-elv4-power-topology-design`
Pinned parent: `31581aa6c396d5ebd6cdf1985c53719d9d05e12a`

The branch name is retained as requested. ELV5 is **discipline-specific engineering calculations**, not a second power-topology foundation. ELV4 owns common physical power models; ELV5 owns explicit calling context, discipline policies and the remaining discipline calculations.

## Entry documents

1. [ELV5 design specification](elv5-discipline-calculations-design-specification.md).
2. [P0–P9 delivery plan](elv5-p0-p9-delivery-plan.md).
3. [Detailed implementation index](elv5-implementation/README.md), with one contract for each package.
4. [Code-level runtime contract](elv5-implementation/code-level-runtime-contract.md): base runtime types, strict wire envelope, 16-operation public command surface, replay/CAS/publication/persistence/dependency contracts.
5. [Engineering primitives contract](elv5-implementation/engineering-primitives-contract.md): dimension-safe exact quantities, evidence basis/applicability, operating cases, deterministic time/frames and canonical hashing.
6. [Typed process API](elv5-implementation/typed-process-api.md): process-specific Dart input/output boundaries for all 27 calculations.
7. [Drift schema 24 persistence contract](elv5-implementation/persistence-schema-contract.md): concrete ELV5 roots/members, PK/FK/index rules, immutable evaluations/pointers, dependency index, migration/restart and shared ledger/history reuse.
8. [Code-level hardening amendments](elv5-implementation/code-level-hardening-amendments.md): normative reconciliation of hardened wire/storage semantics. **Where it conflicts with the older base runtime/persistence wording, this amendment governs.**
9. [Production source blueprint](elv5-implementation/production-source-blueprint.md): recommended Dart/Drift source tree, class/interface responsibilities, 16-handler mapping, capture/publish services, repository/UoW boundaries, UI projection and implementation slices.
10. [Executable qualification contract](elv5-implementation/qualification-contract.md): L0–L6 test architecture, 54 primary process verticals, adversarial commands, failure/race/migration/freeze and false-PASS sentinels.
11. [Machine-readable 16-command registry](elv5-implementation/command-registry.json), the exact schema/operation/payload-key authority.
12. [Canonical command examples](elv5-implementation/command-examples.json), one valid payload and one deterministic rejection mutation for every registered ELV5 operation.
13. [27-process contract registry](elv5-implementation/process-contracts.md) and [machine-readable process registry](elv5-implementation/process-registry.json).
14. [Baseline and boundary audit](../audit/elv5-baseline-alignment-audit.md).
15. [Initial technical audit](../audit/elv5-technical-audit.md) and [second-pass engineering/architecture hardening audit](../audit/elv5-engineering-architecture-hardening-audit.md).
16. [Implemented baseline and extension contract](elv5-implementation/implemented-baseline.md) and [evidence manifest](elv5-implementation/baseline.json).

## Authority and acceptance

Existing ELV1–ELV4 identities, ownership, reference editions, physical routing, revision lifecycle and resolved RM01–RM15 contracts remain authoritative. ELV5 adds typed discipline definitions and versioned process registration, not replacement ports/cables/cache/history/revision lifecycles. Shared platform extensions must update both stages' contracts explicitly.

Within ELV5:

- the governing design fixes stage boundaries and claim scope;
- engineering primitives fix numeric/unit/evidence/time/frame/hash semantics;
- typed process API fixes kernel inputs/outputs;
- process registry fixes machine membership/scopes/dependency binders and required dimensions;
- process contracts fix formulas and technical claim boundaries;
- the command registry fixes the exact 16 public ELV5 operations and payload-key inventories;
- canonical examples fix design-time wire fixtures;
- schema 24 contract fixes persistence ownership/identity/migration semantics;
- hardening amendments resolve later discovered contradictions and supersede conflicting older detailed wording;
- production source blueprint fixes the intended code decomposition and dependency direction;
- package contracts fix implementation responsibilities;
- qualification contract fixes what executed evidence is sufficient for runtime acceptance.

Semantic changes require synchronized updates. Free-form package-local reinterpretation is a specification defect.

The initial ELV5 discipline command registry remains exactly **16 operations** under `electra.elv5-discipline-command.v1`, payload version 1. Hardened design changed exact payload content for three not-yet-shipped operations without changing operation count/schema identity. ELV4 revision freeze/create-next commands remain the public revision boundary; ELV5 extends their transaction/snapshot payload internally rather than adding competing revision commands.

All ELV5 P0–P9 runtime packages remain NOT_STARTED. ELV4 is implemented, runtime accepted at the pinned source SHA and merged through PR #11 at `d2b059d4c11a284cdd32965140f6df3c40020c8d`. The [implemented baseline contract](elv5-implementation/implemented-baseline.md) governs reuse and new integration work. ELV4 acceptance does not qualify the 27 new ELV5 processes or any of the 16 ELV5 command codecs.

## Audit status

The initial all-package/process audit reviewed 80 requirements and 27 process contracts, identified **6 HIGH + 2 MEDIUM** discipline-contract findings and resolved all eight in specification.

The second-pass engineering/architecture audit identified **10 HIGH + 4 MEDIUM** additional findings covering type safety, provenance/uncertainty, operating cases, deterministic time/frames, typed APIs, storage/schema ownership, batch publication, ACS release behavior, CCTV wire-rate basis, optical reach scope, executable qualification and scale fixtures. All 14 are `SPEC_RESOLVED / RUNTIME_NOT_IMPLEMENTED`.

Total design findings resolved across the two passes: **22**. This count is specification hardening, not runtime fixes.

## Implementation-readiness gate

The following design artifacts are now frozen enough to start P1/P2 implementation:

- exactly 27 process codes/scopes/dependencies and typed process input/output boundaries;
- dimension-safe engineering primitives and canonical hash projections;
- exactly 16 public command operations with hardened exact payload-key sets and canonical examples;
- additive Drift target **schema 24** with ownership/PK/FK/index/migration rules;
- replay/history/freeze/create-next integration contract;
- production source/class decomposition with strict dependency direction and 16-handler mapping;
- L0–L6 qualification architecture and exact 54-entry primary process-oracle requirement.

Remaining implementation-entry/runtime artifacts are deliberately executable rather than prose:

- implement production Dart definitions/codecs/resolvers/repositories and schema-24 migration following the source blueprint;
- publish the machine-readable `qualification-manifest.json` with exact fixtures/commands/statuses for all 54 primary POS/NEG entries;
- execute schema/migration/restart, 16-codec adversarial, failure-injection, race/freeze and cross-discipline vertical tests;
- perform post-schema ownership reconciliation proving no ELV5 table duplicates canonical ELV3/ELV4 cable/port/component/source/battery ownership;
- close P9 only from evidence generated at the exact tested source SHA.
