from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def replace_once(rel: str, old: str, new: str) -> None:
    path = ROOT / rel
    text = path.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{rel}: expected one anchor, got {count}: {old[:100]!r}')
    path.write_text(text.replace(old, new, 1))


def replace_all(rel: str, old: str, new: str) -> int:
    path = ROOT / rel
    text = path.read_text()
    count = text.count(old)
    if count:
        path.write_text(text.replace(old, new))
    return count

# Production DB contract: one source for current schema version + bounded SQLite wait.
replace_once(
    'apps/mobile/lib/data/database/app_database.dart',
    "final class AppDatabase extends _$AppDatabase {\n  AppDatabase([QueryExecutor? executor]) : super(executor ?? driftDatabase(name: 'electra'));\n\n  @override\n  int get schemaVersion => 19;",
    "final class AppDatabase extends _$AppDatabase {\n  AppDatabase([QueryExecutor? executor]) : super(executor ?? driftDatabase(name: 'electra'));\n\n  static const currentSchemaVersion = 20;\n\n  @override\n  int get schemaVersion => currentSchemaVersion;",
)
replace_once(
    'apps/mobile/lib/data/database/app_database.dart',
    "    beforeOpen: (details) async {\n      await customStatement('PRAGMA foreign_keys = ON');\n",
    "    beforeOpen: (details) async {\n      await customStatement('PRAGMA foreign_keys = ON');\n      await customStatement('PRAGMA busy_timeout = 5000');\n",
)

# Make claim acquisition deterministic after the writer lock is acquired. The unique
# index remains the final database invariant; the pre-check maps the common conflict
# to the domain outcome instead of relying on insertOrIgnore row-id semantics.
replace_once(
    'apps/mobile/lib/data/repositories/drift_elv_cable_allocation_write_unit_of_work.dart',
    "    for (final atom in evidence.resolvedAtoms) {\n      final inserted = await database.into(database.cableResourceClaims).insert(\n            CableResourceClaimsCompanion.insert(\n              allocationId: allocation.id,\n              cableId: allocation.cableId,\n              resourceAtom: atom,\n              createdAt: now,\n              originDeviceId: originDeviceId,\n            ),\n            mode: InsertMode.insertOrIgnore,\n          );\n      if (inserted == 0) {\n        await (database.delete(database.cableResourceClaims)\n              ..where((row) => row.allocationId.equals(allocation.id)))\n            .go();\n        await (database.delete(database.cableAllocationResourceSelections)\n              ..where((row) => row.allocationId.equals(allocation.id)))\n            .go();\n        return ElvAllocationMutationOutcome.resourceOverlap;\n      }\n    }\n",
    "    for (final atom in evidence.resolvedAtoms) {\n      final conflict = await (database.select(database.cableResourceClaims)\n            ..where(\n              (row) =>\n                  row.cableId.equals(allocation.cableId) &\n                  row.resourceAtom.equals(atom),\n            ))\n          .getSingleOrNull();\n      if (conflict != null) {\n        await (database.delete(database.cableResourceClaims)\n              ..where((row) => row.allocationId.equals(allocation.id)))\n            .go();\n        await (database.delete(database.cableAllocationResourceSelections)\n              ..where((row) => row.allocationId.equals(allocation.id)))\n            .go();\n        return ElvAllocationMutationOutcome.resourceOverlap;\n      }\n      await database.into(database.cableResourceClaims).insert(\n            CableResourceClaimsCompanion.insert(\n              allocationId: allocation.id,\n              cableId: allocation.cableId,\n              resourceAtom: atom,\n              createdAt: now,\n              originDeviceId: originDeviceId,\n            ),\n          );\n    }\n",
)

# Old feature/migration tests must assert the current application schema, not freeze
# the historical schema number of the feature they originally introduced.
changed_schema_assertions = 0
for path in (ROOT / 'apps/mobile/test').rglob('*.dart'):
    text = path.read_text()
    old = text
    for version in range(1, 20):
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

# Record equality does not imply deep List equality. Keep this foundation test about
# deterministic identities rather than Dart List object identity.
replace_once(
    'apps/mobile/test/application/elv_p8_fixture_foundation_test.dart',
    "      expect(\n        (\n          projectId: project.project.id,\n          connectionId: topology.connection.id,\n          runId: routing.run.id,\n          traversalIds: routing.traversals.map((item) => item.id).toList(),\n        ),\n        (\n          projectId: 'PRJ-001',\n          connectionId: 'CONN-003',\n          runId: 'RUN-006',\n          traversalIds: ['TRV-008', 'TRV-009', 'TRV-010'],\n        ),\n      );\n",
    "      expect(project.project.id, 'PRJ-001');\n      expect(topology.connection.id, 'CONN-003');\n      expect(routing.run.id, 'RUN-006');\n      expect(\n        routing.traversals.map((item) => item.id),\n        orderedEquals(['TRV-008', 'TRV-009', 'TRV-010']),\n      );\n",
)

print(f'ELV3 baseline fixes applied; schema assertion files updated: {changed_schema_assertions}')
