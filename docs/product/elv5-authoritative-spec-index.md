# Electra — ELV5 Authoritative Design Index

Status: DESIGN DRAFT / RUNTIME NOT STARTED
Branch: `feat/flutter-elv5-power-topology-design`
Parent branch: `feat/flutter-elv4-power-topology-design`
Pinned parent: `4c35840bf1453df8adc49cce18d937fe20a52801`

The branch name is retained as requested. ELV5 is **discipline-specific engineering calculations**, not a second power-topology foundation. ELV4 owns common physical power models; ELV5 owns explicit calling context, discipline policies and the remaining discipline calculations.

## Entry documents

1. [ELV5 design specification](elv5-discipline-calculations-design-specification.md).
2. [P0–P9 delivery plan](elv5-p0-p9-delivery-plan.md).
3. [Detailed implementation index](elv5-implementation/README.md), with one contract for each package.
4. [27-process contract registry](elv5-implementation/process-contracts.md) and [machine-readable registry](elv5-implementation/process-registry.json).
5. [Baseline and boundary audit](../audit/elv5-baseline-alignment-audit.md).

## Authority and acceptance

Existing ELV1–ELV4 identities, ownership, reference editions, physical routing, revision lifecycle and resolved RM01–RM15 contracts remain authoritative. ELV5 adds typed discipline definitions and versioned process registration, not replacement ports/cables/cache/history/revision lifecycles. Shared platform extensions must update both stages' contracts explicitly.

Within ELV5 the design governs boundaries; process registry governs each algorithm's inputs/outputs; package contracts govern writes and proof. Semantic changes require synchronized updates, not package-local overrides. The older architecture overview remains background: its mixed state list and ambiguous recording-duration formula are refined here, not copied into runtime codecs.

All P0–P9 runtime packages are NOT_STARTED. ELV4 design findings were SPEC_RESOLVED, not implemented or runtime accepted. ELV5 design may proceed; runtime acceptance depends on evidenced ELV4 prerequisite capability gates and unresolved ELV1–ELV3 baseline reconciliation. Missing evidence is not a newly proven source defect.

## Initial technical audit

The [all-package/process audit](../audit/elv5-technical-audit.md) reviewed 80 requirements and 27 process contracts, identified 6 HIGH/2 MEDIUM design findings and resolved all eight in specification. Runtime acceptance remains unproven. See the [structured coverage/probes](../audit/elv5-technical-audit.json).
