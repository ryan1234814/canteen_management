-- COMPREHENSIVE TRIGGER SYSTEM (5 NEW TRIGGERS)

USE canteen_db;

-- Drop existing triggers
DROP TRIGGER IF EXISTS tr_fooditem_audit_insert;
DROP TRIGGER IF EXISTS tr_fooditem_audit_update;
DROP TRIGGER IF EXISTS tr_production_audit_insert;
DROP TRIGGER IF EXISTS tr_production_audit_update;
DROP TRIGGER IF EXISTS tr_sales_validation;
DROP TRIGGER IF EXISTS tr_production_validation;
DROP TRIGGER IF EXISTS tr_alert_cleanup;
DROP TRIGGER IF EXISTS tr_stock_monitor;
DROP TRIGGER IF EXISTS tr_cost_calculation;
DROP TRIGGER IF EXISTS tr_cost_update_production;
DROP TRIGGER IF EXISTS tr_prod_insert;
DROP TRIGGER IF EXISTS tr_sales_insert;
DROP TRIGGER IF EXISTS tr_prod_update;
DROP TRIGGER IF EXISTS tr_sales_update;

-- TRIGGER 1: AUDIT TRAIL TRIGGER (Tracks all data changes)

-- Audit trigger for FoodItem table
DELIMITER $$
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
END$$
DELIMITER ;

DELIMITER $$
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
END$$
DELIMITER ;

-- Audit trigger for DailyProduction
DELIMITER $$
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
END$$
DELIMITER ;

DELIMITER $$
CREATE TRIGGER tr_production_audit_update AFTER UPDATE ON DailyProduction FOR EACH ROW
BEGIN
    INSERT INTO AuditLog (TableName, RecordID, Operation, StaffID, OldValues, NewValues)
    VALUES ('DailyProduction', NEW.ProductionID, 'UPDATE', NEW.StaffID,
            JSON_OBJECT('QuantityPrepared', OLD.QuantityPrepared, 'ProductionCost', OLD.ProductionCost),
            JSON_OBJECT('QuantityPrepared', NEW.QuantityPrepared, 'ProductionCost', NEW.ProductionCost));
END$$
DELIMITER ;

-- TRIGGER 2: BUSINESS VALIDATION TRIGGER (Enforces business rules)
DELIMITER $$
CREATE TRIGGER tr_sales_validation BEFORE INSERT ON DailySales FOR EACH ROW
BEGIN
    DECLARE v_prepared INT DEFAULT 0;
    DECLARE v_max_stock INT DEFAULT 1000;
    
    -- Check if production exists for the date
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
END$$
DELIMITER ;

DELIMITER $$
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
END$$
DELIMITER ;

-- TRIGGER 3: ALERT CLEANUP TRIGGER (Manages alert lifecycle)
DELIMITER $$
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
END$$
DELIMITER ;

-- TRIGGER 4: STOCK LEVEL MONITORING TRIGGER
DELIMITER $$
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
        INSERT INTO WastageAlert (
            FoodID, AlertDate, AlertType, AlertMessage, Severity
        ) VALUES (
            NEW.FoodID, 
            CURDATE(), 
            'low_stock',
            CONCAT('Low stock alert: ', v_food_name, ' - Current: ', v_current_stock, ', Minimum: ', v_min_stock),
            'high'
        )
        ON DUPLICATE KEY UPDATE
            AlertMessage = CONCAT('Low stock alert: ', v_food_name, ' - Current: ', v_current_stock, ', Minimum: ', v_min_stock),
            Severity = 'high';
    END IF;
END$$
DELIMITER ;

-- TRIGGER 5: COST CALCULATION TRIGGER (Auto-calculates costs and prices)
DELIMITER $$
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
END$$
DELIMITER ;

DELIMITER $$
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
END$$
DELIMITER ;

-- Original wastage calculation triggers (Enhanced)
DELIMITER $$
CREATE TRIGGER tr_prod_insert AFTER INSERT ON DailyProduction FOR EACH ROW
BEGIN
    CALL CalculateWastage(NEW.FoodID, NEW.ProductionDate);
END$$
DELIMITER ;

DELIMITER $$
CREATE TRIGGER tr_sales_insert AFTER INSERT ON DailySales FOR EACH ROW
BEGIN
    CALL CalculateWastage(NEW.FoodID, NEW.SaleDate);
END$$
DELIMITER ;

DELIMITER $$
CREATE TRIGGER tr_prod_update AFTER UPDATE ON DailyProduction FOR EACH ROW
BEGIN
    CALL CalculateWastage(NEW.FoodID, NEW.ProductionDate);
END$$
DELIMITER ;

DELIMITER $$
CREATE TRIGGER tr_sales_update AFTER UPDATE ON DailySales FOR EACH ROW
BEGIN
    CALL CalculateWastage(NEW.FoodID, NEW.SaleDate);
END$$
DELIMITER ;