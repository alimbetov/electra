#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REGISTRY = ROOT / "docs/product/elv5-implementation/environment-profile-contract-registry.json"
DOC = ROOT / "docs/product/elv5-implementation/environment-profile-ampacity-amendment.md"
CORE = ROOT / "packages/engineering_core/lib/src/elv5/evidence/environment_profile.dart"
ROUTE = ROOT / "packages/engineering_core/lib/src/elv5/evidence/route_ampacity_contract.dart"
STORE = ROOT / "apps/mobile/lib/data/repositories/elv5/drift_environment_profile_store.dart"
RESOLVER = ROOT / "apps/mobile/lib/data/repositories/elv5/drift_environment_scope_resolver.dart"
AMPACITY_RESOLVER = ROOT / "apps/mobile/lib/application/elv5/environment/ampacity_route_resolver.dart"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"ELV5 environment profile guard failed: {message}")


def main() -> None:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    require(registry["processInventoryChange"] == 0, "must not create process 28")
    require(registry["databaseSchemaChange"] == 0, "must not bump frozen schema")
    require(
        registry["precedence"] == ["ROUTE_SECTION", "ROOM", "MISSING"],
        "scope precedence drifted",
    )
    require(
        registry["roomClassificationIsEngineeringEvidence"] is False,
        "room type/category must remain metadata only",
    )
    require(
        registry["ampacityTemperatureSelection"] == "PROFILE_MAXIMUM_AMBIENT",
        "ampacity temperature selection drifted",
    )
    require(
        registry["routeAmpacityEquation"] == "Iz(run) = min(Iz(section_i))",
        "route ampacity equation drifted",
    )

    doc = DOC.read_text(encoding="utf-8")
    core = CORE.read_text(encoding="utf-8")
    route = ROUTE.read_text(encoding="utf-8")
    store = STORE.read_text(encoding="utf-8")
    resolver = RESOLVER.read_text(encoding="utf-8")
    ampacity_resolver = AMPACITY_RESOLVER.read_text(encoding="utf-8")

    for token in (
        "Room.roomType",
        "Room.roomCategory",
        "ROUTE_SECTION explicit profile",
        "ROOM explicit profile",
        "Iz(run) = min(Iz(section_i))",
        "relative humidity",
        "condensation",
    ):
        require(token in doc, f"amendment missing {token!r}")

    for symbol in (
        "Elv5EnvironmentProfile",
        "Elv5EnvironmentScopeBinding",
        "Elv5CondensationRisk",
        "Elv5EnvironmentExposure",
    ):
        require(symbol in core, f"core contract missing {symbol}")

    require("profile.temperatureC.maximum" in route, "route ampacity must use profile maximum")
    require("results.sort" in route, "route ampacity must select deterministic governing section")
    require("ELV5_ENVIRONMENT_PROFILE" in store, "immutable environment persistence missing")
    require("ROUTE_SECTION" in resolver and "ROOM" in resolver, "scope precedence resolver missing")
    require(
        resolver.index("scopeKind: 'ROUTE_SECTION'") < resolver.index("scopeKind: 'ROOM'"),
        "ROUTE_SECTION lookup must precede ROOM fallback",
    )
    require("roomType" not in resolver and "roomCategory" not in resolver, "resolver must not infer environment from room classification")

    for token in (
        "Elv5AmpacityRouteResolver",
        "ELV5_AMPACITY_ENVIRONMENT_PROFILE_REQUIRED",
        "ELV5_AMPACITY_SECTION_EVIDENCE_REQUIRED",
        "ELV5_AMPACITY_TEMPERATURE_EVIDENCE_SCOPE_MISMATCH",
        "temperatureC.maximum",
    ):
        require(token in ampacity_resolver, f"ampacity route resolver missing {token!r}")

    print("ELV5 environment profile contract: PASS")


if __name__ == "__main__":
    main()
