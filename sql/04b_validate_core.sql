USE ROLE ROLE_ENGINEER;
USE WAREHOUSE WH_TRANSFORM;
USE SCHEMA LOGISTICS_DB.CORE;

-- 1. Row counts
SELECT (SELECT COUNT(*) FROM fact_shipment)        AS fact_shipments,
       (SELECT COUNT(*) FROM dim_rider)            AS dim_rider_rows,
       (SELECT COUNT(*) FROM dim_rider WHERE is_current) AS current_riders,
       (SELECT COUNT_IF(is_delivered) FROM fact_shipment) AS delivered;

-- 2. SCD2 integrity: no rider may have overlapping periods (must be 0)
SELECT COUNT(*) AS overlapping_periods
FROM dim_rider a JOIN dim_rider b
  ON a.rider_id = b.rider_id AND a.rider_key < b.rider_key
 AND a.valid_from < b.valid_to AND b.valid_from < a.valid_to;

-- 3. Every delivered shipment found its rider version (must be 0)
SELECT COUNT_IF(is_delivered AND delivery_rider_key IS NULL) AS delivered_without_rider
FROM fact_shipment;

-- 4. Why SCD2 matters: was the delivering rider in the destination hub at the time?
SELECT ROUND(COUNT_IF(h.hub_id = f.dest_hub_id) / COUNT(*), 4) AS match_using_history,
       ROUND(COUNT_IF(c.hub_id = f.dest_hub_id) / COUNT(*), 4) AS match_using_current_hub_only
FROM fact_shipment f
JOIN dim_rider h ON h.rider_key = f.delivery_rider_key
JOIN dim_rider c ON c.rider_id = h.rider_id AND c.is_current;

-- 5. The payoff: which hubs deliver late? (your planted problem hubs)
SELECT f.dest_hub_id, d.hub_name,
       COUNT(*) AS delivered, ROUND(AVG(IFF(f.is_late, 1, 0)), 3) AS late_rate
FROM fact_shipment f JOIN dim_hub d ON d.hub_id = f.dest_hub_id
WHERE f.is_delivered
GROUP BY f.dest_hub_id, d.hub_name
ORDER BY late_rate DESC
LIMIT 5;
