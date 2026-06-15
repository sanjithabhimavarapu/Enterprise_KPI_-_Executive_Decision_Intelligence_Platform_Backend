# Power BI Connection - Step-by-Step Setup for Windows Authentication

## Your Setup: Local SQL Server + Power BI Desktop

You're all set! Here's what you need:

### **Database Connection Details**

```
Server:        localhost
Port:          1433
Database:      KPI_DataWarehouse
Authentication: Windows (current user)
```

---

## 🔧 Step 1: Create/Verify Database

Run this in SQL Server Management Studio (SSMS):

```sql
-- Create database if it doesn't exist
IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'KPI_DataWarehouse')
BEGIN
    CREATE DATABASE KPI_DataWarehouse;
    PRINT 'Database created successfully';
END
ELSE
BEGIN
    PRINT 'Database already exists';
END;
GO

-- Verify connection
SELECT @@VERSION;
SELECT DB_NAME() AS CurrentDatabase;
```

**Alternative - Command Line:**
```powershell
sqlcmd -S localhost -E -Q "CREATE DATABASE KPI_DataWarehouse"
```

---

## 📊 Step 2: Open Power BI Desktop

1. Open **Power BI Desktop**
2. Click **Get Data** → **SQL Server**

---

## 🔌 Step 3: Enter Connection Details

**In the SQL Server Database dialog:**

| Field | Value |
|-------|-------|
| Server | `localhost` |
| Database | `KPI_DataWarehouse` |

Click **OK**

---

## 🔐 Step 4: Choose Authentication

**Select: Windows** (default)
- Uses your current Windows credentials
- No password needed
- Secured by your network

Click **Connect**

---

## 📁 Step 5: Load Reporting Views

In the **Navigator** window:

✓ Check these views to import:

- [ ] `vw_daily_financial_summary`
- [ ] `vw_executive_kpi_dashboard`
- [ ] `vw_employee_sales_performance`
- [ ] `vw_monthly_financial_segment_summary`
- [ ] `vw_customer_revenue_analysis`

Click **Load**

---

## 📋 Step 6: Review Data Model

1. Click **Model** view (left sidebar)
2. Verify relationships are showing (auto-detected)
3. Check that no errors appear

---

## 📊 Step 7: Create First Dashboard

1. Click **Insert** → **Text Box**
2. Type: "Executive Summary"
3. Add a **Card** visual:
   - Value: Revenue (MTD)
   - Source: `vw_daily_financial_summary`

---

## 💾 Step 8: Save & Publish

**Save Locally:**
```
File → Save
Location: backend/powerbi/
Name: Enterprise_KPI_Dashboard.pbix
```

**Publish to Cloud (Optional):**
```
File → Publish
Select Workspace: YourWorkspace
```

---

## ✅ Troubleshooting

### "Cannot connect to server"
```powershell
# Check if SQL Server is running
Get-WmiObject -Class Win32_Service -Filter "Name='MSSQLSERVER'"

# Try with named instance if default doesn't work
# Server: localhost\SQLEXPRESS
```

### "No databases showing"
- Verify you have permissions
- Try: `sqlcmd -S localhost -E -Q "SELECT name FROM sys.databases;"`

### "Views not found"
- Verify views exist in database:
```sql
SELECT * FROM INFORMATION_SCHEMA.VIEWS 
WHERE TABLE_NAME LIKE 'vw_%';
```

---

## 🚀 Next: Configure Auto-Refresh

After publishing to Power BI Service:

1. Go to **Datasets** → Your dataset → **Settings**
2. Expand **Gateway and cloud connections**
3. Set **Scheduled refresh**:
   - Frequency: **Daily**
   - Time: **03:00 AM** (after ETL at 02:00 AM)

---

## 📖 Full Documentation

For complete setup guide:
- **Full Guide**: `backend/documentation/POWER_BI_SETUP_GUIDE.md`
- **Implementation Checklist**: `backend/documentation/POWER_BI_IMPLEMENTATION_CHECKLIST.md`
- **Configuration File**: `backend/configs/powerbi_config.json`

---

**Next**: Once connected, follow [POWER_BI_IMPLEMENTATION_CHECKLIST.md](POWER_BI_IMPLEMENTATION_CHECKLIST.md) to build dashboards!

