# ELV6 — Project Workspace Physical-Layout Roadmap

Status: normative implementation roadmap  
Branch: `feat/flutter-elv6-enclosure-layout-design`

## 1. Purpose

ELV6 turns a logical `DistributionNode` into a physically realizable enclosure/rack/cabinet arrangement without changing the logical topology owned upstream.

ELV6 owns:

- abstract enclosure/rack capacity planning;
- concrete candidate fit;
- DIN/RU/free-form placement;
- cable entry/routing/terminal access;
- thermal and serviceability evidence;
- reserve and expansion space;
- multi-enclosure realization of one logical node.

ELV6 does not select products by price/brand and does not issue jurisdictional compliance verdicts.

## 2. User journey owned by ELV6

```text
open NODE
 -> inspect required physical envelope
 -> choose/request enclosure
 -> preview placement
 -> detect hard fit issues
 -> inspect remediation options
 -> apply physical-layout decision
 -> publish physical evidence to ELV7/ELV8
```

## 3. Implementation packages

### W6-0 — upstream reconciliation

- pin accepted ELV5 demand/projection versions before runtime entry;
- map `DistributionNode` logical identity without duplicating it;
- consume node equipment demands and exact catalog/abstract physical profiles through APIs;
- define explicit stale behavior when upstream demand changes.

Gate: no ELV6 runtime acceptance on stale/unreconciled ELV5 contracts.

### W6-1 — physical realization model

Introduce the concept:

```text
DistributionNode
  -> PhysicalNodeRealization
       -> 1..N EnclosureInstance
```

One logical node may be realized by several physical cabinets/racks while keeping one upstream node identity.

Required identities:

```text
physicalRealizationId
nodeId
enclosureInstanceId
layoutRevision
```

Gate: split/merge physical cabinets does not rewrite logical connectivity.

### W6-2 — abstract capacity planning

Before exact SKU selection, calculate required physical envelopes from abstract component classes:

- DIN modules;
- RU;
- width/height/depth envelopes;
- mass/load;
- heat dissipation;
- cable-entry count/area;
- terminal capacity;
- bend/service clearance;
- reserve.

Gate: early design can estimate cabinet/rack capacity without a vendor catalog.

### W6-3 — deterministic placement kernel

Required pure evaluators:

```text
ComponentFitEvaluator
AssemblyFitEvaluator
NodeLayoutEvaluator
```

Hard constraints:

- dimensions;
- mounting interface;
- collision;
- access/clearance;
- cable bend/entry;
- terminals;
- mass;
- thermal envelope;
- mandatory accessories;
- mandatory reserve.

Gate: same pinned inputs => same placement result/fingerprint.

### W6-4 — cable-entry and termination workflow

The physical model must include cable reality, not only component rectangles.

Requirements:

- incoming/outgoing cable entry points;
- glands/entry accessories where required;
- termination blocks/patch panels;
- fiber/copper separation where policy requires;
- bend radius and service loop envelope;
- terminal approach/access;
- route occupancy reserve.

Gate: a cabinet cannot PASS if components fit but cables cannot be installed/serviced.

### W6-5 — thermal/service evidence

Produce explicit evidence for:

- total dissipation;
- ventilation assumptions;
- temperature envelope;
- required fan/filter/ventilation accessory where derived from a supported model;
- removal/service clearance;
- front/rear access requirements.

ELV7 consumes normative relevance; ELV6 only proves physical facts.

### W6-6 — remediation engine

When a layout fails, return structured alternatives, for example:

```text
replace 18U with >=24U
split NODE-F2 into Cabinet A + Cabinet B
move selected equipment to adjacent enclosure
choose candidate with smaller physical envelope
reduce optional reserve only through explicit policy decision
```

Remediation is advisory until explicitly applied.

Gate: every supported physical blocker exposes at least one machine-readable reason and, where safely derivable, remediation category.

### W6-7 — workspace projection

Provide a user-facing physical summary:

```text
NODE-F2
required RU / available RU
DIN used / reserved / free
thermal load / envelope
cable entries used / available
serviceability state
physical state = READY | ATTENTION | CRITICAL | NEEDS_DATA | STALE
```

Drill-down must expose exact measurements and evidence.

### W6-8 — ELV8 candidate-validation boundary

ELV8 may ask ELV6 to evaluate a candidate assembly without mutating project layout.

Required behavior:

```text
candidate -> side-effect-free fit evaluation -> Accepted/Rejected + evidence
```

Only explicit Apply may change the selected physical realization.

### W6-9 — golden vertical

Mandatory scenario:

```text
NODE-F2 demand requires 21U
current cabinet = 18U
 -> CRITICAL physical issue
 -> propose 24U replacement and two-cabinet split
 -> preview both
 -> apply one option
 -> layout becomes READY
 -> evidence available to ELV7/ELV8
```

## 4. Testing

Required:

- exact-boundary fit tests;
- collision/access tests;
- cable-entry/bend tests;
- reserve tests;
- mandatory-accessory closure tests;
- thermal evidence tests;
- split realization tests;
- candidate side-effect-free tests;
- stale upstream demand tests;
- deterministic replay/freeze tests.

## 5. Completion gate

ELV6 workspace implementation is complete when one logical MAIN/NODE can be planned abstractly, realized in one or more enclosures, validated with exact candidate assemblies, explained through actionable physical issues, and frozen without taking ownership from ELV5, ELV7 or ELV8.
