-- Load date dimension
-- Fiscal year starts on November 1.
INSERT INTO olap.dim_date (
    date_key, full_date, calendar_year, calendar_month,
    month_name, fiscal_year, fiscal_month
)
SELECT
    TO_CHAR(d, 'YYYYMMDD')::INTEGER,
    d::DATE,
    EXTRACT(YEAR FROM d)::INTEGER,
    EXTRACT(MONTH FROM d)::INTEGER,
    TO_CHAR(d, 'FMMonth'),
    CASE WHEN EXTRACT(MONTH FROM d) >= 11
         THEN EXTRACT(YEAR FROM d)::INTEGER + 1
         ELSE EXTRACT(YEAR FROM d)::INTEGER
    END,
    ((EXTRACT(MONTH FROM d)::INTEGER + 1) % 12) + 1
FROM generate_series(
    (SELECT LEAST(MIN(order_date), MIN(invoice_date))
     FROM (SELECT order_date, NULL::DATE AS invoice_date
           FROM oltp.orders
           UNION ALL
           SELECT NULL::DATE, invoice_date FROM oltp.invoices) dates),
    (SELECT GREATEST(MAX(order_date), MAX(invoice_date))
     FROM (SELECT order_date, NULL::DATE AS invoice_date
           FROM oltp.orders
           UNION ALL
           SELECT NULL::DATE, invoice_date FROM oltp.invoices) dates),
    INTERVAL '1 day'
) AS series(d)
ON CONFLICT (date_key) DO NOTHING;

-- Load city dimension
INSERT INTO olap.dim_city (
    source_city_id, city_name, state_province_id,
    state_province_name, country_id, country_name
)
SELECT c.city_id, c.city_name, c.state_province_id,
       sp.state_province_name, sp.country_id, co.country_name
FROM oltp.cities c
LEFT JOIN oltp.state_provinces sp
    ON sp.state_province_id = c.state_province_id
LEFT JOIN oltp.countries co
    ON co.country_id = sp.country_id
ON CONFLICT (source_city_id) DO NOTHING;

-- Load customer dimension: initial SCD Type 2 versions
INSERT INTO olap.dim_customer (
    source_customer_id, customer_name, customer_category_id,
    buying_group_id, delivery_city_id, credit_limit,
    discount_percentage, is_on_credit_hold, valid_from, valid_to, is_current
)
SELECT customer_id, customer_name, customer_category_id,
       buying_group_id, delivery_city_id, credit_limit,
       standard_discount_percentage, is_on_credit_hold,
       COALESCE(account_opened_date, DATE '2013-01-01'),
       NULL, TRUE
FROM oltp.customers
ON CONFLICT DO NOTHING;

-- Load employee dimension
INSERT INTO olap.dim_employee (
    source_employee_id, employee_name, is_salesperson
)
SELECT person_id, full_name, is_salesperson
FROM oltp.people
WHERE is_employee = TRUE
ON CONFLICT (source_employee_id) DO NOTHING;

-- Load stock item dimension
INSERT INTO olap.dim_stock_item (
    source_stock_item_id, stock_item_name, brand,
    color_id, size, supplier_id, is_chiller_stock, tax_rate, unit_price
)
SELECT stock_item_id, stock_item_name, brand,
       color_id, size, supplier_id, is_chiller_stock, tax_rate, unit_price
FROM oltp.stock_items
ON CONFLICT (source_stock_item_id) DO NOTHING;