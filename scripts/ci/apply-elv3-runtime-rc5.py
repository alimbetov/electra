from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected one anchor, got {count}: {old[:100]!r}')
    path.write_text(text.replace(old, new, 1))

def write(path: str, content: str) -> None:
    target = ROOT / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(content)

service = ROOT / 'apps/mobile/lib/application/elv_physical_calculation_service.dart'
replace_once(
    service,
    "abstract interface class ElvPhysicalCalculationSource {\n",
    "String elvPhysicalCalculationNodeKey({\n  required String designRevisionId,\n  required String processCode,\n  required String subjectKind,\n  required String subjectId,\n}) => 'elv3:$designRevisionId:$processCode:$subjectKind:$subjectId';\n\nabstract interface class ElvPhysicalCalculationSource {\n",
)
replace_once(
    service,
    "    final nodeKey =\n        'elv3:${run.designRevisionId}:${ElvPhysicalProcessCodes.installedLength}:cable-run:${run.id}';\n    await results.put(projectId, nodeKey, result);\n    return result;\n  }\n}",
    "    await persistResult(\n      projectId: projectId,\n      subjectKind: 'cable-run',\n      result: result,\n    );\n    return result;\n  }\n\n  Future<void> persistResult<T>({\n    required String projectId,\n    required String subjectKind,\n    required ElvPhysicalCalculationResult<T> result,\n  }) => results.put(\n    projectId,\n    elvPhysicalCalculationNodeKey(\n      designRevisionId: result.designRevisionId,\n      processCode: result.processCode,\n      subjectKind: subjectKind,\n      subjectId: result.subjectId,\n    ),\n    result,\n  );\n\n  Future<ElvPhysicalCalculationResult<Object?>?> loadResult({\n    required String projectId,\n    required String designRevisionId,\n    required String processCode,\n    required String subjectKind,\n    required String subjectId,\n  }) => results.find(\n    projectId,\n    elvPhysicalCalculationNodeKey(\n      designRevisionId: designRevisionId,\n      processCode: processCode,\n      subjectKind: subjectKind,\n      subjectId: subjectId,\n    ),\n  );\n}\n",
)

write('apps/mobile/test/data/elv_p6_runtime_closure_test.dart', r'''import 'package:drift/native.dart';
import 'package:electra_mobile/application/elv_physical_calculation_service.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/drift_elv_physical_calculation_result_store.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _seed(AppDatabase db) async {
  final now = DateTime.utc(2026, 10, 14);
  await db.into(db.projects).insert(ProjectsCompanion.insert(id: 'p', name: 'P6', measurementSystem: 'metric', defaultStructuralHeightMm: 3000, defaultFinishedCeilingHeightMm: 2700, createdAt: now, updatedAt: now, originDeviceId: 'test'));
}

ElvPhysicalCalculationResult<Object?> _result(String code, String revision, Object? value) => ElvPhysicalCalculationResult<Object?>(
  processCode: code,
  algorithmVersion: 'test-v1',
  projectId: 'p',
  designRevisionId: revision,
  subjectId: 'subject-1',
  value: value,
  unit: 'evidence',
  state: ElvCalculationState.current,
  inputFingerprint: 'fp:$revision:$code',
  trace: {'revision': revision, 'processCode': code},
);

void main() {
  const codes = [
    ElvPhysicalProcessCodes.installedLength,
    ElvPhysicalProcessCodes.carrierFillBasis,
    ElvPhysicalProcessCodes.segregationEvidence,
    ElvPhysicalProcessCodes.bendRadiusBasis,
    ElvPhysicalProcessCodes.congestionBasis,
    ElvPhysicalProcessCodes.reserveAllowance,
  ];

  test('all six ELV-ROUTE process outputs persist with provenance', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await _seed(db);
    final store = DriftElvPhysicalCalculationResultStore(db, originDeviceId: 'test');
    for (final code in codes) {
      final result = _result(code, 'REV-1', {'code': code});
      final key = elvPhysicalCalculationNodeKey(designRevisionId: 'REV-1', processCode: code, subjectKind: 'subject', subjectId: 'subject-1');
      await store.put('p', key, result);
      final loaded = await store.find('p', key);
      expect(loaded, isNotNull);
      expect(loaded!.processCode, code);
      expect(loaded.designRevisionId, 'REV-1');
      expect(loaded.inputFingerprint, 'fp:REV-1:$code');
      expect(loaded.trace['processCode'], code);
    }
    expect(await db.select(db.projectDerivedResults).get(), hasLength(6));
  });

  test('revision-scoped node keys prevent cross-revision overwrite', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await _seed(db);
    final store = DriftElvPhysicalCalculationResultStore(db, originDeviceId: 'test');
    const code = ElvPhysicalProcessCodes.installedLength;
    final key1 = elvPhysicalCalculationNodeKey(designRevisionId: 'REV-1', processCode: code, subjectKind: 'cable-run', subjectId: 'run-1');
    final key2 = elvPhysicalCalculationNodeKey(designRevisionId: 'REV-2', processCode: code, subjectKind: 'cable-run', subjectId: 'run-1');
    await store.put('p', key1, ElvPhysicalCalculationResult<double>(processCode: code, algorithmVersion: 'v1', projectId: 'p', designRevisionId: 'REV-1', subjectId: 'run-1', value: 100, unit: 'mm', state: ElvCalculationState.current, inputFingerprint: 'fp1'));
    await store.put('p', key2, ElvPhysicalCalculationResult<double>(processCode: code, algorithmVersion: 'v1', projectId: 'p', designRevisionId: 'REV-2', subjectId: 'run-1', value: 200, unit: 'mm', state: ElvCalculationState.current, inputFingerprint: 'fp2'));
    expect((await store.find('p', key1))!.value, 100);
    expect((await store.find('p', key2))!.value, 200);
    await store.invalidate('p', [key2]);
    expect((await store.find('p', key1))!.state, ElvCalculationState.current);
    expect((await store.find('p', key2))!.state, ElvCalculationState.stale);
  });

  test('canonical node key includes revision process subject-kind and subject', () {
    expect(elvPhysicalCalculationNodeKey(designRevisionId: 'R7', processCode: ElvPhysicalProcessCodes.bendRadiusBasis, subjectKind: 'route-node', subjectId: 'N9'), 'elv3:R7:ELV-ROUTE-04:route-node:N9');
  });
}
''')
