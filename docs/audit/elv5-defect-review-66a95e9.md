# Ревью ELV5: дефекты lifecycle и достоверности CURRENT

Проверенная ветка: `feat/flutter-elv5-power-topology-design`.
Проверенный исходный SHA: `66a95e9dc158a95c26edee1a8c1032d2f198b3e3`.
Дата ревью: 2026-10-18 UTC.

Ветка не готова к merge/`ELV5 = ACCEPTED`: ниже четыре P1 и один P2.
Выводы подтверждены трассировкой production-кода и SQL; новые end-to-end
воспроизведения этих пяти сценариев в рамках ревью не запускались.

## Объём и проверка

Относительно `origin/main` ветка меняет 505 файлов. Проверены наиболее
рискованные цепочки: capture → calculate → publication/CAS, dependency
invalidation, contract evidence identity, freeze → create-next, текущие
источники геометрии и qualification provenance. Это не утверждение об
исчерпывающей проверке каждой строки всех 505 файлов.

- Уже подготовленная интеграция global reliability CI сохранена в `66a95e9`.
- `git diff --check`: PASS перед сохранением подготовленных изменений.
- `python3 -m unittest discover -s scripts/ci -p 'test_elv5_*.py'`: 42 PASS.
- GitHub Actions run `39092674749` для этого SHA: static/specification gates,
  command/provenance checks, F1/F2 status, manifest и 1500-case generation
  прошли; при проверке run ещё выполнял Generate Drift code. Полный
  formatter/analyze/mobile/core/global-suite PASS для этого SHA не заявляется.
- Новых функциональных исправлений по результатам ревью не внесено.

## D1 — P1: create-next теряет revision-owned ELV5 configuration

Место: `apps/mobile/lib/data/repositories/drift_elv_design_revision_repository.dart`,
строка 431; весь путь `createNext` начинается на строке 289.

После freeze R1 команда создаёт R2, клонирует physical runs/traversals и
вызывает только `DriftPowerSnapshotFacts.materialize`. Ни чтения captured ELV5
discipline section, ни materialization её roots/children в этой транзакции нет.
Метод сразу записывает успешный command result.

**Сценарий:** настроить в R1 camera streams, recording pools, LAN/ACS/FIRE
bindings и policy bindings; заморозить R1; выполнить create-next R2.
**Последствие:** R2 существует, physical/power перенесены, но revision-scoped
ELV5 queries возвращают пустую конфигурацию. Наличие freeze snapshot само по
себе не восстанавливает рабочие таблицы R2.

Требование прямо задано в
`docs/product/elv5-implementation/code-level-runtime-contract.md`, строка 639.

Нужна materialization всех ELV5 roots/children с typed identity remapping в
общей create-next transaction. Исторические evaluations R1 переносить или
ретегировать нельзя. Регрессия: populated R1 → public freeze → public
create-next → сравнение всех ожидаемых remapped roots/children в R2 и
неизменности R1 после reopen.

## D2 — P1: evidence_ref не различает ревизии, а чтение различает

Место: `apps/mobile/lib/data/repositories/elv5/drift_cctv01_geometry_contract_store.dart`,
строка 120; чтение — строка 64.
Схема: `apps/mobile/lib/data/database/elv_history_database_tables.dart`, строка 17.

Writer строит `CCTV01:<cameraId>:<payloadHash>`, ищет existing evidence только
по `evidence_ref` и при совпавшем hash пропускает INSERT. Этот ref является
глобальным primary key. Reader требует совпадения ref, project **и revision**.

**Сценарий:** сохранить контракт камеры в R1; в новой рабочей R2 связать ту же
canonical camera с идентичным контрактом. Payload не содержит revision,
поэтому ref совпадает. Writer использует существующую запись R1 и успешно
создаёт binding R2, но reader R2 не находит revision-local evidence.
**Последствие:** `CCTV01_CONTRACT_EVIDENCE_MISSING` после успешной записи.
Это независимо от D1: повторное явное добавление контракта в R2 тоже ломается.

Тот же шаблон найден в CCTV06, CCTV05, LAN02/03/04/06/07, ACS01/02 и других
contract stores; это семейство дефектов, а не только CCTV01.

Нужен согласованный revision-scoped evidence identity либо отдельная
content-addressed payload/ownership модель. Нельзя исправлять только WHERE
в reader, иначе будет потеряна revision ownership provenance.
Регрессия: одинаковый subject/payload в R1 и R2, успешный load обеих редакций
после reopen, неизменность evidence R1.

## D3 — P1: publication не проверяет captured upstream generations

Место: `apps/mobile/lib/application/elv5/calculation/elv5_calculation_service.dart`,
строка 121. Производитель capture tokens:
`apps/mobile/lib/application/elv5/cctv/cctv05_runtime.dart`, строка 275.

CCTV05 capture сохраняет `upstreamPointerGenerations` для CCTV02/CCTV03.
Guarded resolver сохраняет эту карту, но adapter передаёт в общий
`Elv5CapturedProcess` только opaque input/fingerprint/design captureRevision.
Service не читает карту: перед публикацией проверяются design row revision и
поколения **публикуемых** узлов, но не consumed upstream pointers.

**Сценарий:** первый CCTV05 capture читает CCTV02 generation g; другой writer
перепубликует CCTV02 в g+1 с тем же design revision; затем CCTV05 продолжает
publication. Перепубликация upstream не меняет design row revision.
Пока CCTV05 ещё не опубликован, его dependency index отсутствует, поэтому
cascade invalidation upstream также не может его защитить.
**Последствие:** CCTV05 получает CURRENT на основании уже неактуального
upstream generation. Даже неизменный evaluation ID не отменяет договорённость
о проверке generation при публикации.

Нужна проверка captured upstream existence/freshness/generation/identity внутри
той же publication transaction до записи результатов. Регрессия: barrier
после capture CCTV05, upstream republish отдельным connection, resume и
проверка typed rejection без частичных evaluation/index/pointer/ledger writes.

## D4 — P1: placement/geometry writes не инвалидируют CCTV01

Место потребления:
`apps/mobile/lib/application/elv5/cctv/cctv01_runtime.dart`, строка 287.
Место записи:
`apps/mobile/lib/data/repositories/drift_component_instance_repository.dart`,
строка 99; `apps/mobile/lib/data/repositories/drift_geometry_repository.dart`,
строка 192.

CCTV01 записывает dependency markers `ELV3_COMPONENT_PLACEMENT` и
`ELV3_SURFACE_PATCH`. Поиск этих domains в lib находит только resolver:
production invalidation producer для них отсутствует. `saveComponent`,
`replaceRoomComponents` и `replaceRoomGeometry` меняют canonical source rows,
но не делают ELV5 invalidation и не повышают design capture revision.
Database triggers также не реализуют такую invalidation.

**Сценарий:** опубликовать CURRENT CCTV01, затем через component repository
переместить камеру в другую допустимую local position на той же patch либо
изменить геометрию через geometry repository.
**Последствие:** старый результат покрытия остаётся CURRENT при изменившихся
входных данных. Изменение одновременно с capture может пройти и общий
design-revision guard, поскольку эти writers его token не меняют.

Нужна атомарная invalidation affected working-revision consumers в canonical
mutation boundary и согласованный capture token. Регрессия должна использовать
реальные public placement/geometry writers, проверить affected/unaffected
узлы, reopen и неизменность frozen captured evidence.

## D5 — P2: первое добавление контракта оставляет старый BLOCKED результат CURRENT

Место: `apps/mobile/lib/data/repositories/elv5/drift_elv5_cctv_contract_mutation_coordinator.dart`,
строка 36; capture — `apps/mobile/lib/application/elv5/cctv/cctv01_runtime.dart`,
строка 47.

При отсутствии контракта CCTV01 выбрасывает blocked capture с пустым списком
dependencies. Blocked-aware adapter превращает его в durable evaluation, а
service публикует его pointer как CURRENT. При первом `replaceCctv01` old
snapshot равен null, поэтому coordinator вообще не вызывает invalidator.

**Сценарий:** рассчитать CCTV01 без обязательного контракта; получить durable
BLOCKED/CURRENT; затем создать первый валидный geometry contract.
**Последствие:** старое `CCTV01_GEOMETRY_CONTRACT_REQUIRED` остаётся CURRENT,
несмотря на появившийся источник. Design revision bump защищает будущую
publication, но не исправляет freshness уже опубликованного pointer.

Нужны stable subject/selector dependencies для отсутствующего контракта и
invalidation при появлении первого binding. Аналогичный `previous != null`
шаблон есть у других contract coordinators; проверять их следует той же
missing → present регрессией. BLOCKED сам по себе допустим, дефект именно в
отсутствии freshness transition после исправления входных данных.

## Ограничения квалификации

27 runtime adapters и lifecycle witnesses не доказывают отсутствие этих
дефектов. Текущий collector сохраняет `qualified = 0` и acceptance false;
это корректно. Нельзя переводить ELV5 в ACCEPTED по static 1500-case matrix
или по одним Q6/Q7/Q8 witnesses до регрессий выше, остальных обязательных
qualification gates и полного exact-SHA CI PASS.
