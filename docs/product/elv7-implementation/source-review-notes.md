# ELV7 — Primary-source discovery and review notes

Reviewed for design on 2026-10-18. No licensed full standards text was acquired.
These are discovery records, **not VERIFIED_EXTERNAL executable rule packs**.
Official metadata proves a publication exists; it does not establish a national
adoption, clause interpretation, complete TCC envelope or product certification.

| Source | Observation used in design | Release limitation |
|---|---|---|
| [IEC 60898-1 consolidated publisher page](https://webstore.iec.ch/en/publication/66269) | Identifies 2015 + amendment 2019 consolidated AC household/similar-use scope, with incorporated corrigenda metadata | Full applicable clauses, conditions and national adoption need review; do not copy it to all industrial/DC breakers |
| [IEC 60947-2:2024 publisher page](https://webstore.iec.ch/en/publication/66277) | Separate product-standard scope for circuit breakers | Icu/Ics and release settings require exact adopted device/standard evidence |
| [Schneider Acti9 FAQ FA290880](https://www.se.com/au/en/faqs/FA290880/) | Family-specific B/C/D explanation; D magnetic range described as 10–14 × In | Product-family guidance, not a universal D envelope or KZ legal rule |
| [ABB technical catalogue](https://library.e.abb.com/public/e8cda48862fb424898627405b0276986/B_ELSB_Catalogue-Technical_2024_1st_Edition.pdf) | AC C/D characteristic diagrams include a D 10–20 × In band with operating-condition context | Complete product/edition/condition matching and source interpretation still required |
| [IEC 62423:2009 publisher page](https://webstore.iec.ch/en/publication/6998) | Residual protection Types F/B are a different classification from MCB trip curves; companion-standard context is explicit | Not a complete residual-protection design or national rule pack |
| [IEC 60364-4-41 publisher page](https://webstore.iec.ch/en/publication/1867) | Installation electric-shock protection family, including external-influence coordination | Applicable adopted edition/clauses/time limits require full review |
| [KZ electrical installation rules, official register](https://adilet.zan.kz/rus/docs/V1500010851) and [official history](https://old.adilet.zan.kz/rus/docs/V1500010851/history) | National legal-source identity and amendment history must be distinct from international publisher editions | Direct page retrieval was incomplete; no current consolidated clause approval or numeric limit is asserted here |
| [EU reaction-to-fire classification source locator](https://eur-lex.europa.eu/eli/reg_del/2016/364/oj/eng) | Candidate locator for optional EU cable classification verification | Automated retrieval hit a browser verification wall; locator only, no text/status/applicability verification claimed |

## Required source approval record

Each release candidate requires source identity, edition/amendments/corrigenda,
national incorporation/effective dates and project transition basis; exact clause
locator; lawful evidence locator/hash where licensed; interpretation and units;
parameter-domain coverage and endpoint semantics; independent numerical fixture
oracles; qualified reviewer/approval authority; checker version and case evidence;
licensing constraints; approval and revocation lifecycle. Hashing a URL or these
notes does not create a hash of the official normative publication.

Where publisher/family data differ, preserve their applicability domains.
Do not blend thresholds, silently choose the more convenient value, or call the
entire standard contradictory merely because two manufacturers implement
different guaranteed envelopes within their own declared contexts.

## Initial source families requiring full P0/P4 review

IEC 60898-1/-2, IEC 60947-2, IEC 61008/61009 and 62423, IEC 60269,
IEC 60364 protection/wiring/earthing/verification families, IEC 61643,
IEC 61439, IEC 62208, IEC 60529/62262, IEC 60664, applicable KZ electrical
and fire regulations, national implementations, ISO/IEC cabling and IEEE PoE,
IEC 62676, IEC 60839 and ISO 7240 families from the existing standards matrix.
This is a discovery inventory, not an assertion of one current edition or
mandatory applicability to every project.
