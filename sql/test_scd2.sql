
BEGIN;

-- Pick one customer and preserve the original version.
CREATE TEMP TABLE scd2_test_customer AS
SELECT *
FROM olap.dim_customer
WHERE is_current = TRUE
ORDER BY source_customer_id
LIMIT 1;

-- Close the old version one day before the new version begins.
UPDATE olap.dim_customer d
SET valid_to = DATE '2026-01-01',
    is_current = FALSE
FROM scd2_test_customer t
WHERE d.customer_key = t.customer_key;

-- Insert a new version with a changed customer name.
INSERT INTO olap.dim_customer (
    source_customer_id, customer_name, customer_category_id,
    buying_group_id, delivery_city_id, credit_limit,
    discount_percentage, is_on_credit_hold, valid_from, valid_to, is_current
)
SELECT
    source_customer_id,
    customer_name || ' (SCD2 TEST)',
    customer_category_id,
    buying_group_id,
    delivery_city_id,
    credit_limit,
    discount_percentage,
    is_on_credit_hold,
    DATE '2026-01-02',
    NULL,
    TRUE
FROM scd2_test_customer;

-- Display the two versions.
SELECT source_customer_id, customer_name, valid_from, valid_to, is_current
FROM olap.dim_customer
WHERE source_customer_id = (
    SELECT source_customer_id FROM scd2_test_customer
)
ORDER BY valid_from;

-- Roll back the demonstration so production data remains unchanged.
ROLLBACK;