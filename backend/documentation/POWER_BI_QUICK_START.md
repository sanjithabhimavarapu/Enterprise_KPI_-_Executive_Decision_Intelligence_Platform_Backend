# Power BI Quick Setup (5-Minute Start)

## 1️⃣ Get Database Credentials
```
Server: your_server.database.windows.net (or local server)
Database: KPI_DataWarehouse
Port: 1433
Auth: SQL Server or Azure AD
```

## 2️⃣ Connect in Power BI Desktop
1. **Get Data** → **SQL Server**
2. Enter server/database from Step 1
3. Click **Connect** → Enter credentials

## 3️⃣ Import Core Views (Start Here)
✓ `vw_daily_financial_summary`
✓ `vw_executive_kpi_dashboard`
✓ `vw_employee_sales_performance`

Click **Load**

## 4️⃣ Verify Relationships
Go to **Model** view → Check all dimension/fact links exist

## 5️⃣ Create Your First Dashboard
- Add **KPI Card** from `vw_executive_kpi_dashboard`
- Add **Revenue Trend** line chart from `vw_daily_financial_summary`
- Add **Sales Leaderboard** table from `vw_employee_sales_performance`

## 6️⃣ Publish to Service
**File** → **Publish** → Select workspace

## 7️⃣ Configure Refresh (Power BI Service)
1. Go to **Datasets**
2. Click **⋯** → **Settings**
3. Set refresh: **Daily at 03:00 AM**

---

## 📊 All Available Views

| View | Purpose |
|------|---------|
| `vw_daily_financial_summary` | Revenue/Profit daily |
| `vw_monthly_financial_segment_summary` | Monthly by segment |
| `vw_employee_sales_performance` | Sales team metrics |
| `vw_executive_kpi_dashboard` | Executive KPIs |
| `vw_customer_revenue_analysis` | Customer profitability |
| `vw_inventory_kpi_summary` | Inventory health |
| `vw_sla_operational_metrics` | SLA compliance |
| `vw_recent_orchestrations` | ETL pipeline status |

**Full list**: See [POWER_BI_SETUP_GUIDE.md](POWER_BI_SETUP_GUIDE.md)

---

## 🆘 Common Issues

| Problem | Solution |
|---------|----------|
| Can't connect | Check credentials, firewall port 1433 |
| Refresh fails | Verify gateway, check logs |
| Slow queries | Use view instead of joins, check row count |
| No data | Confirm ETL ran successfully |

---

## 📞 Support
- **Connection Issues**: See "Troubleshooting" in [POWER_BI_SETUP_GUIDE.md](POWER_BI_SETUP_GUIDE.md)
- **SQL Questions**: Check `warehouse/01_optimized_reporting_views.sql`
- **Data Questions**: See `data_dictionary/` folder

