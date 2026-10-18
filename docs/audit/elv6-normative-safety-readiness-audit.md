# ELV6 — normative safety readiness audit

Date: 2026-10-18  
Branch: `feat/flutter-elv6-enclosure-layout-design`  
Status: **DESIGN HARDENING / SAFETY READINESS GAPS OPEN / RUNTIME NOT STARTED**

## Purpose

This audit asks a narrower question than the original ELV6 constructability audit:

> Does ELV6 produce enough exact, revisioned physical evidence for a later ELV7 ruleset to evaluate safety without guessing geometry, silently adopting a standard edition, or rereading mutable current state?

The answer before this remediation was **no**. ELV6 was strong enough to reason about physical fit, serviceability, cable entry, rack/DIN occupancy, mass, airflow and bonding basis, but it did not yet guarantee all evidence needed for insulation coordination, enclosure integrity, accessible hazardous parts and national-edition applicability.

## Standards families reviewed

The machine-readable source is `../product/elv6-implementation/safety-standards-registry.json`.

Core families considered:

- IEC 61439-1 / IEC 61439-2 — LV assembly construction and verification framework;
- IEC 62208 — empty enclosures;
- IEC 60529 — IP enclosure protection;
- IEC 62262 — IK mechanical impact protection;
- IEC 60664-1 — insulation coordination, clearance and creepage basis;
- IEC 60364-4-41 — protection against electric shock;
- IEC 60364-5-54 — earthing/protective conductors and bonding;
- IEC TR 60890 — temperature-rise calculation inputs;
- IEC 60297-3-100 and IEC 61587-1 — rack/cabinet mechanical structures and safety/performance basis;
- IEC 60204-1 — optional machinery-control profile;
- ISO/IEC 11801-1 and EN 50174-2 — ICT/LAN physical cabling context;
- IEC 62676-1-1 — CCTV/VSS context;
- IEC 60839-11-2 — ACS application context.

Kazakhstan catalogue state considered separately from international edition currency. The design must not equate “newer international/interstate publication exists” with “effective national requirement”.

## Kazakhstan edition handling

The KZ profile must represent edition/effectivity state explicitly.

Current catalogue evidence used for design readiness includes:

```text
GOST IEC 61439-1-2013        current national-use baseline in KSM catalogue
GOST IEC 61439-2-2015        current national-use baseline in KSM catalogue
GOST IEC 61439-1-2024        adopted interstate, not introduced
GOST IEC 61439-2-2024        adopted interstate, not introduced
ST RK IEC 60529-2012         current
ST RK IEC 62262-2012         current
ST RK IEC 60364-5-54-2012    current
ST RK IEC 60297-3-100-2018   current
```

The exact project compliance profile remains ELV7 responsibility. ELV6 stores evidence and immutable profile/registry provenance only.

---

## NRG-01 — BLOCKER: enclosure integrity after modification was not first-class

### Existing strength

ELV6 already models cable entries, ventilation openings, doors and placement geometry.

### Gap

There was no canonical projection proving the complete set of openings, cutouts, glands, seals, unused openings and post-modification enclosure fingerprint.

### Risk

A UI could visually place a gland or fan and later ELV7 could incorrectly evaluate an original enclosure IP capability while ignoring that the enclosure had been modified.

### Resolution

Add immutable `Elv6EnclosureIntegrityEvidence` containing:

```text
enclosure technical-definition hash
all openings/cutouts/knockouts
closure/seal/gland adopted-definition hashes
intentional-open state
modification identities
post-modification fingerprint
```

ELV6 never computes an IP/IK class from this evidence.

Status: `SPEC_RESOLVED / RUNTIME_OPEN`.

---

## NRG-02 — BLOCKER: clearance and creepage were conflated with generic segregation

### Existing strength

`LAY-21` exports observed physical segregation distance between declared groups.

### Gap

IEC insulation coordination requires evidence that cannot be represented safely by one generic shortest-distance number. Air clearance and surface creepage are different geometrical problems.

### Risk

An implementation could reuse Euclidean shortest distance as creepage and produce a technically false safety result.

### Resolution

Add two separate projections:

```text
Elv6AirClearanceMeasurement
Elv6CreepagePathMeasurement
```

Air clearance stores exact closest points/distance between classified conductive regions. Creepage stores a deterministic path over identified insulating surfaces plus material/provenance context. Missing path geometry is `UNRESOLVED`.

Status: `SPEC_RESOLVED / RUNTIME_OPEN`.

---

## NRG-03 — HIGH: accessible hazardous parts/barriers were under-modelled

### Existing strength

ELV6 has door sweep, service/removal envelopes and host containment.

### Gap

There was no state-dependent physical model for dangerous/live region exposure with door closed/open, cover removed by tool or maintenance access.

### Resolution

Add:

```text
Elv6BarrierEvidence
Elv6HazardAccessEvidence
Elv6AccessState
```

ELV6 exports geometry and barrier state only. ELV7 decides shock-protection compliance.

Status: `SPEC_RESOLVED / RUNTIME_OPEN`.

---

## NRG-04 — HIGH: partitions/form-of-separation were thermal metadata, not safety evidence

### Existing strength

Thermal basis already mentions partitions.

### Gap

Partitions lacked a normative-evidence identity suitable for separation/access/clearance projections.

### Resolution

Persist exact partition bodies, material-definition hashes, separated regions and adjacency projection. Partition changes invalidate thermal, access and relevant distance evidence atomically.

Status: `SPEC_RESOLVED / RUNTIME_OPEN`.

---

## NRG-05 — HIGH: insulation/material/environment context was not explicit

### Gap

Clearance/creepage downstream logic depends on technical context such as circuit potential class, material evidence, altitude/environment and other profile inputs. A global app default is unacceptable.

### Resolution

Add immutable context/provenance references and classify conductive regions explicitly. ELV6 does not translate those references to normative thresholds.

Status: `SPEC_RESOLVED / RUNTIME_OPEN`.

---

## NRG-06 — HIGH: rack/enclosure capability provenance was incomplete

### Existing strength

ELV6 already has rack profile, static-load facts, mass/CoG and exact physical definitions.

### Gap

Environmental/mechanical capability claims and enclosure/rack test declarations were not explicitly required to carry adopted technical-definition/edition provenance.

### Resolution

Every capability used by ELV6 or exported to ELV7 is tied to an immutable technical-definition hash. Names such as “19 inch”, “IP65 cabinet” or manufacturer labels are never evidence by themselves.

Status: `SPEC_RESOLVED / RUNTIME_OPEN`.

---

## NRG-07 — BLOCKER: standard applicability/effective edition could drift silently

### Gap

The old design said “ELV7 owns normative profiles” but did not require the profile to distinguish effective national edition from newer publications.

### Kazakhstan counterexample

The KSM catalogue currently exposes older effective GOST IEC 61439 editions while 2024 editions are present as adopted interstate documents not yet introduced. A naïve “pick newest year” algorithm is therefore wrong.

### Resolution

Normative profile provenance distinguishes:

```text
CURRENT_NATIONAL
ADOPTED_NOT_YET_INTRODUCED
WITHDRAWN
INTERNATIONAL_REFERENCE_ONLY
PROJECT_EXPLICIT_OVERRIDE
```

Profile edition changes create a new ELV7 evaluation context; they never rewrite frozen ELV6 evidence.

Status: `SPEC_RESOLVED / RUNTIME_OPEN`.

---

## NRG-08 — BLOCKER: safety evidence had no explicit freeze/replay contract

### Gap

Even correct measurements are not auditable if historical revision replay rereads current technical definitions, current openings or current profile context.

### Resolution

The ELV6 snapshot section must include hashes of all mandatory normative evidence projections and their source technical-definition identities. Historical replay is exact. Pre-evidence legacy snapshots return typed NOT_CAPTURED/UNRESOLVED semantics, never current-state fallback.

Status: `SPEC_RESOLVED / RUNTIME_OPEN`.

---

# Readiness matrix against existing LAY processes

| Safety concern | Existing ELV6 coverage | Required hardening |
|---|---|---|
| body containment/collision | LAY-01..04 | sufficient core geometry |
| rack/DIN mechanics | LAY-05..08 | retain profile provenance |
| service/removal/access | LAY-09/10 | add hazardous-access/barrier projection |
| entries/bend/termination | LAY-11..14 | add enclosure-integrity impact |
| battery/support/mass/CoG | LAY-15..17 | sufficient physical basis; downstream rules remain ELV7 |
| ventilation/thermal | LAY-18/19 | strengthen partition + enclosure surface provenance |
| reserve | LAY-20 | no direct safety verdict |
| segregation | LAY-21 | keep generic measurement; add dedicated clearance/creepage projections |
| bonding | LAY-22 | preserve exact physical graph/provenance |
| auto-layout | LAY-23 | hard constraints must include required intrinsic safety evidence availability where applicable |
| aggregate | LAY-24 | must not report readiness if mandatory safety projection capture is incomplete |
| IP/IK | partial data only | enclosure-integrity projection required |
| shock access | partial via door/service geometry | hazardous-access projection required |
| clearance/creepage | incomplete | dedicated measurement projections required |
| national edition provenance | absent | profile/effectivity registry required |

# Runtime-entry consequences

P0 may not return `READY` unless it identifies canonical owners and writers for:

```text
conductive/live region geometry
barriers/covers/partitions
enclosure openings/modifications
seal/gland/closure technical definitions
insulating surface/material refs
safety environment context
normative profile/effectivity provenance
```

If any already has an accepted upstream owner, ELV6 adapts it. If absent and the fact is physical-layout-owned, ELV6 adds the first canonical revision-scoped owner. Duplicate safety truth is prohibited.

# Qualification consequences

The design-only safety checker is `scripts/ci/check-elv6-safety-readiness.py`. Runtime P8/P9 must later prove at exact source SHA:

```text
clearance one-micrometre boundary determinism
creepage path distinct from air distance
access-state/barrier replay
cutout/gland/closure invalidation
partition invalidation closure
bond evidence replay
standards/profile provenance pinning
historical freeze/reopen equality
create-next independence
stale publication rejection
fault rollback with no partial evidence publication
```

# Final audit verdict

**ELV6 is not yet runtime-ready, but its design can now be made safety-ready without violating ELV7 ownership.**

The correct architecture is not “implement every standard inside ELV6”. It is:

```text
ELV6 = exact physical evidence and measurements
ELV7 = jurisdictional/normative rules and verdicts
ELV8 = product/SKU selection and deliverables
```

The highest-priority runtime-entry blockers are `NRG-02`, `NRG-03`, `NRG-07` and `NRG-08`, with `NRG-01` effectively mandatory for any enclosure/IP-sensitive project.
