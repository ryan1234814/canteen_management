from flask import Flask, request, jsonify
from flask_cors import CORS
from config import SECRET_KEY
from models import (
    # Food item functions
    add_fooditem, get_fooditems, get_fooditem_by_id, update_fooditem,
    # Category functions
    get_categories, add_category,
    # Unit functions
    get_units, add_unit,
    # Supplier functions
    get_suppliers, add_supplier,
    # Staff functions
    get_staff, add_staff,
    # Production and sales
    add_production_data, add_sales_data,
    # Reporting
    get_weekly_summary, get_suggestion, get_dashboard_data,
    # Alerts
    get_alerts, resolve_alert,
    # Audit
    get_audit_logs,
    # Validation
    validate_food_exists, get_production_for_date, get_sales_for_date
)

app = Flask(__name__)
app.secret_key = SECRET_KEY
CORS(app)  # Enable CORS for frontend integration

# ===============================
# LOOKUP TABLE ENDPOINTS
# ===============================

@app.route("/api/categories", methods=["GET", "POST"])
def api_categories():
    if request.method == "GET":
        return jsonify(get_categories())
    else:
        data = request.get_json()
        success = add_category(data['category_name'], data.get('description'))
        return jsonify({"success": success})

@app.route("/api/units", methods=["GET", "POST"])
def api_units():
    if request.method == "GET":
        return jsonify(get_units())
    else:
        data = request.get_json()
        success = add_unit(data['unit_name'], data.get('unit_symbol'), data.get('unit_type', 'count'))
        return jsonify({"success": success})

@app.route("/api/suppliers", methods=["GET", "POST"])
def api_suppliers():
    if request.method == "GET":
        return jsonify(get_suppliers())
    else:
        data = request.get_json()
        success = add_supplier(
            data['supplier_name'], 
            data.get('contact_person'), 
            data.get('phone'), 
            data.get('email'), 
            data.get('address')
        )
        return jsonify({"success": success})

@app.route("/api/staff", methods=["GET", "POST"])
def api_staff():
    if request.method == "GET":
        return jsonify(get_staff())
    else:
        data = request.get_json()
        success = add_staff(
            data['staff_name'], 
            data.get('position'), 
            data.get('department', 'kitchen'), 
            data.get('email')
        )
        return jsonify({"success": success})

# ===============================
# ENHANCED FOOD ITEM ENDPOINTS
# ===============================

@app.route("/api/fooditems", methods=["GET", "POST"])
def api_fooditems():
    if request.method == "GET":
        return jsonify(get_fooditems())
    else:
        data = request.get_json()
        success = add_fooditem(
            data['food_name'],
            data['category_id'],
            data['unit_id'],
            data.get('supplier_id'),
            data.get('cost_per_unit', 0.0),
            data.get('selling_price', 0.0),
            data.get('min_stock', 0),
            data.get('max_stock', 1000)
        )
        return jsonify({"success": success})

@app.route("/api/fooditems/<int:food_id>", methods=["GET", "PUT"])
def api_fooditem_detail(food_id):
    if request.method == "GET":
        item = get_fooditem_by_id(food_id)
        if item:
            return jsonify(item)
        return jsonify({"error": "Food item not found"}), 404
    else:
        data = request.get_json()
        success = update_fooditem(food_id, **data)
        return jsonify({"success": success})

# Legacy endpoint for backward compatibility
@app.route("/api/add_fooditem", methods=["POST"])
def api_add_fooditem_legacy():
    data = request.get_json()
    # For backward compatibility, use default values
    success = add_fooditem(
        data['foodname'], 
        data.get('category_id', 1),  # Default to first category
        data.get('unit_id', 1),      # Default to first unit
        data.get('supplier_id'),
        data.get('cost_per_unit', 0.0),
        data.get('selling_price', 0.0)
    )
    return jsonify({"success": success})

@app.route("/api/get_fooditems")
def api_get_fooditems_legacy():
    return jsonify(get_fooditems())

# ===============================
# ENHANCED PRODUCTION & SALES ENDPOINTS
# ===============================

@app.route("/api/production", methods=["POST"])
def api_add_production():
    data = request.get_json()
    
    # Validate required fields
    if not all(key in data for key in ['food_id', 'date', 'quantity']):
        return jsonify({"success": False, "error": "Missing required fields"}), 400
    
    # Validate food exists
    if not validate_food_exists(data['food_id']):
        return jsonify({"success": False, "error": "Invalid food ID"}), 400
    
    success = add_production_data(
        data['food_id'], 
        data['date'], 
        data['quantity'],
        data.get('staff_id', 1),
        data.get('start_time'),
        data.get('end_time'),
        data.get('notes')
    )
    return jsonify({"success": success})

@app.route("/api/sales", methods=["POST"])
def api_add_sales():
    data = request.get_json()
    
    # Validate required fields
    if not all(key in data for key in ['food_id', 'date', 'quantity']):
        return jsonify({"success": False, "error": "Missing required fields"}), 400
    
    # Validate food exists
    if not validate_food_exists(data['food_id']):
        return jsonify({"success": False, "error": "Invalid food ID"}), 400
    
    success = add_sales_data(
        data['food_id'], 
        data['date'], 
        data['quantity'],
        data.get('staff_id', 1),
        data.get('notes')
    )
    return jsonify({"success": success})

# Legacy endpoints for backward compatibility
@app.route("/api/add_production", methods=["POST"])
def api_add_production_legacy():
    data = request.get_json()
    success = add_production_data(data['food_id'], data['date'], data['quantity'])
    return jsonify({"success": success})

@app.route("/api/add_sales", methods=["POST"])
def api_add_sales_legacy():
    data = request.get_json()
    success = add_sales_data(data['food_id'], data['date'], data['quantity'])
    return jsonify({"success": success})

# ===============================
# REPORTING & ANALYTICS ENDPOINTS
# ===============================

@app.route("/api/dashboard")
def api_dashboard():
    """Get dashboard summary data"""
    dashboard_data = get_dashboard_data()
    return jsonify(dashboard_data)

@app.route("/api/weekly_summary")
def api_weekly_summary():
    date = request.args.get("date")
    if not date:
        return jsonify({"error": "Date parameter required"}), 400
    
    summary = get_weekly_summary(date)
    return jsonify(summary)

@app.route("/api/suggestion/<int:food_id>")
def api_suggestion(food_id):
    if not validate_food_exists(food_id):
        return jsonify({"error": "Invalid food ID"}), 404
    
    suggestion = get_suggestion(food_id)
    return jsonify({"food_id": food_id, "suggestion": suggestion})

@app.route("/api/alerts")
def api_get_alerts():
    limit = request.args.get("limit", 10, type=int)
    resolved = request.args.get("resolved", "false").lower() == "true"
    alerts = get_alerts(limit, resolved)
    return jsonify(alerts)

@app.route("/api/alerts/<int:alert_id>/resolve", methods=["POST"])
def api_resolve_alert(alert_id):
    data = request.get_json()
    success = resolve_alert(
        alert_id, 
        data.get('resolved_by', 1), 
        data.get('resolution_notes')
    )
    return jsonify({"success": success})

# ===============================
# DATA INSPECTION ENDPOINTS (for debugging)
# ===============================

@app.route("/api/data/production")
def api_get_production_data():
    """Get production data for inspection"""
    food_id = request.args.get("food_id", type=int)
    date = request.args.get("date")
    
    if food_id and date:
        data = get_production_for_date(food_id, date)
        return jsonify(data)
    
    # Return recent production data if no specific filters
    from models import get_db_connection
    conn = get_db_connection()
    try:
        cur = conn.cursor(dictionary=True)
        cur.execute("""
            SELECT dp.*, f.FoodName, s.StaffName
            FROM DailyProduction dp
            JOIN FoodItem f ON dp.FoodID = f.FoodID
            LEFT JOIN Staff s ON dp.StaffID = s.StaffID
            ORDER BY dp.ProductionDate DESC, dp.CreatedAt DESC
            LIMIT 20
        """)
        return jsonify(cur.fetchall())
    finally:
        cur.close()
        conn.close()

@app.route("/api/data/sales")
def api_get_sales_data():
    """Get sales data for inspection"""
    food_id = request.args.get("food_id", type=int)
    date = request.args.get("date")
    
    if food_id and date:
        data = get_sales_for_date(food_id, date)
        return jsonify(data)
    
    # Return recent sales data if no specific filters
    from models import get_db_connection
    conn = get_db_connection()
    try:
        cur = conn.cursor(dictionary=True)
        cur.execute("""
            SELECT ds.*, f.FoodName, s.StaffName
            FROM DailySales ds
            JOIN FoodItem f ON ds.FoodID = f.FoodID
            LEFT JOIN Staff s ON ds.StaffID = s.StaffID
            ORDER BY ds.SaleDate DESC, ds.CreatedAt DESC
            LIMIT 20
        """)
        return jsonify(cur.fetchall())
    finally:
        cur.close()
        conn.close()

@app.route("/api/data/wastage")
def api_get_wastage_data():
    """Get wastage data for inspection"""
    from models import get_db_connection
    conn = get_db_connection()
    try:
        cur = conn.cursor(dictionary=True)
        cur.execute("""
            SELECT dw.*, f.FoodName, s.StaffName
            FROM DailyWastage dw
            JOIN FoodItem f ON dw.FoodID = f.FoodID
            LEFT JOIN Staff s ON dw.StaffID = s.StaffID
            ORDER BY dw.WastageDate DESC, dw.CreatedAt DESC
            LIMIT 20
        """)
        return jsonify(cur.fetchall())
    finally:
        cur.close()
        conn.close()

@app.route("/api/audit")
def api_get_audit_logs():
    """Get audit logs for inspection"""
    table_name = request.args.get("table")
    limit = request.args.get("limit", 50, type=int)
    logs = get_audit_logs(table_name, limit)
    return jsonify(logs)

# ===============================
# HEALTH CHECK & ROOT ENDPOINTS
# ===============================

@app.route("/api/health")
def api_health():
    """Health check endpoint"""
    try:
        from models import get_db_connection
        conn = get_db_connection()
        if conn:
            conn.close()
            return jsonify({"status": "healthy", "database": "connected"})
        else:
            return jsonify({"status": "unhealthy", "database": "disconnected"}), 500
    except Exception as e:
        return jsonify({"status": "unhealthy", "error": str(e)}), 500

@app.route("/", methods=["GET", "POST"])
def root():
    if request.method == "GET":
        return jsonify({
            "status": "ok",
            "message": "Enhanced Canteen Management API running",
            "version": "2.0",
            "endpoints": {
                "lookup_tables": ["/api/categories", "/api/units", "/api/suppliers", "/api/staff"],
                "food_management": ["/api/fooditems", "/api/fooditems/<id>"],
                "operations": ["/api/production", "/api/sales"],
                "reporting": ["/api/dashboard", "/api/weekly_summary", "/api/suggestion/<id>"],
                "alerts": ["/api/alerts", "/api/alerts/<id>/resolve"],
                "data_inspection": ["/api/data/production", "/api/data/sales", "/api/data/wastage"],
                "system": ["/api/health", "/api/audit"],
                "legacy": ["/api/add_fooditem", "/api/get_fooditems", "/api/add_production", "/api/add_sales"]
            }
        })
    else:
        return jsonify({"status": "ok", "message": "Use /api/* endpoints"}), 200

if __name__ == "__main__":
    # debug=True for development, remove/harden in production
    app.run(debug=True, host='0.0.0.0', port=5000)