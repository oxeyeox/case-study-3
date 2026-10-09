BEGIN;

TRUNCATE TABLE olap.fact_order, olap.fact_sale;

-- Fact order: one row per customer order line
INSERT INTO olap.fact_order (
    order_line_id, order_id, date_key, customer_key,
    employee_key, stock_item_key, ordered_quantity,
    picked_quantity, unit_price, tax_rate, backorder_order_id
)
SELECT
    ol.order_line_id,
    o.order_id,
    TO_CHAR(o.order_date, 'YYYYMMDD')::INTEGER,
    dc.customer_key,
    de.employee_key,
    ds.stock_item_key,
    ol.quantity,
    ol.picked_quantity,
    ol.unit_price,
    ol.tax_rate,
    o.backorder_order_id
FROM oltp.order_lines ol
JOIN oltp.orders o ON o.order_id = ol.order_id
LEFT JOIN olap.dim_customer dc
    ON dc.source_customer_id = o.customer_id
   AND dc.valid_from <= o.order_date
   AND (dc.valid_to IS NULL OR dc.valid_to >= o.order_date)
LEFT JOIN olap.dim_employee de
    ON de.source_employee_id = o.salesperson_person_id
LEFT JOIN olap.dim_stock_item ds
    ON ds.source_stock_item_id = ol.stock_item_id;

-- Fact sale: one row per customer invoice line
INSERT INTO olap.fact_sale (
    invoice_line_id, invoice_id, order_id, date_key, customer_key,
    employee_key, stock_item_key, quantity, unit_price,
    tax_rate, tax_amount, line_profit, extended_price
)
SELECT
    il.invoice_line_id,
    i.invoice_id,
    i.order_id,
    TO_CHAR(i.invoice_date, 'YYYYMMDD')::INTEGER,
    dc.customer_key,
    de.employee_key,
    ds.stock_item_key,
    il.quantity,
    il.unit_price,
    il.tax_rate,
    il.tax_amount,
    il.line_profit,
    il.extended_price
FROM oltp.invoice_lines il
JOIN oltp.invoices i ON i.invoice_id = il.invoice_id
LEFT JOIN olap.dim_customer dc
    ON dc.source_customer_id = i.customer_id
   AND dc.valid_from <= i.invoice_date
   AND (dc.valid_to IS NULL OR dc.valid_to >= i.invoice_date)
LEFT JOIN olap.dim_employee de
    ON de.source_employee_id = i.salesperson_person_id
LEFT JOIN olap.dim_stock_item ds
    ON ds.source_stock_item_id = il.stock_item_id;

COMMIT;