USE ROLE ROLE_ENGINEER;
USE WAREHOUSE WH_TRANSFORM;
USE SCHEMA LOGISTICS_DB.STAGING;

-- Every raw event must be accounted for: good + rejected = raw
SELECT (SELECT COUNT(*) FROM LOGISTICS_DB.RAW.events)       AS raw_events,
       (SELECT COUNT(*) FROM stg_events)                    AS good_events,
       (SELECT COUNT(*) FROM stg_event_rejects)             AS rejected_events,
       raw_events - good_events - rejected_events           AS unaccounted;

-- Why rows were rejected
SELECT reject_reason, COUNT(*) AS n
FROM stg_event_rejects GROUP BY reject_reason ORDER BY n DESC;

-- No duplicates left in the clean table
SELECT COUNT(*) - COUNT(DISTINCT event_id) AS duplicate_ids_left FROM stg_events;

-- Repairs and flags on the clean table
SELECT COUNT_IF(hub_imputed)      AS hubs_imputed,
       COUNT_IF(is_late_arriving) AS late_arriving_events
FROM stg_events;
