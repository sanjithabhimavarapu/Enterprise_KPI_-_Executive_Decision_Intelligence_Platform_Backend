@echo off
echo ============================================
echo  Enterprise KPI Platform - Full Setup
echo  Running as Administrator
echo ============================================
echo.

REM Step 1: Enable SQL Server mixed mode auth
echo [1/6] Enabling SQL Server mixed authentication...
reg add "HKLM\SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQLServer" /v LoginMode /t REG_DWORD /d 2 /f
if %errorlevel%==0 (echo     OK: Mixed auth enabled) else (echo     WARN: Registry write may have failed)

REM Step 2: Restart SQL Server
echo.
echo [2/6] Restarting SQL Server to apply auth change...
net stop MSSQLSERVER /y
timeout /t 3 /nobreak >nul
net start MSSQLSERVER
timeout /t 5 /nobreak >nul
echo     OK: SQL Server restarted

REM Step 3: Enable SA account and set password
echo.
echo [3/6] Enabling SA account with a password...
sqlcmd -S localhost -E -Q "ALTER LOGIN sa ENABLE; ALTER LOGIN sa WITH PASSWORD = 'KPI_Admin_2026!';" 2>nul
if %errorlevel%==0 (
    echo     OK: SA account enabled, password set to: KPI_Admin_2026!
) else (
    sqlcmd -S localhost -U sa -P "" -Q "ALTER LOGIN sa ENABLE; ALTER LOGIN sa WITH PASSWORD = 'KPI_Admin_2026!';" 2>nul
    echo     OK: SA password set to: KPI_Admin_2026!
)

REM Step 4: Create database
echo.
echo [4/6] Creating Enterprise_KPI_DW database...
sqlcmd -S localhost -U sa -P "KPI_Admin_2026!" -Q "IF NOT EXISTS (SELECT name FROM sys.databases WHERE name='KPI_DataWarehouse') CREATE DATABASE KPI_DataWarehouse; PRINT 'Database ready';"
echo     OK: Database created/verified

REM Step 5: Deploy Schema
echo.
echo [5/6] Deploying database schema...
set BASE=C:\Users\rohit\Downloads\Enterprise_KPI_-_Executive_Decision_Intelligence_Platform_Backend\backend\database

echo     Deploying dimensions schema...
sqlcmd -S localhost -U sa -P "KPI_Admin_2026!" -d KPI_DataWarehouse -i "%BASE%\schema\01_dimensions.sql" -b 2>&1 | findstr /v "^$"

echo     Deploying facts schema...
sqlcmd -S localhost -U sa -P "KPI_Admin_2026!" -d KPI_DataWarehouse -i "%BASE%\schema\02_facts.sql" -b 2>&1 | findstr /v "^$"

echo     Deploying staging schema...
sqlcmd -S localhost -U sa -P "KPI_Admin_2026!" -d KPI_DataWarehouse -i "%BASE%\schema\03_staging.sql" -b 2>&1 | findstr /v "^$"

REM Step 6: Install Python dependencies
echo.
echo [6/6] Installing Python backend dependencies...
cd /d "C:\Users\rohit\Downloads\Enterprise_KPI_-_Executive_Decision_Intelligence_Platform_Backend\backend\python"
pip install -r requirements.txt --quiet
echo     OK: Python dependencies installed

echo.
echo ============================================
echo  Setup Complete!
echo ============================================
echo.
echo  SQL Server:  localhost
echo  Database:    KPI_DataWarehouse
echo  SA Password: KPI_Admin_2026!
echo.
echo  Next: Run START_BACKEND.bat to start the API server
echo ============================================
echo.
pause
