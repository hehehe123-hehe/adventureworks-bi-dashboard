USE AdventureWorks2025;
GO

/* ================================================================================
SCHEMA: PURCHASING
DESCRIPTION: This script consolidates Vendor performance, Purchase Order tracking,
             and Product-Vendor relationships for procurement analysis.
================================================================================ */

-- 1. VIEW: Master Vendor Performance
-- Consolidates vendor ratings and status flags into human-readable descriptions.
CREATE OR ALTER VIEW Purchasing.vCleanVendorMaster AS
SELECT
	BusinessEntityID AS VendorID,
	AccountNumber,
	Name AS VendorName,
	
    -- Credit Rating Standardization (1=Superior to 5=Poor)
	CASE CreditRating
		WHEN 1 THEN 'Superior'
		WHEN 2 THEN 'Excellent'
		WHEN 3 THEN 'Above Average'
		WHEN 4 THEN 'Average'
		WHEN 5 THEN 'Below Average'
	END AS CreditRatingDesc,
	
    -- Logical Bit Mapping
	CASE PreferredVendorStatus
		WHEN 1 THEN 'Preferred'
		ELSE 'Regular'
	END AS VendorStatus,
	
    CASE ActiveFlag
		WHEN 1 THEN 'Active'
		ELSE 'Inactive'
	END AS AccountStatus,
    
	ISNULL(PurchasingWebServiceURL, 'No URL') AS WebserviceURL
FROM Purchasing.Vendor;
GO


-- 2. VIEW: Purchase Order Analysis (Header & Detail)
-- Joins procurement headers with line details to monitor quality and logistics.
CREATE OR ALTER VIEW Purchasing.vCleanPurchaseOrders AS
SELECT
	h.PurchaseOrderID, 
    h.VendorID,
	v.Name AS VendorName,
	CAST(h.OrderDate AS DATE) AS OrderDate,
	ISNULL(CAST(h.ShipDate AS DATE), '9999-12-31') AS ShipDate,

	-- Procurement Lifecycle Status
	CASE h.Status
		WHEN 1 THEN 'Pending'
		WHEN 2 THEN 'Approved'
		WHEN 3 THEN 'Rejected'
		WHEN 4 THEN 'Complete'
	END AS OrderStatus,
    
	-- Financial Totals
	h.SubTotal,
    h.TaxAmt, 
    h.Freight,
    h.TotalDue,
    
	-- Item Level Details
	d.ProductID,
	d.OrderQty,
	d.UnitPrice,
	d.LineTotal,
	d.ReceivedQty,
	d.RejectedQty,
    
	-- Quality Metric: Percentage of rejected goods
    -- Note: Multiplied by 1.0 to ensure decimal precision during division
	CASE
		WHEN d.ReceivedQty = 0 THEN 0
		ELSE ROUND((d.RejectedQty * 1.0 / d.ReceivedQty) * 100, 2)
	END AS RejectRatePercentage,
    
	sm.Name AS ShippingMethod
FROM Purchasing.PurchaseOrderHeader h
JOIN Purchasing.PurchaseOrderDetail d ON h.PurchaseOrderID = d.PurchaseOrderID
JOIN Purchasing.Vendor v ON h.VendorID = v.BusinessEntityID
JOIN Purchasing.ShipMethod sm ON h.ShipMethodID = sm.ShipMethodID;
GO


-- 3. VIEW: Product-Vendor Lead Time Analysis
-- Analyzes the relationship between products and their suppliers.
CREATE OR ALTER VIEW Purchasing.vCleanProductVendor AS
SELECT
	pv.ProductID,
	v.Name AS VendorName,
	pv.AverageLeadTime, -- Lead time represented in days
	pv.StandardPrice,
	pv.LastReceiptCost,
	CAST(pv.LastReceiptDate AS DATE) AS LastReceiptDate,
	pv.MinOrderQty,
	pv.MaxOrderQty,
	ISNULL(pv.OnOrderQty, 0) AS OnOrderQty
FROM Purchasing.ProductVendor pv
JOIN Purchasing.Vendor v ON pv.BusinessEntityID = v.BusinessEntityID;
GO
