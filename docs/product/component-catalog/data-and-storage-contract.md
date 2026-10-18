# Component catalogue: data and storage contract

Status: DESIGN PROPOSAL. All table/API names below are proposed; no mobile
migration or production database is created by this specification.

## 1. Existing baseline and one owner

Reuse `ManufacturerCatalog`, `ManufacturerProductVariant`,
`FunctionalDeviceRequirement`, `ManufacturerProductMatcher`, their codecs,
`ManufacturerRepository` and ELV2 component/technical definition identities.
The current manufacturer matcher version is `fl14-strict-product-match-v1`.
Its doubles, generic `breakingCapacityKa`, integer module widths and free-form
trip labels are legacy representations, not a sufficient future safety envelope.
Preserve old decoders/results. Rich assessment uses versioned adapters and the
ELV7 typed product/standard/operating-condition evidence; do not silently alter
FL14 ranking or treat a successful FL14 match as full ELV6/ELV7 qualification.

Existing `ManufacturerCatalogs`, `ManufacturerProducts`, `ManufacturerPolicies`
and `CircuitProductSelections` live in `AppDatabase` (schema 24 at this audit).
Product IDs are edition-local: current imports forbid reusing an ID across
catalogue versions. Keep those IDs and immutable selection snapshots readable.
New stable product identity is an explicit alias relation, never a reinterpretation
of an old edition ID as a stable model ID. Projects cannot join by SKU or name.

## 2. Separate physical database without a second identity system

`electra-catalog.db` is a local SQLite catalogue store. It contains reusable
technical editions, typed dictionary editions, source evidence, compatibility
records and separately versioned offer books. It contains no project geometry,
CURRENT validation, command receipts or project selection writer.

The existing project runtime database owns adopted technical/offer snapshots,
selection proposals/results, reviewed selections, dependency generations,
revision history and freeze. Use the accepted shared UoW/ledger services.

Catalogue-local FK constraints protect local data. Cross-database FK/atomicity
is not assumed, including through SQLite ATTACH. No transaction spanning two
WAL files is part of the correctness contract. Publication is catalogue-local;
project adoption is a later independently atomic command:

1. Read one consistent published catalogue/offer-book manifest, bounded by hash.
2. Capture every selected edition and dependency into an immutable read DTO.
3. Verify hashes, canonical numeric versions, schemas and source/trust snapshot.
4. In one project UoW, recheck replay and expected revision/generations, copy the
   complete adoption closure, append evidence/dependencies, update pointers and
   write the command result. A crash leaves no partial project adoption.
5. Future project reads/freeze/replay use those project-owned snapshots even if
   the catalogue file is replaced, removed or no longer contains the edition.

Installing a newer catalogue never changes an adopted selection. Known revocation
or an expired proof invalidates a CURRENT claim through a trust dependency; it
never rewrites historical evidence. An importer does not write project tables.

Product source/declaration references do not relocate or duplicate the canonical
ELV7 normative-document/profile/checker registry. The product database may embed
lawfully distributable evidence or exact references; verified interpretation and
normative adoption stay with their existing owner. Project historical snapshots
include the consumed lawful evidence/interpretation closure or an explicit missing
evidence status, never a network-dependent claim of complete replay.

## 3. Relational model and edition identity

| Proposed relation | Required key / content / integrity |
|---|---|
| `catalog_publishers` | Stable publisher ID; namespace and provenance; system/user/organization/import provenance does not itself mean trusted |
| `catalog_manufacturers` | Stable ID, exact aliases; manufacturer code separate from translated display labels |
| `catalog_product_models` | Stable model ID, manufacturer ID, manufacturer product code/variant discriminator; revisions of a product share identity only via reviewed mapping |
| `catalog_product_editions` | Immutable edition ID, model ID, technical schema/hash, functional-role refs, exact product/region/voltage variant, source evidence and canonical version |
| `catalog_definition_bindings` | Edition ID + existing ELV2 definition owner/edition/hash + mapping version; embedded immutable definition closure; never a new physical object owner |
| `catalog_parameter_definitions` | Namespaced key + immutable definition edition; type, dimension, unit semantics, enum scheme, bounds and null policy |
| `catalog_parameter_schemas` | Immutable family schema edition and membership; conditional mandatory fields and checker capability/version |
| `catalog_parameter_values` | Product edition + parameter edition; exactly one typed value or explicit unknown/reason; source/conditions/uncertainty |
| `catalog_compatibility_evidence` | Immutable evidence ID, relation kind, exact edition/setting members, applicability domain, verified source and limits |
| `catalog_releases` / `catalog_release_members` | Immutable technical manifest and exact members/dictionary/definition closure; separate mutable active-release pointer with generation |
| `catalog_offer_books` / `catalog_offer_editions` | Independently published commercial manifest, offer IDs and exact product binding; price/availability facts with time and source |
| `catalog_lifecycle_events` | Append-only source/product/release/trust events and effective/knowledge instants; never destructive retirement |
| `catalog_import_batches` / staged rows | Mutable staging only; input hash, source, parser/schema version, validation report and publish receipt |
| `catalog_search_index` | Rebuildable projections/FTS; never normative source of truth or authoritative parameter owner |

Technical edition hash excludes prices, stock, translated labels and UI metadata.
Offer hash includes the bound technical identity, price basis, validity and terms.
A geometry, TCC, connection diagram, certification or material change creates a
new technical edition; a price/stock change creates a new offer edition.
Use composite UNIQUE constraints on publisher/namespace/edition identity, exact
manufacturer variant identity, release membership and parameter value identity.
Prevent UPDATE/DELETE of published semantic rows through DB guards; stage then
publish atomically. Application/DB validation must agree. Concurrent imports of
the same identity/hash replay; the same identity/different bytes conflicts.

## 4. Typed, extensible parameters

Do not introduce an untyped `properties: Map<String, dynamic>` safety engine.
A namespaced parameter definition can add a field without adding a mobile SQL
column for every vendor attribute. Values are typed and validated against an
immutable family schema. Common searchable fields have indexed projections.

Supported value kinds: EXACT_DECIMAL, RATIONAL_INTERVAL, INTEGER, BOOLEAN,
CLASSIFICATION_REF, ENUM_REF, QUANTITY_VECTOR, EVIDENCE_REF and DEFINITION_REF.
Zero, absent, unknown and not applicable are distinct. Units carry dimensions and
meaning: rms current, peak current and residual current cannot be compared merely
because all can be expressed in amperes. Decimal integers travel as strings with
explicit scale; geometry uses ELV6 signed integer micrometres, mass integer grams.
Exact conversion rejects unsupported precision/overflow, never silently rounds
an electrical safety value or device width. Unit/enum definitions are versioned.

Every value carries source/variant/operating conditions and uncertainty where
relevant. Imported manufacturer data is not automatically VERIFIED_EXTERNAL.
Unknown optional vendor fields are preserved with provenance but cannot participate
in hard matching without a supported typed schema/checker. An unknown mandatory
field blocks eligibility. A new family can be registered as unimplemented; adding
its label is not runtime support. New formula/checker logic needs code qualification.

B/C/D overcurrent curves, residual AC/A/F/B types, fuse classes, SPD test types,
fire classes and room/reliability categories use separate ELV7 namespaces.
Rated interrupting capabilities bind voltage, poles, AC/DC, test standard and
Icn/Icu/Ics semantics. Time-current envelopes and adjustable release settings are
first-class evidence, not one global D threshold or a marketing curve letter.

## 5. Prices and supplier offers

A product has no single mutable `price` field. An offer edition includes:

- supplier technical identity, exact manufacturer variant/edition binding or an
  explicitly reviewed compatibility mapping; supplier SKU alone is insufficient;
- currency/ref edition, integer amount with explicit exponent, base unit and
  price basis EACH / PACK / LENGTH / ASSEMBLY;
- pack contents/unit conversion, MOQ, order increment, quantity price tiers;
- net/gross/unknown tax basis, tax rule reference if used, discount and freight
  conditions, included/excluded ancillary costs;
- region, location basis, stock quantity/unit, lead-time interval and observation
  time; unknown stock is distinct from unlimited stock;
- validity `[from,until)`, source document/hash, import time and verification status.

No actual prices, exchange rates or tax percentages are asserted here. Local
manual price books are supported; online supplier ingestion is a future adapter,
not an ELV8 runtime prerequisite or a procurement/ordering subsystem.

Commercial comparisons pin quantity, currency/FX edition and timestamp, tax and
rounding policy, delivery scope and complete accessory BOM. A material-only total
is labelled as such. Missing price is UNPRICED, not zero or an automatically
comparable total. Expired prices may be shown historically, never as a current
quote. Technical eligibility can remain valid while price/stock validity expires.

Compute order quantity per supplier/offer aggregation: satisfy MOQ and order
increment using the declared unit/pack rules, then apply the correct quantity
tier. Do not round each circuit independently and then add the waste. Report
purchased versus installed quantities, surplus, pack cost and missing cost lines.
Fixed installation BOM and replacement/service/lifecycle costs are separate
objectives with explicit horizons; do not mix them in an unexplained score.

## 6. Import, update and maintenance

Support schema-versioned JSON package import/export first, CSV/XLSX mapping as
staged adapters later. No live scraping inside engineering evaluation. Validate
identity, units, edition hashes, duplicate conflicts, declared dependency closure,
physical facts, price bases and source rights before activation. Reject external
executable expressions. Bound archive size, expansion ratio, row counts, numeric
precision and references; disallow path traversal and remote dependency fetching.
A hash proves byte integrity; trust requires independently approved publisher/
source evidence. A later signed package verifies against an explicit trust store.

Release publication and active-pointer CAS occur in one catalogue transaction;
bad rows/quarantine cannot become a partial active release. Retain an import
report with row-level errors and source mapping. For whole-file updates, validate
a staged copy, close/switch connections under the store coordinator and retain
old release readers until drained. Never replace an open WAL file with a raw copy.
Backups include a coherent SQLite snapshot and a manifest of attachment hashes;
missing source files block only checks requiring them and cannot silently PASS.

Search/filter by role, manufacturer, product code, current, pole arrangement,
curve, dimensions/mounting, region and price/availability. Separate technical,
physical, compatibility and offers tabs; show unknown/source/edition states.
A user can add manual products and new dictionary entries through the same
validation/staging path, without editing an approved global edition.

## 7. Migration and deployment boundary

The catalogue database has its own schema version; allocate AppDatabase migration
numbers only against actual main when implementing. Do not reserve schema 25.
Extract existing immutable catalogue data with a hash/ID/row-count reconciliation
report and a restartable checkpoint. Retain legacy project FK rows as immutable
compatibility anchors until a separately qualified FK migration removes them.
After cutover, the legacy rows are read-only adapters, not a second writable
catalogue. Preserve selected snapshots, archived editions and old decoders.

Do not delete legacy rows or enable the new writer until reopen/restart,
FK integrity, history, unchanged old selection tests and rollback are qualified.
Rollback before cutover restores the old authority; after new semantic writes,
rollback needs an explicit compatible reader/import path, not a blind downgrade.
A future shared server can publish the same immutable packages; no backend,
account, personal data or permanent network connection is required for design.


## 8. Exact source-system facets

[Source-system contract](../elv-integration/source-systems-contract.md) defines
condition-bound generator, PV module, inverter/MPPT, battery/BESS, UPS and tested
transfer-assembly facts. `SOURCE_PV_MODULE` is the 23rd planned product family;
a PV string/array is a project configuration of exact modules/connections, not a
new fake single-SKU product. Preserve output-domain versus input-domain facts,
firmware/settings revisions and separate grid-following/forming/island/black-start
capabilities. No live price, forecast, user-entered "hybrid" label or bidirectional
port can act as source-study/grid-permission evidence. Four qualified electrical
producer projections and all required mode proofs are separate runtime gates.
