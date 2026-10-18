# ELV6 / ELV7 / Equipment Catalogue / ELV8 integration agreement

Status: **DESIGN AGREEMENT / RUNTIME NOT STARTED / NO ACCEPTANCE INFERENCE**.
Agreement ID: `electra.elv6-elv8-integration.v1`.

This agreement is distributed unchanged to the ELV6, ELV7 and ELV8 design
branches. It resolves cross-stage interface semantics; stage specifications
retain their own canonical models and writers. A replica is not a new owner.
The interface manifest hash in each local stage binding identifies the exact
agreement; branch SHA pins describe inspected inputs, not future runtime support.

| File | Purpose |
|---|---|
| [Runtime handoff](runtime-handoff-contract.md) | Requirement/evidence split, identities, candidates, application, freeze/report order |
| [Interface registry](interface-registry.json) | Nine proposed schemas, result adapters, operation boundaries and invalidation events |
| [Qualification plan](qualification-plan.json) | Planned cross-stage oracle objectives; no executed runtime claims |
| [Local stage binding](stage-binding.json) | Local stage/document fingerprints, agreement digest and blocked runtime entry gates |
| [Electrical study handoff](electrical-study-handoff-contract.md) | Shared immutable references for short-circuit, voltage-disturbance, motor-start and source-transfer studies; ELV6/7/8 are consumers, not competing physics owners |

Run `python3 scripts/ci/check-elv-integration-contract.py` on each branch.
The check validates local design agreement, schemas, branch adapters, source pins
and guarded interfaces. It does not execute layout, normative or selection code.

## Inspected source reality

| Scope | Exact input source | Reality |
|---|---|---|
| ELV6 | `ab59bb012689c91f371981ce712c81ba71bdae4f` | 24 LAY / 21 commands / safety projections are design contracts; ELV6 runtime not started |
| ELV7 | `f32432c8b14134a5961420fb2a219ecbfb2652ce` | 45 normative family contracts; runtime not started |
| Equipment Catalogue | same ELV7 input | 22 planned product families, separate-store proposal and offer books; runtime not started |
| ELV8 | `efeba9138dd1b918c1f4451ae878986c799b19e9` | Inherited FL14 runtime present; generic ELV8 closure not started |

These inputs are not a promise of identical source trees. Do not merge stale
inherited upstream specifications over a current stage branch. Publish coordinated
contract updates with expected-head leases; if an upstream changes, inspect and
reconcile rather than resetting its branch to a previously read SHA.

## Generator, PV, storage and transfer amendment

[Source-system contract](source-systems-contract.md) defines exact owner roles,
physical/electrical/normative/selection boundaries and mandatory coverage.
[Source registry](source-systems-registry.json) adds four proposed electrical
producer schemas and sixteen mode classes; the original nine stage handoff schemas
remain unchanged. [Source qualification](source-qualification-plan.json) has
32 PLANNED oracles. [Authority review](source-authority-review.md) records primary
metadata discovery without production approval. [Design readiness](design-readiness.json)
separates defined contracts from blocked upstream/runtime/source-review gates.
The catalogue now plans 23 families with a distinct PV module product definition.

## Identification, cabinet-entry and segregation normative amendment

ELV7 future runtime entry MUST also reconcile to
[`../elv7-identification-cabinet-normative-amendment.md`](../elv7-identification-cabinet-normative-amendment.md)
and its machine contract. It defines verified-authority rule families for cable/core/terminal/panel identification,
cabinet entry/glands/IP, bend/accessibility and power/control/ELV segregation while explicitly forbidding a universal
TOP-versus-BOTTOM assumption.

Electrical fault/disturbance facts are consumed through
[`electrical-study-handoff-contract.md`](electrical-study-handoff-contract.md); ELV7 assesses applicable rules and does not recompute physics.
The amendment is design authority for future implementation; source authority and qualification are still required.
