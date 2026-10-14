# ELV2-P6 — explicit adoption acceptance audit

Status: **GREEN / READY FOR EXACT-SHA GATE**

Branch: `feat/flutter-elv2-profile-constraints`

P5 exact gate: `c964be40b25fa2fa7d0f3657508d0f05ae9e88ce`.

## Scope audited

P6 converts the read-only P5 revision impact preview into an explicit engineer-approved catalog-edition adoption. It remains ELV2-only and does not create cable routes, pathways or other ELV3 objects.

## Acceptance matrix

| Area | Evidence | Result |
| --- | --- | --- |
| Exact candidate edition | Command pins `candidateCatalogId + candidateCatalogVersion`; repository re-reads that exact row and verifies payload provenance | GREEN |
| No silent latest | A later imported v3 does not replace a reviewed/adopted v2; retry replays the stored v2 result | GREEN |
| Stale binding review | Canonical frozen-binding fingerprint is re-read and compared before mutation | GREEN |
| Stale graph review | P5 freezes a deterministic payload-sensitive graph fingerprint over relevant connections, groups and internal mappings | GREEN |
| P2 revalidation | Candidate profile is publication-valid, nondeprecated and commit-time placement-compatible with frozen P4 evidence | GREEN |
| System discipline | Active membership and exact family discipline are revalidated | GREEN |
| Port migration | Planner supports preserve/add/retire/explicit-remap only; no positional or guessed rewiring | GREEN |
| Live dependency guard | Removed/remapped ports with external/internal/group dependencies block adoption unless explicitly safe | GREEN |
| Persisted connection safety | Candidate full port set is evaluated against existing exact connection profiles; connector/protocol/interface/voltage incompatibility blocks adoption | GREEN |
| Atomicity | Ports, frozen binding and durable adoption result are written in one Drift transaction | GREEN |
| Rollback | Injected failures after review, port update/insert/retire, binding replacement, operation completion and before commit restore the complete pre-adoption state | GREEN |
| Idempotency | Namespaced durable `adopt:<operationId>` ledger returns the same result for the same command and rejects semantic reuse | GREEN |
| Restart | Adoption ledger, binding, port identities and candidate provenance survive SQLite close/reopen | GREEN |
| Four disciplines | CCTV CAMERA, LAN OUTLET, ACS READER and FIRE DETECTOR adopt exact candidate editions and survive restart | GREEN |
| Schema | P6 reuses schema-17 durable operation ledger; no additional persistence table is required | GREEN |
| ELV3 boundary | No cable/pathway/route mutation is introduced | GREEN |

## Durable mutation boundary

```text
reviewed P5 impact
      ↓
exact adoption command
      ↓
re-read binding + exact candidate + reviewed graph
      ↓
P2 + discipline + dependency + topology compatibility
      ↓
BEGIN TRANSACTION
      ↓
preserve/update ports
add exact candidate ports
retire safe obsolete ports
replace frozen binding snapshot
assert aggregate postconditions
persist namespaced adoption result
      ↓
COMMIT
```

Any blocker or injected failure produces zero partial adoption state.

## Identity and provenance policy

- component identity is unchanged;
- preserved ports keep their durable IDs;
- new candidate templates receive new IDs;
- removed ports are retired, not silently repurposed;
- explicit remapping is one-to-one and engineer-supplied;
- exact interface/protocol/template provenance comes from the selected candidate catalog edition;
- the binding snapshot is replaced only after all compatibility checks pass;
- no code path resolves “latest” at commit time.

## Targeted verification

The P6 targeted verification passed analyzer and planner/preview/SQLite adoption suites, including rollback and four-discipline restart acceptance.

Connected-port safety was separately verified using a real persisted CCTV connection: adopting a candidate port whose exact catalog-v2 connector/protocol/interface provenance no longer matches the persisted catalog-v1 compatibility profile is rejected as `graphIncompatible`, without changing the connection or component aggregate.

## Gate requirement

P6 is marked COMPLETE only when the normal push and pull-request `Flutter Local Foundation` workflows both pass on the same exact branch SHA after this audit commit.
