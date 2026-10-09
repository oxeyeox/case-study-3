
# Data Engineering Pipeline Architecture

## Pipeline

```mermaid
flowchart LR
    A[WWI CSV Files] --> B[Python Raw Loader]
    B --> C[(PostgreSQL Raw Schema)]
    C --> D[OLTP Loader]
    D --> E[(PostgreSQL OLTP Schema)]
    E --> F[SQL Transformations]
    F --> G[(PostgreSQL OLAP Schema)]
    G --> H[Business Queries]
```

## OLTP Relationships

```mermaid
erDiagram
    CUSTOMERS ||--o{ ORDERS : places
    ORDERS ||--|{ ORDER_LINES : contains
    CUSTOMERS ||--o{ INVOICES : receives
    INVOICES ||--|{ INVOICE_LINES : contains
    STOCK_ITEMS ||--o{ ORDER_LINES : includes
    STOCK_ITEMS ||--o{ INVOICE_LINES : includes
    CITIES ||--o{ CUSTOMERS : serves
    STATE_PROVINCES ||--o{ CITIES : contains
```

## OLAP Schema

```mermaid
flowchart TB
    Date[dim_date] --> OrderFact[fact_order]
    Customer[dim_customer] --> OrderFact
    Employee[dim_employee] --> OrderFact
    Stock[dim_stock_item] --> OrderFact
    Date --> SaleFact[fact_sale]
    Customer --> SaleFact
    Employee --> SaleFact
    Stock --> SaleFact
    City[dim_city] -.-> Customer
```

## Fact Table Grain

- `fact_order`: one row per order line, identified by `order_line_id`.
- `fact_sale`: one row per invoice line, identified by `invoice_line_id`.

## Technology

- Database: PostgreSQL
- Ingestion: Python
- Transformations: SQL
- Orchestration: PowerShell
- Input format: semicolon-delimited CSV