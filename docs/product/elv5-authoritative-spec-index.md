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
7. [Unified calculation engine](elv5-implementation/calculation-engine-contract.md): common deterministic execution lifecycle for all 27 processes, solver families, applicability, operating cases, conservative comparisons, headroom/margins, governing cases, limiting factors, deterministic trace and sensitivity rules.
8. [Machine algorithm registry](elv5-implementation/algorithm-registry.json): exact 27/27 process-to-solver-family/operating-case/governing/margin/limiting-factor binding.
9. [Drift schema 24 persistence contract](elv5-implementation/persistence-schema-contract.md): concrete ELV5 roots/members, PK/FK/index rules, immutable evaluations/pointers, dependency index, migration/restart and shared ledger/history reuse.
10. [Code-level hardening amendments](elv5-implementation/code-level-hardening-amendments.md): normative reconciliation of hardened wire/storage semantics.
11. [Third-pass code-level engineering hardening](elv5-implementation/code-level-hardening-v2.md): strongly typed identities, explicit field-resolution algebra, bounded exact arithmetic, captured timezone-rule evidence, deterministic requirement merger, transient/simultaneity model, ACS release matrix, fire supervision/fault states, selector invalidation and bounded atomic publication. **Where it conflicts with older ELV5 wording, this document governs.**
12. [Production source blueprint](elv5-implementation/production-source-blueprint.md): recommended Dart/Drift source tree, class/interface responsibilities, 16-handler mapping, capture/publish services, repository/UoW boundaries, UI projection and implementation slices.
13. [Executable qualification contract](elv5-implementation/qualification-contract.md): L0–L6 test architecture, 54 primary process verticals, adversarial commands, failure/race/migration/freeze and false-PASS sentinels. Third-pass and unified-engine focused suites supplement rather than replace the 54 process verticals.
14. [Machine-readable 16-command registry](elv5-implementation/command-registry.json), the exact schema/operation/payload-key authority subject to later normative hardening semantics.
15. [Canonical command examples](elv5-implementation/command-examples.json), one valid payload and one deterministic rejection mutation for every registered ELV5 operation.
16. [27-process contract registry](elv5-implementation/process-contracts.md) and [machine-readable process registry](elv5-implementation/process-registry.json).
17. [Authority manifest generator](../../scripts/ci/generate-elv5-contract-manifest.py): emits an exact-head SHA-256 manifest/fingerprint over process, algorithm, command and requirement inventories plus the governing code-level contracts and publishes it as a CI artifact.
18. [Baseline and boundary audit](../audit/elv5-baseline-alignment-audit.md).
19. [Initial technical audit](../audit/elv5-technical-audit.md), [second-pass engineering/architecture hardening audit](../audit/elv5-engineering-architecture-hardening-audit.md), and [third-pass production-readiness audit](../audit/elv5-third-pass-production-readiness-audit.md) with its [machine-readable registry](../audit/elv5-third-pass-production-readiness-audit.json).
20. [Implemented baseline and extension contract](elv5-implementation/implemented-baseline.md) and [evidence manifest](elv5-implementation/baseline.json).

## Authority and acceptance

Existing ELV1–ELV4 identities, ownership, reference editions, physical routing, revision lifecycle and resolved RM01–RM15 contracts remain authoritative. ELV5 adds typed discipline definitions and versioned process registration, not replacement ports/cables/cache/history/revision lifecycles. Shared platform extensions must update both stages' contracts explicitly.

Within ELV5 the precedence is explicit. Highest authority first:

1. `code-level-hardening-v2.md`;
2. `code-level-hardening-amendments.md`;
3. machine-readable command/process/algorithm registries for membership/key/solver inventories not superseded by later hardening;
4. engineering primitives, typed process API, unified calculation engine, schema-24 persistence and qualification contracts;
5. process contracts for formulas and technical claim boundaries;
6. base runtime contract;
7. package P0–P9 prose.

A contradiction between active normative artifacts is a specification failure, not a developer choice. P0 implementation entry therefore requires the generated authority fingerprint/manifest and CI consistency guards covering process/algorithm/command/requirement counts, required dimensions, solver mappings, payload inventories, registries, canonical format and schema version.

Semantic changes require synchronized updates. Free-form package-local reinterpretation is a specification defect.

The initial ELV5 discipline command registry remains exactly **16 operations** under `electra.elv5-discipline-command.v1`, payload version 1. Hardened design changed exact payload content for three not-yet-shipped operations without changing operation count/schema identity. ELV4 revision freeze/create-next commands remain the public revision boundary; ELV5 extends their transaction/snapshot payload internally rather than adding competing revision commands.

All ELV5 P0–P9 runtime packages remain NOT_STARTED. ELV4 is implemented, runtime accepted at the pinned source SHA and merged through PR #11 at `d2b059d4c11a284cdd32965140f6df3c40020c8d`. The [implemented baseline contract](elv5-implementation/implemented-baseline.md) governs reuse and new integration work. ELV4 acceptance does not qualify the 27 new ELV5 processes or any of the 16 ELV5 command codecs.

## Audit status

The initial all-package/process audit reviewed 80 requirements and 27 process contracts, identified **6 HIGH + 2 MEDIUM** discipline-contract findings and resolved all eight in specification.

The second-pass engineering/architecture audit identified **10 HIGH + 4 MEDIUM** findings covering type safety, provenance/uncertainty, operating cases, deterministic time/frames, typed APIs, storage/schema ownership, batch publication, ACS release behavior, CCTV wire-rate basis, optical reach scope, executable qualification and scale fixtures. All 14 are `SPEC_RESOLVED / RUNTIME_NOT_IMPLEMENTED`.

The third-pass production-readiness audit identified **11 HIGH + 4 MEDIUM** findings covering strongly typed identities, explicit missing/N-A/unsupported semantics, resource-bounded exact arithmetic, legal quantity algebra, reproducible timezone rules, measurement uncertainty, deterministic policy composition, transient simultaneity, ACS release completeness, fire supervision/fault states, negative dependency selectors, bounded atomic publication, review/result separation, diagnostic cardinality and authority-manifest drift protection. All 15 are `SPEC_RESOLVED / RUNTIME_NOT_IMPLEMENTED`.

Total design findings resolved across the three passes: **37**. This count is specification hardening, not runtime fixes.

The unified calculation-engine pass is an architectural consolidation rather than a new finding count. It standardizes how all 27 already-defined processes determine applicability, operating cases, conservative verdicts, engineering margins, governing cases, limiting factors, explanations and optional what-if results.

## Implementation-readiness gate

The following design artifacts are frozen enough to start P1/P2 implementation:

- exactly 27 process codes/scopes/dependencies and typed process input/output boundaries;
- exactly 27 machine-checkable algorithm mappings to legal solver families/operating cases/governing/margin/limiting semantics;
- one deterministic cross-discipline calculation lifecycle from capture through guarded publication;
- dimension-safe exact quantities plus code-owned legal quantity algebra;
- strongly typed domain identities and explicit field-resolution semantics;
- canonical hash projections and captured timezone-rule evidence;
- deterministic requirement composition/conflict algebra and operating/transient composition rules;
- conservative interval comparison with no false PASS at uncertain thresholds;
- positive=headroom signed margin convention, governing-case and limiting-factor projections where meaningful;
- deterministic semantic calculation trace and non-authoritative bounded sensitivity/what-if semantics;
- exactly 16 public command operations with hardened exact payload-key sets and canonical examples;
- additive Drift target **schema 24** with ownership/PK/FK/index/migration rules;
- selector-aware dependency invalidation including previously missing/newly matching members;
- replay/history/freeze/create-next integration contract;
- bounded coherent all-or-nothing publication contract;
- production source/class decomposition with strict dependency direction and 16-handler mapping;
- L0–L6 qualification architecture and exact 54-entry primary process-oracle requirement plus mandatory third-pass/unified-engine suites;
- exact-head CI authority manifest generation with SHA-256 fingerprints for process/algorithm/command/requirement inventories and normative contracts.

The generated manifest is **authority/design-entry evidence**, not runtime acceptance. Production P0/P9 source must record/verify the accepted authority fingerprint so an implementation cannot be closed against a different specification fingerprint.

Remaining runtime artifacts are deliberately executable rather than prose:

- implement production Dart definitions/codecs/resolvers/repositories and schema-24 migration following the source blueprint and all hardening amendments;
- implement the unified calculation engine/common result envelope without duplicating ELV3/ELV4 physical ownership;
- publish the machine-readable `qualification-manifest.json` with exact fixtures/commands/statuses for all 54 primary POS/NEG entries plus focused third-pass/unified-engine suites;
- execute schema/migration/restart, 16-codec adversarial, resource-limit, failure-injection, selector-invalidation, race/freeze and cross-discipline vertical tests;
- perform post-schema ownership reconciliation proving no ELV5 table duplicates canonical ELV3/ELV4 cable/port/component/source/battery ownership;
- close P9 only from evidence generated at the exact tested source SHA **and matching accepted authority fingerprint**.
