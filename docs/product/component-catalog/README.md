# Extensible component catalogue and automatic configuration

Status: **DESIGN PROPOSAL / RUNTIME NOT STARTED / NO REAL PRODUCT OR PRICE DATA**.
Integration proposal maintained on `feat/flutter-elv7-normative-validation-design`;
it does not mark ELV6/ELV7/ELV8 accepted or modify their parallel branches.

The proposal implements the requested boundary: a separate local
`electra-catalog.db` for reusable product editions, technical parameters and
commercial offer books. Project selection snapshots stay in the existing project
runtime database. The catalogue is installable/updateable independently and works
offline; an eventual remote publication service is an optional source adapter.

| Document | Contract |
|---|---|
| [Target platform alignment](target-platform-alignment.md) | All 21 CAP, 14 K and 10 SH targets; ELEC and smart-building boundaries |
| [Data and storage](data-and-storage-contract.md) | Canonical identity, typed extensibility, separate database, sources, import, pricing, migration |
| [Configuration and layout](configuration-and-layout-contract.md) | ELV6 geometry, ELV7 requirements, ELV8 selection, constrained optimization and apply |
| [Machine manifest](design-manifest.json) | Baseline fingerprints, product families, invariants and implementation packages |
| [Acceptance plan](acceptance-plan.json) | Planned database/import/price/configuration/lifecycle scenarios; no executed runtime witnesses |

Existing owners remain authoritative: [ADR-021](../../adr/ADR-021-manufacturer-catalog-mapping.md),
[ADR-025](../../adr/ADR-025-report-bom-estimate-generation.md),
[ADR-026](../../adr/ADR-026-local-only-mobile-first-implementation-phase.md),
[reference catalogues](../elv-reference-data-catalogs.md),
[ELV7 protection contract](../elv7-implementation/protection-and-classification-contract.md).
The exact external ELV6 and ELV8 design candidates are pinned in the manifest;
files inherited on this branch are not the latest authority for those branches.

Run `python3 scripts/ci/check-elv7-design-contract.py` for design consistency only.
Mobile catalogue extraction, schemas/migrations, product ingestion, price feeds,
selection algorithms and application UI remain implementation work. The product
families below are a planned support inventory, not qualified data/checkers.
