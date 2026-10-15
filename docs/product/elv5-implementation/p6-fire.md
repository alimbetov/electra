# P6 — Fire-alarm implementation

Status: DESIGN DRAFT / RUNTIME NOT STARTED
Depends on: P1/P2, signal topology and supported electrical kernels.
Parent: [ELV5 design](../elv5-discipline-calculations-design-specification.md); [process contracts](process-contracts.md).

## Requirements and planned proof

| Requirement | Required implementation behavior | Planned acceptance |
|---|---|---|
| ELV5-P6-001 | Implement FA-01 distinct physical-device/address-resource limits and uniqueness | P6-T01 |
| ELV5-P6-002 | Implement FA-02 explicit standby/alarm/simultaneous current origins without own-load duplication | P6-T02 |
| ELV5-P6-003 | Implement FA-03 supported electrical basis with explicit unsupported closed-loop/shared-return behavior | P6-T03 |
| ELV5-P6-004 | Implement FA-04 complete panel/loop/notification/auxiliary source requirement set | P6-T04 |
| ELV5-P6-005 | Implement FA-05 explicit standby/alarm sequence and selected bank applicability | P6-T05 |
| ELV5-P6-006 | Implement FA-06 notification count/current/peak/terminal-voltage basis | P6-T06 |
| ELV5-P6-007 | Implement FA-07 closure/branch/isolation/address signal policy and FA-08 cable/evidence policy basis | P6-T07 |
| ELV5-P6-008 | Qualify safety-critical missing-policy behavior, technical claim scope and complete restart/history cases | P6-T08 |

## Concrete contract

Address consumption is profile data: a single module may occupy multiple addresses. Validate loop-scoped domains and reserved capacity; graph membership does not imply one address. FA-02 prepares or reads the same uniquely identified state origins as the physical load model; its subtotal is not added again to those raw loads in PWR-01/FA-04.

A closed signal loop may pass FA-07 while its unsupported electrical mesh remains BLOCKED in FA-03. Qualification must distinguish a supported radial electrical case from an unsupported full loop, not erase return edges to make the loop radial. Isolator presence alone does not prove short-circuit survivability.

FA-08 required ELV5 dimensions are exact project-policy match, route/cable evidence and explicit claim scope. VERIFIED_COMPLIANT is never produced by fictional/project-authored profiles; ELV7 owns that later verified applicability. Missing technical cable/policy input blocks even the basis. No default national standby/alarm hours or fire cable classes are supplied.

## Exit

P6 runtime acceptance requires its numbered assertions at the same accepted source SHA and its prerequisite gates. This document is a design contract, not proof of source implementation.
