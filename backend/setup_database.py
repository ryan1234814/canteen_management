#!/usr/bin/env python3
"""
Simple migration script for normalized canteen database.
"""

import mysql.connector
from config import db_config
import os

def execute_sql_file(cursor, filename):
    """Execute SQL commands from a file"""
    print(f"Executing {filename}...")
    
    with open(filename, 'r') as file:
        sql_content = file.read()
    
    # Split by semicolon and execute each statement
    statements = [stmt.strip() for stmt in sql_content.split(';') if stmt.strip()]
    
    for stmt in statements:
        if stmt and not stmt.startswith('--'):
            try:
                cursor.execute(stmt)
                print(f"✓ Executed statement")
            except Exception as e:
                if "already exists" not in str(e).lower() and "unknown database" not in str(e).lower():
                    print(f"⚠ Warning: {e}")

def main():
    print("=== CANTEEN DATABASE SETUP ===")
    
    try:
        # Connect to MySQL
        conn = mysql.connector.connect(**db_config)
        cursor = conn.cursor()
        
        print("✓ Connected to database")
        
        # Execute schema
        execute_sql_file(cursor, 'schema_clean.sql')
        conn.commit()
        print("✓ Schema created")
        
        # Execute procedures
        execute_sql_file(cursor, 'procedures.sql')
        conn.commit()
        print("✓ Procedures created")
        
        # Execute triggers
        execute_sql_file(cursor, 'triggers.sql')
        conn.commit()
        print("✓ Triggers created")
        
        # Verify setup
        cursor.execute("SHOW TABLES")
        tables = cursor.fetchall()
        print(f"✓ Created {len(tables)} tables")
        
        print("\n=== SETUP COMPLETED SUCCESSFULLY ===")
        print("You can now run: python app.py")
        
    except Exception as e:
        print(f"✗ Error: {e}")
    finally:
        if 'conn' in locals():
            conn.close()

if __name__ == "__main__":
    main()