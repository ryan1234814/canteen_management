import mysql.connector
import mysql.connector
from config import db_config

def reload_procedures():
    """Reload stored procedures from procedures.sql"""
    conn = mysql.connector.connect(**db_config)
    
    try:
        # Read the procedures.sql file
        with open('procedures.sql', 'r', encoding='utf-8') as f:
            sql_content = f.read()
        
        # Execute using multi=True
        print("Reloading stored procedures...")
        
        # Split and execute each statement manually
        cur = conn.cursor()
        
        for statement in sql_content.split('$$'):
            statement = statement.strip()
            # Remove DELIMITER lines
            statement = statement.replace('DELIMITER $$', '').replace('DELIMITER ;', '').strip()
            
            # Skip empty statements and comments
            if not statement or statement.startswith('--') or statement == 'USE canteen_db;':
                continue
            
            # Execute DROP statements
            if statement.startswith('DROP'):
                try:
                    print(f"Executing: {statement[:50]}...")
                    cur.execute(statement)
                    conn.commit()
                    print("  ✓ Success")
                except Exception as e:
                    print(f"  ! Warning: {e}")
                continue
            
            # Execute CREATE PROCEDURE/FUNCTION statements
            if 'CREATE PROCEDURE' in statement or 'CREATE FUNCTION' in statement:
                try:
                    proc_name = ''
                    if 'CREATE PROCEDURE' in statement:
                        proc_name = statement.split('CREATE PROCEDURE')[1].split('(')[0].strip()
                    elif 'CREATE FUNCTION' in statement:
                        proc_name = statement.split('CREATE FUNCTION')[1].split('(')[0].strip()
                    
                    print(f"Creating: {proc_name}")
                    cur.execute(statement)
                    conn.commit()
                    print("  ✓ Success")
                except Exception as e:
                    print(f"  ✗ Error: {e}")
        
        cur.close()
        print("\nProcedures reloaded successfully!")
        
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
    finally:
        conn.close()

if __name__ == '__main__':
    reload_procedures()
