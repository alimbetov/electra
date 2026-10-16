# ELV6 — implementation design index

Status: **DESIGN DRAFT / RUNTIME NOT STARTED**  
Branch: `feat/flutter-elv6-enclosure-layout-design`  
Pinned design upstream: ELV5 `ed7db01adb27ff184b0b8c91a710082fb9eafb9a`.

ELV6 converts exact upstream engineering facts into reproducible physical enclosure/rack arrangement evidence. It owns layout facts only where no earlier accepted owner exists. It does not duplicate ELV3 routing, ELV4 power, ELV5 discipline calculations, ELV7 normative rules or ELV8 commercial selection.

## Normative artifacts

1. [`code-level-runtime-contract.md`](code-level-runtime-contract.md) — mandatory Dart/runtime identities, exact µm geometry, evaluation states, replay/CAS/publication, persistence, solver and workspace contracts.
2. [`process-registry.json`](process-registry.json) — closed 24-process layout/evaluation registry.
3. [`command-registry.json`](command-registry.json) — closed 21-operation public command registry under `electra.elv6-layout-command.v1`.
4. [`../elv6-enclosure-layout-design-specification.md`](../elv6-enclosure-layout-design-specification.md) — stage purpose, ownership and package architecture.
5. [`../elv6-p0-p9-delivery-plan.md`](../elv6-p0-p9-delivery-plan.md) — implementation/acceptance sequence.
6. [`../../audit/elv6-hard-technical-audit.md`](../../audit/elv6-hard-technical-audit.md) — hard engineering/system-architecture audit and finding disposition.

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

### 21 public command operations

The command registry is exact and fail-closed. No widget- or plugin-specific mutation endpoint may bypass it. The public revision lifecycle remains the existing ELV4 revision command family.

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

## Runtime status

All ELV6 P0–P9 runtime packages are `NOT_STARTED`. Design artifacts and CI structural checks never count as runtime qualification.
