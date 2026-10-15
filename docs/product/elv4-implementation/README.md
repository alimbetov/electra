# ELV4 — Implementation technical specification

Status: IMPLEMENTATION DESIGN DRAFT / RUNTIME NOT STARTED
Branch: `feat/flutter-elv4-power-topology-design`
Inspected source: `7f1c701cb4ba492589321f8f9827d20464ddaefb`
Preceding design: `ce8c971`

This specification decomposes all ten P0–P9 packages into implementable requirements. It refines the [governing specification](../elv4-power-topology-design-specification.md) and [coordinated contract](../elv4-coordinated-p0-p9-contract.md); it does not supersede ELV1–ELV3 ownership or certify their closure. Each file defines contracts, implementation order, failure behavior and acceptance cases. Names marked proposed describe future code, not implemented APIs.

| Package | Technical specification | Principal implementation boundary |
|---|---|---|
| P0 | [Baseline and integration](p0-baseline.md) | Evidence, source ownership and entry gates |
| P1 | [Domain and catalog](p1-domain-catalog.md) | Typed quantities, profiles, scenarios and codecs |
| P2 | [Persistence and commands](p2-persistence-commands.md) | SQL scope, atomic writes, replay and history |
| P3 | [Topology and trace](p3-topology-trace.md) | Scenario-directed graph and compatibility |
| P4 | [Loads and conversion](p4-load-conversion.md) | W/A/VA, limits, conversion and peak basis |
| P5 | [PoE delivery](p5-poe.md) | PD/PSE boundary and one physical realization |
| P6 | [DC and backup](p6-dc-backup.md) | Voltage drop, battery, charger and duration |
| P7 | [Dependencies and workspace](p7-dependencies-workspace.md) | Precise invalidation, safe publication and progressive UI |
| P8 | [Runtime verification](p8-acceptance.md) | Public-command verticals, migration, restart and races |
| P9 | [Closure and handoff](p9-closure.md) | Requirement-to-evidence reconciliation at exact SHA |

[Shared runtime contracts](shared-contracts.md) and [resolved RM01–RM15 decisions](remediation-contract.md) apply to every package. [Wire registry/schemas](wire-contract.md), [qualification manifest](qualification.json) and [public-builder contract](qualification-builders.md) are normative implementation inputs. [Requirement ledger](requirements.json) records design traceability; every runtime status remains NOT_STARTED. Test IDs denote planned assertions, not tests that have run.

## Implementation sequence

P0 verification → P1 types/codecs → P2 persistence and mutation infrastructure → P3 graph → P4 load kernels → P5 PoE → P6 DC/backup → complete P7 workspace → P8 integrated proof → P9 closure. P7 dependency keys and P8 fixture builders must start with P1/P2; these concerns cannot wait until the end.

Within P4–P6, compute by supported voltage domain in bottom-up graph order. E0–E6 in the coordinated contract are logical phases, not a recursive call chain between process services. Unsupported nonlinear/mesh behavior returns a typed blocked result.

## Interpretation rules

- MUST requirements have stable IDs `ELV4-Pn-NNN`; each has explicit planned acceptance IDs.
- Structural invalidity rejects a mutation. A valid incomplete draft may persist, with unresolved evaluation findings. Exceeding an engineering capacity is a successful evaluation with FAIL, not a storage exception.
- Database schema number is chosen from the implementation base. Snapshot, catalog, command, process and numeric-policy schema versions are independent.
- Illustrative equipment data is fictional. No implicit national policy, standard class, manufacturer guarantee or certification follows from a fixture.
- Runtime entry still requires P0 baseline reconciliation. Design review may proceed for all packages now.
- Design review, implementation, runtime acceptance, merge and stage CLOSED are separate states.

## Technical audit disposition

All 15 findings from the 2026-10-15 audit are addressed in specification contracts and acceptance refinements. See [remediation record](../../audit/elv4-technical-audit/remediation-review.md). This does not assert implementation, baseline closure, or runtime acceptance.
