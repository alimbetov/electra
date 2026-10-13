# ELV Standards Audit — 2026-10-13

Branch: `docs/elv-engineering-systems-spec`

## Scope

Audit the ELV specification for standards coverage, normative precedence, jurisdiction handling and traceability before implementation.

## Executive result

Status before audit: **PARTIAL**.

The branch already had a strong domain model, discipline-specific reference catalogs and calculation-process architecture, but it lacked a canonical normative-profile model and did not explicitly separate Kazakhstan mandatory/national requirements from IEC/ISO, EN and North American profiles.

Status after this audit: **BASELINE ESTABLISHED / NOT YET LEGALLY COMPLETE**.

A new normative standards matrix now defines:

- jurisdiction profiles;
- precedence rules;
- Kazakhstan baseline;
- IEC/ISO international baseline;
- optional European and North American profiles;
- standards lifecycle and versioning;
- rule provenance;
- discipline-to-standard bindings;
- standards-driven validation/calculation metadata;
- standards regression-test requirements.

## Findings

### A-01 — No explicit jurisdictional precedence

Severity: HIGH

Previous design mentioned normative profiles but did not define which rule wins when national, IEC/ISO, EN, manufacturer and project rules differ.

Resolution: introduced deterministic precedence in `elv-normative-standards-matrix.md`.

### A-02 — Kazakhstan baseline not explicit

Severity: HIGH

The project needs a first-class Kazakhstan profile rather than assuming generic IEC rules are sufficient.

Resolution: introduced `KZ-ELV-BASELINE` with national mandatory rules at higher precedence and international standards as controlled supplements.

### A-03 — Standards were not edition-aware

Severity: HIGH

A standard code without edition/effective dates is unsafe for reproducible engineering calculations.

Resolution: standard references now require edition, status, effective dates, supersession links and project snapshot binding.

### A-04 — Structured cabling coverage incomplete

Severity: MEDIUM

Added explicit ISO/IEC 11801 and ISO/IEC 14763 families, national Kazakhstan adoption, IEEE 802.3 linkage and test/acceptance profile requirements.

### A-05 — CCTV national requirements missing

Severity: HIGH for Kazakhstan projects

Added `СТ РК 4031-2026` as a Kazakhstan CCTV baseline reference and IEC 62676 family for system/application requirements.

### A-06 — Fire-alarm precedence insufficiently strict

Severity: CRITICAL

Fire design cannot be driven by generic international rules alone. Kazakhstan mandatory fire regulations and construction norms must take precedence.

Resolution: explicit precedence and dedicated fire normative profile requirements were added. ISO 7240 is a supplement/baseline, not an automatic replacement for local mandatory rules.

### A-07 — Access-control standards family not explicit

Severity: MEDIUM

Added IEC 60839-11 family and separation from intrusion/hold-up standards (IEC 62642).

### A-08 — Power/EMC/earthing integration incomplete

Severity: HIGH

ELV reliability and safety require explicit linkage to LV installation, EMC, bonding and lightning/surge standards.

Resolution: added IEC 60364, IEC 61000, IEC 62305 and IEC 62368-1 families plus national adoption precedence.

### A-09 — Cable pathway standards missing

Severity: MEDIUM

Added IEC 61537 family and requirement for normative profiles controlling tray/ladder/duct/conduit/penetration rules.

### A-10 — No anti-conflict rule for EN/TIA/NFPA

Severity: HIGH

Applying all global standards simultaneously would produce contradictory rules.

Resolution: EU and North American standards are separate optional profiles and are never silently mixed into the Kazakhstan default.

### A-11 — Normative provenance incomplete

Severity: HIGH

Every calculation/validation must be explainable to an engineer or auditor.

Resolution: rule provenance now includes standard reference, clause metadata, interpretation, parameters, applicability and version.

### A-12 — Copyright/licensing risk

Severity: HIGH

Standards text is generally copyrighted.

Resolution: Electra stores identifiers, metadata and engineering interpretations/rules; full text is not embedded unless licensed.

## Verified current examples used by the audit

The following external facts were verified against current official or authoritative sources during the audit:

- `СТ РК ISO/IEC 11801-2-2019` is listed as active in the Kazakhstan standards catalogue.
- Kazakhstan approved a national CCTV standard in 2026 with an effective date in 2026; the normative matrix records `СТ РК 4031-2026` and requires release-time registry verification.
- `ISO/IEC 11801-1:2017` remains published and has a 2025 amendment/corrigendum.
- `ISO/IEC 14763-2:2019` is the current published planning/installation edition.
- `IEC 62676-4:2025` is the current edition for VSS application guidelines.
- `ISO 7240-1:2025` is current; `ISO 7240-14:2013` was confirmed current in 2025.
- `IEC 60364-4-44:2024` is current for protection against voltage/electromagnetic disturbances.
- `IEC 61537:2023` is current for cable tray/ladder systems.
- `IEC 62368-1:2023` is current for AV/ICT equipment safety within its scope.

## Remaining gaps before implementation-ready status

The branch is not yet sufficient to claim "compliance with all standards". The following work remains mandatory:

1. Verify the exact current Kazakhstan legal/regulatory register for fire alarm, electrical installation, security/access control and cable fire-performance requirements.
2. Build an official `KZ-ELV-BASELINE` standard register with exact document identifiers, editions, effective dates and legal status.
3. Map each calculation and validation rule to a standard/profile reference.
4. Define conflict-resolution test cases for national vs international rules.
5. Define project upgrade/migration workflow between standard-profile editions.
6. Add acceptance fixtures for CCTV, LAN, ACS and fire alarm under the KZ profile.
7. Add a standards regression matrix so a rule change cannot alter unrelated disciplines.
8. Verify whether additional Kazakhstan national standards issued during 2026 apply to VSS installation/operation and add them as separate references after official publication/effective status is confirmed.
9. Determine licensing strategy for commercial standards and prohibit embedding protected full text without rights.
10. Perform a legal/normative release review whenever the KZ profile is shipped or updated.

## Release gate

Implementation of standards-driven calculation logic may begin only when the specific rule pack being implemented has:

- an approved `NormativeProfile`;
- verified source/edition/status;
- typed reference parameters;
- calculation/validation tests;
- provenance output;
- migration/versioning behavior.

No feature may claim standards compliance merely because its algorithm resembles a known engineering formula.

## Audit conclusion

The architecture is now suitable for a canonical standards-aware ELV platform. The main remaining risk is not domain modeling but **normative curation and legal applicability**. Electra should treat standards as versioned engineering data with jurisdictional precedence, not as constants embedded in source code.
