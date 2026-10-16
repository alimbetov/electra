# ELV5 — инженерно-архитектурный hardening audit

Дата: 2026-10-16  
Branch: `feat/flutter-elv5-power-topology-design`  
Статус: DESIGN HARDENED / RUNTIME NOT STARTED

Этот проход является **вторым аудитом** после первоначальной проверки 80 требований и 27 процессов. Первый аудит исправил восемь дефектов самих расчётных контрактов. Второй проход проверяет ТЗ уже как будущую инженерную систему: типы величин, доказуемость исходных данных, воспроизводимость, хранение, транзакции, публичный API, конкурентность, миграции, технические границы утверждений и схему квалификации.

Машиночитаемый реестр: [elv5-engineering-architecture-hardening-audit.json](elv5-engineering-architecture-hardening-audit.json).

## 1. Итог

Найдено **14 дополнительных design-level замечаний: 10 HIGH и 4 MEDIUM**. Все 14 закрыты на уровне спецификации новыми нормативными контрактами; ни одно из них пока не является runtime PASS.

Главный результат: ELV5 теперь описан не только как набор формул и пакетов P0–P9, а как реализация, где заранее зафиксированы:

- размерностно-безопасные инженерные типы;
- provenance и качество каждого значения;
- normal/expected/peak/startup/standby/alarm/emergency operating cases;
- canonical serialization и четыре разных hash projection;
- типизированные Dart input/output contracts для всех 27 процессов;
- additive Drift schema **24** с ownership/PK/FK/index правилами;
- единая replay/history/UoW модель поверх уже реализованной платформы;
- all-or-nothing publication для coherent calculation batch;
- fail-safe/fail-secure ACS release truth table;
- deterministic timezone/DST и geometry-frame semantics;
- L0–L6 executable qualification, 54 основных POS/NEG vertical и adversarial/race/failure matrices.

## 2. ELV5-HARD-01 — HIGH: размерность не была частью типа

**Риск.** Точное rational число само по себе не защищает от `dB ↔ dBm`, `W ↔ A`, `bit/s ↔ byte/s` или от использования одной и той же generic-map формы разными процессами.

**Исправление.** Введён [engineering primitives contract](../product/elv5-implementation/engineering-primitives-contract.md): `Elv5Dimension`, `Elv5Quantity<D>`, канонические единицы и process-safe value objects. [Typed process API](../product/elv5-implementation/typed-process-api.md) использует их во всех 27 inputs/outputs.

**Критерий runtime.** Компиляционно/тестово невозможен легальный вызов оптического kernel с dBm как dB loss; conversion bit→byte остаётся exact до объявленного ceil boundary.

## 3. ELV5-HARD-02 — HIGH: hash не имел нормативной сериализации

**Риск.** `jsonEncode(Map)` не является канонической инженерной схемой: порядок map/set, decimal formatting или timestamp/ID могли менять hash при тех же физических исходных данных.

**Исправление.** Зафиксирован `electra.canonical-json.v1` и отдельные projections для:

```text
request hash
input fingerprint
output hash
snapshot discipline hash
```

`outputHash` намеренно исключает `evaluationId` и `completedAtUtc`, но включает все инженерные статусы, dimensions, steps, findings и consumed evidence.

## 4. ELV5-HARD-03 — HIGH: nominal/typical мог быть принят за гарантированный предел

**Риск.** Типичное потребление, ожидаемый bitrate или оценочная потеря могли технически пройти comparison, который требует worst-case/guaranteed evidence.

**Исправление.** Введены `Elv5EvidenceBasis`, `Elv5EngineeringValue<Q>`, guaranteed intervals и explicit applicability. Reserve и uncertainty разделены: запас не повышает качество источника данных.

**Инженерное правило.** Если threshold требует гарантированный upper/lower bound, `manufacturerTypical`/`estimated` nominal не может дать PASS.

## 5. ELV5-HARD-04 — HIGH: operating cases были недостаточно жёстко идентифицированы

**Риск.** Проект мог непреднамеренно сложить expected CCTV bitrate с peak network state, lock holding current со startup current или fire standby/alarm без явного сценария одновременности.

**Исправление.** Каждый typed input имеет `Elv5OperatingCaseRef`; state selections и composition rules versioned/code-owned. Shared physical wrappers обязаны ссылаться на один и тот же ELV4 scenario/segment evidence.

## 6. ELV5-HARD-05 — HIGH: recurrence зависела бы от host timezone/tzdb

**Риск.** Раскладка записей по времени может измениться после обновления timezone database или на другом устройстве.

**Исправление.** `Elv5TemporalPolicy` фиксирует IANA zone, tzdb version, DST gap/overlap policy; инженерные интервалы `[start,end)` после expansion становятся UTC evidence.

Даже если текущая рабочая зона не использует DST, P8 обязан выполнить DST fixture — это проверка воспроизводимости продукта, а не конкретного региона.

## 7. ELV5-HARD-06 — MEDIUM: геометрия могла смешивать разные frames

**Риск.** Численно корректные X/Y/Z без frame identity способны дать убедительно выглядящий, но физически неверный camera footprint.

**Исправление.** Координата несёт `frameId`, handedness, axis convention и transform-chain hash. Mixed frames fail closed без captured transform.

## 8. ELV5-HARD-07 — HIGH: 27 процессов не имели frozen typed API

Ранее generic `Elv5ProcessDefinition<TInput,TOutput>` задавал архитектурную форму, но не фиксировал поля `TInput/TOutput` каждого процесса.

Теперь [typed-process-api.md](../product/elv5-implementation/typed-process-api.md) задаёт минимальные Dart boundaries всех **CCTV-01…06, LAN-01…07, ACS-01…06, FA-01…08**. Generic `Map<String,Object?>` остаётся только wire/storage boundary и не является kernel API.

## 9. ELV5-HARD-08 — HIGH: persistence не был готов к прямой кодировке

**Риск.** Фраза «persist equivalent roots/children» допускает несовместимые схемы у разных разработчиков, особенно для storage pool, recorder, fire address expansion и door release behavior.

**Исправление.** [persistence-schema-contract.md](../product/elv5-implementation/persistence-schema-contract.md) фиксирует:

- migration `23 → 24`;
- semantic Drift tables;
- root/member ownership;
- PK/FK/index/active uniqueness;
- explicit `FireAddressClaims` вместо скрытого JSON overlap;
- isolated immutable discipline evaluations/pointers;
- reverse dependency index;
- discipline snapshot section;
- reuse существующего `ElvCommandLedgerStore` и revision-history platform;
- запрет duplicate canonical owners (`DisciplineCables`, `DisciplinePorts`, `DisciplinePowerSources` и т.п.).

## 10. ELV5-HARD-09 — HIGH: batch publication должна быть атомарной

**Риск.** `CALCULATE_DISCIPLINE_PROCESS` может включать несколько узлов. Если один pointer generation конфликтует после capture, частичная публикация остальных дала бы hybrid workspace — часть результатов из одного captured world, часть из другого.

**Исправление.** Для requested coherent batch publication задано правило **all-or-nothing**: revalidation/CAS всей группы проходит до того, как любой запрошенный node становится CURRENT.

## 11. ELV5-HARD-10 — HIGH: ACS release semantics были недостаточно формальными

**Риск.** Наличие reader/relay/fire input не доказывает, что замок действительно переходит в нужное состояние при fire release, break-glass или loss of power. Особенно опасно смешение fail-safe/fail-secure.

**Исправление.** ACS-06 получает:

```text
AcsLockSafetyMode
AcsReleaseCause
AcsExpectedLockOutcome
AcsReleaseTruthRow
```

Минимальный qualification набор: normal access, request-to-exit, fire release, emergency break-glass, power failure. Это техническая модель поведения; юридическую/нормативную верификацию по-прежнему выполняет ELV7.

## 12. ELV5-HARD-11 — MEDIUM: CCTV payload bitrate ≠ физический wire rate

**Риск.** Encoded payload bitrate нельзя автоматически сравнивать с доступной network capacity без transport overhead model.

**Исправление.** CCTV-02 разделяет payload и optional versioned wire-rate model. Нет «универсальных +5%/+10%». Если policy требует physical capacity verdict, overhead/capacity basis должен быть конкретным evidence.

## 13. ELV5-HARD-12 — MEDIUM: optical power budget ≠ reach/dispersion

**Риск.** Хороший Rx budget не доказывает transmission reach при нужной скорости/оптике, если отдельные ограничения reach/dispersion не заданы.

**Исправление.** LAN-05 может публиковать reach compatibility только при exact registered reach profile. Основной required optical budget не подменяется этим расширением.

## 14. ELV5-HARD-13 — HIGH: нужна строгая граница между formula test и runtime acceptance

**Риск.** Набор unit/registry tests может создать ложное ощущение, что все 27 процессов реализованы.

**Исправление.** [qualification-contract.md](../product/elv5-implementation/qualification-contract.md) вводит L0–L6:

```text
L0 primitives/hash
L1 typed kernels
L2 wire codecs
L3 schema/migration/restart
L4 UoW/replay/history/failure injection
L5 public-command verticals
L6 concurrency/freeze/historical matrix
```

Основной process manifest содержит **54** entry: POS и NEG/unsupported для каждого из 27 процессов. Каждый primary oracle обязан пройти production dispatcher → file SQLite → typed resolver → kernel → guarded publish → read projection → reopen verification.

## 15. ELV5-HARD-14 — MEDIUM: scale fixture отсутствовал

**Риск.** Формально корректная реализация может иметь квадратичные проходы, слишком большие SQL `IN`, recursion issues или memory blow-up.

**Исправление.** P8 design теперь включает deterministic scale fixtures: 1000 streams, 10000 schedule segments, 5000 LAN mappings, 2000 ACS assignments, 10000 fire address claims, 5000 dependency edges и batch 500 nodes.

Не введён выдуманный millisecond SLA: сначала собираются benchmark evidence на выбранном target hardware, затем продуктовый SLO может стать нормативным.

## 16. Дополнительные инженерные усиления

### CCTV

- pixel density допускается как **техническая плотность**, если известен active pixel count;
- она не превращается в DORI/legal identification claim;
- expected payload, peak payload, wire rate и recorder storage разделены.

### LAN/optics

- optical Rx sensitivity/overload остаётся обязательной двунаправленной проверкой;
- optional reach profile не смешивается с dBm/dB budget;
- LAN-06 может передать RU/weight/depth demand в ELV6, но не заявляет cabinet fit.

### ACS

- control/data path, conductive feed, monitoring и emergency release — разные typed paths;
- dry contact никогда не считается power source.

### Fire

- address collision остаётся физическим SET constraint;
- signal-loop closure не превращает loop в поддержанный electrical mesh;
- policy match не становится certified compliance.

## 17. Что сознательно НЕ перенесено в ELV5

Чтобы не превратить этап в монолит, следующие conclusions оставлены владельцам следующих стадий:

- **ELV6** — реальное размещение в шкафу/стойке, U-position, depth/clearance, ventilation/thermal, cable management;
- **ELV7** — применимость норм, jurisdiction, verified compliance/certification;
- **ELV8** — подбор конкретных SKU, BOM, коммерческая/закупочная документация.

ELV5 обязан передать достаточную техническую demand/evidence basis, но не должен преждевременно выдавать PASS за эти стадии.

## 18. Текущий verdict

После двух проходов ТЗ уже можно считать **архитектурно готовым к реализации P1/P2 гораздо ближе к production-grade уровню**, однако статус остаётся `DESIGN DRAFT / RUNTIME NOT STARTED` до появления кода и исполнимого P8 evidence.

На уровне ТЗ сейчас закрыты:

```text
8 первоначальных discipline findings
+ 14 engineering/architecture hardening findings
= 22 specification findings resolved
```

Это не 22 runtime fixes. Для runtime closure должны существовать production Dart/Drift implementation, schema 24 migration, 54 process verticals, 16 command codec adversarial matrix, restart/failure/race/freeze tests и P9 exact-head evidence ledger.
