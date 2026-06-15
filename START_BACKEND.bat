@echo off
echo ============================================
echo  Enterprise KPI Platform - Start Backend
echo ============================================
echo.
echo  API Server starting on http://localhost:5000
echo  Press Ctrl+C to stop
echo.

cd /d "C:\Users\rohit\Downloads\Enterprise_KPI_-_Executive_Decision_Intelligence_Platform_Backend\backend\python"

set DB_SERVER=localhost
set DB_NAME=KPI_DataWarehouse
set DB_USER=sa
set DB_PASSWORD=KPI_Admin_2026!
set DB_PORT=1433
set FLASK_ENV=development

python api_server.py

pause
