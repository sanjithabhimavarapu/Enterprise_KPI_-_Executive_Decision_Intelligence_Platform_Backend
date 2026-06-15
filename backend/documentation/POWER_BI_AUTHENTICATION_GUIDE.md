# Power BI Connection Setup - Authentication Guide

## Your Current Setup
- **Machine**: Windows with Local SQL Server
- **Authentication Issue**: Windows Azure AD account needs SQL Server login

## 🔐 Authentication Options

### Option 1: Use SA Account (Recommended for Local Dev)

**Step 1: Get SA Password**
- Contact your SQL Server administrator
- If you set it up yourself, use that password

**Step 2: Create Database with SA**

Run in **Command Prompt as Administrator**:
```powershell
sqlcmd -S localhost -U sa -P YourSAPassword -Q "CREATE DATABASE KPI_DataWarehouse;"
```

Replace `YourSAPassword` with actual SA password.

**Step 3: In Power BI Desktop**
- Server: `localhost`
- Database: `KPI_DataWarehouse`
- Username: `sa`
- Password: `(your SA password)`

---

### Option 2: Create Windows Login for Your Account

**Step 1: Open SQL Server Management Studio (SSMS)**

**Step 2: Run this script** (as admin):
```sql
-- Connect as SA first
-- Create login for your Windows account
USE [master];
GO

CREATE LOGIN [YOUR_DOMAIN\rohithgouti35@gmail.com] FROM WINDOWS;
GO

-- Create user in database
CREATE DATABASE KPI_DataWarehouse;
GO

USE [KPI_DataWarehouse];
CREATE USER [YOUR_DOMAIN\rohithgouti35@gmail.com] FOR LOGIN [YOUR_DOMAIN\rohithgouti35@gmail.com];
ALTER ROLE db_owner ADD MEMBER [YOUR_DOMAIN\rohithgouti35@gmail.com];
GO
```

Replace `YOUR_DOMAIN` with your domain or computer name.

**Step 3: In Power BI Desktop**
- Server: `localhost`
- Database: `KPI_DataWarehouse`
- Authentication: **Windows**

---

### Option 3: Create SQL Server Login for Your Email Account

```sql
-- Create SQL login for your email
USE [master];
GO

CREATE LOGIN [Email_Login] WITH PASSWORD = 'TemporaryPassword123!';
GO

-- Create database
CREATE DATABASE KPI_DataWarehouse;
GO

USE [KPI_DataWarehouse];
CREATE USER [Email_Login] FOR LOGIN [Email_Login];
ALTER ROLE db_owner ADD MEMBER [Email_Login];
GO
```

**Step 4: In Power BI Desktop**
- Server: `localhost`
- Database: `KPI_DataWarehouse`
- Username: `Email_Login`
- Password: `TemporaryPassword123!`

---

## 📖 Easiest Path Forward

1. **Find SA Password** (check your setup notes or ask your DBA)
2. **Create Database** using SA credentials (see Option 1, Step 2)
3. **In Power BI Desktop**:
   - Connect as `sa` user
   - Use the SA password

---

## 🚀 Quick Setup Script

**Run this as Administrator in PowerShell:**

```powershell
# Set these variables
$SQLServer = "localhost"
$SAPassword = "YourSAPassword"  # Change this!
$Database = "KPI_DataWarehouse"

# Create database
sqlcmd -S $SQLServer -U sa -P $SAPassword -Q "CREATE DATABASE $Database;"

# Verify creation
sqlcmd -S $SQLServer -U sa -P $SAPassword -Q "SELECT name FROM sys.databases WHERE name='$Database';"
```

---

## ⚠️ If You Still Can't Connect

**Run diagnostics:**

```powershell
# Check SQL Server is running
Get-WmiObject -Class Win32_Service -Filter "Name='MSSQLSERVER'" | Select-Object Name, State

# Check if SQL Server Browser is running (needed for named instances)
Get-WmiObject -Class Win32_Service -Filter "Name='SQLBrowser'" | Select-Object Name, State

# Test connection
sqlcmd -S localhost -U sa -P YourPassword -Q "SELECT @@VERSION;"
```

---

## Next Steps

Once you successfully create the database:

1. **Open Power BI Desktop**
2. Click **Get Data** → **SQL Server**
3. Enter: `localhost` as server
4. Select: `KPI_DataWarehouse` database
5. Choose your authentication method
6. Load the reporting views

See [POWER_BI_LOCAL_SETUP.md](POWER_BI_LOCAL_SETUP.md) for full instructions.

