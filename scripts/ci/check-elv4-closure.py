#!/usr/bin/env python3
"""Check reconciliation integrity; --require-accepted enforces runtime closure.

Source/test paths and a green technical run alone never certify qualification.
Historical audit reports are deliberately not edited or treated as live status.
"""
import argparse
import datetime
import hashlib
import os
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'docs/product/elv4-implementation'
SHA = re.compile(r'^[0-9a-f]{40}$')
PHASES = {'baseline-guards', 'specification', 'reconciliation', 'drift',
          'mobile-deps', 'core-deps', 'mobile-format', 'mobile-analyze', 'mobile-tests',
          'historical-migrations', 'core-format', 'core-analyze', 'core-tests',
          'p7-p8-acceptance', 'runtime-qualification', 'clean-tree'}


def require(ok, message):
    if not ok:
        raise ValueError(message)


def read(path):
    return json.loads(Path(path).read_text())


def check_reconciliation(ledger, closure):
    requirements = ledger['requirements']
    expected = {f'ELV4-P{p}-{n:03}' for p in range(10) for n in range(1, 9)}
    require(len(requirements) == 80 and
            {r['requirementId'] for r in requirements} == expected,
            'Expected exactly the 80 P0-P9 requirement identities')
    findings = closure['findings']
    ids = {f['id'] for f in findings}
    require(len(ids) == len(findings), 'Duplicate finding identity')
    for finding in findings:
        require(finding['status'] in {'OPEN', 'PENDING', 'RESOLVED'}, 'Invalid finding status')
        require(finding['severity'] in {'BLOCKER', 'HIGH', 'MEDIUM', 'LOW', 'GATE'}, 'Invalid severity')
        require(finding['requiredResolution'] and finding['owner'], 'Finding lacks disposition/owner')
    for r in requirements:
        require(r['package'] == r['requirementId'].split('-')[1], 'Wrong package')
        require(r['runtimeStatus'] in {'IN_PROGRESS', 'BLOCKED', 'IMPLEMENTED', 'ACCEPTED'}, 'Invalid runtime status')
        require(SHA.fullmatch(r['sourceReviewedSha']), 'Missing source review SHA')
        require(r['sourcePaths'] and r['testPaths'] and r['evidence'], 'Missing concrete traceability')
        for path in r['sourcePaths'] + r['testPaths']:
            require(not Path(path).is_absolute() and '..' not in Path(path).parts,
                    f'Unsafe evidence path: {path}')
            require((ROOT / path).is_file(), f'Missing source/test: {path}')
        require(set(r['openFindingIds']) <= ids, 'Unknown open finding')
        if r['runtimeStatus'] == 'ACCEPTED':
            require(r['acceptanceStatus'] == 'PASS' and SHA.fullmatch(r['testedSha'] or ''),
                    'Accepted requirement lacks executed exact-head evidence')
            require(not r['openFindingIds'], 'Accepted requirement still has open gap')
    for workflow in (ROOT / '.github/workflows').glob('tmp-elv4-*'):
        raise ValueError(f'Temporary ELV4 workflow remains: {workflow.name}')
    for pattern in ('apply-elv4-*.py', 'fix-elv4-*.py'):
        require(not list((ROOT / 'scripts/ci').glob(pattern)), 'One-shot ELV4 source mutator remains')


def check_qualification(manifest, report, source_sha):
    require(report['sourceSha'] == source_sha, 'Qualification source SHA differs')
    required = set(manifest['requiredPositiveCaseIds'])
    cases = report['cases']
    require(len(cases) == len(required) and {c['id'] for c in cases} == required,
            'Qualification cases are missing, duplicated or unexpected')
    by_id = {c['id']: c for c in cases}
    for expected in manifest['positiveCases']:
        case = by_id[expected['id']]
        require(case['fixtureKind'] == 'PUBLIC_COMMAND_FILE_SQLITE' and
                case['foreignKeyViolations'] == 0, 'Qualification lacks FK-valid public fixture')
        rows = case['results']
        actual = {}
        for row in rows:
            key = (row['context'], row['processCode'], row['dimension'])
            require(key not in actual, 'Duplicate qualification result')
            require(row['evaluationId'] and row['evidenceSha256'] and row['inputFingerprint'],
                    'Qualification result lacks immutable evaluation identity')
            require(all(re.fullmatch(r'[a-f0-9]{64}', row[k])
                        for k in ('evidenceSha256', 'inputFingerprint')), 'Invalid evidence digest')
            actual[key] = row
        for process in expected['requiredResults']:
            for context in expected['requiredContexts'][process['processCode']]:
                for dimension in process['requiredDimensions']:
                    row = actual.get((context, process['processCode'], dimension))
                    require(row is not None, 'Missing required process/context/dimension')
                    require((row['completion'], row['assessment'], row['execution']) ==
                            ('COMPLETE', 'PASS', 'SUCCEEDED'), 'Nonpassing required qualification dimension')


def check_acceptance(ledger, closure, technical, qualification, source_sha):
    require(not [f for f in closure['findings'] if f['status'] != 'RESOLVED' and
                 f['severity'] in {'BLOCKER', 'HIGH', 'GATE'}], 'Runtime closure has unresolved HIGH/BLOCKER or pending gate')
    require(technical is not None and qualification is not None, 'Both executed reports are required')
    require(technical['sourceSha'] == source_sha and technical['technicalResult'] == 'PASS',
            'Technical report does not pass at exact source SHA')
    require(set(technical['phases']) == PHASES and
            all(v == 'PASS' for v in technical['phases'].values()), 'Incomplete technical gate')
    check_qualification(read(BASE / 'qualification.json'), qualification, source_sha)
    # The committed ledger may reference a previous tested source. Requiring it
    # to embed its own final commit SHA would make closure impossible. Current
    # execution evidence lives in the run artifact, outside the source tree.
    require(all(r['runtimeStatus'] in {'IMPLEMENTED', 'ACCEPTED'} and
                not r['openFindingIds'] for r in ledger['requirements']),
            'Committed requirements still contain implementation gaps')
    results = qualification['requirementResults']
    expected = {r['requirementId'] for r in ledger['requirements']}
    require(len(results) == len(expected) and
            {r['requirementId'] for r in results} == expected,
            'Missing, duplicate or unexpected executed requirement result')
    require(all(r['status'] == 'PASS' and isinstance(r['evidenceRefs'], list) and
                r['evidenceRefs'] and all(isinstance(ref, str) and ref.strip()
                                         for ref in r['evidenceRefs'])
                for r in results), 'Requirement execution lacks passing evidence')
    digest = lambda value: hashlib.sha256(json.dumps(
        value, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
    return {'event': 'RUNTIME_ACCEPTED', 'sourceSha': source_sha,
            'timestamp': datetime.datetime.now(datetime.timezone.utc).isoformat(),
            'workflowRunId': os.getenv('GITHUB_RUN_ID'),
            'evidenceRefs': {'technicalReportSha256': digest(technical),
                             'qualificationReportSha256': digest(qualification)}}



def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--require-accepted', action='store_true')
    parser.add_argument('--technical-report', type=Path)
    parser.add_argument('--qualification-report', type=Path)
    parser.add_argument('--acceptance-output', type=Path)
    args = parser.parse_args()
    ledger, closure = read(BASE / 'requirements.json'), read(BASE / 'closure.json')
    check_reconciliation(ledger, closure)
    print('PASS: 80 requirement mappings, explicit gaps, source/test paths, CI cleanup')
    if args.require_accepted:
        source_sha = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
        event = check_acceptance(ledger, closure,
                         read(args.technical_report) if args.technical_report else None,
                         read(args.qualification_report) if args.qualification_report else None,
                         source_sha)
        if args.acceptance_output:
            args.acceptance_output.write_text(json.dumps(event, indent=2) + '\n')
        print(json.dumps(event, indent=2))
    else:
        print('Runtime acceptance: PENDING; reconciliation PASS is not runtime acceptance')


if __name__ == '__main__':
    try:
        main()
    except (ValueError, KeyError, TypeError) as error:
        raise SystemExit(f'FAIL: {error}')
