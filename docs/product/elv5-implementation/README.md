# ELV5 — Implementation design index

Status: DESIGN DRAFT / RUNTIME NOT STARTED
Branch: `feat/flutter-elv5-power-topology-design`
Parent source/design: ELV4 `31581aa6c396d5ebd6cdf1985c53719d9d05e12a`.

ELV5 registers 27 discipline processes and consumes shared ELV3/ELV4 facts. It does not duplicate power topology or create a separate result/revision/history platform. [Governing design](../elv5-discipline-calculations-design-specification.md) defines shared extensions and stage boundaries.

The mandatory bridge from specification to Dart/Drift runtime is the [code-level runtime contract](code-level-runtime-contract.md). It fixes the closed runtime type model, `engineering-node-v3`, exact numeric/status semantics, strict `electra.elv5-discipline-command.v1` envelope, exactly 16 ELV5 discipline command operations, replay-first mutation order, persistence identities, dependency keys and capture → pure run → generation-guarded publish protocol.

| Package | Specification | Outcome |
|---|---|---|
| P0 | [Baseline and stage integration](p0-baseline.md) | Pin actual parent source/design SHA, schema and supported migration origins |
| P1 | [Typed discipline profiles and process registry](p1-profiles-registry.md) | Register exactly 27 stable discipline process codes plus the exact code-owned runtime/schema contracts |
| P2 | [Persistence, command boundaries and revision evidence](p2-persistence-commands.md) | Implement the 16-operation discipline wire family, revision-scoped calculation aspects and isolated evaluation/pointer storage |
| P3 | [CCTV calculation implementation](p3-cctv.md) | Implement CCTV-01 explicit rectilinear plane coverage with coordinate/model applicability and numeric bounds |
| P4 | [LAN and structured-cabling implementation](p4-lan.md) | Implement LAN-01 permanent/channel section unions and nonduplicated installed allowances |
| P5 | [Access-control implementation](p5-acs.md) | Implement ACS-01 explicit door-role alternatives/multiplicities with scoped canonical assignments |
| P6 | [Fire-alarm implementation](p6-fire.md) | Implement FA-01 distinct physical-device/address-resource limits and uniqueness |
| P7 | [Incremental dependencies and engineer workspace](p7-dependencies-workspace.md) | Encode owner/scope-aware consumed dependency keys including missing inputs and membership sets; guard publication by captured generations |
| P8 | [Integrated verification and qualification](p8-acceptance.md) | Qualify all 27 POS/NEG process oracles through public commands, real file SQLite and exact 16-codec dispatch |
| P9 | [Architecture reconciliation and stage handoff](p9-closure.md) | Reconcile all 80 requirements, 27 process definitions and 16 public command codecs to actual source/tests/versions |

[Process contracts](process-contracts.md) and [process registry](process-registry.json) cover CCTV6/LAN7/ACS6/Fire8. [Requirement ledger](requirements.json) contains 80 stable package requirements. Every runtime evidence field is intentionally empty.

ELV4 is an implemented, runtime-accepted and merged prerequisite. Reuse its actual dedicated power persistence, reviewed writers, captured facts and numerical kernels under the [implemented baseline contract](implemented-baseline.md). Complete new ELV5 wire schemas, migrations and executable qualification inputs remain P1/P2/P8 work. Inherited acceptance references live in [baseline.json](baseline.json), separately from ELV5 runtime evidence.

Initial [technical audit/remediation](../../audit/elv5-technical-audit.md) covers all package requirements/processes. Eight findings are resolved in design; strict runtime codecs, full qualification input data and new discipline integration still require their recorded gates.

## Design-to-runtime consistency gate

Before implementation starts, the following four inventories must agree exactly:

1. 27 process codes in `process-registry.json` and runtime `Elv5ProcessRegistry`.
2. Required dimensions/oracles in `process-contracts.md` and process definitions.
3. Exactly 16 operations in `code-level-runtime-contract.md` and runtime semantic codec registry.
4. P0–P9 acceptance assertions and public qualification manifest.

Any mismatch is a specification defect and blocks runtime entry rather than being resolved ad hoc in package code.
