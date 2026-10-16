# ELV4 — технический аудит ТЗ P0–P9

Дата: 2026-10-15. Проверенный локальный HEAD: `4404c02bba777515f70e58150dd8a25bff0a1573`.
Удалённая ветка на момент read-only fetch: `29e0ad06c72d10b38b620d56215ee12f5179c7b8`. Два последних design-коммита пока локальные.

**Вердикт: ТЗ пока не готово к полной реализации без уточнения контрактов.** Архитектурное направление сохраняется: канонические identities, power aspects, pure core, scoped history и общие budgets. Однако найдены конфликты, влияющие на хранение истории, повторное выполнение, сценарные расчёты и честную приёмку.

Проверены все **80 требований**, все десять package specifications, shared runtime contracts, governing/coordinated specification, delivery plan и fictional fixtures; сопоставлены ключевые existing source consumers/writers. Это аудит проектирования и реализуемости, а не утверждение о наличии работающего ELV4 runtime.

## Сводка

Найдено **15 открытых замечаний: 1 BLOCKER, 10 HIGH, 4 MEDIUM**. Полная [матрица 80 требований](requirements-review.md) и [машиночитаемый реестр](findings-and-coverage.json).

BLOCKER означает риск нарушения границы общего существующего механизма при следовании предложенному контракту. HIGH — конфликт или пропущенное решение, меняющее функциональность/историю/приёмку. MEDIUM — обязательная детализация для однозначной реализации. Ни один NO_LOCAL_FINDING не является implementation PASS.

## Метод и ограничения

- Прочитаны исходные требования и действующие Dart/Drift interfaces/consumers. Ссылки path:line ниже зафиксированы для проверенного HEAD.
- Контрпримеры сохранены в [probes.json](probes.json): IEEE-754 boundary, isolated SQLite sequence uniqueness, моделирование segment key и source predicates.
- Python/Decimal и отдельная SQLite модель используются как contract probes; это не исполнение Dart/Flutter или настоящих команд приложения. Flutter/Dart SDK в текущем PATH отсутствуют.
- Ранее открытые BASE-01…04 не закрывались. Их повторное упоминание не считается новым подтверждённым runtime багом.
- Нормативные значения/стандарты не утверждались; все числовые данные синтетические, выводы основаны на коде и внутренних контрактах.

## Замечания по приоритету

### ELV4-AUD-01 — BLOCKER: Общее хранилище результатов не изолировано от устаревшего пересчёта

Класс: `INTEGRATION_CONFLICT`. Пункты: `ELV4-P0-003`, `ELV4-P0-004`, `ELV4-P2-005`, `ELV4-P7-001`, `ELV4-P7-002`, `ELV4-P8-008`, `ELV4-P9-002`, `ELV4-P9-004`.

Доказательства:
- [`docs/product/elv4-coordinated-p0-p9-contract.md:150`](../../../docs/product/elv4-coordinated-p0-p9-contract.md) — `- Each immutable evaluation uses another nodeKey tuple `(elv4-evaluation, logicalNodeKey, evaluationId)`. Its inputsJson contains the complete resolved input snapshot or immutable content-addressed refs; dependenciesJson is populated, sorted and unique. No update/upsert overwrites this evaluation.`
- [`docs/product/elv4-implementation/p2-persistence-commands.md:71`](../../../docs/product/elv4-implementation/p2-persistence-commands.md) — ``dependenciesJson` contains full sorted typed keys including absent dependencies. Existing ELV3 rows remain decodable. Do not route evaluation rows through existing blanket `invalidate` logic. Frozen snapshots embed selected pointer/evaluation content or immutable verifiable references captured in the same transaction. References must remain resolvable after archive and cleanup; no GC of referenced frozen/replay evidence.`
- [`apps/mobile/lib/data/repositories/drift_dependency_recalculation_repository.dart:36`](../../../apps/mobile/lib/data/repositories/drift_dependency_recalculation_repository.dart) — `state: EngineeringDerivedState.values.byName(r.state),`
- [`apps/mobile/lib/data/repositories/drift_dependency_recalculation_repository.dart:72`](../../../apps/mobile/lib/data/repositories/drift_dependency_recalculation_repository.dart) — `final cache = rows.where((r) => r.deletedAt == null).map(decode).toList();`
- [`packages/engineering_core/lib/src/dependency_recalculation.dart:143`](../../../packages/engineering_core/lib/src/dependency_recalculation.dart) — `cache.keys.where((key) => !nodes.containsKey(key)).toSet();`
- [`apps/mobile/lib/data/repositories/drift_dependency_recalculation_repository.dart:760`](../../../apps/mobile/lib/data/repositories/drift_dependency_recalculation_repository.dart) — `for (final key in snapshot.session.removedKeys) {`

**Контрпример / недостающая развилка:** В ProjectDerivedResults добавлены pointer и immutable evaluation ELV4. Пользователь запускает существующий общий recalculate(projectId). Его load читает все строки проекта без фильтра владельца; неизвестные ключи попадают в removedKeys и получают deletedAt. Если SQL state записан буквально CURRENT/STALE, decode дополнительно несовместим с lower-case enum старого клиента.

**Последствие:** Нарушается неизменяемость истории либо ломается общий экран пересчёта. Изменить только ELV4 adapter недостаточно. Это подтверждённый риск наследуемого consumer; работающий ELV4-код ещё не существует.

**Необходимое исправление ТЗ:** Утвердить owner/domain и recordKind для всех строк: legacy node, ELV3 node, ELV4 pointer, ELV4 evaluation. Ограничить SELECT/decode/recalculate/removedKeys/manual/retirement каждого consumer своей областью; определить SQL-кодеки состояний. Зафиксировать это как обязательную совместную доработку P2/P7 и регрессию P8.

**Проверка исправления:** Создать mixed project с legacy/ELV3/ELV4 строками, выполнить существующий общий load/recalculate/manual-flow, закрыть и открыть БД. Ни одна чужая immutable строка не изменена/помечена удалённой; чужой кодек не вызывается; старый пересчёт работает.

### ELV4-AUD-02 — HIGH: Допустимый ноль ELV4 несовместим с валидацией канонического порта

Класс: `CONFIRMED_CONTRACT_CONFLICT`. Пункты: `ELV4-P1-001`, `ELV4-P1-002`, `ELV4-P1-007`, `ELV4-P2-002`, `ELV4-P2-008`, `ELV4-P8-008`.

Доказательства:
- [`docs/product/elv4-implementation/p1-domain-catalog.md:11`](../../../docs/product/elv4-implementation/p1-domain-catalog.md) — `| ELV4-P1-001 | Implement typed validated quantities, edition refs and immutable value objects with explicit absent/zero semantics | P1-T01 domain boundaries |`
- [`docs/product/elv4-implementation/p1-domain-catalog.md:12`](../../../docs/product/elv4-implementation/p1-domain-catalog.md) — `| ELV4-P1-002 | Bind power roles to canonical port/component IDs with one owner per projected field | P1-T02 ownership conflict |`
- [`packages/engineering_core/lib/src/engineering_topology.dart:139`](../../../packages/engineering_core/lib/src/engineering_topology.dart) — `if (v != null && (!v.isFinite || v <= 0))`
- [`packages/engineering_core/lib/src/engineering_topology_graph.dart:95`](../../../packages/engineering_core/lib/src/engineering_topology_graph.dart) — `for (final message in p.validate())`

**Контрпример / недостающая развилка:** Сценарий STANDBY/OFF задаёт известную нагрузку 0W. При прямой проекции в EngineeringPort.powerDemandW=0 существующий validate возвращает INVALID_PORT; connectionFindings включает этот результат.

**Последствие:** Сохранение/соединение валидного отключённого потребителя отвергается либо ноль ошибочно заменяется null и становится неизвестной нагрузкой.

**Необходимое исправление ТЗ:** Явно определить, какие статические поля канонического порта допускают ноль, а какие остаются положительными; либо полностью хранить state-demand в power aspects и определить совместимую статическую проекцию. Обновление общего validator должно быть отдельным согласованным изменением с legacy-тестами.

**Проверка исправления:** Через публичные команды сохранить OFF=0 и неизвестный demand=null, соединить/переоткрыть; два состояния различаются и не нарушают существующие положительные паспортные ограничения.

### ELV4-AUD-03 — HIGH: Не определена проекция нескольких состояний и сценариев в один канонический порт

Класс: `MISSING_PROJECTION_POLICY`. Пункты: `ELV4-P1-002`, `ELV4-P1-004`, `ELV4-P1-007`, `ELV4-P2-003`, `ELV4-P2-008`, `ELV4-P3-002`, `ELV4-P3-005`, `ELV4-P7-004`.

Доказательства:
- [`docs/product/elv4-implementation/p1-domain-catalog.md:12`](../../../docs/product/elv4-implementation/p1-domain-catalog.md) — `| ELV4-P1-002 | Bind power roles to canonical port/component IDs with one owner per projected field | P1-T02 ownership conflict |`
- [`docs/product/elv4-implementation/p2-persistence-commands.md:12`](../../../docs/product/elv4-implementation/p2-persistence-commands.md) — `| ELV4-P2-002 | Implement transaction-bound power stores and integrate canonical port writers without independent commits | P2-T02 rollback all writes |`
- [`packages/engineering_core/lib/src/engineering_topology.dart:127`](../../../packages/engineering_core/lib/src/engineering_topology.dart) — `final double? powerLimitW, powerDemandW;`
- [`apps/mobile/lib/data/repositories/drift_engineering_topology_repository.dart:313`](../../../apps/mobile/lib/data/repositories/drift_engineering_topology_repository.dart) — `'Profile-instantiated ports are frozen. Release the binding before changing their characteristics.',`
- [`apps/mobile/lib/data/repositories/drift_engineering_topology_repository.dart:326`](../../../apps/mobile/lib/data/repositories/drift_engineering_topology_repository.dart) — `'Resolve external/internal links and group attachments before changing a port.',`
- [`packages/engineering_core/lib/src/engineering_topology_graph.dart:215`](../../../packages/engineering_core/lib/src/engineering_topology_graph.dart) — `b.powerDemandW! > a.powerLimitW!)`

**Контрпример / недостающая развилка:** У одного входа demand STANDBY=2W, ALARM=10W; разные сценарии выбирают разные активные transfer. Каноническая запись имеет ровно одно powerDemandW/voltage/powerDirection. ТЗ назначает владельца полей, но не функцию проекции, момент обновления и правила проверки существующих соединений. Обычный savePort также запрещает редактирование bound/connected портов.

**Последствие:** Разработчик может менять глобальный порт при переключении UI-сценария, перезаписывать ELV2 provenance или получать противоречивые connection guards. Модель сценария перестаёт быть чистым чтением.

**Необходимое исправление ТЗ:** Зафиксировать static nameplate projection против scenario-resolved facts. Переключение сценария не пишет канонические строки. Определить отдельный transaction-bound writer для reviewed adoption существующих connected/bound портов, повторную проверку затронутых связей и политику shared ownership.

**Проверка исправления:** Один порт с двумя состояниями и двумя сценариями: переключение только меняет read context; row revision/payload/provenance порта не меняются; проверка потребления берёт выбранный state, а паспортная совместимость остаётся стабильной. Adoption не обходит чужие инварианты.

### ELV4-AUD-04 — HIGH: У результатов по сегментам отсутствует обязательная сегментная идентичность

Класс: `IDENTITY_AMBIGUITY`. Пункты: `ELV4-P1-008`, `ELV4-P2-005`, `ELV4-P4-007`, `ELV4-P6-005`, `ELV4-P7-001`, `ELV4-P7-003`, `ELV4-P8-004`, `ELV4-P8-007`.

Доказательства:
- [`docs/product/elv4-coordinated-p0-p9-contract.md:149`](../../../docs/product/elv4-coordinated-p0-p9-contract.md) — `- A logical node key is canonical encoded tuple `(elv4, revisionId, scenarioId, processCode, subjectKind, subjectId)` within project scope. Use a versioned tuple encoder, not delimiter concatenation of unrestricted IDs.`
- [`docs/product/elv4-implementation/shared-contracts.md:34`](../../../docs/product/elv4-implementation/shared-contracts.md) — `Query context: projectId, designRevisionId, scenarioId, optional segmentId/subject, trace direction. Frozen query chooses its immutable reader before resolving any canonical row. WORKING read captures a consistent view. Display filtering by system is a presentation constraint, not a different calculation scope.`
- [`docs/product/elv4-implementation/shared-contracts.md:42`](../../../docs/product/elv4-implementation/shared-contracts.md) — ``PowerProcessEvaluation` contains processCode, subject, scenario/segment, algorithmVersion, inputSchemaVersion, outputSchemaVersion, numericPolicyVersion, inputFingerprint, quantities, contribution records, assumptions, findings and dependency keys. Each quantity records unit and boundary. Every contribution has a unique origin `(port/load/transfer ID, segmentId, accountingKind)`.`
- [`docs/product/elv4-implementation/p4-load-conversion.md:28`](../../../docs/product/elv4-implementation/p4-load-conversion.md) — `Each records algorithm/input/output/numeric versions and the exact scenario segment. No storage read inside core. Application orchestrator builds physical-domain subproblems, gets PoE/DC boundary demand and evaluates parent conversions in reverse topological order.`

**Контрпример / недостающая развилка:** PWR-01 для source X в BACKUP/STANDBY и BACKUP/ALARM имеет один logical key (revision,scenario,process,subject), поскольку segmentId отсутствует. ТЗ одновременно допускает segment-specific запросы и segment-specific evaluations.

**Последствие:** Публикация ALARM может заменить pointer STANDBY; непонятно, что именно читает PWR-04 и что замораживается.

**Необходимое исправление ТЗ:** Выбрать один обязательный контракт: segmentId/SEGMENT_SET в logical key либо одна scenario evaluation с полным ordered segment result set. Определить отдельный ключ sequence-процесса PWR-04, правила batch publication и зависимости между ними.

**Проверка исправления:** Рассчитать два сегмента одного scenario/subject, опубликовать в разном порядке, переоткрыть и заморозить. Оба значения адресуются однозначно; сумма энергии использует полную согласованную последовательность.

### ELV4-AUD-05 — HIGH: Generic PSU/UPS definitions не имеют завершённого пути в каноническую совместимость

Класс: `INCOMPLETE_CANONICAL_BRIDGE`. Пункты: `ELV4-P0-005`, `ELV4-P0-006`, `ELV4-P1-005`, `ELV4-P2-002`, `ELV4-P2-003`, `ELV4-P3-001`, `ELV4-P3-003`, `ELV4-P5-007`, `ELV4-P8-001`.

Доказательства:
- [`docs/product/elv4-implementation/p1-domain-catalog.md:42`](../../../docs/product/elv4-implementation/p1-domain-catalog.md) — `A generic power component definition contains template ports and local transfers without a ReferenceDiscipline or CanonicalComponentClass requirement. Instantiation creates canonical ELV1 ports through a transaction-bound existing port writer. Existing ports require explicit template-to-port mapping, or an explicitly reviewed creation of missing ports; never match by label alone.`
- [`docs/product/elv4-implementation/p1-domain-catalog.md:26`](../../../docs/product/elv4-implementation/p1-domain-catalog.md) — `| PowerPortDefinition | port template code, powerRole SOURCE/CONSUMER/BIDIRECTIONAL/PASSIVE, envelope, continuous limits and optional peak envelope |`
- [`packages/engineering_core/lib/src/engineering_topology_graph.dart:148`](../../../packages/engineering_core/lib/src/engineering_topology_graph.dart) — `issue('MEMBERSHIP_REQUIRED',`
- [`packages/engineering_core/lib/src/engineering_topology_graph.dart:160`](../../../packages/engineering_core/lib/src/engineering_topology_graph.dart) — `issue('FAMILY_PROFILE',`
- [`packages/engineering_core/lib/src/engineering_topology_graph.dart:171`](../../../packages/engineering_core/lib/src/engineering_topology_graph.dart) — `issue('COMPATIBILITY_UNRESOLVED',`
- [`packages/engineering_core/lib/src/engineering_reference_catalog.dart:435`](../../../packages/engineering_core/lib/src/engineering_reference_catalog.dart) — `if (profiles.isEmpty && cableDefinitions.isEmpty)`

**Контрпример / недостающая развилка:** Импортируется каталог только с power component/port definitions, без fake discipline class. Для нового PSU создаются порты. Existing connection validator требует connector, exact protocol, owning system membership обоих компонентов и compatibility profile с разрешённой family edition. Полный набор этих данных и membership/compatibility materialization для generic source не задан; текущий root validator также не признаёт power-only каталог непустым.

**Последствие:** Профиль можно описать, но публичная последовательность создания соединения и shared-source vertical остаётся недоопределённой.

**Необходимое исправление ТЗ:** Описать обязательную структуру generic port template, ссылки на vocabulary/interface/protocol, генерацию exact compatibility definitions, публикационную проверку power-only catalog и явное membership решение для источника, используемого несколькими системами. Транзакционные writers не должны обходить existing graph guards.

**Проверка исправления:** Один минимальный новый power-only каталог через import → placed generic PSU → ports → memberships → canonical connection → calculate/reopen. Никаких fake camera/controller/cable filler definitions и raw SQL.

### ELV4-AUD-06 — HIGH: Обязательные backup/converter цепочки не согласованы с запретом constant-power DC

Класс: `SUPPORTED_SCOPE_CONFLICT`. Пункты: `ELV4-P0-005`, `ELV4-P4-008`, `ELV4-P6-003`, `ELV4-P6-005`, `ELV4-P6-006`, `ELV4-P6-007`, `ELV4-P8-001`, `ELV4-P9-006`.

Доказательства:
- [`docs/product/elv4-implementation/p6-dc-backup.md:50`](../../../docs/product/elv4-implementation/p6-dc-backup.md) — `First runtime implementation supports radial constant-current DC only. DC constant-power or voltage-dependent loads, shared-return meshes and parallel source networks return ELV4_UNSUPPORTED_ELECTRICAL_MODEL. A converter input behaving as constant power cannot be silently retyped as constant current.`
- [`docs/product/elv4-implementation/p6-dc-backup.md:50`](../../../docs/product/elv4-implementation/p6-dc-backup.md) — `First runtime implementation supports radial constant-current DC only. DC constant-power or voltage-dependent loads, shared-return meshes and parallel source networks return ELV4_UNSUPPORTED_ELECTRICAL_MODEL. A converter input behaving as constant power cannot be silently retyped as constant current.`
- [`docs/product/elv4-implementation/p8-acceptance.md:43`](../../../docs/product/elv4-implementation/p8-acceptance.md) — `| CCTV | AC boundary → UPS → PSE → camera(s); PD/PSE loss and own-load boundary | Same canonical combined cable allocation; input PF explicit; upstream/backup dependencies |`
- [`docs/product/elv4-implementation/p8-acceptance.md:46`](../../../docs/product/elv4-implementation/p8-acceptance.md) — `| Fire | PSU/charger/bank → panel and declared loads; standby/alarm sequence | Explicit hours/model, no implicit fire policy; loop signal topology does not create power loop |`
- [`docs/product/elv4-power-topology-design-specification.md:15`](../../../docs/product/elv4-power-topology-design-specification.md) — `First release supports explicit radial AC/DC supply chains, converters, transformers, distribution/fused outputs, PSE/PD PoE, UPS, chargers and battery banks. A declared transfer device may select alternative supplies per operating scenario. Arbitrary parallel sources, load-sharing, backfeed and circulating-current networks remain unresolved and cannot receive a successful calculation. Closed fire signal loops are not automatically cyclic power networks.`

**Контрпример / недостающая развилка:** UPS/inverter/DC-DC при фиксированной выходной W-нагрузке задаёт DC inputW по модели efficiency. Это constant-power нагрузка на батарейной линии; P6 явно запрещает её переобозначать постоянным током. Тем не менее battery/UPS/converter backup входит в обязательные положительные verticals. Нулевое сопротивление или заданная boundary estimate может быть отдельным случаем, но исключение и его гарантии не определены.

**Последствие:** ТЗ не гарантирует существование полного положительного backup vertical в заявленном первом scope; риск реализации только частичной оценки под видом закрытого ELV4.

**Необходимое исправление ТЗ:** Либо включить ограниченный проверенный radial constant-power solver, либо определить точный допустимый boundary/ideal-transfer режим, что он доказывает и какие физические размерности остаются unresolved. Согласовать один обязательный полный положительный сценарий каждого заявленного типа до реализации.

**Проверка исправления:** Указать реализуемую bank → converter → protected load модель с необходимыми паспортами/физикой и ожидаемыми verdict по каждой размерности. Отдельно показать BLOCKED для физически неподдерживаемой DC линии; номинальный W/V не заменяет solver.

### ELV4-AUD-07 — HIGH: Create-next не задаёт remapping revision-specific run/traversal references

Класс: `MATERIALIZATION_GAP`. Пункты: `ELV4-P0-007`, `ELV4-P2-006`, `ELV4-P5-008`, `ELV4-P6-008`, `ELV4-P7-007`, `ELV4-P8-004`, `ELV4-P8-007`.

Доказательства:
- [`docs/product/elv4-implementation/p2-persistence-commands.md:77`](../../../docs/product/elv4-implementation/p2-persistence-commands.md) — `Create-next requires no existing active WORKING under current lifecycle rules. Materialize scoped aspects and children with stable logical IDs/new scoped PKs; preserve canonical component/port IDs and exact edition references. R1 pointers are not editable in R2. Inherited evidence remains provenance, with new current pointers STALE/absent until validated under R2 input. Pre-power source revision creates an explicitly audited empty draft only when selected by command; no silent inferred power model.`
- [`docs/product/elv4-implementation/p6-dc-backup.md:32`](../../../docs/product/elv4-implementation/p6-dc-backup.md) — `Section fields: sectionId, canonical connection/allocation/run/traversal refs, parent/child terminal IDs, lengthBasis, installedLengthM, resistanceModel tag, temperature evidence, forward/return/contact resistance, current rating and source/consumer applicability.`
- [`apps/mobile/lib/data/repositories/drift_elv_design_revision_repository.dart:304`](../../../apps/mobile/lib/data/repositories/drift_elv_design_revision_repository.dart) — `final newRunId = '${revision.id}:run:$sourceRunId';`
- [`apps/mobile/lib/data/repositories/drift_elv_design_revision_repository.dart:335`](../../../apps/mobile/lib/data/repositories/drift_elv_design_revision_repository.dart) — `id: '$newRunId:trv:$sequence',`

**Контрпример / недостающая развилка:** R1 power physical evidence/dependencies ссылаются на run/traversal R1. Existing createNext создаёт новые run/traversal IDs. ТЗ говорит сохранить logical aspect IDs и скопировать children, но не задаёт mapping старых физических identity → новых и не запрещает ссылки R2 на R1 run.

**Последствие:** R2 может брать длины/termination/path history из R1 или отвергать собственные FK/scope checks; R1/R2 dependency invalidation смешиваются.

**Необходимое исправление ТЗ:** Задать материализатор с полной таблицей identity classes: project-stable, revision-scoped logical, ELV3 newly generated physical IDs, historical provenance-only. Перепривязать все текущие physical refs; provenance refs сохранить отдельно. Проверять отсутствие operational R1 refs в R2.

**Проверка исправления:** Freeze R1 с несколькими кабелями, create R2, проверить mapping run/traversal/aspect/keys; изменить только R2 route, переоткрыть. R2 использует R2 физику, R1 неизменен.

### ELV4-AUD-08 — HIGH: Hash прямой команды не позволяет восстановить redo после перезапуска

Класс: `DURABLE_REDO_GAP`. Пункты: `ELV4-P2-007`, `ELV4-P7-006`, `ELV4-P8-004`, `ELV4-P8-006`, `ELV4-P9-002`.

Доказательства:
- [`docs/product/elv4-implementation/p2-persistence-commands.md:83`](../../../docs/product/elv4-implementation/p2-persistence-commands.md) — `Undo/redo stores command schema, before/after hashes, affected identities, expected cursor and inverse payload. New ordinary edit invalidates the redo suffix according to existing history policy. Irreversible freeze/archive/adoption follows reviewed existing policy; never pretend an edition adoption can be undone by replacing catalog bytes.`
- [`apps/mobile/lib/application/elv_command_history_repository.dart:27`](../../../apps/mobile/lib/application/elv_command_history_repository.dart) — `final String? inverseCommandType;`
- [`apps/mobile/lib/application/elv_command_history_repository.dart:11`](../../../apps/mobile/lib/application/elv_command_history_repository.dart) — `required this.forwardPayloadSha256,`
- [`apps/mobile/lib/data/database/app_database.dart:785`](../../../apps/mobile/lib/data/database/app_database.dart) — `class CommandExecutionRecords extends Table {`

**Контрпример / недостающая развилка:** SetPowerLoad меняет 2W на 10W. Сохранены forward schema/hash и inverse payload (2W), ledger содержит normalizedPayloadSha256 и logical response. После undo и перезапуска нельзя восстановить прямой payload 10W только из hash/receipt. Immutable before/after snapshots могли бы помочь, но их полное хранение для history не задано.

**Последствие:** Persisted redo не реализуется однозначно; in-memory forward command не выполняет требование restart.

**Необходимое исправление ТЗ:** Задать durable history schema с canonical forwardPayloadJson и inversePayloadJson либо полными immutable before/after aggregate snapshots плюс гарантированным восстановлением команды. Привязать историю к designRevision и определить cursor/branch/versioning/GC правила.

**Проверка исправления:** Обычный edit → close/reopen → undo → close/reopen → redo. Новый commandId для reauthorized redo, исходный payload восстановлен точно, original replay не используется как действие redo; frozen history не изменяется.

### ELV4-AUD-09 — HIGH: Строгое сравнение double даёт ложное превышение на точной границе

Класс: `NUMERICAL_COUNTEREXAMPLE`. Пункты: `ELV4-P1-001`, `ELV4-P1-008`, `ELV4-P4-004`, `ELV4-P5-005`, `ELV4-P6-002`, `ELV4-P8-008`.

Доказательства:
- [`docs/product/elv4-implementation/shared-contracts.md:52`](../../../docs/product/elv4-implementation/shared-contracts.md) — `Validation consistency and solver residual comparisons use `abs(a-b) <= max(1e-9, 1e-9 * max(abs(a),abs(b)))` in the quantity's canonical unit. This tolerance is not permission to exceed a rating. Capacity pass uses the unrounded computed demand <= declared available capacity; near-boundary uncertainty is exposed as a finding when input precision requires it. UI rounding never changes verdict. Source min/max range checks use unrounded bounds.`
- [`docs/product/elv4-implementation/p4-load-conversion.md:42`](../../../docs/product/elv4-implementation/p4-load-conversion.md) — `Reserve policy v1 chooses a multiplier >=1 at an explicit selection boundary. `required = demand * multiplier`; `available = nameplate * derating`, derating in `(0,1]`. Signed margin = available-required; utilization = required/available where available >0. If declared zero available capacity, utilization is undefined with a zero-capacity finding, not division by zero.`

**Контрпример / недостающая развилка:** Для limit=0.3 double sum(0.1,0.2)=0.30000000000000004, verdict FAIL. Для тех же десятичных 0.3, разложенных 0.15+0.15, sum=0.3, verdict PASS. Stable enumeration order не устраняет ошибку. Probes повторяют требуемую IEEE-754 модель; Dart runtime не запускался.

**Последствие:** Ложные перегрузки, отрицательные margins около нуля и зависимость verdict от декомпозиции эквивалентной нагрузки.

**Необходимое исправление ТЗ:** Разделить representational error и инженерный допуск. Утвердить decimal/fixed-point либо проверяемую ULP/interval error policy с BOUNDARY/UNRESOLVED для неопределённости; не вводить произвольный engineering epsilon, разрешающий реальное превышение.

**Проверка исправления:** Пограничные decimal-equivalent суммы и конвертации дают согласованный verdict. Реальное превышение вне вычислительной погрешности остаётся FAIL. Fingerprint и версии политики фиксируются.

### ELV4-AUD-10 — HIGH: Выбор старой frozen базы не согласован с уникальной sequence

Класс: `REVISION_LINEAGE_GAP`. Пункты: `ELV4-P0-007`, `ELV4-P2-006`, `ELV4-P8-006`, `ELV4-P9-004`.

Доказательства:
- [`docs/product/elv4-power-topology-design-specification.md:152`](../../../docs/product/elv4-power-topology-design-specification.md) — `Extend the existing coordinated freeze operation with a versioned power section stored as a companion snapshot and manifest under the same designRevisionId. Keep the existing snapshotHash as the physical hash; a separately versioned manifest binds physicalHash and powerHash. Freeze all records in one transaction, as detailed in the coordinated contract. Capture component/port profiles, connection layers, transfers, scenarios, capacity groups, bank data, exact cable/resource/termination/length facts and all current power evidence needed for replay. Retain old snapshot hashes. Historical pre-ELV4 snapshots return POWER_NOT_CAPTURED; never backfill from current tables. New WORKING revision may explicitly initialize power from a complete selected frozen section or an audited empty draft.`
- [`docs/product/elv4-implementation/p2-persistence-commands.md:77`](../../../docs/product/elv4-implementation/p2-persistence-commands.md) — `Create-next requires no existing active WORKING under current lifecycle rules. Materialize scoped aspects and children with stable logical IDs/new scoped PKs; preserve canonical component/port IDs and exact edition references. R1 pointers are not editable in R2. Inherited evidence remains provenance, with new current pointers STALE/absent until validated under R2 input. Pre-power source revision creates an explicitly audited empty draft only when selected by command; no silent inferred power model.`
- [`apps/mobile/lib/data/repositories/drift_elv_design_revision_repository.dart:278`](../../../apps/mobile/lib/data/repositories/drift_elv_design_revision_repository.dart) — `sequence: base.sequence + 1,`
- [`apps/mobile/lib/data/database/app_database.dart:822`](../../../apps/mobile/lib/data/database/app_database.dart) — `{projectId, sequence},`

**Контрпример / недостающая развилка:** В проекте уже есть frozen R1(sequence1) и R2(sequence2), active WORKING отсутствует. Create-next выбирает R1. Existing code вычисляет sequence2 и попадает в UNIQUE(projectId,sequence). ТЗ не ограничивает выбор latest frozen и не задаёт отдельный глобальный sequence allocation/branching contract.

**Последствие:** Разрешённый по описанным предусловиям запрос завершается конфликтом хранения; восстановление модели от старой ревизии недоопределено.

**Необходимое исправление ТЗ:** Определить latest-only с явным domain error либо монотонную project-wide sequence независимо от basedOnRevisionId; формально описать branching/materialization и CAS allocator. Это отдельная baseline reconciliation задача, не доказательство уже реализованного ELV4 дефекта.

**Проверка исправления:** R1 → R2, оба frozen; create from R1 проверяется явным ожидаемым domain result либо создаёт новую уникальную sequence с корректной provenance; два клиента не создают две WORKING ревизии.

### ELV4-AUD-11 — MEDIUM: Версионированные wire payloads ещё не имеют проверяемой полной схемы

Класс: `WIRE_SCHEMA_GAP`. Пункты: `ELV4-P1-005`, `ELV4-P1-006`, `ELV4-P1-008`, `ELV4-P2-001`, `ELV4-P2-003`, `ELV4-P8-003`.

Доказательства:
- [`docs/product/elv4-implementation/p1-domain-catalog.md:40`](../../../docs/product/elv4-implementation/p1-domain-catalog.md) — `New catalog payloads declare a new explicit catalog schema understood by the new decoder. Proposed `power` section contains `schema: electra.elv4-power-definitions.v1`, arrays `portDefinitions`, `componentDefinitions`, `transferDefinitions`, `poeDefinitions`, `batteryDefinitions` and `policyDefinitions`. Every definition has a unique normalized code, version, sourceRef and typed body. References resolve within the exact root edition; no latest-version lookup.`
- [`docs/product/elv4-implementation/p1-domain-catalog.md:40`](../../../docs/product/elv4-implementation/p1-domain-catalog.md) — `New catalog payloads declare a new explicit catalog schema understood by the new decoder. Proposed `power` section contains `schema: electra.elv4-power-definitions.v1`, arrays `portDefinitions`, `componentDefinitions`, `transferDefinitions`, `poeDefinitions`, `batteryDefinitions` and `policyDefinitions`. Every definition has a unique normalized code, version, sourceRef and typed body. References resolve within the exact root edition; no latest-version lookup.`
- [`docs/product/elv4-implementation/p2-persistence-commands.md:47`](../../../docs/product/elv4-implementation/p2-persistence-commands.md) — `Proposed command schema names: `electra.command.elv4.<operation>.v1`; operation is a fixed registered name, not arbitrary user text. Families are bind/adopt/release-power-profile, set-power-load-profile, replace-power-transfers, replace-power-capacity-group, replace-power-supply-requirement, create/replace/archive-power-scenario, bind/replace-poe-delivery, configure-backup-assembly, replace-battery-bank and calculate-power-process. Existing revision command schemas require explicit compatible extension or versioned replacement; old replay decoding must remain available.`
- [`apps/mobile/lib/data/repositories/drift_elv_runtime_support.dart:73`](../../../apps/mobile/lib/data/repositories/drift_elv_runtime_support.dart) — `payloadSchemaVersion: 1,`

**Контрпример / недостающая развилка:** Зафиксированы имена разделов и варианты объектов, но отсутствуют полные wire fields/nullability/union tags/version-dispatch для реального минимального каталога и каждой command/result/history схемы. Fixtures специально не являются import payloads. Existing success helper всегда пишет payloadSchemaVersion=1, тогда как freeze/create-next требуют нового versioned payload.

**Последствие:** Два разработчика могут независимо создать несовместимые JSON и replay decoders; заявленный codec gate пока нельзя выполнить по единому oracle.

**Необходимое исправление ТЗ:** Добавить строгие JSON Schema либо эквивалентные типизированные codec specifications, минимальные valid/invalid wire примеры, dispatch по версии и явное расширение ledger helper без потери старых replay.

**Проверка исправления:** Полный новый import/reimport/replay round-trip, старый payload byte/hash invariant, неизвестный mandatory version rejection, optional metadata policy и реальная запись schema version.

### ELV4-AUD-12 — MEDIUM: Пусковые нагрузки и diversity не имеют полного временного aggregation контракта

Класс: `TEMPORAL_MODEL_GAP`. Пункты: `ELV4-P1-003`, `ELV4-P1-004`, `ELV4-P4-006`, `ELV4-P6-006`, `ELV4-P8-008`.

Доказательства:
- [`docs/product/elv4-implementation/p4-load-conversion.md:58`](../../../docs/product/elv4-implementation/p4-load-conversion.md) — `Peak record contains pulse W/A/VA, durationSeconds, simultaneous group and recurrence/applicability when required. Compare against a declared source peak envelope at the same duration. Unsupported duration/interpolation yields UNRESOLVED; do not average into steady watts. Safety-critical diversity requires explicit applicable policy.`
- [`docs/product/elv4-implementation/p4-load-conversion.md:58`](../../../docs/product/elv4-implementation/p4-load-conversion.md) — `Peak record contains pulse W/A/VA, durationSeconds, simultaneous group and recurrence/applicability when required. Compare against a declared source peak envelope at the same duration. Unsupported duration/interpolation yields UNRESOLVED; do not average into steady watts. Safety-critical diversity requires explicit applicable policy.`
- [`docs/product/elv4-coordinated-p0-p9-contract.md:109`](../../../docs/product/elv4-coordinated-p0-p9-contract.md) — `Diversity is allowed only for a declared mutually exclusive/group policy. It cannot reduce a per-port guaranteed requirement or a safety-critical load without explicit applicable policy. Report demand, applied factor, reserve and capacity as distinct quantities.`

**Контрпример / недостающая развилка:** Два импульса с разными duration и возможным пересечением, собственный steady load и recharge demand. ТЗ требует simultaneity/recurrence, но не задаёт интервалы/корреляции/события и поддерживаемую функцию построения source envelope.

**Последствие:** Нельзя однозначно воспроизвести требуемый peak. Возможны ошибочное усреднение или применение коэффициента к гарантированному per-port требованию.

**Необходимое исправление ТЗ:** Ограничить первую версию ALL_SIMULTANEOUS с консервативной проверкой поддерживаемых durations либо задать точную event/interval модель, наложение pulses, steady baseline и интерполяцию рейтинга. Неизвестная корреляция не уменьшает worst case.

**Проверка исправления:** Разные durations, overlap/non-overlap, steady+peak и recharge+load имеют точные golden outputs; неизвестный envelope даёт UNRESOLVED, не PASS.

### ELV4-AUD-13 — MEDIUM: Область input fingerprint не связана формально с consumed dependencies

Класс: `INPUT_PROJECTION_GAP`. Пункты: `ELV4-P4-007`, `ELV4-P7-001`, `ELV4-P7-002`, `ELV4-P7-003`, `ELV4-P8-002`, `ELV4-P8-008`.

Доказательства:
- [`docs/product/elv4-implementation/shared-contracts.md:40`](../../../docs/product/elv4-implementation/shared-contracts.md) — ``PowerInputSnapshot` contains scope, designToken, scenario/segment payloads, exact port/component/connection/internal mapping data, aspect sets, installed physical evidence, exact definition contents/hashes, policy refs and algorithm/numeric versions. Missing required inputs are represented by typed unresolved entries with dependency identities, not dropped rows.`
- [`docs/product/elv4-implementation/shared-contracts.md:56`](../../../docs/product/elv4-implementation/shared-contracts.md) — `Input fingerprint includes scope IDs, resolved technical input, missing-input markers, exact editions, selected scenario/policy, algorithm/input/output/numeric versions. It excludes calculatedAt, commandId, evaluationId, display labels and UI selection. A design token guards publication but is excluded from the technical fingerprint: unrelated edits can advance it without changing input. Revalidation may then recapture/retry safely.`
- [`docs/product/elv4-implementation/p7-dependencies-workspace.md:37`](../../../docs/product/elv4-implementation/p7-dependencies-workspace.md) — `Changed source voltage affects downstream compatibility/DC terminal results and loss-sensitive upstream/backup basis. Changed bank usable model affects protected energy capacity and explicit charging dependencies; unrelated normal demand stays current. Changed unrelated room label is a required negative control. A broad revision token is a concurrency guard, not permission to mark all numerical results stale.`
- [`docs/product/elv4-implementation/p8-acceptance.md:83`](../../../docs/product/elv4-implementation/p8-acceptance.md) — `Permutation of input iteration order preserves fingerprints/quantities/findings; adding an unrelated isolated source leaves existing logical results unchanged; adding one distinct load increases matching group demand once; a duplicate system membership does not add physical demand. Loop resistance input and explicit forward+return equivalent produce equal simple DC result. Series bank increases V, parallel count increases Ah; capacity factors apply once.`

**Контрпример / недостающая развилка:** PowerInputSnapshot описан как полный захват графа/аспектов, а fingerprint как resolved technical input. Одновременно требуется не менять результат от независимого источника. Не задана функция subject/process input projection и равенство hash inputs фактически прочитанным dependency keys.

**Последствие:** Глобальное хеширование делает независимые результаты stale; слишком узкое хеширование допускает late publication по устаревшим фактам.

**Необходимое исправление ТЗ:** Для каждого process описать canonical consumed-input projection и missing/set-membership dependencies. Хешировать именно этот технический срез; designToken использовать отдельно как CAS guard. Проверять полноту зависимостей instrumented source reads либо эквивалентным контрактом.

**Проверка исправления:** Независимый source/label не меняет technical fingerprint; новая ветвь shared source меняет; заполнение missing profile меняет; поздняя публикация не проходит с изменившимся consumed input.

### ELV4-AUD-14 — MEDIUM: Freeze/RUNNING не согласован с моделью execution и протоколом публикации

Класс: `LIFECYCLE_CONTRADICTION`. Пункты: `ELV4-P2-006`, `ELV4-P7-003`, `ELV4-P7-007`, `ELV4-P8-006`, `ELV4-P9-008`.

Доказательства:
- [`docs/product/elv4-power-topology-design-specification.md:189`](../../../docs/product/elv4-power-topology-design-specification.md) — `Voltage-drop/load feedback is solved inside a bounded process contract, not by introducing dependency cycles. Freeze rejects RUNNING evidence; incomplete designs may freeze with explicit BLOCKED/NOT_CALCULATED findings, but cannot claim successful engineering acceptance.`
- [`docs/product/elv4-implementation/shared-contracts.md:46`](../../../docs/product/elv4-implementation/shared-contracts.md) — `Freshness lives on the current pointer: CURRENT or STALE. Evaluation completion: COMPLETE, PARTIAL or BLOCKED; assessment: PASS, FAIL or UNRESOLVED. Execution: SUCCEEDED or FAILED. Structural/input-domain failures prevent a result from asserting PASS. A proved violated limit can report FAIL even when other dimensions are unresolved; per-dimension status remains available. Overall PASS requires every required dimension complete and passing.`
- [`docs/product/elv4-implementation/p7-dependencies-workspace.md:41`](../../../docs/product/elv4-implementation/p7-dependencies-workspace.md) — `Create request contains scope, process/subject set, command ID and expected input context. Capture under one consistent read transaction; build a dependency-complete immutable input. Run pure evaluator outside write transaction. Reopen short publish transaction and check ledger, WORKING lifecycle, token, recaptured technical fingerprint and prior pointer generation.`
- [`docs/product/elv4-implementation/p8-acceptance.md:75`](../../../docs/product/elv4-implementation/p8-acceptance.md) — `| Freeze versus calculate publish | After capture before publish | Publisher blocked after freeze; captured pointers coherent |`

**Контрпример / недостающая развилка:** Основная спецификация требует reject freeze при RUNNING evidence. Shared contract не содержит RUNNING state или durable job/lease registry; вычисление идёт вне write transaction, P8 допускает freeze с последующим отклонением publisher. Для одного и того же interleaving возможны два разных обязательных результата.

**Последствие:** Расходятся реализация freeze, UI и race tests; непонятно, где лежит статус незавершённой работы после restart.

**Необходимое исправление ТЗ:** Выбрать nonblocking freeze текущих committed фактов с token invalidation для in-flight calculation либо persisted run registry/lease с явным запретом. Согласовать одинаковое правило в governing spec/shared/P7/P8, отдельно хранить неизменяемый evaluation и transient operation state.

**Проверка исправления:** Barrier capture → start compute → freeze → publish даёт один заранее определённый результат; restart не оставляет вечный RUNNING; старый evaluation не превращается в successful fresh result.

### ELV4-AUD-15 — HIGH: Не закреплены обязательные COMPLETE/PASS размерности положительных verticals

Класс: `ACCEPTANCE_GATE_GAP`. Пункты: `ELV4-P0-006`, `ELV4-P8-001`, `ELV4-P8-008`, `ELV4-P9-001`, `ELV4-P9-003`, `ELV4-P9-006`, `ELV4-P9-007`, `ELV4-P9-008`.

Доказательства:
- [`docs/product/elv4-implementation/p8-acceptance.md:50`](../../../docs/product/elv4-implementation/p8-acceptance.md) — `V1/V3/V4/V6 numerical cases are boundary arithmetic oracles. Full vertical builders must provide explicit remaining compatible profiles, ratings, source bounds and physical evidence; the oracle alone cannot assert whole-design PASS. In particular, a constant-W energy sequence does not prove a supported nonlinear DC terminal solution. Use supported constant-current radial loads for terminal-voltage acceptance, or keep that dimension explicitly unresolved.`
- [`docs/product/elv4-implementation/p9-closure.md:56`](../../../docs/product/elv4-implementation/p9-closure.md) — `Zero open BLOCKER/HIGH at runtime closure. Lower findings require explicit decision, owner and target scope. Unsupported general meshes/parallel sources, initial nonlinear DC, unimplemented explicit-loss PoE, detailed battery curves and guaranteed recharge-time predictions are declared scope limits, not silently passing capabilities. A required vertical that depends on an unsupported model blocks acceptance; it cannot be waived by calling the model a limitation after implementation.`
- [`docs/product/elv4-implementation/p8-acceptance.md:33`](../../../docs/product/elv4-implementation/p8-acceptance.md) — `6. Evaluate supported processes; assert topology, realization, quantities, contribution origins, statuses and dependencies.`
- [`docs/examples/elv4-power-design-fixtures.json:9`](../../../docs/examples/elv4-power-design-fixtures.json) — `"scope": "CCTV_PoE_boundary",`

**Контрпример / недостающая развилка:** P8 допускает оставить физическую размерность unresolved, P9 запрещает принимать required vertical на неподдерживаемой модели. Нет scenario×process×dimension gate: какие checks обязаны быть COMPLETE/PASS для каждого положительного кейса. V1 не задаёт конкретные guaranteedPdW/path profiles, V4 не задаёт complete end-of-discharge/voltage model — это честно названо boundary oracles, но не заменяет полный acceptance dataset.

**Последствие:** Все тесты могут формально пройти с BLOCKED/UNRESOLVED в существенной части функциональности; либо P8 и P9 будут требовать несовместимое закрытие.

**Необходимое исправление ТЗ:** Составить versioned qualification manifest: для каждого vertical перечень обязательных процессов, required dimensions, expected statuses, полный input/provenance dataset и отдельные allowed limitation cases. Negative/unsupported tests не засчитываются как положительная вертикаль.

**Проверка исправления:** Автоматический validator отвергает closure, если положительный кейс имеет required dimension UNRESOLVED/BLOCKED/NOT_CALCULATED. Каждый допустимый partial estimate явно находится вне qualification PASS; P9 читает тот же manifest.

## Порядок устранения

1. **До P1/P2:** закрыть A01–A05 и A09; определить owner isolation, static/scenario projection, result identity и полный generic canonical bridge. Уточнить wire-контракты A11.
2. **До приёмки P2:** закрыть A07/A08/A10/A14; зафиксировать remapping, durable redo, lineage и единую freeze race policy.
3. **До расчётных вертикалей P4–P6:** согласовать A06/A12 — точный поддерживаемый электрический/временной scope, не скрывая физический BLOCKED.
4. **До P7/P8/P9:** закрыть A13/A15; один consumed-input/dependency contract и qualification manifest должны управлять публикацией и closure.
5. Выполнить исходные BASE-01…04 gates и только затем оценивать runtime entry/closure. Аудит не даёт разрешения заменить доказательства baseline новым статусом документа.

## Следующий проверяемый результат

Для каждого OPEN finding требуется versioned изменение указанных governing/shared/package контрактов, дополнение acceptance cases и повторная сверка affected требований. Реализацию приложения и runtime gates этот audit-коммит не закрывает. Изменения ТЗ в данном проходе не внесены автоматически: сохранены именно дефекты и конкретные условия их исправления.
