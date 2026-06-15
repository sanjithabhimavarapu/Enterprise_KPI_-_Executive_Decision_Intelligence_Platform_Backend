@echo off
echo ============================================
echo  Fixing SA Account (Single-User Mode)
echo  Must run as Administrator
echo ============================================
echo.

REM Add -m startup flag to start SQL Server in single-user mode
echo [1/5] Adding single-user startup flag...
reg add "HKLM\SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQLServer\Parameters" /v SQLArg3 /t REG_SZ /d "-m" /f
echo     OK

REM Restart SQL Server with single-user mode
echo.
echo [2/5] Restarting SQL Server in single-user mode...
net stop MSSQLSERVER /y
timeout /t 4 /nobreak >nul
net start MSSQLSERVER
timeout /t 6 /nobreak >nul
echo     OK

REM Connect using Windows auth (works in single-user mode for local admin)
echo.
echo [3/5] Enabling SA account and setting password...
sqlcmd -S localhost -E -Q "ALTER LOGIN sa ENABLE; ALTER LOGIN sa WITH PASSWORD = 'KPI_Admin_2026!'; PRINT 'SA account enabled successfully';"
echo     Done

REM Remove the single-user mode flag
echo.
echo [4/5] Removing single-user startup flag...
reg delete "HKLM\SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQLServer\Parameters" /v SQLArg3 /f
echo     OK

REM Restart SQL Server normally
echo.
echo [5/5] Restarting SQL Server normally...
net stop MSSQLSERVER /y
timeout /t 4 /nobreak >nul
net start MSSQLSERVER
timeout /t 6 /nobreak >nul
echo     OK

echo.
echo ============================================
echo Testing SA login...
echo ============================================
sqlcmd -S localhost -U sa -P "KPI_Admin_2026!" -Q "SELECT name FROM sys.databases ORDER BY name;"

echo.
echo ============================================
echo If databases listed above - SA login works!
echo Now run: SETUP_DATABASE.bat (as Admin)
echo ============================================
pause
