
-- Sales by month and fiscal year
SELECT
    d.fiscal_year,
    d.calendar_year,
    d.calendar_month,
    d.month_name,
    ROUND(SUM(f.extended_price), 2) AS sales_amount,
    ROUND(SUM(f.tax_amount), 2) AS tax_amount
FROM olap.fact_sale f
JOIN olap.dim_date d ON d.date_key = f.date_key
GROUP BY d.fiscal_year, d.calendar_year,
         d.calendar_month, d.month_name
ORDER BY d.fiscal_year, d.calendar_year, d.calendar_month;

-- Top stock items by sales
SELECT
    s.stock_item_name,
    SUM(f.quantity) AS units_sold,
    ROUND(SUM(f.extended_price), 2) AS sales_amount,
    ROUND(SUM(f.line_profit), 2) AS line_profit
FROM olap.fact_sale f
JOIN olap.dim_stock_item s ON s.stock_item_key = f.stock_item_key
GROUP BY s.stock_item_name
ORDER BY sales_amount DESC
LIMIT 10;

-- Top customers by sales
SELECT
    c.customer_name,
    COUNT(DISTINCT f.invoice_id) AS invoice_count,
    SUM(f.quantity) AS units_sold,
    ROUND(SUM(f.extended_price), 2) AS sales_amount
FROM olap.fact_sale f
JOIN olap.dim_customer c ON c.customer_key = f.customer_key
GROUP BY c.source_customer_id, c.customer_name
ORDER BY sales_amount DESC
LIMIT 10;

-- Ordered versus invoiced quantities
SELECT
    o.order_id,
    SUM(o.ordered_quantity) AS ordered_quantity,
    COALESCE(s.invoiced_quantity, 0) AS invoiced_quantity,
    SUM(o.ordered_quantity) - COALESCE(s.invoiced_quantity, 0)
        AS quantity_difference
FROM olap.fact_order o
LEFT JOIN (
    SELECT order_id, SUM(quantity) AS invoiced_quantity
    FROM olap.fact_sale
    GROUP BY order_id
) s ON s.order_id = o.order_id
GROUP BY o.order_id, s.invoiced_quantity
ORDER BY ABS(
    SUM(o.ordered_quantity) - COALESCE(s.invoiced_quantity, 0)
) DESC
LIMIT 20;

-- Order lines with backorder references
SELECT
    COUNT(*) AS order_line_count,
    COUNT(*) FILTER (WHERE backorder_order_id IS NOT NULL)
        AS lines_with_backorder_reference
FROM olap.fact_order;

-- Time between orders and invoices
SELECT
    ROUND(AVG(i.invoice_date - o.order_date), 2) AS avg_days_to_invoice,
    MIN(i.invoice_date - o.order_date) AS min_days,
    MAX(i.invoice_date - o.order_date) AS max_days
FROM oltp.invoices i
JOIN oltp.orders o ON o.order_id = i.order_id;