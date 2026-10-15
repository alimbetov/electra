# ELV5 — Implementation design index

Status: DESIGN DRAFT / RUNTIME NOT STARTED
Branch: `feat/flutter-elv5-power-topology-design`
Parent source/design: ELV4 `4c35840bf1453df8adc49cce18d937fe20a52801`.

ELV5 registers 27 discipline processes and consumes shared ELV3/ELV4 facts. It does not duplicate power topology or create a separate result/revision/history platform. [Governing design](../elv5-discipline-calculations-design-specification.md) defines shared extensions and stage boundaries.

| Package | Specification | Outcome |
|---|---|---|
| P0 | [Baseline and stage integration](p0-baseline.md) | Pin actual parent source/design SHA, schema and supported migration origins |
| P1 | [Typed discipline profiles and process registry](p1-profiles-registry.md) | Register exactly 27 stable discipline process codes with algorithm/input/output versions |
| P2 | [Persistence, command boundaries and revision evidence](p2-persistence-commands.md) | Add revision-scoped calculation aspects and normalized FK-bearing assignment children |
| P3 | [CCTV calculation implementation](p3-cctv.md) | Implement CCTV-01 explicit rectilinear plane coverage with coordinate/model applicability and numeric bounds |
| P4 | [LAN and structured-cabling implementation](p4-lan.md) | Implement LAN-01 permanent/channel section unions and nonduplicated installed allowances |
| P5 | [Access-control implementation](p5-acs.md) | Implement ACS-01 explicit door-role alternatives/multiplicities with scoped canonical assignments |
| P6 | [Fire-alarm implementation](p6-fire.md) | Implement FA-01 distinct physical-device/address-resource limits and uniqueness |
| P7 | [Incremental dependencies and engineer workspace](p7-dependencies-workspace.md) | Encode owner/scope-aware consumed dependency keys including missing inputs and membership sets |
| P8 | [Integrated verification and qualification](p8-acceptance.md) | Implement one FK-valid public-command fixture per discipline plus shared-source project context |
| P9 | [Architecture reconciliation and stage handoff](p9-closure.md) | Reconcile all 80 requirements and 27 registry processes to actual source/tests/versions |

[Process contracts](process-contracts.md) and [process registry](process-registry.json) cover CCTV6/LAN7/ACS6/Fire8. [Requirement ledger](requirements.json) contains 80 stable package requirements. Every runtime evidence field is intentionally empty.

ELV4 RM01–RM15 are inherited design obligations, not an already implemented platform. Complete ELV5 wire schemas, DB migrations and executable qualification inputs must be reviewed in P1/P2/P8 before their runtime gates. This first ELV5 branch establishes the detailed package/process contracts without claiming the same audit/remediation maturity as the parent.

Initial [technical audit/remediation](../../audit/elv5-technical-audit.md) covers all package requirements/processes. Eight findings are resolved in design; strict runtime codecs, full qualification input data and inherited prerequisite implementation still require their recorded gates.
