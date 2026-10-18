# ELV5 — Ampacity / allowable continuous current `Iz` engineering contract

Status: **AUTHORITATIVE ELV5 HARDENING AMENDMENT**  
Branch: `feat/flutter-elv5-power-topology-design`  
Applies to: reusable ELV5 cable technical evidence, initially consumed by `FA-08`.

## 1. Purpose and ownership

ELV5 shall calculate cable allowable continuous current `Iz` as a separate engineering contract.

It must not be merged with:

- connected/design load current `Ib`;
- protective-device rated current `In`;
- voltage-drop calculation `ΔU`;
- short-circuit thermal withstand;
- ELV7 jurisdictional compliance/certification.

The contract answers only:

> Given an exact selected ampacity reference row and exact applicable correction factors, what is the allowable continuous current `Iz` for this cable/route section?

The fixed ELV5 process inventory remains **27**. Ampacity is a reusable typed engineering primitive/evidence contract, not process 28.

## 2. Mandatory physical basis

A complete `Iz` evaluation requires all of the following:

1. conductor cross-section;
2. conductor material;
3. insulation/temperature system used by the selected reference table;
4. installation/wiring method;
5. number of loaded conductors;
6. immutable reference-row identity and base allowable current;
7. actual ambient/environment temperature basis;
8. temperature correction factor;
9. cable/circuit grouping count and arrangement;
10. grouping correction factor;
11. every other explicitly applicable derating/correction factor with evidence provenance.

No one of these may be silently defaulted.

Forbidden examples:

```text
missing material       -> assume copper
missing temperature    -> assume 30 C
missing loaded cores   -> assume 2 or 3
missing grouping       -> assume one cable / kG=1
missing method         -> assume tray/free-air
missing factor         -> use 1.0
```

All such cases are incomplete engineering evidence and must remain BLOCKED/UNRESOLVED at the consuming process boundary.

## 3. Reference-row selection

The base current is not invented by the algorithm.

A selected immutable reference row has the effective key:

```text
reference edition
+ conductor cross-section
+ conductor material
+ insulation/temperature system
+ installation method
+ loaded conductor count
= base allowable current Iref
```

The row must carry:

```text
evidenceRef
evidenceContentHash
```

Interpolation between table rows is forbidden unless a separately versioned interpolation model explicitly owns that operation.

The implementation must never keep hidden ampacity tables in UI code or ad-hoc resolver constants.

## 4. Temperature correction

Actual ambient temperature and the selected reference temperature are separate facts.

The temperature factor `kT` must be taken from an immutable evidence edition compatible with the selected reference basis.

```text
actualAmbientTemperatureC
referenceAmbientTemperatureC
kT
temperatureEvidenceRef
temperatureEvidenceContentHash
```

Host weather, current device locale, current date, room label or a generic indoor/outdoor flag must not synthesize temperature.

## 5. Grouping correction

Grouping is a physical-route fact, not a display attribute.

The grouping basis must explicitly state:

```text
groupedCableOrCircuitCount
arrangementCode
kG
groupingEvidenceRef
groupingEvidenceContentHash
```

Examples of arrangement identity may distinguish bunched, touching, spaced, tray layers, conduit grouping or another edition-defined model.

Counting one logical circuit as one physical cable is allowed only when exact route/allocation evidence proves that identity.

## 6. Loaded-conductor count

`loadedConductors` belongs to the selected ampacity reference row key.

It must come from an explicit cable/operating-state model. Neutral/return conductors, parallel conductors and state-dependent loaded-core semantics must not be inferred from cable name, phase count string or UI convention.

If the applicable reference standard/table distinguishes loaded conductor count, missing count blocks `Iz`.

## 7. Mathematical model

The canonical v1 equation is:

```text
Iz = Iref * kT * kG * product(kAdditional[i])
```

where:

- `Iref` = exact base allowable current from selected immutable reference row;
- `kT` = exact temperature correction factor;
- `kG` = exact grouping correction factor;
- `kAdditional[i]` = explicitly applicable additional correction factors.

All values use `Elv5Rational`.

Binary floating point must not decide an engineering verdict.

## 8. Exact input/output contract

Pure core implementation:

```text
Elv5AmpacityReferenceRow
Elv5AmpacityTemperatureCorrection
Elv5AmpacityGroupingCorrection
Elv5AmpacityAdditionalCorrection
Elv5AmpacityInput
Elv5AmpacityResult
Elv5AmpacityKernel
```

Canonical result:

```text
baseAllowableCurrentA
temperatureFactor
groupingFactor
additionalFactorProduct
allowableCurrentIzA
```

The result does not contain `Ib`, `In` or `ΔU`.

## 9. ELV3/ELV4 evidence projection rule

ELV3 remains owner of physical cables, routes, carriers, installation facts and route membership.

ELV5 resolver may project those facts into this contract, but must preserve exact provenance.

Important compatibility rule:

- legacy ELV3 `double` numeric fields are not sufficient by themselves for an Iz PASS/FAIL decision;
- exact decimal/rational evidence or a content-addressed exact projection is mandatory at the ELV5 engineering boundary;
- a resolver may cross-check legacy numeric values for diagnostics but must not round-trip them through binary floating point into canonical `Iz` evidence.

## 10. FA-08 binding

`FA-08` remains the Fire cable/environment technical-policy process.

It consumes the shared ampacity contract through the reserved numeric technical property:

```text
propertyCode = AMPACITY_IZ_A
unitCode     = A
```

A technical policy may therefore express, for example:

```text
AMPACITY_IZ_A >= required technical threshold
```

The value is produced only by `Elv5AmpacityKernel`; callers cannot inject a duplicate raw numeric fact under that reserved property code.

FA-08 still does not claim regulatory compliance. `verifiedCompliance` remains ELV7-owned.

## 11. Separation from connected load and voltage drop

The following are independent dimensions:

```text
load/current demand       -> Ib / demand evidence
ampacity                  -> Iz
voltage drop              -> terminal voltage / ΔU evidence
protection coordination   -> separate protection contract/process
```

A cable may have acceptable voltage drop but insufficient ampacity, or sufficient ampacity but unacceptable voltage drop.

No PASS in one dimension may imply PASS in another.

## 12. Persistence/evidence requirements

Every persisted ampacity edition must be content-addressed or otherwise immutable and include enough evidence to reproduce:

```text
reference table/edition
selected row key
Iref
actual/reference temperature
kT
group count/arrangement
kG
additional corrections
canonical input hash
canonical output hash
```

Changing section, material, installation method, loaded-conductor count, temperature evidence or grouping membership invalidates the affected Iz result.

## 13. Dependency/invalidation requirements

Dependency closure must include selectors for:

- cable definition/reference edition;
- cable/route section identity;
- conductor material/cross-section evidence;
- carrier/path installation method;
- environment/temperature evidence;
- grouping membership set;
- loaded-conductor/state profile;
- ampacity table/policy edition;
- correction-factor editions.

Insertion of a newly grouped cable must invalidate affected ampacity evaluations even when the evaluated cable record itself did not change.

## 14. Qualification vectors

### Positive

```text
Iref = 40 A
kT   = 0.91
kG   = 0.80
Iz   = 29.12 A
```

### Boundary

Exact rational factors producing exactly the policy threshold are PASS when the selected policy comparison is inclusive.

### Negative

A complete Iz value below an explicit technical minimum is FAIL at the consuming technical-policy dimension.

### Missing evidence

Missing material, method, loaded-conductor count, temperature factor or grouping factor is BLOCKED/UNRESOLVED, never defaulted.

### Adversarial

Changing grouped cable count from 1 to 4 while keeping the cable object unchanged must invalidate prior Iz evidence and recompute with the new `kG`.

### Cross-discipline

The same physical cable/section and ampacity evidence may be consumed by Fire, ACS, LAN-powered or other ELV5 technical checks. The physical `Iz` calculation must not be duplicated per discipline.

## 15. Acceptance gate

Ampacity support is accepted only when all are true:

1. pure core uses exact rational arithmetic;
2. no hidden/default engineering factors exist;
3. all six user-facing physical drivers are represented: section, material, temperature, installation method, grouping and loaded conductors;
4. provenance/hash is present for reference row and correction factors;
5. grouping-set mutations invalidate Iz;
6. FA-08 uses the shared result rather than a raw caller-supplied `AMPACITY_IZ_A` value;
7. `Iz` remains independent from connected load and voltage-drop verdicts;
8. tests cover positive, missing-evidence and invalidation/adversarial cases.
