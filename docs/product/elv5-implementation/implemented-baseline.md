# ELV5 — Implemented ELV4 baseline and extension contract

Reconciled: 2026-10-16. Status: DESIGN BASELINE UPDATED / ELV5 RUNTIME NOT STARTED.

Accepted ELV4 source: `31581aa6c396d5ebd6cdf1985c53719d9d05e12a`.
Merged into main by [PR #11](https://github.com/alimbetov/electra/pull/11): `d2b059d4c11a284cdd32965140f6df3c40020c8d`.
[Exact-head run 38859878752](https://github.com/alimbetov/electra/actions/runs/38859878752) completed both technical and runtime-acceptance jobs successfully on the accepted source. Foundation run 38859878966 also passed. These are inherited executed results, not a new ELV5 runtime claim. [Machine-readable baseline](baseline.json) records concrete paths and provenance separately from the ELV5 requirement evidence fields.

This contract supersedes assumptions that ELV4 was design-only, schema 21 was current, or power results shared ProjectDerivedResults. It applies to all 80 requirements and 27 processes. The eight discipline-specific design audit resolutions remain mandatory. Later ELV5 project-alignment/runtime-version hardening now freezes the initial additive ELV5 database target at **schema 24**; that later decision supersedes the earlier provisional instruction to choose an arbitrary version greater than 23 at implementation time.

## P0

Start from merged schema 23, not the original ELV4 design commit. Preserve ELV1 canonical identities, ELV2 immutable reference editions/adoption and ELV3 realized routing/installed length. ELV4 closure findings C01–C06 are RESOLVED. The recorded RM01 architecture deviation is authoritative: dedicated power evaluation records/pointers and reverse index, separate from legacy ProjectDerivedResults. No prerequisite power platform reimplementation is planned in ELV5.

BASE-01 is EVIDENCED for inherited ELV4. BASE-02 is RECONCILED for canonical writer boundaries, immutable history and real v21/v22 migration origins. This does not assert support for every older schema or validate new discipline consumers. BASE-03 and BASE-04 remain OPEN_ELV5_EXTENSION for new storage/dispatch and qualification.

## P1

Reuse PowerRational/PowerInterval and `elv4.exact-rational.v2`; retain existing decimal/rational canonicalization. Add signed discipline units and bounded geometric outputs explicitly without changing power payload semantics. Reuse exact reference editions and explicit reviewed adoption; never read latest catalog values for historical calculations.

Keep `elv4-node-v2`, `elv4-evaluation-v2` and power evidence codecs byte/hash compatible. Proposed `engineering-node-v3` and discipline evaluation v3 are new ELV5 registrations, not new versions of public power commands. DESIGN scope and 27 discipline codes belong to discipline dispatch. Unknown owner/schema/code/scope combinations fail closed.

## P2

Add DisciplineEvaluationRecords, DisciplineEvaluationPointers and a discipline dependency reverse index as new isolated stores. Preserve legacy ProjectDerivedResults and dedicated power stores; never insert discipline process codes into PowerEvaluationRecords or migrate old evaluations into the new owner. An adapter may combine read projections only after explicit owner/schema dispatch. Manual edit, retirement and generic recalculation must leave foreign stores unchanged.

Reuse public command principles and coordinated transaction ownership: replay durable outcome before mutable lifecycle/CAS checks; reject command ID reuse with different type/schema/payload; verify expected aggregate rows and design revision; resolve reviewed impact/dependencies server-side. Replace assignment aggregates in one Drift transaction, with one design-token advance and durable outcome/history. No independently committed nested writer. ELV5 cannot bypass active power ownership by calling legacy writers; coordinated canonical edits must preserve complete graph validation and exact old/new invalidation. Existing fail-closed legacy behavior remains until an explicit reviewed adapter exists.

Public power `electra.elv4-command.v1` and revision `electra.elv4-revision-command.v2` stay registered unchanged. P1/P2 define an independent strict ELV5 command schema and operation/payload versions, required fields, malformed/unknown-field behavior and canonical command fingerprint before implementation acceptance. Command version, evaluation version, node-key version and DB schema are distinct axes.

Extend freeze atomically under the existing revision transition. Preserve `electra.elv4-power-freeze-section.v2` captured canonical/power facts, existing physical hashes and `electra.elv4-snapshot-manifest.v1` verification. Define a new manifest version with a discipline section/hash and an explicit reader dispatch; never rewrite an old frozen manifest. Older captures return ELV5_NOT_CAPTURED, distinct from a new CAPTURED_EMPTY section. Frozen reads use captured facts, including definitions/geometry/assignments, without operational-row fallback.

Create-next uses the project maximum sequence allocator and verifies the base physical/power/manifest hashes first. Materialize new discipline configuration via typed physical/assignment remapping in the same transaction as inherited power configuration. Do not copy CURRENT pointers, evaluation rows, receipts or history cursors into R2; R1 evaluations remain immutable provenance. Reuse durable forward/inverse history, revision-local cursor and replay rules; test restart-safe redo through an ELV5 adapter.

The initial additive ELV5 migration is now **schema 23 → schema 24**, frozen by `runtime-version-registry.json` and `persistence-schema-contract.md`. Implement it as an additive migration from the actual accepted schema-23 baseline; supported historical origins still traverse the existing migration chain to 23 before the ELV5 24 step. A future schema-number change requires an explicit synchronized migration/runtime-version/manifest review and is not a developer-local choice. Old schemas gain no invented discipline policies, evaluations or captured sections.

## P3

CCTV reuses immutable project-wide PoE/source/backup evidence and ELV3 routes. Existing Q-CCTV qualifies the power vertical only; it does not implement CCTV-01…06 geometry, streams, storage or recorder sizing. New discipline tests must prove those dimensions and full shared-source contribution references.

## P4

LAN consumes realized path/resource length and PWR evidence without recalculating installed allowances. Existing Q-LAN and PWR-06 qualify inherited power delivery, not LAN-01…07 copper/optical/port/rack-demand calculations. Keep optical reserve separate from physical loss and preserve basis-only ELV6 handoff.

## P5

ACS reuses canonical assemblies, complete shared supply/battery closure and captured power facts. Q-ACS is inherited power qualification; explicit door role assignments, multiplicities, control capacities and ACS-01…06 remain ELV5 implementation work. Canonical assignment ownership and reviewed power port edits must use one coordinated writer. ACS-03 executable fixtures must use the corrected frozen oracle `23.51 V / +1.51 V` for the stated shared-trunk inputs.

## P6

Fire reuses supported ELV4 DC/backup models and ordered scenarios; Q-FIRE does not qualify FA-01…08 signal loops, addresses or jurisdictional compliance. Signal-loop topology cannot be passed to an unsupported power mesh solver. Preserve declared applicability and ELV7 handoff.

## P7

Reuse consumed-facts fingerprints, exact old/new closures, guarded publication and workspace revision/context generation conventions. Register discipline dependency keys including missing facts and membership sets. Canonical or power changes invalidate affected discipline consumers; discipline demand/policy edits affecting shared requirements invalidate the full affected power closure and its consumers. Capture immutable power evidence IDs/hashes and pointer generations; a changed consumed generation rejects late publication. Avoid dependency cycles: compose physical requirement inputs before power evaluation, then consume evidence in discipline wrappers. A dependency adapter is required; the existing power reverse index does not automatically index new discipline nodes.

Extend the existing editor workspace/controller conventions for preview, draft retention, selection, undo/redo and historical reads. Preserve full source totals alongside selected discipline contribution. RUNNING is transient; freeze and late publication preserve inherited CAS behavior.

## P8

Retain all seven inherited cases: Q-CCTV, Q-LAN, Q-ACS, Q-FIRE, Q-SHARED, Q-GENERIC and Q-CHARGE. Add a complete executable 27-process discipline qualification manifest with required context/dimension/status rows, real evaluator output, immutable evidence and validated CURRENT pointers. A synthetic PASS or an inherited power wrapper is insufficient.

Use FK-valid file SQLite public-command setup, reopen assertions, response-loss replay, durable REJECTED outcomes, failure checkpoints and two-connection races. Cover canonical adoption/edit versus publication, power/discipline membership changes, duplicate freeze, freeze/create-next, pointer generation and undo cursor conflicts. Verify affected and unaffected consumers across all three stores.

Retain real historical v21 origin `74c61f6443c3beaf98e69f0d5f21af3f09474c5c` and v22 origin `b5e3dc94ba026ecb76e3b6e1b17853bf0f63ccb4`; add a real v23 merged-source origin and upgrade all to schema 24. Keep legacy IDs, hashes, v22 scenario and v23 power facts/evidence intact. No synthetic discipline backfill; FK/integrity checks and pre-ELV5 NOT_CAPTURED remain required. Current-schema fixtures with only user_version changed do not prove historical compatibility.

## P9

Keep inherited baseline evidence separate from new ELV5 requirement/source/test evidence. All ELV5 runtime requirements remain NOT_STARTED until implemented; BASE-01/02 reconciliation is not ELV5 runtime acceptance. Original audit records remain historical, with current applicability governed by the ELV5 authoritative index and later hardening amendments.

Provide a permanent read-only ELV5 gate: project-alignment/binding/specification guards, Drift generation, format, analyzers, full mobile/core suites, historical migrations, inherited seven-case qualification plus new discipline qualification, baseline compatibility and clean-tree check at one SHA. Technical and qualification reports must match that SHA. Runtime acceptance is an external executed artifact, avoiding a source-tree self-referential SHA. No automatic normalization/apply scripts in the gate. Zero unresolved BLOCKER/HIGH/GATE precedes acceptance; merge and closure are separate events.
