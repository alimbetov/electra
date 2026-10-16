#!/usr/bin/env python3
"""Generate deterministic ELV5 exact-head authority manifest."""
from __future__ import annotations
import argparse,hashlib,json,re
from elv5_evidence import source_provenance
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
IMPL=ROOT/'docs/product/elv5-implementation'
DOSSIERS=[
'docs/product/elv5-implementation/process-specifications/cctv-processes.md',
'docs/product/elv5-implementation/process-specifications/lan-processes.md',
'docs/product/elv5-implementation/process-specifications/acs-processes.md',
'docs/product/elv5-implementation/process-specifications/fire-processes.md',
]
AUTHORITY_PATHS=[
'.github/workflows/flutter-local.yml',
'docs/product/elv5-authoritative-spec-index.md','docs/product/elv5-discipline-calculations-design-specification.md','docs/product/elv5-p0-p9-delivery-plan.md','docs/product/elv5-implementation/README.md',
'docs/product/elv5-implementation/implemented-baseline.md','docs/product/elv5-implementation/baseline.json','docs/adr/ADR-031-elv5-pure-core-and-module-boundary.md',
'docs/product/elv5-implementation/requirements.json','docs/product/elv5-implementation/normative-requirements-registry.json','docs/product/elv5-implementation/market-simulation-requirements.json','docs/product/elv5-implementation/market-simulation-catalog.json','docs/product/elv5-implementation/market-simulation-450-plan.md','docs/product/elv5-implementation/market-simulation-p0-p9-bindings.json',
'docs/product/elv5-implementation/combinatorial-engineering-requirements.json','docs/product/elv5-implementation/combinatorial-engineering-1500-plan.md','docs/product/elv5-implementation/p8-p9-combinatorial-1500-amendment.md','docs/product/elv5-implementation/combinatorial-legal-pair-constraints.json','docs/product/elv5-implementation/combinatorial-targeted-three-wise.json','docs/product/elv5-implementation/combinatorial-covering-template-v1.json','docs/product/elv5-implementation/combinatorial-system-wide-inventory.json',
'docs/product/elv5-implementation/process-contracts.md','docs/product/elv5-implementation/process-registry.json','docs/product/elv5-implementation/algorithm-registry.json','docs/product/elv5-implementation/command-registry.json','docs/product/elv5-implementation/engineering-primitives-contract.md','docs/product/elv5-implementation/typed-process-api.md','docs/product/elv5-implementation/calculation-engine-contract.md','docs/product/elv5-implementation/process-code-level-specification.md',*DOSSIERS,
'docs/product/elv5-implementation/calculation-oracle-errata-v1.md','docs/product/elv5-implementation/flutter-performance-contract.md','docs/product/elv5-implementation/persistence-schema-contract.md','docs/product/elv5-implementation/code-level-runtime-contract.md','docs/product/elv5-implementation/code-level-hardening-amendments.md','docs/product/elv5-implementation/code-level-hardening-v2.md','docs/product/elv5-implementation/production-source-blueprint.md','docs/product/elv5-implementation/qualification-contract.md',
'docs/product/elv5-implementation/implementation-binding-hardening-v1.md','docs/product/elv5-implementation/implementation-binding-registry.json','docs/product/elv5-implementation/repository-contract-registry.json','docs/product/elv5-implementation/runtime-version-registry.json','docs/product/elv5-implementation/algorithm-performance-registry.json','docs/product/elv5-implementation/finding-trace-code-registry.json',
'docs/product/elv5-implementation/project-alignment-hardening-v1.md','docs/product/elv5-implementation/downstream-handoff-registry.json','docs/product/development-roadmap.md',
'docs/product/elv5-implementation/p0-baseline.md','docs/product/elv5-implementation/p1-profiles-registry.md','docs/product/elv5-implementation/p2-persistence-commands.md','docs/product/elv5-implementation/p3-cctv.md','docs/product/elv5-implementation/p4-lan.md','docs/product/elv5-implementation/p5-acs.md','docs/product/elv5-implementation/p6-fire.md','docs/product/elv5-implementation/p7-dependencies-workspace.md','docs/product/elv5-implementation/p8-acceptance.md','docs/product/elv5-implementation/p9-closure.md',
'docs/audit/elv5-third-pass-production-readiness-audit.json','docs/audit/elv5-fourth-pass-algorithm-performance-audit.md','docs/audit/elv5-fourth-pass-algorithm-performance-audit.json','docs/audit/elv5-fifth-pass-specification-closure-audit.md','docs/audit/elv5-fifth-pass-specification-closure-audit.json','docs/audit/elv5-sixth-pass-code-binding-performance-audit.md','docs/audit/elv5-sixth-pass-code-binding-performance-audit.json','docs/audit/elv5-seventh-pass-project-alignment-audit.md','docs/audit/elv5-seventh-pass-project-alignment-audit.json',
'scripts/ci/elv5_evidence.py','scripts/ci/test_elv5_evidence.py','scripts/ci/generate-elv5-contract-manifest.py','scripts/ci/check-elv5-command-examples.py','docs/product/elv5-implementation/command-examples.json',
'scripts/ci/check-elv5-market-simulation.py','scripts/ci/check-elv5-market-p0-p9-bindings.py','scripts/ci/generate-elv5-combinatorial-1500.py','scripts/ci/check-elv5-fifth-pass-closure.py','scripts/ci/check-elv5-implementation-bindings.py','scripts/ci/check-elv5-project-alignment.py',
]

def hbytes(b): return hashlib.sha256(b).hexdigest()
def hfile(p): return hbytes(p.read_bytes())
def cbytes(v): return json.dumps(v,ensure_ascii=False,sort_keys=True,separators=(',',':')).encode()
def load(p): return json.loads(p.read_text(encoding='utf-8'))
def req(ok,msg):
    if not ok: raise SystemExit(msg)
def rows(v): return v if isinstance(v,list) else v.get('requirements',[])
def dossiers():
    pr=re.compile(r'^## (CCTV-\d{2}|LAN-\d{2}|ACS-\d{2}|FA-\d{2}) — .+$',re.M)
    out=[]; codes=[]
    for rel in DOSSIERS:
        p=ROOT/rel; text=p.read_text(encoding='utf-8'); found=pr.findall(text); codes+=found
        out.append({'path':rel,'sha256':hfile(p),'byteLength':p.stat().st_size,'processCodes':found})
    req(len(codes)==len(set(codes))==27,'expected 27 unique process dossiers')
    return out

def build_manifest(provenance):
    process=load(IMPL/'process-registry.json'); alg=load(IMPL/'algorithm-registry.json'); command=load(IMPL/'command-registry.json'); requirement=load(IMPL/'requirements.json')
    norm=load(IMPL/'normative-requirements-registry.json'); market_req=load(IMPL/'market-simulation-requirements.json'); market_cat=load(IMPL/'market-simulation-catalog.json')
    comb_req=load(IMPL/'combinatorial-engineering-requirements.json'); constraints=load(IMPL/'combinatorial-legal-pair-constraints.json'); three=load(IMPL/'combinatorial-targeted-three-wise.json'); template=load(IMPL/'combinatorial-covering-template-v1.json'); system=load(IMPL/'combinatorial-system-wide-inventory.json')
    impl=load(IMPL/'implementation-binding-registry.json'); repo=load(IMPL/'repository-contract-registry.json'); versions=load(IMPL/'runtime-version-registry.json'); perf=load(IMPL/'algorithm-performance-registry.json'); findings=load(IMPL/'finding-trace-code-registry.json'); handoff=load(IMPL/'downstream-handoff-registry.json')
    fifth=load(ROOT/'docs/audit/elv5-fifth-pass-specification-closure-audit.json'); sixth=load(ROOT/'docs/audit/elv5-sixth-pass-code-binding-performance-audit.json'); seventh=load(ROOT/'docs/audit/elv5-seventh-pass-project-alignment-audit.json')
    p,a,c,r=process['processes'],alg['processes'],command['commands'],rows(requirement); obligations=norm['obligations']; mr=market_req['requirements']; cr=comb_req['requirements']
    req(len(p)==len(a)==27 and {x['code'] for x in p}=={x['code'] for x in a},'process/algorithm inventory drift')
    codes={x['code'] for x in p}; req(len(c)==16 and len(r)==80 and len(obligations)==42 and len(mr)==12 and len(cr)==12,'closed count drift')
    req(len(impl['processBindings'])==27 and {x['code'] for x in impl['processBindings']}==codes,'implementation binding drift')
    req(len(impl['commandBindings'])==16,'command implementation binding drift')
    req(len(versions['processVersions'])==27 and {x['code'] for x in versions['processVersions']}==codes,'runtime version drift')
    req(versions['databaseSchemaVersion']==24,'ELV5 schema 24 runtime freeze drift')
    req(len(perf['processes'])==27 and {x['code'] for x in perf['processes']}==codes,'performance registry drift')
    req(len(findings['processNamespaces'])==27 and {x['code'] for x in findings['processNamespaces']}==codes,'finding/trace registry drift')
    req(all(x['bulk'] and not x['queryCountDependsOnCardinality'] for x in repo['readMethods']),'unsafe repository read contract')
    req(market_req['scenarioMatrixTarget']==450 and sum(market_cat['processScenarioCounts'].values())==450,'market target drift')
    req(comb_req['scenarioTarget']==1500 and comb_req['priorityProcessMinimum']==72 and comb_req['regularProcessMinimum']==42 and comb_req['systemWideScenarioCount']==36,'combinatorial target drift')
    req(template['rowCount']==42 and template['expectedLegalPairCount']==593,'covering template drift')
    req(constraints['currentClosure']['requiredLegalPairCountAllProcesses']==16011,'legal pair closure drift'); req(three['policy']['requiredGlobalTargetCount']==330,'3-wise closure drift'); req(system['requiredCount']==len(system['scenarios'])==36,'system-wide closure drift')
    req(fifth['counts']=={'high':6,'medium':2,'total':8,'resolved':8,'open':0},'fifth-pass audit drift'); req(sixth['counts']=={'high':7,'medium':3,'total':10,'resolved':10,'open':0},'sixth-pass audit drift'); req(seventh['counts']=={'high':5,'medium':5,'total':10,'resolved':10,'open':0},'seventh-pass audit drift')
    hp=handoff['runtimeEntryPolicy']; req(hp['exactAcceptedElv5SourceShaRequired'] and hp['exactAuthorityFingerprintRequired'] and hp['acceptedElv5RuntimeEvidenceRequiredBeforeElv6Runtime'],'downstream handoff weakened'); req(not hp['historicalDesignShaAloneMayAuthorizeRuntime'] and hp['databaseSchemaAtInitialElv5Entry']==24,'downstream handoff version/runtime policy drift')
    fixed=norm['fixedInventories']; req(fixed['designFindingsResolved']==56 and fixed['minimumProcessVectorCount']==135,'historical normative inventory drift')
    errata=(IMPL/'calculation-oracle-errata-v1.md').read_text(encoding='utf-8'); req('ERRATA-001 — ACS-03' in errata and '23.51 V' in errata and '+1.51 V' in errata,'ACS-03 errata missing')
    contracts=(IMPL/'process-contracts.md').read_text(encoding='utf-8'); acs=(IMPL/'process-specifications/acs-processes.md').read_text(encoding='utf-8'); req('23.45 V' not in contracts and 'lock23.45V' not in contracts and '23.45 V' not in acs and '+1.45 V' not in acs,'stale ACS-03 active oracle')
    baseline=(IMPL/'implemented-baseline.md').read_text(encoding='utf-8'); req('schema 23 → schema 24' in baseline and 'arbitrary version greater than 23' in baseline,'baseline schema-24 reconciliation missing')
    adr=(ROOT/'docs/adr/ADR-031-elv5-pure-core-and-module-boundary.md').read_text(encoding='utf-8'); req('repository-aware `resolveinput(...)` is not a method' in adr.lower() and 'exact source filenames are **tracked implementation coordinates**' in adr.lower(),'ADR-031 module/resolver boundary missing')
    dossier_rows=dossiers(); artifacts=[]
    for rel in AUTHORITY_PATHS:
        path=ROOT/rel; req(path.is_file(),f'missing authority artifact: {rel}'); artifacts.append({'path':rel,'sha256':hfile(path),'byteLength':path.stat().st_size})
    core={
      'manifestSchema':'electra.elv5-contract-manifest.v1','manifestCanonicalization':'utf8-json-sort-keys-separators-v1','hashAlgorithm':'SHA-256','engineeringCanonicalJsonVersion':'electra.canonical-json.v1','databaseSchemaVersion':24,'wireSchema':'electra.elv5-discipline-command.v1','payloadSchemaVersion':1,
      'processCount':27,'algorithmMappingCount':27,'processCodeLevelDossierCount':27,'processDossierSectionCount':25,'processVectorClassCount':5,'minimumProcessVectorCount':135,'primaryProcessOracleCount':54,
      'marketSimulationScenarioCount':450,'marketSimulationRequirementCount':12,'combinatorialScenarioCount':1500,'combinatorialRequirementCount':12,'combinatorialBaseRowCount':42,'combinatorialLegalPairCountPerProcess':593,'combinatorialLegalPairCountAllProcesses':16011,'combinatorialTargetedThreeWiseTemplateCount':30,'combinatorialTargetedThreeWiseCount':330,'combinatorialSystemWideCount':36,
      'commandCount':16,'requirementCount':80,'normativeObligationCount':42,'implementationBindingCount':27,'repositoryReadMethodCount':len(repo['readMethods']),'runtimeVersionCount':27,'algorithmPerformanceBindingCount':27,'findingTraceNamespaceCount':27,
      'historicalDesignFindingsResolvedThroughFourthPass':56,'fifthPassClosureFindingCount':8,'fifthPassOpenFindingCount':0,'sixthPassClosureFindingCount':10,'sixthPassOpenFindingCount':0,'seventhPassClosureFindingCount':10,'seventhPassOpenFindingCount':0,'downstreamReconciliationRequired':True,'authorityArtifactCount':len(AUTHORITY_PATHS),
      'processRegistrySha256':hfile(IMPL/'process-registry.json'),'algorithmRegistrySha256':hfile(IMPL/'algorithm-registry.json'),'commandRegistrySha256':hfile(IMPL/'command-registry.json'),'requirementsSha256':hfile(IMPL/'requirements.json'),'normativeRequirementsSha256':hfile(IMPL/'normative-requirements-registry.json'),'marketSimulationRequirementsSha256':hfile(IMPL/'market-simulation-requirements.json'),'marketSimulationCatalogSha256':hfile(IMPL/'market-simulation-catalog.json'),'marketSimulationP0P9BindingsSha256':hfile(IMPL/'market-simulation-p0-p9-bindings.json'),
      'implementedBaselineSha256':hfile(IMPL/'implemented-baseline.md'),'baselineEvidenceSha256':hfile(IMPL/'baseline.json'),'elv5ModuleBoundaryAdrSha256':hfile(ROOT/'docs/adr/ADR-031-elv5-pure-core-and-module-boundary.md'),
      'implementationBindingHardeningSha256':hfile(IMPL/'implementation-binding-hardening-v1.md'),'implementationBindingRegistrySha256':hfile(IMPL/'implementation-binding-registry.json'),'repositoryContractRegistrySha256':hfile(IMPL/'repository-contract-registry.json'),'runtimeVersionRegistrySha256':hfile(IMPL/'runtime-version-registry.json'),'algorithmPerformanceRegistrySha256':hfile(IMPL/'algorithm-performance-registry.json'),'findingTraceCodeRegistrySha256':hfile(IMPL/'finding-trace-code-registry.json'),'implementationBindingGuardSha256':hfile(ROOT/'scripts/ci/check-elv5-implementation-bindings.py'),'sixthPassAuditSha256':hfile(ROOT/'docs/audit/elv5-sixth-pass-code-binding-performance-audit.json'),
      'projectAlignmentHardeningSha256':hfile(IMPL/'project-alignment-hardening-v1.md'),'downstreamHandoffRegistrySha256':hfile(IMPL/'downstream-handoff-registry.json'),'projectAlignmentGuardSha256':hfile(ROOT/'scripts/ci/check-elv5-project-alignment.py'),'seventhPassAuditSha256':hfile(ROOT/'docs/audit/elv5-seventh-pass-project-alignment-audit.json'),'developmentRoadmapSha256':hfile(ROOT/'docs/product/development-roadmap.md'),
      'combinatorialRequirementsSha256':hfile(IMPL/'combinatorial-engineering-requirements.json'),'combinatorialPlanSha256':hfile(IMPL/'combinatorial-engineering-1500-plan.md'),'combinatorialLegalPairConstraintsSha256':hfile(IMPL/'combinatorial-legal-pair-constraints.json'),'combinatorialTargetedThreeWiseSha256':hfile(IMPL/'combinatorial-targeted-three-wise.json'),'combinatorialCoveringTemplateSha256':hfile(IMPL/'combinatorial-covering-template-v1.json'),'combinatorialSystemWideInventorySha256':hfile(IMPL/'combinatorial-system-wide-inventory.json'),'combinatorialGeneratorSha256':hfile(ROOT/'scripts/ci/generate-elv5-combinatorial-1500.py'),'fifthPassClosureAuditSha256':hfile(ROOT/'docs/audit/elv5-fifth-pass-specification-closure-audit.json'),
      'processDossierAggregateSha256':hbytes(cbytes(dossier_rows)),'calculationOracleErrataSha256':hfile(IMPL/'calculation-oracle-errata-v1.md'),'flutterPerformanceContractSha256':hfile(IMPL/'flutter-performance-contract.md'),'authorityArtifacts':artifacts,
    }
    fp=hbytes(cbytes(core)); out={**core,'authorityFingerprintSha256':fp,**provenance,'runtimeStatus':'NOT_STARTED','qualificationStatus':'NOT_EXECUTED','marketSimulationStatus':'DESIGN_SIMULATION_ONLY','combinatorialMatrixStatus':'DESIGN_MATRIX_ONLY_RUNTIME_NOT_EXECUTED','implementationBindingStatus':'DESIGN_FROZEN_RUNTIME_NOT_EXECUTED','projectAlignmentStatus':'ELV5_SPEC_CLOSED_DOWNSTREAM_RECONCILIATION_REQUIRED','note':'Exact-head authority fingerprint/design-entry evidence only; no ELV5 production runtime, ELV7 compliance or ELV8 procurement acceptance is claimed.'}
    return out


def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--output',required=True)
    ap.add_argument('--allow-dirty', action='store_true', help='Label uncommitted checks WORKTREE_PREVIEW; never exact-head evidence')
    args=ap.parse_args(); provenance=source_provenance(ROOT, allow_dirty=args.allow_dirty)
    out=build_manifest(provenance)
    req(source_provenance(ROOT, allow_dirty=args.allow_dirty)==provenance, 'Source changed during manifest generation')
    fp=out['authorityFingerprintSha256']; repo=load(IMPL/'repository-contract-registry.json')
    path=Path(args.output); path.parent.mkdir(parents=True,exist_ok=True); path.write_text(json.dumps(out,ensure_ascii=False,sort_keys=True,indent=2)+'\n',encoding='utf-8')
    print(f'ELV5 contract manifest generated: {path}'); print(f"sourceSha={out['sourceSha']}"); print(f'authorityFingerprintSha256={fp}'); print(f"processes=27 algorithms=27 commands=16 requirements=80 obligations=42 market=450 combinatorial=1500 pairs=16011 targeted3Wise=330 implementationBindings=27 repoMethods={len(repo['readMethods'])} fifthOpen=0 sixthOpen=0 seventhOpen=0 downstreamReconciliationRequired=1 authorityArtifacts={len(AUTHORITY_PATHS)}")
if __name__=='__main__': main()
