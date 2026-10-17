# ELV5 F2 production qualification harness

## Purpose

`Elv5F2QualificationHarness` is the canonical test-side lifecycle contract for production qualification of the 27 ELV5 calculation processes.

It does not replace process-specific engineering assertions. It centralizes the cross-cutting Q6/Q7/Q8 invariants so different processes cannot silently use different definitions of production qualification.

## Canonical implementation

- `apps/mobile/test/support/elv5_f2_qualification_harness.dart`

## Q6 — production publication

The shared harness requires a production-runtime publication to persist a non-empty evaluation identity, publish a `CURRENT` pointer with a positive generation, persist a 64-character input fingerprint, and produce a non-empty logical result.

Where the fixture has a mutable authoritative dependency, replacement and recalculation must publish a new evaluation and a changed input fingerprint.

Process-specific dependency domains, assessment semantics and engineering outputs remain asserted by the owning E2E test.

## Q7 — restart and concurrency

The shared harness requires durable SQLite reopen/restart replay to preserve:

- pointer generation;
- evaluation identity;
- logical result.

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

## Promotion rule

A process is not promoted merely because it imports or calls the harness. Q6/Q7/Q8 status is promoted only when the corresponding production witness is present in the canonical F2 matrix and the exact source SHA has passed the repository Flutter CI gates.

The remaining ELV5 processes must be migrated in controlled waves using this same lifecycle contract before final `ELV5 = ACCEPTED`.
