-- NORMALIZED SCHEMA - CANTEEN WASTAGE TRACKER (1NF, 2NF, 3NF COMPLIANT)

CREATE DATABASE IF NOT EXISTS canteen_db;
USE canteen_db;

-- LOOKUP TABLES FOR NORMALIZATION (3NF COMPLIANCE)

-- 1. CATEGORIES TABLE (3NF - Separate food categories)
CREATE TABLE IF NOT EXISTS Categories (
    CategoryID INT PRIMARY KEY AUTO_INCREMENT,
    CategoryName VARCHAR(50) NOT NULL UNIQUE,
    Description TEXT,
    CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. UNITS TABLE (3NF - Separate measurement units)
CREATE TABLE IF NOT EXISTS Units (
    UnitID INT PRIMARY KEY AUTO_INCREMENT,
    UnitName VARCHAR(20) NOT NULL UNIQUE,
    UnitSymbol VARCHAR(10),
    UnitType ENUM('volume', 'weight', 'count') DEFAULT 'count',
    CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 3. SUPPLIERS TABLE (3NF - Separate supplier information)
CREATE TABLE IF NOT EXISTS Suppliers (
    SupplierID INT PRIMARY KEY AUTO_INCREMENT,
    SupplierName VARCHAR(100) NOT NULL,
    ContactPerson VARCHAR(50),
    Phone VARCHAR(15),
    Email VARCHAR(100),
    Address TEXT,
    IsActive BOOLEAN DEFAULT TRUE,
    CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 4. STAFF TABLE (3NF - Separate staff information for audit)
CREATE TABLE IF NOT EXISTS Staff (
    StaffID INT PRIMARY KEY AUTO_INCREMENT,
    StaffName VARCHAR(50) NOT NULL,
    Position VARCHAR(30),
    Department ENUM('kitchen', 'service', 'management', 'admin') DEFAULT 'kitchen',
    Email VARCHAR(100),
    IsActive BOOLEAN DEFAULT TRUE,
    CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- MAIN TABLES (NORMALIZED)

-- 5. FOOD ITEM TABLE (Enhanced with normalization)
CREATE TABLE IF NOT EXISTS FoodItem (
    FoodID INT PRIMARY KEY AUTO_INCREMENT,
    FoodName VARCHAR(50) NOT NULL,
    CategoryID INT NOT NULL,
    UnitID INT NOT NULL,
    SupplierID INT,
    CostPerUnit DECIMAL(10,2) DEFAULT 0.00,
    SellingPricePerUnit DECIMAL(10,2) DEFAULT 0.00,
    MinStockLevel INT DEFAULT 0,
    MaxStockLevel INT DEFAULT 1000,
    IsActive BOOLEAN DEFAULT TRUE,
    CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (CategoryID) REFERENCES Categories(CategoryID),
    FOREIGN KEY (UnitID) REFERENCES Units(UnitID),
    FOREIGN KEY (SupplierID) REFERENCES Suppliers(SupplierID),
    UNIQUE KEY unique_food_category (FoodName, CategoryID)
);

-- 6. DAILY PRODUCTION TABLE (Enhanced)
CREATE TABLE IF NOT EXISTS DailyProduction (
    ProductionID INT PRIMARY KEY AUTO_INCREMENT,
    FoodID INT NOT NULL,
    ProductionDate DATE NOT NULL,
    QuantityPrepared INT CHECK (QuantityPrepared >= 0),
    StaffID INT,
    ProductionCost DECIMAL(10,2) DEFAULT 0.00,
    StartTime TIME,
    EndTime TIME,
    Notes TEXT,
    CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (FoodID) REFERENCES FoodItem(FoodID) ON DELETE CASCADE,
    FOREIGN KEY (StaffID) REFERENCES Staff(StaffID),
    UNIQUE KEY unique_production (FoodID, ProductionDate)
);

-- 7. DAILY SALES TABLE (Enhanced)
CREATE TABLE IF NOT EXISTS DailySales (
    SaleID INT PRIMARY KEY AUTO_INCREMENT,
    FoodID INT NOT NULL,
    SaleDate DATE NOT NULL,
    QuantitySold INT CHECK (QuantitySold >= 0),
    SalePrice DECIMAL(10,2) DEFAULT 0.00,
    StaffID INT,
    Revenue DECIMAL(10,2) GENERATED ALWAYS AS (QuantitySold * SalePrice) STORED,
    Notes TEXT,
    CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (FoodID) REFERENCES FoodItem(FoodID) ON DELETE CASCADE,
    FOREIGN KEY (StaffID) REFERENCES Staff(StaffID),
    UNIQUE KEY unique_sale (FoodID, SaleDate)
);

-- 8. DAILY WASTAGE TABLE (Enhanced)
CREATE TABLE IF NOT EXISTS DailyWastage (
    WastageID INT PRIMARY KEY AUTO_INCREMENT,
    FoodID INT NOT NULL,
    WastageDate DATE NOT NULL,
    QuantityWasted INT CHECK (QuantityWasted >= 0),
    WastageReason ENUM('expired', 'overproduction', 'quality_issue', 'customer_return', 'other') DEFAULT 'overproduction',
    WasteValue DECIMAL(10,2) DEFAULT 0.00,
    StaffID INT,
    Notes TEXT,
    CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (FoodID) REFERENCES FoodItem(FoodID) ON DELETE CASCADE,
    FOREIGN KEY (StaffID) REFERENCES Staff(StaffID),
    UNIQUE KEY unique_wastage (FoodID, WastageDate)
);

-- 9. WASTAGE ALERT TABLE (Enhanced)
CREATE TABLE IF NOT EXISTS WastageAlert (
    AlertID INT PRIMARY KEY AUTO_INCREMENT,
    FoodID INT NOT NULL,
    AlertDate DATE NOT NULL,
    WastagePercentage DECIMAL(5,2),
    AlertType ENUM('high_wastage', 'low_stock', 'expiry_warning', 'cost_alert') DEFAULT 'high_wastage',
    AlertMessage VARCHAR(200),
    Severity ENUM('low', 'medium', 'high', 'critical') DEFAULT 'medium',
    IsResolved BOOLEAN DEFAULT FALSE,
    ResolvedBy INT,
    ResolvedAt TIMESTAMP NULL,
    ResolutionNotes TEXT,
    CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (FoodID) REFERENCES FoodItem(FoodID) ON DELETE CASCADE,
    FOREIGN KEY (ResolvedBy) REFERENCES Staff(StaffID)
);

-- 10. AUDIT LOG TABLE (Complete audit trail)
CREATE TABLE IF NOT EXISTS AuditLog (
    LogID INT PRIMARY KEY AUTO_INCREMENT,
    TableName VARCHAR(50) NOT NULL,
    RecordID INT NOT NULL,
    Operation ENUM('INSERT', 'UPDATE', 'DELETE') NOT NULL,
    StaffID INT,
    OldValues JSON,
    NewValues JSON,
    ChangedFields TEXT,
    IPAddress VARCHAR(45),
    UserAgent TEXT,
    CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (StaffID) REFERENCES Staff(StaffID),
    INDEX idx_table_record (TableName, RecordID),
    INDEX idx_operation_date (Operation, CreatedAt)
);

-- INSERT DEFAULT DATA FOR LOOKUP TABLES

-- Default Categories
INSERT IGNORE INTO Categories (CategoryName, Description) VALUES
('Main Course', 'Primary dishes like rice, curry, dal'),
('Side Dish', 'Accompaniments and secondary items'),
('Dessert', 'Sweet items and desserts'),
('Beverage', 'Drinks and liquid refreshments'),
('Snack', 'Light snacks and finger foods'),
('Bread', 'Roti, naan and other bread items');

-- Default Units
INSERT IGNORE INTO Units (UnitName, UnitSymbol, UnitType) VALUES
('Plates', 'pcs', 'count'),
('Liters', 'L', 'volume'),
('Kilograms', 'kg', 'weight'),
('Pieces', 'pcs', 'count'),
('Bowls', 'bowls', 'count'),
('Cups', 'cups', 'volume'),
('Servings', 'servings', 'count');

-- Default Suppliers
INSERT IGNORE INTO Suppliers (SupplierName, ContactPerson, Phone, Email, Address) VALUES
('Local Vegetable Market', 'Ravi Kumar', '9876543210', 'ravi@localmarket.com', 'Main Market Street'),
('Grain Wholesale', 'Sunita Devi', '9876543211', 'sunita@grainwholesale.com', 'Wholesale Market Area'),
('Dairy Products Co.', 'Mohan Lal', '9876543212', 'mohan@dairy.com', 'Industrial Area');

-- Default Staff
INSERT IGNORE INTO Staff (StaffName, Position, Department, Email) VALUES
('Admin User', 'Administrator', 'admin', 'admin@canteen.com'),
('Head Chef', 'Chef', 'kitchen', 'chef@canteen.com'),
('Kitchen Helper', 'Assistant', 'kitchen', 'helper@canteen.com'),
('Service Staff', 'Server', 'service', 'service@canteen.com');

-- STORED PROCEDURES (Updated for normalized schema)

-- PROCEDURE: Add Production (Updated)
DELIMITER //
CREATE PROCEDURE AddProductionData(
    IN p_food_id INT, 
    IN p_production_date DATE, 
    IN p_quantity_prepared INT,
    IN p_staff_id INT DEFAULT 1,
    IN p_start_time TIME DEFAULT NULL,
    IN p_end_time TIME DEFAULT NULL,
    IN p_notes TEXT DEFAULT NULL
)
BEGIN
    DECLARE v_cost_per_unit DECIMAL(10,2) DEFAULT 0.00;
    DECLARE v_production_cost DECIMAL(10,2) DEFAULT 0.00;
    
    -- Get cost per unit from FoodItem
    SELECT CostPerUnit INTO v_cost_per_unit FROM FoodItem WHERE FoodID = p_food_id;
    SET v_production_cost = v_cost_per_unit * p_quantity_prepared;
    
    INSERT INTO DailyProduction (
        FoodID, ProductionDate, QuantityPrepared, StaffID, 
        ProductionCost, StartTime, EndTime, Notes
    ) VALUES (
        p_food_id, p_production_date, p_quantity_prepared, p_staff_id,
        v_production_cost, p_start_time, p_end_time, p_notes
    )
    ON DUPLICATE KEY UPDATE 
        QuantityPrepared = p_quantity_prepared,
        ProductionCost = v_production_cost,
        StaffID = p_staff_id,
        StartTime = COALESCE(p_start_time, StartTime),
        EndTime = COALESCE(p_end_time, EndTime),
        Notes = COALESCE(p_notes, Notes),
        UpdatedAt = CURRENT_TIMESTAMP;
        
    CALL CalculateWastage(p_food_id, p_production_date);
END//
DELIMITER ;

-- PROCEDURE: Add Sales (Updated)
DELIMITER //
CREATE PROCEDURE AddSalesData(
    IN p_food_id INT, 
    IN p_sale_date DATE, 
    IN p_quantity_sold INT,
    IN p_staff_id INT DEFAULT 1,
    IN p_notes TEXT DEFAULT NULL
)
BEGIN
    DECLARE v_sale_price DECIMAL(10,2) DEFAULT 0.00;
    
    -- Get selling price from FoodItem
    SELECT SellingPricePerUnit INTO v_sale_price FROM FoodItem WHERE FoodID = p_food_id;
    
    INSERT INTO DailySales (
        FoodID, SaleDate, QuantitySold, SalePrice, StaffID, Notes
    ) VALUES (
        p_food_id, p_sale_date, p_quantity_sold, v_sale_price, p_staff_id, p_notes
    )
    ON DUPLICATE KEY UPDATE 
        QuantitySold = p_quantity_sold,
        SalePrice = v_sale_price,
        StaffID = p_staff_id,
        Notes = COALESCE(p_notes, Notes),
        UpdatedAt = CURRENT_TIMESTAMP;
        
    CALL CalculateWastage(p_food_id, p_sale_date);
END//
DELIMITER ;

-- Helper procedure: Calculate wastage (Updated)
DELIMITER //
CREATE PROCEDURE CalculateWastage(IN p_food_id INT, IN p_date DATE)
BEGIN
    DECLARE v_prepared INT DEFAULT 0;
    DECLARE v_sold INT DEFAULT 0;
    DECLARE v_wasted INT DEFAULT 0;
    DECLARE v_percent DECIMAL(5,2) DEFAULT 0.00;
    DECLARE v_cost_per_unit DECIMAL(10,2) DEFAULT 0.00;
    DECLARE v_waste_value DECIMAL(10,2) DEFAULT 0.00;

    SELECT QuantityPrepared INTO v_prepared 
    FROM DailyProduction WHERE FoodID=p_food_id AND ProductionDate=p_date;
    
    SELECT QuantitySold INTO v_sold 
    FROM DailySales WHERE FoodID=p_food_id AND SaleDate=p_date;
    
    SELECT CostPerUnit INTO v_cost_per_unit 
    FROM FoodItem WHERE FoodID=p_food_id;

    SET v_wasted = IFNULL(v_prepared,0) - IFNULL(v_sold,0);
    SET v_percent = CASE WHEN IFNULL(v_prepared,0) > 0 THEN (v_wasted/v_prepared*100) ELSE 0 END;
    SET v_waste_value = v_wasted * IFNULL(v_cost_per_unit,0);

    IF v_wasted > 0 THEN
        INSERT INTO DailyWastage (FoodID, WastageDate, QuantityWasted, WasteValue, WastageReason)
        VALUES (p_food_id, p_date, v_wasted, v_waste_value, 'overproduction')
        ON DUPLICATE KEY UPDATE 
            QuantityWasted = v_wasted,
            WasteValue = v_waste_value;
    END IF;

    IF v_percent > 30 THEN
        INSERT INTO WastageAlert(FoodID, AlertDate, WastagePercentage, AlertType, AlertMessage, Severity)
        VALUES (p_food_id, p_date, v_percent, 'high_wastage', 
               CONCAT('High wastage: ', ROUND(v_percent,2), '% (', v_wasted, ' units)'), 
               CASE WHEN v_percent > 50 THEN 'critical' 
                    WHEN v_percent > 40 THEN 'high' 
                    ELSE 'medium' END);
    END IF;
END//
DELIMITER ;

-- FUNCTION: Next day production suggestion (Updated)
DELIMITER //
CREATE FUNCTION GetProductionSuggestion(p_food_id INT)
RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE avg_sales DECIMAL(10,2) DEFAULT 0;
    DECLARE safety_stock_pct DECIMAL(5,2) DEFAULT 10; -- 10% safety stock
    DECLARE suggested_qty INT DEFAULT 0;
    
    SELECT AVG(QuantitySold) INTO avg_sales 
    FROM DailySales
    WHERE FoodID=p_food_id AND SaleDate >= DATE_SUB(CURDATE(), INTERVAL 7 DAY);
    
    SET suggested_qty = CEIL(IFNULL(avg_sales,0) * (1 + safety_stock_pct/100));
    
    RETURN GREATEST(suggested_qty, 0);
END//
DELIMITER ;

-- Enhanced Weekly Summary with Categories and Financial Data
DELIMITER //
CREATE PROCEDURE GenerateWeeklySummaryReport(IN p_start_date DATE)
BEGIN
    DECLARE done INT DEFAULT 0;
    DECLARE food INT;
    DECLARE fname VARCHAR(50);
    DECLARE cat_name VARCHAR(50);
    DECLARE prepared INT;
    DECLARE sold INT;
    DECLARE wasted INT;
    DECLARE revenue DECIMAL(10,2);
    DECLARE waste_value DECIMAL(10,2);

    DECLARE food_cursor CURSOR FOR 
        SELECT f.FoodID, f.FoodName, c.CategoryName
        FROM FoodItem f 
        JOIN Categories c ON f.CategoryID = c.CategoryID
        WHERE f.IsActive = TRUE;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

    DROP TEMPORARY TABLE IF EXISTS WeeklySummary;
    CREATE TEMPORARY TABLE WeeklySummary(
        Food VARCHAR(50), 
        Category VARCHAR(50),
        Prepared INT, 
        Sold INT, 
        Wasted INT,
        Revenue DECIMAL(10,2),
        WasteValue DECIMAL(10,2),
        WastagePercentage DECIMAL(5,2)
    );

    OPEN food_cursor;
    summary_loop: LOOP
        FETCH food_cursor INTO food, fname, cat_name;
        IF done THEN LEAVE summary_loop; END IF;
        
        SELECT 
            IFNULL(SUM(QuantityPrepared),0),
            IFNULL(SUM(Revenue),0)
        INTO prepared, revenue
        FROM DailyProduction dp
        LEFT JOIN DailySales ds ON dp.FoodID = ds.FoodID AND dp.ProductionDate = ds.SaleDate
        WHERE dp.FoodID=food AND dp.ProductionDate BETWEEN p_start_date AND DATE_ADD(p_start_date, INTERVAL 6 DAY);
        
        SELECT IFNULL(SUM(QuantitySold),0) INTO sold 
        FROM DailySales 
        WHERE FoodID=food AND SaleDate BETWEEN p_start_date AND DATE_ADD(p_start_date, INTERVAL 6 DAY);
        
        SELECT IFNULL(SUM(QuantityWasted),0), IFNULL(SUM(WasteValue),0) INTO wasted, waste_value
        FROM DailyWastage 
        WHERE FoodID=food AND WastageDate BETWEEN p_start_date AND DATE_ADD(p_start_date, INTERVAL 6 DAY);

        INSERT INTO WeeklySummary VALUES(
            fname, cat_name, prepared, sold, wasted, revenue, waste_value,
            CASE WHEN prepared > 0 THEN ROUND((wasted/prepared)*100,2) ELSE 0 END
        );
    END LOOP;
    CLOSE food_cursor;

    SELECT * FROM WeeklySummary ORDER BY Category, Food;
END//
DELIMITER ;

-- =====================================
-- COMPREHENSIVE TRIGGER SYSTEM (5 NEW TRIGGERS)
-- =====================================

-- TRIGGER 1: AUDIT TRAIL TRIGGER (Tracks all data changes)
DELIMITER //

-- Audit trigger for FoodItem table
CREATE TRIGGER tr_fooditem_audit_insert AFTER INSERT ON FoodItem FOR EACH ROW
BEGIN
    INSERT INTO AuditLog (TableName, RecordID, Operation, NewValues, ChangedFields)
    VALUES ('FoodItem', NEW.FoodID, 'INSERT', 
            JSON_OBJECT(
                'FoodID', NEW.FoodID,
                'FoodName', NEW.FoodName,
                'CategoryID', NEW.CategoryID,
                'UnitID', NEW.UnitID,
                'CostPerUnit', NEW.CostPerUnit
            ),
            'FoodID,FoodName,CategoryID,UnitID,CostPerUnit');
END//

CREATE TRIGGER tr_fooditem_audit_update AFTER UPDATE ON FoodItem FOR EACH ROW
BEGIN
    INSERT INTO AuditLog (TableName, RecordID, Operation, OldValues, NewValues, ChangedFields)
    VALUES ('FoodItem', NEW.FoodID, 'UPDATE',
            JSON_OBJECT(
                'FoodName', OLD.FoodName,
                'CategoryID', OLD.CategoryID,
                'CostPerUnit', OLD.CostPerUnit,
                'IsActive', OLD.IsActive
            ),
            JSON_OBJECT(
                'FoodName', NEW.FoodName,
                'CategoryID', NEW.CategoryID,
                'CostPerUnit', NEW.CostPerUnit,
                'IsActive', NEW.IsActive
            ),
            CONCAT_WS(',',
                IF(OLD.FoodName != NEW.FoodName, 'FoodName', NULL),
                IF(OLD.CategoryID != NEW.CategoryID, 'CategoryID', NULL),
                IF(OLD.CostPerUnit != NEW.CostPerUnit, 'CostPerUnit', NULL),
                IF(OLD.IsActive != NEW.IsActive, 'IsActive', NULL)
            ));
END//

-- Audit trigger for DailyProduction
CREATE TRIGGER tr_production_audit_insert AFTER INSERT ON DailyProduction FOR EACH ROW
BEGIN
    INSERT INTO AuditLog (TableName, RecordID, Operation, StaffID, NewValues)
    VALUES ('DailyProduction', NEW.ProductionID, 'INSERT', NEW.StaffID,
            JSON_OBJECT(
                'FoodID', NEW.FoodID,
                'ProductionDate', NEW.ProductionDate,
                'QuantityPrepared', NEW.QuantityPrepared,
                'ProductionCost', NEW.ProductionCost
            ));
END//

CREATE TRIGGER tr_production_audit_update AFTER UPDATE ON DailyProduction FOR EACH ROW
BEGIN
    INSERT INTO AuditLog (TableName, RecordID, Operation, StaffID, OldValues, NewValues)
    VALUES ('DailyProduction', NEW.ProductionID, 'UPDATE', NEW.StaffID,
            JSON_OBJECT('QuantityPrepared', OLD.QuantityPrepared, 'ProductionCost', OLD.ProductionCost),
            JSON_OBJECT('QuantityPrepared', NEW.QuantityPrepared, 'ProductionCost', NEW.ProductionCost));
END//

-- TRIGGER 2: BUSINESS VALIDATION TRIGGER 
CREATE TRIGGER tr_sales_validation BEFORE INSERT ON DailySales FOR EACH ROW
BEGIN
    DECLARE v_prepared INT DEFAULT 0;
    DECLARE v_max_stock INT DEFAULT 1000;
    
   
    SELECT QuantityPrepared INTO v_prepared 
    FROM DailyProduction 
    WHERE FoodID = NEW.FoodID AND ProductionDate = NEW.SaleDate;
    
    -- Get max stock level
    SELECT MaxStockLevel INTO v_max_stock 
    FROM FoodItem 
    WHERE FoodID = NEW.FoodID;
    
    -- Validate: Sales cannot exceed production
    IF NEW.QuantitySold > IFNULL(v_prepared, 0) THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Error: Sales quantity cannot exceed production quantity';
    END IF;
    
    -- Validate: Quantity should be reasonable
    IF NEW.QuantitySold > v_max_stock THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Error: Sales quantity exceeds maximum stock level';
    END IF;
    
    -- Validate: No negative quantities
    IF NEW.QuantitySold < 0 THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Error: Sales quantity cannot be negative';
    END IF;
END//

CREATE TRIGGER tr_production_validation BEFORE INSERT ON DailyProduction FOR EACH ROW
BEGIN
    DECLARE v_max_stock INT DEFAULT 1000;
    
    SELECT MaxStockLevel INTO v_max_stock 
    FROM FoodItem 
    WHERE FoodID = NEW.FoodID;
    
    -- Validate: Production quantity should be reasonable
    IF NEW.QuantityPrepared > v_max_stock THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Error: Production quantity exceeds maximum stock level';
    END IF;
    
    -- Auto-calculate production cost if not provided
    IF NEW.ProductionCost IS NULL OR NEW.ProductionCost = 0 THEN
        SELECT NEW.QuantityPrepared * IFNULL(CostPerUnit, 0) INTO NEW.ProductionCost
        FROM FoodItem WHERE FoodID = NEW.FoodID;
    END IF;
END//

-- TRIGGER 3: ALERT CLEANUP TRIGGER (Manages alert lifecycle)
CREATE TRIGGER tr_alert_cleanup AFTER INSERT ON WastageAlert FOR EACH ROW
BEGIN
    -- Auto-resolve old alerts of same type for same food
    UPDATE WastageAlert 
    SET IsResolved = TRUE, 
        ResolvedAt = CURRENT_TIMESTAMP,
        ResolutionNotes = 'Auto-resolved: New alert created'
    WHERE FoodID = NEW.FoodID 
      AND AlertType = NEW.AlertType 
      AND AlertID != NEW.AlertID 
      AND IsResolved = FALSE
      AND AlertDate < NEW.AlertDate;
      
    -- Delete very old resolved alerts (older than 90 days)
    DELETE FROM WastageAlert 
    WHERE IsResolved = TRUE 
      AND ResolvedAt < DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 90 DAY);
END//

-- TRIGGER 4: STOCK LEVEL MONITORING TRIGGER
CREATE TRIGGER tr_stock_monitor AFTER UPDATE ON DailySales FOR EACH ROW
BEGIN
    DECLARE v_current_stock INT DEFAULT 0;
    DECLARE v_min_stock INT DEFAULT 0;
    DECLARE v_food_name VARCHAR(50);
    
    -- Calculate current available stock (production - sales)
    SELECT 
        IFNULL(SUM(dp.QuantityPrepared), 0) - IFNULL(SUM(ds.QuantitySold), 0),
        f.MinStockLevel,
        f.FoodName
    INTO v_current_stock, v_min_stock, v_food_name
    FROM FoodItem f
    LEFT JOIN DailyProduction dp ON f.FoodID = dp.FoodID AND dp.ProductionDate >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
    LEFT JOIN DailySales ds ON f.FoodID = ds.FoodID AND ds.SaleDate >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
    WHERE f.FoodID = NEW.FoodID
    GROUP BY f.FoodID, f.MinStockLevel, f.FoodName;
    
    -- Create low stock alert if needed
    IF v_current_stock <= v_min_stock AND v_min_stock > 0 THEN
        INSERT IGNORE INTO WastageAlert (
            FoodID, AlertDate, AlertType, AlertMessage, Severity
        ) VALUES (
            NEW.FoodID, 
            CURDATE(), 
            'low_stock',
            CONCAT('Low stock alert: ', v_food_name, ' - Current: ', v_current_stock, ', Minimum: ', v_min_stock),
            'high'
        );
    END IF;
END//

-- TRIGGER 5: COST CALCULATION TRIGGER (Auto-calculates costs and prices)
CREATE TRIGGER tr_cost_calculation BEFORE UPDATE ON FoodItem FOR EACH ROW
BEGIN
    -- Auto-calculate selling price if cost per unit is updated
    IF OLD.CostPerUnit != NEW.CostPerUnit AND NEW.CostPerUnit > 0 THEN
        -- Apply 30% markup if selling price is not manually set
        IF NEW.SellingPricePerUnit = OLD.SellingPricePerUnit THEN
            SET NEW.SellingPricePerUnit = NEW.CostPerUnit * 1.30;
        END IF;
    END IF;
    
    -- Update timestamp
    SET NEW.UpdatedAt = CURRENT_TIMESTAMP;
END//

CREATE TRIGGER tr_cost_update_production AFTER UPDATE ON FoodItem FOR EACH ROW
BEGIN
    -- Update production costs for recent productions when cost changes
    IF OLD.CostPerUnit != NEW.CostPerUnit THEN
        UPDATE DailyProduction 
        SET ProductionCost = QuantityPrepared * NEW.CostPerUnit,
            UpdatedAt = CURRENT_TIMESTAMP
        WHERE FoodID = NEW.FoodID 
          AND ProductionDate >= DATE_SUB(CURDATE(), INTERVAL 30 DAY);
    END IF;
END//

-- Original wastage calculation triggers (Enhanced)
CREATE TRIGGER tr_prod_insert AFTER INSERT ON DailyProduction FOR EACH ROW
BEGIN
    CALL CalculateWastage(NEW.FoodID, NEW.ProductionDate);
END//

CREATE TRIGGER tr_sales_insert AFTER INSERT ON DailySales FOR EACH ROW
BEGIN
    CALL CalculateWastage(NEW.FoodID, NEW.SaleDate);
END//

CREATE TRIGGER tr_prod_update AFTER UPDATE ON DailyProduction FOR EACH ROW
BEGIN
    CALL CalculateWastage(NEW.FoodID, NEW.ProductionDate);
END//

CREATE TRIGGER tr_sales_update AFTER UPDATE ON DailySales FOR EACH ROW
BEGIN
    CALL CalculateWastage(NEW.FoodID, NEW.SaleDate);
END//

DELIMITER ;
