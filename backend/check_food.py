import mysql.connector
from config import db_config

conn = mysql.connector.connect(**db_config)
cur = conn.cursor(dictionary=True)
cur.execute('SELECT * FROM FoodItem LIMIT 5')
items = cur.fetchall()
print('Food items:')
for item in items:
    print(f'  ID={item["FoodID"]}, Name={item["FoodName"]}, Cost={item["CostPerUnit"]}')
cur.close()
conn.close()
