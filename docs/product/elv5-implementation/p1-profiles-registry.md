# P1 — Typed discipline profiles and process registry

Status: DESIGN DRAFT / RUNTIME NOT STARTED
Depends on: P0 ownership/scope map.
Parent: [ELV5 design](../elv5-discipline-calculations-design-specification.md); [process contracts](process-contracts.md); [code-level runtime contract](code-level-runtime-contract.md).

Inherited implementation and mandatory new extensions: [baseline contract P1](implemented-baseline.md#p1); [pinned evidence](baseline.json). This contract supersedes the original design-only parent assumptions.

## Requirements and planned proof

| Requirement | Required implementation behavior | Planned acceptance |
|---|---|---|
| ELV5-P1-001 | Register exactly 27 stable discipline process codes with algorithm/input/output versions | P1-T01 |
| ELV5-P1-002 | Define typed immutable policy editions with exact applicability, units, source status and hashes | P1-T02 |
| ELV5-P1-003 | Define DESIGN/SEGMENT/SEQUENCE key and process input/output scope compatibility | P1-T03 |
| ELV5-P1-004 | Model stream/recording, link/port, door/channel and fire/address assignments without duplicate canonical identities | P1-T04 |
| ELV5-P1-005 | Extend exact-decimal/rational quantities with signed coordinates/dBm and versioned bounded geometry output | P1-T05 |
| ELV5-P1-006 | Define shared-source requirement composition without repeated reserves/losses or reduced membership totals | P1-T06 |
| ELV5-P1-007 | Specify strict new wire schema/codec examples and preserve legacy/ELV4 decoder/hash invariants | P1-T07 |
| ELV5-P1-008 | Define code-owned dependency/evaluation registry, model-limit outcomes and per-dimension status | P1-T08 |

## Concrete contract

The machine-readable process registry is the design source for process membership, modes and planned oracles. Runtime registry is compiled/code-owned, not arbitrary expressions imported from profiles. Policy definitions are data, versioned and validated before adoption. Imported executable formula/script content is not supported.

The runtime implementation MUST expose one closed `Elv5ProcessRegistry` containing exactly CCTV-01…06, LAN-01…07, ACS-01…06 and FA-01…08. Each definition pins `algorithmVersion`, `inputSchemaVersion`, `outputSchemaVersion`, required dimension codes, discipline, legal scope kinds and typed upstream bindings. Startup/test construction fails on missing/duplicate code, unknown upstream process, unknown binder, invalid scope compatibility or cycle.

`Elv5EngineeringNodeKeyV3` is owner-isolated from `PowerNodeKeyV2` and serializes `[engineering-node-v3, ELV5, revision, scenarioKey, scopeKind, scopeId, processCode, subjectKind, subjectId]`. DESIGN uses scenarioKey `NONE`; SEGMENT/SEQUENCE require actual power scenario context when registered. UI scenario selection never silently rewrites calculation identity.

Freshness, completion, assessment and execution are separate types. `CURRENT` is pointer freshness, not a verdict. A completed technical violation is SUCCEEDED/COMPLETE/FAIL; missing model/input may be BLOCKED/UNRESOLVED; ELV6/7/8-owned dimensions remain explicitly NOT_ASSESSED where the process contract says so.

New discipline evaluation/key v3 dispatch is separate from PowerNodeKeyV2 and its ELV-PWR-only evidence. Public command schemas are a different version axis: keep `electra.elv4-command.v1` and `electra.elv4-revision-command.v2` unchanged and register strict `electra.elv5-discipline-command.v1` with payload schema version 1. The initial ELV5 registry contains exactly the 16 operations fixed by the code-level runtime contract. Unknown owner/schema/operation/version combinations are rejected before mutation.

Retain old keys/decoders/hashes and reject unknown owner/schema/operation/version combinations before mutation. Signed quantities are permitted only for coordinates, dBm and signed margins; current, capacity, durations and losses remain nonnegative. Numeric uncertainty uses conservative intervals, never an epsilon allowing overload.

DESIGN consumers of power evidence, such as CCTV-06, declare the complete required scenario/segment applicability set in their policy and consume those exact evidence refs. They do not use whichever UI scenario happens to be selected. Source-owned requirement sets consider every participating discipline and select the strongest applicable capability constraint per dimension on one physical demand; incompatible scenario policies require explicit project composition.

### Mandatory runtime type surface

P1 implementation MUST introduce equivalents of:

- `Elv5Discipline`, `Elv5ScopeKind`, `Elv5Freshness`, `Elv5Completion`, `Elv5Assessment`, `Elv5Execution`;
- `Elv5EngineeringNodeKeyV3`;
- exact decimal/rational and conservative interval types;
- immutable `Elv5PolicyEditionRef` and typed policy editions;
- typed `Elv5ProcessDefinition<TInput,TOutput>` and total `Elv5ProcessRegistry`;
- sealed input resolution outcomes: resolved, blocked-by-missing-dependency, unsupported-model;
- immutable dimension result/evaluation draft contracts.

Dynamic maps are limited to codec/storage boundaries and may not flow through calculation kernels as untyped property bags.

### Mandatory codec examples before implementation entry

P1-T07 is not satisfied by naming the schema. The specification/fixture set MUST include one canonical valid JSON envelope and at least one rejection example for every one of the 16 registered operations, including exact nested identity rules for streams, recordings, optical events, door/controller resources and fire address sets.

## Exit

P1 runtime acceptance requires its numbered assertions at the same accepted source SHA and its prerequisite gates. This document is a design contract, not proof of source implementation.

P1 implementation entry is blocked until the 27-process registry, required-dimension inventory and exact 16-operation command registry are mutually consistent and the command examples are frozen.

## Audit refinements

Audit resolutions require: exact pool/copy/sizing/channel basis types; integer-capacity rounding separate from UI formatting; signed optical physical-loss interval separate from design reserve; full expanded fire address sets; gross/net rack capacity tag. Registry upstream edges use registered code/scope/subject/condition fields and are validated for unknown nodes/cycles; free-text dependency notes never drive execution.
