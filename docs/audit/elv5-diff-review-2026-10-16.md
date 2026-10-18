# Audit report: feat/flutter-elv5-power-topology-design

**Ветка:** feat/flutter-elv5-power-topology-design  
**База сравнения:** main @ d2b059d4c11a284cdd32965140f6df3c40020c8d  
**HEAD на момент аудита:** 61534ea13a37245cff563da3603ea8f9c7358e02  
**Дата:** 2026-10-16  
**Инструмент:** локальный клон; публикация коммитов — GitHub API с expected_sha и без force

## 1. Объём изменений

- На проверенном HEAD против main: **98 файлов; +23644 / -36 строк**.
- Начальный remote HEAD этого прохода: `bf0b1c2951bd223411f7927a3185e133d38bb522` (94 файла; +23086 / -36).
- Затронутые слои: техническое задание/domain/data contracts, архитектурные документы, реестры, Python CI и workflow. Изменений production `.dart`, `pubspec.yaml` и `pubspec.lock` в diff нет.
- Объём ТЗ: 27 процессов (6 CCTV, 7 LAN, 6 ACS, 8 FA), 16 команд, 80 требований P0–P9. ELV4 baseline сохранён; ELV5 runtime остаётся `NOT_STARTED`.
- Существующие изменения других сессий сохранены через fast-forward. Незавершённый локальный альтернативный черновик сохранён отдельно и не включён как конкурирующий контракт.
- Данный отчёт, журнал проверок и ссылка из индекса добавляются отдельным последующим коммитом; приведённая статистика относится к указанному проверенному HEAD.

## 2. Результаты статического анализа

```text
flutter pub get --enforce-lockfile: NOT RUN — executable 'flutter' not found (127)
flutter analyze: NOT RUN — executable 'flutter' not found (127)
dart format --output=none --set-exit-if-changed lib test:
  NOT RUN — executable 'dart' not found (127)
flutter test: NOT RUN — executable 'flutter' not found (127)

check-elv5-*.py: 13/13 PASS
ELV5 unittest suite: 21 tests, OK
Command example key-set probes: 16 positive + 114 negative, PASS
check-elv4-specification.py: PASS
ELV4 closure unittest suite: 5 tests, OK
git diff --check: PASS
Authority manifest: CLEAN / EXACT_HEAD
450 planned market scenarios: generated; runtime executed=0
1500 combinatorial scenarios: generated; 16011/16011 pairs, 330/330 targeted triples
```

Полные команды, stdout/stderr и exit codes: [elv5-diff-review-checks.json](elv5-diff-review-checks.json).

Fingerprint проверенного ТЗ: `d18e9512ada9d72c5d30ec37d70324dcb12abeca53894d50627143e82ffa2c65`.
Он относится к `61534ea`, а не к будущему коммиту отчёта. После любого изменения
входящих в manifest документов артефакты необходимо сформировать заново.

GitHub Actions для проверенного SHA: [Flutter Local Foundation, run 38907667151](https://github.com/alimbetov/electra/actions/runs/38907667151), статус при подготовке отчёта — `in_progress`. Успешный Flutter runtime/CI результат этим отчётом не заявлен.

## 3. Исправленные дефекты

### P0

Подтверждённых P0 в проверенном diff не обнаружено. Это не результат Flutter analyze: SDK отсутствует, а production Dart в diff не менялся.

### P1

| # | Файл:строка (после исправления) | Описание и проверка | Коммит |
|---|---|---|---|
| A1 | `scripts/ci/generate-elv5-combinatorial-1500.py:166` | Генератор принимал fingerprint из 64 букв `z`. Теперь проверяет алфавит, хэш core, полный inventory, байты файлов и равенство заново построенному manifest. Отрицательная репродукция до фикса завершалась exit 0. | `628a386` |
| A2 | `scripts/ci/elv5_evidence.py:20` | `GITHUB_SHA` мог подменять реальный HEAD; dirty tree маркировалось точным SHA без оговорки. Теперь HEAD проверяется, dirty по умолчанию отвергается; `--allow-dirty` выдаёт только WORKTREE_PREVIEW. Регрессии покрывают tracked/untracked изменения и чужой SHA. | `628a386` |
| A3 | `scripts/ci/check-elv5-market-simulation.py:401` | 10 POSITIVE-строк содержали отрицательный запас, но называли ожидаемый исход PASS. В result.v2 отделены plannedDisposition, независимая синтетическая арифметика и проверка знаков; fullProcessAssessment=NOT_ASSESSED. Числа не подменялись ради PASS. | `1f2a4d5` |
| A4 | `docs/product/elv5-implementation/persistence-schema-contract.md:582` | PK FireAddressClaims включал bindingId, позволяя разным привязкам занять один физический адрес. Добавлены domain-wide UNIQUE, составной FK членства, активные claims и атомарное повторное занятие адресов при undo. 7 SQLite-тестов исполняют SQL из ТЗ. | `0f5a0de` |
| A5 | `docs/product/elv5-implementation/typed-process-api.md:215` | Peak/upper bitrate не фиксировал окно и силу гарантии. CctvRateEvidence разделяет target, measurement, window и pointwise bound; несопоставимые окна не дают гарантированный PASS. Добавлен контрпример 8/0 Mbit/s и обязательная передача статуса в CCTV-03/05. | `6ec7723` |

### P2

| # | Файл:строка (после исправления) | Описание и проверка | Коммит |
|---|---|---|---|
| A6 | `scripts/ci/check-elv5-command-examples.py:65` | Проверка читала описание отказа, но не выполняла мутацию. Теперь удаляет поля и проверяет отказ; дополнительно проверяет лишнее поле, не-object payload и неизвестную операцию. 114 отрицательных probes реально выполнены; вложенные codecs ими не объявлены проверенными. | `61534ea` |

## 4. Не исправлено (с обоснованием)

| # | Файл:строка / область | Severity | Почему не исправлено |
|---|---|---|---|
| L1 | `apps/mobile` / `packages/engineering_core` | Ограничение проверки | Flutter/Dart SDK отсутствует локально. Flutter CI проверяется отдельно; статический просмотр не объявлен эквивалентом анализатора или тестов. |
| L2 | `qualification-contract.md`, L0–L6 | План runtime | Реализация 27 kernels/resolvers, 16 codecs/handlers, миграции 24, UI и runtime acceptance не входит в подготовку ТЗ и не существует в этом diff. NOT_STARTED сохранён. |
| L3 | Матрицы 450/1500 | План runtime | Нужны полные согласованные входы, независимые ожидаемые результаты и исполнение production public path. Комбинаторное покрытие и скалярные diagnostics не закрывают эту работу. |

Открытых подтверждённых P0/P1 **из находок этого прохода** не оставлено.
Исправления A4/A5 закрыты на уровне ТЗ; их будущая реализация обязана пройти
указанную приёмку. Абсолютное отсутствие дефектов и готовность runtime к merge
не заявлены.

## 5. Out of scope (найдено вне diff)

- Production Flutter UI/state, обработка mounted/dispose, DI, локализация и accessibility не изменены в этой ветке. Массовый аудит/рефакторинг этих файлов не проводился.
- Подтверждённых дефектов вне diff, требующих отдельного исправления, в ходе этого прохода не зафиксировано.
- Зависимости, lockfile, main и ветки ELV6/ELV7/ELV8 этим проходом не изменялись; merge не выполнялся.

## 6. Коммиты, добавленные в ветку

```text
628a386 fix(elv5): verify exact-head authority evidence before matrix publication
1f2a4d5 fix(elv5): distinguish planned scenarios from scalar evidence
0f5a0de fix(elv5): prevent cross-binding fire address collisions in schema contract
6ec7723 fix(elv5): qualify CCTV peak and retention claims by rate evidence
61534ea test(elv5): execute command example rejection mutations
```

Отчёт и журнал оформлены следующим отдельным `chore(elv5)` коммитом; его SHA
не записывается внутрь собственного содержимого.

## 7. Рекомендации ревьюеру

- Ревьюить ветку как ТЗ и проверочные инструменты. Production runtime acceptance не подменять историческим ELV4 PASS.
- Начать с A4/A5, затем проверить реальное отклонение повреждённого manifest и provenance A1/A2.
- Для следующего HEAD заново сформировать manifest и обе матрицы; старый fingerprint не переносить.
- При реализации обеспечить L0–L6, миграцию/reopen/history/fault/race проверки и точную привязку каждого требования к source/test/evidence.

## 8. Что проверить вручную

- GitHub Flutter CI именно на финальном SHA, включая analyze, format, tests и отсутствие generated drift.
- Таблицу fire claims: одинаковый адрес у двух binding одного домена запрещён; разные домены допустимы; конфликт undo не оставляет частичных изменений.
- UI будущей реализации: configured/average bitrate не отображается как гарантированный пик; UNSUPPORTED/UNRESOLVED/STALE/engineering FAIL/execution failure различаются.
- Контрольный сценарий CCTV: 8 Mbit/s в первую секунду и 0 во вторую не проходит по 1 s peak на основании 2 s среднего 4 Mbit/s.
