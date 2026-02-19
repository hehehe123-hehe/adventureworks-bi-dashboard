USE AdventureWorks2025;
GO

/* ================================================================================
SCHEMA: PRODUCTION
DESCRIPTION: This script creates views for Product Master Data, Inventory, 
             Work Order Efficiency, and Transaction History.
================================================================================ */

-- 1. VIEW: Master Product Data
-- Consolidates product names, categories, costs, and current market status.
CREATE OR ALTER VIEW Production.vCleanProductMaster AS
SELECT
	p.ProductID, 
    p.Name AS ProductName, 
    p.ProductNumber,
	pc.Name AS CategoryName,
	psc.Name AS SubcategoryName,
	pm.Name AS ModelName,

	-- Physical Attribute Cleaning
	ISNULL(p.Color, 'No Color') AS Color,
	ISNULL(p.Size, 'N/A') AS Size,
	p.StandardCost, 
    p.ListPrice,
    -- Calculate Profit Margin per unit
	p.ListPrice - p.StandardCost AS ProfitMargin,

	-- Date Normalization (Removing Time component)
	CAST(p.SellStartDate AS DATE) AS SellStartDate,
	ISNULL(CAST(p.SellEndDate AS DATE), '9999-12-31') AS SellEndDate,

	-- Business Logic: Determine Product Lifecycle Status
	CASE
		WHEN p.SellEndDate IS NULL THEN 'Active'
		WHEN p.SellEndDate <= GETDATE() THEN 'Discontinued'
		ELSE 'Active'
	END AS ProductStatus

FROM Production.Product p
LEFT JOIN Production.ProductSubcategory psc ON p.ProductSubcategoryID = psc.ProductSubcategoryID
LEFT JOIN Production.ProductCategory pc ON psc.ProductCategoryID = pc.ProductCategoryID
LEFT JOIN Production.ProductModel pm ON p.ProductModelID = pm.ProductModelID;
GO


-- 2. VIEW: Inventory and Warehouse Management
-- Monitors stock levels across locations and flags items below safety thresholds.
CREATE OR ALTER VIEW Production.vCleanInventory AS
SELECT
	pi.ProductID,
	p.Name AS ProductName,
	l.Name AS LocationName,
	pi.Shelf, 
    pi.Bin,
    pi.Quantity,
    -- Inventory Alert System
	CASE 
		WHEN pi.Quantity < p.SafetyStockLevel THEN 'Low Stock'
		ELSE 'Safe'
	END AS StockStatus
FROM Production.ProductInventory pi
JOIN Production.Product p ON pi.ProductID = p.ProductID
JOIN Production.Location l ON pi.LocationID = l.LocationID;
GO


-- 3. VIEW: Production Efficiency (Work Orders)
-- Analyzes production volume, scrap reasons, and manufacturing lead times.
CREATE OR ALTER VIEW Production.vCleanWorkOrder AS
SELECT
	wo.WorkOrderID,
	p.Name AS ProductName,
	wo.OrderQty,
	wo.StockedQty,
	wo.ScrappedQty,
	sr.Name AS ScrapReasonName,
	CAST(wo.StartDate AS DATE) AS StartDate,
	CAST(wo.EndDate AS DATE) AS EndDate,

	-- Efficiency Metric: Total days taken to complete the order
	DATEDIFF(DAY, wo.StartDate, wo.EndDate) AS ProductionDays
FROM Production.WorkOrder wo
JOIN Production.Product p ON wo.ProductID = p.ProductID
LEFT JOIN Production.ScrapReason sr ON wo.ScrapReasonID = sr.ScrapReasonID;
GO


-- 4. VIEW: Production Transaction History
-- Standardizes transaction types into human-readable descriptions for reporting.
CREATE OR ALTER VIEW Production.vCleanTransactionHistory AS
SELECT
	TransactionID, 
    ProductID,
	ReferenceOrderID,
	TransactionDate,
    -- Mapping Transaction Codes to Full Names
	CASE TransactionType
		WHEN 'W' THEN 'Work Order'
		WHEN 'S' THEN 'Sales Order'
		WHEN 'P' THEN 'Purchase Order'
	END AS TransactionTypeDesc,
	Quantity,
	ActualCost
FROM Production.TransactionHistory;
GO
