#!/usr/bin/env python3
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STATUS = ROOT / "docs/product/elv5-implementation/engineering-foundation-f1-f2-status.json"

EXPECTED_PILOTS = {"AMPACITY_ROUTE_IZ", "FA-03", "ACS-03", "CCTV-03", "LAN-05"}
MANDATORY_Q = {f"Q{i}" for i in range(9)}


def fail(message: str) -> None:
    raise SystemExit(f"ELV5 foundation F1/F2 status guard: {message}")


def main() -> None:
    data = json.loads(STATUS.read_text(encoding="utf-8"))
    if data.get("schema") != "electra.engineering-foundation-f1-f2-status.v1":
        fail("unexpected schema")
    if data.get("acceptanceClaimed") is not False:
        fail("acceptanceClaimed must stay false until exact-SHA acceptance exists")

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

    f2 = data["foundationStages"]["F2"]
    pilots = f2["pilots"]
    pilot_ids = {p["id"] for p in pilots}
    if pilot_ids != EXPECTED_PILOTS:
        fail(f"F2 pilot set mismatch: {sorted(pilot_ids)}")

    for pilot in pilots:
        q = pilot["qualification"]
        missing = MANDATORY_Q.difference(q)
        if missing:
            fail(f"{pilot['id']} missing mandatory qualification keys: {sorted(missing)}")
        lifecycle = pilot["lifecycle"]
        incomplete = any(q[key] not in {"PASS", "NOT_APPLICABLE"} for key in MANDATORY_Q)
        if lifecycle in {"QUALIFIED", "ACCEPTED"} and incomplete:
            fail(f"{pilot['id']} claims {lifecycle} before Q0-Q8 are closed")
        if lifecycle == "ACCEPTED" and q.get("Q9") not in {"PASS", "NOT_APPLICABLE"}:
            fail(f"{pilot['id']} accepted without closed Q9 applicability")

    if f2.get("exitGateSatisfied") is True:
        for pilot in pilots:
            if pilot["lifecycle"] not in {"QUALIFIED", "ACCEPTED"}:
                fail("F2 exit gate cannot be true before every pilot is qualified")

    print(
        f"ELV5 foundation F1/F2 status OK: runtime={integrated}/{total}, "
        f"remaining={remaining}, pilots={len(pilots)}"
    )


if __name__ == "__main__":
    main()
