import mysql.connector
from mysql.connector import Error
from config import db_config

queries = {
    "FoodItem": "SELECT * FROM FoodItem ORDER BY FoodID DESC LIMIT 10",
    "DailyProduction": "SELECT * FROM DailyProduction ORDER BY ProductionID DESC LIMIT 10",
    "DailySales": "SELECT * FROM DailySales ORDER BY SaleID DESC LIMIT 10",
    "DailyWastage": "SELECT * FROM DailyWastage ORDER BY WastageID DESC LIMIT 10",
    "WastageAlert": "SELECT * FROM WastageAlert ORDER BY AlertID DESC LIMIT 10",
}

try:
    conn = mysql.connector.connect(**db_config)
    cur = conn.cursor()
    for name, sql in queries.items():
        print(f"\n=== {name} ===")
        cur.execute(sql)
        rows = cur.fetchall()
        for row in rows:
            print(row)
    print("\nVerification complete.")
finally:
    try:
        cur.close()
        conn.close()
    except Exception:
        pass
