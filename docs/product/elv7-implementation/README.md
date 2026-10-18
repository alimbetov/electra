# ELV7 implementation design package

Status: DESIGN HARDENED / RUNTIME NOT STARTED / NO VERIFIED PRODUCTION PACKS.

| Contract | Purpose |
|---|---|
| [Code-level runtime](code-level-runtime-contract.md) | Exact types, coverage, claims, publication, storage, lifecycle, performance and qualification |
| [Protection and classifications](protection-and-classification-contract.md) | B/C/D, K/Z/MA, RCD, fuses, SPD, cable/room categories, numerical proof boundaries |
| [Rule-family registry](rule-family-registry.json) | 45 proposed normative families and explicit mapping of all 27 ELV5 processes |
| [Command registry](command-registry.json) | 12 project operations, separate catalogue governance, inherited revision commands |
| [Upstream handoff](upstream-handoff-contract.md) | Main/ELV5 reality, provisional ELV6 evidence and ownership |
| [Baseline pins](baseline-and-handoff.json) | Exact source SHA/schema/ELV6 contract fingerprints |
| [Source review](source-review-notes.md) | Primary-source observations and unverified release obligations |
| [Qualification plan](qualification-plan.json) | 362 planned scenarios, Q0–Q9 witness fields, zero executed qualifications |

Run `python3 scripts/ci/check-elv7-design-contract.py` for design consistency.
It checks registry coverage, namespaces, command boundaries, source/status
claims, historical handoff pins and planned-case integrity. It does not execute
a normative engine or qualify any legal rule. Runtime remains NOT_STARTED;
all planned scenarios require actual inputs, independent oracles and exact-SHA
non-skipped execution before they count as evidence.
