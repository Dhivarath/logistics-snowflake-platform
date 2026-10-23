USE ROLE ROLE_ENGINEER;
USE WAREHOUSE WH_INGEST;
USE SCHEMA LOGISTICS_DB.RAW;

SELECT 'hubs' AS tbl, COUNT(*) AS n FROM hubs
UNION ALL SELECT 'riders', COUNT(*) FROM riders
UNION ALL SELECT 'rider_changes', COUNT(*) FROM rider_changes
UNION ALL SELECT 'customers', COUNT(*) FROM customers
UNION ALL SELECT 'shipments', COUNT(*) FROM shipments
UNION ALL SELECT 'events', COUNT(*) FROM events
UNION ALL SELECT 'complaints', COUNT(*) FROM complaints;

SELECT COUNT(*) AS duplicate_event_ids
FROM (SELECT event_id FROM events GROUP BY event_id HAVING COUNT(*) > 1);

SELECT COUNT(*) AS events_missing_timestamp FROM events WHERE event_ts IS NULL;

SELECT COUNT(*) AS orphan_events
FROM events e LEFT JOIN shipments s ON e.shipment_id = s.shipment_id
WHERE s.shipment_id IS NULL;
