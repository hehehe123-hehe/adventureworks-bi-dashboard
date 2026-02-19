# 📐 DAX Measures — Complete Reference

> All measures and calculated columns used in the AdventureWorks 2025 Power BI dashboard

---

## Table of Contents
- [Core KPI Measures](#core-kpi-measures)
- [Time Intelligence](#time-intelligence)
- [Moving Averages](#moving-averages)
- [Customer Analytics](#customer-analytics)
- [RFM Calculated Columns](#rfm-calculated-columns)
- [Product Analytics](#product-analytics)
- [Operational Metrics](#operational-metrics)
- [Anomaly Detection](#anomaly-detection)
- [Forecast & Scenario](#forecast--scenario)
- [Seasonal Analysis](#seasonal-analysis)
- [Channel Analysis](#channel-analysis)

---

## Core KPI Measures

```dax
Total Revenue =
SUM('Sales vMasterBusinessAnalytics'[GrossRevenueUSD])

Total Profit =
SUM('Sales vMasterBusinessAnalytics'[EstimatedNetProfitUSD])

Total Orders =
DISTINCTCOUNT('Sales vMasterBusinessAnalytics'[SalesOrderID])

Total Customers =
DISTINCTCOUNT('Sales vMasterBusinessAnalytics'[CustomerID])

Total Quantity =
SUM('Sales vMasterBusinessAnalytics'[OrderQty])

Product Count =
DISTINCTCOUNT('Sales vMasterBusinessAnalytics'[ProductName])

Profit Margin % =
DIVIDE([Total Profit], [Total Revenue], 0)

Avg Order Value =
DIVIDE([Total Revenue], [Total Orders], 0)

Avg Revenue Per Transaction =
DIVIDE([Total Revenue], COUNTROWS('Sales vMasterBusinessAnalytics'), 0)

Mean Revenue =
AVERAGE('Sales vMasterBusinessAnalytics'[GrossRevenueUSD])
```

---

## Time Intelligence

```dax
PM Revenue =
CALCULATE([Total Revenue], DATEADD(DateTable[Date], -1, MONTH))

PY Revenue =
CALCULATE([Total Revenue], SAMEPERIODLASTYEAR(DateTable[Date]))

PM Profit =
CALCULATE([Total Profit], DATEADD(DateTable[Date], -1, MONTH))

MoM Growth % =
DIVIDE([Total Revenue] - [PM Revenue], [PM Revenue], 0)

YoY Growth % =
DIVIDE([Total Revenue] - [PY Revenue], [PY Revenue], 0)

MoM Profit Growth % =
DIVIDE([Total Profit] - [PM Profit], [PM Profit], 0)

Health Status =
VAR MoMGrowth = [MoM Growth %]
RETURN
SWITCH(TRUE(),
    MoMGrowth > 5,   "📈 Excellent Growth",
    MoMGrowth > 0,   "✅ Positive Growth",
    MoMGrowth > -5,  "⚠️ Warning - Slight Decline",
                     "🔴 Critical - Significant Decline"
)

Revenue 2022 = CALCULATE([Total Revenue], DateTable[Year] = 2022)
Revenue 2023 = CALCULATE([Total Revenue], DateTable[Year] = 2023)
Revenue 2024 = CALCULATE([Total Revenue], DateTable[Year] = 2024)
Revenue 2025 = CALCULATE([Total Revenue], DateTable[Year] = 2025)
```

---

## Moving Averages

```dax
MA 3-Month =
CALCULATE(
    [Total Revenue],
    DATESINPERIOD(DateTable[Date], LASTDATE(DateTable[Date]), -3, MONTH)
) / 3

MA 6-Month =
CALCULATE(
    [Total Revenue],
    DATESINPERIOD(DateTable[Date], LASTDATE(DateTable[Date]), -6, MONTH)
) / 6
```

---

## Customer Analytics

```dax
Customer LTV =
CALCULATE(
    [Total Revenue],
    ALLEXCEPT('Sales vMasterBusinessAnalytics',
        'Sales vMasterBusinessAnalytics'[CustomerID],
        'Sales vMasterBusinessAnalytics'[Customer Segment],
        DateTable[Year],
        'Sales vMasterBusinessAnalytics'[CustomerName]
    )
)

Days Since Last Order =
VAR MaxOrderDate = MAX('Sales vMasterBusinessAnalytics'[OrderDate])
VAR GlobalMaxDate = CALCULATE(MAX('Sales vMasterBusinessAnalytics'[OrderDate]), ALL('Sales vMasterBusinessAnalytics'))
RETURN DATEDIFF(MaxOrderDate, GlobalMaxDate, DAY)

Retention Rate =
VAR CurrentCustomers = VALUES('Sales vMasterBusinessAnalytics'[CustomerID])
VAR PreviousCustomers =
    CALCULATETABLE(
        VALUES('Sales vMasterBusinessAnalytics'[CustomerID]),
        DATEADD(DateTable[Date], -1, MONTH)
    )
VAR RetainedCustomers = COUNTROWS(INTERSECT(CurrentCustomers, PreviousCustomers))
RETURN DIVIDE(RetainedCustomers, COUNTROWS(PreviousCustomers), 0)

Repeat Customer % =
VAR RepeatCustomers =
    COUNTROWS(
        FILTER(
            ADDCOLUMNS(VALUES('Sales vMasterBusinessAnalytics'[CustomerID]),
                "OrderCount", [Total Orders]),
            [OrderCount] > 1
        )
    )
RETURN DIVIDE(RepeatCustomers, [Total Customers], 0)
```

---

## RFM Calculated Columns

> Add these as **Calculated Columns** on `Sales vMasterBusinessAnalytics` table

```dax
-- R Score (Recency — how recently did they buy?)
R Score =
VAR CustomerLastOrder =
    CALCULATE(MAX('Sales vMasterBusinessAnalytics'[OrderDate]),
        ALLEXCEPT('Sales vMasterBusinessAnalytics', 'Sales vMasterBusinessAnalytics'[CustomerID]))
VAR MaxDate = MAX('Sales vMasterBusinessAnalytics'[OrderDate])
VAR DaysSince = DATEDIFF(CustomerLastOrder, MaxDate, DAY)
RETURN
SWITCH(TRUE(),
    DaysSince <= 30,  5,
    DaysSince <= 90,  4,
    DaysSince <= 180, 3,
    DaysSince <= 365, 2,
    1
)

-- F Score (Frequency — how often do they buy?)
F Score =
VAR OrderCount =
    CALCULATE(DISTINCTCOUNT('Sales vMasterBusinessAnalytics'[SalesOrderID]),
        ALLEXCEPT('Sales vMasterBusinessAnalytics', 'Sales vMasterBusinessAnalytics'[CustomerID]))
RETURN
SWITCH(TRUE(),
    OrderCount >= 20, 5,
    OrderCount >= 10, 4,
    OrderCount >= 5,  3,
    OrderCount >= 2,  2,
    1
)

-- M Score (Monetary — how much do they spend?)
M Score =
VAR CustomerRevenue =
    CALCULATE(SUM('Sales vMasterBusinessAnalytics'[GrossRevenueUSD]),
        ALLEXCEPT('Sales vMasterBusinessAnalytics', 'Sales vMasterBusinessAnalytics'[CustomerID]))
RETURN
SWITCH(TRUE(),
    CustomerRevenue >= 100000, 5,
    CustomerRevenue >= 50000,  4,
    CustomerRevenue >= 25000,  3,
    CustomerRevenue >= 10000,  2,
    1
)

-- Customer Segment (based on R/F/M scores)
Customer Segment =
VAR R = 'Sales vMasterBusinessAnalytics'[R Score]
VAR F = 'Sales vMasterBusinessAnalytics'[F Score]
VAR M = 'Sales vMasterBusinessAnalytics'[M Score]
RETURN
SWITCH(TRUE(),
    R >= 4 && F >= 4 && M >= 4, "Champions",
    R >= 3 && F >= 3 && M >= 4, "Loyal Customers",
    R >= 4 && F <= 2 && M >= 3, "Big Spenders",
    R <= 2 && F >= 3 && M >= 3, "At Risk",
    R <= 2 && F >= 4,           "Can't Lose Them",
    R <= 2,                     "Lost",
                                "Regular"
)
```

---

## Product Analytics

```dax
Product Contribution % =
DIVIDE(
    [Total Revenue],
    CALCULATE([Total Revenue], ALL('Sales vMasterBusinessAnalytics'[ProductName])),
    0
)

Product Velocity =
DIVIDE([Total Quantity], [Total Orders], 0)

Top20 Products Revenue =
CALCULATE(
    [Total Revenue],
    TOPN(
        ROUNDUP([Product Count] * 0.2, 0),
        ALL('Sales vMasterBusinessAnalytics'[ProductName]),
        [Total Revenue]
    )
)

Pareto Ratio =
DIVIDE([Top20 Products Revenue], [Total Revenue], 0) * 100

-- Product Lifecycle Stage (Calculated Column)
Product Lifecycle Stage =
VAR ReferenceDate = CALCULATE(MAX('Sales vMasterBusinessAnalytics'[OrderDate]), ALL('Sales vMasterBusinessAnalytics'))
VAR FirstOrderDate = CALCULATE(MIN('Sales vMasterBusinessAnalytics'[OrderDate]),
    ALLEXCEPT('Sales vMasterBusinessAnalytics', 'Sales vMasterBusinessAnalytics'[ProductName]))
VAR LastOrderDate = CALCULATE(MAX('Sales vMasterBusinessAnalytics'[OrderDate]),
    ALLEXCEPT('Sales vMasterBusinessAnalytics', 'Sales vMasterBusinessAnalytics'[ProductName]))
VAR DaysSinceFirst = DATEDIFF(FirstOrderDate, ReferenceDate, DAY)
VAR DaysSinceLast  = DATEDIFF(LastOrderDate, ReferenceDate, DAY)
VAR Status_ = 'Sales vMasterBusinessAnalytics'[ProductStatus]
VAR Growth = CALCULATE([YoY Growth %], ALLEXCEPT('Sales vMasterBusinessAnalytics', 'Sales vMasterBusinessAnalytics'[ProductName]))
RETURN
SWITCH(TRUE(),
    Status_ = "Discontinued" && DaysSinceLast > 180, "Obsolete",
    Status_ = "Discontinued",                         "Phasing Out",
    DaysSinceFirst < 180,                             "New/Launch",
    Growth > 0.20,                                    "Growth",
    Growth > 0.05,                                    "Mature/Stable",
    Growth > 0,                                       "Declining",
                                                      "Stagnant/No Growth"
)
```

---

## Operational Metrics

```dax
Avg Processing Days =
AVERAGEX(
    'Sales vMasterBusinessAnalytics',
    'Sales vMasterBusinessAnalytics'[DaysToShip]
)

Avg Orders per Day =
AVERAGEX(VALUES(DateTable[Date]), [Total Orders])

Avg Items per Order =
DIVIDE([Total Quantity], [Total Orders], 0)

Order Fulfillment Rate =
VAR SuccessOrders =
    CALCULATE([Total Orders], 'Sales vMasterBusinessAnalytics'[OrderStatus] = "Shipped")
RETURN DIVIDE(SuccessOrders, [Total Orders], 0)

Orders per Day =
DIVIDE([Total Orders], DISTINCTCOUNT(DateTable[Date]), 0)

-- Order Online (Calculated Column)
Order Online =
IF('Sales vMasterBusinessAnalytics'[IsOnlineOrder] = TRUE, "Online", "Offline")

-- Order Size Bucket (Calculated Column)
Order Size Bucket =
SWITCH(TRUE(),
    'Sales vMasterBusinessAnalytics'[GrossRevenueUSD] < 100,  "Small (<$100)",
    'Sales vMasterBusinessAnalytics'[GrossRevenueUSD] < 500,  "Medium ($100-$500)",
    'Sales vMasterBusinessAnalytics'[GrossRevenueUSD] < 2000, "Large ($500-$2K)",
    "Extra Large (>$2K)"
)

-- Discount Bucket (Calculated Column)
Discount Bucket =
SWITCH(TRUE(),
    'Sales vMasterBusinessAnalytics'[UnitPriceDiscount] = 0,    "No Discount",
    'Sales vMasterBusinessAnalytics'[UnitPriceDiscount] <= 0.05, "Small (0-5%)",
    'Sales vMasterBusinessAnalytics'[UnitPriceDiscount] <= 0.15, "Medium (5-15%)",
    'Sales vMasterBusinessAnalytics'[UnitPriceDiscount] <= 0.30, "Large (15-30%)",
    "Very Large (>30%)"
)

Avg Discount % =
AVERAGE('Sales vMasterBusinessAnalytics'[UnitPriceDiscount])

Territory Growth Rank =
RANKX(ALL('Sales vMasterBusinessAnalytics'[TerritoryName]), [YoY Growth %], , DESC, DENSE)
```

---

## Anomaly Detection

```dax
Revenue StdDev =
CALCULATE(
    STDEV.P('Sales vMasterBusinessAnalytics'[GrossRevenueUSD]),
    ALLSELECTED('Sales vMasterBusinessAnalytics')
)

Revenue Variance =
VAR.P('Sales vMasterBusinessAnalytics'[GrossRevenueUSD])

Revenue Z-Score =
VAR AvgRevenue = CALCULATE(AVERAGE('Sales vMasterBusinessAnalytics'[GrossRevenueUSD]), ALLSELECTED('Sales vMasterBusinessAnalytics'))
VAR Std_Dev = [Revenue StdDev]
VAR CurrentRevenue = AVERAGE('Sales vMasterBusinessAnalytics'[GrossRevenueUSD])
RETURN DIVIDE(CurrentRevenue - AvgRevenue, Std_Dev, 0)

Count of Outliers =
COUNTROWS(FILTER('Sales vMasterBusinessAnalytics', ABS([Revenue Z-Score]) > 2))

Outlier % of Total =
DIVIDE([Count of Outliers], COUNTROWS('Sales vMasterBusinessAnalytics'), 0)

Positive Outliers =
COUNTROWS(FILTER('Sales vMasterBusinessAnalytics', [Revenue Z-Score] > 2))

Negative Outliers =
COUNTROWS(FILTER('Sales vMasterBusinessAnalytics', [Revenue Z-Score] < -2))

Alert - Critical Count (|Z| > 3) =
COUNTROWS(FILTER('Sales vMasterBusinessAnalytics', ABS([Revenue Z-Score]) > 3))

Alert - Warning Count (2-3) =
COUNTROWS(FILTER('Sales vMasterBusinessAnalytics', ABS([Revenue Z-Score]) > 2 && ABS([Revenue Z-Score]) <= 3))

Alert - Normal Count =
COUNTROWS(FILTER('Sales vMasterBusinessAnalytics', ABS([Revenue Z-Score]) <= 2))
```

---

## Forecast & Scenario

```dax
-- ⚠️ Requires What-If Parameter: Modeling → New Parameter → Numeric Range
-- Name: Growth Scenario | Min: -0.50 | Max: 0.50 | Increment: 0.05 | Default: 0.00
-- Power BI auto-generates: Growth Scenario Value measure

Forecast Next Month =
VAR MA6 = [MA 6-Month]
VAR AvgGrowth = [MoM Growth %]
VAR ScenarioAdj = [Growth Scenario Value]
VAR TotalGrowth = AvgGrowth + ScenarioAdj
RETURN MA6 * (1 + TotalGrowth)

Revenue Projection =
VAR LastDataDate = CALCULATE(MAX('Sales vMasterBusinessAnalytics'[OrderDate]), ALL('Sales vMasterBusinessAnalytics'))
VAR LastMonthStart = DATE(YEAR(LastDataDate), MONTH(LastDataDate), 1)
VAR DaysInLastMonth = DATEDIFF(LastMonthStart, LastDataDate, DAY) + 1
VAR FullMonthDays = DAY(EOMONTH(LastDataDate, 0))
VAR LastMonthRev =
    CALCULATE([Total Revenue],
        'Sales vMasterBusinessAnalytics'[OrderDate] >= LastMonthStart,
        'Sales vMasterBusinessAnalytics'[OrderDate] <= LastDataDate,
        ALL(DateTable))
VAR NormalizedRev = DIVIDE(LastMonthRev, DaysInLastMonth) * FullMonthDays
VAR Growth = [MoM Growth %] + [Growth Scenario Value]
RETURN ROUND(NormalizedRev * (1 + Growth), 0)

Scenario Label =
VAR S = [Growth Scenario Value]
RETURN
SWITCH(TRUE(),
    S > 0.20,  "🚀 Aggressive Growth",
    S > 0.05,  "📈 Optimistic",
    S > -0.05, "📊 Base Case",
    S > -0.20, "⚠️ Conservative",
               "🔴 Pessimistic"
)

Profit Volatility =
STDEV.P('Sales vMasterBusinessAnalytics'[EstimatedNetProfitUSD]) /
AVERAGE('Sales vMasterBusinessAnalytics'[EstimatedNetProfitUSD])

Forecast Confidence =
VAR Volatility = [Revenue StdDev] / AVERAGE('Sales vMasterBusinessAnalytics'[GrossRevenueUSD])
RETURN
SWITCH(TRUE(),
    Volatility < 0.1, "🟢 High Confidence",
    Volatility < 0.3, "🟡 Medium Confidence",
                      "🔴 Low Confidence"
)

Trend Direction =
VAR MA = [MA 6-Month]
VAR CurrentRevenue = [Total Revenue]
RETURN
SWITCH(TRUE(),
    CurrentRevenue > MA * 1.10, "Strong Growth",
    CurrentRevenue > MA * 1.05, "Moderate Growth",
    CurrentRevenue > MA * 0.95, "Stable",
    CurrentRevenue > MA * 0.90, "Moderate Decline",
                                "Strong Decline"
)
```

---

## Seasonal Analysis

```dax
Seasonal Index =
VAR CurrentMonthRevenue = [Total Revenue]
VAR AvgRevenuePerMonth =
    CALCULATE(
        AVERAGEX(VALUES(DateTable[MonthName]), [Total Revenue]),
        ALLEXCEPT(DateTable, DateTable[Year])
    )
RETURN DIVIDE(CurrentMonthRevenue, AvgRevenuePerMonth)

Weekday Revenue =
CALCULATE([Total Revenue], DateTable[IsWeekend] = FALSE)

Weekend Revenue =
CALCULATE([Total Revenue], DateTable[IsWeekend] = TRUE)
```

---

## Channel Analysis

```dax
-- Calculated Column
Order Online =
IF('Sales vMasterBusinessAnalytics'[IsOnlineOrder] = TRUE, "Online", "Offline")
```

---

---

*Author: [@hehehe123-hehe](https://github.com/hehehe123-hehe)*  
*All measures use `GrossRevenueUSD` and `EstimatedNetProfitUSD` for consistent USD normalization across currencies.*
