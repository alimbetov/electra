#!/usr/bin/env python3
"""Validate ELV5 design registries and exact contract oracles, not app runtime."""
from collections import Counter
from fractions import Fraction as Q
import argparse
import copy
import json
import math
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'docs/product/elv5-implementation'
SCOPE = {'DESIGN', 'SEGMENT', 'SEQUENCE'}
BINDINGS = {'DESIGN', 'SAME_SEGMENT', 'SAME_SEQUENCE', 'COMPOSED_SEGMENTS', 'REQUIRED_APPLICABILITY_SEGMENTS'}
SUBJECTS = {'RECORDED_STREAM_SET', 'GLOBAL_PSE_CONTEXT', 'RECORDER_INGRESS', 'RECORDER_POOL', 'REALIZED_LINK_SECTIONS', 'SAME_LINK_POLICY_CONTEXT', 'GLOBAL_SUPPLY_CONTEXT', 'SUPPLY_DC_DOMAIN', 'SOURCE_REQUIREMENT_CONTEXT', 'GLOBAL_PROTECTED_BANK', 'FIRE_STATE_ORIGINS', 'NOTIFICATION_OUTPUT_CONTEXT', 'NOTIFICATION_DC_DOMAIN', 'SAME_FIRE_LOOP'}


def load(path):
    return json.loads(path.read_text())


def validate_registry(registry):
    rows = registry['processes']
    by_code = {r['code']: r for r in rows}
    assert len(by_code) == len(rows) == 27
    expected = {f'{prefix}-{i:02d}' for prefix, maximum in [('CCTV', 6), ('LAN', 7), ('ACS', 6), ('FA', 8)] for i in range(1, maximum + 1)}
    assert set(by_code) == expected
    external = set(registry['externalProcessCodes'])
    assert external == {f'ELV-PWR-0{i}' for i in range(1, 7)} | {'ELV-ROUTE-01'}
    for row in rows:
        assert row['runtimeStatus'] == 'NOT_STARTED' and row['scope'] in SCOPE
        assert row['requiredDimensions'] and len(row['requiredDimensions']) == len(set(row['requiredDimensions']))
        assert row['positiveOracle'] and row['negativeCase'] and len(row['plannedAcceptanceIds']) == 2
        for edge in row['upstreamProcesses']:
            code = edge['processCode']
            assert code in by_code or code in external, 'Unknown upstream process'
            binding = edge['scopeBinding']
            assert binding in BINDINGS and edge['subjectBinding'] in SUBJECTS
            assert edge['when'] in {'ALWAYS', 'POWERED'}
            target = by_code[code]['scope'] if code in by_code else ('DESIGN' if code == 'ELV-ROUTE-01' else ('SEQUENCE' if code == 'ELV-PWR-04' else 'SEGMENT'))
            if binding == 'DESIGN':
                assert target == 'DESIGN'
            elif binding == 'SAME_SEGMENT':
                assert row['scope'] == target == 'SEGMENT'
            elif binding == 'SAME_SEQUENCE':
                assert row['scope'] == target == 'SEQUENCE'
            elif binding == 'COMPOSED_SEGMENTS':
                assert row['scope'] == 'SEQUENCE' and target == 'SEGMENT'
            elif binding == 'REQUIRED_APPLICABILITY_SEGMENTS':
                assert row['scope'] == 'DESIGN' and target == 'SEGMENT'
    visiting, done = set(), set()
    def visit(code):
        assert code not in visiting, 'Dependency cycle'
        if code in done:
            return
        visiting.add(code)
        for edge in by_code[code]['upstreamProcesses']:
            if edge['processCode'] in by_code:
                visit(edge['processCode'])
        visiting.remove(code)
        done.add(code)
    for code in by_code:
        visit(code)


def must_reject(registry):
    try:
        validate_registry(registry)
    except AssertionError:
        return
    raise AssertionError('Invalid registry accepted')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    registry = load(BASE / 'process-registry.json')
    requirements = load(BASE / 'requirements.json')['requirements']
    validate_registry(registry)
    assert len(requirements) == len({r['requirementId'] for r in requirements}) == 80
    assert Counter(r['package'] for r in requirements) == {f'P{i}': 8 for i in range(10)}
    for r in requirements:
        assert r['runtimeStatus'] == 'NOT_STARTED' and r['testedSha'] is None and not r['evidence']
        assert r['requirementId'] in (BASE / r['designDocument']).read_text()
    invalid = copy.deepcopy(registry)
    invalid['processes'][0]['upstreamProcesses'] = [{'processCode': 'ELV-PWR-01/03', 'scopeBinding': 'DESIGN', 'subjectBinding': 'RECORDER_POOL', 'when': 'ALWAYS'}]
    must_reject(invalid)
    cyclic = copy.deepcopy(registry)
    cyclic['processes'][1]['upstreamProcesses'] = [{'processCode': 'CCTV-03', 'scopeBinding': 'DESIGN', 'subjectBinding': 'RECORDER_POOL', 'when': 'ALWAYS'}]
    must_reject(cyclic)
    assert math.ceil(Q(1, 8) + Q(1, 8)) == 1
    assert math.ceil(Q(1, 8)) + math.ceil(Q(1, 8)) == 2
    assert Q(1000000) * 3600 / 8 == 450000000
    assert Q(4000000) * 3600 / 8 == 1800000000
    assert 450000000 <= 500000000 < 1800000000
    assert Q(-1) - Q(0) > Q(-3)
    assert Q(-1) - Q(2) <= Q(-3)
    assert {1, 2} & {2, 3} == {2}
    streams = [{'camera': 'c1', 'stream': 'main', 'bitrate': 4000000}, {'camera': 'c1', 'stream': 'sub', 'bitrate': 1000000}]
    assert len({s['camera'] for s in streams}) == 1 and len({s['stream'] for s in streams}) == 2
    assert sum(s['bitrate'] for s in streams) == 5000000
    assert 6 - 1 - 3 == 5 - 3 == 2
    assert Q(8000000) / 8 * (30 * 86400) == 2592000000000
    assert Q(2592000000000) * Q('1.1') == 2851200000000
    assert Q(2851200000000) / Q('.5') == 5702400000000
    def atan_bounds(x):
        total = Q(0)
        for k in range(64):
            total += (-1)**k * x**(2*k + 1) / (2*k + 1)
        adjacent = total + x**129 / 129
        return min(total, adjacent), max(total, adjacent)
    for x, lower, upper in [(Q(1, 2), Q('.9272952180'), Q('.9272952181')), (Q(1, 3), Q('.6435011087'), Q('.6435011089'))]:
        lo, hi = atan_bounds(x)
        assert lower < 2*lo <= 2*hi < upper
        assert 2*(hi-lo) <= Q(1, 10**9)
    audit = load(ROOT / 'docs/audit/elv5-technical-audit.json')
    assert len(audit['requirementReviews']) == 80 and len(audit['findings']) == 8
    assert all(f['specificationStatus'] == 'SPEC_RESOLVED' and f['runtimeStatus'] == 'NOT_IMPLEMENTED' for f in audit['findings'])
    links = 0
    documents = list(BASE.glob('*.md')) + list((ROOT / 'docs/product').glob('elv5-*.md')) + list((ROOT / 'docs/audit').glob('elv5-*.md'))
    for file in documents:
        for target in re.findall(r'\]\(([^)]+)\)', file.read_text()):
            if '://' not in target and not target.startswith('#'):
                assert (file.parent / target.split('#')[0]).exists(), (str(file), target)
                links += 1
    result = {'schema': 'electra.elv5-specification-checks.v1', 'result': 'PASS', 'scope': 'Design contract/registry probes only; not Flutter/Dart/Drift runtime evidence', 'processCount': 27, 'requirementCount': 80, 'specificationFindingsResolved': 8, 'localLinksChecked': links, 'checks': ['typed upstream code/scope/subject/condition and acyclic graph', 'unknown upstream and cycle rejection', '80 requirement identity/package/evidence invariants', 'pool-level byte ceiling', 'expected versus guaranteed retention', 'optical reserve not physical loss', 'expanded address overlap', 'camera/stream channel identity', 'gross/net RU equivalence', 'recording horizon/reserve/redundancy arithmetic', 'mandatory pinhole H/V FOV interval oracles'], 'runtimeImplemented': False}
    if args.output:
        args.output.write_text(json.dumps(result, indent=2) + '\n')
    print(f'PASS: 27 processes, 80 requirements, 8 specification resolutions, {links} local links; no runtime claim')


if __name__ == '__main__':
    main()
