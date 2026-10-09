
Wide World Importers Data Engineering Pipeline
==============================================

Project overview
----------------

This project uses the Wide World Importers dataset to build a data pipeline. CSV files are loaded into PostgreSQL, transformed into typed OLTP tables, and organized into OLAP dimensions and fact tables for analysis.

Pipeline
--------

CSV files -> raw schema -> OLTP schema -> OLAP schema -> business queries

Tools
-----

- Python
- PostgreSQL 16
- Docker
- SQL
- PowerShell

Data model
----------

The OLTP schema contains people, countries, state provinces, cities, customers, stock items, orders, order lines, invoices, and invoice lines.

The OLAP schema contains these dimensions:

- `dim_date` - calendar and fiscal dates; fiscal year starts November 1
- `dim_city` - geographic attributes
- `dim_customer` - customer attributes and version fields
- `dim_employee` - employee attributes
- `dim_stock_item` - stock item attributes

Fact tables:

- `fact_order` - one row per order line
- `fact_sale` - one row per invoice line

Validation
----------

Source CSV validation reported zero issues.

| Table | Rows |
|---|---:|
| Orders | 73,595 |
| Order lines | 231,412 |
| Invoices | 70,510 |
| Invoice lines | 228,265 |

The OLAP fact tables contain 231,412 order lines and 228,265 invoice lines. Initial checks found no missing customer, stock item, or date keys.

Evidence files are stored in the `evidence` directory.

Business queries
----------------

The SQL queries cover monthly and fiscal-year sales, stock item sales, customer sales, ordered versus invoiced quantities, backorder references, and the time between orders and invoices.

Some invoice timing results are negative or unusually long and need further investigation.

SCD Type 2
----------

The customer dimension contains version start and end dates and a current-version flag. A controlled SQL test demonstrated closing an existing version and inserting a new version. The test was rolled back, so the original data was preserved.

Automated change detection and transaction-date-based historical customer lookups have not been implemented. The current fact loading process does not provide full historical SCD Type 2 accuracy.

Running the pipeline
--------------------

Start PostgreSQL:

    docker compose -f compose.yaml up -d

Activate the Python virtual environment, then run the scripts in this order:

1. `load_raw_csv.py`
2. `sql/oltp/01_create_oltp.sql`
3. `load_oltp.py`
4. `sql/dimensions_facts.sql`
5. `sql/load_dimensions.sql`
6. `sql/load_facts.sql`
7. `sql/queries/business_queries.sql`

Run schema creation before loading data on a fresh database.

The PowerShell entry point is `run_pipeline.ps1`. The current loading scripts are not a complete incremental pipeline and may not refresh existing fact records when source data changes.

Data sources
------------

Microsoft Wide World Importers documentation:
https://learn.microsoft.com/en-us/sql/samples/wide-world-importers-what-is

Kaggle dataset:
https://www.kaggle.com/datasets/pauloviniciusornelas/wwimporters