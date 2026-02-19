use AdventureWorks2025;
go
-- ============================================================================
-- DEEP SALES DATA ANALYSIS TEMPLATE
-- Advanced Analytics Beyond Surface-Level Metrics
-- ============================================================================

-- ============================================================================
-- SECTION 1: REVENUE & PROFITABILITY DEEP DIVE
-- ============================================================================

-- 1.1 Revenue Trend Analysis with Growth Rate & Acceleration
WITH MonthlyRevenue AS (
    SELECT 
        OrderYear,
        OrderMonth,
        CurrencyCode,
        SUM(GrossRevenue) AS MonthlyRevenue,
        SUM(EstimatedNetProfit) AS MonthlyProfit,
        COUNT(DISTINCT SalesOrderID) AS OrderCount,
        COUNT(DISTINCT CustomerName) AS UniqueCustomers
    FROM Sales.vMasterBusinessAnalytics
    WHERE OrderDate IS NOT NULL
    GROUP BY OrderYear, OrderMonth, CurrencyCode
),
RevenueWithGrowth AS (
    SELECT 
        *,
        -- CRITICAL FIX: Add PARTITION BY CurrencyCode
        LAG(MonthlyRevenue, 1) OVER (PARTITION BY CurrencyCode ORDER BY OrderYear, OrderMonth) AS PrevMonthRevenue,
        LAG(MonthlyRevenue, 12) OVER (PARTITION BY CurrencyCode ORDER BY OrderYear, OrderMonth) AS YoYRevenue,
        AVG(MonthlyRevenue) OVER (PARTITION BY CurrencyCode ORDER BY OrderYear, OrderMonth ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS MA3
    FROM MonthlyRevenue
)
SELECT TOP 10
    OrderYear,
    OrderMonth,
    CurrencyCode,
    MonthlyRevenue,
    MonthlyProfit,
    -- Month-over-Month Growth (now comparing same currency)
    ROUND(((MonthlyRevenue - PrevMonthRevenue) / NULLIF(PrevMonthRevenue, 0) * 100), 2) AS MoM_Growth_Pct,
    -- Year-over-Year Growth (now comparing same currency)
    ROUND(((MonthlyRevenue - YoYRevenue) / NULLIF(YoYRevenue, 0) * 100), 2) AS YoY_Growth_Pct,
    -- Profit Margin
    ROUND((MonthlyProfit / NULLIF(MonthlyRevenue, 0) * 100), 2) AS ProfitMargin_Pct,
    -- Moving Average for trend smoothing
    MA3 AS ThreeMonth_MA,
    -- Deviation from moving average (volatility indicator)
    ROUND(((MonthlyRevenue - MA3) / NULLIF(MA3, 0) * 100), 2) AS Deviation_From_Trend_Pct
FROM RevenueWithGrowth
ORDER BY CurrencyCode, OrderYear DESC, OrderMonth DESC;


-- 1.2 Profit Margin Analysis by Multiple Dimensions
SELECT top 10
    CategoryName,
    SubcategoryName,
    ProductColor,
    CustomerType,
    -- Revenue metrics
    CurrencyCode,
    SUM(GrossRevenue) AS TotalRevenue,
    SUM(EstimatedNetProfit) AS TotalProfit,
    -- Margin analysis
    ROUND(AVG(EstimatedNetProfit / NULLIF(GrossRevenue, 0) * 100), 2) AS AvgMargin_Pct,
    ROUND(MIN(EstimatedNetProfit / NULLIF(GrossRevenue, 0) * 100), 2) AS MinMargin_Pct,
    ROUND(MAX(EstimatedNetProfit / NULLIF(GrossRevenue, 0) * 100), 2) AS MaxMargin_Pct,
    -- Volume metrics
    COUNT(DISTINCT SalesOrderID) AS OrderCount,
    SUM(OrderQty) AS TotalQty,
    -- Average order value
    ROUND(AVG(GrossRevenue), 2) AS AvgOrderValue
FROM Sales.vMasterBusinessAnalytics
WHERE EstimatedNetProfit IS NOT NULL AND GrossRevenue > 0
GROUP BY CategoryName, SubcategoryName, ProductColor, CustomerType, CurrencyCode
HAVING COUNT(DISTINCT SalesOrderID) >= 5  -- Filter for statistical significance
ORDER BY TotalProfit DESC;


-- 1.3 Discount Impact Analysis - Elasticity & Effectiveness
WITH DiscountBuckets AS (
    SELECT 
        CASE 
            WHEN UnitPriceDiscount = 0 THEN 'No Discount'
            WHEN UnitPriceDiscount <= 0.05 THEN 'Small (0-5%)'
            WHEN UnitPriceDiscount <= 0.15 THEN 'Medium (5-15%)'
            WHEN UnitPriceDiscount <= 0.30 THEN 'Large (15-30%)'
            ELSE 'VeryLarge (>30%)'
        END AS DiscountBucket,
        UnitPriceDiscount,
        OrderQty,
        CurrencyCode,
        GrossRevenue,
        EstimatedNetProfit,
        CategoryName
    FROM Sales.vMasterBusinessAnalytics
)
SELECT top 10
    DiscountBucket,
    CategoryName,
    COUNT(*) AS TransactionCount,
    -- Quantity metrics
    AVG(OrderQty) AS AvgQtyPerOrder,
    SUM(OrderQty) AS TotalQty,
    -- Revenue metrics
    CurrencyCode,
    SUM(GrossRevenue) AS TotalRevenue,
    ROUND(AVG(GrossRevenue), 2) AS AvgRevenuePerOrder,
    -- Profitability
    SUM(EstimatedNetProfit) AS TotalProfit,
    ROUND(AVG(EstimatedNetProfit / NULLIF(GrossRevenue, 0) * 100), 2) AS AvgMargin_Pct,
    -- Discount effectiveness
    ROUND(AVG(UnitPriceDiscount * 100), 2) AS AvgDiscount_Pct,
    -- Revenue per unit discount (ROI of discount)
    ROUND(SUM(GrossRevenue) / NULLIF(SUM(UnitPriceDiscount), 0), 2) AS Revenue_Per_Discount_Dollar
FROM DiscountBuckets
GROUP BY DiscountBucket, CategoryName, CurrencyCode
ORDER BY DiscountBucket, TotalRevenue DESC;


-- ============================================================================
-- SECTION 2: CUSTOMER BEHAVIOR & SEGMENTATION ANALYSIS
-- ============================================================================

-- 2.1 RFM Analysis (Recency, Frequency, Monetary)
WITH CustomerMetrics AS (
    SELECT 
        CustomerName,
        CustomerEmail,
        CustomerType,
        TerritoryName,
        -- Recency: Days since last purchase
        DATEDIFF(day, MAX(OrderDate), (SELECT MAX(OrderDate) FROM Sales.vMasterBusinessAnalytics)) AS DaysSinceLastOrder,
        -- Frequency: Number of orders
        COUNT(DISTINCT SalesOrderID) AS TotalOrders,
        COUNT(DISTINCT CAST(OrderYear AS VARCHAR) + '-' + CAST(OrderMonth AS VARCHAR)) AS ActiveMonths,
        -- Monetary: Total spend dalam USD (apple-to-apple semua customer)
        SUM(GrossRevenueUSD) AS TotalRevenue_USD,
        AVG(GrossRevenueUSD) AS AvgOrderValue_USD,
        SUM(EstimatedNetProfitUSD) AS TotalProfit_USD,
        -- Additional metrics
        MIN(OrderDate) AS FirstOrderDate,
        MAX(OrderDate) AS LastOrderDate,
        SUM(OrderQty) AS TotalQtyPurchased
    FROM Sales.vMasterBusinessAnalytics
    WHERE CustomerName IS NOT NULL
    -- TIDAK GROUP BY CurrencyCode → satu baris per customer, revenue sudah USD
    GROUP BY CustomerName, CustomerEmail, CustomerType, TerritoryName
),
RFMScores AS (
    SELECT 
        *,
        -- RFM Scoring: semua customer dibanding globally (bukan per currency!)
        -- Recency: makin kecil DaysSince = makin bagus → ASC = score 1 dulu, NTILE flips it
        NTILE(5) OVER (ORDER BY DaysSinceLastOrder ASC) AS R_Score,
        -- Frequency: makin banyak order = makin bagus
        NTILE(5) OVER (ORDER BY TotalOrders DESC) AS F_Score,
        -- Monetary: ranking pakai USD → fair comparison lintas currency
        NTILE(5) OVER (ORDER BY TotalRevenue_USD DESC) AS M_Score,
        -- Customer lifetime
        DATEDIFF(day, FirstOrderDate, LastOrderDate) AS CustomerLifetimeDays
    FROM CustomerMetrics
)
SELECT TOP 10
    CustomerName,
    CustomerType,
    TerritoryName,
    -- RFM Scores
    R_Score,
    F_Score,
    M_Score,
    (R_Score + F_Score + M_Score) AS RFM_Total_Score,
    -- Segment classification
    CASE 
        WHEN R_Score >= 4 AND F_Score >= 4 AND M_Score >= 4 THEN 'Champions'
        WHEN R_Score >= 3 AND F_Score >= 3 AND M_Score >= 4 THEN 'Loyal Customers'
        WHEN R_Score >= 4 AND F_Score <= 2 AND M_Score >= 3 THEN 'Big Spenders'
        WHEN R_Score >= 4 AND F_Score <= 2                  THEN 'Promising'
        WHEN R_Score <= 2 AND F_Score >= 3 AND M_Score >= 3 THEN 'At Risk'
        WHEN R_Score <= 2 AND F_Score >= 4                  THEN 'Cant Lose Them'
        WHEN R_Score <= 2 AND F_Score <= 2 AND M_Score >= 3 THEN 'Hibernating High Value'
        WHEN R_Score <= 2                                   THEN 'Lost'
        ELSE 'Regular'
    END AS CustomerSegment,
    -- Metrics dalam USD
    DaysSinceLastOrder,
    TotalOrders,
    ActiveMonths,
    TotalRevenue_USD,
    AvgOrderValue_USD,
    TotalProfit_USD,
    ROUND(TotalProfit_USD / NULLIF(TotalRevenue_USD, 0) * 100, 2) AS AvgMargin_Pct,
    CustomerLifetimeDays,
    -- Purchase frequency per month
    CASE 
        WHEN CustomerLifetimeDays > 0 
        THEN ROUND(CAST(TotalOrders AS FLOAT) / (CustomerLifetimeDays / 30.0), 2)
        ELSE 0 
    END AS OrdersPerMonth
FROM RFMScores
ORDER BY RFM_Total_Score DESC, TotalRevenue_USD DESC;


-- 2.2 Customer Cohort Analysis - Retention & Lifetime Value
WITH FirstPurchase AS (
    SELECT 
        CustomerName,
        MIN(OrderDate) AS FirstOrderDate,
        YEAR(MIN(OrderDate)) AS CohortYear,
        MONTH(MIN(OrderDate)) AS CohortMonth
    FROM Sales.vMasterBusinessAnalytics
    WHERE CustomerName IS NOT NULL
    GROUP BY CustomerName
),
CohortData AS (
    SELECT 
        f.CustomerName,
        f.CohortYear,
        f.CohortMonth,
        s.OrderYear,
        s.OrderMonth,
        s.OrderDate,
        S.CurrencyCode,
        s.GrossRevenue,
        s.EstimatedNetProfit,
        -- Months since first purchase
        DATEDIFF(month, f.FirstOrderDate, s.OrderDate) AS MonthsSinceFirstPurchase
    FROM FirstPurchase f
    INNER JOIN Sales.vMasterBusinessAnalytics s ON f.CustomerName = s.CustomerName
)
SELECT top 10
    CohortYear,
    CohortMonth,
    MonthsSinceFirstPurchase,
    CurrencyCode,
    -- Cohort metrics
    COUNT(DISTINCT CustomerName) AS ActiveCustomers,
    COUNT(*) AS TotalOrders,
    SUM(GrossRevenue) AS CohortRevenue,
    SUM(EstimatedNetProfit) AS CohortProfit,
    AVG(GrossRevenue) AS AvgOrderValue,
    -- Revenue per customer in cohort period
    SUM(GrossRevenue) / NULLIF(COUNT(DISTINCT CustomerName), 0) AS RevenuePerCustomer
FROM CohortData
WHERE CohortYear IS NOT NULL
GROUP BY CohortYear, CohortMonth, MonthsSinceFirstPurchase, CurrencyCode
ORDER BY CohortYear DESC, CohortMonth DESC, MonthsSinceFirstPurchase;


-- 2.3 Customer Churn Risk Analysis
WITH OrderSequences as(
    select
    CustomerName,
    OrderDate,
    CurrencyCode,
    GrossRevenue,
    SalesOrderID,
    lag(OrderDate) over (partition by CustomerName order By OrderDate) as PreviousOrderDate
    from Sales.vMasterBusinessAnalytics
    where CustomerName is not null
),
CustomerActivity AS (
    SELECT 
        CustomerName,
        MAX(OrderDate) AS LastOrderDate,
        COUNT(DISTINCT SalesOrderID) AS TotalOrders,
        CurrencyCode,
        SUM(GrossRevenue) AS TotalRevenue,
        AVG(cast(DATEDIFF(day, PreviousOrderDate,
            OrderDate) as float)) AS AvgDaysBetweenOrders,
        DATEDIFF(day, MAX(OrderDate), GETDATE()) AS DaysSinceLastOrder
    FROM OrderSequences
    GROUP BY CustomerName, CurrencyCode
)
SELECT top 10
    CustomerName,
    LastOrderDate,
    TotalOrders,
    TotalRevenue,
    DaysSinceLastOrder,
    AvgDaysBetweenOrders,
    -- Churn risk calculation
    CASE 
        WHEN DaysSinceLastOrder > (AvgDaysBetweenOrders * 3) THEN 'High Risk'
        WHEN DaysSinceLastOrder > (AvgDaysBetweenOrders * 2) THEN 'Medium Risk'
        WHEN DaysSinceLastOrder > AvgDaysBetweenOrders THEN 'Low Risk'
        ELSE 'Active'
    END AS ChurnRisk,
    -- Expected next purchase date
    DATEADD(day, AvgDaysBetweenOrders, LastOrderDate) AS ExpectedNextPurchaseDate,
    -- Value at risk
    CASE 
        WHEN DaysSinceLastOrder > (AvgDaysBetweenOrders * 2) 
        THEN TotalRevenue / NULLIF(TotalOrders, 0)
        ELSE 0 
    END AS MonthlyRevenueAtRisk
FROM CustomerActivity
WHERE TotalOrders >= 2  -- Need at least 2 orders to calculate pattern
ORDER BY 
    CASE 
        WHEN DaysSinceLastOrder > (AvgDaysBetweenOrders * 3) THEN 1
        WHEN DaysSinceLastOrder > (AvgDaysBetweenOrders * 2) THEN 2
        WHEN DaysSinceLastOrder > AvgDaysBetweenOrders THEN 3
        ELSE 4
    END,
    TotalRevenue DESC;




-- ============================================================================
-- SECTION 3: PRODUCT PERFORMANCE & PORTFOLIO ANALYSIS
-- ============================================================================

-- 3.1 Product Portfolio Matrix (BCG-Style Analysis)
declare @maxYear int = ( 
    select max(OrderYear)
    from Sales.vMasterBusinessAnalytics);

WITH ProductMetrics AS (
    SELECT 
        ProductName,
        CategoryName,
        SubcategoryName,
        -- Market metrics
        CurrencyCode,
        SUM(GrossRevenue) AS TotalRevenue,
        SUM(OrderQty) AS TotalQtySold,
        COUNT(DISTINCT SalesOrderID) AS OrderCount,
        COUNT(DISTINCT CustomerName) AS UniqueCustomers,
        -- Growth calculation
        SUM(CASE WHEN OrderYear = @maxYear THEN GrossRevenue ELSE 0 END) AS CurrentYearRevenue,
        SUM(CASE WHEN OrderYear = @maxYear - 1 THEN GrossRevenue ELSE 0 END) AS PriorYearRevenue,
        -- Profitability
        SUM(EstimatedNetProfit) AS TotalProfit,
        AVG(EstimatedNetProfit / NULLIF(GrossRevenue, 0)) AS AvgMargin
    FROM Sales.vMasterBusinessAnalytics
    WHERE ProductName IS NOT NULL
    GROUP BY ProductName, CategoryName, SubcategoryName, CurrencyCode
),
MarketShare AS (
    SELECT 
        *,
        -- Market share within category
        TotalRevenue / SUM(TotalRevenue) OVER (PARTITION BY CategoryName) AS CategoryMarketShare,
        -- Growth rate
        (CurrentYearRevenue - PriorYearRevenue) / NULLIF(PriorYearRevenue, 0) AS GrowthRate,
        -- Relative market share (vs average in category)
        TotalRevenue / AVG(TotalRevenue) OVER (PARTITION BY CategoryName) AS RelativeMarketShare
    FROM ProductMetrics
),
ProductClassification AS (
    SELECT 
        *,
        -- BCG Matrix Classification
        CASE 
            WHEN RelativeMarketShare > 1 AND GrowthRate > 0.15 THEN 'Stars'
            WHEN RelativeMarketShare > 1 AND GrowthRate <= 0.15 THEN 'Cash Cows'
            WHEN RelativeMarketShare <= 1 AND GrowthRate > 0.15 THEN 'Question Marks'
            WHEN RelativeMarketShare <= 1 AND GrowthRate <= 0.15 THEN 'Dogs'
            ELSE 'Unclassified'
        END AS BCG_Category
    FROM MarketShare
)
SELECT 
    ProductName,
    CategoryName,
    SubcategoryName,
    BCG_Category,
    ROUND(TotalRevenue, 2) AS TotalRevenue,
    ROUND(CategoryMarketShare * 100, 2) AS CategoryShare_Pct,
    ROUND(RelativeMarketShare, 2) AS RelativeMarketShare,
    ROUND(GrowthRate * 100, 2) AS YoY_Growth_Pct,
    ROUND(AvgMargin * 100, 2) AS AvgMargin_Pct,
    OrderCount,
    UniqueCustomers,
    -- Strategic recommendation
    CASE 
        WHEN BCG_Category = 'Stars' THEN 'Invest for growth - High priority'
        WHEN BCG_Category = 'Cash Cows' THEN 'Maintain & maximize profit'
        WHEN BCG_Category = 'Question Marks' THEN 'Evaluate: Invest or divest'
        WHEN BCG_Category = 'Dogs' THEN 'Consider discontinuation or reposition'
        ELSE 'Needs analysis'
    END AS StrategyRecommendation
FROM ProductClassification
ORDER BY 
    CASE BCG_Category
        WHEN 'Stars' THEN 1
        WHEN 'Question Marks' THEN 2
        WHEN 'Cash Cows' THEN 3
        WHEN 'Dogs' THEN 4
        ELSE 5
    END,
    TotalRevenue DESC;


-- 3.2 Product Affinity & Cross-Sell Analysis
WITH ProductPairs AS (
    SELECT 
        s1.SalesOrderID,
        s1.ProductName AS Product1,
        s1.CategoryName AS Category1,
        s2.ProductName AS Product2,
        s2.CategoryName AS Category2,
        S1.CurrencyCode AS CurrencyCode1,
        S2.CurrencyCode AS CurrencyCode2,
        s1.GrossRevenue AS Revenue1,
        s2.GrossRevenue AS Revenue2
    FROM Sales.vMasterBusinessAnalytics s1
    INNER JOIN Sales.vMasterBusinessAnalytics s2 
        ON s1.SalesOrderID = s2.SalesOrderID 
        AND s1.ProductName < s2.ProductName  -- Avoid duplicates
    WHERE s1.ProductName IS NOT NULL 
        AND s2.ProductName IS NOT NULL
)
SELECT top 20 
    Product1,
    Category1,
    Product2,
    Category2,
    CurrencyCode1,
    CurrencyCode2,
    COUNT(*) AS TimesBoughtTogether,
    AVG(Revenue1 + Revenue2) AS AvgBundleRevenue,
    SUM(Revenue1 + Revenue2) AS TotalBundleRevenue,
    -- Lift calculation (vs random expectation)
    CAST(COUNT(*) AS FLOAT) / (
        SELECT COUNT(DISTINCT SalesOrderID) * 0.01 FROM Sales.vMasterBusinessAnalytics
    ) AS AffinityScore
FROM ProductPairs
GROUP BY Product1, Category1, Product2, Category2, CurrencyCode1,CurrencyCode2
HAVING COUNT(*) >= 3  -- Minimum co-occurrence threshold
ORDER BY TimesBoughtTogether DESC, TotalBundleRevenue DESC;


-- 3.3 Product Lifecycle Analysis
WITH ProductDates as (
    select
        ProductName,
        min(OrderDate) as ProductLaunchDate,
        max(OrderDate) as ProductLastSaleDate
    from Sales.vMasterBusinessAnalytics
    where ProductName is not null
    group by ProductName
),
ProductTimeline AS (
    SELECT 
        ProductName,
        CategoryName,
        OrderYear,
        OrderMonth,
        CurrencyCode,
        SUM(GrossRevenue) AS MonthlyRevenue,
        SUM(OrderQty) AS MonthlyQty,
        COUNT(DISTINCT SalesOrderID) AS MonthlyOrders,
        AVG(UnitPrice) AS AvgPrice
    FROM Sales.vMasterBusinessAnalytics
    GROUP BY ProductName, CategoryName, OrderYear, OrderMonth, CurrencyCode
),
ProductAge AS (
    SELECT 
        t.*,
        d.ProductLaunchDate,
        DATEDIFF(month, d.ProductLaunchDate, 
            DATEFROMPARTS(t.OrderYear, t.OrderMonth, 1)) AS MonthsSinceLaunch,
        DATEDIFF(month, d.ProductLaunchDate,d. ProductLastSaleDate) AS ProductLifetimeMonths,
        -- Calculate trend
        AVG(t.MonthlyRevenue) OVER (
            PARTITION BY t.ProductName, CurrencyCode 
            ORDER BY t.OrderYear,t.OrderMonth 
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ) AS MA3_Revenue
    FROM ProductTimeline t
    join ProductDates d on t.ProductName = d.ProductName
)
SELECT 
    ProductName,
    CategoryName,
    ProductLaunchDate,
    ProductLifetimeMonths,
    MonthsSinceLaunch,
    MonthlyRevenue,
    MA3_Revenue,
    -- Lifecycle stage determination
    CASE 
        WHEN MonthsSinceLaunch <= 3 THEN 'Introduction'
        WHEN MonthsSinceLaunch <= 12 AND MonthlyRevenue > MA3_Revenue * 1.1 THEN 'Growth'
        WHEN MonthlyRevenue >= MA3_Revenue * 0.9 AND MonthlyRevenue <= MA3_Revenue * 1.1 THEN 'Maturity'
        WHEN MonthlyRevenue < MA3_Revenue * 0.9 THEN 'Decline'
        ELSE 'Stable'
    END AS LifecycleStage,
    -- Performance vs trend
    ROUND((MonthlyRevenue - MA3_Revenue) / NULLIF(MA3_Revenue, 0) * 100, 2) AS Deviation_From_Trend_Pct
FROM ProductAge
WHERE OrderYear = (SELECT MAX(OrderYear) FROM Sales.vMasterBusinessAnalytics)
   
ORDER BY ProductName, OrderYear DESC, OrderMonth DESC;


-- ============================================================================
-- SECTION 4: GEOGRAPHIC & CHANNEL ANALYSIS
-- ============================================================================

-- 4.1 Geographic Performance Deep Dive
WITH GeoMetrics AS (
    SELECT 
        TerritoryName,
        TerritoryRegion,
        CountryRegionCode,
        CustomerType,
        IsOnlineOrder,
        OrderYear,
        CurrencyCode,
        -- Revenue metrics
        SUM(GrossRevenue) AS TotalRevenue,
        SUM(EstimatedNetProfit) AS TotalProfit,
        AVG(GrossRevenue) AS AvgOrderValue,
        -- Volume metrics
        COUNT(DISTINCT SalesOrderID) AS OrderCount,
        COUNT(DISTINCT CustomerName) AS UniqueCustomers,
        SUM(OrderQty) AS TotalQty,
        -- Product diversity
        COUNT(DISTINCT ProductName) AS UniqueProducts,
        COUNT(DISTINCT CategoryName) AS UniqueCategories
    FROM Sales.vMasterBusinessAnalytics
    WHERE TerritoryName IS NOT NULL
    GROUP BY TerritoryName, TerritoryRegion, CountryRegionCode, CustomerType, IsOnlineOrder, OrderYear, CurrencyCode
),
GeoWithGrowth AS (
    SELECT 
        *,
        LAG(TotalRevenue) OVER (
            PARTITION BY TerritoryName, CustomerType, IsOnlineOrder 
            ORDER BY OrderYear
        ) AS PriorYearRevenue,
        -- Market concentration
        TotalRevenue / SUM(TotalRevenue) OVER (PARTITION BY OrderYear) AS RevenueShare
    FROM GeoMetrics
)
SELECT 
    TerritoryName,
    TerritoryRegion,
    CountryRegionCode,
    CustomerType,
    CASE WHEN IsOnlineOrder = 1 THEN 'Online' ELSE 'Offline' END AS Channel,
    OrderYear,
    TotalRevenue,
    TotalProfit,
    ROUND(TotalProfit / NULLIF(TotalRevenue, 0) * 100, 2) AS ProfitMargin_Pct,
    -- Growth metrics
    ROUND((TotalRevenue - PriorYearRevenue) / NULLIF(PriorYearRevenue, 0) * 100, 2) AS YoY_Growth_Pct,
    -- Market metrics
    ROUND(RevenueShare * 100, 2) AS MarketShare_Pct,
    OrderCount,
    UniqueCustomers,
    ROUND(CAST(OrderCount AS FLOAT) / NULLIF(UniqueCustomers, 0), 2) AS OrdersPerCustomer,
    AvgOrderValue,
    -- Product diversity index
    ROUND(CAST(UniqueProducts AS FLOAT) / NULLIF(OrderCount, 0), 2) AS ProductDiversityIndex
FROM GeoWithGrowth
WHERE OrderYear >= (SELECT MAX(OrderYear) - 2 FROM Sales.vMasterBusinessAnalytics)
ORDER BY OrderYear DESC, TotalRevenue DESC;


-- 4.2 Online vs Offline Channel Comparison
WITH ChannelMetrics AS (
    SELECT 
        CASE WHEN IsOnlineOrder = 1 THEN 'Online' ELSE 'Offline' END AS Channel,
        CategoryName,
        CustomerType,
        OrderYear,
        OrderMonth,
        CurrencyCode,
        -- Revenue
        SUM(GrossRevenue) AS Revenue,
        SUM(EstimatedNetProfit) AS Profit,
        -- Volume
        COUNT(DISTINCT SalesOrderID) AS Orders,
        COUNT(DISTINCT CustomerName) AS Customers,
        SUM(OrderQty) AS Quantity,
        -- Pricing
        AVG(UnitPrice) AS AvgPrice,
        AVG(UnitPriceDiscount) AS AvgDiscount,
        -- Basket size
        AVG(OrderQty) AS AvgQtyPerOrder
    FROM Sales.vMasterBusinessAnalytics
    GROUP BY IsOnlineOrder, CategoryName, CustomerType, OrderYear, OrderMonth, CurrencyCode
)
SELECT 
    Channel,
    CategoryName,
    CustomerType,
    OrderYear,
    Revenue,
    Profit,
    ROUND(Profit / NULLIF(Revenue, 0) * 100, 2) AS Margin_Pct,
    Orders,
    Customers,
    ROUND(Revenue / NULLIF(Orders, 0), 2) AS AvgOrderValue,
    ROUND(Revenue / NULLIF(Customers, 0), 2) AS RevenuePerCustomer,
    ROUND(CAST(Orders AS FLOAT) / NULLIF(Customers, 0), 2) AS OrdersPerCustomer,
    AvgQtyPerOrder,
    ROUND(AvgDiscount * 100, 2) AS AvgDiscount_Pct,
    -- Channel efficiency
    ROUND(Profit / NULLIF(Orders, 0), 2) AS ProfitPerOrder,
    -- Market share within channel
    ROUND(Revenue / SUM(Revenue) OVER (PARTITION BY Channel, OrderYear) * 100, 2) AS ChannelShare_Pct
FROM ChannelMetrics
WHERE OrderYear >= (SELECT MAX(OrderYear) - 1 FROM Sales.vMasterBusinessAnalytics)
ORDER BY OrderYear DESC, Channel, Revenue DESC;


-- ============================================================================
-- SECTION 5: PRICING & PROMOTION OPTIMIZATION
-- ============================================================================

-- 5.1 Price Sensitivity Analysis by Segment
WITH PriceTiers AS (
    SELECT 
        ProductName,
        CategoryName,
        CustomerType,
        CurrencyCode,
        CASE 
            WHEN UnitPrice < 100 THEN '1_Budget (<$100)'
            WHEN UnitPrice < 500 THEN '2_Mid ($100-500)'
            WHEN UnitPrice < 1000 THEN '3_Premium ($500-1K)'
            ELSE '4_Luxury (>$1K)'
        END AS PriceRange,
        UnitPrice,
        UnitPriceDiscount,
        OrderQty,
        GrossRevenue,
        EstimatedNetProfit
    FROM Sales.vMasterBusinessAnalytics
    WHERE UnitPrice > 0
)
SELECT 
    PriceRange,
    CategoryName,
    CustomerType,
    -- Volume metrics
    COUNT(*) AS TransactionCount,
    SUM(OrderQty) AS TotalQtySold,
    AVG(OrderQty) AS AvgQtyPerTransaction,
    -- Revenue metrics
    SUM(GrossRevenue) AS TotalRevenue,
    AVG(GrossRevenue) AS AvgTransactionValue,
    -- Pricing metrics
    AVG(UnitPrice) AS AvgPrice,
    MIN(UnitPrice) AS MinPrice,
    MAX(UnitPrice) AS MaxPrice,
    STDEV(UnitPrice) AS PriceStdDev,
    -- Discount metrics
    AVG(UnitPriceDiscount * 100) AS AvgDiscount_Pct,
    SUM(CASE WHEN UnitPriceDiscount > 0 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS Discount_Penetration_Pct,
    -- Profitability
    SUM(EstimatedNetProfit) AS TotalProfit,
    AVG(EstimatedNetProfit / NULLIF(GrossRevenue, 0) * 100) AS AvgMargin_Pct,
    -- Price elasticity indicator
    ROUND(
        STDEV(OrderQty) / NULLIF(AVG(OrderQty), 0) / 
        (STDEV(UnitPrice) / NULLIF(AVG(UnitPrice), 0))
    , 2) AS Elasticity_Proxy
FROM PriceTiers
GROUP BY PriceRange, CategoryName, CustomerType, CurrencyCode
ORDER BY PriceRange, TotalRevenue DESC;


-- 5.2 Promotional Effectiveness Analysis
WITH PromoPerformance AS (
    SELECT 
        OrderYear,
        OrderMonth,
        CategoryName,
        ProductName,
        CustomerType,
        CurrencyCode,
        -- Discount classification
        CASE 
            WHEN UnitPriceDiscount = 0 THEN 'No Promotion'
            ELSE 'On Promotion'
        END AS PromoStatus,
        -- Metrics
        COUNT(*) AS Transactions,
        SUM(OrderQty) AS TotalQty,
        SUM(GrossRevenue) AS Revenue,
        SUM(EstimatedNetProfit) AS Profit,
        AVG(UnitPrice) AS AvgPrice,
        AVG(UnitPriceDiscount) AS AvgDiscount
    FROM Sales.vMasterBusinessAnalytics
    GROUP BY OrderYear, OrderMonth, CategoryName, ProductName, CustomerType, CurrencyCode,
        CASE WHEN UnitPriceDiscount = 0 THEN 'No Promotion' ELSE 'On Promotion' END
)
SELECT 
    OrderYear,
    CategoryName,
    ProductName,
    PromoStatus,
    -- Volume uplift
    SUM(Transactions) AS TotalTransactions,
    SUM(TotalQty) AS TotalQuantity,
    -- Revenue metrics
    SUM(Revenue) AS TotalRevenue,
    AVG(Revenue / NULLIF(Transactions, 0)) AS AvgTransactionValue,
    -- Profitability
    SUM(Profit) AS TotalProfit,
    AVG(Profit / NULLIF(Revenue, 0) * 100) AS AvgMargin_Pct,
    -- Promotional metrics
    AVG(AvgDiscount * 100) AS AvgDiscount_Pct,
    -- Incremental analysis (compare promo vs non-promo)
    SUM(Revenue) / SUM(Transactions) - 
        AVG(CASE WHEN PromoStatus = 'No Promotion' THEN Revenue / NULLIF(Transactions, 0) END) 
        AS IncrementalRevenuePerTransaction
FROM PromoPerformance
GROUP BY OrderYear, CategoryName, ProductName, PromoStatus
HAVING SUM(Transactions) >= 5
ORDER BY OrderYear DESC, TotalRevenue DESC;


-- ============================================================================
-- SECTION 6: OPERATIONAL EFFICIENCY & ANOMALY DETECTION
-- ============================================================================

-- 6.1 Order Status Analysis & Fulfillment Performance
SELECT 
    OrderStatus,
    CustomerType,
    IsOnlineOrder,
    TerritoryRegion,
    CurrencyCode,
    -- Volume metrics
    COUNT(DISTINCT SalesOrderID) AS OrderCount,
    COUNT(*) AS LineItemCount,
    -- Revenue impact
    SUM(GrossRevenue) AS TotalRevenue,
    AVG(GrossRevenue) AS AvgOrderValue,
    SUM(EstimatedNetProfit) AS TotalProfit,
    -- Status distribution
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS Status_Distribution_Pct,
    -- Revenue at risk (if not completed)
    CASE 
        WHEN OrderStatus NOT IN ('Completed', 'Shipped', 'Delivered') 
        THEN SUM(GrossRevenue)
        ELSE 0 
    END AS RevenueAtRisk,
    -- Average processing time proxy
    AVG(DATEDIFF(day, OrderDate, GETDATE())) AS AvgDaysSinceOrder
FROM Sales.vMasterBusinessAnalytics
WHERE OrderStatus IS NOT NULL
GROUP BY OrderStatus, CustomerType, IsOnlineOrder, TerritoryRegion, CurrencyCode
ORDER BY 
    CASE OrderStatus
        WHEN 'Pending' THEN 1
        WHEN 'Processing' THEN 2
        WHEN 'Shipped' THEN 3
        WHEN 'Delivered' THEN 4
        WHEN 'Completed' THEN 5
        WHEN 'Cancelled' THEN 6
        ELSE 7
    END,
    TotalRevenue DESC;


-- 6.2 Anomaly Detection - Revenue & Volume Outliers
WITH DailyMetrics AS (
    SELECT 
        OrderDate,
        CategoryName,
        CurrencyCode,
        COUNT(DISTINCT SalesOrderID) AS DailyOrders,
        SUM(GrossRevenue) AS DailyRevenue,
        AVG(GrossRevenue) AS AvgOrderValue,
        SUM(OrderQty) AS DailyQty
    FROM Sales.vMasterBusinessAnalytics
    WHERE OrderDate IS NOT NULL
    GROUP BY OrderDate, CategoryName, CurrencyCode
),
StatsCalculation AS (
    SELECT 
        *,
        AVG(DailyRevenue) OVER (PARTITION BY CategoryName) AS AvgRevenue,
        STDEV(DailyRevenue) OVER (PARTITION BY CategoryName) AS StdDevRevenue,
        AVG(DailyOrders) OVER (PARTITION BY CategoryName) AS AvgOrders,
        STDEV(DailyOrders) OVER (PARTITION BY CategoryName) AS StdDevOrders
    FROM DailyMetrics
),
AnomalyDetection AS (
    SELECT 
        *,
        -- Z-score for revenue
        (DailyRevenue - AvgRevenue) / NULLIF(StdDevRevenue, 0) AS Revenue_ZScore,
        -- Z-score for orders
        (DailyOrders - AvgOrders) / NULLIF(StdDevOrders, 0) AS Orders_ZScore
    FROM StatsCalculation
)
SELECT 
    OrderDate,
    CategoryName,
    DailyOrders,
    DailyRevenue,
    AvgOrderValue,
    -- Deviation from normal
    ROUND(Revenue_ZScore, 2) AS Revenue_ZScore,
    ROUND(Orders_ZScore, 2) AS Orders_ZScore,
    -- Anomaly classification
    CASE 
        WHEN ABS(Revenue_ZScore) > 3 OR ABS(Orders_ZScore) > 3 THEN 'Extreme Anomaly'
        WHEN ABS(Revenue_ZScore) > 2 OR ABS(Orders_ZScore) > 2 THEN 'Significant Anomaly'
        WHEN ABS(Revenue_ZScore) > 1.5 OR ABS(Orders_ZScore) > 1.5 THEN 'Moderate Anomaly'
        ELSE 'Normal'
    END AS AnomalyLevel,
    -- Direction
    CASE 
        WHEN Revenue_ZScore > 0 THEN 'Above Average'
        ELSE 'Below Average'
    END AS Direction
FROM AnomalyDetection
WHERE ABS(Revenue_ZScore) > 1.5 OR ABS(Orders_ZScore) > 1.5
ORDER BY ABS(Revenue_ZScore) DESC;


-- ============================================================================
-- SECTION 7: PREDICTIVE & FORECASTING QUERIES
-- ============================================================================

-- 7.1 Trend Analysis for Forecasting
WITH MonthlyTrend AS (
    SELECT 
        OrderYear,
        OrderMonth,
        CategoryName,
        CurrencyCode,
        SUM(GrossRevenue) AS MonthlyRevenue,
        COUNT(DISTINCT SalesOrderID) AS MonthlyOrders,
        COUNT(DISTINCT CustomerName) AS MonthlyCustomers
    FROM Sales.vMasterBusinessAnalytics
    WHERE OrderDate IS NOT NULL
    GROUP BY OrderYear, OrderMonth, CategoryName, CurrencyCode
),
TrendWithStats AS (
    SELECT 
        *,
        ROW_NUMBER() OVER (PARTITION BY CategoryName ORDER BY OrderYear, OrderMonth) AS MonthIndex,
        AVG(MonthlyRevenue) OVER (
            PARTITION BY CategoryName 
            ORDER BY OrderYear, OrderMonth 
            ROWS BETWEEN 5 PRECEDING AND CURRENT ROW
        ) AS MA6_Revenue,
        -- Linear trend approximation
        AVG(MonthlyRevenue) OVER (PARTITION BY CategoryName) AS OverallAvgRevenue
    FROM MonthlyTrend
)
SELECT 
    OrderYear,
    OrderMonth,
    CategoryName,
    MonthlyRevenue,
    MA6_Revenue,
    -- Trend direction
    CASE 
        WHEN MonthlyRevenue > MA6_Revenue * 1.1 THEN 'Strong Growth'
        WHEN MonthlyRevenue > MA6_Revenue * 1.05 THEN 'Moderate Growth'
        WHEN MonthlyRevenue > MA6_Revenue * 0.95 THEN 'Stable'
        WHEN MonthlyRevenue > MA6_Revenue * 0.90 THEN 'Moderate Decline'
        ELSE 'Strong Decline'
    END AS TrendDirection,
    -- Seasonality indicator (compare to same month last year)
    LAG(MonthlyRevenue, 12) OVER (PARTITION BY CategoryName ORDER BY OrderYear, OrderMonth) AS SameMonthLastYear,
    -- YoY change
    ROUND((MonthlyRevenue - LAG(MonthlyRevenue, 12) OVER (PARTITION BY CategoryName ORDER BY OrderYear, OrderMonth)) 
        / NULLIF(LAG(MonthlyRevenue, 12) OVER (PARTITION BY CategoryName ORDER BY OrderYear, OrderMonth), 0) * 100, 2) AS YoY_Change_Pct,
    -- Volatility
    STDEV(MonthlyRevenue) OVER (
        PARTITION BY CategoryName 
        ORDER BY OrderYear, OrderMonth 
        ROWS BETWEEN 11 PRECEDING AND CURRENT ROW
    ) AS Revenue_Volatility
FROM TrendWithStats
WHERE OrderYear >= (SELECT MAX(OrderYear) - 2 FROM Sales.vMasterBusinessAnalytics)
ORDER BY CategoryName, OrderYear DESC, OrderMonth DESC;


-- ============================================================================
-- SECTION 8: EXECUTIVE SUMMARY DASHBOARD QUERY
-- ============================================================================

-- 8.1 Comprehensive Business Health Scorecard
WITH CurrentPeriod AS (
    SELECT 
        SUM(GrossRevenueUSD)        AS CurrentRevenue,
        SUM(EstimatedNetProfitUSD)  AS CurrentProfit,
        COUNT(DISTINCT SalesOrderID)    AS CurrentOrders,
        COUNT(DISTINCT CustomerName)    AS CurrentCustomers,
        AVG(GrossRevenueUSD)        AS CurrentAOV
    FROM Sales.vMasterBusinessAnalytics
    WHERE OrderYear  = (SELECT MAX(OrderYear)  FROM Sales.vMasterBusinessAnalytics)
      AND OrderMonth = (SELECT MAX(OrderMonth) FROM Sales.vMasterBusinessAnalytics 
                        WHERE OrderYear = (SELECT MAX(OrderYear) FROM Sales.vMasterBusinessAnalytics))
    -- TIDAK GROUP BY CurrencyCode → satu baris total, semua USD
),
PriorPeriod AS (
    SELECT 
        SUM(GrossRevenueUSD)        AS PriorRevenue,
        SUM(EstimatedNetProfitUSD)  AS PriorProfit,
        COUNT(DISTINCT SalesOrderID)    AS PriorOrders,
        COUNT(DISTINCT CustomerName)    AS PriorCustomers,
        AVG(GrossRevenueUSD)        AS PriorAOV
    FROM Sales.vMasterBusinessAnalytics
    WHERE (
            OrderYear  = (SELECT MAX(OrderYear) FROM Sales.vMasterBusinessAnalytics)
        AND OrderMonth = (SELECT MAX(OrderMonth) - 1 FROM Sales.vMasterBusinessAnalytics 
                          WHERE OrderYear = (SELECT MAX(OrderYear) FROM Sales.vMasterBusinessAnalytics))
          )
       OR (
            OrderYear  = (SELECT MAX(OrderYear) - 1 FROM Sales.vMasterBusinessAnalytics)
        AND OrderMonth = 12
        AND (SELECT MAX(OrderMonth) FROM Sales.vMasterBusinessAnalytics 
             WHERE OrderYear = (SELECT MAX(OrderYear) FROM Sales.vMasterBusinessAnalytics)) = 1
          )
),
YoYPeriod AS (
    SELECT 
        SUM(GrossRevenueUSD)        AS YoYRevenue,
        SUM(EstimatedNetProfitUSD)  AS YoYProfit
    FROM Sales.vMasterBusinessAnalytics
    WHERE OrderYear  = (SELECT MAX(OrderYear) - 1 FROM Sales.vMasterBusinessAnalytics)
      AND OrderMonth = (SELECT MAX(OrderMonth) FROM Sales.vMasterBusinessAnalytics 
                        WHERE OrderYear = (SELECT MAX(OrderYear) FROM Sales.vMasterBusinessAnalytics))
)
-- Revenue
SELECT 
    'Revenue (USD)'     AS Metric,
    ROUND(c.CurrentRevenue, 2)  AS Current_Value,
    ROUND(p.PriorRevenue, 2)    AS Prior_Period_Value,
    ROUND((c.CurrentRevenue - p.PriorRevenue) / NULLIF(p.PriorRevenue, 0) * 100, 2)    AS MoM_Change_Pct,
    ROUND((c.CurrentRevenue - y.YoYRevenue)   / NULLIF(y.YoYRevenue,   0) * 100, 2)    AS YoY_Change_Pct,
    CASE 
        WHEN (c.CurrentRevenue - p.PriorRevenue) / NULLIF(p.PriorRevenue, 0) >  0.05  THEN 'Excellent'
        WHEN (c.CurrentRevenue - p.PriorRevenue) / NULLIF(p.PriorRevenue, 0) >  0     THEN 'Good'
        WHEN (c.CurrentRevenue - p.PriorRevenue) / NULLIF(p.PriorRevenue, 0) > -0.05  THEN 'Warning'
        ELSE 'Critical'
    END AS Health_Status
FROM CurrentPeriod c, PriorPeriod p, YoYPeriod y

UNION ALL

-- Profit
SELECT 
    'Profit (USD)',
    ROUND(c.CurrentProfit, 2),
    ROUND(p.PriorProfit, 2),
    ROUND((c.CurrentProfit - p.PriorProfit) / NULLIF(p.PriorProfit, 0) * 100, 2),
    ROUND((c.CurrentProfit - y.YoYProfit)   / NULLIF(y.YoYProfit,   0) * 100, 2),
    CASE 
        WHEN (c.CurrentProfit - p.PriorProfit) / NULLIF(p.PriorProfit, 0) >  0.05  THEN 'Excellent'
        WHEN (c.CurrentProfit - p.PriorProfit) / NULLIF(p.PriorProfit, 0) >  0     THEN 'Good'
        WHEN (c.CurrentProfit - p.PriorProfit) / NULLIF(p.PriorProfit, 0) > -0.05  THEN 'Warning'
        ELSE 'Critical'
    END
FROM CurrentPeriod c, PriorPeriod p, YoYPeriod y

UNION ALL

-- Profit Margin %
SELECT 
    'Profit Margin %',
    ROUND(c.CurrentProfit / NULLIF(c.CurrentRevenue, 0) * 100, 2),
    ROUND(p.PriorProfit   / NULLIF(p.PriorRevenue,   0) * 100, 2),
    -- Perubahan margin dalam percentage points (bukan %)
    ROUND((c.CurrentProfit / NULLIF(c.CurrentRevenue, 0) 
         - p.PriorProfit   / NULLIF(p.PriorRevenue,   0)) * 100, 2),
    ROUND((c.CurrentProfit / NULLIF(c.CurrentRevenue, 0) 
         - y.YoYProfit     / NULLIF(y.YoYRevenue,     0)) * 100, 2),
    CASE 
        WHEN c.CurrentProfit / NULLIF(c.CurrentRevenue, 0) > 0.25  THEN 'Excellent'
        WHEN c.CurrentProfit / NULLIF(c.CurrentRevenue, 0) > 0.15  THEN 'Good'
        WHEN c.CurrentProfit / NULLIF(c.CurrentRevenue, 0) > 0.05  THEN 'Warning'
        ELSE 'Critical'
    END
FROM CurrentPeriod c, PriorPeriod p, YoYPeriod y

UNION ALL

-- Active Customers
SELECT 
    'Active Customers',
    CAST(c.CurrentCustomers AS FLOAT),
    CAST(p.PriorCustomers   AS FLOAT),
    ROUND((c.CurrentCustomers - p.PriorCustomers) / NULLIF(CAST(p.PriorCustomers AS FLOAT), 0) * 100, 2),
    NULL,
    CASE 
        WHEN (c.CurrentCustomers - p.PriorCustomers) / NULLIF(CAST(p.PriorCustomers AS FLOAT), 0) >  0.10  THEN 'Excellent'
        WHEN (c.CurrentCustomers - p.PriorCustomers) / NULLIF(CAST(p.PriorCustomers AS FLOAT), 0) >  0     THEN 'Good'
        WHEN (c.CurrentCustomers - p.PriorCustomers) / NULLIF(CAST(p.PriorCustomers AS FLOAT), 0) > -0.05  THEN 'Warning'
        ELSE 'Critical'
    END
FROM CurrentPeriod c, PriorPeriod p

UNION ALL

-- Average Order Value
SELECT 
    'Average Order Value (USD)',
    ROUND(c.CurrentAOV, 2),
    ROUND(p.PriorAOV,   2),
    ROUND((c.CurrentAOV - p.PriorAOV) / NULLIF(p.PriorAOV, 0) * 100, 2),
    NULL,
    CASE 
        WHEN (c.CurrentAOV - p.PriorAOV) / NULLIF(p.PriorAOV, 0) >  0.05  THEN 'Excellent'
        WHEN (c.CurrentAOV - p.PriorAOV) / NULLIF(p.PriorAOV, 0) >  0     THEN 'Good'
        WHEN (c.CurrentAOV - p.PriorAOV) / NULLIF(p.PriorAOV, 0) > -0.05  THEN 'Warning'
        ELSE 'Critical'
    END
FROM CurrentPeriod c, PriorPeriod p;


-- ============================================================================
-- END OF DEEP ANALYSIS TEMPLATE
-- 
-- USAGE NOTES:
-- 1. Adjust date filters and thresholds based on your business context
-- 2. Add indexes on frequently queried columns for performance
-- 3. These queries can be converted into views or stored procedures
-- 4. Consider scheduling key queries for automated reporting
-- 5. Customize KPIs and thresholds based on your industry benchmarks
-- ============================================================================
