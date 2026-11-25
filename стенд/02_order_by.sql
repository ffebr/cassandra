-- =====================================================================
-- Задание 2. Ключ сортировки и объём чтения
-- Запуск после задания 1 (исходная takt.listening_events уже загружена).
-- =====================================================================

-- 2.1 Подготовка: две копии истории 13-26 октября с разным ключом
DROP TABLE IF EXISTS takt.hw_events_country;
DROP TABLE IF EXISTS takt.hw_events_time;

CREATE TABLE takt.hw_events_time
AS takt.listening_events
ENGINE = MergeTree
ORDER BY (ended_at)
SETTINGS
    index_granularity = 8192,
    index_granularity_bytes = 0;

CREATE TABLE takt.hw_events_country
AS takt.hw_events_time
ENGINE = MergeTree
ORDER BY (country, ended_at)
SETTINGS
    index_granularity = 8192,
    index_granularity_bytes = 0;

INSERT INTO takt.hw_events_time
SELECT *
FROM takt.listening_events
WHERE ended_at >= toDateTime('2026-10-13 00:00:00', 'UTC')
  AND ended_at <  toDateTime('2026-10-27 00:00:00', 'UTC');

INSERT INTO takt.hw_events_country
SELECT * FROM takt.hw_events_time;

OPTIMIZE TABLE takt.hw_events_time FINAL;
OPTIMIZE TABLE takt.hw_events_country FINAL;

-- Проверка подготовки: по одной активной части и 10 000 000 событий
SELECT
    table,
    count() AS active_parts,
    sum(rows) AS events
FROM system.parts
WHERE database = 'takt'
  AND active
  AND table IN ('hw_events_time', 'hw_events_country')
GROUP BY table
ORDER BY table;

SHOW CREATE TABLE takt.hw_events_time;      -- ORDER BY ended_at
SHOW CREATE TABLE takt.hw_events_country;   -- ORDER BY (country, ended_at)

-- 2.2 Четыре запроса за 24 октября 2026 (UTC) с одинаковым блоком SETTINGS.
--     Read: rows/bytes берём из X-ClickHouse-Summary HTTP-ответа (аналог Read в /play).
--     Для EXPLAIN indexes = 1 добавляем префикс и сохраняем блок Keys/Condition/Parts/Granules.

-- Германия, ключ (ended_at)
SELECT country, count() AS events_total, countIf(played_seconds < 20) AS events_under_20,
       round(100 * countIf(played_seconds < 20) / count(), 2) AS under_20_percent
FROM takt.hw_events_time
WHERE ended_at >= toDateTime('2026-10-24 00:00:00', 'UTC')
  AND ended_at <  toDateTime('2026-10-25 00:00:00', 'UTC')
  AND country = 'DE'
GROUP BY country
ORDER BY country
SETTINGS max_threads = 4, use_query_cache = 0, use_query_condition_cache = 0, optimize_move_to_prewhere = 0;

-- Германия, ключ (country, ended_at)
SELECT country, count() AS events_total, countIf(played_seconds < 20) AS events_under_20,
       round(100 * countIf(played_seconds < 20) / count(), 2) AS under_20_percent
FROM takt.hw_events_country
WHERE ended_at >= toDateTime('2026-10-24 00:00:00', 'UTC')
  AND ended_at <  toDateTime('2026-10-25 00:00:00', 'UTC')
  AND country = 'DE'
GROUP BY country
ORDER BY country
SETTINGS max_threads = 4, use_query_cache = 0, use_query_condition_cache = 0, optimize_move_to_prewhere = 0;

-- Все страны, ключ (ended_at)
SELECT country, count() AS events_total, countIf(played_seconds < 20) AS events_under_20,
       round(100 * countIf(played_seconds < 20) / count(), 2) AS under_20_percent
FROM takt.hw_events_time
WHERE ended_at >= toDateTime('2026-10-24 00:00:00', 'UTC')
  AND ended_at <  toDateTime('2026-10-25 00:00:00', 'UTC')
GROUP BY country
ORDER BY country
SETTINGS max_threads = 4, use_query_cache = 0, use_query_condition_cache = 0, optimize_move_to_prewhere = 0;

-- Все страны, ключ (country, ended_at)
SELECT country, count() AS events_total, countIf(played_seconds < 20) AS events_under_20,
       round(100 * countIf(played_seconds < 20) / count(), 2) AS under_20_percent
FROM takt.hw_events_country
WHERE ended_at >= toDateTime('2026-10-24 00:00:00', 'UTC')
  AND ended_at <  toDateTime('2026-10-25 00:00:00', 'UTC')
GROUP BY country
ORDER BY country
SETTINGS max_threads = 4, use_query_cache = 0, use_query_condition_cache = 0, optimize_move_to_prewhere = 0;

-- Планы (пример; добавить EXPLAIN indexes = 1 перед SELECT).
-- EXPLAIN indexes = 1 SELECT ... (тот же текст, формат: Keys, Condition, Parts, Granules)