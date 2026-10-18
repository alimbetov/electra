# ELV5 — Environment profile and route ampacity amendment

Status: IMPLEMENTATION AMENDMENT  
Branch: `feat/flutter-elv5-power-topology-design`

## 1. Decision

`Room.roomType` and `Room.roomCategory` are classification/UI metadata only. They MUST NOT directly determine temperature, humidity, condensation, moisture, contamination, ampacity factors or technical PASS/FAIL.

Engineering environment is a separate immutable/versioned evidence object:

```text
Room / RouteSection
        ↓ explicit binding
EnvironmentProfile edition
        ↓
exact temperature range
exact relative-humidity range
condensation risk
exposure
moisture / contamination / climate classes
provenance + content hash
```

A room type MAY suggest a profile in UI, but the user/project must explicitly select/capture the profile edition before calculations may consume it.

## 2. Canonical types

Pure `engineering_core` owns:

```text
Elv5EnvironmentProfile
Elv5EnvironmentScopeBinding
Elv5RationalRange
Elv5CondensationRisk
Elv5EnvironmentExposure
```

Application/data owns persistence and scope resolution.

## 3. Scope precedence

For a cable route section:

```text
ROUTE_SECTION explicit profile
        >
ROOM explicit profile
        >
MISSING
```

No implicit fallback exists from:

```text
roomType
roomCategory
host OS locale/weather
project address
carrier label
```

Missing environment evidence is fail-closed for any process that requires it.

## 4. Route ownership

Current routing model provides:

```text
CableRunTraversal
  → routeSegmentId
  → CableRouteSegment.routeId
  → CableRoute.roomId
```

Therefore a section can resolve the containing room deterministically. A section override is used for local conditions such as:

- riser/shaft temperature;
- roof/outdoor exposure;
- plant-room hot zone;
- wet or condensing local zone;
- special enclosure/pathway environment.

## 5. Temperature and ampacity

Ampacity remains a separate shared engineering contract:

```text
reference row
(section + material + insulation + installation + loaded conductors)
        ↓ Iref
route-section environment max temperature
        ↓ exact kT evidence
cable/circuit grouping
        ↓ exact kG evidence
other explicit correction evidence
        ↓
Iz(section) = Iref × kT × kG × Πki
```

Each traversed section is evaluated independently.

Cable-run allowable current is:

```text
Iz(run) = min(Iz(section_i))
```

The section with minimum exact `Iz` is the governing section. Start-room conditions MUST NOT mask a worse environment later on the route.

## 6. Conservative temperature binding

For continuous-current ampacity, the route-section ampacity input uses the profile's conservative maximum ambient temperature:

```text
actualAmbientTemperatureC == EnvironmentProfile.temperatureC.maximum
```

A different representative temperature requires a separately versioned applicability model; it cannot be selected ad hoc by UI/runtime code.

## 7. Humidity and condensation

Relative humidity is a first-class exact range:

```text
0% <= RHmin <= RHmax <= 100%
```

Condensation is explicit:

```text
NONE
POSSIBLE
EXPECTED
UNKNOWN
```

Humidity/condensation are normally used for cable/equipment/environment compatibility and FA-08 technical policy matching. They MUST NOT silently generate an ampacity correction factor unless a versioned correction rule explicitly owns that factor.

## 8. Persistence

No schema bump is introduced. Frozen ELV5 schema remains unchanged.

Environment editions are stored content-addressed in:

```text
elv_revision_aggregate_evidence_records
aggregate_kind = ELV5_ENVIRONMENT_PROFILE
```

Active selectors use:

```text
discipline_policy_bindings
subject_kind = ROOM | ROUTE_SECTION
policyCode = ELV5_ENVIRONMENT_PROFILE
```

Writes use binding CAS + design-revision CAS. Historical editions remain immutable.

## 9. Invalidation

Changes to any of the following invalidate affected route ampacity / FA-08 results:

- room environment profile edition;
- route-section environment override;
- temperature range;
- relative humidity range when required by policy;
- condensation risk;
- moisture/contamination/climate class;
- route membership / traversal section;
- grouping membership;
- ampacity reference/correction editions.

Changing only `roomType` does not alter engineering results unless the user explicitly selects a different environment-profile edition.

## 10. False-PASS sentinels

The following are forbidden:

```text
SERVER_ROOM → assume 18..27 C
WET → assume RH 100%
TECHNICAL → assume 40 C
no profile → assume 30 C
no grouping evidence → kG = 1
first room temperature → whole-route temperature
```

## 11. Qualification vectors

Positive:

```text
section A / room profile max 30 C → Iz 27 A
section B / explicit shaft override max 45 C → Iz 19.2 A
route result = 19.2 A, governing section B
```

Boundary:

```text
RH 0..100% is valid; outside this range is rejected.
```

Negative:

```text
route section has no section profile and containing room has no explicit profile
→ BLOCKED / missing environment evidence
```

Adversarial:

```text
roomType = SERVER_ROOM but no profile edition
→ MUST NOT synthesize temperature/humidity
```

Cross-discipline:

```text
same EnvironmentProfile edition may feed FA-08 cable/environment policy,
shared ampacity Iz and later ELV7 applicability checks without duplicating
physical/environment ownership.
```
