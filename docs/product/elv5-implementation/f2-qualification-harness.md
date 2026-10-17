# ELV5 F2 production qualification harness

## Purpose

`Elv5F2QualificationHarness` is the canonical test-side lifecycle contract for production qualification of the 27 ELV5 calculation processes.

It does not replace process-specific engineering assertions. It centralizes the cross-cutting Q6/Q7/Q8 invariants so different processes cannot silently use different definitions of production qualification.

## Canonical implementation

- `apps/mobile/test/support/elv5_f2_qualification_harness.dart`

## Q6 — production publication

Q6 requires `SUCCEEDED` and `COMPLETE`; a persisted `BLOCKED` result cannot satisfy production qualification.

The shared harness requires a production-runtime publication to persist a non-empty evaluation identity, publish a `CURRENT` pointer with a positive generation, persist a 64-character input fingerprint, and produce a non-empty logical result.

Where the fixture has a mutable authoritative dependency, replacement and recalculation must publish a new evaluation and a changed input fingerprint.

Process-specific dependency domains, assessment semantics and engineering outputs remain asserted by the owning E2E test.

## Q7 — restart and concurrency

The shared harness requires durable SQLite reopen/restart replay to preserve:

- pointer generation;
- evaluation identity;
- logical result.

Replay additionally preserves the exact input fingerprint, output SHA-256 and the execution/completion axes. Both hashes must be non-empty lowercase 64-hex values; every baseline witness reads output identity from persisted evaluation/pointer state.

A stale writer must fail closed with `ELV5_POINTER_GENERATION_CONFLICT`.

## Q8 — frozen historical replay

After the design revision becomes `FROZEN`, the committed command must remain historically replayable without republishing CURRENT.

A new calculation must fail closed with `ELV5_DESIGN_REVISION_READ_ONLY`.

Process-specific authoritative mutation paths remain responsible for asserting their own read-only rejection after freeze.

## Mature production scenarios bound to the harness

The first qualification wave binds the previously proven production E2E scenarios to the common lifecycle assertions without weakening their process-specific evidence:

- `CCTV-03` — `apps/mobile/test/data/elv5_f2_cctv03_full_runtime_e2e_test.dart`
- `LAN-05` — `apps/mobile/test/data/elv5_f2_lan05_full_runtime_e2e_test.dart`
- `ACS-03` — `apps/mobile/test/data/elv5_f2_acs03_full_runtime_e2e_test.dart`

Their existing dependency, result, invalidation and mutation assertions remain in place.

## Formatter reproducibility

The mature witness files are formatted only after `flutter pub get --enforce-lockfile`, matching the repository `Flutter Local Foundation` ordering. This ensures `dart format` uses the package language configuration seen by the authoritative CI gate instead of an unconfigured formatter context.

Formatter alignment itself is not qualification evidence. The harness wave remains pending until the resulting exact source SHA passes formatting, mobile analyze/test, engineering-core analyze/test and all ELV5 foundation gates.

## Analyze hygiene

The first exact-SHA harness run reached `flutter analyze` after the formatter gate and identified only three unused imports left from the former bespoke exception assertions. Those imports were removed without changing production behavior or shared Q6/Q7/Q8 semantics.

The formatter residue after that import cleanup was limited to one leading blank line in each of the CCTV-03 and LAN-05 witness files. The exact CI formatter artifact identified those two lines and they were removed without any functional change. The wave remains pending until this post-cleanup exact source SHA passes the complete foundation workflow.

## Promotion rule

A process is not promoted merely because it imports or calls the harness. Q6/Q7/Q8 status is promoted only when the corresponding production witness is present in the canonical F2 matrix and the exact source SHA has passed the repository Flutter CI gates.

The remaining ELV5 processes must be migrated in controlled waves using this same lifecycle contract before final `ELV5 = ACCEPTED`.

## FA-08 reference wave

The FA-08 production witness uses file-backed SQLite, the production runtime,
production environment/ampacity/policy writers, and a foreign-key-valid route
including its floor, surface patch, endpoints and traversal. Foreign keys stay
enabled, and `PRAGMA foreign_key_check` must be empty.

Normal conditions produce exactly 27 A against a 25 A policy minimum (PASS,
+2 A). Replacing the environment and its pinned correction produces 21 A
(FAIL, -4 A), with STALE invalidation followed by guarded republication.
Restart and frozen replay preserve the exact persisted output hash and input
fingerprint. Verified compliance remains `notAssessed`, owned by ELV7.

Q9 has a finite 512-section, two-requirement expansion vector in
`packages/engineering_core/test/elv5_fa08_cable_policy_test.dart`; reordering
requirements must produce the same 1024 policy results.

These source assertions remain pending qualification until their exact source
commit passes the complete workflow. The wave does not claim ELV5 acceptance.

The environment writer now invalidates consumed dependencies in the same
transaction as source replacement and design CAS. Semantic subject expansion
preserves each persisted dependency member identity. A fault at pointer
invalidation must roll back the new environment evidence, selector and design
revision; the witness proves the prior CURRENT pointer survives unchanged.

FA-08 Q7 also races two public runtime callers on the same durable database:
exactly one advances generation 3 to 4, the other receives a typed pointer CAS
conflict. An old design revision is rejected with no extra evaluation/ledger
records. Independent-connection races remain part of the global reliability
suite. After freeze, policy, environment and ampacity replacement all reject.

Policy and ampacity writers also invalidate their exact consumed markers in
the source-replacement transaction. Separate production witnesses replace each
source while CURRENT, require STALE generation 2, then republish a complete
engineering FAIL at generation 3 (+27 A versus 28 A policy, or 21 A versus
25 A policy respectively). New bindings invalidate missing-selector route
closures so previously blocked calculations cannot remain silently CURRENT.

Baseline replay witnesses re-read the evaluation row from SQLite after reopen
and freeze. Their fingerprint/output identity comparisons must not reuse an
evaluation object retained in memory from the initial publication.
