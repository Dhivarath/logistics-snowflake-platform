USE ROLE ROLE_ENGINEER;
USE WAREHOUSE WH_TRANSFORM;
USE SCHEMA LOGISTICS_DB.GOVERNANCE;

-- 1. Create a tag for PII classification
CREATE OR REPLACE TAG pii_tag;

-- Apply tag to PII columns
ALTER TABLE LOGISTICS_DB.GOVERNANCE.pii_customer MODIFY COLUMN full_name SET TAG pii_tag = 'PII_NAME';
ALTER TABLE LOGISTICS_DB.GOVERNANCE.pii_customer MODIFY COLUMN phone SET TAG pii_tag = 'PII_PHONE';
ALTER TABLE LOGISTICS_DB.GOVERNANCE.pii_customer MODIFY COLUMN email SET TAG pii_tag = 'PII_EMAIL';

ALTER TABLE LOGISTICS_DB.GOVERNANCE.pii_rider MODIFY COLUMN rider_name SET TAG pii_tag = 'PII_NAME';
ALTER TABLE LOGISTICS_DB.GOVERNANCE.pii_rider MODIFY COLUMN phone SET TAG pii_tag = 'PII_PHONE';

-- 2. Create Dynamic Data Masking Policy for Phone and Email
CREATE OR REPLACE MASKING POLICY mask_phone AS (val STRING) RETURNS STRING ->
  CASE
    WHEN CURRENT_ROLE() IN ('ROLE_ENGINEER', 'ACCOUNTADMIN') THEN val
    ELSE '***-***-' || RIGHT(val, 4)
  END;

CREATE OR REPLACE MASKING POLICY mask_email AS (val STRING) RETURNS STRING ->
  CASE
    WHEN CURRENT_ROLE() IN ('ROLE_ENGINEER', 'ACCOUNTADMIN') THEN val
    ELSE REGEXP_REPLACE(val, '(^.).*(@.*)', '\\1***\\2')
  END;

-- Apply masking policies to PII tables
ALTER TABLE LOGISTICS_DB.GOVERNANCE.pii_customer MODIFY COLUMN phone SET MASKING POLICY mask_phone;
ALTER TABLE LOGISTICS_DB.GOVERNANCE.pii_customer MODIFY COLUMN email SET MASKING POLICY mask_email;
ALTER TABLE LOGISTICS_DB.GOVERNANCE.pii_rider MODIFY COLUMN phone SET MASKING POLICY mask_phone;

-- 3. Row Access Policy for Regional Hub Access
-- Maps regional analysts to their respective regions
CREATE OR REPLACE ROW ACCESS POLICY regional_access AS (region STRING) RETURNS BOOLEAN ->
  CURRENT_ROLE() IN ('ROLE_ENGINEER', 'ACCOUNTADMIN')
  OR (
    CURRENT_ROLE() = 'ROLE_ANALYST_SOUTH' AND region = 'South'
  )
  OR (
    CURRENT_ROLE() = 'ROLE_ANALYST_NORTH' AND region = 'North'
  );

-- Apply row access policy to dim_hub or fact tables if region is available
-- (For demonstration, we apply it to dim_hub)
ALTER TABLE LOGISTICS_DB.CORE.dim_hub ADD ROW ACCESS POLICY regional_access ON (region);

SHOW MASKING POLICIES;
SHOW ROW ACCESS POLICIES;
