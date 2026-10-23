USE ROLE ROLE_ENGINEER;
USE WAREHOUSE WH_TRANSFORM;
USE SCHEMA LOGISTICS_DB.GOVERNANCE;

-- Test 1: As Engineer (should see full unmasked data)
SELECT 'ENGINEER_VIEW' AS test_mode, phone, email 
FROM LOGISTICS_DB.GOVERNANCE.pii_customer 
LIMIT 2;

-- Test 2: Verify Tag Assignment using Snowflake System Function
SELECT 
    SYSTEM$GET_TAG('LOGISTICS_DB.GOVERNANCE.pii_tag', 'LOGISTICS_DB.GOVERNANCE.pii_customer.phone', 'COLUMN') AS phone_tag,
    SYSTEM$GET_TAG('LOGISTICS_DB.GOVERNANCE.pii_tag', 'LOGISTICS_DB.GOVERNANCE.pii_customer.email', 'COLUMN') AS email_tag;

-- Test 3: Verify Masking Policies are attached to the table
SELECT 
    ref_column_name AS column_name, 
    policy_name, 
    policy_kind 
FROM TABLE(LOGISTICS_DB.INFORMATION_SCHEMA.POLICY_REFERENCES(
    REF_ENTITY_NAME => 'LOGISTICS_DB.GOVERNANCE.pii_customer',
    REF_ENTITY_DOMAIN => 'TABLE'
));
