# Secure Cloud Logistics Data Platform (Azure & Snowflake)

An enterprise-grade, end-to-end data engineering pipeline built to handle large-scale logistics data, featuring Medallion architecture, SCD Type 2 tracking, Change Data Capture (CDC), and robust data governance.

## 🏗️ Architecture
* **Ingestion & Staging:** Simulated streaming event logs validated and loaded into staging tables.
* **Core Star Schema:** Modeled dimensions (`dim_hub`, `dim_customer`, `dim_date`, `dim_rider`) and fact tables (`fact_shipment`, `fact_event`).
* **SCD Type 2 Implementation:** Maintained historical accuracy for delivery personnel shifts and hub reassignments using valid-from/valid-to date ranges.
* **Governance & Security Vault:** Isolated Personally Identifiable Information (PII) into restricted schemas protected by dynamic data masking policies and column-level tags.

## 🚀 Tech Stack
* **Cloud & Orchestration:** Azure, Azure DevOps
* **Processing:** PySpark, Python
* **Data Warehouse:** Snowflake (Streams, Tasks, Dynamic Tables, RBAC)
* **Visualization & Analytics:** Power BI

## 📊 Key Highlights & Results
* **100,000+ Records Processed:** Validated through automated test suites with zero unaccounted event drops.
* **Historical Accuracy Boost:** Improved delivery-to-rider hub assignment matching from ~95% (using static current-hub models) to **99%+** using SCD Type 2 history.
* **Automated Security Validation:** Tested dynamic masking and tag assignments programmatically via Snowflake system functions.
