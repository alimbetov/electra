#!/usr/bin/env python3
"""Generate and validate the deterministic ELV5 1500-case combinatorial matrix."""
from __future__ import annotations
import argparse, json, os, subprocess
from collections import Counter
from hashlib import sha256
from itertools import combinations, product
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
IMPL = ROOT / "docs" / "product" / "elv5-implementation"
PATHS = {
    "req": IMPL / "combinatorial-engineering-requirements.json",
    "constraints": IMPL / "combinatorial-legal-pair-constraints.json",
    "three": IMPL / "combinatorial-targeted-three-wise.json",
    "template": IMPL / "combinatorial-covering-template-v1.json",
    "system": IMPL / "combinatorial-system-wide-inventory.json",
    "process": IMPL / "process-registry.json",
}
PRIORITY = ["CCTV-02","CCTV-03","LAN-01","LAN-05","ACS-03","ACS-04","ACS-05","FA-02","FA-04","FA-05","FA-06"]

def load(path): return json.loads(path.read_text(encoding="utf-8"))
def require(ok, msg):
    if not ok: raise SystemExit(msg)
def cbytes(v): return json.dumps(v, ensure_ascii=False, sort_keys=True, separators=(",",":")).encode()
def digest(v): return sha256(cbytes(v)).hexdigest()
def source_sha():
    if os.getenv("GITHUB_SHA"): return os.environ["GITHUB_SHA"]
    try: return subprocess.check_output(["git","rev-parse","HEAD"], cwd=ROOT, text=True).strip()
    except (OSError, subprocess.CalledProcessError): return "UNKNOWN"

def all_pairs(factors):
    names=list(factors); out=set()
    for a,b in combinations(names,2):
        out |= {(a,va,b,vb) for va,vb in product(factors[a],factors[b])}
    return out

def row_pairs(factors,row):
    names=list(factors)
    return {(a,row[a],b,row[b]) for a,b in combinations(names,2)}

def pair_key(factors,a,va,b,vb):
    names=list(factors)
    return (a,va,b,vb) if names.index(a)<names.index(b) else (b,vb,a,va)

def excluded(process_code,constraints,factors):
    rows=list(constraints.get("globalExcludedPairs",[]))
    rows += constraints["processOverrides"][process_code].get("excludedPairs",[])
    reason_codes={x["code"] for x in constraints["reasonCodes"]}
    out=set()
    for x in rows:
        a,b,va,vb,reason=x.get("factorA"),x.get("factorB"),x.get("valueA"),x.get("valueB"),x.get("reasonCode")
        require(a in factors and b in factors and a!=b, f"invalid excluded pair factors: {process_code} {x}")
        require(va in factors[a] and vb in factors[b], f"invalid excluded pair values: {process_code} {x}")
        require(reason in reason_codes, f"unknown exclusion reason: {process_code} {reason}")
        out.add(pair_key(factors,a,va,b,vb))
    return out

def variant(vector):
    return {
        "POSITIVE":"POSITIVE_CONTROL",
        "BOUNDARY":"EXACT_BOUNDARY",
        "NEGATIVE_OR_UNSUPPORTED":"DEFECT_OR_UNSUPPORTED_ACTIVE",
        "ADVERSARIAL":"ADVERSARIAL_MUTATION",
        "CROSS_DISCIPLINE":"CROSS_DISCIPLINE_INTERACTION",
    }[vector]

def base_rows(req,template):
    factors=req["factorModel"]; cols=template["columnOrder"]; rows=[]
    require(set(cols)==set(factors), "covering-template factor inventory drift")
    require(template["rowCount"]==len(template["rows"])==42, "covering template must contain 42 rows")
    require(template["levelCounts"]==[len(factors[n]) for n in cols], "covering template level-count drift")
    for ri,cells in enumerate(template["rows"],1):
        require(len(cells)==8, f"template row {ri} width mismatch")
        row={}
        for ci,name in enumerate(cols):
            cell=cells[ci]
            require(isinstance(cell,int) and 0<=cell<len(factors[name]), f"template row {ri} invalid {name} index")
            row[name]=factors[name][cell]
        rows.append(row)
    return rows

def targets(three,factors):
    result=[]; ids=set()
    for family in three["families"]:
        names=family["factors"]
        require(len(names)==3 and len(set(names))==3 and all(n in factors for n in names), f"invalid 3-wise family {family['id']}")
        for target in family["targets"]:
            tid=target["id"]; vals=target["values"]
            require(tid not in ids and len(vals)==3, f"invalid/duplicate 3-wise target {tid}")
            require(all(v in factors[n] for n,v in zip(names,vals)), f"invalid values in 3-wise target {tid}")
            ids.add(tid); result.append({"id":tid,"familyId":family["id"],"factors":names,"values":vals})
    require(len(result)==30, f"expected 30 3-wise templates, found {len(result)}")
    return result

def target_row(factors,target,process_index,target_index):
    row={name: vals[(process_index*7+target_index*3+len(name))%len(vals)] for name,vals in factors.items()}
    for name,value in zip(target["factors"],target["values"]): row[name]=value
    return row

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--output",type=Path,required=True)
    ap.add_argument("--authority-manifest",type=Path)
    args=ap.parse_args()
    req,constraints,three,template,system,process=[load(PATHS[k]) for k in ("req","constraints","three","template","system","process")]
    require(req["scenarioTarget"]==1500 and req["priorityProcessMinimum"]==72 and req["regularProcessMinimum"]==42 and req["systemWideScenarioCount"]==36, "1500 distribution contract drift")
    require(req["priorityComputationalCore"]==PRIORITY, "priority inventory drift")
    require(constraints["schema"]=="electra.elv5-combinatorial-legal-pairs.v1" and constraints["policy"]["silentExclusionAllowed"] is False, "legal-pair policy drift")
    require(three["schema"]=="electra.elv5-combinatorial-targeted-three-wise.v1" and three["appliesToPriorityProcesses"]==PRIORITY, "3-wise registry drift")
    require(system["schema"]=="electra.elv5-combinatorial-system-wide.v1", "system-wide registry drift")

    codes=[x["code"] for x in process["processes"]]
    require(len(codes)==len(set(codes))==27 and set(PRIORITY)<=set(codes), "process inventory drift")
    regular=sorted(set(codes)-set(PRIORITY))
    require(len(regular)==16 and set(constraints["processOverrides"])==set(codes), "process/constraint inventory drift")
    factors=req["factorModel"]
    require(len(factors)==8, "factor inventory must contain eight factors")
    universe=all_pairs(factors)
    require(len(universe)==593, f"expected 593 factor-value pairs, found {len(universe)}")

    base=base_rows(req,template)
    base_cov=set().union(*(row_pairs(factors,r) for r in base))
    require(base_cov==universe and template["expectedLegalPairCount"]==593, f"42-row strength-2 proof failed: {len(base_cov)}/593")
    target_list=targets(three,factors)
    require(three["policy"]["requiredGlobalTargetCount"]==330, "3-wise global target must be 330")

    scenarios=[]; counts=Counter(); pair_metrics={}; t3_cov={}
    for pi,code in enumerate(sorted(codes)):
        ex=excluded(code,constraints,factors); legal=universe-ex
        require(not(base_cov & ex), f"base template contains excluded pair for {code}")
        rows=[]
        for i,row in enumerate(base,1):
            rows.append(row); counts[code]+=1
            scenarios.append({"caseId":f"COMB-{code}-P2-{i:03d}","scenarioKind":"PAIRWISE_BASE","processCode":code,"factors":row,"variantMode":variant(row["vectorClass"]),"claimScope":"QUALIFICATION_DESIGN_MATRIX_RUNTIME_NOT_EXECUTED"})
        covered_targets=[]
        if code in PRIORITY:
            for ti,target in enumerate(target_list):
                row=target_row(factors,target,pi,ti)
                require(not(row_pairs(factors,row)&ex), f"3-wise target {target['id']} violates excluded pair for {code}")
                rows.append(row); counts[code]+=1; covered_targets.append(target["id"])
                scenarios.append({"caseId":f"COMB-{code}-T3-{ti+1:03d}","scenarioKind":"TARGETED_THREE_WISE","processCode":code,"targetId":target["id"],"targetFamilyId":target["familyId"],"factors":row,"variantMode":variant(row["vectorClass"]),"claimScope":"QUALIFICATION_DESIGN_MATRIX_RUNTIME_NOT_EXECUTED"})
        t3_cov[code]=covered_targets
        covered=set().union(*(row_pairs(factors,r) for r in rows))
        require(legal<=covered, f"{code} pairwise incomplete {len(legal&covered)}/{len(legal)}")
        pair_metrics[code]={"unconstrainedPairCount":593,"excludedPairCount":len(ex),"legalPairCount":len(legal),"coveredLegalPairCount":len(legal&covered),"pairwiseCoveragePercent":100.0}

    require(all(counts[c]==72 for c in PRIORITY), "priority scenario count drift")
    require(all(counts[c]==42 for c in regular), "regular scenario count drift")
    sysrows=system["scenarios"]
    require(system["requiredCount"]==len(sysrows)==36 and [x["id"] for x in sysrows]==[f"SYS-{i:03d}" for i in range(1,37)], "system-wide inventory must be SYS-001..SYS-036")
    for x in sysrows:
        require(x.get("title") and x.get("packages"), f"incomplete system scenario {x.get('id')}")
        scenarios.append({"caseId":f"COMB-{x['id']}","scenarioKind":"SYSTEM_WIDE","systemScenarioId":x["id"],"title":x["title"],"packages":x["packages"],"claimScope":"QUALIFICATION_DESIGN_MATRIX_RUNTIME_NOT_EXECUTED"})

    require(len(scenarios)==len({x["caseId"] for x in scenarios})==1500, "scenario count/id uniqueness failure")
    require(sum(counts.values())==1464, "per-process subtotal must be 1464")
    legal_count=sum(x["legalPairCount"] for x in pair_metrics.values())
    covered_count=sum(x["coveredLegalPairCount"] for x in pair_metrics.values())
    excluded_count=sum(x["excludedPairCount"] for x in pair_metrics.values())
    require(legal_count==covered_count==16011 and excluded_count==0, f"pair closure drift legal={legal_count} covered={covered_count} excluded={excluded_count}")
    t3_count=sum(len(x) for x in t3_cov.values())
    require(t3_count==330 and all(len(t3_cov[c])==30 for c in PRIORITY), f"targeted 3-wise closure drift: {t3_count}")

    authority=None
    if args.authority_manifest:
        m=load(args.authority_manifest)
        require(m["sourceSha"]==source_sha(), "authority manifest source SHA mismatch")
        authority=m.get("authorityFingerprintSha256")
        require(isinstance(authority,str) and len(authority)==64, "authority fingerprint missing/invalid")

    inputs={"requirements":req,"constraints":constraints,"threeWise":three,"template":template,"systemWide":system}
    core={
        "schema":"electra.elv5-combinatorial-qualification.v1",
        "generationVersion":"electra.elv5-combinatorial-generator.v1",
        "status":"DESIGN_MATRIX_GENERATED_RUNTIME_NOT_EXECUTED",
        "sourceSha":source_sha(),
        "authorityFingerprint":authority,
        "qualificationContractFingerprintSha256":digest(inputs),
        "scenarioCount":1500,"processCount":27,"priorityProcessCount":11,"regularProcessCount":16,
        "priorityProcessScenarioCount":72,"regularProcessScenarioCount":42,"systemWideScenarioCount":36,
        "factorInventory":factors,
        "legalPairCountPerProcessCurrentClosure":593,
        "legalPairCount":legal_count,"coveredLegalPairCount":covered_count,"pairwiseCoveragePercent":100.0,"excludedPairCount":excluded_count,
        "targetedThreeWiseTemplateCount":30,"targetedThreeWiseLegalCount":330,"targetedThreeWiseCoveredCount":t3_count,
        "processScenarioCounts":dict(sorted(counts.items())),"pairwiseMetricsByProcess":pair_metrics,"targetedThreeWiseCoverageByProcess":t3_cov,
        "runtimeExecuted":False,
        "claimScope":"Design matrix generation and coverage proof only; production ELV5 Dart kernels have not executed this matrix.",
    }
    result={**core,"scenarioMatrixFingerprintSha256":digest(scenarios),"scenarios":scenarios}
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(result,ensure_ascii=False,sort_keys=True,indent=2)+"\n",encoding="utf-8")
    print("ELV5 deterministic 1500-case combinatorial matrix PASS")
    print("scenarios=1500 processSubtotal=1464 systemWide=36 priority=11x72 regular=16x42")
    print(f"pairwise={covered_count}/{legal_count}=100% targeted3Wise={t3_count}/330")
    print(f"matrixFingerprintSha256={result['scenarioMatrixFingerprintSha256']}")
    print("runtimeExecuted=0")

if __name__=="__main__": main()
