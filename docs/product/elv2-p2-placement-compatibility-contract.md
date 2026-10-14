# ELV2-P2 Placement Compatibility Engine — decision contract

Status: implementation contract for P2  
Branch: `feat/flutter-elv2-profile-constraints`  
Parent specification: `docs/product/elv2-profile-constraints-technical-specification.md`

## Boundary

P2 is a pure `engineering_core` capability. It has no Flutter, Drift, repository or localization dependency. The engine evaluates one immutable `ComponentEngineeringProfile` against one candidate placement context. Discipline-specific behavior is forbidden inside the engine; CCTV, LAN, ACS and Fire are acceptance fixtures proving that the same rules work across disciplines.

## Input

`PlacementCandidateContext` carries engineering facts known before placement:

- project/room/surface identity;
- installation surface and mounting method;
- environment exposure, moisture, contamination and climate;
- ambient temperature when known;
- actual/available IP protection when known;
- whether an enclosure is present;
- available clearance when known;
- selected system topology shape when known;
- intended topology participation role when known.

Missing information is represented explicitly and never guessed.

## Output

`PlacementCompatibilityResult` contains:

- `status`: `compatible | warning | forbidden | unresolved`;
- exact profile/catalog provenance supplied to the evaluation;
- deterministic ordered `PlacementFinding[]`.

Each finding contains a stable machine code, severity, dimension, explanation, allowed/expected value and actual candidate value. UI code may localize or render findings but must not reproduce the engineering decision rules.

## Aggregation

Final status is deterministic:

```text
any ERROR finding       -> FORBIDDEN
else any UNRESOLVED     -> UNRESOLVED
else any WARNING        -> WARNING
else                    -> COMPATIBLE
```

`legacyUnspecified` constraints always produce `UNRESOLVED`. They never mean unrestricted compatibility.

## Mounting rules

- Surface + mounting method is validated as one exact `MountingOption` pair.
- `enclosureRequired` is enforced.
- `minimumClearanceMm` is enforced when defined.
- Missing facts required to prove a rule produce `UNRESOLVED`; a known mismatch produces `FORBIDDEN`.

## Environment rules

- Exposure is mandatory for a defined profile.
- Moisture, contamination and climate are checked when the profile constrains that dimension.
- Temperature is checked when the profile declares a range.
- Minimum IP protection is checked by numeric ingress/water positions; `X` cannot prove satisfaction of a numeric requirement.
- Missing required environmental evidence produces `UNRESOLVED`.

## Topology pre-placement boundary

P2 validates only candidate intent that can be known before graph mutation:

- selected topology shape is allowed;
- intended participation role is allowed.

It does not prove graph-state invariants such as real loop closure, degree, branch count or ordering across persisted connections. Those remain graph validation / revision revalidation responsibilities.

## Acceptance

P2 is complete only when pure-domain tests cover:

- compatible candidate;
- exact mounting-pair mismatch;
- enclosure and clearance requirements;
- each environment dimension;
- lower/upper temperature boundaries;
- IP satisfaction and insufficient/unknown IP;
- topology shape/role mismatch;
- incomplete candidate context -> `UNRESOLVED`;
- legacy profile -> `UNRESOLVED`;
- CCTV, LAN, ACS and Fire profiles evaluated by the same engine;
- deterministic finding order and status aggregation;
- `dart format`, `dart analyze`, `dart test`, and full exact-head CI green.
