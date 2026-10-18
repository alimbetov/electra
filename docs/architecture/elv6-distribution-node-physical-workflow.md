# ELV6 — Distribution Node Physical Workflow

Status: normative product/design contract  
Branch: `feat/flutter-elv6-enclosure-layout-design`

## 1. Purpose

ELV6 SHALL transform the logical `DistributionNode` used by the project workflow into a physically realizable enclosure/rack/cabinet solution without changing ELV5 engineering truth.

User-facing concept:

```text
NODE-F2
  -> required equipment/functions
  -> selected enclosure/rack
  -> physical placement
  -> cable entry/routing
  -> reserve/serviceability
  -> fit result
```

ELV6 owns physical feasibility. It does not own upstream demand, catalog ranking or normative compliance.

## 2. Logical node to physical realization

One logical `DistributionNode` MAY be realized as:

- one enclosure;
- one rack;
- a panel with internal DIN assemblies;
- multiple physically coupled enclosures when capacity requires it.

The logical node identity SHALL remain stable even if its physical realization changes.

```text
DistributionNode
  -> PhysicalNodeRealization
       -> Enclosure/Rack 1
       -> optional Enclosure/Rack 2
       -> placements
       -> entries/routes
```

A user SHALL NOT need to rebuild logical topology merely because a larger cabinet or second enclosure is selected.

## 3. Main and node cabinets

`MAIN` and `NODE` are logical roles inherited from upstream. ELV6 SHALL NOT create separate incompatible layout engines for them.

The same fit engine SHALL evaluate:

- main distribution cabinet;
- floor/node cabinet;
- telecom rack;
- fire cabinet;
- combined ELV cabinet;
- auxiliary battery/UPS enclosure.

Differences SHALL be expressed through physical profiles, placement policies, required reserve and applicable evidence.

## 4. Cable-aware enclosure model

Cable connectivity SHALL materially affect fit.

ELV6 SHALL consider where data is available:

- incoming cable count and direction;
- outgoing cable count and direction;
- cable diameter/bundle envelope;
- gland/entry capacity;
- bend radius;
- terminal reachability;
- segregation/routing zones;
- service loops;
- fiber management;
- patching/termination space;
- removable/service envelopes.

A cabinet SHALL NOT be considered physically acceptable only because all primary devices geometrically fit.

## 5. Capacity planning before SKU selection

The user SHOULD be able to create `NODE-F2` and obtain an early capacity envelope before exact products exist.

ELV6 SHALL therefore support:

```text
abstract equipment envelope
  -> estimated DIN/RU/space/thermal/entry demand
  -> candidate enclosure class
```

and later:

```text
resolved ELV8 SKU assembly
  -> exact physical profiles
  -> final placement validation
```

This preserves the client workflow while avoiding premature catalog lock-in.

## 6. Client-facing result

The normal UI SHALL summarize physical state in understandable terms, for example:

```text
NODE-F2 cabinet
Status: ATTENTION

Used rack units: 15 / 18
Reserved: 2 U
Free after reserve: 1 U
Cable entries: 26 / 32
Thermal load: within current design envelope

Issue:
- only 1 U remains after required reserve
```

Engineering drill-down SHALL expose exact placement evidence, measured envelopes and stable violation codes.

## 7. Remediation proposals

ELV6 MAY produce deterministic remediation options such as:

- choose a larger enclosure/rack;
- split the physical realization into two enclosures;
- move a component to another valid placement zone;
- add required mounting/accessory hardware;
- increase cable-entry capacity;
- preserve required reserve by rejecting the current placement.

ELV6 SHALL NOT silently apply a remediation that changes the project design.

## 8. Coordination with ELV8

ELV8 may evaluate catalog candidates against the ELV6 fit boundary.

The sequence SHALL remain:

```text
ELV5 demand
  -> ELV8 candidate
  -> ELV6 physical assessment
  -> accepted/rejected candidate
```

If the selected candidate changes dimensions, accessories, dissipation or mounting requirements, affected placement evidence becomes stale and is recalculated.

## 9. Acceptance criteria

1. logical MAIN/NODE identity survives enclosure changes;
2. the same physical engine handles main, node, telecom, fire and mixed cabinets;
3. cable entries, terminal access and bend/service space participate in fit;
4. early abstract capacity planning works without concrete SKU selection;
5. exact ELV8 assemblies can later be validated without redesigning the topology;
6. the normal UI gives a compact physical summary and actionable problem statement;
7. exact physical evidence remains available for engineer review and ELV7 qualification;
8. remediation suggestions never silently mutate project design;
9. reserve cannot be consumed without explicit policy-visible consequence;
10. one logical node may use multiple physical enclosures when required without becoming multiple unrelated project nodes.
