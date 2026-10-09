import csv
import os
import re
from pathlib import Path

import psycopg
from psycopg import sql

ROOT = Path(__file__).resolve().parent
RAW_DIR = ROOT / "data" / "raw"

# Read local connection settings from .env without hardcoding credentials here.
env = {}
for line in (ROOT / ".env").read_text(encoding="utf-8").splitlines():
    line = line.strip()
    if line and not line.startswith("#") and "=" in line:
        key, value = line.split("=", 1)
        env[key.strip()] = value.strip().strip('"').strip("'")

conn = psycopg.connect(
    host="localhost",
    port=5433,
    dbname=env.get("POSTGRES_DB", "wwi_oltp"),
    user=env.get("POSTGRES_USER", "wwi_user"),
    password=env["POSTGRES_PASSWORD"],
)

def safe_name(value):
    return re.sub(r"[^a-zA-Z0-9_]", "_", value).lower()

files = sorted(RAW_DIR.rglob("*.csv"))
if not files:
    raise FileNotFoundError(f"No CSV files found under {RAW_DIR}")

loaded = 0

try:
    with conn.cursor() as cur:
        cur.execute("CREATE SCHEMA IF NOT EXISTS raw")

        for path in files:
            relative = path.relative_to(RAW_DIR).with_suffix("")
            table_name = safe_name("_".join(relative.parts))
            print(f"Loading {path.relative_to(ROOT)} ...", flush=True)

            with path.open("r", encoding="utf-8-sig", newline="") as f:
                reader = csv.reader(f, delimiter=";")
                headers = next(reader, None)
                if not headers:
                    print("  Skipped: empty file")
                    continue

                columns = [safe_name(h) for h in headers]
                if len(columns) != len(set(columns)):
                    raise ValueError(f"Duplicate column names after cleanup: {path}")

                cur.execute(
                    sql.SQL("DROP TABLE IF EXISTS {}.{}").format(
                        sql.Identifier("raw"), sql.Identifier(table_name)
                    )
                )
                cur.execute(
                    sql.SQL("CREATE TABLE {}.{} ({})").format(
                        sql.Identifier("raw"),
                        sql.Identifier(table_name),
                        sql.SQL(", ").join(
                            sql.SQL("{} TEXT").format(sql.Identifier(c))
                            for c in columns
                        ),
                    )
                )

                insert_stmt = sql.SQL("INSERT INTO {}.{} ({}) VALUES ({})").format(
                    sql.Identifier("raw"),
                    sql.Identifier(table_name),
                    sql.SQL(", ").join(map(sql.Identifier, columns)),
                    sql.SQL(", ").join(sql.Placeholder() for _ in columns),
                )

                count = 0
                for row in reader:
                    if len(row) != len(columns):
                        raise ValueError(
                            f"{path}: row {count + 2} has {len(row)} fields; "
                            f"expected {len(columns)}"
                        )
                    cur.execute(insert_stmt, [v if v != "" else None for v in row])
                    count += 1

                print(f"  Loaded {count:,} rows into raw.{table_name}", flush=True)
                loaded += 1

    conn.commit()
    print(f"\nSUCCESS: loaded {loaded} CSV files into PostgreSQL.")
except Exception:
    conn.rollback()
    raise
finally:
    conn.close()
