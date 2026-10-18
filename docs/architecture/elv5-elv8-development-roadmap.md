# Electra — ELV5→ELV8 Development Roadmap

Status: canonical delivery roadmap  
Branch: `target/electra-professional-electrical-platform`

## 1. Goal

Deliver the client-oriented Electra workflow on top of the existing ELV architecture without exposing internal process complexity as the primary UX.

Target user loop:

```text
Project
 -> MAIN/NODE
 -> equipment + cables + sources
 -> automatic engineering recalculation
 -> actionable Issues
 -> Configure
 -> ELV6/ELV7 validation
 -> explicit Apply
 -> Freeze
 -> BOM/specification/reports
```

The roadmap uses the existing branches:

- `feat/flutter-elv5-power-topology-design`
- `feat/flutter-elv6-enclosure-layout-design`
- `feat/flutter-elv7-normative-validation-design`
- `feat/flutter-elv8-deliverables-design`
- `target/electra-professional-electrical-platform`

No extra feature branches are required by this roadmap unless implementation isolation becomes operationally useful.

## 2. Ownership matrix

| Capability | ELV5 | ELV6 | ELV7 | ELV8 | Target/UI |
|---|---|---|---|---|---|
| MAIN/NODE logical engineering projection | OWN | consume | consume | consume | present |
| Connection-driven applicability | OWN | consume | consume | consume | edit/present |
| 27 discipline processes | OWN | - | consume evidence | consume demand | hide/drill-down |
| Incremental recalculation/invalidation | OWN | own physical deps | own rule deps | own config deps | observe |
| EquipmentDemand | OWN | consume abstract needs | consume requirements | consume/resolve | present summary |
| Physical enclosure/rack realization | - | OWN | consume evidence | consume/evaluate | present/edit |
| Normative qualification | - | evidence only | OWN | orchestrate | present/drill-down |
| Catalog/SKU/accessories | - | physical profile only | certification facts only | OWN | present/select |
| Ranking/alternatives | - | no | no | OWN | present |
| Apply configuration | upstream invalidation | physical apply | qualification refresh | OWN orchestration | explicit user action |
| Freeze/configuration deliverables | preserve evidence | freeze layout | freeze qualification refs | OWN | trigger/present |

## 3. Non-negotiable boundaries

1. UI must not calculate engineering truth.
2. ELV5 does not select SKU/manufacturer/price.
3. ELV6 does not rank products commercially.
4. ELV7 does not own catalog facts or physical placement.
5. ELV8 cannot bypass ELV6/ELV7 blockers.
6. Navigation tree is not authoritative engineering topology.
7. Every design mutation that changes accepted configuration requires explicit user action.
8. Frozen revisions/results are immutable and reproducible.

## 4. Delivery waves

### Wave 0 — authority and contract alignment

Branches: all + target.

Deliverables:

- reconcile exact current HEADs and authority/status wording;
- pin cross-stage DTO/schema/version contracts;
- include new workspace/roadmap docs in authority/architecture indexes;
- define canonical user-state vocabulary;
- define exact stale/invalidation semantics across ELV5→8;
- freeze first golden-project fixture identity.

Exit gate G0:

- no unresolved ownership contradiction;
- every cross-stage API has one owner and explicit consumer;
- no downstream runtime acceptance against stale upstream design SHA.

### Wave 1 — Workspace MVP + ELV5 vertical slice

Primary branch: ELV5.  
Target/UI work may proceed in parallel against stable read contracts.

Scope:

- Project Workspace shell;
- project tree and selection inspector;
- logical MAIN/NODE projection;
- bulk endpoint connection workflow;
- automatic process applicability;
- precise dependency invalidation;
- node engineering metrics;
- actionable issues;
- advanced engineering drill-down;
- node-scoped EquipmentDemand.

Golden journey GJ-1:

```text
create NODE-F2
 -> add 12 cameras
 -> batch connect
 -> automatic CCTV/LAN/PoE calculations
 -> show node metrics
 -> show one actionable issue
 -> drill down to exact evidence
 -> generate stable EquipmentDemand
```

Exit gate G1:

- no manual process-code selection required;
- same frozen project produces same node projection/demand fingerprint;
- unrelated node edits do not invalidate GJ-1 results;
- UI contains no duplicated formulas.

### Wave 2 — ELV6 physical realization

Primary branch: ELV6.  
ELV5 may continue hardening in parallel.

Scope:

- `PhysicalNodeRealization`;
- one logical node -> 1..N enclosures;
- abstract RU/DIN/dimension/thermal/cable-entry capacity;
- deterministic placement evaluator;
- cable termination/bend/access constraints;
- reserve/serviceability;
- structured physical remediation.

Golden journey GJ-2:

```text
NODE-F2 requires 21U
 -> current 18U enclosure fails
 -> show 24U replacement and two-cabinet split
 -> preview
 -> Apply physical decision
 -> physical state READY
```

Exit gate G2:

- components fitting without cable/service feasibility cannot PASS;
- physical result is deterministic;
- logical node identity survives cabinet split.

### Wave 3 — ELV7 normative qualification

Primary branch: ELV7.  
May start rule/profile implementation in parallel with late Wave 2 once ELV5/ELV6 evidence contracts are stable.

Scope:

- project normative profile pinning;
- applicability resolver;
- deterministic rule evaluation;
- missing-evidence semantics;
- user-friendly compliance issues;
- exact engineer/auditor drill-down;
- override governance;
- external-source operating modes.

Golden journey GJ-3:

```text
candidate lacks mandatory verified fact
 -> qualification is not fabricated PASS
 -> user receives actionable issue
 -> exact rule/reference/evidence available
 -> alternative candidate can pass
```

Exit gate G3:

- no unpinned verified compliance;
- every simplified issue maps to exact rule evidence;
- non-overridable blocker cannot be suppressed by UI/ranking.

### Wave 4 — ELV8 catalog + autoconfiguration MVP

Primary branch: ELV8.

Scope:

- canonical catalog class/family/variant model;
- typed technical facts/provenance;
- EquipmentDemand candidate generation;
- compatibility/accessory closure;
- ELV7 candidate qualification;
- ELV6 candidate fit;
- explainable ranking;
- recommendation/alternatives;
- no-solution diagnostics;
- explicit Apply.

Golden journey GJ-4:

```text
NODE-F2 needs >=28 ports + PoE requirement
 -> generate 48-port candidates
 -> reject missing-fact candidate
 -> ELV7 rejects one
 -> ELV6 rejects one
 -> rank survivors
 -> show recommendation + alternatives
 -> engineer Apply
```

Exit gate G4:

- only technically valid candidates are ranked;
- ranking is deterministic/versioned;
- recommendation generation is side-effect free;
- Apply is explicit.

### Wave 5 — Freeze + Issue

Primary branch: ELV8 with target/UI integration; ELV5/6/7 provide immutable evidence references.

Scope:

- project readiness aggregation;
- freeze resolved configuration/layout/qualification references;
- BOM;
- equipment schedules;
- node/panel schedules;
- configuration summary;
- report/export integration;
- historical revision replay.

Golden journey GJ-5:

```text
all blockers resolved
 -> ISSUE readiness READY
 -> Freeze revision
 -> reopen project
 -> frozen BOM/layout/qualification unchanged
 -> live catalog/rule/price updates do not rewrite history
```

Exit gate G5:

- frozen outputs are reproducible from pinned fingerprints/versions;
- no live catalog mutation changes frozen deliverables.

### Wave 6 — Professional UX hardening

Branches: target/UI + stage branches as needed.

Scope:

- mobile/tablet/desktop responsive workspace;
- large-project virtualization;
- keyboard/mouse professional workflows;
- batch operations;
- issue navigation;
- undo/redo boundaries;
- offline/local-first behavior;
- stale commercial/catalog indicators;
- performance/load testing;
- accessibility/localization foundations.

Exit gate G6:

- large golden project remains interactive;
- engineering workers do not block UI isolate;
- offline project work preserves deterministic engineering state.

## 5. Parallelization plan

Safe parallel work:

```text
Wave 1 ELV5 runtime/workspace
    ||
    ||-- ELV6 abstract physical DTO/kernel scaffolding
    ||-- ELV7 rule-pack/applicability scaffolding
    ||-- ELV8 catalog canonical model/import scaffolding
```

Not safe before upstream contracts are pinned:

```text
ELV6 accepted runtime  <- blocked by accepted ELV5 handoff
ELV7 final qualification <- blocked by exact consumed ELV5/ELV6 evidence schemas
ELV8 final resolution <- blocked by ELV5 demand + ELV6 fit + ELV7 candidate contracts
Freeze/Issue <- blocked by accepted configuration/evidence fingerprints
```

## 6. Recommended implementation order inside Flutter

Do not create one monolithic workspace screen.

Preferred layering:

```text
application/
  project_workspace/
    commands
    queries
    controllers
    projections

features/editor/
  workspace shell
  project tree
  selection inspector
  node summary
  contextual actions

features/calculations/
  advanced process/evidence drill-down

features/reports/
  issue/freeze/deliverable surfaces
```

Existing `projects`, `floors`, `rooms`, `editor`, `calculations`, `reports` remain useful; the information architecture changes from calculation-first to project/workspace-first.

## 7. Cross-stage contract checklist

Before a downstream wave starts, verify:

### ELV5 -> ELV6/7/8

- node/project identity;
- revision identity;
- engineering projection fingerprint;
- EquipmentDemand schema/version;
- evidence references;
- stale/current semantics.

### ELV6 -> ELV7/8

- layout snapshot ID/version;
- physical profile version;
- fit assessment schema;
- violation codes;
- physical evidence references.

### ELV7 -> ELV8

- normative profile/rule-pack version;
- candidate verdict schema;
- blocking/advisory severity;
- evidence/reference IDs;
- override policy/result.

### ELV8 -> ISSUE

- resolved configuration fingerprint;
- catalog snapshot;
- selection-policy version;
- commercial snapshot when used;
- applied decision history;
- frozen component/accessory identities.

## 8. Product milestones

### M1 — Engineer can model and understand

Wave 1 complete.

User can build a node, connect equipment and immediately understand engineering state.

### M2 — Engineer can prove physical realizability

Wave 2 complete.

User sees whether the node can physically be built and how to fix enclosure/layout problems.

### M3 — Engineer can prove compliance

Wave 3 complete.

User sees deterministic, evidence-backed normative qualification.

### M4 — Engineer can autoconfigure

Wave 4 complete.

User receives explainable equipment recommendations and alternatives.

### M5 — Engineer can issue a project

Wave 5 complete.

User freezes a reproducible design and generates BOM/specification outputs.

### M6 — Professional production UX

Wave 6 complete.

Workflow is performant, offline-capable and efficient on phone/tablet/desktop.

## 9. Definition of Done for the whole roadmap

The roadmap is complete when a professional engineer can:

1. create a project and MAIN/NODE topology;
2. place equipment and connect cables without knowing process codes;
3. receive automatic deterministic calculations and actionable issues;
4. inspect exact evidence when needed;
5. obtain physical layout/remediation;
6. obtain profile-pinned compliance qualification;
7. request explainable equipment configuration;
8. compare alternatives and explicitly Apply a solution;
9. freeze a reproducible accepted revision;
10. issue BOM/specification/reports;
11. reopen the project later and reproduce the same frozen engineering truth.

The product experience remains:

> model -> connect -> calculate -> explain -> fix -> configure -> verify -> freeze -> issue.
