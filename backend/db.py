import mysql.connector
from mysql.connector import Error
from config import db_config

def get_db_connection():
    try:
        conn = mysql.connector.connect(**db_config)
        if conn.is_connected():
            return conn
    except Error as e:
        print(f"DB Connection Error: {e}")
    return None
