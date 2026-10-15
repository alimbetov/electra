from pathlib import Path

path = Path(__file__).resolve().parents[2] / 'apps/mobile/test/data/elv4_p7_t06_history_test.dart'
text = path.read_text()
marker = "\n}\n\n  test('P7 T06 new edit after undo abandons the old redo branch'"
if marker in text:
    text = text.replace(
        marker,
        "\n\n  test('P7 T06 new edit after undo abandons the old redo branch'",
        1,
    )
    clock = "\nDateTime _clock() => DateTime.utc(2026, 10, 15, 13, 45);\n"
    if text.count(clock) != 1:
        raise SystemExit('history acceptance clock anchor missing')
    text = text.replace(
        clock,
        "\n}\n\nDateTime _clock() => DateTime.utc(2026, 10, 15, 13, 45);\n",
        1,
    )
path.write_text(text)
