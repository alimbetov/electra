# ELV6 — Normative safety evidence contract

Status: **DESIGN HARDENING / RUNTIME NOT STARTED**  
Branch: `feat/flutter-elv6-enclosure-layout-design`  
Authority: `elv6-authoritative-spec-index.md` → code-level runtime contract → this evidence contract → safety standards registry → ELV7 rule profiles.

## 1. Architectural rule

ELV6 does not decide whether a cabinet/rack is compliant with IEC, EN, ST RK, GOST, manufacturer rules or a project specification. ELV6 owns the exact revisioned physical evidence required to make that decision later.

The mandatory split is:

```text
technical/product facts + ELV3/4/5 engineering facts
                    ↓
ELV6 exact physical arrangement and measurements
                    ↓
immutable normative-evidence projection
                    ↓
ELV7 selected jurisdiction/ruleset/profile
                    ↓
PASS / FAIL / UNRESOLVED normative verdict
```

A standard number or edition is never an ELV6 algorithm. A numeric normative threshold is never embedded in a LAY kernel unless it is an intrinsic adopted product capability with immutable provenance.

## 2. Why the existing 24 LAY processes are not enough by themselves

The 24-process layout registry already covers containment, collision, DIN/U occupancy, service/removal access, entries, bend space, duct/termination capacity, mass/CoG, ventilation, thermal inputs, reserve, observed segregation and bonding.

However safety readiness requires additional **cross-cutting evidence projections** that must survive freeze/replay even when they do not deserve an independent layout process code:

1. enclosure integrity and modification evidence for IP/IK evaluation;
2. clearance and creepage measurement inputs;
3. accessible hazardous-part/barrier evidence;
4. partition/form-of-separation geometry;
5. insulation/material/environment context;
6. environmental/mechanical capability provenance;
7. exact national/profile/edition provenance;
8. immutable freeze/replay identity of every evidence projection.

These projections extend the evidence model without changing the closed `LAY-01..LAY-24` registry. If implementation proves any projection requires independent execution/publication semantics, P0/P1 must explicitly reopen the process registry instead of hiding a 25th calculation behind a helper.

## 3. Common evidence identity

```dart
final class Elv6NormativeEvidenceRef {
  final String id;
  final String projectId;
  final String designRevisionId;
  final String hostId;
  final String evidenceKind;
  final String evidenceSchema;
  final String captureFingerprint;
  final String sourceLayoutFingerprint;
  final String? sourceTechnicalDefinitionHash;
  final int generation;
}
```

Rules:

- evidence is revision-scoped and immutable after publication;
- CURRENT is guarded by generation/CAS exactly like other ELV6 evidence;
- no latest-revision fallback during historical replay;
- create-next remaps logical identity but never rewrites frozen evidence;
- evidence hash excludes display labels and timestamps;
- missing source facts yield explicit `PARTIAL/BLOCKED/UNRESOLVED`, never optimistic empty evidence.

## 4. Enclosure integrity and modification evidence

Needed by downstream IP/IK and enclosure rules.

```dart
enum Elv6EnclosureOpeningKind {
  doorGap,
  gland,
  glandPlate,
  knockout,
  cutout,
  vent,
  fanOpening,
  brushPanel,
  unusedOpening,
  custom,
}

final class Elv6EnclosureOpeningEvidence {
  final String openingId;
  final Elv6Aabb3 envelope;
  final Elv6EnclosureOpeningKind kind;
  final String? closureDefinitionHash;
  final String? sealDefinitionHash;
  final String? glandDefinitionHash;
  final bool intentionallyOpen;
  final String provenanceHash;
}

final class Elv6EnclosureIntegrityEvidence {
  final String hostId;
  final String enclosureDefinitionHash;
  final List<Elv6EnclosureOpeningEvidence> openings;
  final List<String> modificationIds;
  final String postModificationFingerprint;
}
```

ELV6 does not claim `IP54`, `IP65`, `IK08`, etc. It proves what the enclosure is, which openings/modifications exist and which adopted closure/gland/seal technical definitions are present.

Fail-closed rules:

- an untyped cutout cannot disappear from evidence;
- an unused opening without a closure definition is not treated as sealed;
- changing a door/gland/cutout/vent invalidates enclosure-integrity evidence;
- manual UI metadata cannot assert a resulting IP/IK class.

## 5. Clearance measurement basis

ELV7 may require air-clearance checks. ELV6 therefore needs exact live/conductive geometry and shortest-distance measurements.

```dart
enum Elv6ElectricalPotentialClass {
  protectiveEarth,
  neutral,
  functionalEarth,
  liveAc,
  liveDc,
  selvPelv,
  signal,
  unknown,
}

final class Elv6ConductiveRegionRef {
  final String regionId;
  final String ownerRef;
  final Elv6ElectricalPotentialClass potentialClass;
  final String? circuitRef;
  final String geometryFingerprint;
}

final class Elv6AirClearanceMeasurement {
  final String fromRegionId;
  final String toRegionId;
  final int shortestDistanceUm;
  final Elv6Point3 fromPoint;
  final Elv6Point3 toPoint;
  final String geometryAlgorithmVersion;
}
```

ELV6 reports the actual distance. ELV7 decides the required distance from voltage, impulse category, altitude, pollution/ruleset and the selected standard profile.

## 6. Creepage measurement basis

Creepage is not equivalent to Euclidean air distance. The model therefore cannot reuse `LAY-21` blindly.

```dart
final class Elv6InsulatingSurfaceSegment {
  final String surfaceId;
  final String technicalDefinitionHash;
  final String? materialGroupRef;
  final String? ctiEvidenceRef;
  final String geometryFingerprint;
}

final class Elv6CreepagePathMeasurement {
  final String fromRegionId;
  final String toRegionId;
  final List<String> traversedSurfaceIds;
  final int pathLengthUm;
  final String pathAlgorithmVersion;
  final String captureFingerprint;
}
```

If no deterministic surface path can be constructed from the available geometry, the result is `UNRESOLVED`; ELV6 must not substitute straight-line distance.

## 7. Accessible hazardous-part and barrier evidence

Downstream electric-shock rules need more than a cabinet AABB.

```dart
enum Elv6AccessState {
  normalOperation,
  doorOpen,
  coverRemovedByTool,
  maintenance,
}

final class Elv6BarrierEvidence {
  final String barrierId;
  final Elv6Aabb3 envelope;
  final String barrierDefinitionHash;
  final bool requiresToolToRemove;
  final List<Elv6AccessState> presentInStates;
}

final class Elv6HazardAccessEvidence {
  final String hazardousRegionId;
  final Elv6AccessState accessState;
  final bool geometricallyExposed;
  final List<String> blockingBarrierIds;
  final int? nearestAccessDistanceUm;
}
```

No `finger-safe`, `touch-safe`, basic-protection or similar compliance label is produced by ELV6. It exports exact access/barrier evidence.

## 8. Partition and form-of-separation evidence

```dart
final class Elv6Partition {
  final String id;
  final String hostId;
  final Elv6Aabb3 envelope;
  final String materialDefinitionHash;
  final List<String> separatedRegionIds;
  final String provenanceHash;
}

final class Elv6SeparationProjection {
  final List<Elv6Partition> partitions;
  final Map<String, List<String>> regionAdjacency;
  final String geometryFingerprint;
}
```

ELV6 captures physical separation. ELV7 decides whether a required form of internal separation or another normative arrangement is satisfied.

## 9. Environment and insulation context

The downstream ruleset needs explicit context, not global app defaults:

```dart
final class Elv6SafetyEnvironmentContext {
  final String contextId;
  final int? altitudeMm;
  final String? pollutionContextRef;
  final String? indoorOutdoorRef;
  final String? ambientProfileRef;
  final String? corrosionEnvironmentRef;
  final String? installationAccessClassRef;
  final String sourceFingerprint;
}
```

ELV6 stores/passes the context reference and provenance. ELV7 resolves normative categories and thresholds.

## 10. Mechanical/environmental capability provenance

For racks/enclosures ELV6 must retain adopted technical-definition capabilities rather than infer them from names:

```text
static load capability
rack/cabinet mechanical profile
material definition
environmental classification refs
hinge/door capabilities
mounting support definition
impact/IP test declaration refs when supplied by manufacturer/upstream
edition / variant / technical-definition hash
```

Changing the adopted technical definition invalidates every dependent layout/safety projection.

## 11. Discipline-specific safety projections

### LAN/ICT

Capture physical patch/termination positions, rack profile, media/interface identity, remote-power context, bundle/duct basis, observed segregation and bonding refs. No PoE thermal or separation rule is guessed by ELV6.

### CCTV

Capture equipment/PSU/network termination positions, service access, ventilation/heat facts, environmental enclosure refs and exact power/network subject identities.

### ACS

Capture controller/PSU/battery positions, physical terminations, service/access, enclosure integrity and bonding evidence.

### FIRE

Capture fire controller/PSU/battery physical positions, terminal identities, cable-end assignments, service/removal access, thermal facts, enclosure integrity and any project-required separation geometry. Fire-system functional compliance remains downstream.

## 12. Standards/profile provenance

ELV6 stores no mutable global `currentStandard` string. ELV7 profiles must bind applicability to an immutable profile identity:

```dart
final class ElvNormativeProfileRef {
  final String profileId;
  final String jurisdiction;
  final String profileVersion;
  final String standardsRegistryFingerprint;
  final String effectiveDecisionHash;
}
```

The KZ profile must distinguish at minimum:

```text
CURRENT_NATIONAL
ADOPTED_NOT_YET_INTRODUCED
WITHDRAWN
INTERNATIONAL_REFERENCE_ONLY
PROJECT_EXPLICIT_OVERRIDE
```

A newer IEC/GOST edition discovered online is not automatically effective for a Kazakhstan project.

## 13. Invalidation matrix

At minimum:

```text
host geometry change          -> containment/collision + clearance + access + integrity
placement move                -> collision + clearance + access + segregation + thermal distribution
technical definition change   -> body/service/mass/heat + capability + insulation/material evidence
door/cover change             -> sweep + access + integrity
cutout/gland/vent change      -> entry + airflow + enclosure integrity
partition change              -> collision + thermal + separation + creepage context
bond point/link change        -> bonding evidence
circuit/potential mapping     -> clearance/creepage/access evidence
safety environment context    -> downstream profile results stale; physical measurements remain immutable
```

The invalidation set is server-derived. The client cannot submit trusted dependency closure.

## 14. Freeze/create-next

The ELV6 snapshot section must include hashes for:

```text
layout canonical state
LAY evaluation set/current pointers
normative evidence projections
technical-definition references
safety environment context refs
standards-registry/profile refs used only as provenance
```

Historical replay must reconstruct the evidence available at the frozen revision. A later standard/profile version may re-evaluate old immutable ELV6 evidence in ELV7, but it may not mutate the old ELV6 snapshot.

## 15. Qualification requirements

P8/P9 qualification must include at least:

```text
one-micrometre clearance change updates measured distance deterministically
straight-line distance is not accepted as creepage when a surface path is required
placement move invalidates affected safety projections only
cutout/gland mutation changes enclosure-integrity fingerprint
unused opening without closure remains explicit
manual payload cannot assert IP/IK or compliance class
door-open state changes hazardous-access evidence without changing closed-state evidence
partition removal invalidates separation/thermal/clearance dependencies atomically
bond-link removal remains visible to downstream rules
national profile can pin current KZ edition while newer not-yet-effective edition exists
freeze/reopen yields byte-stable evidence hashes
create-next remaps logical identity without changing frozen evidence
stale writer cannot publish normative evidence over newer generation
fault after evidence insert but before pointer/ledger commits no partial publication
```

## 16. Readiness verdict

Before this contract, ELV6 was strong on constructability but only **partially normatively ready**. The largest missing evidence areas were insulation coordination, accessible hazardous parts and enclosure-integrity/modification provenance.

Runtime implementation must not claim P0 READY until these evidence ownership questions are resolved against actual existing domain/persistence writers. Runtime acceptance must not claim ELV6 complete merely because all 24 LAY calculations pass if the mandatory safety projections required by the selected target profiles cannot be reproduced.
