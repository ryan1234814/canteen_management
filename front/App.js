import React, { useState, useEffect } from "react";
import axios from "axios";
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, Legend, PieChart, Pie, Cell } from "recharts";
import "./App.css"; // We'll use CSS for colors and layout

function App() {
  // --------------------------
  // State
  // --------------------------
  const [page, setPage] = useState("login"); // "login", "dashboard", "detail"
  const [loginAttempts, setLoginAttempts] = useState(0);
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [activeDetail, setActiveDetail] = useState("Production"); // selected detail page

  // Enhanced state for normalized data
  const [foodItems, setFoodItems] = useState([]);
  const [categories, setCategories] = useState([]);
  const [units, setUnits] = useState([]);
  const [suppliers, setSuppliers] = useState([]);
  const [staff, setStaff] = useState([]);
  const [dashboardData, setDashboardData] = useState({});
  const [alerts, setAlerts] = useState([]);
  const [loading, setLoading] = useState(false);
  
  // New features state
  const [productionSuggestions, setProductionSuggestions] = useState([]);
  const [wastageAnalytics, setWastageAnalytics] = useState(null);

  // Form states
  const [newFoodForm, setNewFoodForm] = useState({
    food_name: "",
    category_id: "",
    unit_id: "",
    supplier_id: "",
    cost_per_unit: "",
    selling_price: "",
    min_stock: "",
    max_stock: ""
  });

  // Local timezone ISO date utility to avoid UTC offset issues
  const localISODate = () => {
    const d = new Date();
    const tzOff = d.getTimezoneOffset();
    const local = new Date(d.getTime() - tzOff * 60000);
    return local.toISOString().slice(0, 10);
  };

  const [productionForm, setProductionForm] = useState({
    food_id: "",
    date: localISODate(),
    quantity: "",
    staff_id: "",
    start_time: "",
    end_time: "",
    notes: ""
  });

  const [salesForm, setSalesForm] = useState({
    food_id: "",
    date: localISODate(),
    quantity: "",
    staff_id: "",
    notes: ""
  });

  const fetchLookupData = async () => {
    try {
      const [categoriesRes, unitsRes, suppliersRes, staffRes] = await Promise.all([
        axios.get('/api/categories'),
        axios.get('/api/units'),
        axios.get('/api/suppliers'),
        axios.get('/api/staff')
      ]);
      setCategories(categoriesRes.data);
      setUnits(unitsRes.data);
      setSuppliers(suppliersRes.data);
      setStaff(staffRes.data);
    } catch (error) {
      console.error('Failed to fetch lookup data:', error);
    }
  };

  const fetchFoodItems = async () => {
    try {
      const response = await axios.get('/api/fooditems');
      setFoodItems(response.data);
    } catch (error) {
      console.error('Failed to fetch food items:', error);
    }
  };

  const fetchDashboardData = async () => {
    try {
      const response = await axios.get('/api/dashboard');
      setDashboardData(response.data);
    } catch (error) {
      console.error('Failed to fetch dashboard data:', error);
    }
  };

  const fetchAlerts = async () => {
    try {
      const response = await axios.get('/api/alerts?limit=10');
      setAlerts(response.data);
    } catch (error) {
      console.error('Failed to fetch alerts:', error);
    }
  };

  const fetchProductionSuggestions = async () => {
    try {
      const response = await axios.get('/api/production/suggestions');
      setProductionSuggestions(response.data);
    } catch (error) {
      console.error('Failed to fetch production suggestions:', error);
    }
  };

  const fetchWastageAnalytics = async () => {
    try {
      const response = await axios.get('/api/wastage/analytics');
      setWastageAnalytics(response.data);
    } catch (error) {
      console.error('Failed to fetch wastage analytics:', error);
    }
  };

  // --------------------------
  // Effects
  // --------------------------
  useEffect(() => {
    if (page === "dashboard" || page === "detail") {
      fetchLookupData();
      fetchFoodItems();
      fetchDashboardData();
      fetchAlerts();
    }
  }, [page]);

  useEffect(() => {
    if (page === "detail" && activeDetail === "Production") {
      fetchProductionSuggestions();
    }
    if (page === "detail" && activeDetail === "Analytics") {
      fetchWastageAnalytics();
    }
  }, [page, activeDetail]);

  // --------------------------
  // Handlers
  // --------------------------
  const handleLogin = () => {
    if (loginAttempts >= 3) {
      alert("Maximum login attempts reached!");
      return;
    }
    if (username === "admin" && password === "1234") {
      setPage("dashboard");
    } else {
      setLoginAttempts(loginAttempts + 1);
      alert(`Wrong credentials! Attempts left: ${3 - loginAttempts - 1}`);
    }
  };

  const handleAddFood = async () => {
    if (!newFoodForm.food_name || !newFoodForm.category_id || !newFoodForm.unit_id) {
      alert("Please fill in required fields: Food Name, Category, and Unit");
      return;
    }

    setLoading(true);
    try {
      const response = await axios.post('/api/fooditems', newFoodForm);
      if (response.data.success) {
        alert("Food item added successfully!");
        setNewFoodForm({
          food_name: "",
          category_id: "",
          unit_id: "",
          supplier_id: "",
          cost_per_unit: "",
          selling_price: "",
          min_stock: "",
          max_stock: ""
        });
        await fetchFoodItems();
      } else {
        alert("Failed to add food item");
      }
    } catch (error) {
      alert("Error adding food item: " + (error.response?.data?.error || error.message));
    }
    setLoading(false);
  };

  const handleAddProduction = async () => {
    if (!productionForm.food_id || !productionForm.quantity) {
      alert("Please select food item and enter quantity");
      return;
    }

    setLoading(true);
    try {
      const response = await axios.post('/api/production', productionForm);
      if (response.data.success) {
        alert("Production data added successfully!");
        setProductionForm({
          ...productionForm,
          quantity: "",
          notes: ""
        });
        await fetchDashboardData();
      } else {
        alert("Failed to add production data: " + (response.data.error || "Unknown error"));
      }
    } catch (error) {
      alert("Error adding production data: " + (error.response?.data?.error || error.message));
    }
    setLoading(false);
  };

  const handleAddSales = async () => {
    if (!salesForm.food_id || !salesForm.quantity) {
      alert("Please select food item and enter quantity");
      return;
    }

    setLoading(true);
    try {
      const response = await axios.post('/api/sales', salesForm);
      if (response.data.success) {
        alert("Sales data added successfully!");
        setSalesForm({
          ...salesForm,
          quantity: "",
          notes: ""
        });
        await fetchDashboardData();
        await fetchAlerts(); // Refresh alerts after sales update
      } else {
        alert("Failed to add sales data: " + (response.data.error || "Unknown error"));
      }
    } catch (error) {
      alert("Error adding sales data: " + (error.response?.data?.error || error.message));
    }
    setLoading(false);
  };

  const handleResolveAlert = async (alertId) => {
    try {
      const response = await axios.post(`/api/alerts/${alertId}/resolve`, {
        resolved_by: 1, // Admin user
        resolution_notes: "Resolved via UI"
      });
      if (response.data.success) {
        alert("Alert resolved!");
        await fetchAlerts();
      }
    } catch (error) {
      alert("Failed to resolve alert");
    }
  };

  // --------------------------
  // Chart Data Preparation
  // --------------------------
  const chartData = foodItems.map(item => ({
    name: item.FoodName,
    category: item.CategoryName,
    cost: parseFloat(item.CostPerUnit || 0),
    price: parseFloat(item.SellingPricePerUnit || 0)
  }));

  const alertsByType = alerts.reduce((acc, alert) => {
    acc[alert.AlertType] = (acc[alert.AlertType] || 0) + 1;
    return acc;
  }, {});

  const alertChartData = Object.entries(alertsByType).map(([type, count]) => ({
    name: type.replace('_', ' ').toUpperCase(),
    value: count
  }));

  const colors = ['#0088FE', '#00C49F', '#FFBB28', '#FF8042', '#8884D8'];

  // --------------------------
  // Page Rendering
  // --------------------------
  if (page === "login") {
    return (
      <div className="login-page">
        <h1>Enhanced Canteen Management System</h1>
        <p>Normalized Database with Advanced Triggers</p>
        <input 
          placeholder="Username" 
          value={username} 
          onChange={e => setUsername(e.target.value)} 
        />
        <input 
          type="password" 
          placeholder="Password" 
          value={password} 
          onChange={e => setPassword(e.target.value)} 
          onKeyPress={e => e.key === 'Enter' && handleLogin()}
        />
        <button className="login-btn" onClick={handleLogin}>Login</button>
        <div className="login-hint">
          <small>Use: admin / 1234</small>
        </div>
      </div>
    );
  }

  if (page === "dashboard") {
    return (
      <div className="dashboard-page">
        <h1>Enhanced Canteen Dashboard</h1>
        
        {/* Dashboard Summary Cards */}
        <div className="summary-cards">
          <div className="summary-card">
            <h3>Today's Production</h3>
            <p className="big-number">{dashboardData.total_produced || 0}</p>
            <small>items produced</small>
          </div>
          <div className="summary-card">
            <h3>Today's Sales</h3>
            <p className="big-number">{dashboardData.total_sold || 0}</p>
            <small>items sold</small>
          </div>
          <div className="summary-card">
            <h3>Today's Waste</h3>
            <p className="big-number">{dashboardData.total_wasted || 0}</p>
            <small>items wasted</small>
          </div>
          <div className="summary-card">
            <h3>Revenue</h3>
            <p className="big-number">₹{parseFloat(dashboardData.total_revenue || 0).toFixed(2)}</p>
            <small>today's revenue</small>
          </div>
        </div>

        {/* Active Alerts */}
        {alerts.length > 0 && (
          <div className="alerts-section">
            <h3>Active Alerts ({alerts.length})</h3>
            <div className="alerts-list">
              {alerts.slice(0, 3).map(alert => (
                <div key={alert.AlertID} className={`alert-item severity-${alert.Severity}`}>
                  <div className="alert-content">
                    <strong>{alert.FoodName}</strong> - {alert.AlertMessage}
                    <small>{new Date(alert.AlertDate).toLocaleDateString()}</small>
                  </div>
                  <button 
                    className="resolve-btn"
                    onClick={() => handleResolveAlert(alert.AlertID)}
                  >
                    Resolve
                  </button>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Navigation Cards */}
        <div className="card-container">
          {[
            { name: "Food Management", detail: "FoodManagement" },
            { name: "Production", detail: "Production" },
            { name: "Sales", detail: "Sales" },
            { name: "Analytics", detail: "Analytics" },
            { name: "Alerts", detail: "Alerts" }
          ].map(opt => (
            <div 
              key={opt.name} 
              className="dashboard-card" 
              onClick={() => { setActiveDetail(opt.detail); setPage("detail") }}
            >
              {opt.name}
            </div>
          ))}
        </div>
      </div>
    );
  }

  if (page === "detail") {
    return (
      <div className="detail-page">
        <button className="back-btn" onClick={() => setPage("dashboard")}>← Back to Dashboard</button>
        <h2>{activeDetail.replace(/([A-Z])/g, ' $1').trim()}</h2>

        {/* Food Management Page */}
        {activeDetail === "FoodManagement" && (
          <div>
            <div className="add-food-form">
              <h3>Add New Food Item</h3>
              <div className="form-grid">
                <input
                  type="text"
                  placeholder="Food Name *"
                  value={newFoodForm.food_name}
                  onChange={(e) => setNewFoodForm({...newFoodForm, food_name: e.target.value})}
                />
                <select
                  value={newFoodForm.category_id}
                  onChange={(e) => setNewFoodForm({...newFoodForm, category_id: e.target.value})}
                >
                  <option value="">Select Category *</option>
                  {categories.map(cat => (
                    <option key={cat.CategoryID} value={cat.CategoryID}>{cat.CategoryName}</option>
                  ))}
                </select>
                <select
                  value={newFoodForm.unit_id}
                  onChange={(e) => setNewFoodForm({...newFoodForm, unit_id: e.target.value})}
                >
                  <option value="">Select Unit *</option>
                  {units.map(unit => (
                    <option key={unit.UnitID} value={unit.UnitID}>{unit.UnitName}</option>
                  ))}
                </select>
                <select
                  value={newFoodForm.supplier_id}
                  onChange={(e) => setNewFoodForm({...newFoodForm, supplier_id: e.target.value})}
                >
                  <option value="">Select Supplier</option>
                  {suppliers.map(supplier => (
                    <option key={supplier.SupplierID} value={supplier.SupplierID}>{supplier.SupplierName}</option>
                  ))}
                </select>
                <input
                  type="number"
                  step="0.01"
                  placeholder="Cost per Unit"
                  value={newFoodForm.cost_per_unit}
                  onChange={(e) => setNewFoodForm({...newFoodForm, cost_per_unit: e.target.value})}
                />
                <input
                  type="number"
                  step="0.01"
                  placeholder="Selling Price"
                  value={newFoodForm.selling_price}
                  onChange={(e) => setNewFoodForm({...newFoodForm, selling_price: e.target.value})}
                />
                <input
                  type="number"
                  placeholder="Min Stock Level"
                  value={newFoodForm.min_stock}
                  onChange={(e) => setNewFoodForm({...newFoodForm, min_stock: e.target.value})}
                />
                <input
                  type="number"
                  placeholder="Max Stock Level"
                  value={newFoodForm.max_stock}
                  onChange={(e) => setNewFoodForm({...newFoodForm, max_stock: e.target.value})}
                />
              </div>
              <button 
                className="add-btn" 
                onClick={handleAddFood}
                disabled={loading}
              >
                {loading ? "Adding..." : "Add Food Item"}
              </button>
            </div>

            <div className="food-items-list">
              <h3>Current Food Items</h3>
              <table className="food-table">
                <thead>
                  <tr>
                    <th>Name</th>
                    <th>Category</th>
                    <th>Unit</th>
                    <th>Cost</th>
                    <th>Price</th>
                    <th>Supplier</th>
                  </tr>
                </thead>
                <tbody>
                  {foodItems.map(item => (
                    <tr key={item.FoodID}>
                      <td>{item.FoodName}</td>
                      <td>{item.CategoryName}</td>
                      <td>{item.UnitName}</td>
                      <td>₹{parseFloat(item.CostPerUnit || 0).toFixed(2)}</td>
                      <td>₹{parseFloat(item.SellingPricePerUnit || 0).toFixed(2)}</td>
                      <td>{item.SupplierName || 'N/A'}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )}

        {/* Production Page */}
        {activeDetail === "Production" && (
          <div>
            <div className="production-form">
              <h3>Add Production Data</h3>
              <div className="form-grid">
                <select
                  value={productionForm.food_id}
                  onChange={(e) => setProductionForm({...productionForm, food_id: e.target.value})}
                >
                  <option value="">Select Food Item *</option>
                  {foodItems.map(item => (
                    <option key={item.FoodID} value={item.FoodID}>
                      {item.FoodName} ({item.CategoryName})
                    </option>
                  ))}
                </select>
                <input
                  type="date"
                  value={productionForm.date}
                  onChange={(e) => setProductionForm({...productionForm, date: e.target.value})}
                />
                <input
                  type="number"
                  placeholder="Quantity Prepared *"
                  value={productionForm.quantity}
                  onChange={(e) => setProductionForm({...productionForm, quantity: e.target.value})}
                />
                <select
                  value={productionForm.staff_id}
                  onChange={(e) => setProductionForm({...productionForm, staff_id: e.target.value})}
                >
                  <option value="">Select Staff</option>
                  {staff.map(member => (
                    <option key={member.StaffID} value={member.StaffID}>
                      {member.StaffName} ({member.Position})
                    </option>
                  ))}
                </select>
                <input
                  type="time"
                  placeholder="Start Time"
                  value={productionForm.start_time}
                  onChange={(e) => setProductionForm({...productionForm, start_time: e.target.value})}
                />
                <input
                  type="time"
                  placeholder="End Time"
                  value={productionForm.end_time}
                  onChange={(e) => setProductionForm({...productionForm, end_time: e.target.value})}
                />
                <textarea
                  placeholder="Notes"
                  value={productionForm.notes}
                  onChange={(e) => setProductionForm({...productionForm, notes: e.target.value})}
                />
              </div>
              <button 
                className="add-btn" 
                onClick={handleAddProduction}
                disabled={loading}
              >
                {loading ? "Adding..." : "Add Production"}
              </button>
            </div>

            {/* Production Suggestions Table */}
            {productionSuggestions.length > 0 && (
              <div className="production-suggestions">
                <h3>Production Planning</h3>
                <table className="production-table">
                  <thead>
                    <tr>
                      <th>Food Item</th>
                      <th>Category</th>
                      <th>Last Production</th>
                      <th>Avg Weekly Sales</th>
                      <th className="suggestion-header">Next Day Suggestion</th>
                    </tr>
                  </thead>
                  <tbody>
                    {productionSuggestions.map(item => (
                      <tr key={item.FoodID}>
                        <td>{item.FoodName}</td>
                        <td>{item.CategoryName}</td>
                        <td>{item.LastProduction} {item.UnitSymbol}</td>
                        <td>{parseFloat(item.AvgWeeklySales).toFixed(1)} {item.UnitSymbol}</td>
                        <td className="suggestion-cell">
                          <strong>{item.NextDaySuggestion} {item.UnitSymbol}</strong>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        )}

        {/* Sales Page */}
        {activeDetail === "Sales" && (
          <div>
            <div className="sales-form">
              <h3>Add Sales Data</h3>
              <div className="form-grid">
                <select
                  value={salesForm.food_id}
                  onChange={(e) => setSalesForm({...salesForm, food_id: e.target.value})}
                >
                  <option value="">Select Food Item *</option>
                  {foodItems.map(item => (
                    <option key={item.FoodID} value={item.FoodID}>
                      {item.FoodName} ({item.CategoryName})
                    </option>
                  ))}
                </select>
                <input
                  type="date"
                  value={salesForm.date}
                  onChange={(e) => setSalesForm({...salesForm, date: e.target.value})}
                />
                <input
                  type="number"
                  placeholder="Quantity Sold *"
                  value={salesForm.quantity}
                  onChange={(e) => setSalesForm({...salesForm, quantity: e.target.value})}
                />
                <select
                  value={salesForm.staff_id}
                  onChange={(e) => setSalesForm({...salesForm, staff_id: e.target.value})}
                >
                  <option value="">Select Staff</option>
                  {staff.map(member => (
                    <option key={member.StaffID} value={member.StaffID}>
                      {member.StaffName} ({member.Position})
                    </option>
                  ))}
                </select>
                <textarea
                  placeholder="Notes"
                  value={salesForm.notes}
                  onChange={(e) => setSalesForm({...salesForm, notes: e.target.value})}
                />
              </div>
              <button 
                className="add-btn" 
                onClick={handleAddSales}
                disabled={loading}
              >
                {loading ? "Adding..." : "Add Sales"}
              </button>
            </div>
          </div>
        )}

        {/* Analytics Page */}
        {activeDetail === "Analytics" && (
          <div>
            {/* Wastage Analytics Section */}
            {wastageAnalytics && wastageAnalytics.chart_data && wastageAnalytics.chart_data.length > 0 && (
              <div className="wastage-section">
                <h3>Wastage Analysis - {wastageAnalytics.date}</h3>
                
                {/* Summary Cards */}
                <div className="wastage-summary">
                  <div className="wastage-card prepared">
                    <h4>Total Prepared</h4>
                    <p className="big-number">{wastageAnalytics.summary.total_prepared}</p>
                  </div>
                  <div className="wastage-card sold">
                    <h4>Total Sold</h4>
                    <p className="big-number">{wastageAnalytics.summary.total_sold}</p>
                  </div>
                  <div className="wastage-card wasted">
                    <h4>Total Wasted</h4>
                    <p className="big-number">{wastageAnalytics.summary.total_wasted}</p>
                  </div>
                  <div className="wastage-card percentage">
                    <h4>Wastage %</h4>
                    <p className="big-number">{wastageAnalytics.summary.wastage_percentage}%</p>
                  </div>
                </div>

                {/* Wastage Alerts */}
                {wastageAnalytics.alerts && wastageAnalytics.alerts.length > 0 && (
                  <div className="wastage-alerts">
                    {wastageAnalytics.alerts.map(alert => (
                      <div key={alert.AlertID} className={`wastage-alert alert-${alert.Severity}`}>
                        <span className="alert-icon">
                          {alert.Severity === 'critical' && '🔴'}
                          {alert.Severity === 'high' && '🟠'}
                          {alert.Severity === 'medium' && '🟡'}
                          {alert.Severity === 'low' && '🟢'}
                        </span>
                        <span className="alert-text">{alert.AlertMessage}</span>
                      </div>
                    ))}
                  </div>
                )}

                {/* Wastage Bar Chart */}
                <div className="chart-section wastage-chart">
                  <BarChart 
                    width={Math.min(wastageAnalytics.chart_data.length * 120, 1000)} 
                    height={400} 
                    data={wastageAnalytics.chart_data}
                  >
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="FoodName" />
                    <YAxis />
                    <Tooltip />
                    <Legend />
                    <Bar dataKey="Prepared" fill="#17a2b8" name="made" />
                    <Bar dataKey="Sold" fill="#85d8e8" name="sold" />
                    <Bar dataKey="Wasted" fill="#dc3545" name="wasted" />
                  </BarChart>
                </div>
              </div>
            )}

            {/* Original Charts */}
            <div className="charts-container">
              <div className="chart-section">
                <h3>Food Items Cost vs Price</h3>
                <BarChart width={600} height={300} data={chartData}>
                  <CartesianGrid strokeDasharray="3 3" />
                  <XAxis dataKey="name" />
                  <YAxis />
                  <Tooltip />
                  <Legend />
                  <Bar dataKey="cost" fill="#ff6b6b" name="Cost per Unit" />
                  <Bar dataKey="price" fill="#00b4d8" name="Selling Price" />
                </BarChart>
              </div>
              
              {alertChartData.length > 0 && (
                <div className="chart-section">
                  <h3>Alert Distribution</h3>
                  <PieChart width={400} height={300}>
                    <Pie
                      data={alertChartData}
                      cx={200}
                      cy={150}
                      innerRadius={60}
                      outerRadius={100}
                      paddingAngle={5}
                      dataKey="value"
                    >
                      {alertChartData.map((entry, index) => (
                        <Cell key={`cell-${index}`} fill={colors[index % colors.length]} />
                      ))}
                    </Pie>
                    <Tooltip />
                    <Legend />
                  </PieChart>
                </div>
              )}
            </div>
          </div>
        )}

        {/* Alerts Page */}
        {activeDetail === "Alerts" && (
          <div>
            <h3>All Alerts</h3>
            <div className="alerts-detailed">
              {alerts.length === 0 ? (
                <div className="no-alerts">✅ No active alerts</div>
              ) : (
                alerts.map(alert => (
                  <div key={alert.AlertID} className={`alert-card severity-${alert.Severity}`}>
                    <div className="alert-header">
                      <h4>{alert.FoodName} - {alert.CategoryName}</h4>
                      <span className={`severity-badge ${alert.Severity}`}>{alert.Severity.toUpperCase()}</span>
                    </div>
                    <p>{alert.AlertMessage}</p>
                    <div className="alert-meta">
                      <small>Type: {alert.AlertType.replace('_', ' ')}</small>
                      <small>Date: {new Date(alert.AlertDate).toLocaleDateString()}</small>
                      {alert.WastagePercentage && (
                        <small>Wastage: {alert.WastagePercentage}%</small>
                      )}
                    </div>
                    <button 
                      className="resolve-btn"
                      onClick={() => handleResolveAlert(alert.AlertID)}
                    >
                      Resolve Alert
                    </button>
                  </div>
                ))
              )}
            </div>
          </div>
        )}
      </div>
    );
  }

  return null;
}

export default App;