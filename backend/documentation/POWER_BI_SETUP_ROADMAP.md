# Power BI Connection Setup - Master Roadmap

## 📋 Your Setup Configuration

| Item | Status |
|------|--------|
| Power BI Desktop | ✅ Installed |
| Local SQL Server | ✅ Running |
| KPI_DataWarehouse Database | ⏳ Needs Setup |
| Power BI Connection | ⏳ Pending |

---

## 🚀 Complete Setup Workflow

### Phase 1: Database & Authentication (⏱️ 5-10 minutes)

**Step 1.1: Determine Authentication Method**

Choose ONE of these:
- 🟢 **Option A: SQL Server Login (SA)** ← Easiest for local dev
  - [Guide](POWER_BI_AUTHENTICATION_GUIDE.md#option-1-use-sa-account-recommended-for-local-dev)
  - Requirements: SA password
  - Complexity: Simple
  
- 🟡 **Option B: Windows AD Account** 
  - [Guide](POWER_BI_AUTHENTICATION_GUIDE.md#option-2-create-windows-login-for-your-account)
  - Requirements: Admin access
  - Complexity: Moderate

- 🔴 **Option C: New SQL Login**
  - [Guide](POWER_BI_AUTHENTICATION_GUIDE.md#option-3-create-sql-server-login-for-your-email-account)
  - Requirements: Access to SSMS
  - Complexity: Moderate

**→ Recommended: START WITH OPTION A (SA Account)**

---

**Step 1.2: Create Database**

Run in PowerShell (as Administrator):

```powershell
# Variables - customize these
$Server = "localhost"
$SAPassword = "YourSAPassword"     # ← CHANGE THIS
$Database = "KPI_DataWarehouse"

# Create the database
sqlcmd -S $Server -U sa -P $SAPassword -Q "CREATE DATABASE $Database;"

# Verify it was created
sqlcmd -S $Server -U sa -P $SAPassword -Q "SELECT name FROM sys.databases WHERE name='$Database';"
```

**✓ Expected output**: Should show `KPI_DataWarehouse`

---

**Step 1.3: Verify Connection**

```powershell
# Test the connection
sqlcmd -S localhost -U sa -P YourSAPassword -Q "SELECT @@VERSION;"
```

**✓ Expected output**: SQL Server version info (e.g., "Microsoft SQL Server 2019...")

---

### Phase 2: Power BI Connection (⏱️ 10-15 minutes)

**Step 2.1: Open Power BI Desktop**

**Step 2.2: Connect to Database**

1. Click **Get Data** → **SQL Server**
2. Enter these details:
   - **Server**: `localhost`
   - **Database**: `KPI_DataWarehouse`
   - Click **OK**

**Step 2.3: Authenticate**

Choose based on your authentication method from Phase 1:

**If using SA Login:**
- Choose: **Database** (not Windows)
- Username: `sa`
- Password: `YourSAPassword`
- Click **Connect**

**If using Windows Auth:**
- Choose: **Windows**
- Click **Connect**

**✓ Expected**: Navigator window opens showing database objects

---

**Step 2.4: Select Views to Load**

In the Navigator window, check these views:

- [ ] `vw_daily_financial_summary`
- [ ] `vw_executive_kpi_dashboard`
- [ ] `vw_employee_sales_performance`
- [ ] `vw_monthly_financial_segment_summary`
- [ ] `vw_customer_revenue_analysis`
- [ ] `vw_inventory_kpi_summary`
- [ ] `vw_sla_operational_metrics`
- [ ] `vw_recent_orchestrations`

Click **Load**

**Note**: These views will load successfully only after you:
1. Deploy the database schema (`backend/database/schema/`)
2. Deploy the stored procedures (`backend/database/stored_procedures/`)
3. Run the warehouse views (`backend/database/warehouse/`)

---

### Phase 3: Dashboard Creation (⏱️ 30-60 minutes)

Follow the detailed guide: [POWER_BI_LOCAL_SETUP.md](POWER_BI_LOCAL_SETUP.md#-step-7-create-first-dashboard)

Or use the comprehensive guide: [POWER_BI_IMPLEMENTATION_CHECKLIST.md](POWER_BI_IMPLEMENTATION_CHECKLIST.md)

---

## 📚 Documentation Map

```
Power BI Setup Documentation
├── THIS FILE → Master Roadmap (START HERE)
├── POWER_BI_AUTHENTICATION_GUIDE.md
│   ├── Option A: SA Account
│   ├── Option B: Windows Auth
│   └── Option C: SQL Login
├── POWER_BI_LOCAL_SETUP.md
│   └── Step-by-step for your setup
├── POWER_BI_QUICK_START.md
│   └── 5-minute quick start
├── POWER_BI_SETUP_GUIDE.md
│   └── Comprehensive 10-step guide
├── POWER_BI_IMPLEMENTATION_CHECKLIST.md
│   └── Track progress with 10 phases
└── powerbi_config.json
    └── Configuration templates
```

---

## ✅ Success Checklist

- [ ] **Phase 1 Complete**: Database created & connection verified
- [ ] **Phase 2 Complete**: Power BI connected to database
- [ ] **Views Load**: All 8+ views showing in Power BI
- [ ] **Dashboard Created**: At least 1 visual working
- [ ] **Ready**: Ready for production setup

---

## 🆘 Troubleshooting Quick Links

| Problem | Solution |
|---------|----------|
| "Login failed" | → [Authentication Guide](POWER_BI_AUTHENTICATION_GUIDE.md) |
| "Cannot connect to server" | → [POWER_BI_LOCAL_SETUP.md#troubleshooting](POWER_BI_LOCAL_SETUP.md#%EF%B8%8F-troubleshooting) |
| "Views not found" | Deploy schema first (backend/database/schema/) |
| "No data in views" | Deploy stored procedures + run ETL |
| "Slow performance" | See [KPI_OPTIMIZATION_GUIDE.md](architecture/KPI_OPTIMIZATION_GUIDE.md) |

---

## 🎯 Next Action

**Choose your authentication option and proceed:**

1. [I know the SA password → Use Option A](POWER_BI_AUTHENTICATION_GUIDE.md#option-1-use-sa-account-recommended-for-local-dev)
2. [I have admin access → Use Option B](POWER_BI_AUTHENTICATION_GUIDE.md#option-2-create-windows-login-for-your-account)
3. [I'll create a new login → Use Option C](POWER_BI_AUTHENTICATION_GUIDE.md#option-3-create-sql-server-login-for-your-email-account)

---

## 📞 Support Resources

- **Full Setup Guide**: [POWER_BI_SETUP_GUIDE.md](POWER_BI_SETUP_GUIDE.md)
- **Configuration Template**: [powerbi_config.json](../configs/powerbi_config.json)
- **Database Schema**: [backend/database/schema/](../database/schema/)
- **SQL Views**: [backend/database/warehouse/](../database/warehouse/)

---

**Last Updated**: 2026-06-16  
**Status**: Ready for Setup

