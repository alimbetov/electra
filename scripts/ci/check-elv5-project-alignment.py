#!/usr/bin/env python3
"""Validate ELV5 seventh-pass project-wide authority/alignment closure."""
from __future__ import annotations
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
IMPL = ROOT / 'docs/product/elv5-implementation'
AUDIT = ROOT / 'docs/audit/elv5-seventh-pass-project-alignment-audit.json'


def req(ok: bool, msg: str) -> None:
    if not ok:
        raise SystemExit(msg)


def text(path: Path) -> str:
    return path.read_text(encoding='utf-8')


def main() -> None:
    authority = text(ROOT / 'docs/product/elv5-authoritative-spec-index.md')
    typed = text(IMPL / 'typed-process-api.md')
    binding = text(IMPL / 'implementation-binding-hardening-v1.md')
    alignment = text(IMPL / 'project-alignment-hardening-v1.md')
    process_contracts = text(IMPL / 'process-contracts.md')
    acs_dossier = text(IMPL / 'process-specifications/acs-processes.md')
    persistence = text(IMPL / 'persistence-schema-contract.md')
    baseline = text(IMPL / 'implemented-baseline.md')
    adr = text(ROOT / 'docs/adr/ADR-031-elv5-pure-core-and-module-boundary.md')
    roadmap = text(ROOT / 'docs/product/development-roadmap.md')
    versions = json.loads(text(IMPL / 'runtime-version-registry.json'))
    handoff = json.loads(text(IMPL / 'downstream-handoff-registry.json'))
    audit = json.loads(text(AUDIT))

    for token in [
        'project-alignment-hardening-v1.md',
        'implementation-binding-hardening-v1.md',
        'downstream-handoff-registry.json',
        'ADR-031-elv5-pure-core-and-module-boundary.md',
        '1500',
        'seventh-pass',
    ]:
        req(token.lower() in authority.lower(), f'authority index missing project-alignment token: {token}')

    req('Elv5InputResolution<I> resolveInput(' not in typed,
        'typed process definition still owns repository-aware resolveInput')
    req('abstract interface class Elv5InputResolver<I>' in typed,
        'application-layer InputResolver boundary missing')
    req('repository-aware input resolution belongs to the application layer' in binding.lower(),
        'binding hardening does not freeze resolver ownership')
    req('exact filename is not engineering semantics' in binding.lower(),
        'source-layout filename policy not reconciled')

    adr_lower = adr.lower()
    req('adr-031 — elv5 pure-core and module boundary' in adr_lower,
        'ADR-031 identity missing')
    req('repository-aware `resolveinput(...)` is not a method' in adr_lower,
        'ADR-031 resolver ownership missing')
    req('exact source filenames are **tracked implementation coordinates**' in adr_lower,
        'ADR-031 source-layout semantics missing')
    req('packages/engineering_core/lib/src/elv5/' in adr,
        'ADR-031 nested ELV5 bounded-context layout missing')

    stale_oracles = ['23.45 V', '+1.45 V', 'lock23.45V']
    for stale in stale_oracles:
        req(stale not in process_contracts, f'stale ACS-03 oracle remains in process contracts: {stale}')
        req(stale not in acs_dossier, f'stale ACS-03 oracle remains in ACS dossier: {stale}')
    for current in ['23.51 V', '+1.51 V']:
        req(current in acs_dossier, f'corrected ACS-03 dossier oracle missing: {current}')
    req('23.51V' in process_contracts and '+1.51V' in process_contracts,
        'corrected ACS-03 process-contract oracle missing')

    req(versions['databaseSchemaVersion'] == 24, 'runtime version registry must freeze schema 24')
    req('Required ELV5 additive target: **24**' in persistence,
        'persistence schema-24 contract missing')
    req('supersedes earlier baseline wording' in binding,
        'schema-24 precedence sentence missing')
    req('schema 23 → schema 24' in baseline,
        'implemented baseline does not freeze schema 23 -> 24')
    req('Choose an additive migration version strictly greater than 23 from the actual implementation HEAD' not in baseline,
        'obsolete choose->23 migration directive remains active')
    req('arbitrary version greater than 23' in baseline,
        'baseline does not explicitly record superseded provisional schema rule')

    policy = handoff['runtimeEntryPolicy']
    req(policy['exactAcceptedElv5SourceShaRequired'], 'downstream exact ELV5 source SHA not required')
    req(policy['exactAuthorityFingerprintRequired'], 'downstream authority fingerprint not required')
    req(policy['acceptedElv5RuntimeEvidenceRequiredBeforeElv6Runtime'],
        'ELV6 runtime not blocked on accepted ELV5 runtime evidence')
    req(not policy['historicalDesignShaAloneMayAuthorizeRuntime'],
        'historical design SHA incorrectly authorizes downstream runtime')
    req(policy['databaseSchemaAtInitialElv5Entry'] == 24,
        'downstream handoff schema differs from frozen ELV5 schema')
    req(len(handoff['claimBoundaries']) == 3, 'expected ELV6/ELV7/ELV8 claim boundaries')
    req(any(r['branch'] == 'feat/flutter-elv6-enclosure-layout-design' and
            r['state'] == 'RECONCILIATION_REQUIRED_BEFORE_RUNTIME'
            for r in handoff['knownDownstreamDesignPins']),
        'ELV6 stale design pin is not explicitly blocked before runtime')

    req('ELV4 | Power, PoE, PSU, UPS, converters and backup graph | CLOSED / ACCEPTED' in roadmap,
        'development roadmap does not show accepted ELV4')
    req('ELV5 | Versioned CCTV/LAN/ACS/fire calculations | DESIGN HARDENED / RUNTIME NOT STARTED' in roadmap,
        'development roadmap does not show hardened ELV5 design')

    req(audit['counts'] == {'high': 5, 'medium': 5, 'total': 10, 'resolved': 10, 'open': 0},
        'seventh-pass audit count drift')
    req(audit['downstreamActionRequired'] is True,
        'downstream reconciliation requirement was lost')
    req(all(f['status'] in {'SPEC_RESOLVED', 'ELV5_SPEC_RESOLVED_DOWNSTREAM_RECONCILIATION_REQUIRED'}
            for f in audit['findings']),
        'seventh-pass unresolved ELV5 finding')

    for token in [
        'human-readable authority',
        'application layer',
        'schema 24',
        '23.51 v',
        '+1.51 v',
        'reconciliation_required_before_runtime',
    ]:
        req(token in alignment.lower(), f'project alignment hardening missing token: {token}')

    print('ELV5 seventh-pass project alignment PASS')
    print('findings=10 resolved=10 open=0 downstreamReconciliationRequired=1')
    print('acs03=23.51V/+1.51V resolverOwnership=application schema=24 authorityHandoff=exact-fingerprint adr031=verified')


if __name__ == '__main__':
    main()
