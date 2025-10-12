from db import get_db_connection
import json
from datetime import datetime

# ===============================
# CATEGORY MANAGEMENT FUNCTIONS
# ===============================

def get_categories():
    """Get all food categories"""
    conn = get_db_connection()
    try:
        cur = conn.cursor(dictionary=True)
        cur.execute("SELECT * FROM Categories ORDER BY CategoryName")
        return cur.fetchall()
    finally:
        cur.close()
        conn.close()

def add_category(category_name, description=None):
    """Add a new food category"""
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        cur.execute(
            "INSERT INTO Categories (CategoryName, Description) VALUES (%s, %s)",
            (category_name, description)
        )
        conn.commit()
        return True
    except Exception as e:
        print(f"Error adding category: {e}")
        return False
    finally:
        cur.close()
        conn.close()

# ===============================
# UNIT MANAGEMENT FUNCTIONS
# ===============================

def get_units():
    """Get all measurement units"""
    conn = get_db_connection()
    try:
        cur = conn.cursor(dictionary=True)
        cur.execute("SELECT * FROM Units ORDER BY UnitName")
        return cur.fetchall()
    finally:
        cur.close()
        conn.close()

def add_unit(unit_name, unit_symbol=None, unit_type='count'):
    """Add a new measurement unit"""
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        cur.execute(
            "INSERT INTO Units (UnitName, UnitSymbol, UnitType) VALUES (%s, %s, %s)",
            (unit_name, unit_symbol, unit_type)
        )
        conn.commit()
        return True
    except Exception as e:
        print(f"Error adding unit: {e}")
        return False
    finally:
        cur.close()
        conn.close()

# ===============================
# SUPPLIER MANAGEMENT FUNCTIONS
# ===============================

def get_suppliers():
    """Get all suppliers"""
    conn = get_db_connection()
    try:
        cur = conn.cursor(dictionary=True)
        cur.execute("SELECT * FROM Suppliers WHERE IsActive = TRUE ORDER BY SupplierName")
        return cur.fetchall()
    finally:
        cur.close()
        conn.close()

def add_supplier(supplier_name, contact_person=None, phone=None, email=None, address=None):
    """Add a new supplier"""
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        cur.execute(
            """INSERT INTO Suppliers (SupplierName, ContactPerson, Phone, Email, Address) 
               VALUES (%s, %s, %s, %s, %s)""",
            (supplier_name, contact_person, phone, email, address)
        )
        conn.commit()
        return True
    except Exception as e:
        print(f"Error adding supplier: {e}")
        return False
    finally:
        cur.close()
        conn.close()

# ===============================
# STAFF MANAGEMENT FUNCTIONS
# ===============================

def get_staff():
    """Get all active staff"""
    conn = get_db_connection()
    try:
        cur = conn.cursor(dictionary=True)
        cur.execute("SELECT * FROM Staff WHERE IsActive = TRUE ORDER BY StaffName")
        return cur.fetchall()
    finally:
        cur.close()
        conn.close()

def add_staff(staff_name, position=None, department='kitchen', email=None):
    """Add a new staff member"""
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        cur.execute(
            "INSERT INTO Staff (StaffName, Position, Department, Email) VALUES (%s, %s, %s, %s)",
            (staff_name, position, department, email)
        )
        conn.commit()
        return True
    except Exception as e:
        print(f"Error adding staff: {e}")
        return False
    finally:
        cur.close()
        conn.close()

# ===============================
# ENHANCED FOOD ITEM FUNCTIONS
# ===============================

def add_fooditem(foodname, category_id, unit_id, supplier_id=None, cost_per_unit=0.0, selling_price=0.0, min_stock=0, max_stock=1000):
    """Add a new food item with normalized structure"""
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        cur.execute(
            """INSERT INTO FoodItem (FoodName, CategoryID, UnitID, SupplierID, CostPerUnit, 
                                    SellingPricePerUnit, MinStockLevel, MaxStockLevel) 
               VALUES (%s, %s, %s, %s, %s, %s, %s, %s)""",
            (foodname, category_id, unit_id, supplier_id, cost_per_unit, selling_price, min_stock, max_stock)
        )
        conn.commit()
        return True
    except Exception as e:
        print(f"Error adding food item: {e}")
        return False
    finally:
        cur.close()
        conn.close()

def get_fooditems():
    """Get all food items with category, unit, and supplier information"""
    conn = get_db_connection()
    try:
        cur = conn.cursor(dictionary=True)
        cur.execute("""
            SELECT f.*, c.CategoryName, u.UnitName, u.UnitSymbol, s.SupplierName
            FROM FoodItem f
            JOIN Categories c ON f.CategoryID = c.CategoryID
            JOIN Units u ON f.UnitID = u.UnitID
            LEFT JOIN Suppliers s ON f.SupplierID = s.SupplierID
            WHERE f.IsActive = TRUE
            ORDER BY c.CategoryName, f.FoodName
        """)
        rows = cur.fetchall()
        return rows
    finally:
        cur.close()
        conn.close()

def get_fooditem_by_id(food_id):
    """Get specific food item details"""
    conn = get_db_connection()
    try:
        cur = conn.cursor(dictionary=True)
        cur.execute("""
            SELECT f.*, c.CategoryName, u.UnitName, u.UnitSymbol, s.SupplierName
            FROM FoodItem f
            JOIN Categories c ON f.CategoryID = c.CategoryID
            JOIN Units u ON f.UnitID = u.UnitID
            LEFT JOIN Suppliers s ON f.SupplierID = s.SupplierID
            WHERE f.FoodID = %s AND f.IsActive = TRUE
        """, (food_id,))
        return cur.fetchone()
    finally:
        cur.close()
        conn.close()

def update_fooditem(food_id, **kwargs):
    """Update food item with any provided fields"""
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        
        # Build dynamic update query
        set_clauses = []
        values = []
        
        allowed_fields = ['FoodName', 'CategoryID', 'UnitID', 'SupplierID', 'CostPerUnit', 
                         'SellingPricePerUnit', 'MinStockLevel', 'MaxStockLevel', 'IsActive']
        
        for field, value in kwargs.items():
            if field in allowed_fields:
                set_clauses.append(f"{field} = %s")
                values.append(value)
        
        if not set_clauses:
            return False
            
        values.append(food_id)
        query = f"UPDATE FoodItem SET {', '.join(set_clauses)} WHERE FoodID = %s"
        
        cur.execute(query, values)
        conn.commit()
        return True
    except Exception as e:
        print(f"Error updating food item: {e}")
        return False
    finally:
        cur.close()
        conn.close()

# ===============================
# ENHANCED PROCEDURE CALLS
# ===============================

def call_procedure(proc_name, params):
    """Generic procedure caller"""
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        cur.callproc(proc_name, params)
        conn.commit()
        return True
    except Exception as e:
        print(f"Error calling procedure {proc_name}: {e}")
        return False
    finally:
        cur.close()
        conn.close()

def add_production_data(food_id, production_date, quantity_prepared, staff_id=1, start_time=None, end_time=None, notes=None):
    """Add production data with enhanced parameters"""
    return call_procedure("AddProductionData", 
                         [food_id, production_date, quantity_prepared, staff_id, start_time, end_time, notes])

def add_sales_data(food_id, sale_date, quantity_sold, staff_id=1, notes=None):
    """Add sales data with enhanced parameters"""
    return call_procedure("AddSalesData", 
                         [food_id, sale_date, quantity_sold, staff_id, notes])

# ===============================
# REPORTING AND ANALYTICS
# ===============================

def get_weekly_summary(start_date):
    """Get enhanced weekly summary with financial data"""
    conn = get_db_connection()
    try:
        cur = conn.cursor(dictionary=True)
        cur.callproc('GenerateWeeklySummaryReport', [start_date])
        summary = []
        for result in cur.stored_results():
            summary.extend(result.fetchall())
        return summary
    finally:
        cur.close()
        conn.close()

def get_suggestion(food_id):
    """Get production suggestion for a food item"""
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        cur.execute("SELECT GetProductionSuggestion(%s)", (food_id,))
        suggestion = cur.fetchone()[0]
        return suggestion
    finally:
        cur.close()
        conn.close()

def get_dashboard_data():
    """Get dashboard summary data"""
    conn = get_db_connection()
    try:
        cur = conn.cursor(dictionary=True)
        
        # Get today's summary
        cur.execute("""
            SELECT 
                COUNT(DISTINCT dp.FoodID) as items_produced,
                IFNULL(SUM(dp.QuantityPrepared), 0) as total_produced,
                IFNULL(SUM(ds.QuantitySold), 0) as total_sold,
                IFNULL(SUM(dw.QuantityWasted), 0) as total_wasted,
                IFNULL(SUM(ds.QuantitySold * ds.SalePrice), 0) as total_revenue,
                IFNULL(SUM(dw.WasteValue), 0) as waste_value
            FROM DailyProduction dp
            LEFT JOIN DailySales ds ON dp.FoodID = ds.FoodID AND dp.ProductionDate = ds.SaleDate
            LEFT JOIN DailyWastage dw ON dp.FoodID = dw.FoodID AND dp.ProductionDate = dw.WastageDate
            WHERE dp.ProductionDate = CURDATE()
        """)
        
        dashboard_data = cur.fetchone()
        
        # Get active alerts
        cur.execute("""
            SELECT COUNT(*) as active_alerts
            FROM WastageAlert 
            WHERE IsResolved = FALSE AND AlertDate >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
        """)
        
        alert_data = cur.fetchone()
        dashboard_data.update(alert_data)
        
        return dashboard_data
    finally:
        cur.close()
        conn.close()

def get_alerts(limit=10, resolved=False):
    """Get recent alerts"""
    conn = get_db_connection()
    try:
        cur = conn.cursor(dictionary=True)
        cur.execute("""
            SELECT a.*, f.FoodName, c.CategoryName
            FROM WastageAlert a
            JOIN FoodItem f ON a.FoodID = f.FoodID
            JOIN Categories c ON f.CategoryID = c.CategoryID
            WHERE a.IsResolved = %s
            ORDER BY a.CreatedAt DESC
            LIMIT %s
        """, (resolved, limit))
        return cur.fetchall()
    finally:
        cur.close()
        conn.close()

def resolve_alert(alert_id, resolved_by, resolution_notes=None):
    """Resolve an alert"""
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        cur.execute("""
            UPDATE WastageAlert 
            SET IsResolved = TRUE, ResolvedBy = %s, ResolvedAt = CURRENT_TIMESTAMP, ResolutionNotes = %s
            WHERE AlertID = %s
        """, (resolved_by, resolution_notes, alert_id))
        conn.commit()
        return True
    except Exception as e:
        print(f"Error resolving alert: {e}")
        return False
    finally:
        cur.close()
        conn.close()

# ===============================
# AUDIT LOG FUNCTIONS
# ===============================

def get_audit_logs(table_name=None, limit=50):
    """Get audit logs with optional table filter"""
    conn = get_db_connection()
    try:
        cur = conn.cursor(dictionary=True)
        if table_name:
            cur.execute("""
                SELECT a.*, s.StaffName
                FROM AuditLog a
                LEFT JOIN Staff s ON a.StaffID = s.StaffID
                WHERE a.TableName = %s
                ORDER BY a.CreatedAt DESC
                LIMIT %s
            """, (table_name, limit))
        else:
            cur.execute("""
                SELECT a.*, s.StaffName
                FROM AuditLog a
                LEFT JOIN Staff s ON a.StaffID = s.StaffID
                ORDER BY a.CreatedAt DESC
                LIMIT %s
            """, (limit,))
        return cur.fetchall()
    finally:
        cur.close()
        conn.close()

# ===============================
# DATA VALIDATION FUNCTIONS
# ===============================

def validate_food_exists(food_id):
    """Check if food item exists and is active"""
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        cur.execute("SELECT COUNT(*) FROM FoodItem WHERE FoodID = %s AND IsActive = TRUE", (food_id,))
        return cur.fetchone()[0] > 0
    finally:
        cur.close()
        conn.close()

def get_production_for_date(food_id, date):
    """Get production quantity for specific food and date"""
    conn = get_db_connection()
    try:
        cur = conn.cursor(dictionary=True)
        cur.execute("""
            SELECT * FROM DailyProduction 
            WHERE FoodID = %s AND ProductionDate = %s
        """, (food_id, date))
        return cur.fetchone()
    finally:
        cur.close()
        conn.close()

def get_sales_for_date(food_id, date):
    """Get sales quantity for specific food and date"""
    conn = get_db_connection()
    try:
        cur = conn.cursor(dictionary=True)
        cur.execute("""
            SELECT * FROM DailySales 
            WHERE FoodID = %s AND SaleDate = %s
        """, (food_id, date))
        return cur.fetchone()
    finally:
        cur.close()
        conn.close()