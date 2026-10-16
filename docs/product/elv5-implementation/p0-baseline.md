# P0 — Baseline and stage integration

Status: DESIGN DRAFT / RUNTIME NOT STARTED
Depends on: Existing ELV1–ELV4 source/design/evidence.
Parent: [ELV5 design](../elv5-discipline-calculations-design-specification.md); [process contracts](process-contracts.md).

Inherited implementation and mandatory new extensions: [baseline contract P0](implemented-baseline.md#p0); [pinned evidence](baseline.json). This contract supersedes the original design-only parent assumptions.

## Requirements and planned proof

| Requirement | Required implementation behavior | Planned acceptance |
|---|---|---|
| ELV5-P0-001 | Pin accepted ELV4 source, merge SHA, schema 23 and real v21/v22 migration origins | P0-T01 |
| ELV5-P0-002 | Reuse implemented ELV4 RM01–RM15 with source/test/CI evidence and recorded architecture deviations | P0-T02 |
| ELV5-P0-003 | Map all legacy/ELV3/ELV4 result consumers before adding owner ELV5 | P0-T03 |
| ELV5-P0-004 | Inventory canonical equipment/profile/path/assembly editors and snapshot/history writers | P0-T04 |
| ELV5-P0-005 | Freeze supported technical scope and explicit ELV6/ELV7/ELV8 boundaries for all 27 codes | P0-T05 |
| ELV5-P0-006 | Identify exact ELV4 evidence reuse/policy composition and required runtime capabilities | P0-T06 |
| ELV5-P0-007 | Design four-discipline and shared-source public-command qualification fixtures | P0-T07 |
| ELV5-P0-008 | Record runtime-entry outcome without treating merge or SPEC_RESOLVED as implemented capability | P0-T08 |

## Concrete contract

Inventory entries contain source symbol/table/key, command owner, lifecycle/CAS, schema/codec, dependency keys, freeze/materialization coverage, tests and exact executed SHA. ELV4 PowerGraph/PWR kernels, dedicated result isolation, reviewed canonical projection and freeze/materialization are implemented and accepted. The [baseline manifest](baseline.json) pins their source/test/CI evidence. Verify new discipline adapter isolation separately.

Runtime entry requires actual shared result-owner isolation, numeric contracts, revision/command/history/remapping and accepted power kernels needed by the dependent package. Do not create ELV5-owned replacements to bypass a missing ELV4 prerequisite. The inherited baseline is evidenced; new ELV5 integration remains subject to its own runtime gates.

## Exit

P0 runtime acceptance requires its numbered assertions at the same accepted source SHA and its prerequisite gates. This document is a design contract, not proof of source implementation.
