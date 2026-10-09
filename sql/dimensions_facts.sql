-- OLAP schema
CREATE SCHEMA IF NOT EXISTS olap;

-- Date dimension: fiscal year starts November 1
CREATE TABLE IF NOT EXISTS olap.dim_date (
    date_key        INTEGER PRIMARY KEY,
    full_date       DATE UNIQUE NOT NULL,
    calendar_year   INTEGER NOT NULL,
    calendar_month  INTEGER NOT NULL,
    month_name      TEXT NOT NULL,
    fiscal_year     INTEGER NOT NULL,
    fiscal_month    INTEGER NOT NULL
);

-- City dimension
CREATE TABLE IF NOT EXISTS olap.dim_city (
    city_key          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source_city_id    INTEGER UNIQUE NOT NULL,
    city_name         TEXT,
    state_province_id INTEGER,
    state_province_name TEXT,
    country_id        INTEGER,
    country_name      TEXT
);

-- Customer dimension, with SCD Type 2 history
CREATE TABLE IF NOT EXISTS olap.dim_customer (
    customer_key       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source_customer_id INTEGER NOT NULL,
    customer_name      TEXT,
    customer_category_id INTEGER,
    buying_group_id    INTEGER,
    delivery_city_id   INTEGER,
    credit_limit       NUMERIC(18,2),
    discount_percentage NUMERIC(9,4),
    is_on_credit_hold  BOOLEAN,
    valid_from         DATE NOT NULL,
    valid_to           DATE,
    is_current         BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_dim_customer_current
ON olap.dim_customer(source_customer_id)
WHERE is_current = TRUE;

-- Employee dimension
CREATE TABLE IF NOT EXISTS olap.dim_employee (
    employee_key      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source_employee_id INTEGER UNIQUE NOT NULL,
    employee_name     TEXT,
    is_salesperson     BOOLEAN
);

-- Stock item dimension
CREATE TABLE IF NOT EXISTS olap.dim_stock_item (
    stock_item_key     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source_stock_item_id INTEGER UNIQUE NOT NULL,
    stock_item_name    TEXT,
    brand              TEXT,
    color_id           INTEGER,
    size               TEXT,
    supplier_id        INTEGER,
    is_chiller_stock   BOOLEAN,
    tax_rate           NUMERIC(9,4),
    unit_price         NUMERIC(18,2)
);

-- Order fact table: One row per customer order line
CREATE TABLE IF NOT EXISTS olap.fact_order (
    order_line_id     INTEGER PRIMARY KEY,
    order_id          INTEGER NOT NULL,
    date_key          INTEGER,
    customer_key      BIGINT,
    employee_key      BIGINT,
    stock_item_key    BIGINT,
    ordered_quantity  INTEGER,
    picked_quantity   INTEGER,
    unit_price        NUMERIC(18,2),
    tax_rate          NUMERIC(9,4),
    backorder_order_id INTEGER
);

-- Sales fact table: One row per customer invoice line
CREATE TABLE IF NOT EXISTS olap.fact_sale (
    invoice_line_id   INTEGER PRIMARY KEY,
    invoice_id        INTEGER NOT NULL,
    order_id          INTEGER,
    date_key          INTEGER,
    customer_key      BIGINT,
    employee_key      BIGINT,
    stock_item_key    BIGINT,
    quantity          INTEGER,
    unit_price        NUMERIC(18,2),
    tax_rate          NUMERIC(9,4),
    tax_amount        NUMERIC(18,2),
    line_profit       NUMERIC(18,2),
    extended_price    NUMERIC(18,2)
);