
BEGIN;

CREATE TEMP TABLE customer_changes ON COMMIT DROP AS
SELECT
    c.customer_id AS source_customer_id,
    c.customer_name,
    c.customer_category_id,
    c.buying_group_id,
    c.delivery_city_id,
    c.credit_limit,
    c.standard_discount_percentage AS discount_percentage,
    c.is_on_credit_hold,
    d.customer_key,
    CASE
        WHEN CURRENT_DATE > d.valid_from THEN CURRENT_DATE
        ELSE d.valid_from + 1
    END AS change_date
FROM oltp.customers c
JOIN olap.dim_customer d
    ON d.source_customer_id = c.customer_id
   AND d.is_current = TRUE
WHERE
       d.customer_name IS DISTINCT FROM c.customer_name
    OR d.customer_category_id IS DISTINCT FROM c.customer_category_id
    OR d.buying_group_id IS DISTINCT FROM c.buying_group_id
    OR d.delivery_city_id IS DISTINCT FROM c.delivery_city_id
    OR d.credit_limit IS DISTINCT FROM c.credit_limit
    OR d.discount_percentage IS DISTINCT FROM c.standard_discount_percentage
    OR d.is_on_credit_hold IS DISTINCT FROM c.is_on_credit_hold;

UPDATE olap.dim_customer d
SET
    valid_to = ch.change_date - 1,
    is_current = FALSE
FROM customer_changes ch
WHERE d.customer_key = ch.customer_key;

INSERT INTO olap.dim_customer (
    source_customer_id,
    customer_name,
    customer_category_id,
    buying_group_id,
    delivery_city_id,
    credit_limit,
    discount_percentage,
    is_on_credit_hold,
    valid_from,
    valid_to,
    is_current
)
SELECT
    source_customer_id,
    customer_name,
    customer_category_id,
    buying_group_id,
    delivery_city_id,
    credit_limit,
    discount_percentage,
    is_on_credit_hold,
    change_date,
    NULL,
    TRUE
FROM customer_changes;

INSERT INTO olap.dim_customer (
    source_customer_id,
    customer_name,
    customer_category_id,
    buying_group_id,
    delivery_city_id,
    credit_limit,
    discount_percentage,
    is_on_credit_hold,
    valid_from,
    valid_to,
    is_current
)
SELECT
    c.customer_id,
    c.customer_name,
    c.customer_category_id,
    c.buying_group_id,
    c.delivery_city_id,
    c.credit_limit,
    c.standard_discount_percentage,
    c.is_on_credit_hold,
    COALESCE(c.account_opened_date, DATE '2013-01-01'),
    NULL,
    TRUE
FROM oltp.customers c
WHERE NOT EXISTS (
    SELECT 1
    FROM olap.dim_customer d
    WHERE d.source_customer_id = c.customer_id
      AND d.is_current = TRUE
);

COMMIT;