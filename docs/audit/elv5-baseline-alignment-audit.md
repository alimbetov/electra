# ELV5 — Baseline and boundary alignment

Date: 2026-10-15. Parent branch: `feat/flutter-elv4-power-topology-design`.
Pinned parent: `4c35840bf1453df8adc49cce18d937fe20a52801`.
Scope: repository/design inspection, not runtime tests.

## Observed foundation

The parent contains ELV4 authoritative/coordinated/detailed specifications, 80 requirements, RM01–RM15 design remediation, wire examples and seven positive qualification design cases. Their own statuses are RUNTIME_NOT_IMPLEMENTED/NOT_STARTED. They cannot be cited as existing accepted power runtime.

The inherited source declares database schema 21. ELV3 installed length code is ELV-ROUTE-01 in engineering_core/lib/src/elv_physical_calculations.dart. Existing older overview lists mixed CURRENT/RUNNING/WARNING/BLOCKED statuses and an ambiguous recordingSeconds×retentionDays example; new ELV5 contracts separate freshness/completion/assessment/execution and integrate unique recording time once.

## Alignment decisions

| Area | ELV5 decision |
|---|---|
| Stage responsibility | 27 discipline processes; keep ELV4 physical topology/power kernel and ELV3 routing |
| Shared platform | Add ELV5 owner and registered v3 evaluation/key scope extension; preserve old v1/v2 codecs/hashes |
| Shared power | One full project source/bank closure; context wrappers show contribution without reducing total or repeating reserves |
| Exact evidence | Same revision/scenario scope, consumed facts, typed remapping, durable history and guarded publication |
| Geometry | Explicit supported pinhole/plane model and bounded backend; unsupported visibility/DORI never passes |
| Later stages | LAN-06 demand basis versus ELV6 layout; FA-08 policy/evidence basis versus ELV7 verified compliance; no ELV8 product selection |

## Entry obligations

ELV5-BASE-01 HIGH: obtain actual accepted ELV4 runtime evidence for required RM01–RM15 infrastructure and PWR processes before dependent runtime acceptance.
ELV5-BASE-02 HIGH: reconcile inherited ELV1–ELV3 baseline gaps and actual supported migrations; parent design closure labels are not evidence.
ELV5-BASE-03 MEDIUM: define/test v3 owner/key/envelope/schema dispatch and old cached result/manual/retirement consumers.
ELV5-BASE-04 MEDIUM: implement concrete strict discipline codecs and complete executable qualification input dataset during P1/P2/P8; planned oracles alone are not a passing vertical.

These are known design entry obligations, not newly proven source bugs. ELV5 design proceeds; no app or normative compliance verification has been performed in this branch preparation.
