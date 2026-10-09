import csv
from collections import Counter
from datetime import datetime
from decimal import Decimal, InvalidOperation
from pathlib import Path

ROOT = Path(__file__).resolve().parent
RAW = ROOT / "data" / "raw"
EVIDENCE = ROOT / "evidence"
EVIDENCE.mkdir(exist_ok=True)

# Source CSV basename: (primary key, required fields, field types)
RULES = {
    "Application.People": (
        "PersonID", ["PersonID", "FullName"],
        {"PersonID": "int", "IsEmployee": "bool", "IsSalesperson": "bool"}
    ),
    "Application.Countries": (
        "CountryID", ["CountryID", "CountryName"],
        {"CountryID": "int", "LatestRecordedPopulation": "int"}
    ),
    "Application.StateProvinces": (
        "StateProvinceID", ["StateProvinceID", "StateProvinceName", "CountryID"],
        {"StateProvinceID": "int", "CountryID": "int"}
    ),
    "Application.Cities": (
        "CityID", ["CityID", "CityName", "StateProvinceID"],
        {"CityID": "int", "StateProvinceID": "int",
         "Latitude": "decimal", "Longitude": "decimal",
         "LatestRecordedPopulation": "int"}
    ),
    "Sales.Customers": (
        "CustomerID", ["CustomerID", "CustomerName"],
        {"CustomerID": "int", "BillToCustomerID": "int",
         "CustomerCategoryID": "int", "BuyingGroupID": "int",
         "PrimaryContactPersonID": "int", "AlternateContactPersonID": "int",
         "DeliveryMethodID": "int", "DeliveryCityID": "int",
         "CreditLimit": "decimal", "AccountOpenedDate": "date",
         "StandardDiscountPercentage": "decimal", "IsStatementSent": "bool",
         "IsOnCreditHold": "bool", "PaymentDays": "int",
         "DeliveryLocationLat": "decimal", "DeliveryLocationLong": "decimal"}
    ),
    "Warehouse.StockItems": (
        "StockItemID", ["StockItemID", "StockItemName"],
        {"StockItemID": "int", "SupplierID": "int", "ColorID": "int",
         "UnitPackageID": "int", "OuterPackageID": "int",
         "LeadTimeDays": "int", "QuantityPerOuter": "int",
         "IsChillerStock": "bool", "TaxRate": "decimal",
         "UnitPrice": "decimal", "RecommendedRetailPrice": "decimal",
         "TypicalWeightPerUnit": "decimal"}
    ),
    "Sales.Orders": (
        "OrderID", ["OrderID", "CustomerID"],
        {"OrderID": "int", "CustomerID": "int",
         "SalespersonPersonID": "int", "PickedByPersonID": "int",
         "BackorderOrderID": "int", "OrderDate": "date",
         "ExpectedDeliveryDate": "date", "IsUndersupplyBackordered": "bool",
         "PickingCompletedWhen": "timestamp"}
    ),
    "Sales.OrderLines": (
        "OrderLineID", ["OrderLineID", "OrderID", "StockItemID", "Quantity"],
        {"OrderLineID": "int", "OrderID": "int", "StockItemID": "int",
         "PackageTypeID": "int", "Quantity": "int", "UnitPrice": "decimal",
         "TaxRate": "decimal", "PickedQuantity": "int",
         "PickingCompletedWhen": "timestamp"}
    ),
    "Sales.Invoices": (
        "InvoiceID", ["InvoiceID", "CustomerID"],
        {"InvoiceID": "int", "CustomerID": "int", "BillToCustomerID": "int",
         "OrderID": "int", "DeliveryMethodID": "int", "ContactPersonID": "int",
         "AccountsPersonID": "int", "SalespersonPersonID": "int",
         "PackedByPersonID": "int", "InvoiceDate": "date",
         "TotalDryItems": "int", "TotalChillerItems": "int",
         "ConfirmedDeliveryTime": "timestamp"}
    ),
    "Sales.InvoiceLines": (
        "InvoiceLineID", ["InvoiceLineID", "InvoiceID", "StockItemID", "Quantity"],
        {"InvoiceLineID": "int", "InvoiceID": "int", "StockItemID": "int",
         "PackageTypeID": "int", "Quantity": "int", "UnitPrice": "decimal",
         "TaxRate": "decimal", "TaxAmount": "decimal",
         "LineProfit": "decimal", "ExtendedPrice": "decimal"}
    ),
}

def clean(v):
    if v is None or not v.strip() or v.strip().upper() == "NULL":
        return None
    return v.strip()

def valid(value, kind):
    if value is None:
        return True
    try:
        if kind == "int":
            int(value)
        elif kind == "decimal":
            Decimal(value.replace(",", "."))
        elif kind == "bool":
            if value.lower() not in ("1", "0", "true", "false", "t", "f", "yes", "no"):
                return False
        elif kind == "date":
            parsed = False
            for fmt in ("%Y-%m-%d", "%m/%d/%Y", "%d/%m/%Y"):
                try:
                    datetime.strptime(value, fmt)
                    parsed = True
                    break
                except ValueError:
                    pass
            if not parsed:
                try:
                    datetime.fromisoformat(value.replace("Z", "+00:00"))
                    parsed = True
                except ValueError:
                    pass
            return parsed
        elif kind == "timestamp":
            try:
                datetime.fromisoformat(value.replace("Z", "+00:00"))
            except ValueError:
                for fmt in ("%m/%d/%Y %H:%M:%S", "%d/%m/%Y %H:%M:%S"):
                    try:
                        datetime.strptime(value, fmt)
                        break
                    except ValueError:
                        continue
                else:
                    return False
    except (ValueError, InvalidOperation):
        return False
    return True

issues = []
summary = []
files = sorted(RAW.rglob("*.csv"))

if not files:
    raise FileNotFoundError(f"No CSV files found in {RAW}")

for path in files:
    name = path.stem
    count = 0
    malformed = 0
    file_issues = 0

    key, required, types = RULES.get(name, (None, [], {}))
    seen_keys = set()
    duplicate_keys = 0

    with path.open("r", encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f, delimiter=";")
        if not reader.fieldnames:
            issues.append(f"{path.name}: missing header")
            continue

        headers = set(reader.fieldnames)

        for col in [key] + required if key else required:
            if col not in headers:
                issues.append(f"{path.name}: expected column missing: {col}")
                file_issues += 1

        for row_num, row in enumerate(reader, start=2):
            count += 1

            if None in row:
                malformed += 1
                if malformed <= 5:
                    issues.append(
                        f"{path.name}, row {row_num}: too many fields in CSV row"
                    )
                continue

            for col in required:
                if col in row and clean(row[col]) is None:
                    file_issues += 1
                    if file_issues <= 10:
                        issues.append(
                            f"{path.name}, row {row_num}: required value missing: {col}"
                        )

            if key and key in row:
                key_value = clean(row[key])
                if key_value is not None:
                    if key_value in seen_keys:
                        duplicate_keys += 1
                        if duplicate_keys <= 5:
                            issues.append(
                                f"{path.name}, row {row_num}: duplicate {key}={key_value}"
                            )
                    seen_keys.add(key_value)

            for col, kind in types.items():
                if col not in row:
                    continue
                val = clean(row[col])
                if not valid(val, kind):
                    file_issues += 1
                    if file_issues <= 10:
                        issues.append(
                            f"{path.name}, row {row_num}: invalid {kind} "
                            f"for {col}: {val!r}"
                        )

    summary.append(
        f"{path.relative_to(RAW)}: {count:,} rows; "
        f"{duplicate_keys} duplicate keys; {malformed} malformed rows"
    )

report = [
    "WIDE WORLD IMPORTERS - SOURCE DATA VALIDATION",
    f"CSV files scanned: {len(files)}",
    "",
    "ROW COUNTS:",
    *summary,
    "",
    f"ISSUES REPORTED: {len(issues)}",
    *issues,
    "",
    "Note: date validation accepts both month/day/year and day/month/year. "
    "Ambiguous dates need source-format confirmation.",
]

out = EVIDENCE / "data_validation.txt"
out.write_text("\n".join(report), encoding="utf-8")

print(f"Scanned {len(files)} CSV files.")
print(f"Issues reported: {len(issues)}")
print(f"Full report saved to: {out}")
print("\nFirst 30 issues:")
for issue in issues[:30]:
    print("-", issue)

if not issues:
    print("\nPASS: no issues found by these checks.")
else:
    print("\nReview the report before loading.")
