# ELV5 — технический аудит и исправление ТЗ

Дата: 2026-10-15. Проверенный draft: `4421346799b32a5fe41a62729480713947723b51`; tree `3aa26291a50d3247ffa2c8075e399e67cb124a24` (эквивалент локального design snapshot `510fc06`).

Проверены **80 требований P0–P9 и все 27 процессов**: архитектура, контракты, математические границы, общие источники, область утверждений и критерии приёмки. Найдено **8 замечаний: 6 HIGH, 2 MEDIUM**; все получили **SPEC_RESOLVED** в документах. Это не runtime PASS ELV5. Актуальные статусы BASE-01…04 после merge ELV4 приведены в [baseline reconciliation](elv5-baseline-alignment-audit.md).

Полный [реестр и матрица 80 требований](elv5-technical-audit.json) сохраняет исходные алгоритмы проверенного draft, контрпримеры и связь с исправлениями. Следующие решения внесены в [registry](../product/elv5-implementation/process-registry.json), [process contracts](../product/elv5-implementation/process-contracts.md), пакеты и governing specification.

## ELV5-AUD-01 — HIGH: Округление целочисленной ёмкости хранилища

**Дефект:** Формула выдаёт рациональные bytes без правила технического округления; округление каждого потока завышает общий pool, округление вниз занижает требование.

**Исправление ТЗ:** Сначала суммировать точные rational bytes всех уникальных recording assignments в одном storage pool/horizon, затем применить reserve один раз и ceil до целого usable byte. Raw basis=ceil(rounded usable/redundancy fraction). UI rounding не меняет ни один verdict.

**Контрпример/проверка:** Two assignments of1bit/s for1s -> exact .25B total ->1 required usable B, not2 or0. Noninteger raw requirement rounds upward once per pool.

**Пункты:** ELV5-P1-005, ELV5-P3-003, ELV5-P8-002, ELV5-P8-008, ELV5-P9-003. Статус: SPEC_RESOLVED / RUNTIME_NOT_IMPLEMENTED.

## ELV5-AUD-02 — HIGH: Оценка VBR storage не равна гарантии retention

**Дефект:** Expected bitrate sizing может пройти selected capacity check, но не гарантирует срок хранения при VBR; scope гарантии не был отдельным входом/выходом.

**Исправление ТЗ:** Явный sizingBasis EXPECTED_ESTIMATE либо GUARANTEED_UPPER_BOUND. Для guarantee интегрировать подтверждённый upper-bound bitrate/schedule model; missing bound ->UNRESOLVED. Estimate может пройти только estimate-capacity и всегда retentionGuarantee=NOT_ASSESSED. Recording identity=(streamId,poolId,copyRole); duplicate identity rejected; two deliberate pools/copies counted explicitly.

**Контрпример/проверка:** 1Mbps expected for3600s=450MB,4Mbps upper=1.8GB;500MB pool passes estimate but fails guaranteed upper-bound sizing. No guarantee from a generic1.1 reserve.

**Пункты:** ELV5-P1-002, ELV5-P1-004, ELV5-P3-003, ELV5-P3-005, ELV5-P8-002, ELV5-P9-006. Статус: SPEC_RESOLVED / RUNTIME_NOT_IMPLEMENTED.

## ELV5-AUD-03 — HIGH: Запас оптического бюджета не является физическим затуханием

**Дефект:** Не разделены physical loss minimum и design reserve. Вычитание запаса из RxMax может скрыть перегрузку приёмника.

**Исправление ТЗ:** Physical loss interval excludes reserve. Sensitivity check: TxMin-lossMax >= sensitivity+requiredSensitivityMargin. Overload: TxMax-lossMin <= receiverMax; no reserve is added to lossMin. Both directions pin separate optics/wavelength/path facts.

**Контрпример/проверка:** TxMax=-1dBm,physicalLossMin=0,receiverMax=-3,reserve2dB ->overload FAIL (-1>-3), never PASS from artificial Rx=-3.

**Пункты:** ELV5-P1-002, ELV5-P4-005, ELV5-P8-002, ELV5-P8-008, ELV5-P9-003. Статус: SPEC_RESOLVED / RUNTIME_NOT_IMPLEMENTED.

## ELV5-AUD-04 — HIGH: Подсчёт адресов должен проверять полные множества ресурсов

**Дефект:** Count/addressConsumption не задаёт однозначно все занятые адреса многоканального модуля и может не обнаружить пересечение диапазонов.

**Исправление ТЗ:** Assignments store explicit address set or versioned deterministic expansion with loop/panel address domain; expanded cardinality must equal profile consumption. Uniqueness is checked on full(domain,address) set including reserved resources, not just start address. Noncontiguous sets allowed only by selected profile.

**Контрпример/проверка:** ModuleA=[1,2],moduleB=[2,3],capacity5 ->counts4 fit, but overlap address2 gives FAIL; not silently union3 addresses.

**Пункты:** ELV5-P1-004, ELV5-P6-001, ELV5-P6-007, ELV5-P8-002, ELV5-P8-008. Статус: SPEC_RESOLVED / RUNTIME_NOT_IMPLEMENTED.

## ELV5-AUD-05 — HIGH: Ключ подсчёта NVR/VMS channels/licences

**Дефект:** Количество encoded streams не всегда соответствует определённому профилем количеству recorder channels/licenses; ключ группировки не был обязательным.

**Исправление ТЗ:** Recorder profile explicitly selects accounting basis DEVICE, ENCODED_STREAM or LICENSE_CHANNEL with exact assignments. Enforce each declared channel/license capacity separately. Sum actual ingress and recordings independently of channel grouping. Missing accounting basis ->BLOCKED.

**Контрпример/проверка:** One camera/main4Mbps+sub1Mbps,DEVICE basis,limit1 ->1 channel PASS,ingress5Mbps. ENCODED_STREAM basis/limit1 ->2 channels FAIL. Storage still counts selected distinct recordings.

**Пункты:** ELV5-P1-004, ELV5-P3-002, ELV5-P3-005, ELV5-P8-002, ELV5-P9-003. Статус: SPEC_RESOLVED / RUNTIME_NOT_IMPLEMENTED.

## ELV5-AUD-06 — MEDIUM: Машинные зависимости нельзя выводить из поясняющих строк

**Дефект:** Registry dependencies смешивали notes и коды вроде ELV-PWR-01/03; машинный DAG и scope binding нельзя проверить однозначно.

**Исправление ТЗ:** Keep notes separately; add typed upstreamProcesses(processCode,scopeBinding,subjectBinding,when), plus registered factKinds. Only registered code-owned bindings/conditions accepted; no free-text parsing or executable expressions. Validate known codes and DAG; external ELV3/ELV4 codes use explicit adapter contracts.

**Контрпример/проверка:** FA-06 has separate ELV-PWR-01 and03 edges. Unknown code, unresolved scope binder and cycle are rejected before registry publication.

**Пункты:** ELV5-P1-001, ELV5-P1-008, ELV5-P7-001, ELV5-P7-003, ELV5-P8-008, ELV5-P9-001. Статус: SPEC_RESOLVED / RUNTIME_NOT_IMPLEMENTED.

## ELV5-AUD-07 — MEDIUM: Gross versus already-usable rack capacity basis

**Дефект:** Available RU не указывает, были ли резервы/неиспользуемые зоны уже исключены; повторное вычитание даёт неправильный margin.

**Исправление ТЗ:** Capacity basis is GROSS_WITH_EXCLUSIONS or NET_USABLE. Gross subtracts explicit unavailable/reserved set once; net never subtracts those again and records their provenance. Equipment demand is distinct from excluded reserve. Actual slot/depth/thermal fit stays NOT_ASSESSED until ELV6.

**Контрпример/проверка:** Gross6RU,reserved1RU,equipment3RU ->free2RU. Net usable5RU with same reservation already excluded ->free2RU, not1RU.

**Пункты:** ELV5-P1-004, ELV5-P4-006, ELV5-P8-002, ELV5-P9-007. Статус: SPEC_RESOLVED / RUNTIME_NOT_IMPLEMENTED.

## ELV5-AUD-08 — HIGH: полнота FOV camera coverage

**Дефект:** footprint-only мог считаться квалифицированным процессом без H/V углов. **Исправление:** оба FOV interval включены в обязательные dimensions; зафиксирован bounded rational backend с range reduction/alternating-series bounds и пределами итераций/ширины. Missing backend не даёт полного PASS. Oracle: 6x4mm sensor/6mm focal ->H .927295218…rad,V .643501108…rad и footprint3x2m на высоте3m. Статус SPEC_RESOLVED/RUNTIME_NOT_IMPLEMENTED.

## Выполненные проверки и ограничения

Проверены exact-rational storage/ceil, оценка против upper-bound retention, оптический overload без ложного reserve-loss, пересечение адресных множеств, camera-versus-stream channel key и gross/net RU. Проверены уникальность 27 process codes/80 requirement IDs, типизированные upstream ссылки, scope/subject registries и отсутствие циклов; ссылки документов и whitespace проверены отдельно. Это контрактные probes/структурная проверка, не исполнение Dart/Flutter/Drift/public-command verticals.

Отсутствующие strict runtime wire schemas, полные публичные fixture datasets и принятые ELV4 runtime capabilities уже явно являются P0/P1/P2/P8 gates, а не скрываются за этим аудитом. Не объявлялись national compliance, real product performance или cabinet fit.

## Вердикт

Первичный audit/remediation проход завершён на уровне ТЗ. Можно продолжать дизайн/входную проверку P0 и детализировать wire/qualification contracts; реализация и acceptance пакетов требуют предусмотренных source/test/CI доказательств. Сохраняется DESIGN DRAFT / RUNTIME NOT_STARTED.

Проверяемый результат design-only guard: [elv5-specification-checks.json](elv5-specification-checks.json). Запуск: `python scripts/ci/check-elv5-specification.py`. Он не подтверждает runtime/standards compliance.

## Актуализация базы 2026-10-16

Первичный аудит выше сохранён как история проверки discipline-контрактов. ELV4 теперь реализован, принят и замержен; предположения о design-only prerequisite заменены [контрактом реализованной базы](../product/elv5-implementation/implemented-baseline.md). Восемь замечаний к новым discipline-процессам сохраняют SPEC_RESOLVED / runtime NOT_IMPLEMENTED; их не закрывает унаследованный ELV4 PASS.
