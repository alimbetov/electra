# ELV6 — implementation design index

Status: **DESIGN HARDENED / RUNTIME NOT STARTED**  
Branch: `feat/flutter-elv6-enclosure-layout-design`  
Pinned design upstream: ELV5 `ed7db01adb27ff184b0b8c91a710082fb9eafb9a`.

ELV6 converts exact upstream engineering facts into reproducible physical enclosure/rack arrangement evidence. It owns layout facts only where no earlier accepted owner exists. It does not duplicate ELV3 routing, ELV4 power, ELV5 discipline calculations, ELV7 normative rules or ELV8 commercial selection.

## Normative artifacts

1. [`code-level-runtime-contract.md`](code-level-runtime-contract.md) — mandatory Dart/runtime identities, exact µm geometry, evaluation states, replay/CAS/publication, persistence, solver and workspace contracts.
2. [`mutation-safety-contract.md`](mutation-safety-contract.md) — strict placement-intent wire union, server-derived physical geometry/provenance and fail-closed referenced-member replacement semantics.
3. [`process-registry.json`](process-registry.json) — closed 24-process layout/evaluation registry.
4. [`command-registry.json`](command-registry.json) — closed 21-operation public command registry under `electra.elv6-layout-command.v1`.
5. [`command-examples.json`](command-examples.json) — one canonical design-time valid payload and deterministic missing-field rejection for every registered operation.
6. [`qualification-manifest.json`](qualification-manifest.json) — 72 process oracles: POS/NEG/BLOCKED for all 24 codes plus cross-cutting constructability/concurrency cases.
7. [`../elv6-enclosure-layout-design-specification.md`](../elv6-enclosure-layout-design-specification.md) — stage purpose, ownership and package architecture.
8. [`../elv6-p0-p9-delivery-plan.md`](../elv6-p0-p9-delivery-plan.md) — 80 implementation/acceptance requirements.
9. [`../../audit/elv6-hard-technical-audit.md`](../../audit/elv6-hard-technical-audit.md) — initial 18 hard engineering/system-architecture findings and remediation.
10. [`../../audit/elv6-final-architecture-hardening.md`](../../audit/elv6-final-architecture-hardening.md) — findings 19–20: client-derived geometry/provenance and orphaned-reference replacement hazards.

## Closed registries

### 24 engineering processes

```text
LAY-01..04  host/surface/containment/collision
LAY-05..08  rack/DIN/surface physical fit
LAY-09..12  service/door/cable-entry/bend constructability
LAY-13..14  wiring duct and physical termination capacity
LAY-15..17  battery/support/mass/CoG basis
LAY-18..19  ventilation and thermal-input basis
LAY-20      reserve-capacity basis
LAY-21      observed segregation geometry
LAY-22      protective-bonding physical basis
LAY-23      deterministic auto-layout proposal
LAY-24      aggregate intrinsic validation
```

Each process has a mandatory positive, negative and blocked design oracle. For measurement/basis processes a negative case may intentionally be `UNRESOLVED` rather than a fake engineering FAIL.

### 21 public command operations

The command registry is exact and fail-closed. Canonical examples mirror its payload-key sets exactly. No widget- or plugin-specific mutation endpoint may bypass it. The public revision lifecycle remains the existing ELV4 revision command family.

For placement commands, the wire carries only `placementSpec` intent. Body envelopes, rack/DIN spans, world-space service/protrusion geometry and proposal provenance are server-derived/materialized facts. This prevents a UI/client from forging a smaller collision envelope or impersonating solver provenance.

Set-replacement commands are reference-safe: mounting surfaces and cable entries cannot be removed while active placements/assignments still reference them. There is no client `force` bypass.

## Runtime ownership gate

`PanelAssembly`/ADR-019 are an accepted semantic baseline, but runtime ownership must be proved separately. P0 produces an evidence matrix for:

```text
semantic model
persistence
public writer
revision identity
replay/history
freeze
create-next
concurrency CAS
qualification
```

If an accepted panel-layout writer is absent, ELV6 promotes the existing semantic identity into the first revision-scoped runtime owner. A parallel “new generic panel” model is prohibited.

## Numeric contract

New canonical mechanical geometry is integer micrometre fixed-point. Project integer millimetres convert exactly. Legacy `double` geometry is compatibility input only and may not become hash-significant without deterministic normalization.

## Claim boundary

A physical `FAIL` means an intrinsic constructability/capability violation supported by exact technical facts. It does **not** mean normative non-compliance. ELV7 applies jurisdictional/ruleset requirements to the exact ELV6 physical projection. ELV8 may select products only through explicit substitution/revalidation impact.

## CI design guards

The main Flutter workflow runs three independent ELV6 design gates before Flutter setup:

```text
check-elv6-specification.py
check-elv6-command-registry.py
check-elv6-qualification-design.py
```

They verify the 24/80/20 counts, dependency DAG and hard engineering boundary tokens; exact 21-command wire/payload registry including server-derived-placement constraints; 21 canonical payload examples; and 72 POS/NEG/BLOCKED process oracles.

These gates prevent specification drift. They are explicitly **not runtime acceptance**.

## Runtime status

All ELV6 P0–P9 runtime packages are `NOT_STARTED`. Runtime evidence fields must remain empty until actual source/tests/CI exist.
