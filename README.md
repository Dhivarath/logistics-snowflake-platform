# Secure Enterprise Logistics Data Platform (Snowflake)

An enterprise-grade, end-to-end data engineering platform built on Snowflake, featuring Medallion architecture, SCD Type 2 historical tracking, Change Data Capture (CDC), and robust data governance.

## 🏗️ Architecture & Data Flow
* **Ingestion & Staging:** Simulated streaming event logs validated and loaded into staging tables within Snowflake.
* **Core Star Schema:** Modeled dimensions (`dim_hub`, `dim_customer`, `dim_date`, `dim_rider`) and fact tables (`fact_shipment`, `fact_event`).
* **SCD Type 2 Implementation:** Maintained historical accuracy for delivery personnel shifts and hub reassignments using valid-from/valid-to date ranges (`valid_from`, `valid_to`, `is_current`).
* **Change Data Capture (CDC):** Utilized Snowflake Streams, Tasks, and Dynamic Tables to handle incremental updates and deletes without expensive full reloads.
* **Governance & Security Vault:** Isolated Personally Identifiable Information (PII) into restricted schemas protected by dynamic data masking policies, column-level security tags, and Row Access Policies (RAP).

## 🚀 Tech Stack
* **Data Warehouse & Orchestration:** Snowflake (Virtual Warehouses, Streams, Tasks, Dynamic Tables)
* **Processing & Scripting:** Python, SQL
* **Security & Governance:** Dynamic Data Masking, Column-Level Tags (`SYSTEM$GET_TAG`), RBAC
* **Analytics & BI:** Power BI

## 📊 Key Highlights & Results
* **100,000+ Records Processed:** Validated through automated test suites with zero unaccounted event drops.
* **Historical Accuracy Boost:** Improved delivery-to-rider hub assignment matching from ~95% (using static current-hub models) to **99%+** using SCD Type 2 history.
* **Automated Security Validation:** Tested dynamic masking and tag assignments programmatically via Snowflake system functions.
