USE ROLE ROLE_ENGINEER;
USE WAREHOUSE WH_TRANSFORM;
USE SCHEMA LOGISTICS_DB.STAGING;

-- ---------- reference tables: typed ----------
CREATE OR REPLACE TABLE stg_hubs AS
SELECT hub_id, hub_name, city, state, region,
       TRY_TO_NUMBER(capacity_per_day) AS capacity_per_day
FROM LOGISTICS_DB.RAW.hubs;

CREATE OR REPLACE TABLE stg_riders AS
SELECT rider_id, rider_name, phone, hub_id, vehicle_type,
       TRY_TO_DATE(join_date) AS join_date, status
FROM LOGISTICS_DB.RAW.riders;

CREATE OR REPLACE TABLE stg_rider_changes AS
SELECT change_id, rider_id, old_hub_id, new_hub_id,
       TRY_TO_DATE(effective_date) AS effective_date
FROM LOGISTICS_DB.RAW.rider_changes;

CREATE OR REPLACE TABLE stg_customers AS
SELECT customer_id, full_name, phone, email, address_line, city, state, pincode, region
FROM LOGISTICS_DB.RAW.customers;

-- ---------- shipments: typed and deduplicated ----------
CREATE OR REPLACE TABLE stg_shipments AS
SELECT shipment_id, customer_id, origin_hub_id, dest_hub_id,
       TRY_TO_TIMESTAMP_NTZ(order_ts)    AS order_ts,
       TRY_TO_TIMESTAMP_NTZ(promised_ts) AS promised_ts,
       TRY_TO_NUMBER(weight_kg, 8, 2)    AS weight_kg,
       package_type, service_level, payment_mode,
       TRY_TO_NUMBER(cod_amount)         AS cod_amount
FROM LOGISTICS_DB.RAW.shipments
QUALIFY ROW_NUMBER() OVER (PARTITION BY shipment_id
                           ORDER BY _source_file, _file_row_number) = 1;

-- ---------- complaints: flatten the JSON ----------
CREATE OR REPLACE TABLE stg_complaints AS
SELECT payload:complaint_id::STRING AS complaint_id,
       payload:shipment_id::STRING  AS shipment_id,
       payload:customer_id::STRING  AS customer_id,
       payload:category::STRING     AS category,
       payload:message::STRING      AS message,
       TRY_TO_TIMESTAMP_NTZ(payload:created_ts::STRING) AS created_ts
FROM LOGISTICS_DB.RAW.complaints;

-- ---------- events: check every row, then split good from rejected ----------
CREATE OR REPLACE TRANSIENT TABLE stg_events_checked AS
WITH typed AS (
  SELECT event_id, shipment_id, status,
         TRY_TO_TIMESTAMP_NTZ(event_ts)    AS event_ts,
         hub_id, rider_id,
         TRY_TO_TIMESTAMP_NTZ(ingested_ts) AS ingested_ts,
         _source_file, _file_row_number
  FROM LOGISTICS_DB.RAW.events
),
ranked AS (
  SELECT t.*,
         s.shipment_id   AS matched_shipment,
         s.order_ts, s.origin_hub_id, s.dest_hub_id,
         ROW_NUMBER() OVER (PARTITION BY t.event_id
                            ORDER BY t.ingested_ts, t._source_file, t._file_row_number) AS rn
  FROM typed t
  LEFT JOIN stg_shipments s ON t.shipment_id = s.shipment_id
)
SELECT *,
  CASE
    WHEN rn > 1                                   THEN 'DUPLICATE_EVENT_ID'
    WHEN matched_shipment IS NULL                 THEN 'ORPHAN_SHIPMENT'
    WHEN event_ts IS NULL                         THEN 'MISSING_EVENT_TS'
    WHEN status <> 'ORDER_PLACED'
         AND event_ts < order_ts                  THEN 'EVENT_BEFORE_ORDER'
  END AS reject_reason
FROM ranked;

CREATE OR REPLACE TABLE stg_events AS
SELECT event_id, shipment_id, status, event_ts,
       COALESCE(hub_id,
         CASE WHEN status IN ('AT_DEST_HUB','OUT_FOR_DELIVERY','DELIVERED','FAILED_ATTEMPT')
              THEN dest_hub_id ELSE origin_hub_id END)  AS hub_id,
       (hub_id IS NULL)                                 AS hub_imputed,
       rider_id, ingested_ts,
       DATEDIFF('minute', event_ts, ingested_ts) / 60.0 AS ingest_lag_hours,
       (DATEDIFF('minute', event_ts, ingested_ts) > 1440) AS is_late_arriving,
       _source_file, _file_row_number
FROM stg_events_checked
WHERE reject_reason IS NULL;

CREATE OR REPLACE TABLE stg_event_rejects AS
SELECT event_id, shipment_id, status, event_ts, hub_id, rider_id, ingested_ts,
       reject_reason, _source_file, _file_row_number
FROM stg_events_checked
WHERE reject_reason IS NOT NULL;

SHOW TABLES IN SCHEMA LOGISTICS_DB.STAGING;
