from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DB = ROOT / 'apps/mobile/lib/data/database/app_database.dart'
text = DB.read_text()

if 'trg_elv_revision_history_state_transition' not in text:
    anchor = '''    await customStatement(
      "CREATE TRIGGER IF NOT EXISTS trg_elv_revision_history_execution_operation "
      "BEFORE INSERT ON elv_revision_command_history_executions FOR EACH ROW "
      "WHEN NOT EXISTS (SELECT 1 FROM elv_revision_command_history_operations h "
      "WHERE h.project_id = NEW.project_id AND h.design_revision_id = NEW.design_revision_id "
      "AND h.sequence = NEW.history_sequence) "
      "BEGIN SELECT RAISE(ABORT, 'ELV4_HISTORY_OPERATION_NOT_FOUND'); END",
    );
'''
    if text.count(anchor) != 1:
        raise SystemExit('history integrity insertion anchor missing or ambiguous')
    extra = anchor + '''    await customStatement(
      "CREATE TRIGGER IF NOT EXISTS trg_elv_revision_history_operation_identity_immutable "
      "BEFORE UPDATE ON elv_revision_command_history_operations FOR EACH ROW "
      "WHEN OLD.project_id != NEW.project_id OR OLD.design_revision_id != NEW.design_revision_id "
      "OR OLD.sequence != NEW.sequence "
      "BEGIN SELECT RAISE(ABORT, 'ELV4_HISTORY_IMMUTABLE_OPERATION_IDENTITY'); END",
    );
    await customStatement(
      "CREATE TRIGGER IF NOT EXISTS trg_elv_revision_history_operation_delete "
      "BEFORE DELETE ON elv_revision_command_history_operations "
      "BEGIN SELECT RAISE(ABORT, 'ELV4_HISTORY_IMMUTABLE_OPERATION'); END",
    );
    await customStatement(
      "CREATE TRIGGER IF NOT EXISTS trg_elv_revision_history_state_transition "
      "BEFORE UPDATE ON elv_revision_command_history_operations FOR EACH ROW "
      "WHEN NOT (OLD.state = NEW.state "
      "OR (OLD.state = 'APPLIED' AND NEW.state = 'UNDONE') "
      "OR (OLD.state = 'UNDONE' AND NEW.state = 'APPLIED') "
      "OR (OLD.state = 'UNDONE' AND NEW.state = 'REDO_ABANDONED')) "
      "BEGIN SELECT RAISE(ABORT, 'ELV4_HISTORY_INVALID_STATE_TRANSITION'); END",
    );
    await customStatement(
      "CREATE TRIGGER IF NOT EXISTS trg_elv_revision_history_operation_evidence "
      "BEFORE INSERT ON elv_revision_command_history_operations FOR EACH ROW "
      "WHEN NOT EXISTS (SELECT 1 FROM elv_revision_aggregate_evidence_records e "
      "WHERE e.evidence_ref = NEW.before_aggregate_evidence_ref "
      "AND e.project_id = NEW.project_id AND e.design_revision_id = NEW.design_revision_id "
      "AND e.payload_sha256 = NEW.before_aggregate_hash) "
      "OR NOT EXISTS (SELECT 1 FROM elv_revision_aggregate_evidence_records e "
      "WHERE e.evidence_ref = NEW.after_aggregate_evidence_ref "
      "AND e.project_id = NEW.project_id AND e.design_revision_id = NEW.design_revision_id "
      "AND e.payload_sha256 = NEW.after_aggregate_hash) "
      "OR NOT EXISTS (SELECT 1 FROM command_execution_records c "
      "WHERE c.project_id = NEW.project_id AND c.command_id = NEW.original_command_id "
      "AND c.outcome_kind = 'SUCCESS') "
      "BEGIN SELECT RAISE(ABORT, 'ELV4_HISTORY_OPERATION_EVIDENCE_MISMATCH'); END",
    );
    await customStatement(
      "CREATE TRIGGER IF NOT EXISTS trg_elv_revision_history_cursor_insert_head "
      "BEFORE INSERT ON elv_revision_command_history_cursors FOR EACH ROW "
      "WHEN NEW.head_sequence != 0 AND NOT EXISTS (SELECT 1 FROM elv_revision_command_history_operations h "
      "WHERE h.project_id = NEW.project_id AND h.design_revision_id = NEW.design_revision_id "
      "AND h.sequence = NEW.head_sequence AND h.state = 'APPLIED') "
      "BEGIN SELECT RAISE(ABORT, 'ELV4_HISTORY_CURSOR_HEAD_INVALID'); END",
    );
    await customStatement(
      "CREATE TRIGGER IF NOT EXISTS trg_elv_revision_history_cursor_update_head "
      "BEFORE UPDATE ON elv_revision_command_history_cursors FOR EACH ROW "
      "WHEN NEW.head_sequence != 0 AND NOT EXISTS (SELECT 1 FROM elv_revision_command_history_operations h "
      "WHERE h.project_id = NEW.project_id AND h.design_revision_id = NEW.design_revision_id "
      "AND h.sequence = NEW.head_sequence AND h.state = 'APPLIED') "
      "BEGIN SELECT RAISE(ABORT, 'ELV4_HISTORY_CURSOR_HEAD_INVALID'); END",
    );
    await customStatement(
      "CREATE TRIGGER IF NOT EXISTS trg_elv_revision_history_execution_receipt "
      "BEFORE INSERT ON elv_revision_command_history_executions FOR EACH ROW "
      "WHEN NOT EXISTS (SELECT 1 FROM command_execution_records c "
      "WHERE c.project_id = NEW.project_id AND c.command_id = NEW.execution_command_id "
      "AND c.outcome_kind = 'SUCCESS') "
      "BEGIN SELECT RAISE(ABORT, 'ELV4_HISTORY_EXECUTION_RECEIPT_MISSING'); END",
    );
'''
    text = text.replace(anchor, extra, 1)

DB.write_text(text)
