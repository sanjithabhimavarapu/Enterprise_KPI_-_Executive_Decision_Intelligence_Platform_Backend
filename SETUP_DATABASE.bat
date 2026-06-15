@echo off
echo ============================================
echo  Creating Database and Deploying Schema
echo  Must run as Administrator
echo ============================================
echo.

set SA_PASS=KPI_Admin_2026!
set BASE=C:\Users\rohit\Downloads\Enterprise_KPI_-_Executive_Decision_Intelligence_Platform_Backend\backend\database

echo [1/5] Creating KPI_DataWarehouse database...
sqlcmd -S localhost -U sa -P "%SA_PASS%" -Q "IF NOT EXISTS (SELECT name FROM sys.databases WHERE name='KPI_DataWarehouse') BEGIN CREATE DATABASE KPI_DataWarehouse; PRINT 'Created KPI_DataWarehouse'; END ELSE PRINT 'Database already exists';"
echo.

echo [2/5] Deploying dimensions schema (tables)...
sqlcmd -S localhost -U sa -P "%SA_PASS%" -d KPI_DataWarehouse -i "%BASE%\schema\01_dimensions.sql"
echo.

echo [3/5] Deploying facts schema...
sqlcmd -S localhost -U sa -P "%SA_PASS%" -d KPI_DataWarehouse -i "%BASE%\schema\02_facts.sql"
echo.

echo [4/5] Deploying staging schema...
sqlcmd -S localhost -U sa -P "%SA_PASS%" -d KPI_DataWarehouse -i "%BASE%\schema\03_staging.sql"
echo.

echo [5/5] Deploying stored procedures...
sqlcmd -S localhost -U sa -P "%SA_PASS%" -d KPI_DataWarehouse -i "%BASE%\stored_procedures\01_sp_load_dimensions.sql"
sqlcmd -S localhost -U sa -P "%SA_PASS%" -d KPI_DataWarehouse -i "%BASE%\stored_procedures\02_sp_load_facts.sql"
sqlcmd -S localhost -U sa -P "%SA_PASS%" -d KPI_DataWarehouse -i "%BASE%\stored_procedures\03_sp_calculate_kpis.sql"
sqlcmd -S localhost -U sa -P "%SA_PASS%" -d KPI_DataWarehouse -i "%BASE%\stored_procedures\04_sp_etl_master_orchestration.sql"
sqlcmd -S localhost -U sa -P "%SA_PASS%" -d KPI_DataWarehouse -i "%BASE%\stored_procedures\06_sp_data_quality_validation.sql"
sqlcmd -S localhost -U sa -P "%SA_PASS%" -d KPI_DataWarehouse -i "%BASE%\stored_procedures\08_sp_kpi_optimization.sql"
echo.

echo ============================================
echo Verifying deployment...
echo ============================================
sqlcmd -S localhost -U sa -P "%SA_PASS%" -d KPI_DataWarehouse -Q "SELECT 'Tables: ' + CAST(COUNT(*) AS VARCHAR) AS Info FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE='BASE TABLE'; SELECT 'Procedures: ' + CAST(COUNT(*) AS VARCHAR) AS Info FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_TYPE='PROCEDURE';"

echo.
echo ============================================
echo  Database setup complete!
echo  Next: Double-click START_BACKEND.bat
echo ============================================
pause
