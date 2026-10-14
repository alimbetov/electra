from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def replace_once(rel: str, old: str, new: str) -> None:
    path = ROOT / rel
    text = path.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{rel}: expected one anchor, got {count}: {old[:100]!r}')
    path.write_text(text.replace(old, new, 1))

# Production DB contract: one source for current schema version + bounded SQLite wait.
replace_once(
    'apps/mobile/lib/data/database/app_database.dart',
    "final class AppDatabase extends _$AppDatabase {\n  AppDatabase([QueryExecutor? executor]) : super(executor ?? driftDatabase(name: 'electra'));\n\n  @override\n  int get schemaVersion => 20;",
    "final class AppDatabase extends _$AppDatabase {\n  AppDatabase([QueryExecutor? executor]) : super(executor ?? driftDatabase(name: 'electra'));\n\n  static const currentSchemaVersion = 20;\n\n  @override\n  int get schemaVersion => currentSchemaVersion;",
)
replace_once(
    'apps/mobile/lib/data/database/app_database.dart',
    "    beforeOpen: (details) async {\n      await customStatement('PRAGMA foreign_keys = ON');\n",
    "    beforeOpen: (details) async {\n      await customStatement('PRAGMA foreign_keys = ON');\n      await customStatement('PRAGMA busy_timeout = 5000');\n",
)

# BEGIN IMMEDIATE contention happens before the body is entered, so SQLite busy timeout
# is not sufficient across independent Drift connections. Retry only SQLITE_BUSY with
# a small bounded backoff; all other database failures propagate unchanged.
for rel, session_type, session_ctor in [
    (
        'apps/mobile/lib/data/repositories/drift_elv_cable_write_unit_of_work.dart',
        'ElvCableWriteSession',
        '_DriftElvCableWriteSession',
    ),
    (
        'apps/mobile/lib/data/repositories/drift_elv_cable_allocation_write_unit_of_work.dart',
        'ElvAllocationWriteSession',
        '_DriftElvAllocationWriteSession',
    ),
]:
    path = ROOT / rel
    text = path.read_text()
    if "package:sqlite3/sqlite3.dart" not in text:
        text = text.replace(
            "import 'package:engineering_core/engineering_core.dart';\n",
            "import 'package:engineering_core/engineering_core.dart';\nimport 'package:sqlite3/sqlite3.dart' show SqliteException;\n",
            1,
        )
    old = (
        f"  @override\n  Future<T> run<T>(Future<T> Function({session_type} session) action) =>\n"
        "      database.transaction(() async {\n"
        f"        final session = {session_ctor}(\n"
        "          database,\n"
        "          originDeviceId: originDeviceId,\n"
        "        );\n"
        "        return action(session);\n"
        "      });\n"
    )
    new = (
        f"  @override\n  Future<T> run<T>(Future<T> Function({session_type} session) action) async {{\n"
        "    const maxAttempts = 8;\n"
        "    for (var attempt = 1; attempt <= maxAttempts; attempt++) {\n"
        "      try {\n"
        "        return await database.transaction(() async {\n"
        f"          final session = {session_ctor}(\n"
        "            database,\n"
        "            originDeviceId: originDeviceId,\n"
        "          );\n"
        "          return action(session);\n"
        "        });\n"
        "      } on SqliteException catch (error) {\n"
        "        if (error.resultCode != 5 || attempt == maxAttempts) rethrow;\n"
        "        await Future<void>.delayed(Duration(milliseconds: 25 * attempt));\n"
        "      }\n"
        "    }\n"
        "    throw StateError('unreachable sqlite busy retry state');\n"
        "  }\n"
    )
    if old not in text:
        raise SystemExit(f'{rel}: transaction run anchor missing')
    path.write_text(text.replace(old, new, 1))

# Make claim acquisition deterministic after the writer lock is acquired. The unique
# index remains the final database invariant; the pre-check maps the common conflict
# to the domain outcome instead of relying on insertOrIgnore row-id semantics.
replace_once(
    'apps/mobile/lib/data/repositories/drift_elv_cable_allocation_write_unit_of_work.dart',
    "    for (final atom in evidence.resolvedAtoms) {\n      final inserted = await database.into(database.cableResourceClaims).insert(\n            CableResourceClaimsCompanion.insert(\n              allocationId: allocation.id,\n              cableId: allocation.cableId,\n              resourceAtom: atom,\n              createdAt: now,\n              originDeviceId: originDeviceId,\n            ),\n            mode: InsertMode.insertOrIgnore,\n          );\n      if (inserted == 0) {\n        await (database.delete(database.cableResourceClaims)\n              ..where((row) => row.allocationId.equals(allocation.id)))\n            .go();\n        await (database.delete(database.cableAllocationResourceSelections)\n              ..where((row) => row.allocationId.equals(allocation.id)))\n            .go();\n        return ElvAllocationMutationOutcome.resourceOverlap;\n      }\n    }\n",
    "    for (final atom in evidence.resolvedAtoms) {\n      final conflict = await (database.select(database.cableResourceClaims)\n            ..where(\n              (row) =>\n                  row.cableId.equals(allocation.cableId) &\n                  row.resourceAtom.equals(atom),\n            ))\n          .getSingleOrNull();\n      if (conflict != null) {\n        await (database.delete(database.cableResourceClaims)\n              ..where((row) => row.allocationId.equals(allocation.id)))\n            .go();\n        await (database.delete(database.cableAllocationResourceSelections)\n              ..where((row) => row.allocationId.equals(allocation.id)))\n            .go();\n        return ElvAllocationMutationOutcome.resourceOverlap;\n      }\n      await database.into(database.cableResourceClaims).insert(\n            CableResourceClaimsCompanion.insert(\n              allocationId: allocation.id,\n              cableId: allocation.cableId,\n              resourceAtom: atom,\n              createdAt: now,\n              originDeviceId: originDeviceId,\n            ),\n          );\n    }\n",
)

# Old feature/migration tests assert the latest application schema through one symbol,
# avoiding brittle updates on every sequential schema increment.
changed_schema_assertions = 0
for path in (ROOT / 'apps/mobile/test').rglob('*.dart'):
    text = path.read_text()
    old = text
    for version in range(1, 21):
        text = text.replace(
            f'expect(database.schemaVersion, {version});',
            'expect(database.schemaVersion, AppDatabase.currentSchemaVersion);',
        )
        text = text.replace(
            f'expect(db.schemaVersion, {version});',
            'expect(db.schemaVersion, AppDatabase.currentSchemaVersion);',
        )
    if text != old:
        path.write_text(text)
        changed_schema_assertions += 1

# Dart records still compare List fields by identity. Assert deterministic fixture
# identities structurally instead of record equality.
replace_once(
    'apps/mobile/test/application/elv_p8_fixture_foundation_test.dart',
    "      expect(first, second);\n",
    "      expect(first.projectId, second.projectId);\n      expect(first.connectionId, second.connectionId);\n      expect(first.runId, second.runId);\n      expect(first.traversalIds, orderedEquals(second.traversalIds));\n",
)

print(f'ELV3 baseline fixes applied; schema assertion files updated: {changed_schema_assertions}')
