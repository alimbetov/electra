# ELV4 — повторная проверка после исправления ТЗ

Дата: 2026-10-15. Основа исправлений: audit commit `75cac79`; исходное проверенное ТЗ `4404c02`.

Все **15 замечаний устранены на уровне спецификации**. Статус `SPEC_RESOLVED` означает, что решение закреплено в согласованных контрактах, схемах/примерах и приёмочных требованиях. Это не закрывает runtime-дефекты, не подтверждает реализацию и не заменяет BASE-01…04.

Исходный [аудит](report.md), его 80 построчных оценок и контрпримеры оставлены историческими. Текущий [реестр исправлений](remediation.json) связывает каждое замечание с требованиями и будущей проверкой.

| Аудит | Решение в ТЗ | Проверка реализации |
|---|---|---|
| A01 BLOCKER | Явные resultOwner/recordKind; фильтрация всех legacy/ELV3/ELV4 consumers до decode/retirement/manual writes | RM01-T mixed-owner restart/regression |
| A02 HIGH | Ноль — только state demand; канонический nameplate сохраняет null-or-positive | RM02-T zero versus unknown |
| A03 HIGH | Статическая проекция независима от сценария; reviewed connected writer проверяет весь candidate graph | RM03-T read-only scenario/adoption |
| A04 HIGH | Обязательные SEGMENT/segmentId и SEQUENCE/scenarioId ключи; атомарные consumed generation checks | RM04-T два сегмента и энергия |
| A05 HIGH | Полный power-only catalog wire, exact interface/compatibility materialization и явные system memberships | RM05-T import/bind/connect/reopen |
| A06 HIGH | Поддерживаемый ограниченный single-CP feeder solver с корнями/границами, необходимый для UPS backup | RM06-T oracle, no-solution, boundary и vertical |
| A07 HIGH | Typed identity map, remapping operational refs, separate provenance и reviewed restore старой базы | RM07-T R1/R2 физика без смешения |
| A08 HIGH | Полные durable forward/inverse commands, revision-local cursors, новый commandId на undo/redo | RM08-T два restart и redo |
| A09 HIGH | Decimal-string → exact rational; conservative solver intervals, equality PASS без инженерного epsilon | RM09-T равенство и реальное превышение |
| A10 HIGH | Project-wide allocator max+1, CAS generation, independent basedOnRevision | RM10-T старая база и race |
| A11 MEDIUM | Строгие wire schemas, valid/invalid examples, actual ledger version dispatch и semantic validators | RM11-T schema/codec/replay |
| A12 MEDIUM | ALL_SIMULTANEOUS, TOTAL/INCREMENTAL, event trace и консервативный max load на longest window | RM12-T 35/25/5W и envelope |
| A13 MEDIUM | Consumed facts map точно совпадает с dependency set; отсутствующие/set inputs включены | RM13-T isolated/shared/missing changes |
| A14 MEDIUM | Nonblocking freeze только committed evidence; RUNNING transient, late publisher конфликтует | RM14-T freeze/publish barriers |
| A15 HIGH | Один qualification manifest, полный resolved synthetic input и required process×dimension COMPLETE/PASS | RM15-T partial positive запрещён |

Основные документы: [RM01–RM15](../../product/elv4-implementation/remediation-contract.md), [wire registry](../../product/elv4-implementation/wire-contract.md), [qualification](../../product/elv4-implementation/qualification.json), [builder contract](../../product/elv4-implementation/qualification-builders.md).

Проверка документации выполняется `python scripts/ci/check-elv4-specification.py`. Она проверяет поддерживаемые structural schema constraints, valid/invalid examples, ссылки/реестры и математические contract oracles. Реальный файл SQLite с public-command verticals, Drift migration, Dart/Flutter, конкурентные команды и редактор должны быть проверены при реализации, а не объявлены работающими данным проходом.

Машиночитаемый [результат проверки](remediation-checks.json) отдельно указывает `runtimeImplemented=false`. История SHA исходного аудита сохранена; новые изменения не переписывают старую причину и серьёзность замечаний.
