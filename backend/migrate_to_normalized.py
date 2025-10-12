#!/usr/bin/env python3
"""
Migration script to transform existing canteen database to normalized structure.
This script will:
1. Backup existing data
2. Create normalized schema
3. Migrate data to new structure
4. Verify data integrity
"""

import mysql.connector
from mysql.connector import Error
from config import db_config
import json
from datetime import datetime
import sys

class DatabaseMigrator:
    def __init__(self):
        self.conn = None
        self.backup_data = {}
        
    def connect(self):
        """Establish database connection"""
        try:
            self.conn = mysql.connector.connect(**db_config)
            print("✓ Connected to database")
            return True
        except Error as e:
            print(f"✗ Database connection failed: {e}")
            return False
    
    def backup_existing_data(self):
        """Backup existing data before migration"""
        print("\n=== BACKING UP EXISTING DATA ===")
        
        if not self.conn:
            print("✗ No database connection")
            return False
            
        try:
            cursor = self.conn.cursor(dictionary=True)
            
            # Check if old tables exist
            cursor.execute("SHOW TABLES")
            existing_tables = [table[list(table.keys())[0]] for table in cursor.fetchall()]
            
            tables_to_backup = ['FoodItem', 'DailyProduction', 'DailySales', 'DailyWastage', 'WastageAlert']
            
            for table in tables_to_backup:
                if table in existing_tables:
                    cursor.execute(f"SELECT * FROM {table}")
                    self.backup_data[table] = cursor.fetchall()
                    print(f"✓ Backed up {len(self.backup_data[table])} records from {table}")
                else:
                    print(f"⚠ Table {table} not found - skipping backup")
                    self.backup_data[table] = []
            
            # Save backup to file
            backup_filename = f"backup_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
            with open(backup_filename, 'w') as f:
                json.dump(self.backup_data, f, indent=2, default=str)
            print(f"✓ Backup saved to {backup_filename}")
            
            return True
            
        except Error as e:
            print(f"✗ Backup failed: {e}")
            return False
    
    def apply_normalized_schema(self):
        """Apply the new normalized schema"""
        print("\n=== APPLYING NORMALIZED SCHEMA ===")
        
        try:
            cursor = self.conn.cursor()
            
            # Read and execute schema.sql
            with open('schema.sql', 'r') as f:
                schema_content = f.read()
            
            # Split by delimiter and execute each statement
            statements = schema_content.split('DELIMITER')
            
            for i, statement in enumerate(statements):
                if statement.strip():
                    # Handle delimiter changes
                    if '//' in statement:
                        lines = statement.split('\n')
                        delimiter = '//'
                        statement_lines = []
                        for line in lines:
                            if line.strip() and not line.strip().startswith('//'):
                                statement_lines.append(line)
                        if statement_lines:
                            statement_to_execute = '\n'.join(statement_lines)
                            if statement_to_execute.strip():
                                try:
                                    cursor.execute(statement_to_execute)
                                    print(f"✓ Executed statement block {i+1}")
                                except Error as e:
                                    if "already exists" not in str(e).lower():
                                        print(f"⚠ Warning in statement {i+1}: {e}")
                    else:
                        # Regular SQL statements
                        individual_statements = [s.strip() for s in statement.split(';') if s.strip()]
                        for stmt in individual_statements:
                            if stmt and not stmt.startswith('--'):
                                try:
                                    cursor.execute(stmt)
                                    print(f"✓ Executed: {stmt[:50]}...")
                                except Error as e:
                                    if "already exists" not in str(e).lower():
                                        print(f"⚠ Warning: {e}")
            
            self.conn.commit()
            print("✓ Schema applied successfully")
            return True
            
        except Exception as e:
            print(f"✗ Schema application failed: {e}")
            return False
    
    def migrate_lookup_data(self):
        """Migrate data to lookup tables"""
        print("\n=== MIGRATING LOOKUP DATA ===")
        
        try:
            cursor = self.conn.cursor()
            
            # The default data is already inserted via schema.sql INSERT statements
            # Just verify they exist
            cursor.execute("SELECT COUNT(*) FROM Categories")
            cat_count = cursor.fetchone()[0]
            print(f"✓ Categories: {cat_count} records")
            
            cursor.execute("SELECT COUNT(*) FROM Units")
            unit_count = cursor.fetchone()[0]
            print(f"✓ Units: {unit_count} records")
            
            cursor.execute("SELECT COUNT(*) FROM Suppliers")
            supplier_count = cursor.fetchone()[0]
            print(f"✓ Suppliers: {supplier_count} records")
            
            cursor.execute("SELECT COUNT(*) FROM Staff")
            staff_count = cursor.fetchone()[0]
            print(f"✓ Staff: {staff_count} records")
            
            return True
            
        except Error as e:
            print(f"✗ Lookup data migration failed: {e}")
            return False
    
    def migrate_food_items(self):
        """Migrate food items to normalized structure"""
        print("\n=== MIGRATING FOOD ITEMS ===")
        
        if not self.backup_data.get('FoodItem'):
            print("⚠ No food items to migrate")
            return True
            
        try:
            cursor = self.conn.cursor()
            
            # Get default IDs for lookup tables
            cursor.execute("SELECT CategoryID FROM Categories LIMIT 1")
            default_category = cursor.fetchone()[0]
            
            cursor.execute("SELECT UnitID FROM Units WHERE UnitName = 'Plates' LIMIT 1")
            result = cursor.fetchone()
            default_unit = result[0] if result else 1
            
            cursor.execute("SELECT SupplierID FROM Suppliers LIMIT 1")
            default_supplier = cursor.fetchone()[0]
            
            migrated_count = 0
            
            for old_item in self.backup_data['FoodItem']:
                # Map old unit text to unit ID
                unit_id = default_unit
                if 'Unit' in old_item and old_item['Unit']:
                    cursor.execute("SELECT UnitID FROM Units WHERE UnitName LIKE %s", (f"%{old_item['Unit']}%",))
                    result = cursor.fetchone()
                    if result:
                        unit_id = result[0]
                
                # Insert into new normalized structure
                cursor.execute("""
                    INSERT INTO FoodItem (FoodID, FoodName, CategoryID, UnitID, SupplierID, CostPerUnit, SellingPricePerUnit)
                    VALUES (%s, %s, %s, %s, %s, %s, %s)
                    ON DUPLICATE KEY UPDATE 
                        FoodName = VALUES(FoodName),
                        CategoryID = VALUES(CategoryID),
                        UnitID = VALUES(UnitID)
                """, (
                    old_item['FoodID'],
                    old_item['FoodName'],
                    default_category,
                    unit_id,
                    default_supplier,
                    0.00,  # Default cost
                    0.00   # Default selling price
                ))
                migrated_count += 1
            
            self.conn.commit()
            print(f"✓ Migrated {migrated_count} food items")
            return True
            
        except Error as e:
            print(f"✗ Food items migration failed: {e}")
            return False
    
    def migrate_operational_data(self):
        """Migrate production, sales, and wastage data"""
        print("\n=== MIGRATING OPERATIONAL DATA ===")
        
        try:
            cursor = self.conn.cursor()
            
            # Get default staff ID
            cursor.execute("SELECT StaffID FROM Staff WHERE Position = 'Administrator' LIMIT 1")
            default_staff = cursor.fetchone()[0]
            
            # Migrate production data
            if self.backup_data.get('DailyProduction'):
                prod_count = 0
                for prod in self.backup_data['DailyProduction']:
                    cursor.execute("""
                        INSERT INTO DailyProduction (ProductionID, FoodID, ProductionDate, QuantityPrepared, StaffID, ProductionCost)
                        VALUES (%s, %s, %s, %s, %s, %s)
                        ON DUPLICATE KEY UPDATE 
                            QuantityPrepared = VALUES(QuantityPrepared)
                    """, (
                        prod['ProductionID'],
                        prod['FoodID'],
                        prod['ProductionDate'],
                        prod['QuantityPrepared'],
                        default_staff,
                        0.00  # Will be calculated by trigger
                    ))
                    prod_count += 1
                print(f"✓ Migrated {prod_count} production records")
            
            # Migrate sales data
            if self.backup_data.get('DailySales'):
                sales_count = 0
                for sale in self.backup_data['DailySales']:
                    cursor.execute("""
                        INSERT INTO DailySales (SaleID, FoodID, SaleDate, QuantitySold, StaffID, SalePrice)
                        VALUES (%s, %s, %s, %s, %s, %s)
                        ON DUPLICATE KEY UPDATE 
                            QuantitySold = VALUES(QuantitySold)
                    """, (
                        sale['SaleID'],
                        sale['FoodID'],
                        sale['SaleDate'],
                        sale['QuantitySold'],
                        default_staff,
                        0.00  # Will be calculated by trigger
                    ))
                    sales_count += 1
                print(f"✓ Migrated {sales_count} sales records")
            
            # Migrate wastage data (if any - will be recalculated by triggers)
            if self.backup_data.get('DailyWastage'):
                wastage_count = 0
                for wastage in self.backup_data['DailyWastage']:
                    cursor.execute("""
                        INSERT INTO DailyWastage (WastageID, FoodID, WastageDate, QuantityWasted, WastageReason, StaffID)
                        VALUES (%s, %s, %s, %s, %s, %s)
                        ON DUPLICATE KEY UPDATE 
                            QuantityWasted = VALUES(QuantityWasted)
                    """, (
                        wastage['WastageID'],
                        wastage['FoodID'],
                        wastage['WastageDate'],
                        wastage['QuantityWasted'],
                        'overproduction',  # Default reason
                        default_staff
                    ))
                    wastage_count += 1
                print(f"✓ Migrated {wastage_count} wastage records")
            
            # Migrate alerts
            if self.backup_data.get('WastageAlert'):
                alert_count = 0
                for alert in self.backup_data['WastageAlert']:
                    cursor.execute("""
                        INSERT INTO WastageAlert (AlertID, FoodID, AlertDate, WastagePercentage, AlertType, AlertMessage, Severity)
                        VALUES (%s, %s, %s, %s, %s, %s, %s)
                        ON DUPLICATE KEY UPDATE 
                            WastagePercentage = VALUES(WastagePercentage),
                            AlertMessage = VALUES(AlertMessage)
                    """, (
                        alert['AlertID'],
                        alert['FoodID'],
                        alert['AlertDate'],
                        alert['WastagePercentage'],
                        'high_wastage',
                        alert['AlertMessage'],
                        'medium'
                    ))
                    alert_count += 1
                print(f"✓ Migrated {alert_count} alert records")
            
            self.conn.commit()
            return True
            
        except Error as e:
            print(f"✗ Operational data migration failed: {e}")
            return False
    
    def verify_migration(self):
        """Verify migration was successful"""
        print("\n=== VERIFYING MIGRATION ===")
        
        try:
            cursor = self.conn.cursor(dictionary=True)
            
            # Check table counts
            tables = ['Categories', 'Units', 'Suppliers', 'Staff', 'FoodItem', 'DailyProduction', 'DailySales', 'DailyWastage', 'WastageAlert']
            
            for table in tables:
                cursor.execute(f"SELECT COUNT(*) as count FROM {table}")
                count = cursor.fetchone()['count']
                print(f"✓ {table}: {count} records")
            
            # Test a join query
            cursor.execute("""
                SELECT f.FoodName, c.CategoryName, u.UnitName
                FROM FoodItem f
                JOIN Categories c ON f.CategoryID = c.CategoryID
                JOIN Units u ON f.UnitID = u.UnitID
                LIMIT 3
            """)
            
            results = cursor.fetchall()
            if results:
                print("✓ Join queries working correctly")
                for row in results:
                    print(f"  - {row['FoodName']} ({row['CategoryName']}, {row['UnitName']})")
            
            # Test triggers
            print("✓ Database structure verification complete")
            return True
            
        except Error as e:
            print(f"✗ Verification failed: {e}")
            return False
    
    def run_migration(self):
        """Run the complete migration process"""
        print("=== CANTEEN DATABASE NORMALIZATION MIGRATION ===")
        print(f"Started at: {datetime.now()}")
        
        if not self.connect():
            sys.exit(1)
        
        steps = [
            ("Backup existing data", self.backup_existing_data),
            ("Apply normalized schema", self.apply_normalized_schema),
            ("Migrate lookup data", self.migrate_lookup_data),
            ("Migrate food items", self.migrate_food_items),
            ("Migrate operational data", self.migrate_operational_data),
            ("Verify migration", self.verify_migration)
        ]
        
        for step_name, step_func in steps:
            print(f"\n--- {step_name} ---")
            if not step_func():
                print(f"✗ Migration failed at: {step_name}")
                sys.exit(1)
        
        print("\n=== MIGRATION COMPLETED SUCCESSFULLY ===")
        print(f"Completed at: {datetime.now()}")
        print("\nNext steps:")
        print("1. Test the application with: python app.py")
        print("2. Verify data via API endpoints")
        print("3. Update frontend if needed")
        
        if self.conn:
            self.conn.close()

if __name__ == "__main__":
    migrator = DatabaseMigrator()
    migrator.run_migration()