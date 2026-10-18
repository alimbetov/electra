#!/usr/bin/env python3
"""Validate ELV6 design registries/requirements/boundaries. Not runtime evidence."""
from collections import Counter
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
PRODUCT = ROOT / 'docs/product'
BASE = PRODUCT / 'elv6-implementation'
AUDIT = ROOT / 'docs/audit/elv6-hard-technical-audit.md'
AUDIT_ADDENDUM = ROOT / 'docs/audit/elv6-final-architecture-hardening.md'
PINNED_ELV5 = 'ed7db01adb27ff184b0b8c91a710082fb9eafb9a'
OLD_ELV5 = 'a20ae91ecbef1da0d16443201e48f7e1b99e8701'


def load_json(path: Path):
    return json.loads(path.read_text())


def validate_process_registry(registry):
    assert registry['schema'] == 'electra.elv6-layout-process-registry.v1'
    assert registry['status'] == 'DESIGN_DRAFT'
    assert registry['runtimeStatus'] == 'NOT_STARTED'
    assert registry['owner'] == 'ELV6'
    assert registry['pinnedUpstreamElv5Sha'] == PINNED_ELV5
    assert registry['geometryScalar'] == 'SIGNED_INTEGER_MICROMETRE_V1'
    assert registry['occupancyConvention'] == 'HALF_OPEN_V1'

    rows = registry['processes']
    by_code = {row['code']: row for row in rows}
    expected = {f'LAY-{i:02d}' for i in range(1, 25)}
    assert len(rows) == len(by_code) == 24
    assert set(by_code) == expected

    scopes = {'HOST', 'PLACEMENT', 'ENTRY', 'ASSIGNMENT'}
    for row in rows:
        assert row['scope'] in scopes
        assert row['mode']
        assert row['requiredFacts']
        assert row['requiredDimensions']
        assert len(row['requiredFacts']) == len(set(row['requiredFacts']))
        assert len(row['requiredDimensions']) == len(set(row['requiredDimensions']))
        assert row['positiveOracle'] and row['negativeOracle']
        for upstream in row['upstream']:
            assert upstream in by_code, ('unknown ELV6 upstream', row['code'], upstream)

    visiting, done = set(), set()

    def visit(code):
        assert code not in visiting, ('dependency cycle', code)
        if code in done:
            return
        visiting.add(code)
        for upstream in by_code[code]['upstream']:
            visit(upstream)
        visiting.remove(code)
        done.add(code)

    for code in sorted(by_code):
        visit(code)

    assert by_code['LAY-23']['mode'] == 'SOLVER'
    assert by_code['LAY-24']['mode'] == 'AGGREGATE'
    assert 'LAY-23' not in by_code['LAY-24']['upstream'], 'aggregate result must not depend on proposal existence'


def acceptance_id(requirement_id):
    match = re.fullmatch(r'ELV6-P([0-9])-([0-9]{3})', requirement_id)
    assert match
    package = int(match.group(1))
    ordinal = int(match.group(2))
    assert 1 <= ordinal <= 8
    return f'P{package}-T{ordinal:02d}'


def validate_requirements(plan_text):
    ids = re.findall(r'^### (ELV6-P([0-9])-([0-9]{3}))\b', plan_text, flags=re.M)
    full = [row[0] for row in ids]
    assert len(full) == len(set(full)) == 80
    counts = Counter(f'P{row[1]}' for row in ids)
    assert counts == {f'P{i}': 8 for i in range(10)}
    for package in range(10):
        expected = {f'ELV6-P{package}-{i:03d}' for i in range(1, 9)}
        assert expected <= set(full), ('missing package requirements', package, expected - set(full))

    acceptance_clauses = re.findall(r'^Acceptance:\s+(.+)$', plan_text, flags=re.M)
    assert len(acceptance_clauses) == 80, ('every requirement needs one acceptance clause', len(acceptance_clauses))
    derived = {acceptance_id(requirement_id) for requirement_id in full}
    assert len(derived) == 80
    assert derived == {f'P{p}-T{i:02d}' for p in range(10) for i in range(1, 9)}


def validate_boundary_documents():
    index = (PRODUCT / 'elv6-authoritative-spec-index.md').read_text()
    design = (PRODUCT / 'elv6-enclosure-layout-design-specification.md').read_text()
    runtime = (BASE / 'code-level-runtime-contract.md').read_text()
    safety = (BASE / 'mutation-safety-contract.md').read_text()
    plan = (PRODUCT / 'elv6-p0-p9-delivery-plan.md').read_text()
    audit = AUDIT.read_text()
    addendum = AUDIT_ADDENDUM.read_text()
    registry_text = (BASE / 'process-registry.json').read_text()

    combined = '\n'.join([index, design, runtime, safety, plan, registry_text])
    assert PINNED_ELV5 in index and PINNED_ELV5 in design and PINNED_ELV5 in runtime and PINNED_ELV5 in plan
    assert OLD_ELV5 not in '\n'.join([index, design, runtime, safety, plan]), 'ELV6 authoritative docs still pin obsolete ELV5 baseline'

    for token in [
        'SIGNED_INTEGER_MICROMETRE_V1',
        'HALF_OPEN_V1',
        'electra.elv6-layout-command.v1',
        'LAY-01',
        'LAY-24',
        'ELV6_NOT_CAPTURED',
        'capture → pure kernel/projection → guarded publication',
        'SERVER_DERIVED_GEOMETRY',
        'REFERENCED_MEMBER_REMOVAL',
    ]:
        assert token in combined, ('missing hardening token', token)

    assert 'does not reserve schema 24' in design.lower() or 'does not pre-allocate database schema 24' in index.lower()
    assert 'temperature-rise' in design.lower()
    assert 'normative' in design.lower()
    assert 'one active canonical writer' in index.lower()

    audit_ids = re.findall(r'^#{2,3} (ELV6-AUD-[0-9]{2})\b', audit + '\n' + addendum, flags=re.M)
    assert len(audit_ids) == len(set(audit_ids)) == 20
    assert all(f'ELV6-AUD-{i:02d}' in audit_ids for i in range(1, 21))

    validate_requirements(plan)


def validate_repository_baseline():
    db = (ROOT / 'apps/mobile/lib/data/database/app_database.dart').read_text()
    assert 'int get schemaVersion => 23;' in db

    geometry = (ROOT / 'packages/engineering_core/lib/src/geometry.dart').read_text()
    assert 'final class Point2Mm' in geometry and 'final int xMm;' in geometry

    panel = (ROOT / 'packages/engineering_core/lib/src/panel_assembly.dart').read_text()
    for token in ['class PanelAssembly', 'class DinRail', 'class PanelModulePlacement', 'class PanelCableDuct', 'class PanelReservedZone']:
        assert token in panel
    assert 'final double widthMm;' in panel, 'legacy double boundary changed; re-audit ELV6 import contract'


def validate_links():
    documents = [
        PRODUCT / 'elv6-authoritative-spec-index.md',
        PRODUCT / 'elv6-enclosure-layout-design-specification.md',
        PRODUCT / 'elv6-p0-p9-delivery-plan.md',
        BASE / 'README.md',
        BASE / 'code-level-runtime-contract.md',
        BASE / 'mutation-safety-contract.md',
        AUDIT,
        AUDIT_ADDENDUM,
    ]
    checked = 0
    for file in documents:
        text = file.read_text()
        for target in re.findall(r'\]\(([^)]+)\)', text):
            if '://' in target or target.startswith('#'):
                continue
            path = (file.parent / target.split('#')[0]).resolve()
            assert path.exists(), ('broken ELV6 local link', str(file), target)
            checked += 1
    return checked


def main():
    registry = load_json(BASE / 'process-registry.json')
    validate_process_registry(registry)
    validate_boundary_documents()
    validate_repository_baseline()
    links = validate_links()
    print(f'PASS: ELV6 24 processes, 80 P0-P9 requirements/acceptance clauses, 20 audit findings, {links} local links; design-only guard')


if __name__ == '__main__':
    main()
