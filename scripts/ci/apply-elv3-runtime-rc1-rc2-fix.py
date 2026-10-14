from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

for rel in [
    'apps/mobile/test/data/elv_p1_cable_persistence_test.dart',
    'apps/mobile/test/data/elv_p3_runtime_closure_test.dart',
]:
    path = ROOT / rel
    text = path.read_text()
    text = text.replace("import 'package:drift/drift.dart' hide isNull, isNotNull;\n", '')
    path.write_text(text)

print('ELV3 RC1/RC2 analyzer cleanup applied')
