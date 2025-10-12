-- NORMALIZED SCHEMA - CANTEEN WASTAGE TRACKER (1NF, 2NF, 3NF COMPLIANT)

CREATE DATABASE IF NOT EXISTS canteen_db;
USE canteen_db;

-- Drop existing tables if they exist (for clean migration)
DROP TABLE IF EXISTS AuditLog;
DROP TABLE IF EXISTS WastageAlert;
DROP TABLE IF EXISTS DailyWastage;
DROP TABLE IF EXISTS DailySales;
DROP TABLE IF EXISTS DailyProduction;
DROP TABLE IF EXISTS FoodItem;
DROP TABLE IF EXISTS Staff;
DROP TABLE IF EXISTS Suppliers;
DROP TABLE IF EXISTS Units;
DROP TABLE IF EXISTS Categories;

-- LOOKUP TABLES FOR NORMALIZATION (3NF COMPLIANCE)

-- 1. CATEGORIES TABLE (3NF - Separate food categories)
CREATE TABLE Categories (
    CategoryID INT PRIMARY KEY AUTO_INCREMENT,
    CategoryName VARCHAR(50) NOT NULL UNIQUE,
    Description TEXT,
    CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. UNITS TABLE (3NF - Separate measurement units)
CREATE TABLE Units (
    UnitID INT PRIMARY KEY AUTO_INCREMENT,
    UnitName VARCHAR(20) NOT NULL UNIQUE,
    UnitSymbol VARCHAR(10),
    UnitType ENUM('volume', 'weight', 'count') DEFAULT 'count',
    CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 3. SUPPLIERS TABLE (3NF - Separate supplier information)
CREATE TABLE Suppliers (
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
CREATE TABLE Staff (
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
CREATE TABLE FoodItem (
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
CREATE TABLE DailyProduction (
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
CREATE TABLE DailySales (
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
CREATE TABLE DailyWastage (
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
CREATE TABLE WastageAlert (
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
CREATE TABLE AuditLog (
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
INSERT INTO Categories (CategoryName, Description) VALUES
('Main Course', 'Primary dishes like rice, curry, dal'),
('Side Dish', 'Accompaniments and secondary items'),
('Dessert', 'Sweet items and desserts'),
('Beverage', 'Drinks and liquid refreshments'),
('Snack', 'Light snacks and finger foods'),
('Bread', 'Roti, naan and other bread items');

-- Default Units
INSERT INTO Units (UnitName, UnitSymbol, UnitType) VALUES
('Plates', 'pcs', 'count'),
('Liters', 'L', 'volume'),
('Kilograms', 'kg', 'weight'),
('Pieces', 'pcs', 'count'),
('Bowls', 'bowls', 'count'),
('Cups', 'cups', 'volume'),
('Servings', 'servings', 'count');

-- Default Suppliers
INSERT INTO Suppliers (SupplierName, ContactPerson, Phone, Email, Address) VALUES
('Local Vegetable Market', 'Ravi Kumar', '9876543210', 'ravi@localmarket.com', 'Main Market Street'),
('Grain Wholesale', 'Sunita Devi', '9876543211', 'sunita@grainwholesale.com', 'Wholesale Market Area'),
('Dairy Products Co.', 'Mohan Lal', '9876543212', 'mohan@dairy.com', 'Industrial Area');

-- Default Staff
INSERT INTO Staff (StaffName, Position, Department, Email) VALUES
('Admin User', 'Administrator', 'admin', 'admin@canteen.com'),
('Head Chef', 'Chef', 'kitchen', 'chef@canteen.com'),
('Kitchen Helper', 'Assistant', 'kitchen', 'helper@canteen.com'),
('Service Staff', 'Server', 'service', 'service@canteen.com');