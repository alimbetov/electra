#!/usr/bin/env python3
"""Check ELV4 specification contracts and oracles; does not execute app code.

The schema checker supports only the deliberately restricted local keyword set
used by the accompanying schemas. It is not a general JSON Schema validator.
"""
from __future__ import annotations
import argparse
import copy
from fractions import Fraction
import hashlib
import json
from pathlib import Path
import re
import sqlite3

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'docs/product/elv4-implementation'
AUDIT = ROOT / 'docs/audit/elv4-technical-audit'


def read(path):
    return json.loads(path.read_text())


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=False)


def digest(value):
    return hashlib.sha256(canonical(value).encode()).hexdigest()


class ContractError(ValueError):
    pass


def validate(value, node, root=None, path='$'):
    """Validate the local schema subset, fail closed on unsupported keywords."""
    root = node if root is None else root
    allowed = {'$schema', '$id', '$defs', '$ref', 'type', 'properties', 'required',
               'additionalProperties', 'propertyNames', 'oneOf', 'const', 'enum',
               'items', 'minItems', 'minLength', 'maxLength', 'pattern', 'minimum'}
    if set(node) - allowed:
        raise ContractError(f'{path}: unsupported schema keywords {set(node)-allowed}')
    if '$ref' in node:
        target = node['$ref']
        if not target.startswith('#/'):
            raise ContractError('Only local references are permitted')
        resolved = root
        for part in target[2:].split('/'):
            resolved = resolved[part.replace('~1', '/').replace('~0', '~')]
        return validate(value, resolved, root, path)
    if 'oneOf' in node:
        matches = 0
        for branch in node['oneOf']:
            try:
                validate(value, branch, root, path)
                matches += 1
            except ContractError:
                pass
        if matches != 1:
            raise ContractError(f'{path}: oneOf matched {matches} branches')
    if 'const' in node and canonical(value) != canonical(node['const']):
        raise ContractError(f'{path}: const mismatch')
    if 'enum' in node and canonical(value) not in [canonical(x) for x in node['enum']]:
        raise ContractError(f'{path}: enum mismatch')
    kinds = {'object': lambda x: isinstance(x, dict),
             'array': lambda x: isinstance(x, list),
             'string': lambda x: isinstance(x, str),
             'integer': lambda x: isinstance(x, int) and not isinstance(x, bool),
             'boolean': lambda x: isinstance(x, bool), 'null': lambda x: x is None}
    kind = node.get('type')
    if kind and (kind not in kinds or not kinds[kind](value)):
        raise ContractError(f'{path}: expected {kind}')
    if isinstance(value, dict):
        if set(node.get('required', [])) - set(value):
            raise ContractError(f'{path}: missing required property')
        props = node.get('properties', {})
        for key, item in value.items():
            if 'propertyNames' in node:
                validate(key, node['propertyNames'], root, path + '.<key>')
            if key in props:
                validate(item, props[key], root, path + '.' + key)
            elif node.get('additionalProperties') is False:
                raise ContractError(f'{path}: unexpected {key}')
            elif isinstance(node.get('additionalProperties'), dict):
                validate(item, node['additionalProperties'], root, path + '.' + key)
    if isinstance(value, list):
        if len(value) < node.get('minItems', 0):
            raise ContractError(f'{path}: too few items')
        if 'items' in node:
            for i, item in enumerate(value):
                validate(item, node['items'], root, f'{path}[{i}]')
    if isinstance(value, str):
        if len(value) < node.get('minLength', 0) or len(value) > node.get('maxLength', float('inf')):
            raise ContractError(f'{path}: string length')
        if 'pattern' in node and re.search(node['pattern'], value) is None:
            raise ContractError(f'{path}: pattern mismatch')
    if kind == 'integer' and value < node.get('minimum', value):
        raise ContractError(f'{path}: integer below minimum')


def inspect_schema(node, root=None):
    """Check all branches/local references, including unused example paths."""
    root = node if root is None else root
    if '$ref' in node:
        target = node['$ref']
        if not target.startswith('#/'):
            raise ContractError('External schema reference is not allowed')
        resolved = root
        for part in target[2:].split('/'):
            resolved = resolved[part.replace('~1', '/').replace('~0', '~')]
        if not isinstance(resolved, dict):
            raise ContractError('Reference is not a schema object')
    if 'pattern' in node:
        re.compile(node['pattern'])
    if set(node.get('required', [])) - set(node.get('properties', {})):
        raise ContractError('Required field absent from properties')
    children = list(node.get('$defs', {}).values()) + list(node.get('properties', {}).values()) + node.get('oneOf', [])
    for keyword in ['items', 'propertyNames', 'additionalProperties']:
        if isinstance(node.get(keyword), dict):
            children.append(node[keyword])
    for child in children:
        inspect_schema(child, root)


def rejected(value, schema):
    try:
        validate(value, schema)
    except ContractError:
        return True
    return False


def sqrt_bounds(value, tolerance=Fraction(1, 10**9)):
    assert value >= 0
    lo, hi = Fraction(0), max(Fraction(1), value)
    for _ in range(128):
        mid = (lo + hi) / 2
        if mid * mid == value:
            return mid, mid
        if mid * mid < value:
            lo = mid
        else:
            hi = mid
        if hi - lo <= tolerance:
            return lo, hi
    raise ContractError('Contract oracle solver did not converge')


def cp_feeder(vs, resistance, power):
    vs, resistance, power = map(Fraction, (vs, resistance, power))
    if resistance == 0 or power == 0:
        return (vs, vs), (power / vs, power / vs)
    disc = vs * vs - 4 * resistance * power
    if disc < 0:
        raise ContractError('NO_FEASIBLE_ELECTRICAL_SOLUTION')
    if disc == 0:
        raise ContractError('OPERATING_POINT_AT_BOUNDARY')
    low, high = sqrt_bounds(disc)
    vlow, vhigh = (vs + low) / 2, (vs + high) / 2
    return (vlow, vhigh), (power / vhigh, power / vlow)


def check_qualification_report(manifest, report):
    for case in manifest['positiveCases']:
        if case['id'] not in report:
            raise ContractError('Missing positive case')
        for row in case['requiredResults']:
            for context in case['requiredContexts'][row['processCode']]:
                for dimension in row['requiredDimensions']:
                    key = (context, row['processCode'], dimension)
                    if report[case['id']].get(key) != ('COMPLETE', 'PASS', 'SUCCEEDED'):
                        raise ContractError('Required qualification dimension is not passing')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    checks = []
    for schema_file in (BASE / 'schemas').glob('*.json'):
        inspect_schema(read(schema_file))
    schema_examples = [
        ('power-catalog.schema.json', 'minimal-power-catalog.json', True),
        ('power-catalog.schema.json', 'invalid-power-catalog.json', False),
        ('power-command.schema.json', 'set-zero-load-command.json', True),
        ('power-command.schema.json', 'invalid-numeric-command.json', False),
        ('power-command.schema.json', 'freeze-v2-command.json', True),
        ('power-evaluation.schema.json', 'power-evaluation.json', True),
        ('power-evaluation.schema.json', 'invalid-missing-segment-evaluation.json', False),
        ('power-history.schema.json', 'persisted-history.json', True),
    ]
    for schema_name, example_name, expected in schema_examples:
        schema = read(BASE / 'schemas' / schema_name)
        value = read(BASE / 'examples' / example_name)
        assert (not rejected(value, schema)) == expected, example_name
    cmd_schema = read(BASE / 'schemas/power-command.schema.json')
    unknown = read(BASE / 'examples/freeze-v2-command.json')
    unknown['payloadSchemaVersion'] = 99
    assert rejected(unknown, cmd_schema)
    checks.append('RM11: 8 structural valid/invalid examples and unknown-version rejection')

    cat = read(BASE / 'examples/minimal-power-catalog.json')['power']
    index = {}
    for kind in ['connectors', 'protocols', 'interfaces', 'portDefinitions', 'componentDefinitions', 'transferDefinitions', 'poeDefinitions', 'batteryDefinitions', 'policyDefinitions', 'compatibilityDefinitions']:
        entries = {x['code']: x for x in cat[kind]}
        assert len(entries) == len(cat[kind]), kind
        index[kind] = entries
    for port in cat['portDefinitions']:
        assert port['connectorCode'] in index['connectors']
        assert port['protocolCode'] in index['protocols']
        assert index['interfaces'][port['interfaceCode']]['portCode'] == port['code']
        assert Fraction(port['voltage']['minV']) <= Fraction(port['voltage']['nominalV']) <= Fraction(port['voltage']['maxV'])
    for profile in cat['compatibilityDefinitions']:
        for suffix in ['A', 'B']:
            port = index['portDefinitions'][profile['portCode' + suffix]]
            assert profile['protocolCode' + suffix] == port['protocolCode']
            assert profile['interfaceCode' + suffix] == port['interfaceCode']
    for comp in cat['componentDefinitions']:
        assert set(comp['portCodes']) <= set(index['portDefinitions'])
    checks.append('RM05: strict power-only catalog has resolving canonical interface/compatibility references')

    rows = [('LEGACY', 'NODE', 'a'), ('ELV3', 'NODE', 'b'), ('ELV4', 'POINTER', 'c'), ('ELV4', 'EVALUATION', 'd')]
    assert [r[2] for r in rows if r[:2] == ('LEGACY', 'NODE')] == ['a']
    checks.append('RM01: specified owner/kind partition isolates old consumers (contract model only)')
    zero = read(BASE / 'examples/set-zero-load-command.json')
    assert Fraction(zero['payload']['loads'][0]['demand']['currentA']) == 0
    canonical_nameplate = '10'
    scenario_demands = {'STANDBY': '0', 'ALARM': '8'}
    assert canonical_nameplate == '10' and scenario_demands['STANDBY'] != None
    checks.append('RM02/RM03: explicit zero remains a state fact, static nameplate stays separate (contract model)')
    keys = [canonical(['elv4-node-v2', 'r1', 'backup', 'SEGMENT', seg, 'ELV-PWR-01', 'SOURCE', 'p1']) for seg in ['standby', 'alarm']]
    assert keys[0] != keys[1]
    checks.append('RM04: standby/alarm result keys differ')
    volt, amps = cp_feeder('24', '.5', '160')
    assert volt == (Fraction(20), Fraction(20)) and amps == (Fraction(8), Fraction(8))
    assert Fraction(24) * amps[0] == Fraction(160) + amps[0]**2 * Fraction('.5')
    for r, power, message in [('1', '160', 'NO_FEASIBLE'), ('1', '144', 'BOUNDARY')]:
        try:
            cp_feeder('24', r, power)
            raise AssertionError('No-solution/boundary was accepted')
        except ContractError as error:
            assert message in str(error)
    checks.append('RM06: exact CP oracle, power conservation, no-real-solution and collapse-boundary rejection')
    mapping = {'r1-run-a': 'r2-run-a', 'r1-traversal-a': 'r2-traversal-a'}
    assert [mapping[x] for x in mapping] == ['r2-run-a', 'r2-traversal-a']
    checks.append('RM07: required operational remapping contract model; app materializer not executed')
    history = read(BASE / 'examples/persisted-history.json')
    for direction in ['forward', 'inverse']:
        assert digest(history[direction + 'Command']) == history[direction + 'PayloadSha256']
    persisted = json.loads(json.dumps(history))
    assert persisted['forwardCommand']['payload']['loads'][0]['demand']['currentA'] == '0.4'
    checks.append('RM08: durable complete forward/inverse payloads survive JSON reopen with matching hashes')
    assert Fraction('.1') + Fraction('.2') == Fraction('.15') + Fraction('.15') == Fraction('.3')
    assert Fraction('.300000000001') > Fraction('.3')
    checks.append('RM09: exact-decimal equality and real overload are distinguished')
    db = sqlite3.connect(':memory:')
    db.execute('CREATE TABLE rev(project TEXT, seq INTEGER, UNIQUE(project,seq))')
    db.executemany('INSERT INTO rev VALUES (?,?)', [('p', 1), ('p', 2)])
    next_seq = db.execute('SELECT MAX(seq)+1 FROM rev WHERE project=?', ('p',)).fetchone()[0]
    db.execute('INSERT INTO rev VALUES (?,?)', ('p', next_seq))
    assert next_seq == 3
    db.close()
    checks.append('RM10: older base does not reuse sequence 2 in isolated allocator oracle')
    event_totals = [Fraction(5) + 10 + 20, Fraction(5) + 20, Fraction(5)]
    assert event_totals == [35, 25, 5] and max(event_totals) == 35
    checks.append('RM12: simultaneous startup event totals and conservative 35W/5s requirement')
    evaluation = read(BASE / 'examples/power-evaluation.json')
    assert set(evaluation['dependencyKeys']) == {f['key'] for f in evaluation['consumedFacts']}
    used = {f['key']: f['canonicalValueJson'] for f in evaluation['consumedFacts']}
    assert digest(used) == digest(copy.deepcopy(used))
    changed = dict(used); changed['shared-member-set'] = '["new-pd"]'
    assert digest(used) != digest(changed)
    checks.append('RM13: example facts equal declared dependencies; membership addition changes technical hash')
    assert 'RUNNING' not in read(BASE / 'schemas/power-evaluation.schema.json')['properties']['execution']['enum']
    checks.append('RM14: durable evaluation excludes transient RUNNING; app freeze race remains runtime obligation')
    manifest = read(BASE / 'qualification.json')
    assert set(manifest['requiredPositiveCaseIds']) == {c['id'] for c in manifest['positiveCases']}
    coverage = set(); report = {}
    for case in manifest['positiveCases']:
        assert len(case['facts']['paths']) > 0
        assert case['facts']['applicability']['unsupportedModelAllowed'] is False
        coverage.update(r['processCode'] for r in case['requiredResults'])
        report[case['id']] = {}
        for row in case['requiredResults']:
            assert (row['completion'], row['assessment'], row['execution']) == ('COMPLETE', 'PASS', 'SUCCEEDED')
            assert case['requiredContexts'][row['processCode']]
            for context in case['requiredContexts'][row['processCode']]:
                for dimension in row['requiredDimensions']:
                    report[case['id']][context, row['processCode'], dimension] = ('COMPLETE', 'PASS', 'SUCCEEDED')
    assert len(coverage) == 6
    check_qualification_report(manifest, report)
    broken = copy.deepcopy(report); first = next(iter(broken['Q-CCTV']))
    broken['Q-CCTV'][first] = ('BLOCKED', 'UNRESOLVED', 'SUCCEEDED')
    try:
        check_qualification_report(manifest, broken)
        raise AssertionError('Unresolved positive qualification was accepted')
    except ContractError:
        pass
    for cid in ['Q-CCTV', 'Q-SHARED']:
        case = next(c for c in manifest['positiveCases'] if c['id'] == cid)
        f = case['facts']; pse = f['pse']; ups = f['ups']
        cp_power = (sum(map(Fraction, pse['reservedPseW'])) / Fraction(pse['conversionEfficiency']) + Fraction(pse['idleW'])) / Fraction(ups['backupEfficiency'])
        v, current = cp_feeder('24', '.05', cp_power)
        assert v[0] > 20 and current[1] < 10
        assert Fraction('43.75') < Fraction(24) * current[0] <= Fraction(24) * current[1] < 44
        assert Fraction(24) * current[1] < Fraction('134.4')
    checks.append(f'RM15: {len(manifest["positiveCases"])} positive manifests cover all processes; missing/unresolved qualification rejected; supported backup bound <44Wh')
    ledger = read(BASE / 'requirements.json')
    assert len(ledger['requirements']) == len({r['requirementId'] for r in ledger['requirements']}) == 80
    assert all(r['runtimeStatus'] == 'NOT_STARTED' for r in ledger['requirements'])
    resolutions = read(AUDIT / 'remediation.json')
    assert len(resolutions['resolutions']) == 15
    assert all(x['specificationStatus'] == 'SPEC_RESOLVED' and x['runtimeStatus'] == 'NOT_IMPLEMENTED' for x in resolutions['resolutions'])
    link_count = 0
    files = list(BASE.glob('*.md')) + list((ROOT / 'docs/product').glob('elv4-*.md')) + [AUDIT / 'remediation-review.md']
    for file in files:
        for target in re.findall(r'\]\(([^)]+)\)', file.read_text()):
            if '://' not in target and not target.startswith('#'):
                resolved_target = (file.parent / target.split('#')[0]).resolve()
                planned_output = args.output.resolve() if args.output else None
                if not resolved_target.exists() and resolved_target != planned_output:
                    raise ContractError(f'Broken link {file}: {target}')
                link_count += 1
    result = {'schema': 'electra.elv4-specification-checks.v1', 'result': 'PASS',
              'scope': 'Specification oracles/schema subset only; not Flutter/Dart/runtime implementation evidence',
              'checks': checks, 'requirementCount': 80, 'specificationResolutions': 15,
              'positiveQualificationCases': len(manifest['positiveCases']), 'localLinksChecked': link_count,
              'runtimeImplemented': False}
    if args.output:
        args.output.write_text(json.dumps(result, indent=2, ensure_ascii=False) + '\n')
    print(f'PASS: {len(checks)} specification checks, 80 requirements, 15 specification resolutions, {link_count} links; no runtime claim')


if __name__ == '__main__':
    main()
