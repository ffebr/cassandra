# Результаты сценариев

Артефакты: `results.json` - статусы и числа сценариев; `tablestats.txt` /
`tablestats_plain.txt` - `bash ops.sh tablestats`; `repair.txt` - `bash ops.sh repair`;
`compaction.txt` - `bash ops.sh compact`.

Все сценарии `results.json` имеют статус `passed`: `data` (16 проверок), `bulk` (5),
`consistency` (4), `compaction` (5), `metrics` (10).

## `bulk` - вставка 10 000

| Что вставлено | Сколько | Время |
|---|---|---|
| События пользователя 1001 (`login`, `purchase`, `view`) | 10 000 | 5.887 с |

Среднее на запись = 5.887 / 10 000 ≈ **0.59 мс**. Источник: `artifacts.bulk.seconds`.

## `consistency` - ONE и QUORUM

| Уровень | Запись, мс | Чтение, мс |
|---|---|---|
| ONE | 465 | 2 |
| QUORUM | 678 | 3 |

Источник: `artifacts.consistency` (секунды переведены в мс; медианы 5 прогонов после прогрева).

## Сжатие - `tablestats`

| Таблица | Space used (total) | SSTable count | SSTable Compression Ratio |
|---|---|---|---|
| `user_actions` (LZ4) | 151 609 | 1 | 0.38191 |
| `user_actions_none` (без сжатия) | 386 886 | 1 | −1.00000 |

Источник - `tablestats.txt` (секция `hw3.user_actions`) и `tablestats_plain.txt`
(секция `hw3.user_actions_none`).

## Bloom-фильтр

| Показатель | Значение |
|---|---|
| Bloom filter false positives | 0 |
| Bloom filter false ratio | 0.00000 |

Источник - `tablestats.txt`, секция `hw3.user_actions`.

## `compaction` - TWCS и TTL

| Показатель | Значение |
|---|---|
| Стратегия компакции | `TimeWindowCompactionStrategy` |
| Окно компакции | 1 день (`compaction_window_unit=DAYS`, `compaction_window_size=1`) |
| default_time_to_live | 2592000 (30 дней) |
| События с TTL 5 секунд: до / после истечения | 5 / 0 |

Источник - `results/results.json`, раздел `artifacts.compaction`, и `compaction.txt`
(major compaction `hw3.user_actions`, bytes 146 047 → 146 047).

## `data` и `repair`

`data` - `status: passed`, 16 проверок: две таблицы, partition key `user_id`,
clustering `event_time DESC`, колонки `event_type`/`payload`, сжатие LZ4 у `user_actions`
и его отключение у `user_actions_none`, 20 фикстур пользователя 1001, чтение 5 последних
в порядке убывания времени.

`repair` - `results/repair.txt`, финальные строки:

```
Starting repair command #2 ... repairing keyspace hw3
  (parallelism: parallel, incremental: true, # of ranges: 48, ...)
Repair completed successfully  ... finished in 0 seconds
```

Anti-entropy: repair активно сверяет и исправляет расхождения между репликами вне пути
чтения; при долгой работе без него реплики расходятся, чтение может вернуть неактуальные
данные, а tombstones не подчищаются. Отличия: read repair чинит только ключи, затронутые
чтением; hinted handoff компенсирует короткие простои узла хинтами.