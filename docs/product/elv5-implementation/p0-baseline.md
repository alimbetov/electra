# P0 — Baseline and stage integration

Status: DESIGN HARDENED / RUNTIME NOT STARTED
Depends on: Existing ELV1–ELV4 source/design/evidence.
Parent: [ELV5 design](../elv5-discipline-calculations-design-specification.md); [process contracts](process-contracts.md); [engineering primitives](engineering-primitives-contract.md); [production source blueprint](production-source-blueprint.md).

Inherited implementation and mandatory new extensions: [baseline contract P0](implemented-baseline.md#p0); [pinned evidence](baseline.json).

## Requirements and planned proof

| Requirement | Required implementation behavior | Planned acceptance |
|---|---|---|
| ELV5-P0-001 | Pin accepted ELV4 source, merge SHA, schema 23 and real supported migration origins | P0-T01 |
| ELV5-P0-002 | Reuse implemented ELV4 RM01–RM15 with source/test/CI evidence and recorded architecture deviations | P0-T02 |
| ELV5-P0-003 | Map all legacy/ELV3/ELV4 result consumers before adding owner ELV5 | P0-T03 |
| ELV5-P0-004 | Inventory canonical equipment/profile/path/assembly editors and snapshot/history writers | P0-T04 |
| ELV5-P0-005 | Freeze supported technical scope and explicit ELV6/ELV7/ELV8 boundaries for all 27 codes | P0-T05 |
| ELV5-P0-006 | Identify exact ELV4 evidence reuse/policy composition and required runtime capabilities | P0-T06 |
| ELV5-P0-007 | Design four-discipline/shared-source public-command qualification fixtures and no-false-PASS sentinels | P0-T07 |
| ELV5-P0-008 | Record runtime-entry outcome without treating merge, CI design guard or SPEC_RESOLVED as implemented capability | P0-T08 |

## Concrete contract

Inventory entries contain source symbol/table/key, canonical owner, command owner, lifecycle/CAS, schema/codec, dependency keys, freeze/materialization coverage, tests and exact executed SHA. ELV4 power graph/PWR kernels, dedicated result isolation, reviewed canonical projection and freeze/materialization are inherited accepted prerequisites. The [baseline manifest](baseline.json) pins their source/test/CI evidence; new discipline adapter isolation is separately qualified by ELV5.

### Frozen implementation-entry assumptions

P0 no longer leaves these choices open to later packages:

```text
inherited database schema = 23
ELV5 additive database target = 24
ELV5 owner/result namespace = engineering-node-v3 / ELV5
public ELV5 discipline operations = exactly 16
ELV5 process codes = exactly 27
ELV5 primary P8 verticals = exactly 54 POS/NEG entries
canonical engineering hash encoder = electra.canonical-json.v1
power/cable/port/component/source/battery canonical ownership remains ELV3/ELV4/platform-owned
revision freeze/create-next remains the existing shared public boundary
```

### Required reuse map

P0 implementation evidence must identify the actual production owners reused by ELV5 for:

- project/design revision lifecycle and revision token;
- shared command ledger and replay semantics;
- shared write-unit-of-work/transaction boundary;
- complete revision history/cursor and undo/redo;
- canonical component/port/cable/run/resource identities;
- immutable catalog/component definition editions;
- ELV4 immutable power evaluations/pointers and their generation semantics;
- snapshot manifest/freeze and create-next identity remapping;
- existing UI editor/revision context required by the ELV5 workspace.

If any required capability is absent in the accepted baseline, P0 records it as an explicit shared-platform delta. ELV5 may not silently create a package-local replacement.

### Ownership map that must remain impossible to violate

ELV5 owns discipline calculation aspects, policy bindings, non-owning assignments, immutable discipline evaluations/pointers and dependency indexes. It does **not** own a second version of:

```text
project/revision
physical cable/run
component/port
power source/PSE/battery
immutable device capability definition
command ledger/history cursor
```

This ownership map is later re-audited after schema 24 exists in source.

### Stage boundary map

P0 fixes downstream ownership before formulas are implemented:

- ELV6 — actual enclosure/rack placement, U positions, clearance, thermal/ventilation and cable-management fit;
- ELV7 — verified normative applicability, jurisdiction and compliance/certification;
- ELV8 — concrete equipment/SKU selection, BOM, commercial/procurement deliverables.

ELV5 may produce exact technical demand and provenance needed by those stages but must report their conclusions as NOT_ASSESSED/UNRESOLVED where appropriate.

## Runtime entry

Runtime entry requires actual shared result-owner isolation, numeric/canonical contracts, revision/command/history/remapping and accepted physical-power kernels needed by the dependent package. Inherited evidence is not reimplemented; new ELV5 integration remains subject to its own L0–L6 runtime gates.

P0 runtime acceptance also verifies that actual production source still matches the design assumptions above. A later change to schema ownership, command platform or revision lifecycle must update P0 before downstream runtime evidence can close.

## Exit

P0 runtime acceptance requires P0-T01…T08 at the same accepted source SHA and its prerequisite gates. This document is a hardened design contract, not proof that ELV5 runtime implementation has started.
