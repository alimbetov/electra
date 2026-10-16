# P4 — LAN and structured-cabling implementation

Status: DESIGN DRAFT / RUNTIME NOT STARTED
Depends on: P1/P2, ELV3 lengths/resources and PWR-06.
Parent: [ELV5 design](../elv5-discipline-calculations-design-specification.md); [process contracts](process-contracts.md).

Inherited implementation and mandatory new extensions: [baseline contract P4](implemented-baseline.md#p4); [pinned evidence](baseline.json). This contract supersedes the original design-only parent assumptions.

## Requirements and planned proof

| Requirement | Required implementation behavior | Planned acceptance |
|---|---|---|
| ELV5-P4-001 | Implement LAN-01 permanent/channel section unions and nonduplicated installed allowances | P4-T01 |
| ELV5-P4-002 | Implement LAN-02 physical switch assignment and explicit integer spare policy | P4-T02 |
| ELV5-P4-003 | Implement LAN-03 global shared-source PoE context without duplicate electrical calculation | P4-T03 |
| ELV5-P4-004 | Implement LAN-04 complete copper path compatibility against selected profile matrix | P4-T04 |
| ELV5-P4-005 | Implement LAN-05 bidirectional signed optical sensitivity and overload budgets | P4-T05 |
| ELV5-P4-006 | Implement LAN-06 demand/capacity basis without ELV6 slot-layout/fit claims | P4-T06 |
| ELV5-P4-007 | Implement LAN-07 patch resource counts and mapping completeness | P4-T07 |
| ELV5-P4-008 | Qualify exact boundary, missing/unsupported inputs, independent paths and restart/freeze behavior | P4-T08 |

## Concrete contract

A section identity can contribute once to a given physical length category; patch, termination and installed slack accounting flags are explicit. Limits come from pinned profiles, never a hardcoded universal channel limit. Occupied physical resources are counted across all memberships; required spare follows an explicitly selected denominator/ceiling policy.

Optical loss counts mated connector pairs and splice events, not two cable ends as two separate connector losses by default. Each direction pins wavelength and its own TxMin/TxMax/receiver sensitivity/overload. Check minimum received power with maximum loss and maximum received power with minimum loss; adequate sensitivity alone does not prove feasibility. Fiber field types allow signed dBm while dB loss remains nonnegative.

Rack basis reports required RU/weight/depth and available-limit comparison only when provided. Missing placement/clearance/thermal layout remains NOT_ASSESSED and is outside required ELV5 basis dimensions. ELV6 receives these inputs explicitly.

## Exit

P4 runtime acceptance requires its numbered assertions at the same accepted source SHA and its prerequisite gates. This document is a design contract, not proof of source implementation.

## Audit refinements

LAN-05 keeps physical lossMin/lossMax free of engineering reserve: sensitivity margin is required separately against TxMin-lossMax; overload always checks TxMax-lossMin without fictitious attenuation. LAN-06 tags GROSS_WITH_EXCLUSIONS versus NET_USABLE and subtracts known reservations once. Neither basis proves layout/fit.
