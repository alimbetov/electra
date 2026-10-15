from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DB = ROOT / 'apps/mobile/lib/data/database/app_database.dart'
text = DB.read_text()


def replace_once(old: str, new: str) -> None:
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'expected one schema anchor, got {count}: {old[:120]!r}')
    text = text.replace(old, new, 1)


if "part 'elv_history_database_tables.dart';" not in text:
    replace_once(
        "part 'power_database_tables.dart';\n",
        "part 'power_database_tables.dart';\npart 'elv_history_database_tables.dart';\n",
    )

if 'ElvRevisionCommandHistoryOperations,' not in text:
    replace_once(
        '    PowerOperationRecords,\n',
        '    PowerOperationRecords,\n'
        '    ElvRevisionAggregateEvidenceRecords,\n'
        '    ElvRevisionCommandHistoryOperations,\n'
        '    ElvRevisionCommandHistoryCursors,\n'
        '    ElvRevisionCommandHistoryExecutions,\n',
    )

if 'int get schemaVersion => 23;' not in text:
    replace_once('  int get schemaVersion => 22;', '  int get schemaVersion => 23;')

if 'migrator.createTable(elvRevisionAggregateEvidenceRecords)' not in text:
    replace_once(
        '          await migrator.createTable(powerOperationRecords);\n'
        '        }\n'
        '      }\n',
        '          await migrator.createTable(powerOperationRecords);\n'
        '        }\n'
        '        if (from < 23) {\n'
        '          await migrator.createTable(elvRevisionAggregateEvidenceRecords);\n'
        '          await migrator.createTable(elvRevisionCommandHistoryOperations);\n'
        '          await migrator.createTable(elvRevisionCommandHistoryCursors);\n'
        '          await migrator.createTable(elvRevisionCommandHistoryExecutions);\n'
        '        }\n'
        '      }\n',
    )

if 'idx_elv_revision_history_state' not in text:
    replace_once(
        "    await customStatement(\n"
        "      'CREATE INDEX IF NOT EXISTS idx_power_pointer_scope ON power_evaluation_pointers(project_id, design_revision_id, logical_node_key_sha256)',\n"
        "    );\n"
        "  }\n",
        "    await customStatement(\n"
        "      'CREATE INDEX IF NOT EXISTS idx_power_pointer_scope ON power_evaluation_pointers(project_id, design_revision_id, logical_node_key_sha256)',\n"
        "    );\n"
        "    await customStatement(\n"
        "      'CREATE INDEX IF NOT EXISTS idx_elv_revision_history_state ON elv_revision_command_history_operations(project_id, design_revision_id, state, sequence)',\n"
        "    );\n"
        "    await customStatement(\n"
        "      'CREATE UNIQUE INDEX IF NOT EXISTS ux_elv_revision_history_original_command ON elv_revision_command_history_operations(project_id, design_revision_id, original_command_id)',\n"
        "    );\n"
        "    await customStatement(\n"
        "      'CREATE INDEX IF NOT EXISTS idx_elv_revision_history_evidence ON elv_revision_aggregate_evidence_records(project_id, design_revision_id, aggregate_kind, aggregate_id)',\n"
        "    );\n"
        "    await customStatement(\n"
        "      'CREATE INDEX IF NOT EXISTS idx_elv_revision_history_execution ON elv_revision_command_history_executions(project_id, design_revision_id, history_sequence)',\n"
        "    );\n"
        "  }\n",
    )

if "'elv_revision_command_history_operations'," not in text:
    replace_once(
        "      'power_operation_records',\n",
        "      'power_operation_records',\n"
        "      'elv_revision_aggregate_evidence_records',\n"
        "      'elv_revision_command_history_operations',\n"
        "      'elv_revision_command_history_cursors',\n"
        "      'elv_revision_command_history_executions',\n",
    )

if "'elv_revision_aggregate_evidence_records'," not in text.split(
    'const immutableTables = <String>['
)[1]:
    replace_once(
        "      'power_evaluation_records',\n"
        "    ];\n"
        "    for (final table in immutableTables) {\n",
        "      'power_evaluation_records',\n"
        "      'elv_revision_aggregate_evidence_records',\n"
        "      'elv_revision_command_history_executions',\n"
        "    ];\n"
        "    for (final table in immutableTables) {\n",
    )

if 'trg_elv_revision_history_operation_payload_immutable' not in text:
    immutable_tail = (
        "    for (final table in immutableTables) {\n"
        "      await customStatement(\n"
        "        'CREATE TRIGGER IF NOT EXISTS trg_${table}_immutable_update '\n"
        "        'BEFORE UPDATE ON $table '\n"
        "        \"BEGIN SELECT RAISE(ABORT, 'ELV4_IMMUTABLE_EVIDENCE'); END\",\n"
        "      );\n"
        "      await customStatement(\n"
        "        'CREATE TRIGGER IF NOT EXISTS trg_${table}_immutable_delete '\n"
        "        'BEFORE DELETE ON $table '\n"
        "        \"BEGIN SELECT RAISE(ABORT, 'ELV4_IMMUTABLE_EVIDENCE'); END\",\n"
        "      );\n"
        "    }\n"
        "  }\n"
        "}\n"
    )
    method_body = immutable_tail.removesuffix("  }\n}\n")
    hardened_tail = method_body + (
        "    await customStatement(\n"
        "      \"CREATE TRIGGER IF NOT EXISTS trg_elv_revision_history_operation_payload_immutable \"\n"
        "      \"BEFORE UPDATE ON elv_revision_command_history_operations FOR EACH ROW \"\n"
        "      \"WHEN OLD.original_command_id != NEW.original_command_id \"\n"
        "      \"OR OLD.forward_command_type != NEW.forward_command_type \"\n"
        "      \"OR OLD.forward_command_schema != NEW.forward_command_schema \"\n"
        "      \"OR OLD.forward_canonical_payload_json != NEW.forward_canonical_payload_json \"\n"
        "      \"OR OLD.forward_payload_sha256 != NEW.forward_payload_sha256 \"\n"
        "      \"OR OLD.inverse_command_type != NEW.inverse_command_type \"\n"
        "      \"OR OLD.inverse_command_schema != NEW.inverse_command_schema \"\n"
        "      \"OR OLD.inverse_canonical_payload_json != NEW.inverse_canonical_payload_json \"\n"
        "      \"OR OLD.inverse_payload_sha256 != NEW.inverse_payload_sha256 \"\n"
        "      \"OR OLD.before_aggregate_evidence_ref != NEW.before_aggregate_evidence_ref \"\n"
        "      \"OR OLD.before_aggregate_hash != NEW.before_aggregate_hash \"\n"
        "      \"OR OLD.after_aggregate_evidence_ref != NEW.after_aggregate_evidence_ref \"\n"
        "      \"OR OLD.after_aggregate_hash != NEW.after_aggregate_hash \"\n"
        "      \"OR OLD.affected_ids_json != NEW.affected_ids_json \"\n"
        "      \"BEGIN SELECT RAISE(ABORT, 'ELV4_HISTORY_IMMUTABLE_OPERATION_PAYLOAD'); END\",\n"
        "    );\n"
        "    await customStatement(\n"
        "      \"CREATE TRIGGER IF NOT EXISTS trg_elv_revision_history_cursor_monotonic \"\n"
        "      \"BEFORE UPDATE ON elv_revision_command_history_cursors FOR EACH ROW \"\n"
        "      \"WHEN NEW.generation <= OLD.generation \"\n"
        "      \"BEGIN SELECT RAISE(ABORT, 'ELV4_HISTORY_CURSOR_GENERATION_CONFLICT'); END\",\n"
        "    );\n"
        "    await customStatement(\n"
        "      \"CREATE TRIGGER IF NOT EXISTS trg_elv_revision_history_execution_operation \"\n"
        "      \"BEFORE INSERT ON elv_revision_command_history_executions FOR EACH ROW \"\n"
        "      \"WHEN NOT EXISTS (SELECT 1 FROM elv_revision_command_history_operations h \"\n"
        "      \"WHERE h.project_id = NEW.project_id AND h.design_revision_id = NEW.design_revision_id \"\n"
        "      \"AND h.sequence = NEW.history_sequence) \"\n"
        "      \"BEGIN SELECT RAISE(ABORT, 'ELV4_HISTORY_OPERATION_NOT_FOUND'); END\",\n"
        "    );\n"
        "  }\n"
        "}\n"
    )
    replace_once(immutable_tail, hardened_tail)

DB.write_text(text)
