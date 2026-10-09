CREATE SCHEMA IF NOT EXISTS oltp;

CREATE TABLE IF NOT EXISTS oltp.people (
    person_id INTEGER PRIMARY KEY,
    full_name TEXT NOT NULL,
    preferred_name TEXT,
    is_employee BOOLEAN,
    is_salesperson BOOLEAN
);

CREATE TABLE IF NOT EXISTS oltp.countries (
    country_id INTEGER PRIMARY KEY,
    country_name TEXT NOT NULL,
    continent TEXT,
    region TEXT,
    subregion TEXT
);

CREATE TABLE IF NOT EXISTS oltp.state_provinces (
    state_province_id INTEGER PRIMARY KEY,
    state_province_name TEXT NOT NULL,
    country_id INTEGER REFERENCES oltp.countries(country_id)
);

CREATE TABLE IF NOT EXISTS oltp.cities (
    city_id INTEGER PRIMARY KEY,
    city_name TEXT NOT NULL,
    state_province_id INTEGER REFERENCES oltp.state_provinces(state_province_id),
    latitude NUMERIC,
    longitude NUMERIC,
    latest_recorded_population BIGINT
);

CREATE TABLE IF NOT EXISTS oltp.customers (
    customer_id INTEGER PRIMARY KEY,
    customer_name TEXT NOT NULL,
    bill_to_customer_id INTEGER,
    customer_category_id INTEGER,
    buying_group_id INTEGER,
    primary_contact_person_id INTEGER REFERENCES oltp.people(person_id),
    alternate_contact_person_id INTEGER REFERENCES oltp.people(person_id),
    delivery_method_id INTEGER,
    delivery_city_id INTEGER REFERENCES oltp.cities(city_id),
    credit_limit NUMERIC(12,2),
    account_opened_date DATE,
    standard_discount_percentage NUMERIC(7,4),
    is_statement_sent BOOLEAN,
    is_on_credit_hold BOOLEAN,
    payment_days INTEGER,
    phone_number TEXT,
    website_url TEXT,
    delivery_address_line TEXT,
    delivery_location_lat NUMERIC,
    delivery_location_long NUMERIC
);

CREATE TABLE IF NOT EXISTS oltp.stock_items (
    stock_item_id INTEGER PRIMARY KEY,
    stock_item_name TEXT NOT NULL,
    supplier_id INTEGER,
    color_id INTEGER,
    unit_package_id INTEGER,
    outer_package_id INTEGER,
    brand TEXT,
    size TEXT,
    lead_time_days INTEGER,
    quantity_per_outer INTEGER,
    is_chiller_stock BOOLEAN,
    barcode TEXT,
    tax_rate NUMERIC(7,4),
    unit_price NUMERIC(12,2),
    recommended_retail_price NUMERIC(12,2),
    typical_weight_per_unit NUMERIC(12,3)
);

CREATE TABLE IF NOT EXISTS oltp.orders (
    order_id INTEGER PRIMARY KEY,
    customer_id INTEGER NOT NULL REFERENCES oltp.customers(customer_id),
    salesperson_person_id INTEGER REFERENCES oltp.people(person_id),
    picked_by_person_id INTEGER REFERENCES oltp.people(person_id),
    backorder_order_id INTEGER,
    order_date DATE,
    expected_delivery_date DATE,
    customer_purchase_order_number TEXT,
    is_undersupply_backordered BOOLEAN,
    picking_completed_when TIMESTAMP
);

CREATE TABLE IF NOT EXISTS oltp.order_lines (
    order_line_id INTEGER PRIMARY KEY,
    order_id INTEGER NOT NULL REFERENCES oltp.orders(order_id),
    stock_item_id INTEGER NOT NULL REFERENCES oltp.stock_items(stock_item_id),
    description TEXT,
    package_type_id INTEGER,
    quantity INTEGER NOT NULL,
    unit_price NUMERIC(12,2),
    tax_rate NUMERIC(7,4),
    picked_quantity INTEGER,
    picking_completed_when TIMESTAMP
);

CREATE TABLE IF NOT EXISTS oltp.invoices (
    invoice_id INTEGER PRIMARY KEY,
    customer_id INTEGER NOT NULL REFERENCES oltp.customers(customer_id),
    bill_to_customer_id INTEGER,
    order_id INTEGER REFERENCES oltp.orders(order_id),
    delivery_method_id INTEGER,
    contact_person_id INTEGER REFERENCES oltp.people(person_id),
    accounts_person_id INTEGER REFERENCES oltp.people(person_id),
    salesperson_person_id INTEGER REFERENCES oltp.people(person_id),
    packed_by_person_id INTEGER REFERENCES oltp.people(person_id),
    invoice_date DATE,
    customer_purchase_order_number TEXT,
    delivery_instructions TEXT,
    total_dry_items INTEGER,
    total_chiller_items INTEGER,
    confirmed_delivery_time TIMESTAMP,
    confirmed_received_by TEXT
);

CREATE TABLE IF NOT EXISTS oltp.invoice_lines (
    invoice_line_id INTEGER PRIMARY KEY,
    invoice_id INTEGER NOT NULL REFERENCES oltp.invoices(invoice_id),
    stock_item_id INTEGER NOT NULL REFERENCES oltp.stock_items(stock_item_id),
    description TEXT,
    package_type_id INTEGER,
    quantity INTEGER NOT NULL,
    unit_price NUMERIC(12,2),
    tax_rate NUMERIC(7,4),
    tax_amount NUMERIC(12,2),
    line_profit NUMERIC(12,2),
    extended_price NUMERIC(12,2)
);
