import psycopg

conn = psycopg.connect(
    host="localhost",
    port=5433,
    dbname="wwi_oltp",
    user="wwi_user",
    password="WWI_Local_2026_change_me"
)

with conn.cursor() as cur:
    cur.execute("SELECT version();")
    print("PostgreSQL connection successful!")
    print(cur.fetchone()[0])

conn.close()
