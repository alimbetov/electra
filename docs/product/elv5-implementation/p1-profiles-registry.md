# P1 — Typed discipline profiles and process registry

Status: DESIGN DRAFT / RUNTIME NOT STARTED
Depends on: P0 ownership/scope map.
Parent: [ELV5 design](../elv5-discipline-calculations-design-specification.md); [process contracts](process-contracts.md).

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

New discipline evaluation/key v3 dispatch is separate from PowerNodeKeyV2 and its ELV-PWR-only evidence. Public command schemas are a different version axis: keep electra.elv4-command.v1 and electra.elv4-revision-command.v2 unchanged and register a strict ELV5 command family. Retain old keys/decoders/hashes and reject unknown owner/schema/operation/version combinations before mutation. Signed quantities are permitted only for coordinates, dBm and signed margins; current, capacity, durations and losses remain nonnegative. Numeric uncertainty uses conservative intervals, never an epsilon allowing overload.

DESIGN consumers of power evidence, such as CCTV-06, declare the complete required scenario/segment applicability set in their policy and consume those exact evidence refs. They do not use whichever UI scenario happens to be selected. Source-owned requirement sets consider every participating discipline and select the strongest applicable capability constraint per dimension on one physical demand; incompatible scenario policies require explicit project composition.

## Exit

P1 runtime acceptance requires its numbered assertions at the same accepted source SHA and its prerequisite gates. This document is a design contract, not proof of source implementation.

## Audit refinements

Audit resolutions require: exact pool/copy/sizing/channel basis types; integer-capacity rounding separate from UI formatting; signed optical physical-loss interval separate from design reserve; full expanded fire address sets; gross/net rack capacity tag. Registry upstream edges use registered code/scope/subject/condition fields and are validated for unknown nodes/cycles; free-text dependency notes never drive execution.
