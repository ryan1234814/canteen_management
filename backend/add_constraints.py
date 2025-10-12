import mysql.connector
from mysql.connector import Error
from config import db_config

constraints = [
    "ALTER TABLE DailyProduction ADD UNIQUE KEY IF NOT EXISTS uq_daily_prod (FoodID, ProductionDate)",
    "ALTER TABLE DailySales ADD UNIQUE KEY IF NOT EXISTS uq_daily_sales (FoodID, SaleDate)",
]

try:
    conn = mysql.connector.connect(**db_config)
    cur = conn.cursor()
    for sql in constraints:
        try:
            print(f"Applying: {sql}")
            cur.execute(sql)
        except Error as e:
            # Fallback for servers that don't support IF NOT EXISTS on keys
            if "Duplicate" in str(e) or "exists" in str(e).lower():
                print(f"Already exists: {sql}")
            else:
                print(f"Error: {e}")
    conn.commit()
    print("Constraints ensured.")
finally:
    try:
        cur.close()
        conn.close()
    except Exception:
        pass
