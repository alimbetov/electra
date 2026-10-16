# P5 — Access-control implementation

Status: DESIGN HARDENED / RUNTIME NOT STARTED
Depends on: P1/P2, canonical assemblies and power kernels.
Parent: [ELV5 design](../elv5-discipline-calculations-design-specification.md); [process contracts](process-contracts.md); [typed process API](typed-process-api.md); [hardening amendments](code-level-hardening-amendments.md).

Inherited implementation and mandatory new extensions: [baseline contract P5](implemented-baseline.md#p5); [pinned evidence](baseline.json).

## Requirements and planned proof

| Requirement | Required implementation behavior | Planned acceptance |
|---|---|---|
| ELV5-P5-001 | Implement ACS-01 explicit door-role alternatives/multiplicities with scoped canonical assignments | P5-T01 |
| ELV5-P5-002 | Implement ACS-02 independent controller reader/relay/input resource capacities | P5-T02 |
| ELV5-P5-003 | Implement ACS-03 lock holding/active/startup mode and shared-trunk voltage evidence | P5-T03 |
| ELV5-P5-004 | Implement ACS-04 shared-source requirement composition with reserve/derating once | P5-T04 |
| ELV5-P5-005 | Implement ACS-05 full protected sequence/model policy and global bank evidence | P5-T05 |
| ELV5-P5-006 | Implement ACS-06 independent reader/control/feed/monitoring/release topology plus explicit safety/release truth table | P5-T06 |
| ELV5-P5-007 | Integrate assignment/deletion/adoption guards, findings and consumed dependency projection | P5-T07 |
| ELV5-P5-008 | Qualify role/resource/power/release positives/negatives, shared non-ACS loads, restart and historical evidence | P5-T08 |

## Concrete contract

Door assembly membership is non-owning. Explicit OR alternatives do not mean both roles are required; one component may fill several roles only under a declared allowed mapping. Resource channels are distinct from component counts, and a relay control relation does not create a conductive supply edge.

ACS-03/04/05 are typed wrappers over exact shared PWR evidence, not copies of formulas. An upstream trunk/bank includes all concurrent protected loads, including other systems. Lock startup model is the supported explicit simultaneous policy; no hidden duty or holding factor. Required autonomy duration/extension policy is selected data, not a default.

## ACS-06 safety/release contract

ACS-06 must not infer life-safety behavior from component names such as `fire`, `emergency`, `break glass` or from mere presence of a relay/input.

The persisted aggregate contains:

```text
doorAssemblyId
topologyProfileRef
safetyMode
roleAssignments
releaseTruthTable
```

`safetyMode` is one of:

```text
FAIL_SAFE
FAIL_SECURE
PROJECT_DEFINED
```

The initial technical release causes include at least:

```text
NORMAL_ACCESS
REQUEST_TO_EXIT
FIRE_RELEASE
EMERGENCY_BREAK_GLASS
POWER_FAILURE
```

Each truth-table row declares the expected lock outcome and required evidence roles/paths. Runtime resolves and evaluates distinct typed paths for:

```text
reader/data/control
conductive lock feed
monitoring/supervision
release/interlock
```

A dry contact is control evidence only unless a separately captured conductive feed path exists.

### Fail-safe/fail-secure qualification

P5-T06/P5-T08 must include both:

- a fail-safe fixture whose expected power-failure outcome is de-energized/unlocked according to the selected profile;
- a fail-secure or project-defined fixture whose expected behavior is explicitly different and whose release path is proven through its selected topology.

The test validates the project's **technical behavior model**. It does not create a verified jurisdictional egress/fire-code statement; that remains ELV7 scope.

## Shared-source rules

ACS-04/05 consume full physical source/bank closure. Discipline contribution may be displayed, but non-ACS loads cannot be filtered from the physical sizing verdict. Reserve/derating/autonomy extension is applied only at its declared owner/boundary and never per door by repetition.

## Dependency rules

Changing any of the following invalidates exact affected ACS nodes:

```text
door role set
controller resource set
lock state/load profile evidence
selected operating case
safetyMode
releaseTruthTable row/membership
canonical control/feed/release path
exact consumed ELV4 evaluation/pointer generation
policy edition/hash/applicability
```

Unrelated doors/controllers must remain unaffected unless they share a physical source/bank/policy dependency that actually changed.

## Exit

P5 runtime acceptance requires its numbered assertions at the same accepted source SHA and its prerequisite gates. This document is a design contract, not proof of source implementation.

P5 cannot close if ACS-06 reports a generic topology PASS while any required release cause remains unproven, or if a technical release result is labelled verified legal/normative compliance.
