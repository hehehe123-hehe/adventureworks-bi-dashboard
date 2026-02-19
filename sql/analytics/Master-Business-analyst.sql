USE AdventureWorks2025;
GO

/* ================================================================================
VIEW NAME: Sales.vMasterBusinessAnalytics (ENHANCED VERSION 2.0)
DESCRIPTION: 
    This is the "Golden Record" view for the AdventureWorks ecosystem with 
    critical enhancements for Power BI dashboard compatibility.

AUTHORS: hehehe123-hehe
================================================================================ */

CREATE OR ALTER VIEW Sales.vMasterBusinessAnalytics AS
SELECT
    -- ═══════════════════════════════════════════════════════════════════════════
    -- 1. TIME & TRANSACTION DIMENSIONS
    -- ═══════════════════════════════════════════════════════════════════════════
    c.CustomerID,
    S.SalesOrderID,
    S.SalesOrderNumber,
    
    S.OrderDate,
    YEAR(S.OrderDate) AS OrderYear,
    MONTH(S.OrderDate) AS OrderMonth,
    S.ShipDate,
    CASE 
        WHEN S.ShipDate IS NOT NULL THEN DATEDIFF(DAY, S.OrderDate, S.ShipDate)
        ELSE NULL 
    END AS DaysToShip,
    S.OrderStatus,
    S.IsOnlineOrder,

    -- ═══════════════════════════════════════════════════════════════════════════
    -- 2. PRODUCT DIMENSIONS
    -- ═══════════════════════════════════════════════════════════════════════════
    P.ProductName,
    P.ProductNumber,
    P.CategoryName,
    P.SubcategoryName,
    P.Color AS ProductColor,
    P.ProductStatus,

    -- ═══════════════════════════════════════════════════════════════════════════
    -- 3. CUSTOMER IDENTITY
    -- ═══════════════════════════════════════════════════════════════════════════
    C.CustomerType,
    C.StoreName,
    COALESCE(PE.FullName, 
        CASE 
            WHEN C.CustomerType = 'B2B (Store)' THEN 'B2B - Store ID: ' + CAST(S.CustomerID AS VARCHAR)
            ELSE 'B2C - Customer ID: ' + CAST(S.CustomerID AS VARCHAR)
        END) AS CustomerName,
    COALESCE(PE.CleanEmail, 'N/A (Update Required)') AS CustomerEmail,

    -- ═══════════════════════════════════════════════════════════════════════════
    -- 4. GEOGRAPHY & TERRITORY
    -- ═══════════════════════════════════════════════════════════════════════════
    C.TerritoryName,
    C.TerritoryRegion,
    C.CountryRegionCode,

    -- ═══════════════════════════════════════════════════════════════════════════
    -- 5. TRANSACTIONAL METRICS (Original Columns - Preserved for backward compatibility)
    -- ═══════════════════════════════════════════════════════════════════════════
    S.OrderQty,
    S.UnitPrice,
    S.UnitPriceDiscount,
    
    -- Original columns in local currency (kept for reference)
    S.LineTotal AS GrossRevenue,
    (S.LineTotal - (P.StandardCost * S.OrderQty)) AS EstimatedNetProfit,
    
    -- Original currency code
    S.CurrencyCode AS RawCurrencyCode,

    -- ═══════════════════════════════════════════════════════════════════════════
    -- 6. ✅ NEW: CURRENCY STANDARDIZATION (USD-Normalized Columns)
    -- ═══════════════════════════════════════════════════════════════════════════
    
    -- Clean Currency Code (handles NULL, old codes, wrong mappings)
    CASE
        -- Handle NULL currency (infer from territory, default USD)
        WHEN S.CurrencyCode IS NULL THEN
            CASE C.CountryRegionCode
                WHEN 'CA' THEN 'CAD'
                WHEN 'GB' THEN 'GBP'
                WHEN 'AU' THEN 'AUD'
                WHEN 'FR' THEN 'EUR'
                WHEN 'DE' THEN 'EUR'
                ELSE 'USD'
            END
        -- Convert old European currencies to EUR
        WHEN S.CurrencyCode IN ('DEM', 'FRF') THEN 'EUR'
        -- Fix wrong currency mappings (GBP territory using FRF code)
        WHEN S.CurrencyCode = 'FRF' AND C.CountryRegionCode = 'GB' THEN 'GBP'
        WHEN S.CurrencyCode = 'GBP' AND C.CountryRegionCode = 'FR' THEN 'EUR'
        WHEN S.CurrencyCode = 'CAD' AND C.CountryRegionCode = 'US' THEN 'USD'
        -- Keep valid codes as-is
        ELSE S.CurrencyCode
    END AS CurrencyCode,
    CASE
        WHEN S.CurrencyCode IS NULL THEN
            CASE C.CountryRegionCode
                WHEN 'CA' THEN 0.74  -- CAD
                WHEN 'GB' THEN 1.27  -- GBP
                WHEN 'AU' THEN 0.66  -- AUD
                WHEN 'FR' THEN 1.08  -- EUR
                WHEN 'DE' THEN 1.08  -- EUR
                ELSE 1.00            -- USD default
            END
        WHEN S.CurrencyCode IN ('DEM', 'FRF') THEN 1.08      -- Old EUR
        WHEN S.CurrencyCode = 'USD' THEN 1.00
        WHEN S.CurrencyCode = 'CAD' THEN 0.74
        WHEN S.CurrencyCode = 'EUR' THEN 1.08
        WHEN S.CurrencyCode = 'GBP' THEN 1.27
        WHEN S.CurrencyCode = 'AUD' THEN 0.66
        ELSE 1.00  -- Default fallback
    END AS ExchangeRateToUSD,
    
    -- USD-NORMALIZED REVENUE (Use this in Power BI measures!)
    -- Formula: GrossRevenue * ExchangeRateToUSD
    S.LineTotal * 
        CASE
            WHEN S.CurrencyCode IS NULL THEN
                CASE C.CountryRegionCode
                    WHEN 'CA' THEN 0.74
                    WHEN 'GB' THEN 1.27
                    WHEN 'AU' THEN 0.66
                    WHEN 'FR' THEN 1.08
                    WHEN 'DE' THEN 1.08
                    ELSE 1.00
                END
            WHEN S.CurrencyCode IN ('DEM', 'FRF') THEN 1.08
            WHEN S.CurrencyCode = 'USD' THEN 1.00
            WHEN S.CurrencyCode = 'CAD' THEN 0.74
            WHEN S.CurrencyCode = 'EUR' THEN 1.08
            WHEN S.CurrencyCode = 'GBP' THEN 1.27
            WHEN S.CurrencyCode = 'AUD' THEN 0.66
            ELSE 1.00
        END AS GrossRevenueUSD,
    
    -- USD-NORMALIZED PROFIT (Use this in Power BI measures!)
    -- Formula: EstimatedNetProfit * ExchangeRateToUSD
    (S.LineTotal - (P.StandardCost * S.OrderQty)) * 
        CASE
            WHEN S.CurrencyCode IS NULL THEN
                CASE C.CountryRegionCode
                    WHEN 'CA' THEN 0.74
                    WHEN 'GB' THEN 1.27
                    WHEN 'AU' THEN 0.66
                    WHEN 'FR' THEN 1.08
                    WHEN 'DE' THEN 1.08
                    ELSE 1.00
                END
            WHEN S.CurrencyCode IN ('DEM', 'FRF') THEN 1.08
            WHEN S.CurrencyCode = 'USD' THEN 1.00
            WHEN S.CurrencyCode = 'CAD' THEN 0.74
            WHEN S.CurrencyCode = 'EUR' THEN 1.08
            WHEN S.CurrencyCode = 'GBP' THEN 1.27
            WHEN S.CurrencyCode = 'AUD' THEN 0.66
            ELSE 1.00
        END AS EstimatedNetProfitUSD,
    
    -- ✅ Data Quality Flag (for monitoring/debugging)
    CASE
        WHEN S.CurrencyCode IS NULL THEN 'NULL - Inferred from Territory'
        WHEN S.CurrencyCode IN ('DEM', 'FRF') THEN 'OLD - Converted to EUR'
        WHEN S.CurrencyCode = 'FRF' AND C.CountryRegionCode = 'GB' THEN 'WRONG - Corrected GBP'
        WHEN S.CurrencyCode = 'GBP' AND C.CountryRegionCode = 'FR' THEN 'WRONG - Corrected EUR'
        WHEN S.CurrencyCode = 'CAD' AND C.CountryRegionCode = 'US' THEN 'WRONG - Corrected USD'
        ELSE 'OK'
    END AS CurrencyDataQualityFlag

FROM Sales.vCleanSalesPerformance S

-- JOIN 1: Product hierarchy and costs
LEFT JOIN Production.vCleanProductMaster P 
    ON S.ProductID = P.ProductID

-- JOIN 2: Customer types and territories
LEFT JOIN Sales.vCleanCustomerProfile C 
    ON S.CustomerID = C.CustomerID

-- JOIN 3: Personal identity (B2C customers)
LEFT JOIN Person.vCleanPerson PE 
    ON S.CustomerID = PE.BusinessEntityID
GO
