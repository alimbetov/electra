#!/usr/bin/env python3
"""Collect executed lifecycle evidence, never infer PASS from a source filename."""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import re
import os
from elv5_evidence import canonical_bytes, source_provenance

ROOT = Path(__file__).resolve().parents[2]
REGISTRY = ROOT / 'docs/product/elv5-implementation/f2-lifecycle-witness-registry.json'
PREFIX = 'ELV5_F2_WITNESS:'
REQUIRED = {'Q6_INITIAL', 'Q7_CAS_REJECTED', 'Q7_REPLAY', 'Q8_REPLAY', 'Q8_READ_ONLY', 'PERSISTED_IDENTITY'}
GLOBAL_REQUIRED = {'GLOBAL_PUBLICATION_ROLLBACK','GLOBAL_INDEPENDENT_CAS','GLOBAL_FREEZE_MANIFEST'}
SHA256 = re.compile(r'[0-9a-f]{64}')


def require(ok, message):
    if not ok:
        raise ValueError(message)


def digest(value):
    return hashlib.sha256(canonical_bytes(value)).hexdigest()


def registry():
    value = json.loads(REGISTRY.read_text())
    require(value.get('schema') == 'electra.elv5-f2-lifecycle-witness-registry.v1', 'Unknown witness registry')
    rows = value['witnesses']
    codes = {r['code'] for r in json.loads((REGISTRY.parent / 'process-registry.json').read_text())['processes']}
    require(len(rows) == len(codes) == 27 and {r['processCode'] for r in rows} == codes, 'Expected exactly 27 unique witnesses')
    require(len({(r['path'], r['testName']) for r in rows}) == 27, 'Duplicate witness test binding')
    for row in rows:
        require(isinstance(row['requireRepublished'], bool), 'Explicit mutation coverage is required')
        path = row['path']
        require(path.startswith('apps/mobile/test/') and '..' not in Path(path).parts, 'Witness path escapes mobile tests')
        require((ROOT / path).is_file(), 'Missing witness source: ' + path)
    return rows


def collect(events, witnesses, source_sha, *, require_global=False):
    """Return rows only after all tests, checkpoints and persisted pins agree."""
    require(re.fullmatch(r'(?:[0-9a-f]{40}|[0-9a-f]{64})', source_sha), 'Full Git source SHA required')
    suites, tests, outcomes, checkpoints = {}, {}, {}, {}
    start, done = False, None
    for event in events:
        kind = event.get('type')
        if kind == 'start':
            require(not start, 'Duplicate machine stream start')
            start = True
        elif kind == 'suite':
            suite = event['suite']
            suites[suite['id']] = suite['path'].replace('\\', '/')
        elif kind == 'testStart':
            test = event['test']
            require(test['id'] not in tests, 'Duplicate test id')
            tests[test['id']] = test
        elif kind == 'testDone':
            require(event['testID'] not in outcomes, 'Duplicate test completion')
            outcomes[event['testID']] = event
        elif kind == 'error':
            raise ValueError('Machine suite reported an error')
        elif kind == 'print' and event.get('message', '').startswith(PREFIX):
            payload = json.loads(event['message'][len(PREFIX):])
            require(event.get('testID') in tests, 'Unassociated lifecycle event')
            require(payload.get('schema') == 'electra.elv5-f2-lifecycle-event.v1', 'Unknown lifecycle event schema')
            require(payload.get('sourceSha') == source_sha, 'Lifecycle event source SHA mismatch')
            checkpoints.setdefault(event['testID'], []).append(payload)
        elif kind == 'done':
            require(done is None, 'Duplicate machine suite completion')
            done = event
    require(start and done and done.get('success') is True, 'Incomplete or failed machine test stream')
    require(tests and set(tests) == set(outcomes), 'Missing test completion')
    require(all(v.get('result') == 'success' for v in outcomes.values()), 'A test did not succeed')
    rows = []
    manifest = None
    for witness in witnesses:
        code = witness['processCode']
        matching = [tid for tid, test in tests.items()
                    if test['name'] == witness['testName']
                    and (suites.get(test['suiteID'], '') in {witness['path'], witness['path'].removeprefix('apps/mobile/')}
                         or suites.get(test['suiteID'], '').endswith('/' + witness['path']))]
        require(len(matching) == 1, f'{code}: exact witness test missing or ambiguous')
        tid = matching[0]
        require(outcomes[tid].get('skipped') is False, f'{code}: skipped witness')
        stages = {}
        for entry in checkpoints.get(tid, []):
            require(entry.get('processCode') == code, f'{code}: foreign process event')
            stage = entry.get('stage')
            require(stage in REQUIRED | {'Q6_REPUBLISHED'} | (GLOBAL_REQUIRED if require_global else set()), f'{code}: unknown checkpoint')
            require(stage not in stages, f'{code}: duplicate checkpoint {stage}')
            stages[stage] = entry
        required = REQUIRED | ({'Q6_REPUBLISHED'} if witness['requireRepublished'] else set()) | (GLOBAL_REQUIRED if require_global else set())
        require(required <= stages.keys(), f'{code}: missing lifecycle checkpoints {sorted(required - stages.keys())}')
        first, replay, frozen, persisted = [stages[s] for s in ('Q6_INITIAL', 'Q7_REPLAY', 'Q8_REPLAY', 'PERSISTED_IDENTITY')]
        for observed in (first, replay, frozen, persisted):
            require(observed.get('freshness') == 'CURRENT' and observed.get('execution') == 'SUCCEEDED'
                    and observed.get('completion') == 'COMPLETE', f'{code}: incomplete CURRENT observation')
            require(isinstance(observed.get('pointerGeneration'), int) and observed['pointerGeneration'] >= 1, f'{code}: invalid pointer generation')
            require(isinstance(observed.get('evaluationId'), str) and bool(observed['evaluationId']), f'{code}: missing evaluation identity')
            for field in ('inputFingerprint', 'outputSha256'):
                require(isinstance(observed.get(field), str) and SHA256.fullmatch(observed[field]), f'{code}: invalid {field}')
        for field in ('evaluationId', 'pointerGeneration', 'inputFingerprint', 'outputSha256'):
            require(replay[field] == frozen[field] == persisted[field], f'{code}: persisted replay {field} differs')
        if witness['requireRepublished']:
            changed = stages['Q6_REPUBLISHED']
            require(changed['pointerGeneration'] > first['pointerGeneration'], f'{code}: no invalidation/republication generation')
            require(changed['inputFingerprint'] != first['inputFingerprint'] and changed['evaluationId'] != first['evaluationId'], f'{code}: unchanged source identity')
            require(changed['evaluationId'] == replay['evaluationId'] and changed['pointerGeneration'] <= replay['pointerGeneration'], f'{code}: replay not from republished evaluation')
        require(persisted.get('revisionState') == 'FROZEN', f'{code}: persisted evidence not frozen')
        for field in ('nodeKeySha256', 'evidenceSha256'):
            require(isinstance(persisted.get(field), str) and SHA256.fullmatch(persisted[field]), f'{code}: invalid {field}')
        authority = persisted['authorityManifest']
        identity = persisted['qualificationIdentity']
        if manifest is None:
            manifest = authority
        require(authority == manifest, f'{code}: authority differs across process witnesses')
        require(authority.get('schema') == 'electra.elv5-foundation-authority-manifest.v1', 'Unknown runtime authority manifest')
        entries = [p for p in authority['processes'] if p['processCode'] == code]
        require(len(authority['processes']) == 27 and len({p['processCode'] for p in authority['processes']}) == 27 and len(entries) == 1, f'{code}: incomplete authority manifest')
        require(identity == {'schema':'electra.elv5-foundation-qualification-identity.v1',
                             'sourceSha':source_sha,'processVersion':entries[0]['processVersion'],
                             'rulesetVersion':authority['rulesetVersion'],'authorityFingerprint':digest(authority)}, f'{code}: persisted qualification identity mismatch')
        if require_global:
            rollback, race, freeze = [stages[key] for key in ('GLOBAL_PUBLICATION_ROLLBACK','GLOBAL_INDEPENDENT_CAS','GLOBAL_FREEZE_MANIFEST')]
            require(rollback.get('reopenedAfterEveryFault') is True and set(rollback.get('faultTables', [])) == {'discipline_evaluation_records','discipline_dependency_index','discipline_evaluation_pointers','command_execution_records'} and len(rollback['faultTables']) == 4, f'{code}: incomplete durable publication fault suite')
            require(race.get('connections') == 2 and race.get('committedWriters') == 1 and race.get('loserCode') == 'ELV5_POINTER_GENERATION_CONFLICT' and race.get('pointerGeneration') == 1, f'{code}: independent CAS witness missing')
            require(all(freeze.get(key) is True for key in ('publicFreezeApi','faultAfterAllSections','restartReplayIdentical','newCalculationRejected','manifestImmutable','disciplineAppendOnly','physicalHashLinked','powerHashLinked','createNextRestoresConfiguration')) and freeze.get('manifestSchema') == 'electra.elv4-snapshot-manifest.v1' and freeze.get('disciplineSectionSchema') == 'electra.elv5-discipline-freeze-section.v1', f'{code}: incomplete real freeze witness')
        rows.append({'processCode':code,'qualificationIdentity':identity,
                     'witness':{'path':witness['path'],'testName':witness['testName'], 'testID':tid,
                                'sourceFileSha256':hashlib.sha256((ROOT / witness['path']).read_bytes()).hexdigest()},
                     'lifecycleCheckpoints':stages,
                     'sourceMutationObserved':witness['requireRepublished'],
                     'lifecycleResult':'PASS_Q6_Q7_Q8', 'globalReliabilityResult':'PASS' if require_global else 'NOT_EXECUTED_IN_THIS_SUITE', 'fullQualificationResult':'PENDING_Q0_Q5_Q9' if require_global else 'PENDING_Q0_Q5_Q9_AND_GLOBAL_RELIABILITY'})
    return sorted(rows, key=lambda row: row['processCode'])


def verify_regressions(events, bindings):
    suites = {e['suite']['id']:e['suite']['path'].replace('\\','/') for e in events if e.get('type') == 'suite'}
    tests = {e['test']['id']:e['test'] for e in events if e.get('type') == 'testStart'}
    results = {e['testID']:e for e in events if e.get('type') == 'testDone'}
    proof = []
    for binding in bindings:
        path = binding['path']
        matches = [tid for tid,t in tests.items() if t['name'] == binding['testName'] and (suites.get(t['suiteID'],'') in {path,path.removeprefix('apps/mobile/')} or suites.get(t['suiteID'],'').endswith('/'+path))]
        require(len(matches) == 1, 'Missing exact global regression: '+binding['testName'])
        tid = matches[0]
        require(results.get(tid,{}).get('result') == 'success' and results[tid].get('skipped') is False, 'Global regression failed or skipped')
        proof.append({**binding,'testID':tid,'sourceFileSha256':hashlib.sha256((ROOT/path).read_bytes()).hexdigest()})
    return proof


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--paths', action='store_true')
    parser.add_argument('--require-global', action='store_true')
    parser.add_argument('--machine-log', type=Path)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--run-id', default=os.environ.get('GITHUB_RUN_ID'))
    args = parser.parse_args()
    witnesses = registry()
    regressions = json.loads(REGISTRY.read_text()).get('globalRegressionWitnesses', []) if args.require_global else []
    if args.require_global:
        require(len(regressions) == 3 and len({(r['path'],r['testName']) for r in regressions}) == 3, 'Three exact global regressions required')
    if args.paths:
        print('\n'.join(dict.fromkeys(row['path'].removeprefix('apps/mobile/') for row in [*witnesses,*regressions])))
        return
    require(args.machine_log and args.output, 'Machine log and output paths are required')
    provenance = source_provenance(ROOT)
    require(args.run_id and str(args.run_id).isdigit(), 'Workflow run id required')
    # Only machine JSON is authoritative. Flutter startup chatter is ignored.
    events = [json.loads(line) for line in args.machine_log.read_text().splitlines() if line.lstrip().startswith('{')]
    rows = collect(events, witnesses, provenance['sourceSha'], require_global=args.require_global)
    regression_proof = verify_regressions(events, regressions)
    report = {'schema':'electra.elv5-f2-executed-witness-matrix.v1', **provenance,
              'workflowRunId':int(args.run_id), 'machineLogSha256':hashlib.sha256(args.machine_log.read_bytes()).hexdigest(),
              'registrySha256':hashlib.sha256(REGISTRY.read_bytes()).hexdigest(),
              'processCount':len(rows),'lifecycleCovered':len(rows),'qualified':0,'accepted':False,
              'globalReliabilityExecuted':args.require_global,'globalRegressionWitnesses':regression_proof,
              'processes':rows}
    report['matrixSha256'] = digest(report)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2, sort_keys=True) + '\n')
    print(f'ELV5 executed lifecycle matrix: {len(rows)}/27, qualified=0, source={provenance["sourceSha"]}')


if __name__ == '__main__':
    main()
