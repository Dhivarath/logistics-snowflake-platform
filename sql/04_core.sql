USE ROLE ROLE_ENGINEER;
USE WAREHOUSE WH_TRANSFORM;
USE SCHEMA LOGISTICS_DB.CORE;

-- ---------- simple dimensions (no personal data) ----------
CREATE OR REPLACE TABLE dim_hub AS
SELECT hub_id, hub_name, city, state, region, capacity_per_day
FROM LOGISTICS_DB.STAGING.stg_hubs;

CREATE OR REPLACE TABLE dim_customer AS
SELECT customer_id, city, state, pincode, region
FROM LOGISTICS_DB.STAGING.stg_customers;

CREATE OR REPLACE TABLE dim_date AS
SELECT TO_NUMBER(TO_CHAR(d, 'YYYYMMDD')) AS date_key, d AS full_date,
       DAYNAME(d) AS day_name, DAYOFWEEKISO(d) AS iso_day_of_week,
       IFF(DAYOFWEEKISO(d) >= 6, TRUE, FALSE) AS is_weekend,
       MONTH(d) AS month_num, MONTHNAME(d) AS month_name,
       QUARTER(d) AS quarter_num, YEAR(d) AS year_num,
       IFF(MONTH(d) BETWEEN 6 AND 9, TRUE, FALSE) AS is_monsoon_season
FROM (SELECT DATEADD(day, SEQ4(), DATE '2026-05-01') AS d
      FROM TABLE(GENERATOR(ROWCOUNT => 400)));

-- ---------- PII vault (restricted schema) ----------
CREATE OR REPLACE TABLE LOGISTICS_DB.GOVERNANCE.pii_customer AS
SELECT customer_id, full_name, phone, email, address_line
FROM LOGISTICS_DB.STAGING.stg_customers;

CREATE OR REPLACE TABLE LOGISTICS_DB.GOVERNANCE.pii_rider AS
SELECT rider_id, rider_name, phone
FROM LOGISTICS_DB.STAGING.stg_riders;

-- ---------- rider dimension, SCD Type 2 ----------
-- One row per rider per hub period. Interval is [valid_from, valid_to).
CREATE OR REPLACE TABLE dim_rider AS
WITH segs AS (
  SELECT rider_id, hub_id, DATE '1900-01-01' AS valid_from, vehicle_type, join_date, status
  FROM LOGISTICS_DB.STAGING.stg_riders
  UNION ALL
  SELECT c.rider_id, c.new_hub_id, c.effective_date, r.vehicle_type, r.join_date, r.status
  FROM LOGISTICS_DB.STAGING.stg_rider_changes c
  JOIN LOGISTICS_DB.STAGING.stg_riders r ON r.rider_id = c.rider_id
)
SELECT ROW_NUMBER() OVER (ORDER BY rider_id, valid_from) AS rider_key,
       rider_id, hub_id, vehicle_type, join_date, status, valid_from,
       COALESCE(LEAD(valid_from) OVER (PARTITION BY rider_id ORDER BY valid_from),
                DATE '9999-12-31') AS valid_to,
       (LEAD(valid_from) OVER (PARTITION BY rider_id ORDER BY valid_from) IS NULL) AS is_current
FROM segs;

-- ---------- clean event-level fact ----------
CREATE OR REPLACE TABLE fact_event AS
SELECT event_id, shipment_id, status, event_ts,
       TO_NUMBER(TO_CHAR(event_ts, 'YYYYMMDD')) AS date_key,
       hub_id, rider_id, ingested_ts, ingest_lag_hours, is_late_arriving, hub_imputed
FROM LOGISTICS_DB.STAGING.stg_events;

-- ---------- shipment fact: one row per shipment ----------
CREATE OR REPLACE TABLE fact_shipment AS
WITH ev AS (
  SELECT shipment_id,
    MIN(IFF(status = 'PICKED_UP', event_ts, NULL))        AS picked_up_ts,
    MIN(IFF(status = 'AT_ORIGIN_HUB', event_ts, NULL))    AS at_origin_hub_ts,
    MIN(IFF(status = 'IN_TRANSIT', event_ts, NULL))       AS in_transit_ts,
    MIN(IFF(status = 'AT_DEST_HUB', event_ts, NULL))      AS at_dest_hub_ts,
    MIN(IFF(status = 'OUT_FOR_DELIVERY', event_ts, NULL)) AS first_out_for_delivery_ts,
    MIN(IFF(status = 'DELIVERED', event_ts, NULL))        AS delivered_ts,
    MIN(IFF(status = 'RETURNED', event_ts, NULL))         AS returned_ts,
    COUNT_IF(status = 'FAILED_ATTEMPT')                   AS failed_attempts,
    MAX(IFF(status = 'DELIVERED', rider_id, NULL))        AS delivery_rider_id
  FROM LOGISTICS_DB.STAGING.stg_events
  GROUP BY shipment_id
)
SELECT s.shipment_id, s.customer_id, s.origin_hub_id, s.dest_hub_id,
       TO_NUMBER(TO_CHAR(s.order_ts, 'YYYYMMDD')) AS order_date_key,
       s.order_ts, s.promised_ts, s.service_level, s.package_type,
       s.payment_mode, s.cod_amount, s.weight_kg,
       e.picked_up_ts, e.at_origin_hub_ts, e.in_transit_ts, e.at_dest_hub_ts,
       e.first_out_for_delivery_ts, e.delivered_ts, e.returned_ts, e.failed_attempts,
       r.rider_key AS delivery_rider_key,
       CASE WHEN e.delivered_ts IS NOT NULL THEN 'DELIVERED'
            WHEN e.returned_ts  IS NOT NULL THEN 'RETURNED'
            ELSE 'IN_PROGRESS' END AS current_status,
       (e.delivered_ts IS NOT NULL) AS is_delivered,
       (e.delivered_ts > s.promised_ts) AS is_late,
       DATEDIFF('minute', s.promised_ts, e.delivered_ts) / 60.0 AS hours_vs_promise,
       DATEDIFF('minute', s.order_ts, e.delivered_ts) / 60.0    AS hours_to_deliver
FROM LOGISTICS_DB.STAGING.stg_shipments s
LEFT JOIN ev e ON e.shipment_id = s.shipment_id
LEFT JOIN dim_rider r
  ON r.rider_id = e.delivery_rider_id
 AND CAST(e.delivered_ts AS DATE) >= r.valid_from
 AND CAST(e.delivered_ts AS DATE) <  r.valid_to;

SHOW TABLES IN SCHEMA LOGISTICS_DB.CORE;
