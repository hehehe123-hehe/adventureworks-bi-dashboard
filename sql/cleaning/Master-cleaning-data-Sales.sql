USE AdventureWorks2025;
GO

/* ================================================================================
SCHEMA: SALES
DESCRIPTION: This script consolidates sales performance, customer profiles, 
             and sales person metrics for revenue and market analysis.
================================================================================ */

-- 1. VIEW: Master Sales Performance (Header & Detail)
-- Combines transaction headers with line items to provide a granular view of revenue.
CREATE OR ALTER VIEW Sales.vCleanSalesPerformance AS
SELECT
    h.SalesOrderID, 
    h.SalesOrderNumber,
    h.CustomerID, -- WAJIB: Kolom ini harus ada untuk relasi ke Customer Profile
    CAST(h.OrderDate AS DATE) AS OrderDate,
    CAST(h.ShipDate AS DATE) AS ShipDate,
    
    -- Order Lifecycle Mapping
    -- Pastikan tidak ada filter WHERE di bawah agar semua status ini muncul di hasil query
    CASE h.Status
        WHEN 1 THEN 'In Process'
        WHEN 2 THEN 'Approved'
        WHEN 3 THEN 'Backordered'
        WHEN 4 THEN 'Rejected'
        WHEN 5 THEN 'Shipped'
        WHEN 6 THEN 'Cancelled'
    END AS OrderStatus,
    h.OnlineOrderFlag AS IsOnlineOrder,

    d.ProductID,
    d.OrderQty,
    d.UnitPrice,
    d.UnitPriceDiscount,
    d.LineTotal,

    h.SubTotal,
    h.TaxAmt,
    h.Freight,
    h.TotalDue,
    h.TerritoryID,
    cr.ToCurrencyCode AS CurrencyCode
FROM Sales.SalesOrderHeader h 
JOIN Sales.SalesOrderDetail d ON h.SalesOrderID = d.SalesOrderID
LEFT JOIN Sales.CurrencyRate cr ON h.CurrencyRateID = cr.CurrencyRateID;
-- PENTING: Jangan tambahkan "WHERE h.Status = 5" di sini jika ingin melihat semua status.
GO


-- 2. VIEW: Customer & Territory Profiles
-- Identifies customer segments (B2B vs B2C) and maps them to sales regions.
CREATE OR ALTER VIEW Sales.vCleanCustomerProfile AS
SELECT
    c.CustomerID, 
    c.AccountNumber,
    CASE
        WHEN c.StoreID IS NOT NULL THEN 'B2B (Store)'
        WHEN c.PersonID IS NOT NULL THEN 'B2C (Individual)'
        ELSE 'Unknown'
    END AS CustomerType,
    ISNULL(s.Name, 'Individual Customer') AS StoreName,
    t.Name AS TerritoryName,
    t.[Group] AS TerritoryRegion,
    t.CountryRegionCode
FROM Sales.Customer c
LEFT JOIN Sales.Store s ON c.StoreID = s.BusinessEntityID
LEFT JOIN Sales.SalesTerritory t ON c.TerritoryID = t.TerritoryID;
GO


-- 3. VIEW: Sales Person Performance
-- Tracks sales quotas, actual results, and achievement status.
CREATE OR ALTER VIEW Sales.vCleanSalesPerson AS
SELECT
    h.SalesOrderID, 
    h.SalesOrderNumber,
    h.CustomerID, -- KRUSIAL: Tambahkan ini agar tidak error 'Invalid column name CustomerID'
    CAST(h.OrderDate AS DATE) AS OrderDate,
    CAST(h.ShipDate AS DATE) AS ShipDate, -- ShipDate dari sisi Sales
    
    -- Order Lifecycle Mapping
    CASE h.Status
        WHEN 1 THEN 'In Process'
        WHEN 2 THEN 'Approved'
        WHEN 3 THEN 'Backordered'
        WHEN 4 THEN 'Rejected'
        WHEN 5 THEN 'Shipped'
        WHEN 6 THEN 'Cancelled'
    END AS OrderStatus,
    h.OnlineOrderFlag AS IsOnlineOrder,

    -- Detail Produk
    d.ProductID,
    d.OrderQty,
    d.UnitPrice,
    d.UnitPriceDiscount,
    d.LineTotal,

    -- Financials
    h.SubTotal,
    h.TaxAmt,
    h.Freight,
    h.TotalDue,

    -- Referensi Wilayah & Mata Uang
    h.TerritoryID,
    cr.ToCurrencyCode AS CurrencyCode
FROM Sales.SalesOrderHeader h 
JOIN Sales.SalesOrderDetail d ON h.SalesOrderID = d.SalesOrderID
LEFT JOIN Sales.CurrencyRate cr ON h.CurrencyRateID = cr.CurrencyRateID;
GO
