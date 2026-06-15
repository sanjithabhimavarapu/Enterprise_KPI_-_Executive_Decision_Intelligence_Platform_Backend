@echo off
REM Power BI Connection Setup Script
REM Purpose: Test SQL Server connectivity and prepare Power BI configuration

setlocal enabledelayedexpansion

echo.
echo ========================================
echo Power BI Connection Setup
echo ========================================
echo.
echo Step 1: Testing SQL Server connectivity...
echo.

REM Test connection to SQL Server using sqlcmd
sqlcmd -S localhost -E -Q "SELECT @@VERSION;" >nul 2>&1

if %ERRORLEVEL% EQU 0 (
    echo [OK] SQL Server is accessible via Windows Authentication
    echo.
    echo Available databases:
    sqlcmd -S localhost -E -Q "SELECT name FROM sys.databases WHERE database_id > 4 ORDER BY name;" -h -1
) else (
    echo [ERROR] Cannot connect to SQL Server
    echo.
    echo Try one of these alternatives:
    echo   1. Run as Administrator
    echo   2. Use SQL Server credentials: sqlcmd -S localhost -U sa -P YourPassword
    echo   3. Use named instance: sqlcmd -S localhost\SQLEXPRESS
    echo.
    exit /b 1
)

echo.
echo ========================================
echo Step 2: SQL Server Connection Details
echo ========================================
echo.
echo For Power BI connection, use these settings:
echo.
echo Server:        localhost  (or your machine name or IP)
echo Port:          1433
echo Database:      KPI_DataWarehouse  (create if needed)
echo Authentication: Windows or SQL Server
echo.

echo Step 3: Opening Power BI Setup Guide...
echo Please follow: backend\documentation\POWER_BI_QUICK_START.md
echo.

pause
