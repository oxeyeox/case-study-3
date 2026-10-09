
$ErrorActionPreference = "Stop"

Write-Host "`n=== Step 1: Start PostgreSQL ===" -ForegroundColor Cyan
docker compose -f .\compose.yaml up -d
if ($LASTEXITCODE -ne 0) { throw "Could not start PostgreSQL." }

Write-Host "`n=== Step 2: Load raw CSV files ===" -ForegroundColor Cyan
python .\load_raw_csv.py
if ($LASTEXITCODE -ne 0) { throw "Raw CSV loading failed." }

Write-Host "`n=== Step 3: Create OLTP schema ===" -ForegroundColor Cyan
Get-Content .\sql\oltp\01_create_oltp.sql -Raw |
    docker compose -f .\compose.yaml exec -T wwi-postgres psql -U wwi_user -d wwi_oltp -v ON_ERROR_STOP=1
if ($LASTEXITCODE -ne 0) { throw "OLTP schema creation failed." }

Write-Host "`n=== Step 4: Load typed OLTP tables ===" -ForegroundColor Cyan
python .\load_oltp.py
if ($LASTEXITCODE -ne 0) { throw "OLTP loading failed." }

Write-Host "`n=== Step 5: Create OLAP tables ===" -ForegroundColor Cyan
Get-Content .\sql\dimensions_facts.sql -Raw |
    docker compose -f .\compose.yaml exec -T wwi-postgres psql -U wwi_user -d wwi_oltp -v ON_ERROR_STOP=1
if ($LASTEXITCODE -ne 0) { throw "OLAP table creation failed." }

Write-Host "`n=== Step 6: Load dimensions ===" -ForegroundColor Cyan
Get-Content .\sql\load_dimensions.sql -Raw |
    docker compose -f .\compose.yaml exec -T wwi-postgres psql -U wwi_user -d wwi_oltp -v ON_ERROR_STOP=1
if ($LASTEXITCODE -ne 0) { throw "Dimension loading failed." }

Write-Host "`n=== Step 6b: Update customer history (SCD Type 2) ===" -ForegroundColor Cyan
Get-Content .\sql\load_customer_scd2.sql -Raw |
    docker compose -f .\compose.yaml exec -T wwi-postgres psql -U wwi_user -d wwi_oltp -v ON_ERROR_STOP=1
if ($LASTEXITCODE -ne 0) { throw "Customer SCD Type 2 loading failed." }

Write-Host "`n=== Step 7: Load facts ===" -ForegroundColor Cyan
Get-Content .\sql\load_facts.sql -Raw |
    docker compose -f .\compose.yaml exec -T wwi-postgres psql -U wwi_user -d wwi_oltp -v ON_ERROR_STOP=1
if ($LASTEXITCODE -ne 0) { throw "Fact loading failed." }

Write-Host "`n=== Step 8: Run business queries ===" -ForegroundColor Cyan
Get-Content .\sql\queries\business_queries.sql -Raw |
    docker compose -f .\compose.yaml exec -T wwi-postgres psql -U wwi_user -d wwi_oltp -v ON_ERROR_STOP=1 |
    Tee-Object -FilePath .\evidence\business_query_results.txt
if ($LASTEXITCODE -ne 0) { throw "Business queries failed." }

Write-Host "`nPipeline run completed." -ForegroundColor Green