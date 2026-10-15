# P5 — Access-control implementation

Status: DESIGN DRAFT / RUNTIME NOT STARTED
Depends on: P1/P2, canonical assemblies and power kernels.
Parent: [ELV5 design](../elv5-discipline-calculations-design-specification.md); [process contracts](process-contracts.md).

## Requirements and planned proof

| Requirement | Required implementation behavior | Planned acceptance |
|---|---|---|
| ELV5-P5-001 | Implement ACS-01 explicit door-role alternatives/multiplicities with scoped canonical assignments | P5-T01 |
| ELV5-P5-002 | Implement ACS-02 independent controller reader/relay/input resource capacities | P5-T02 |
| ELV5-P5-003 | Implement ACS-03 lock holding/active/startup mode and shared-trunk voltage evidence | P5-T03 |
| ELV5-P5-004 | Implement ACS-04 shared-source requirement composition with reserve/derating once | P5-T04 |
| ELV5-P5-005 | Implement ACS-05 full protected sequence/model policy and global bank evidence | P5-T05 |
| ELV5-P5-006 | Implement ACS-06 independent reader/control/feed/release topology checks | P5-T06 |
| ELV5-P5-007 | Integrate assignment/deletion/adoption guards, findings and consumed dependency projection | P5-T07 |
| ELV5-P5-008 | Qualify door positives/negatives, shared non-ACS loads, restart and historical evidence | P5-T08 |

## Concrete contract

Door assembly membership is non-owning. Explicit OR alternatives do not mean both roles are required; one component may fill several roles only under a declared allowed mapping. Resource channels are distinct from component counts, and a relay control relation does not create a supply edge.

ACS-03/04/05 are typed wrappers over exact shared PWR evidence, not copies of formulas. An upstream trunk/bank includes all concurrent protected loads, including other systems. Lock startup model is the supported explicit simultaneous policy; no hidden duty or holding factor. Required autonomy duration/extension policy is selected data, not a default. Door operation/safety claims require the corresponding selected policy and supported topology evidence.

## Exit

P5 runtime acceptance requires its numbered assertions at the same accepted source SHA and its prerequisite gates. This document is a design contract, not proof of source implementation.
