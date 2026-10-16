# Electra — ELV5 Authoritative Design Index

Status: DESIGN DRAFT / RUNTIME NOT STARTED
Branch: `feat/flutter-elv5-power-topology-design`
Parent branch: `feat/flutter-elv4-power-topology-design`
Pinned parent: `31581aa6c396d5ebd6cdf1985c53719d9d05e12a`

The branch name is retained as requested. ELV5 is **discipline-specific engineering calculations**, not a second power-topology foundation. ELV4 owns common physical power models; ELV5 owns explicit calling context, discipline policies and the remaining discipline calculations.

## Entry documents

1. [ELV5 design specification](elv5-discipline-calculations-design-specification.md).
2. [P0–P9 delivery plan](elv5-p0-p9-delivery-plan.md).
3. [Detailed implementation index](elv5-implementation/README.md), with one contract for each package.
4. [Code-level runtime contract](elv5-implementation/code-level-runtime-contract.md): normative Dart/runtime types, strict wire envelope, exact 16-operation public command surface, replay/CAS/publication/persistence/dependency contracts.
5. [Machine-readable 16-command registry](elv5-implementation/command-registry.json), validated as a closed schema/operation/payload-key set.
6. [Canonical command examples](elv5-implementation/command-examples.json), one valid payload and one deterministic rejection mutation for every registered ELV5 operation.
7. [27-process contract registry](elv5-implementation/process-contracts.md) and [machine-readable process registry](elv5-implementation/process-registry.json).
8. [Baseline and boundary audit](../audit/elv5-baseline-alignment-audit.md).
9. [Implemented baseline and extension contract](elv5-implementation/implemented-baseline.md) and [evidence manifest](elv5-implementation/baseline.json).

## Authority and acceptance

Existing ELV1–ELV4 identities, ownership, reference editions, physical routing, revision lifecycle and resolved RM01–RM15 contracts remain authoritative. ELV5 adds typed discipline definitions and versioned process registration, not replacement ports/cables/cache/history/revision lifecycles. Shared platform extensions must update both stages' contracts explicitly.

Within ELV5 the design governs stage boundaries; the code-level runtime contract governs mandatory runtime types, wire/command semantics, persistence identity, dependency/publication protocol and fail-closed behavior; the command registry governs the exact public ELV5 command schema/operation/payload-key inventory; canonical examples govern the design-time wire fixtures; the process registry governs each algorithm's machine membership/dependencies; process contracts govern math and claim boundaries; package contracts govern writes and proof. Semantic changes require synchronized updates, not package-local overrides. The older architecture overview remains background: its mixed state list and ambiguous recording-duration formula are refined here, not copied into runtime codecs.

The initial ELV5 discipline command registry is fixed at exactly 16 operations under `electra.elv5-discipline-command.v1`. ELV4 revision freeze/create-next commands remain the public revision boundary; ELV5 extends their transaction/snapshot payload internally rather than adding competing revision commands.

All ELV5 P0–P9 runtime packages remain NOT_STARTED. ELV4 is implemented, runtime accepted at the pinned source SHA and merged through PR #11 at `d2b059d4c11a284cdd32965140f6df3c40020c8d`. The [implemented baseline contract](elv5-implementation/implemented-baseline.md) governs reuse and new integration work. ELV4 acceptance does not qualify the 27 new ELV5 processes or any of the 16 ELV5 command codecs.

## Initial technical audit

The [all-package/process audit](../audit/elv5-technical-audit.md) reviewed 80 requirements and 27 process contracts, identified 6 HIGH/2 MEDIUM design findings and resolved all eight in specification. Runtime acceptance remains unproven. See the [structured coverage/probes](../audit/elv5-technical-audit.json).

## Implementation-readiness gate

The 16-operation registry and canonical payload/rejection examples are now frozen as design artifacts and are checked independently in CI together with the existing 27-process/80-requirement specification guard. Remaining design-to-runtime entry artifacts are:

- select the additive Drift migration target from implementation HEAD above accepted schema 23 and freeze its PK/FK/index plan;
- publish the public-command qualification manifest for all 27 POS/NEG process oracles, including exact fixtures, scopes, subjects, required dimensions and expected statuses;
- re-run ownership reconciliation after the concrete Drift schema exists, proving no ELV5 table becomes a duplicate canonical owner of ELV3/ELV4 cable/port/component/source/battery identities.
