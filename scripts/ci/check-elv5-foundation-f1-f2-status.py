#!/usr/bin/env python3
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "docs/product/elv5-implementation"
STATUS = BASE / "engineering-foundation-f1-f2-status.json"
PROCESS_REGISTRY = BASE / "process-registry.json"

LEGACY_PILOTS = {"AMPACITY_ROUTE_IZ", "FA-03", "ACS-03", "CCTV-03", "LAN-05"}
MANDATORY_Q = tuple(f"Q{i}" for i in range(10))
CLOSED_Q = {
    "PASS",
    "PASS_SOURCE",
    "PASS_PRODUCTION_PATH",
    "PASS_RESTART_AND_CONCURRENCY",
    "PASS_HISTORICAL_REPLAY",
    "PASS_BOUNDED",
    "NOT_APPLICABLE",
}
OPEN_Q = {
    "PENDING",
    "SOURCE_PENDING_CI",
    "PRODUCTION_PATH_PENDING",
    "RESTART_AND_CONCURRENCY_PENDING",
    "HISTORICAL_REPLAY_PENDING",
    "BOUNDED_PENDING",
}
VALID_Q = CLOSED_Q | OPEN_Q
VALID_LIFECYCLE = {
    "RUNTIME_INTEGRATED",
    "SOURCE_QUALIFIED_CI_PENDING",
    "PRODUCTION_LIFECYCLE_SOURCE_COMPLETE_CI_PENDING",
    "QUALIFIED",
    "ACCEPTED",
}
VALID_RESULT = {"PENDING", "PENDING_EXACT_SHA", "QUALIFIED", "ACCEPTED"}
WITNESS_KEYS = ("sourceWitnesses", "persistenceWitnesses", "replayWitnesses", "freezeWitnesses")


def fail(message: str) -> None:
    raise SystemExit(f"ELV5 foundation F1/F2 status guard: {message}")


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def validate_runtime(data: dict) -> tuple[int, int, int]:
    runtime = data["runtimeBaseline"]
    total = runtime["processCount"]
    integrated = runtime["productionAdapters"]
    remaining = runtime["remainingAdapters"]
    if total != 27:
        fail(f"ELV5 process count drifted: {total}")
    if integrated + remaining != total:
        fail("productionAdapters + remainingAdapters must equal processCount")
    by_discipline = runtime["byDiscipline"]
    discipline_total = sum(v["total"] for v in by_discipline.values())
    discipline_integrated = sum(v["integrated"] for v in by_discipline.values())
    if discipline_total != total:
        fail("discipline totals do not equal 27")
    if discipline_integrated != integrated:
        fail("discipline integrated counts do not equal productionAdapters")
    if len(runtime["remaining"]) != remaining:
        fail("remaining list length does not equal remainingAdapters")
    if len(set(runtime["remaining"])) != len(runtime["remaining"]):
        fail("remaining process list contains duplicates")
    return total, integrated, remaining


def validate_legacy_v1(data: dict) -> int:
    f2 = data["foundationStages"]["F2"]
    pilots = f2["pilots"]
    pilot_ids = {p["id"] for p in pilots}
    if pilot_ids != LEGACY_PILOTS:
        fail(f"F2 pilot set mismatch: {sorted(pilot_ids)}")
    mandatory_q = set(MANDATORY_Q[:-1])
    for pilot in pilots:
        q = pilot["qualification"]
        missing = mandatory_q.difference(q)
        if missing:
            fail(f"{pilot['id']} missing mandatory qualification keys: {sorted(missing)}")
        lifecycle = pilot["lifecycle"]
        incomplete = any(q[key] not in {"PASS", "NOT_APPLICABLE"} for key in mandatory_q)
        if lifecycle in {"QUALIFIED", "ACCEPTED"} and incomplete:
            fail(f"{pilot['id']} claims {lifecycle} before Q0-Q8 are closed")
        if lifecycle == "ACCEPTED" and q.get("Q9") not in {"PASS", "NOT_APPLICABLE"}:
            fail(f"{pilot['id']} accepted without closed Q9 applicability")
    if f2.get("exitGateSatisfied") is True:
        for pilot in pilots:
            if pilot["lifecycle"] not in {"QUALIFIED", "ACCEPTED"}:
                fail("F2 exit gate cannot be true before every pilot is qualified")
    return len(pilots)


def validate_witnesses(process_code: str, evidence: dict) -> None:
    for key in WITNESS_KEYS:
        value = evidence.get(key)
        if not isinstance(value, list):
            fail(f"{process_code} evidence.{key} must be a list")
        if len(value) != len(set(value)):
            fail(f"{process_code} evidence.{key} contains duplicates")
        for relative in value:
            if not isinstance(relative, str) or not relative:
                fail(f"{process_code} evidence.{key} contains an invalid path")
            if not (ROOT / relative).is_file():
                fail(f"{process_code} witness does not exist: {relative}")


def validate_matrix_v2(data: dict) -> tuple[int, int]:
    registry = load(PROCESS_REGISTRY)
    expected = {row["code"] for row in registry["processes"]}
    if len(expected) != 27:
        fail(f"canonical process registry must contain 27 codes, found {len(expected)}")

    f2 = data["foundationStages"]["F2"]
    matrix = f2.get("processQualificationMatrix")
    if not isinstance(matrix, list):
        fail("F2 processQualificationMatrix must be a list")
    codes = [row.get("processCode") for row in matrix]
    if len(codes) != 27 or len(set(codes)) != 27:
        fail("F2 processQualificationMatrix must contain exactly 27 unique process codes")
    if set(codes) != expected:
        missing = sorted(expected.difference(codes))
        extra = sorted(set(codes).difference(expected))
        fail(f"F2 matrix differs from canonical process registry; missing={missing}, extra={extra}")

    qualified = 0
    production_lifecycle = 0
    for row in matrix:
        code = row["processCode"]
        lifecycle = row.get("lifecycle")
        result = row.get("result")
        if lifecycle not in VALID_LIFECYCLE:
            fail(f"{code} has invalid lifecycle {lifecycle!r}")
        if result not in VALID_RESULT:
            fail(f"{code} has invalid result {result!r}")

        q = row.get("qualification")
        if not isinstance(q, dict) or set(q) != set(MANDATORY_Q):
            fail(f"{code} must declare exactly Q0..Q9")
        invalid = {key: value for key, value in q.items() if value not in VALID_Q}
        if invalid:
            fail(f"{code} has invalid qualification statuses: {invalid}")

        evidence = row.get("evidence")
        if not isinstance(evidence, dict):
            fail(f"{code} evidence must be an object")
        validate_witnesses(code, evidence)

        all_closed = all(q[key] in CLOSED_Q for key in MANDATORY_Q)
        exact_identity = all(
            isinstance(evidence.get(key), str)
            and len(evidence[key]) in ({40, 64} if key == "sourceSha" else {64})
            and all(ch in "0123456789abcdef" for ch in evidence[key])
            for key in ("sourceSha", "authorityFingerprint")
        ) and all(
            isinstance(evidence.get(key), str) and bool(evidence[key].strip())
            for key in ("processVersion", "rulesetVersion")
        )

        if q["Q6"] == "PASS_PRODUCTION_PATH":
            production_lifecycle += 1
            if not evidence["persistenceWitnesses"]:
                fail(f"{code} Q6 production path lacks persistence witness")
        if q["Q7"] == "PASS_RESTART_AND_CONCURRENCY" and not evidence["replayWitnesses"]:
            fail(f"{code} Q7 lacks replay/restart witness")
        if q["Q8"] == "PASS_HISTORICAL_REPLAY" and not evidence["freezeWitnesses"]:
            fail(f"{code} Q8 lacks freeze/historical witness")

        claims_qualified = lifecycle in {"QUALIFIED", "ACCEPTED"} or result in {"QUALIFIED", "ACCEPTED"}
        if claims_qualified and not all_closed:
            fail(f"{code} claims qualification before Q0..Q9 are closed")
        if claims_qualified and not exact_identity:
            fail(f"{code} claims qualification without exact source/authority/process/ruleset identity")
        if lifecycle == "ACCEPTED" and result != "ACCEPTED":
            fail(f"{code} lifecycle ACCEPTED requires result ACCEPTED")
        if result == "ACCEPTED" and lifecycle != "ACCEPTED":
            fail(f"{code} result ACCEPTED requires lifecycle ACCEPTED")
        if result in {"QUALIFIED", "ACCEPTED"}:
            qualified += 1

    summary = f2.get("matrixSummary")
    if not isinstance(summary, dict):
        fail("F2 matrixSummary must be an object")
    expected_summary = {
        "processCount": 27,
        "qualified": qualified,
        "productionLifecycleCovered": production_lifecycle,
        "pending": 27 - qualified,
    }
    if summary != expected_summary:
        fail(f"F2 matrixSummary mismatch: expected {expected_summary}, found {summary}")

    cross_cutting = f2.get("crossCuttingQualifications")
    if not isinstance(cross_cutting, list):
        fail("F2 crossCuttingQualifications must be a list")
    if {row.get("id") for row in cross_cutting} != {"AMPACITY_ROUTE_IZ"}:
        fail("AMPACITY_ROUTE_IZ must remain the sole declared cross-cutting qualification")
    if "AMPACITY_ROUTE_IZ" in expected:
        fail("AMPACITY_ROUTE_IZ must not be counted as one of the 27 process codes")

    if f2.get("exitGateSatisfied") is True and qualified != 27:
        fail("F2 exit gate cannot be true before all 27 processes are qualified")
    return qualified, production_lifecycle


def main() -> None:
    data = load(STATUS)
    schema = data.get("schema")
    if schema not in {
        "electra.engineering-foundation-f1-f2-status.v1",
        "electra.engineering-foundation-f1-f2-status.v2",
    }:
        fail("unexpected schema")
    if data.get("acceptanceClaimed") is not False:
        fail("acceptanceClaimed must stay false until exact-SHA acceptance exists")

    total, integrated, remaining = validate_runtime(data)
    if schema.endswith(".v1"):
        pilots = validate_legacy_v1(data)
        print(
            f"ELV5 foundation F1/F2 status OK (legacy v1): runtime={integrated}/{total}, "
            f"remaining={remaining}, pilots={pilots}"
        )
        return

    qualified, production_lifecycle = validate_matrix_v2(data)
    print(
        f"ELV5 foundation F1/F2 status OK: runtime={integrated}/{total}, remaining={remaining}, "
        f"matrix=27, qualified={qualified}, productionLifecycleCovered={production_lifecycle}"
    )


if __name__ == "__main__":
    main()
