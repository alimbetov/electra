# ELV7 — Identification, Cabinet Entry & Segregation Normative Amendment

Status: **DESIGN AMENDMENT / SOURCE AUTHORITY REQUIRED / RUNTIME NOT CLAIMED / ACCEPTANCE NOT CLAIMED**

This amendment is normative for future ELV7 runtime entry. It defines the compliance ownership for engineering identification/marking, cabinet cable entry, internal routing and segregation. It does not invent universal numeric rules: every executable normative rule requires verified jurisdiction/profile/edition/applicability evidence.

## 1. Ownership boundary

```text
canonical object identity / topology       -> upstream owners
physical panel layout / entry geometry     -> ELV6
normative applicability / findings         -> ELV7
marker rendering / print / QR deliverable  -> ELV8
fault/disturbance physics                  -> shared electrical study producer
```

ELV7 MUST NOT redefine the cable label, panel geometry or calculated short-circuit result. It evaluates whether a known fact satisfies an applicable verified rule.

## 2. Engineering identification and marking rules

The normative layer SHALL be able to express requirements for subject identification without owning the rendered label.

Supported target subjects include:

- Cable and cable end;
- CableCore/conductor/pair/fiber where applicable;
- Circuit;
- ProtectiveDevice;
- Panel/switchboard/MCC;
- TerminalBlock and Terminal;
- Device/load/field component;
- Port/patch-panel port;
- PLC/remote-I/O channel;
- automation sensor/actuator/channel.

Rule families MAY cover, when supported by verified authority:

```text
IDENTIFICATION_REQUIRED
IDENTIFIER_UNIQUENESS_SCOPE
SOURCE_DESTINATION_MARKING
CORE_CONDUCTOR_IDENTIFICATION
TERMINAL_IDENTIFICATION
PANEL_DEVICE_IDENTIFICATION
WARNING_SAFETY_LABEL
DURABILITY_OR_ENVIRONMENT_CLASS
FIELD_READABILITY
```

The rule result MUST reference the canonical subject identity. ELV7 SHALL NOT create an alternative engineering code.

## 3. Cable-entry and enclosure rule families

ELV7 SHALL support applicability/checking for physical facts supplied by ELV6, including:

```text
ENTRY_SIDE_APPLICABILITY
GLAND_OR_ENTRY_INTERFACE
ENCLOSURE_IP_OR_ENVIRONMENT_REQUIREMENT
CABLE_DIAMETER_ENTRY_COMPATIBILITY
EMC_SHIELD_ENTRY_TERMINATION
PE_BONDING_AT_ENTRY
RESERVED_OR_SEALED_OPENINGS
MINIMUM_BEND_RADIUS
ACCESSIBILITY_MAINTAINABILITY
```

No global rule such as `TOP_ENTRY_REQUIRED` or `BOTTOM_ENTRY_REQUIRED` may be hard-coded unless the selected jurisdiction/project profile explicitly proves such applicability. `TOP`, `BOTTOM`, `LEFT`, `RIGHT`, `MIXED` and `CUSTOM` are design facts, not compliance conclusions.

## 4. Segregation and internal routing

ELV7 SHALL be able to validate typed internal-route evidence against applicable rules for:

- power/control/ELV separation;
- functional/safety circuit separation;
- EMC-sensitive routing where authority exists;
- terminal/group separation;
- PE/N/PEN handling;
- fire/life-safety separation where applicable;
- cable duct/trunk capacity rule boundary where normative rather than physical;
- service/access clearance when normative.

Physical impossibility remains an ELV6 finding. Normative non-compliance is an ELV7 finding. The two MUST NOT be collapsed.

## 5. Evidence and applicability contract

Every executable rule SHALL preserve:

```text
jurisdiction/profile
standard family
edition/version
clause/table/source locator where lawfully available
applicability predicate
input evidence refs
result PASS | FAIL | UNRESOLVED | NOT_APPLICABLE
ruleset fingerprint
effective/transition dates where relevant
```

Missing required authority or input evidence SHALL produce `UNRESOLVED`, never an assumed PASS.

Publisher metadata alone is not sufficient to create numeric or mandatory executable requirements.

## 6. Electrical-study normative consumption

ELV7 MAY consume `ElectricalStudyRef` from `elv-integration/electrical-study-handoff-contract.md` to assess applicable requirements such as:

- breaking capacity relative to qualified fault current;
- trip/clearing requirements where the protection study proves the needed facts;
- voltage disturbance limits where a verified profile applies;
- motor-start voltage-dip acceptance where a verified profile applies;
- source-transfer timing/availability requirements where applicable.

ELV7 MUST NOT recompute short-circuit, motor-start, source-transfer or voltage-disturbance physics internally.

The following claims are separate and MUST remain separate:

```text
FAULT_CURRENT_CALCULATED
BREAKING_CAPACITY_ADEQUATE
TRIP_CONDITION_PROVEN
SELECTIVITY_PROVEN
FAULT_CLEARING_PROVEN
```

One claim MUST NOT imply another without explicit evidence.

## 7. Marking schedule normative projection

ELV7 SHALL expose findings/requirements that ELV8 can project into label/marker schedules, for example:

```text
subjectRef
requiredMarkerClass
requiredContentRole[]
requiredEnvironmentClass?
findingRef
ruleRef
```

ELV7 does not choose printer media, page layout, QR format or vendor template.

## 8. Qualification requirements

Future ELV7 qualification SHALL include at least:

- applicable vs not-applicable profile cases;
- UNKNOWN authority/evidence fail-closed cases;
- top/bottom/mixed cabinet-entry cases proving no universal side assumption;
- physical-fit PASS but normative FAIL separation;
- physical BLOCKED but normative not falsely PASS;
- label identity continuity across subject/finding projection;
- stale study reference invalidation after topology/protection changes;
- exact edition/ruleset replay on frozen revisions.

## 9. Runtime-entry gate

ELV7 runtime implementation for these rule families is blocked until exact rule authority, lawful source handling, applicable KZ/IEC/EU or project profile semantics and independent qualification fixtures are approved. Design completeness does not imply normative acceptance.
