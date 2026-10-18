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
| [Qualification plan](qualification-plan.json) | 364 planned scenarios, Q0–Q9 witness fields, zero executed qualifications |

Run `python3 scripts/ci/check-elv7-design-contract.py` for design consistency.
It checks registry coverage, namespaces, command boundaries, source/status
claims, historical handoff pins and planned-case integrity. It does not execute
a normative engine or qualify any legal rule. Runtime remains NOT_STARTED;
all planned scenarios require actual inputs, independent oracles and exact-SHA
non-skipped execution before they count as evidence.

The [component catalogue proposal](../component-catalog/README.md) specifies a
separate reusable technical/offer database aligned to all 21 professional CAP,
14 K and 10 smart-building SH targets. Its 23 product families and 40 catalogue
acceptance scenarios are design inventories, separate from the 45 normative
families and 364 normative scenarios above. ELV7 retains normative authority;
ELV8 retains product selection and ELV6 actual layout ownership.
