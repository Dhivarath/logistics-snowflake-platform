USE ROLE ROLE_ENGINEER;
USE WAREHOUSE WH_INGEST;
USE SCHEMA LOGISTICS_DB.RAW;

CREATE OR REPLACE FILE FORMAT ff_csv
  TYPE = CSV SKIP_HEADER = 1 FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  NULL_IF = ('', 'NULL') EMPTY_FIELD_AS_NULL = TRUE TRIM_SPACE = TRUE;
CREATE OR REPLACE FILE FORMAT ff_json TYPE = JSON;

CREATE OR REPLACE STAGE stg_landing;

CREATE OR REPLACE TABLE hubs (
  hub_id STRING, hub_name STRING, city STRING, state STRING, region STRING, capacity_per_day STRING,
  _source_file STRING, _file_row_number NUMBER, _loaded_at TIMESTAMP_LTZ);
CREATE OR REPLACE TABLE riders (
  rider_id STRING, rider_name STRING, phone STRING, hub_id STRING, vehicle_type STRING,
  join_date STRING, status STRING,
  _source_file STRING, _file_row_number NUMBER, _loaded_at TIMESTAMP_LTZ);
CREATE OR REPLACE TABLE rider_changes (
  change_id STRING, rider_id STRING, old_hub_id STRING, new_hub_id STRING, effective_date STRING,
  _source_file STRING, _file_row_number NUMBER, _loaded_at TIMESTAMP_LTZ);
CREATE OR REPLACE TABLE customers (
  customer_id STRING, full_name STRING, phone STRING, email STRING, address_line STRING,
  city STRING, state STRING, pincode STRING, region STRING,
  _source_file STRING, _file_row_number NUMBER, _loaded_at TIMESTAMP_LTZ);
CREATE OR REPLACE TABLE shipments (
  shipment_id STRING, customer_id STRING, origin_hub_id STRING, dest_hub_id STRING,
  order_ts STRING, promised_ts STRING, weight_kg STRING, package_type STRING,
  service_level STRING, payment_mode STRING, cod_amount STRING,
  _source_file STRING, _file_row_number NUMBER, _loaded_at TIMESTAMP_LTZ);
CREATE OR REPLACE TABLE events (
  event_id STRING, shipment_id STRING, status STRING, event_ts STRING,
  hub_id STRING, rider_id STRING, ingested_ts STRING,
  _source_file STRING, _file_row_number NUMBER, _loaded_at TIMESTAMP_LTZ);
CREATE OR REPLACE TABLE complaints (
  payload VARIANT,
  _source_file STRING, _file_row_number NUMBER, _loaded_at TIMESTAMP_LTZ);

SHOW TABLES IN SCHEMA LOGISTICS_DB.RAW;
