#!/usr/bin/env python3
"""Validate ELV5 P0-P6 implementation bindings and performance freeze."""
from __future__ import annotations
from collections import Counter
import json,re
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
IMPL=ROOT/'docs/product/elv5-implementation'
AUDIT=ROOT/'docs/audit/elv5-sixth-pass-code-binding-performance-audit.json'
DOSSIERS=[IMPL/'process-specifications/cctv-processes.md',IMPL/'process-specifications/lan-processes.md',IMPL/'process-specifications/acs-processes.md',IMPL/'process-specifications/fire-processes.md']
PRIORITY=['CCTV-02','CCTV-03','LAN-01','LAN-05','ACS-03','ACS-04','ACS-05','FA-02','FA-04','FA-05','FA-06']

def load(name): return json.loads((IMPL/name).read_text(encoding='utf-8'))
def req(ok,msg):
    if not ok: raise SystemExit(msg)

def main():
    process=load('process-registry.json'); alg=load('algorithm-registry.json'); cmd=load('command-registry.json')
    bind=load('implementation-binding-registry.json'); repo=load('repository-contract-registry.json')
    versions=load('runtime-version-registry.json'); perf=load('algorithm-performance-registry.json'); ft=load('finding-trace-code-registry.json')
    audit=json.loads(AUDIT.read_text(encoding='utf-8'))
    codes={r['code'] for r in process['processes']}; req(len(codes)==27,'process registry must contain 27 codes')
    alg_by={r['code']:r for r in alg['processes']}; req(set(alg_by)==codes,'algorithm registry code drift')
    rows=bind['processBindings']; by={r['code']:r for r in rows}; req(len(rows)==len(by)==27 and set(by)==codes,'implementation binding coverage drift')
    req(Counter(r['package'] for r in rows)=={'P3':6,'P4':7,'P5':6,'P6':8},'P3-P6 process distribution drift')
    req(bind['status']=='DESIGN_FROZEN_RUNTIME_NOT_STARTED','implementation bindings must be frozen')
    common=bind['common']; req(common['pureKernel'] and not common['kernelDatabaseAccessAllowed'],'kernels must remain pure')
    req(not common['mediumLargeMainUiIsolateAllowed'],'medium/large UI isolate execution must be forbidden')
    method_rows=repo['readMethods']; methods={r['id']:r for r in method_rows}; req(len(methods)==len(method_rows),'duplicate repository method ID')
    qp=repo['queryPolicy']; req(not qp['cardinalityDependentQueryCountAllowed'] and not qp['pointLookupInsideMemberLoopAllowed'],'N+1 query policy weakened')
    req(not qp['captureTransactionMayContainKernelWork'],'kernel work inside capture transaction forbidden')
    for m in method_rows:
        req(m['bulk'] and not m['queryCountDependsOnCardinality'] and m['returnsDomainObjects'],f"unsafe repository method {m['id']}")
    version_rows=versions['processVersions']; vb={r['code']:r for r in version_rows}; req(len(vb)==27 and set(vb)==codes,'runtime version coverage drift')
    req(versions['databaseSchemaVersion']==24 and versions['canonicalEncoderVersion']=='electra.canonical-json.v1','global runtime version drift')
    perf_rows=perf['processes']; pb={r['code']:r for r in perf_rows}; req(len(pb)==27 and set(pb)==codes,'performance registry coverage drift')
    req({r['code'] for r in perf_rows if r['priority']}==set(PRIORITY),'priority performance core drift')
    gr=perf['globalRules']; req(not gr['nestedFullScanAllowed'] and not gr['pointQueryInsideMemberLoopAllowed'] and not gr['unboundedPowersetOrCartesianEnumerationAllowed'],'performance anti-pattern guard weakened')
    req(not gr['mediumLargeUiIsolateExecutionAllowed'] and not gr['workerCompletionOrderMayAffectResult'],'execution determinism guard weakened')
    req(gr['performanceRegressionThresholdPercent']==15,'performance regression threshold drift')
    ft_rows=ft['processNamespaces']; fb={r['code']:r for r in ft_rows}; req(len(fb)==27 and set(fb)==codes,'finding/trace namespace coverage drift')
    repo_ids=set(methods)
    for code,row in by.items():
        req(row['algorithmVersion']==vb[code]['algorithmVersion'],f'{code} algorithm version mismatch')
        req(row['complexity']==pb[code]['complexity'] and row['workload']==pb[code]['workloadClass'],f'{code} performance binding mismatch')
        req(row['family'] in alg_by[code]['families'],f'{code} primary family absent from algorithm registry')
        req(set(row['reads'])<=repo_ids,f'{code} references unknown repository read method')
        req(row['tracePrefix']==fb[code]['tracePrefix'],f'{code} trace prefix mismatch')
        req(row['definition'].endswith('ProcessDefinition') and row['resolver'].endswith('InputResolver') and row['kernel'].endswith('Kernel'),f'{code} symbol contract malformed')
        req(row['definitionPath'].startswith('packages/engineering_core/lib/src/elv5/processes/'),f'{code} pure definition path drift')
        req(row['resolverPath'].startswith('apps/mobile/lib/application/elv5/calculation/resolvers/'),f'{code} resolver path drift')
    command_ops=[r.get('operation') or r.get('code') for r in cmd['commands']]
    command_bind=bind['commandBindings']; req(len(command_bind)==16 and len({r[0] for r in command_bind})==16,'expected 16 unique command bindings')
    req(set(r[0] for r in command_bind)==set(command_ops),'command handler binding differs from command registry')
    req(sum(1 for r in command_bind if r[2]=='CAPTURE_RUN_GUARDED_PUBLISH')==1,'exactly one calculation protocol binding required')
    req(sum(1 for r in command_bind if r[2]=='REPLAY_FIRST_REPLACEMENT')==15,'exactly 15 replay-first mutation bindings required')
    dossier_text='\n'.join(p.read_text(encoding='utf-8') for p in DOSSIERS)
    for code in sorted(codes):
        prefix=fb[code]['tracePrefix']+'_'
        block=re.search(rf'^## {re.escape(code)} — .*?(?=^## (?:CCTV|LAN|ACS|FA)-\d{{2}} — |\Z)',dossier_text,re.M|re.S)
        req(block is not None,f'{code} dossier missing')
        trace=re.search(r'^### 17\. Calculation trace\n(.*?)(?=^### 18\.)',block.group(0),re.M|re.S)
        req(trace is not None and prefix in trace.group(1),f'{code} dossier trace prefix not frozen')
    req(audit['counts']=={'high':7,'medium':3,'total':10,'resolved':10,'open':0},'sixth-pass audit count drift')
    req(all(r['status']=='SPEC_RESOLVED' for r in audit['findings']),'sixth-pass unresolved finding')
    hard=(IMPL/'implementation-binding-hardening-v1.md').read_text(encoding='utf-8').lower()
    for token in ['design frozen','n+1','o(n²)','worker count','runtime-version-registry.json']:
        req(token in hard,f'implementation hardening missing token: {token}')
    print('ELV5 implementation binding/performance contract PASS')
    print('processes=27 commands=16 repoMethods=%d priority=11 sixthOpen=0' % len(methods))
    print('bulkOnly=1 nPlusOneForbidden=1 kernelDbAccess=0 mediumLargeUi=0 deterministicParallel=1')

if __name__=='__main__': main()
