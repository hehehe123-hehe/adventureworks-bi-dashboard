# 🚴 AdventureWorks 2025 — Business Intelligence Dashboard

> **End-to-end BI project**: SQL data cleaning → analytical views → Power BI dashboard (9 pages, 60+ visuals)

![Power BI](https://img.shields.io/badge/Power%20BI-F2C811?style=for-the-badge&logo=powerbi&logoColor=black)
![SQL Server](https://img.shields.io/badge/SQL%20Server-CC2927?style=for-the-badge&logo=microsoftsqlserver&logoColor=white)
![DAX](https://img.shields.io/badge/DAX-0078D4?style=for-the-badge&logo=microsoft&logoColor=white)

---

## 📋 Table of Contents

- [Project Overview](#-project-overview)
- [Database Setup](#-database-setup)
- [Project Structure](#-project-structure)
- [SQL Layer — Data Cleaning & Views](#-sql-layer--data-cleaning--views)
- [Power BI Dashboard](#-power-bi-dashboard)
- [DAX Measures Reference](#-dax-measures-reference)
- [Dashboard Pages](#-dashboard-pages)
- [Key Findings](#-key-findings)
- [Tech Stack](#-tech-stack)

---

## 🎯 Project Overview

This project transforms the **AdventureWorks 2025** database into a fully interactive Power BI dashboard for executive-level business analysis. The pipeline covers:

1. **Data Cleaning** — 6 SQL schemas cleaned and standardized via views
2. **Analytics Layer** — Golden Record view (`Sales.vMasterBusinessAnalytics`) with USD normalization and currency handling
3. **Power BI Dashboard** — 9 analytical pages covering revenue, profitability, customers, products, geography, seasonality, operations, anomaly detection, and forecasting

### Dashboard Preview

| Page | Focus |
|------|-------|
| 1 | Executive Summary |
| 2 | Revenue & Profitability |
| 3 | Customer Behavior & Segmentation |
| 4 | Product Performance Intelligence |
| 5 | Territory & Regional Performance |
| 6 | Time-Series & Seasonality |
| 7 | Operational Efficiency Metrics |
| 8 | Anomaly Detection & Outliers |
| 9 | Forecast & Scenario Planning |

---

## 🗄️ Database Setup

### 1. Download the Database

```
https://github.com/Microsoft/sql-server-samples/releases/download/adventureworks/AdventureWorks2025.bak
```

### 2. Restore to SQL Server

```sql
RESTORE DATABASE AdventureWorks2025
FROM DISK = 'C:\path\to\AdventureWorks2025.bak'
WITH 
    MOVE 'AdventureWorks2019' TO 'C:\SQLData\AdventureWorks2025.mdf',
    MOVE 'AdventureWorks2019_log' TO 'C:\SQLData\AdventureWorks2025_log.ldf',
    REPLACE;
GO
```

### 3. Verify

```sql
USE AdventureWorks2025;
SELECT name, state_desc FROM sys.databases WHERE name = 'AdventureWorks2025';
```

### Requirements

- SQL Server 2019+ (or Azure SQL)
- SQL Server Management Studio (SSMS) 18+
- Power BI Desktop (latest)

---

## 📁 Project Structure

```
AdventureWorks-BI/
│
├── 📂 sql/
│   ├── 📂 cleaning/                  # Data cleaning views per schema
│   │   ├── Master-cleaning-data-HR.sql
│   │   ├── Master-cleaning-data-Person.sql
│   │   ├── Master-cleaning-data-Production.sql
│   │   ├── Master-cleaning-data-Purchasing.sql
│   │   └── Master-cleaning-data-Sales.sql
│   │
│   ├── 📂 analytics/                 # Golden Record analytics view
│   │   └── Master-Business-analyst.sql
│   │
│   └── 📂 deep-dive/                 # Ad-hoc deep dive analysis
│       └── Deep-Dive-Analysis.sql
│
├── 📂 docs/
│   └── dashboard_blueprint.xlsx      # Full chart & DAX blueprint
|   └── DAX_REFERENCE.md
│
├── dashboard.pbix                    # Power BI dashboard file
├── SETUP.md
├── .gitignore
└── README.md

```

---

## 🧹 SQL Layer — Data Cleaning & Views

All raw tables are cleaned via `CREATE OR ALTER VIEW` — no data is modified at source.

### Schema Coverage

| Schema | Views Created | Key Transformations |
|--------|--------------|---------------------|
| `HumanResources` | 6 views | Age/tenure calc, status flags, shift hours |
| `Person` | 1 view (`vCleanPerson`) | Email normalization, full address join |
| `Production` | 4 views | Product lifecycle status, inventory alerts, scrap analysis |
| `Purchasing` | 3 views | Vendor ratings, reject rate %, lead time |
| `Sales` | 3 views | B2B/B2C segmentation, territory mapping, order status labels |

### Execution Order

```
1. sql/cleaning/Master-cleaning-data-Person.sql
2. sql/cleaning/Master-cleaning-data-HR.sql
3. sql/cleaning/Master-cleaning-data-Production.sql
4. sql/cleaning/Master-cleaning-data-Purchasing.sql
5. sql/cleaning/Master-cleaning-data-Sales.sql
6. sql/analytics/Master-Business-analyst.sql     ← Run LAST
```

> ⚠️ `Master-Business-analyst.sql` depends on views from all cleaning scripts — run it last.

---

## 📊 Power BI Dashboard

### Data Model

```
DateTable ──────────────────────────────────┐
                                            │ (Active: OrderDate)
Sales.vMasterBusinessAnalytics ─────────────┘
         │                                  (Inactive: ShipDate)
         └── Fact table (line-item grain)
```

### DateTable DAX

```dax
DateTable = 
VAR MinDate = DATE(2022, 5, 1)
VAR MaxDate = DATE(2025, 6, 30)
RETURN
ADDCOLUMNS(
    CALENDARAUTO(),
    "Year",              YEAR([Date]),
    "YearMonth",         FORMAT([Date], "YYYY-MM"),
    "YearQuarter",       "Q" & QUARTER([Date]) & " " & YEAR([Date]),
    "Quarter",           QUARTER([Date]),
    "QuarterName",       "Q" & QUARTER([Date]),
    "Month",             MONTH([Date]),
    "MonthName",         FORMAT([Date], "MMMM"),
    "MonthShort",        FORMAT([Date], "MMM"),
    "MonthYear",         FORMAT([Date], "MMM YYYY"),
    "WeekOfYear",        WEEKNUM([Date]),
    "DayOfWeek",         WEEKDAY([Date]),
    "DayName",           FORMAT([Date], "dddd"),
    "DayShort",          FORMAT([Date], "ddd"),
    "IsWeekend",         IF(WEEKDAY([Date]) IN {1, 7}, TRUE, FALSE),
    "FiscalYear",        IF(MONTH([Date]) >= 7, YEAR([Date]) + 1, YEAR([Date])),
    "DayOfMonth",        DAY([Date]),
    "IsLastDayOfMonth",  DAY([Date]) = DAY(EOMONTH([Date], 0))
)
```

---

## 📐 DAX Measures Reference

### Core Measures

```dax
Total Revenue = SUM('Sales vMasterBusinessAnalytics'[GrossRevenueUSD])

Total Profit = SUM('Sales vMasterBusinessAnalytics'[EstimatedNetProfitUSD])

Total Orders = DISTINCTCOUNT('Sales vMasterBusinessAnalytics'[SalesOrderID])

Total Customers = DISTINCTCOUNT('Sales vMasterBusinessAnalytics'[CustomerID])

Total Quantity = SUM('Sales vMasterBusinessAnalytics'[OrderQty])

Product Count = DISTINCTCOUNT('Sales vMasterBusinessAnalytics'[ProductName])

Profit Margin % = DIVIDE([Total Profit], [Total Revenue], 0)

Avg Order Value = DIVIDE([Total Revenue], [Total Orders], 0)

Avg Revenue Per Transaction = DIVIDE([Total Revenue], COUNTROWS('Sales vMasterBusinessAnalytics'), 0)
```

### Time Intelligence

```dax
PM Revenue = CALCULATE([Total Revenue], DATEADD(DateTable[Date], -1, MONTH))

PY Revenue = CALCULATE([Total Revenue], SAMEPERIODLASTYEAR(DateTable[Date]))

MoM Growth % = DIVIDE([Total Revenue] - [PM Revenue], [PM Revenue], 0)

YoY Growth % = DIVIDE([Total Revenue] - [PY Revenue], [PY Revenue], 0)

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

### RFM Calculated Columns (on `Sales vMasterBusinessAnalytics`)

```dax
-- R Score (Recency)
R Score = 
VAR CustomerLastOrder = CALCULATE(MAX([OrderDate]), ALLEXCEPT('Sales vMasterBusinessAnalytics', [CustomerID]))
VAR MaxDate = MAX([OrderDate])
VAR DaysSince = DATEDIFF(CustomerLastOrder, MaxDate, DAY)
RETURN SWITCH(TRUE(), DaysSince <= 30, 5, DaysSince <= 90, 4, DaysSince <= 180, 3, DaysSince <= 365, 2, 1)

-- F Score (Frequency)
F Score = 
VAR OrderCount = CALCULATE(DISTINCTCOUNT([SalesOrderID]), ALLEXCEPT('Sales vMasterBusinessAnalytics', [CustomerID]))
RETURN SWITCH(TRUE(), OrderCount >= 20, 5, OrderCount >= 10, 4, OrderCount >= 5, 3, OrderCount >= 2, 2, 1)

-- M Score (Monetary)
M Score = 
VAR CustomerRevenue = CALCULATE(SUM([GrossRevenueUSD]), ALLEXCEPT('Sales vMasterBusinessAnalytics', [CustomerID]))
RETURN SWITCH(TRUE(), CustomerRevenue >= 100000, 5, CustomerRevenue >= 50000, 4, CustomerRevenue >= 25000, 3, CustomerRevenue >= 10000, 2, 1)

-- Customer Segment
Customer Segment = 
VAR R = [R Score]
VAR F = [F Score]
VAR M = [M Score]
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

### Operational Metrics

```dax
Avg Processing Days = 
AVERAGEX('Sales vMasterBusinessAnalytics', 'Sales vMasterBusinessAnalytics'[DaysToShip])

Avg Orders per Day = AVERAGEX(VALUES(DateTable[Date]), [Total Orders])

Avg Items per Order = DIVIDE([Total Quantity], [Total Orders], 0)

Order Fulfillment Rate = 
DIVIDE(
    CALCULATE([Total Orders], 'Sales vMasterBusinessAnalytics'[OrderStatus] = "Shipped"),
    [Total Orders],
    0
)
```

### Anomaly Detection (Z-Score)

```dax
Revenue StdDev = 
CALCULATE(STDEV.P('Sales vMasterBusinessAnalytics'[GrossRevenueUSD]), ALLSELECTED('Sales vMasterBusinessAnalytics'))

Revenue Z-Score = 
VAR AvgRevenue = CALCULATE(AVERAGE('Sales vMasterBusinessAnalytics'[GrossRevenueUSD]), ALLSELECTED('Sales vMasterBusinessAnalytics'))
VAR Std_Dev = [Revenue StdDev]
VAR CurrentRevenue = AVERAGE('Sales vMasterBusinessAnalytics'[GrossRevenueUSD])
RETURN DIVIDE(CurrentRevenue - AvgRevenue, Std_Dev, 0)

Count of Outliers = COUNTROWS(FILTER('Sales vMasterBusinessAnalytics', ABS([Revenue Z-Score]) > 2))
```

### Forecast & Scenario Planning

```dax
-- Create via: Modeling → New Parameter → Numeric Range
-- Name: Growth Scenario | Min: -0.50 | Max: 0.50 | Increment: 0.05

Revenue Projection = 
VAR LastDataDate = CALCULATE(MAX('Sales vMasterBusinessAnalytics'[OrderDate]), ALL('Sales vMasterBusinessAnalytics'))
VAR LastMonthStart = DATE(YEAR(LastDataDate), MONTH(LastDataDate), 1)
VAR DaysInLastMonth = DATEDIFF(LastMonthStart, LastDataDate, DAY) + 1
VAR FullMonthDays = DAY(EOMONTH(LastDataDate, 0))
VAR LastMonthRev = CALCULATE([Total Revenue], 
    'Sales vMasterBusinessAnalytics'[OrderDate] >= LastMonthStart,
    'Sales vMasterBusinessAnalytics'[OrderDate] <= LastDataDate,
    ALL(DateTable))
VAR NormalizedRev = DIVIDE(LastMonthRev, DaysInLastMonth) * FullMonthDays
VAR Growth = [MoM Growth %] + [Growth Scenario Value]
RETURN ROUND(NormalizedRev * (1 + Growth), 0)

Scenario Label = 
VAR S = [Growth Scenario Value]
RETURN SWITCH(TRUE(),
    S > 0.20,  "🚀 Aggressive Growth",
    S > 0.05,  "📈 Optimistic",
    S > -0.05, "📊 Base Case",
    S > -0.20, "⚠️ Conservative",
               "🔴 Pessimistic"
)
```

---

## 📄 Dashboard Pages

### Page 1 — Executive Summary
KPI cards (Total Revenue, Profit, Orders, Margin) + MA 3-Month trend + Revenue by Category/Region + Heatmap

### Page 2 — Revenue & Profitability
MoM vs YoY growth analysis + Profit margin heatmap by segment + Discount impact table + MA 6-Month + Margin distribution by subcategory

### Page 3 — Customer Behavior & Segmentation
RFM segmentation matrix + Customer LTV distribution scatter + Top 20 customers + Retention rate trend + Segment donut + Repeat customer %

### Page 4 — Product Performance Intelligence
Product portfolio scatter (Contribution % vs YoY Growth) + Lifecycle stage donut + Pareto analysis + Profit margin by color/category + Top 20 product matrix

### Page 5 — Territory & Regional Performance
Filled map + Territory ranking table + Revenue & KPI bar by region + Combo trend chart + Territory performance matrix by year

### Page 6 — Time-Series & Seasonality
Multi-year seasonal patterns + Revenue heatmap (Month × Year) + Seasonal index line + Day-of-week revenue + Weekend vs Weekday donut + Area chart by MonthYear

### Page 7 — Operational Efficiency Metrics
Daily order velocity + Avg processing days + Online vs Offline channel + Order size distribution + Fulfillment matrix by territory + KPI cards

### Page 8 — Anomaly Detection & Outliers
Z-Score scatter + Transaction count by Z-Score band + Outlier bar by category + Anomaly transaction log + KPI cards (Mean, StdDev, Variance, Outlier %)

### Page 9 — Forecast & Scenario Planning
6-month revenue forecast + What-If scenario slider (±50%) + Profit volatility gauge + Category trend classification table + MoM vs Profit growth combo + Revenue Projection card

---

## 🔍 Key Findings

| Metric | Value |
|--------|-------|
| Total Revenue | **$105.03M** |
| Total Profit | **$8.59M** |
| Profit Margin | **8.18%** |
| Total Orders | **31K** |
| Total Customers | **19,119** |
| Top Territory | **North America** ($75M, 71%) |
| Top Category | **Bikes** ($90.36M, 86%) |
| Best Customer Segment | **Loyal Customers** (134 customers, $41.6M LTV) |
| Top Product | **Mountain-200 Black, 38** ($4.23M revenue) |
| Avg Processing Days | **7 days** (all territories) |
| Peak Month | **March** (Seasonal Index: 1.2) |
| Weekday vs Weekend | **69% Weekday** / 31% Weekend |

---

## 🛠️ Tech Stack

| Tool | Usage |
|------|-------|
| **SQL Server 2019+** | Database hosting & query engine |
| **T-SQL / Views** | Data cleaning & analytics layer |
| **Power BI Desktop** | Dashboard development |
| **DAX** | Measures, calculated columns, What-If parameters |
| **Power Query (M)** | Minor data transformations |

---

## 👥 Authors

Built by **[@hehehe123-hehe](https://github.com/hehehe123-hehe)**

---

## 📄 License

This project uses the AdventureWorks sample database provided by Microsoft under the [MIT License](https://github.com/microsoft/sql-server-samples/blob/master/license.txt).

Project code and documentation: MIT License — free to use, modify, and distribute with attribution.
