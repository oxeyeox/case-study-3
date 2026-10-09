import os
import csv
import re
from pathlib import Path
from datetime import datetime

import psycopg
from psycopg import sql

ROOT = Path(__file__).resolve().parent
RAW = ROOT / "data" / "raw"

env = {}
for line in (ROOT / ".env").read_text(encoding="utf-8").splitlines():
    line = line.strip()
    if line and not line.startswith("#") and "=" in line:
        k, v = line.split("=", 1)
        env[k.strip()] = v.strip().strip('"').strip("'")

conn = psycopg.connect(
    host="localhost", port=5433,
    dbname=env.get("POSTGRES_DB", "wwi_oltp"),
    user=env.get("POSTGRES_USER", "wwi_user"),
    password=env["POSTGRES_PASSWORD"],
)

def read_csv(prefix):
    matches = list(RAW.rglob(prefix + ".csv"))
    if not matches:
        raise FileNotFoundError(f"Missing CSV: {prefix}.csv")
    with matches[0].open(encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f, delimiter=";"))

def value(v):
    if v is None or v.strip() == "" or v.strip().upper() == "NULL":
        return None
    return v.strip()

def integer(v):
    v = value(v)
    return int(v) if v is not None else None

def decimal(v):
    v = value(v)
    if v is None:
        return None
    return v.replace(",", ".")

def boolean(v):
    v = value(v)
    if v is None:
        return None
    return v.lower() in ("1", "true", "t", "yes")

def date(v):
    v = value(v)
    if not v:
        return None

    # Handle ISO format, e.g. 2013-01-01
    try:
        return datetime.fromisoformat(v.replace("Z", "+00:00")).date()
    except ValueError:
        pass

    # Handle source format, e.g. 01/01/2013
    for fmt in ("%m/%d/%Y", "%d/%m/%Y"):
        try:
            return datetime.strptime(v, fmt).date()
        except ValueError:
            continue

    raise ValueError(f"Unrecognized date format: {v}")

def timestamp(v):
    v = value(v)
    if not v:
        return None
    return datetime.fromisoformat(v.replace("Z", "+00:00")).replace(tzinfo=None)

def load_table(table, columns, rows):
    with conn.cursor() as cur:
        cur.execute(sql.SQL("TRUNCATE TABLE oltp.{} CASCADE").format(
            sql.Identifier(table)
        ))
        stmt = sql.SQL("INSERT INTO oltp.{} ({}) VALUES ({})").format(
            sql.Identifier(table),
            sql.SQL(", ").join(map(sql.Identifier, columns)),
            sql.SQL(", ").join(sql.Placeholder() for _ in columns),
        )
        cur.executemany(stmt, rows)
    print(f"Loaded oltp.{table}: {len(rows):,} rows")

try:
    people = read_csv("Application.People")
    load_table("people",
        ["person_id", "full_name", "preferred_name", "is_employee", "is_salesperson"],
        [(integer(r["PersonID"]), value(r["FullName"]), value(r["PreferredName"]),
          boolean(r["IsEmployee"]), boolean(r["IsSalesperson"])) for r in people])

    countries = read_csv("Application.Countries")
    load_table("countries",
        ["country_id", "country_name", "continent", "region", "subregion"],
        [(integer(r["CountryID"]), value(r["CountryName"]), value(r["Continent"]),
          value(r["Region"]), value(r["Subregion"])) for r in countries])

    states = read_csv("Application.StateProvinces")
    load_table("state_provinces",
        ["state_province_id", "state_province_name", "country_id"],
        [(integer(r["StateProvinceID"]), value(r["StateProvinceName"]),
          integer(r["CountryID"])) for r in states])

    cities = read_csv("Application.Cities")
    load_table("cities",
        ["city_id", "city_name", "state_province_id", "latitude", "longitude",
         "latest_recorded_population"],
        [(integer(r["CityID"]), value(r["CityName"]), integer(r["StateProvinceID"]),
          decimal(r["Latitude"]), decimal(r["Longitude"]),
          integer(r["LatestRecordedPopulation"])) for r in cities])

    customers = read_csv("Sales.Customers")
    load_table("customers",
        ["customer_id", "customer_name", "bill_to_customer_id", "customer_category_id",
         "buying_group_id", "primary_contact_person_id", "alternate_contact_person_id",
         "delivery_method_id", "delivery_city_id", "credit_limit", "account_opened_date",
         "standard_discount_percentage", "is_statement_sent", "is_on_credit_hold",
         "payment_days", "phone_number", "website_url", "delivery_address_line",
         "delivery_location_lat", "delivery_location_long"],
        [(integer(r["CustomerID"]), value(r["CustomerName"]), integer(r["BillToCustomerID"]),
          integer(r["CustomerCategoryID"]), integer(r["BuyingGroupID"]),
          integer(r["PrimaryContactPersonID"]), integer(r["AlternateContactPersonID"]),
          integer(r["DeliveryMethodID"]), integer(r["DeliveryCityID"]), decimal(r["CreditLimit"]),
          date(r["AccountOpenedDate"]), decimal(r["StandardDiscountPercentage"]),
          boolean(r["IsStatementSent"]), boolean(r["IsOnCreditHold"]), integer(r["PaymentDays"]),
          value(r["PhoneNumber"]), value(r["WebsiteURL"]), value(r["DeliveryAddressLine"]),
          decimal(r["DeliveryLocationLat"]), decimal(r["DeliveryLocationLong"])) for r in customers])

    items = read_csv("Warehouse.StockItems")
    load_table("stock_items",
        ["stock_item_id", "stock_item_name", "supplier_id", "color_id", "unit_package_id",
         "outer_package_id", "brand", "size", "lead_time_days", "quantity_per_outer",
         "is_chiller_stock", "barcode", "tax_rate", "unit_price",
         "recommended_retail_price", "typical_weight_per_unit"],
        [(integer(r["StockItemID"]), value(r["StockItemName"]), integer(r["SupplierID"]),
          integer(r["ColorID"]), integer(r["UnitPackageID"]), integer(r["OuterPackageID"]),
          value(r["Brand"]), value(r["Size"]), integer(r["LeadTimeDays"]),
          integer(r["QuantityPerOuter"]), boolean(r["IsChillerStock"]), value(r["Barcode"]),
          decimal(r["TaxRate"]), decimal(r["UnitPrice"]), decimal(r["RecommendedRetailPrice"]),
          decimal(r["TypicalWeightPerUnit"])) for r in items])

    orders = read_csv("Sales.Orders")
    load_table("orders",
        ["order_id", "customer_id", "salesperson_person_id", "picked_by_person_id",
         "backorder_order_id", "order_date", "expected_delivery_date",
         "customer_purchase_order_number", "is_undersupply_backordered", "picking_completed_when"],
        [(integer(r["OrderID"]), integer(r["CustomerID"]), integer(r["SalespersonPersonID"]),
          integer(r["PickedByPersonID"]), integer(r["BackorderOrderID"]), date(r["OrderDate"]),
          date(r["ExpectedDeliveryDate"]), value(r["CustomerPurchaseOrderNumber"]),
          boolean(r["IsUndersupplyBackordered"]), timestamp(r["PickingCompletedWhen"]))
         for r in orders])

    order_lines = read_csv("Sales.OrderLines")
    load_table("order_lines",
        ["order_line_id", "order_id", "stock_item_id", "description", "package_type_id",
         "quantity", "unit_price", "tax_rate", "picked_quantity", "picking_completed_when"],
        [(integer(r["OrderLineID"]), integer(r["OrderID"]), integer(r["StockItemID"]),
          value(r["Description"]), integer(r["PackageTypeID"]), integer(r["Quantity"]),
          decimal(r["UnitPrice"]), decimal(r["TaxRate"]), integer(r["PickedQuantity"]),
          timestamp(r["PickingCompletedWhen"])) for r in order_lines])

    invoices = read_csv("Sales.Invoices")
    load_table("invoices",
        ["invoice_id", "customer_id", "bill_to_customer_id", "order_id", "delivery_method_id",
         "contact_person_id", "accounts_person_id", "salesperson_person_id", "packed_by_person_id",
         "invoice_date", "customer_purchase_order_number", "delivery_instructions",
         "total_dry_items", "total_chiller_items", "confirmed_delivery_time", "confirmed_received_by"],
        [(integer(r["InvoiceID"]), integer(r["CustomerID"]), integer(r["BillToCustomerID"]),
          integer(r["OrderID"]), integer(r["DeliveryMethodID"]), integer(r["ContactPersonID"]),
          integer(r["AccountsPersonID"]), integer(r["SalespersonPersonID"]),
          integer(r["PackedByPersonID"]), date(r["InvoiceDate"]),
          value(r["CustomerPurchaseOrderNumber"]), value(r["DeliveryInstructions"]),
          integer(r["TotalDryItems"]), integer(r["TotalChillerItems"]),
          timestamp(r["ConfirmedDeliveryTime"]), value(r["ConfirmedReceivedBy"]))
         for r in invoices])

    invoice_lines = read_csv("Sales.InvoiceLines")
    load_table("invoice_lines",
        ["invoice_line_id", "invoice_id", "stock_item_id", "description", "package_type_id",
         "quantity", "unit_price", "tax_rate", "tax_amount", "line_profit", "extended_price"],
        [(integer(r["InvoiceLineID"]), integer(r["InvoiceID"]), integer(r["StockItemID"]),
          value(r["Description"]), integer(r["PackageTypeID"]), integer(r["Quantity"]),
          decimal(r["UnitPrice"]), decimal(r["TaxRate"]), decimal(r["TaxAmount"]),
          decimal(r["LineProfit"]), decimal(r["ExtendedPrice"])) for r in invoice_lines])

    conn.commit()
    print("\nSUCCESS: core OLTP tables loaded.")
except Exception:
    conn.rollback()
    raise
finally:
    conn.close()