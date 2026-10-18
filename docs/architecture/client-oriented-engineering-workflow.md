# Electra — Client-Oriented Engineering Workflow

Status: target product architecture  
Branch: `target/electra-professional-electrical-platform`

## 1. Product principle

Electra SHALL be organized around the engineer's real project workflow rather than exposing internal calculation/process architecture as the primary UX.

Primary product loop:

```text
create project
  -> place MAIN/NODE distribution point
  -> route cables/connections
  -> connect equipment/endpoints
  -> Electra determines applicable calculations
  -> show actionable engineering state
  -> propose remediation/configuration
  -> engineer explicitly applies decisions
  -> qualify/freeze/issue deliverables
```

The platform may contain many calculation engines internally, but the normal user experience SHALL remain object- and action-oriented.

## 2. Core user object: DistributionNode

The central navigation object for distribution-oriented workflows SHALL be a logical `DistributionNode`.

Minimum roles:

```text
MAIN
NODE
```

A node may represent, depending on the project, an electrical panel, ELV cabinet, telecom rack, fire cabinet or mixed distribution point.

MAIN/NODE are roles, not incompatible subclasses.

The logical node SHALL remain stable while its physical enclosure, catalog equipment and compliance state evolve.

## 3. User tree and engineering graph

The product SHALL distinguish two structures:

### 3.1 Navigation tree

Optimized for human orientation:

```text
Project
  -> Building
     -> Floor/Zone
        -> MAIN/NODE
           -> connected equipment
```

### 3.2 Engineering graph

Derived from explicit connections and capable of non-tree topology:

```text
source -> transfer -> MAIN -> NODE -> load
MAIN-A -> NODE-X
MAIN-B -> NODE-X backup
NODE-X -> endpoint
```

The UI tree MUST NOT become the authoritative electrical/network topology.

## 4. Stage responsibilities

The client workflow SHALL map to the engineering stages without exposing their complexity unnecessarily.

```text
ELV4
  physical electrical truth and shared source/circuit/load evidence

ELV5
  discipline calculations + node-scoped engineering demand

ELV6
  physical enclosure/rack/placement feasibility

ELV7
  deterministic normative qualification

ELV8
  catalog resolution, alternatives, commercial ranking, freeze and deliverables
```

No stage may silently rewrite another stage's authority.

## 5. Automatic calculation selection

The user SHALL NOT normally select calculation process codes.

Applicability is inferred from project facts:

```text
camera -> CCTV calculations
Ethernet/fiber -> LAN calculations
ACS door/controller -> ACS calculations
fire device/loop -> Fire calculations
power/source/battery -> applicable shared electrical/autonomy calculations
physical enclosure -> ELV6
normative profile -> ELV7
catalog resolution request -> ELV8
```

Advanced users MAY drill down into exact process/evidence details.

## 6. Simple surface, strict core

Normal user-facing statuses SHOULD be compact:

```text
READY
ATTENTION
CRITICAL
STALE
NEEDS_DATA
```

Engineering detail SHALL preserve exact domain states, evidence, versions, findings and provenance.

Example normal message:

```text
NODE-F2 needs 4 additional PoE-capable ports.
```

Example engineer drill-down:

```text
process/evaluation ID
required capability
measured/available value
margin
algorithm/ruleset version
source evidence
finding code
```

The simple UX SHALL never reduce engineering rigor.

## 7. Action-oriented problem solving

Electra SHALL prefer remediation paths over opaque error codes.

For a detected problem, the product SHOULD provide, where deterministic and safe:

- what is wrong;
- why it matters;
- what object is affected;
- required vs available value;
- safe remediation alternatives;
- effect on reserve/fit/compliance/cost;
- whether explicit engineer approval is required.

No remediation that changes engineering design SHALL be silently applied.

## 8. Autoconfiguration loop

The target differentiating workflow is:

```text
project topology
  -> deterministic calculations
  -> EquipmentDemand
  -> candidate generation
  -> normative filtering
  -> physical-fit filtering
  -> compatibility/accessory closure
  -> explainable ranking
  -> recommendation + alternatives
  -> engineer Apply
  -> freeze
  -> BOM/specification/deliverables
```

Commercial preference is evaluated only after technical validity.

## 9. MAIN/NODE aggregation

A node SHALL provide a coherent engineering summary across applicable domains where aggregation is technically valid:

- load/power contribution;
- PoE demand;
- network ports/uplinks/bandwidth;
- storage/recorder demand;
- ACS channels/interfaces;
- fire resources/current;
- source/PSU/autonomy requirements;
- reserve;
- physical enclosure capacity;
- normative issues;
- unresolved data.

MAIN nodes may aggregate downstream node contributions while preserving individual source identities and preventing double counting.

## 10. Progressive project maturity

The product SHALL support useful work before the project is fully specified.

```text
early design
  logical nodes + routes + abstract requirements

intermediate design
  calculations + reserve + abstract enclosure capacity

late design
  exact catalog candidates + exact layout + normative qualification

issue
  frozen accepted configuration + deliverables
```

Unknown information remains explicit and does not block unrelated work.

## 11. Explicit user decision boundaries

The following changes require explicit user action:

- applying/replacing a selected product;
- accepting a project policy change;
- recording a permitted normative override;
- changing mandatory reserve policy;
- freezing/issuing a project configuration.

Refresh, recalculation, navigation, sync or commercial-price updates MUST NOT silently rewrite accepted design decisions.

## 12. Client-oriented acceptance principles

The target product is acceptable when:

1. a new user can model a typical project through nodes, cables and equipment without learning internal process codes;
2. the system automatically activates applicable engineering calculations;
3. every simplified status drills down to exact evidence;
4. warnings/errors are action-oriented and identify affected project objects;
5. MAIN/NODE scale from small projects to buildings/campuses without changing the core model;
6. non-tree physical topologies remain representable beneath the navigation tree;
7. autoconfiguration is explainable and never silently applied;
8. unknown mandatory evidence remains explicit;
9. physical, normative, technical and commercial truths remain separated;
10. the same frozen inputs reproduce the same engineering/configuration result.

## 13. Product positioning

Electra SHALL not position itself as a collection of 27 calculators or as a catalog database.

The product experience is:

> model the real object -> connect it -> Electra calculates -> explains -> proposes -> verifies -> configures -> freezes -> issues.

That is the client-oriented surface of the underlying professional engineering platform.
