#!/usr/bin/env python3
"""
Simplified database initialization for normalized canteen database.
"""

import mysql.connector
from config import db_config

def create_tables():
    """Create all tables"""
    conn = mysql.connector.connect(**db_config)
    cursor = conn.cursor()
    
    # Use the database
    cursor.execute("USE canteen_db")
    
    # Drop existing tables
    drop_tables = [
        "DROP TABLE IF EXISTS AuditLog",
        "DROP TABLE IF EXISTS WastageAlert", 
        "DROP TABLE IF EXISTS DailyWastage",
        "DROP TABLE IF EXISTS DailySales",
        "DROP TABLE IF EXISTS DailyProduction",
        "DROP TABLE IF EXISTS FoodItem",
        "DROP TABLE IF EXISTS Staff",
        "DROP TABLE IF EXISTS Suppliers", 
        "DROP TABLE IF EXISTS Units",
        "DROP TABLE IF EXISTS Categories"
    ]
    
    for drop_sql in drop_tables:
        cursor.execute(drop_sql)
    
    # Create tables
    tables = [
        """CREATE TABLE Categories (
            CategoryID INT PRIMARY KEY AUTO_INCREMENT,
            CategoryName VARCHAR(50) NOT NULL UNIQUE,
            Description TEXT,
            CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )""",
        
        """CREATE TABLE Units (
            UnitID INT PRIMARY KEY AUTO_INCREMENT,
            UnitName VARCHAR(20) NOT NULL UNIQUE,
            UnitSymbol VARCHAR(10),
            UnitType ENUM('volume', 'weight', 'count') DEFAULT 'count',
            CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )""",
        
        """CREATE TABLE Suppliers (
            SupplierID INT PRIMARY KEY AUTO_INCREMENT,
            SupplierName VARCHAR(100) NOT NULL,
            ContactPerson VARCHAR(50),
            Phone VARCHAR(15),
            Email VARCHAR(100),
            Address TEXT,
            IsActive BOOLEAN DEFAULT TRUE,
            CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )""",
        
        """CREATE TABLE Staff (
            StaffID INT PRIMARY KEY AUTO_INCREMENT,
            StaffName VARCHAR(50) NOT NULL,
            Position VARCHAR(30),
            Department ENUM('kitchen', 'service', 'management', 'admin') DEFAULT 'kitchen',
            Email VARCHAR(100),
            IsActive BOOLEAN DEFAULT TRUE,
            CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )""",
        
        """CREATE TABLE FoodItem (
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
            FOREIGN KEY (SupplierID) REFERENCES Suppliers(SupplierID)
        )""",
        
        """CREATE TABLE DailyProduction (
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
        )""",
        
        """CREATE TABLE DailySales (
            SaleID INT PRIMARY KEY AUTO_INCREMENT,
            FoodID INT NOT NULL,
            SaleDate DATE NOT NULL,
            QuantitySold INT CHECK (QuantitySold >= 0),
            SalePrice DECIMAL(10,2) DEFAULT 0.00,
            StaffID INT,
            Notes TEXT,
            CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            UpdatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            FOREIGN KEY (FoodID) REFERENCES FoodItem(FoodID) ON DELETE CASCADE,
            FOREIGN KEY (StaffID) REFERENCES Staff(StaffID),
            UNIQUE KEY unique_sale (FoodID, SaleDate)
        )""",
        
        """CREATE TABLE DailyWastage (
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
        )""",
        
        """CREATE TABLE WastageAlert (
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
        )""",
        
        """CREATE TABLE AuditLog (
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
            FOREIGN KEY (StaffID) REFERENCES Staff(StaffID)
        )"""
    ]
    
    for table_sql in tables:
        cursor.execute(table_sql)
        print("✓ Created table")
    
    # Insert default data
    default_data = [
        # Categories
        "INSERT INTO Categories (CategoryName, Description) VALUES ('Main Course', 'Primary dishes like rice, curry, dal')",
        "INSERT INTO Categories (CategoryName, Description) VALUES ('Side Dish', 'Accompaniments and secondary items')",
        "INSERT INTO Categories (CategoryName, Description) VALUES ('Dessert', 'Sweet items and desserts')",
        "INSERT INTO Categories (CategoryName, Description) VALUES ('Beverage', 'Drinks and liquid refreshments')",
        "INSERT INTO Categories (CategoryName, Description) VALUES ('Snack', 'Light snacks and finger foods')",
        "INSERT INTO Categories (CategoryName, Description) VALUES ('Bread', 'Roti, naan and other bread items')",
        
        # Units
        "INSERT INTO Units (UnitName, UnitSymbol, UnitType) VALUES ('Plates', 'pcs', 'count')",
        "INSERT INTO Units (UnitName, UnitSymbol, UnitType) VALUES ('Liters', 'L', 'volume')",
        "INSERT INTO Units (UnitName, UnitSymbol, UnitType) VALUES ('Kilograms', 'kg', 'weight')",
        "INSERT INTO Units (UnitName, UnitSymbol, UnitType) VALUES ('Pieces', 'pcs', 'count')",
        "INSERT INTO Units (UnitName, UnitSymbol, UnitType) VALUES ('Bowls', 'bowls', 'count')",
        "INSERT INTO Units (UnitName, UnitSymbol, UnitType) VALUES ('Cups', 'cups', 'volume')",
        "INSERT INTO Units (UnitName, UnitSymbol, UnitType) VALUES ('Servings', 'servings', 'count')",
        
        # Suppliers
        "INSERT INTO Suppliers (SupplierName, ContactPerson, Phone, Email, Address) VALUES ('Local Vegetable Market', 'Ravi Kumar', '9876543210', 'ravi@localmarket.com', 'Main Market Street')",
        "INSERT INTO Suppliers (SupplierName, ContactPerson, Phone, Email, Address) VALUES ('Grain Wholesale', 'Sunita Devi', '9876543211', 'sunita@grainwholesale.com', 'Wholesale Market Area')",
        "INSERT INTO Suppliers (SupplierName, ContactPerson, Phone, Email, Address) VALUES ('Dairy Products Co.', 'Mohan Lal', '9876543212', 'mohan@dairy.com', 'Industrial Area')",
        
        # Staff
        "INSERT INTO Staff (StaffName, Position, Department, Email) VALUES ('Admin User', 'Administrator', 'admin', 'admin@canteen.com')",
        "INSERT INTO Staff (StaffName, Position, Department, Email) VALUES ('Head Chef', 'Chef', 'kitchen', 'chef@canteen.com')",
        "INSERT INTO Staff (StaffName, Position, Department, Email) VALUES ('Kitchen Helper', 'Assistant', 'kitchen', 'helper@canteen.com')",
        "INSERT INTO Staff (StaffName, Position, Department, Email) VALUES ('Service Staff', 'Server', 'service', 'service@canteen.com')"
    ]
    
    for data_sql in default_data:
        cursor.execute(data_sql)
        print("✓ Inserted default data")
    
    conn.commit()
    conn.close()
    print("✓ Database setup complete!")

if __name__ == "__main__":
    create_tables()