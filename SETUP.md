# ⚡ Quick Setup Guide

## Step 1 — Download & Restore Database

```bash
# Download (±250MB)
curl -L -o AdventureWorks2025.bak \
  "https://github.com/Microsoft/sql-server-samples/releases/download/adventureworks/AdventureWorks2025.bak"
```

Restore via SSMS: **Right-click Databases → Restore Database → Device → Add .bak file**

Or via T-SQL:
```sql
RESTORE DATABASE AdventureWorks2025
FROM DISK = 'C:\Backup\AdventureWorks2025.bak'
WITH MOVE 'AdventureWorks2019'     TO 'C:\SQLData\AdventureWorks2025.mdf',
     MOVE 'AdventureWorks2019_log' TO 'C:\SQLData\AdventureWorks2025_log.ldf',
     REPLACE, STATS = 10;
GO
```

---

## Step 2 — Run SQL Scripts (IN ORDER)

```
1. sql/cleaning/Master-cleaning-data-Person.sql
2. sql/cleaning/Master-cleaning-data-HR.sql
3. sql/cleaning/Master-cleaning-data-Production.sql
4. sql/cleaning/Master-cleaning-data-Purchasing.sql
5. sql/cleaning/Master-cleaning-data-Sales.sql
6. sql/analytics/Master-Business-analyst.sql
```

Verify the main analytics view works:
```sql
SELECT TOP 10
    SalesOrderNumber, OrderDate, ShipDate, DaysToShip,
    OrderStatus, GrossRevenueUSD, CustomerName, TerritoryName
FROM Sales.vMasterBusinessAnalytics;
```

---

## Step 3 — Open Power BI Dashboard

1. Open `dashboard.pbix` in **Power BI Desktop**
2. Go to **Home → Transform Data → Data Source Settings**
3. Change server name to your SQL Server instance
4. Click **Refresh All**

---

## Troubleshooting

| Error | Fix |
|-------|-----|
| `Invalid object name 'Sales.vMasterBusinessAnalytics'` | Run cleaning scripts first, then analytics script |
| `Column 'DaysToShip' not found` | You're using old view v1.0 — re-run `Master-Business-analyst.sql` |
| Blank visuals in Power BI | Check DateTable relationship to `OrderDate` is active |
| `Revenue Projection` shows `--` | Normal if no What-If Parameter slicer on page — create via Modeling → New Parameter |
