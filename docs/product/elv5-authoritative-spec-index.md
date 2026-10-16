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
4. [27-process contract registry](elv5-implementation/process-contracts.md) and [machine-readable registry](elv5-implementation/process-registry.json).
5. [Baseline and boundary audit](../audit/elv5-baseline-alignment-audit.md).
6. [Implemented baseline and extension contract](elv5-implementation/implemented-baseline.md) and [evidence manifest](elv5-implementation/baseline.json).

## Authority and acceptance

Existing ELV1–ELV4 identities, ownership, reference editions, physical routing, revision lifecycle and resolved RM01–RM15 contracts remain authoritative. ELV5 adds typed discipline definitions and versioned process registration, not replacement ports/cables/cache/history/revision lifecycles. Shared platform extensions must update both stages' contracts explicitly.

Within ELV5 the design governs boundaries; process registry governs each algorithm's inputs/outputs; package contracts govern writes and proof. Semantic changes require synchronized updates, not package-local overrides. The older architecture overview remains background: its mixed state list and ambiguous recording-duration formula are refined here, not copied into runtime codecs.

All ELV5 P0–P9 runtime packages remain NOT_STARTED. ELV4 is implemented, runtime accepted at the pinned source SHA and merged through PR #11 at `d2b059d4c11a284cdd32965140f6df3c40020c8d`. The [implemented baseline contract](elv5-implementation/implemented-baseline.md) governs reuse and new integration work. ELV4 acceptance does not qualify the 27 new ELV5 processes.

## Initial technical audit

The [all-package/process audit](../audit/elv5-technical-audit.md) reviewed 80 requirements and 27 process contracts, identified 6 HIGH/2 MEDIUM design findings and resolved all eight in specification. Runtime acceptance remains unproven. See the [structured coverage/probes](../audit/elv5-technical-audit.json).
