#!/usr/bin/env python3
"""Validate ELV6 normative safety evidence design. This is not runtime compliance evidence."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'docs/product/elv6-implementation'
REGISTRY = BASE / 'safety-standards-registry.json'
MATRIX = BASE / 'safety-domain-readiness-matrix.json'
CONTRACT = BASE / 'normative-safety-evidence-contract.md'

REQUIRED_PROFILES = {
    'IEC_BASELINE',
    'KZ_NATIONAL',
    'EU_CENELEC',
    'MACHINE_CONTROL_OPTIONAL',
    'DISCIPLINE_CCTV',
    'DISCIPLINE_LAN_ICT',
    'DISCIPLINE_ACS',
    'DISCIPLINE_FIRE',
}

REQUIRED_STANDARD_IDS = {
    'IEC-61439-1-2020',
    'IEC-61439-2-2020',
    'IEC-62208-2023',
    'KZ-GOST-32127-2013-IEC-62208-2002',
    'IEC-60529-1989-A1-1999-A2-2013',
    'KZ-ST-RK-IEC-60529-2012',
    'IEC-62262',
    'KZ-ST-RK-IEC-62262-2012',
    'IEC-60664-1-2020-A1-2025',
    'IEC-60364-4-41-2005-A1-2017',
    'IEC-60364-5-54-2011-A1-2021',
    'KZ-ST-RK-IEC-60364-5-54-2012',
    'IEC-TR-60890-2022',
    'IEC-60297-3-100-2008',
    'KZ-ST-RK-IEC-60297-3-100-2018',
    'IEC-61587-1-2022',
    'IEC-60204-1-2016-A1-2021',
    'ISO-IEC-11801-1-2017-A1-2025',
    'EN-50174-2-2018',
    'IEC-62676-1-1-2013',
    'IEC-60839-11-2-2014',
}

REQUIRED_DOMAINS = {
    'LV_ASSEMBLY',
    'INSULATION_COORDINATION',
    'ENCLOSURE_IP_IK',
    'ELECTRIC_SHOCK_AND_BONDING',
    'PROTECTIVE_DEVICES',
    'THERMAL',
    'RACK_MECHANICAL',
    'ICT_LAN',
    'CCTV',
    'ACS',
    'FIRE',
}

REQUIRED_GAPS = {
    'NRG-01 enclosure integrity/modification evidence for IP profile',
    'NRG-02 clearance and creepage measurement projection',
    'NRG-03 accessible hazardous-part/barrier evidence',
    'NRG-04 partition/form-of-separation geometry and identity',
    'NRG-05 insulation/material/environment context needed by downstream rules',
    'NRG-06 explicit enclosure/rack environmental and mechanical capability provenance',
    'NRG-07 versioned national/profile applicability registry with effective-status pinning',
    'NRG-08 freeze/replay provenance for all normative evidence projections',
}


def validate_registry(registry):
    assert registry['schema'] == 'electra.elv6-safety-standards-registry.v1'
    assert registry['status'] == 'DESIGN_NORMATIVE_READINESS'
    assert registry['owner'] == 'ELV6_DESIGN_ELV7_RULES'
    assert set(registry['jurisdictionProfiles']) == REQUIRED_PROFILES

    rows = registry['standards']
    ids = [row['id'] for row in rows]
    assert len(ids) == len(set(ids)), 'duplicate safety standard ID'
    assert REQUIRED_STANDARD_IDS <= set(ids), ('missing safety standards', sorted(REQUIRED_STANDARD_IDS - set(ids)))

    for row in rows:
        assert row['title']
        assert row['authority']
        assert row['profiles']
        assert set(row['profiles']) <= REQUIRED_PROFILES
        assert row['applicability']
        assert row['elv6Evidence']
        assert isinstance(row['elv7Owner'], bool)
        assert row['elv6Gap']

    assert set(registry['mandatoryReadinessGaps']) == REQUIRED_GAPS

    notes = '\n'.join(registry['kazakhstanStatusNotes'])
    assert '61439-1-2013' in notes and '61439-2-2015' in notes
    assert '61439-1-2024' in notes and 'not yet introduced' in notes
    assert 'ST RK IEC 60529-2012' in notes
    assert 'ST RK IEC 62262-2012' in notes
    assert 'ST RK IEC 60364-5-54-2012' in notes
    assert 'ST RK IEC 60297-3-100-2018' in notes

    return len(rows)


def validate_domain_matrix(matrix):
    assert matrix['schema'] == 'electra.elv6-safety-domain-readiness-matrix.v1'
    assert matrix['status'] == 'DESIGN_HARDENING'
    assert matrix['branch'] == 'feat/flutter-elv6-enclosure-layout-design'

    rows = matrix['domains']
    by_id = {row['id']: row for row in rows}
    assert len(rows) == len(by_id) == len(REQUIRED_DOMAINS)
    assert set(by_id) == REQUIRED_DOMAINS

    for row in rows:
        assert row['standards'], ('missing standards', row['id'])
        assert row['elv6Evidence'], ('missing ELV6 evidence', row['id'])
        assert row['runtimeOwner']
        assert row['verdictOwner']
        assert row['readiness']

    protective = by_id['PROTECTIVE_DEVICES']
    assert 'B/C/D' in protective['hardBoundary']
    assert protective['runtimeOwner'] == 'ELV4_SELECTION_ELV6_PLACEMENT'
    assert any('IEC 60898-1' in item for item in protective['standards'])
    assert any('IEC 61008-1' in item for item in protective['standards'])
    assert any('IEC 61009-1' in item for item in protective['standards'])

    assert 'IEC 60839-11-1:2013' in by_id['ACS']['standards']
    assert any('EN 54-4' in item for item in by_id['FIRE']['standards'])
    assert any('EN 54-13' in item for item in by_id['FIRE']['standards'])

    kz = matrix['kazakhstanPinnedStatus']
    for key in [
        'GOST IEC 61439-1-2013',
        'GOST IEC 61439-2-2015',
        'ST RK IEC 60529-2012',
        'ST RK IEC 62262-2012',
        'ST RK IEC 60364-5-54-2012',
        'ST RK IEC 60297-3-100-2018',
    ]:
        assert key in kz

    assert len(matrix['runtimeEntryBlockers']) == 9
    return len(rows)


def validate_contract(contract):
    for forbidden in ['ELV6 is compliant', 'ELV6_COMPLIANT', 'auto-upgrade national standard']:
        assert forbidden not in contract

    for token in [
        'ELV6 captures exact physical evidence; ELV7 decides jurisdictional applicability and compliance',
        'Elv6EnclosureIntegrityEvidence',
        'Elv6AirClearanceMeasurement',
        'Elv6CreepagePathMeasurement',
        'Elv6HazardAccessEvidence',
        'Elv6Partition',
        'Elv6SafetyEnvironmentContext',
        'CURRENT_NATIONAL',
        'ADOPTED_NOT_YET_INTRODUCED',
        'freeze/reopen yields byte-stable evidence hashes',
    ]:
        assert token in contract, ('missing normative safety contract token', token)


def main():
    registry = json.loads(REGISTRY.read_text())
    matrix = json.loads(MATRIX.read_text())
    contract = CONTRACT.read_text()

    standard_count = validate_registry(registry)
    domain_count = validate_domain_matrix(matrix)
    validate_contract(contract)

    print(
        f'PASS: ELV6 safety readiness registry {standard_count} standards, '
        f'{domain_count} safety domains, {len(REQUIRED_PROFILES)} profiles, '
        f'{len(REQUIRED_GAPS)} mandatory evidence gaps; design-only guard'
    )


if __name__ == '__main__':
    main()
