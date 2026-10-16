# P4 — LAN and structured-cabling implementation

Status: DESIGN HARDENED / RUNTIME NOT STARTED
Depends on: P1/P2, ELV3 lengths/resources and exact PWR-06 evidence where powered.
Parent: [ELV5 design](../elv5-discipline-calculations-design-specification.md); [process contracts](process-contracts.md); [typed process API](typed-process-api.md); [engineering primitives](engineering-primitives-contract.md).

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

## LAN-01 — permanent link / channel length

A realized section identity contributes once to its declared role in one selected link composition. The typed ordered path distinguishes permanent, patch and explicit allowance sections. Installed slack/service-loop allowance already represented by a realized section cannot be added again through a policy multiplier.

There is no universal hardcoded `90m/100m` rule in the kernel. Limits and permitted composition come from the selected immutable policy/profile. If the product/project policy selects another technology or stricter basis, the exact edition governs.

Required proof includes:

```text
below limit
exactly at limit
one canonical unit above limit
duplicate section identity
missing realized section
explicit allowance already included vs not included
```

## LAN-02 — switch-port capacity

Capacity is based on canonical physical port identities and their immutable capabilities. Each assignment binds endpoint → one exact port → selected speed/media mode.

Rules:

- one physical port cannot be occupied twice in the same active capacity context;
- media and speed compatibility are independent from mere port count;
- administratively/project-reserved ports are inventory state, not duplicated demand;
- spare requirement uses the exact selected ratio/denominator and code-owned ceiling rule;
- available compatible ports and required spare are integer quantities; UI percentages never drive verdicts.

A switch with free ports can still FAIL because the free ports are incompatible with the required media/mode.

## LAN-03 — shared PoE context

LAN-03 references the same immutable PWR-06 physical evidence used by any CCTV/other discipline sharing the PSE. It exposes global demand/budget/margin and LAN contribution.

Filtering to LAN endpoints must not recalculate a reduced PSE and publish it as global evidence. One physical PSE context has one physical budget evidence identity for the same captured facts/scenario.

## LAN-04 — copper path compatibility

Compatibility is evaluated over the complete passive path, not only the main horizontal cable. Typed path evidence includes each relevant section/termination/connector/patch component and immutable capability edition.

The supported speed/mode set is constrained by the weakest incompatible element. A high-category horizontal cable does not override an incompatible patch cord, connector or interface.

Shielding/grounding-related evidence is reported only to the exact technical scope represented by selected policy facts; no national-compliance conclusion is inferred here.

## LAN-05 — bidirectional optical budget

The kernel must enforce the physical distinction:

```text
dB  = attenuation/loss/margin quantity
dBm = absolute optical power level
```

These are different types/value objects. They cannot be passed interchangeably through a legal typed kernel call.

For each direction independently:

```text
physical loss interval = fiber attenuation + mated connector-pair losses + splice/event losses
minimum received power = TxMin - lossMax
maximum received power = TxMax - lossMin
sensitivity margin     = minimum received power - receiverSensitivity
 overload margin       = receiverOverload - maximum received power
```

Required design sensitivity margin remains a separate nonnegative dB requirement; it is not inserted into physical loss. Overload uses physical minimum loss and must not benefit from a fictitious reserve attenuation.

Each direction pins transmitter, receiver, wavelength and immutable source evidence. A connector pair is one mated-pair event unless the selected exact model explicitly defines otherwise.

### Optical reach is a separate claim

Passing sensitivity/overload does not prove transmission reach/dispersion/modal bandwidth at the selected rate. ELV5 may emit a reach-compatibility dimension only when an exact registered optic/fiber reach profile or separately versioned model is consumed. Without it, reach remains outside claim scope / NOT_ASSESSED rather than inferred from optical power budget.

Required P4 tests include a case where optical power budget passes but selected reach profile fails or is unavailable.

## LAN-06 — rack demand/capacity basis

LAN-06 is intentionally a **demand/capacity handoff**, not cabinet layout.

ELV5 may calculate/store:

```text
equipment RU demand
declared gross or net usable RU basis
explicit exclusions/reservations
free RU margin
optional aggregate weight demand
optional maximum equipment depth demand
exact equipment membership/provenance
```

Capacity basis is explicitly tagged:

```text
GROSS_WITH_EXCLUSIONS
NET_USABLE
```

Known exclusions are subtracted exactly once. If both representations describe the same usable rack, their normalized usable capacity/result must agree.

ELV5 must return actual slot/U-position, collision, front/rear clearance, rail fit, thermal/airflow, PDU placement and cable-management fit as NOT_ASSESSED. Those belong to ELV6. A positive RU margin is therefore not an ELV6 layout PASS.

## LAN-07 — patch-panel utilization

Patch-panel occupancy is based on canonical panel-port identity. One active panel port cannot terminate two independent assignments unless a later explicit hardware model supports that semantics.

The process independently checks:

```text
occupied ports
free ports
required spare
free-after-reserve
interface compatibility/mapping completeness
endpoint/destination identity
```

A numerical free-port margin cannot mask an invalid/missing endpoint mapping.

## Provenance and evidence quality

All capacity/compatibility/loss facts consumed from device/cable/optic definitions retain exact immutable definition reference/hash and engineering basis. Typical/estimated optical attenuation or reach must not silently satisfy a process dimension whose selected policy requires a guaranteed limit.

Environmental applicability is explicit. If the consumed definition is only valid in an environmental envelope that does not cover the captured route/equipment conditions, the affected dimension is unresolved/blocked rather than evaluated at an implicit room-temperature default.

## Dependencies and invalidation

P4 dependency closure includes exact:

```text
realized section SET + ordered path
switch/panel physical port SET
endpoint assignments
selected speed/media mode
immutable cable/connector/optic definition refs/hashes
optical event SET + direction/wavelength
rack equipment membership + capacity basis
spare/compatibility/policy editions
exact PWR-06 evidence/pointer generation for LAN-03
MISSING markers for absent path/definition/policy/evidence
```

Removing/moving a link section or port invalidates both the old and new relevant closure. An optical event edit does not invalidate an unrelated ACS door unless they share an explicit dependency.

## Public vertical qualification

Primary LAN qualification executes through real public setup commands, schema-24 file SQLite, `CALCULATE_DISCIPLINE_PROCESS`, production capture/typed resolver/kernel/publication and close/reopen projection verification.

Required adversarial cases include:

- duplicate physical port assignment;
- enough ports but incompatible media/speed;
- exact spare ceiling boundary;
- path cable compatible but one patch/connector incompatible;
- forward optical direction passes while reverse fails;
- sensitivity passes but overload fails;
- dB/dBm misuse impossible at typed API/tests;
- physical budget passes but reach is unavailable/fails;
- GROSS_WITH_EXCLUSIONS and equivalent NET_USABLE normalization;
- positive RU margin while actual ELV6 fit remains NOT_ASSESSED;
- shared LAN/CCTV PSE preserves one global PWR-06 evidence;
- reopen/freeze preserves exact ordered path, hashes and provenance.

## Exit

P4 runtime acceptance requires P4-T01…T08 and both primary POS/NEG entries for LAN-01…07 at the same accepted source SHA, together with required L0–L6 coverage.

This document is a hardened design contract, not proof of source implementation.
