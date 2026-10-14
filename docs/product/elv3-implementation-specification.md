# Electra — ELV3 Implementation Specification P1–P9

Status: SUPERSEDED — DO NOT IMPLEMENT FROM THIS FILE  
Branch: `feat/flutter-elv3-physical-routing-design`

This first implementation specification was intentionally retained as historical evidence of the pre-hardening design. An adversarial review found implementation ambiguities in CableDefinition reference binding, route evolution strategy, design revision identity, CableAllocation lifecycle, multi-cable transition semantics, PathwayContext hosting and technical compatibility profile ownership.

The authoritative implementation specification is now:

`docs/product/elv3-implementation-specification-v2.md`

Required supporting contracts:

- `docs/product/elv3-pre-p1-final-hardening.md`
- `docs/adr/ADR-029-elv3-reusable-route-traversal.md`
- `docs/adr/ADR-030-project-design-revision-identity.md`
- `docs/product/elv3-p0-system-architecture-remediation.md`

No implementation decision may rely on wording from the superseded version where it differs from v2 or the final hardening contract.
