-- STORED PROCEDURES AND FUNCTIONS

USE canteen_db;

-- Drop existing procedures and functions
DROP PROCEDURE IF EXISTS AddProductionData;
DROP PROCEDURE IF EXISTS AddSalesData;
DROP PROCEDURE IF EXISTS CalculateWastage;
DROP FUNCTION IF EXISTS GetProductionSuggestion;
DROP PROCEDURE IF EXISTS GenerateWeeklySummaryReport;

-- PROCEDURE: Add Production (Updated - All parameters required, defaults handled in body)
DELIMITER $$
CREATE PROCEDURE AddProductionData(
    IN p_food_id INT, 
    IN p_production_date DATE, 
    IN p_quantity_prepared INT,
    IN p_staff_id INT,
    IN p_start_time TIME,
    IN p_end_time TIME,
    IN p_notes TEXT
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
        p_food_id, p_production_date, p_quantity_prepared, IFNULL(p_staff_id, 1),
        v_production_cost, p_start_time, p_end_time, p_notes
    )
    ON DUPLICATE KEY UPDATE 
        QuantityPrepared = p_quantity_prepared,
        ProductionCost = v_production_cost,
        StaffID = IFNULL(p_staff_id, StaffID),
        StartTime = COALESCE(p_start_time, StartTime),
        EndTime = COALESCE(p_end_time, EndTime),
        Notes = COALESCE(p_notes, Notes),
        UpdatedAt = CURRENT_TIMESTAMP;
        
    CALL CalculateWastage(p_food_id, p_production_date);
END$$
DELIMITER ;

-- PROCEDURE: Add Sales (Updated - All parameters required, defaults handled in body)
DELIMITER $$
CREATE PROCEDURE AddSalesData(
    IN p_food_id INT, 
    IN p_sale_date DATE, 
    IN p_quantity_sold INT,
    IN p_staff_id INT,
    IN p_notes TEXT
)
BEGIN
    DECLARE v_sale_price DECIMAL(10,2) DEFAULT 0.00;
    
    -- Get selling price from FoodItem
    SELECT SellingPricePerUnit INTO v_sale_price FROM FoodItem WHERE FoodID = p_food_id;
    
    INSERT INTO DailySales (
        FoodID, SaleDate, QuantitySold, SalePrice, StaffID, Notes
    ) VALUES (
        p_food_id, p_sale_date, p_quantity_sold, v_sale_price, IFNULL(p_staff_id, 1), p_notes
    )
    ON DUPLICATE KEY UPDATE 
        QuantitySold = p_quantity_sold,
        SalePrice = v_sale_price,
        StaffID = IFNULL(p_staff_id, StaffID),
        Notes = COALESCE(p_notes, Notes),
        UpdatedAt = CURRENT_TIMESTAMP;
        
    CALL CalculateWastage(p_food_id, p_sale_date);
END$$
DELIMITER ;

-- Helper procedure: Calculate wastage (Updated)
DELIMITER $$
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
                    ELSE 'medium' END)
        ON DUPLICATE KEY UPDATE
            WastagePercentage = v_percent,
            AlertMessage = CONCAT('High wastage: ', ROUND(v_percent,2), '% (', v_wasted, ' units)'),
            Severity = CASE WHEN v_percent > 50 THEN 'critical' 
                           WHEN v_percent > 40 THEN 'high' 
                           ELSE 'medium' END;
    END IF;
END$$
DELIMITER ;

-- FUNCTION: Next day production suggestion (Updated)
DELIMITER $$
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
END$$
DELIMITER ;

-- Enhanced Weekly Summary with Categories and Financial Data
DELIMITER $$
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
END$$
DELIMITER ;