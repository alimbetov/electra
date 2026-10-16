# P4 — LAN and structured-cabling implementation

Status: DESIGN HARDENED / RUNTIME NOT STARTED
Depends on: P1/P2, ELV3 lengths/resources and exact PWR-06 evidence where powered.
Parent: [ELV5 design](../elv5-discipline-calculations-design-specification.md); [process contracts](process-contracts.md); [typed process API](typed-process-api.md); [engineering primitives](engineering-primitives-contract.md); [LAN code-level dossiers](process-specifications/lan-processes.md); [Flutter performance contract](flutter-performance-contract.md).

Inherited implementation and mandatory new extensions: [baseline contract P4](implemented-baseline.md#p4); [pinned evidence](baseline.json).

## Requirements and planned proof

| Requirement | Required implementation behavior | Planned acceptance |
|---|---|---|
| ELV5-P4-001 | Implement LAN-01 ordered permanent/channel section accounting with no duplicated installed allowance | P4-T01 |
| ELV5-P4-002 | Implement LAN-02 unique physical switch-port assignment, compatibility and explicit integer spare policy | P4-T02 |
| ELV5-P4-003 | Implement LAN-03 global shared-source PoE context without duplicate electrical calculation | P4-T03 |
| ELV5-P4-004 | Implement LAN-04 full passive copper-path compatibility against selected immutable policy/definition evidence | P4-T04 |
| ELV5-P4-005 | Implement LAN-05 bidirectional dB/dBm optical sensitivity/overload budgets with optional separately evidenced reach model | P4-T05 |
| ELV5-P4-006 | Implement LAN-06 rack demand/capacity basis and explicit ELV6 handoff without actual layout-fit claims | P4-T06 |
| ELV5-P4-007 | Implement LAN-07 unique patch-panel port occupancy, mapping completeness and spare policy | P4-T07 |
| ELV5-P4-008 | Qualify exact boundaries, missing/unsupported inputs, restart/freeze, shared PSE and no-false-PASS cases | P4-T08 |

## Normative code-level binding

The package text below is a summary. Runtime implementation MUST match LAN-01…07 in [process-specifications/lan-processes.md](process-specifications/lan-processes.md) for all 25 dossier sections: applicability, typed inputs/evidence, cases, mathematical model/equations, exact arithmetic, worst case, requirements, comparisons/margins, governing/limiting factor, missing behavior, dependencies, trace, complexity, pseudocode, Dart interfaces and all five vector classes.

Implementation priority inside P4 is **LAN-01 then LAN-05**. Together they prove exact installed-path accounting and conservative interval optical algebra before the simpler capacity/basis checks.

## LAN-01 — permanent link / channel length

A realized section identity contributes once to its declared role in one selected link composition. The typed ordered path distinguishes permanent, patch and explicit allowance sections. Installed slack/service-loop allowance already represented by a realized section cannot be added again through a policy multiplier.

There is no universal hardcoded `90m/100m` rule in the kernel. Limits and permitted composition come from the selected immutable policy/profile. Maximum-length comparisons use the conservative upper installed-length bound and exact signed margin `limit - realizedUpper`; display rounding never decides verdict.

Required proof includes below/exactly-at/one-canonical-unit-above limit, duplicate section identity, missing realized section and already-included versus not-included allowance.

## LAN-02 — switch-port capacity

Capacity is based on canonical physical port identities and immutable capabilities. One physical port cannot be occupied twice in the same exclusive context; media/speed compatibility is independent from port count; spare ratios use exact rational arithmetic and code-owned `ceil` at the count boundary. Administratively/project-reserved ports are inventory state and are not duplicated as load.

## LAN-03 — shared PoE context

LAN-03 references the same immutable PWR-06 physical evidence used by CCTV/other disciplines sharing the PSE. It exposes the same global demand/budget/margin plus LAN contribution. Filtering to LAN endpoints cannot recompute a reduced PSE and publish it as global evidence.

## LAN-04 — copper path compatibility

Compatibility evaluates every ordered relevant path element, not only the horizontal cable. Capability is limited by the weakest explicit section/property according to the selected compatibility matrix. Category/product names are not parsed into capability. Shielding/grounding facts remain technical evidence and do not manufacture ELV7 compliance.

## LAN-05 — bidirectional optical budget

The kernel enforces different types:

```text
dB  = attenuation/loss/design margin
dBm = absolute optical power level
```

For each direction independently:

```text
LossMin = Σ minimum physical fiber/connector/splice/event losses
LossMax = Σ maximum physical fiber/connector/splice/event losses
RxLow   = TxMin - LossMax
RxHigh  = TxMax - LossMin

SensitivityMargin = RxLow - (ReceiverSensitivity + RequiredSensitivityMargin)
OverloadMargin    = ReceiverOverloadMax - RxHigh
```

Mandatory cases are:

```text
A_TO_B_SENSITIVITY
A_TO_B_OVERLOAD
B_TO_A_SENSITIVITY
B_TO_A_OVERLOAD
```

The governing optical case is the smallest signed dB margin. Physical loss excludes design reserve; overload never receives fictitious reserve attenuation. Connector loss is counted per exact mated-pair/event model, not once per connector end.

Passing optical power budget does not prove reach/dispersion/modal-bandwidth compatibility. Such a dimension exists only with an explicit separately versioned reach model/profile; otherwise it remains NOT_ASSESSED.

## LAN-06 — rack demand/capacity basis

LAN-06 computes RU/weight/depth demand basis and optional simple available-capacity comparisons. Capacity basis is explicitly `GROSS_WITH_EXCLUSIONS` or `NET_USABLE`; known exclusions are subtracted exactly once. Slot/U-position, collision, rail/depth clearance, thermal/airflow, PDU/cable management and cabinet fit remain ELV6 `NOT_ASSESSED` even when every ELV5 numeric capacity margin is positive.

## LAN-07 — patch-panel utilization

Occupancy is keyed by canonical physical panel-port identity. Port count/spare and end-to-end mapping completeness are independent dimensions. Passive continuation and termination relationships cannot make one physical port count twice or create extra capacity.

## Dependencies and invalidation

P4 dependency closure includes exact realized section SET+order, switch/panel physical port SET, endpoint assignments, selected speed/media mode, immutable cable/connector/optic definitions, optical event SET+direction/wavelength, rack membership/capacity basis, spare/compatibility policies, exact PWR-06 evidence/generation and MISSING/selector markers.

Edits invalidate `union(oldClosure,newClosure)` and newly matching selector dependencies. Optical event changes must not invalidate unrelated ACS/Fire nodes absent an actual shared dependency.

## Public vertical qualification

Primary LAN qualification executes through public setup, schema-24 file SQLite, `CALCULATE_DISCIPLINE_PROCESS`, production capture/resolver, `Elv5CalculationExecutor` where required, typed kernel, guarded publication, targeted workspace projection and close/reopen verification.

Required vector coverage includes duplicate physical port assignment, enough ports but incompatible mode, exact spare/length boundary, path cable passing while patch/connector fails, one optical direction passing while reverse fails, sensitivity passing while overload fails, power budget passing while reach is absent/fails, gross/net rack normalization and RU PASS with ELV6 layout NOT_ASSESSED.

## Performance obligations

P4 follows [flutter-performance-contract.md](flutter-performance-contract.md):

- LAN-01 is a single O(P) ordered-path fold, not repeated path scans;
- LAN-02 and LAN-07 use keyed resource/mapping indexes rather than pairwise assignment searches;
- LAN-04 is O(P×R) with code-owned bounded property count `R`;
- LAN-05 is O(P+E) per optical path/direction and propagates intervals directly instead of enumerating uncertainty combinations;
- medium/large captured workloads execute through the native worker executor outside the UI isolate;
- one link/port/optic edit recalculates only the affected dependency closure;
- large link/mapping result lists are projected lazily/virtually in Flutter.

## Exit

P4 runtime acceptance requires P4-T01…T08, both primary POS/NEG entries for LAN-01…07, all LAN boundary/adversarial/cross-discipline dossier vectors, and required L0–L6/performance evidence at the same source SHA and authority fingerprint.

This document is a hardened design contract, not proof of source implementation.
