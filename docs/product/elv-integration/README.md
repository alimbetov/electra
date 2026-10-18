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
