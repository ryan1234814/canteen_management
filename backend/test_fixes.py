"""
Quick test script to verify the fixes
"""
from models import get_dashboard_data, add_production_data, add_sales_data
from datetime import date

print("=" * 60)
print("TESTING DATABASE FIXES")
print("=" * 60)

# Test 1: Dashboard data (should not error on Revenue column)
print("\n1. Testing get_dashboard_data...")
try:
    data = get_dashboard_data()
    print("   ✓ Success! Dashboard data retrieved:")
    for key, value in data.items():
        print(f"      - {key}: {value}")
except Exception as e:
    print(f"   ✗ Error: {e}")

# Test 2: Add production data (should accept 7 parameters)
print("\n2. Testing add_production_data with 7 parameters...")
try:
    result = add_production_data(
        food_id=1,
        production_date=date.today(),
        quantity_prepared=50,
        staff_id=1,
        start_time=None,
        end_time=None,
        notes="Test production entry"
    )
    if result:
        print("   ✓ Success! Production data added")
    else:
        print("   ! Warning: Function returned False (check logs)")
except Exception as e:
    print(f"   ✗ Error: {e}")

# Test 3: Add sales data (should accept 5 parameters)
print("\n3. Testing add_sales_data with 5 parameters...")
try:
    result = add_sales_data(
        food_id=1,
        sale_date=date.today(),
        quantity_sold=30,
        staff_id=1,
        notes="Test sales entry"
    )
    if result:
        print("   ✓ Success! Sales data added")
    else:
        print("   ! Warning: Function returned False (check logs)")
except Exception as e:
    print(f"   ✗ Error: {e}")

print("\n" + "=" * 60)
print("TEST COMPLETE")
print("=" * 60)
