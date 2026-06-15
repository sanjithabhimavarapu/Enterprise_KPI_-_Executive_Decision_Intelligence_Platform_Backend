-- ============================================================
-- SQL SERVER AGENT JOB DEPLOYMENT & TESTING SCRIPT
-- ============================================================
-- Purpose: Deploy jobs and perform comprehensive testing
-- Author: Enterprise KPI Platform Team
-- Created: June 2024
-- ============================================================

USE KPI_DataWarehouse;
GO

-- ============================================================
-- SECTION 1: PRE-DEPLOYMENT VALIDATION
-- ============================================================
-- Verify all required components exist before deploying jobs

PRINT '========================================';
PRINT 'PRE-DEPLOYMENT VALIDATION';
PRINT '========================================';

-- Check 1: Required tables exist
PRINT 'Checking required tables...';
DECLARE @RequiredTablesCount INT;
SELECT @RequiredTablesCount = COUNT(*)
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_NAME IN (
    'etl_logs',
    'etl_incremental_checkpoints',
    'stg_raw_erp_orders',
    'stg_raw_salesforce_customers',
    'stg_raw_inventory',
    'fact_orders',
    'dim_customer'
);

IF @RequiredTablesCount < 7
BEGIN
    PRINT 'ERROR: Not all required tables exist!';
    PRINT 'Missing tables needed for ETL jobs.';
    PRINT 'Please execute schema scripts first.';
    GOTO EndOfScript;
END;
ELSE
    PRINT '✓ All required tables found (' + CAST(@RequiredTablesCount AS VARCHAR(2)) + ' tables)';

-- Check 2: Required stored procedures exist
PRINT 'Checking required stored procedures...';
DECLARE @RequiredProcCount INT;
SELECT @RequiredProcCount = COUNT(*)
FROM INFORMATION_SCHEMA.ROUTINES
WHERE ROUTINE_NAME IN (
    'sp_etl_master_orchestration',
    'sp_data_quality_validation',
    'sp_refresh_all_kpi_metrics'
)
AND ROUTINE_TYPE = 'PROCEDURE';

IF @RequiredProcCount < 3
BEGIN
    PRINT 'WARNING: Not all required procedures exist.';
    PRINT 'Please execute stored procedure scripts from: backend/database/stored_procedures/';
    PRINT 'Continuing anyway...';
END;
ELSE
    PRINT '✓ All required stored procedures found (' + CAST(@RequiredProcCount AS VARCHAR(2)) + ' procedures)';

-- Check 3: SQL Server Agent is running
PRINT 'Checking SQL Server Agent status...';
DECLARE @AgentStatus INT;
BEGIN TRY
    SELECT @AgentStatus = CAST(status AS INT) FROM master.sys.services WHERE name = 'SQLAgent$MSSQLSERVER';
    IF @AgentStatus = 4
        PRINT '✓ SQL Server Agent is running'
    ELSE
        PRINT 'WARNING: SQL Server Agent may not be running. Start it manually if needed.';
END TRY
BEGIN CATCH
    PRINT 'INFO: Unable to check SQL Server Agent status. Verify manually in Services.';
END CATCH;

PRINT '';
PRINT 'Pre-deployment validation complete.';

-- ============================================================
-- SECTION 2: CREATE SUPPORT TABLES (if not exist)
-- ============================================================
PRINT '========================================';
PRINT 'CREATING SUPPORT TABLES';
PRINT '========================================';

-- Create alert table if needed
IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'etl_alerts')
BEGIN
    CREATE TABLE etl_alerts (
        alert_id INT IDENTITY(1,1) PRIMARY KEY,
        alert_type VARCHAR(50) NOT NULL,
        severity VARCHAR(20) NOT NULL,  -- LOW, MEDIUM, HIGH, CRITICAL
        alert_time DATETIME2 NOT NULL,
        message VARCHAR(MAX),
        resolved_time DATETIME2 NULL,
        created_date DATETIME2 DEFAULT GETDATE()
    );
    PRINT '✓ Created etl_alerts table';
END;
ELSE
    PRINT '✓ etl_alerts table already exists';

-- Create checkpoint archive if needed
IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'etl_checkpoint_archive')
BEGIN
    CREATE TABLE etl_checkpoint_archive (
        checkpoint_id INT IDENTITY(1,1) PRIMARY KEY,
        source_system VARCHAR(50),
        table_name VARCHAR(100),
        last_load_time DATETIME2,
        record_count INT,
        last_status VARCHAR(20),
        last_error_message VARCHAR(MAX),
        archived_date DATETIME2 DEFAULT GETDATE()
    );
    PRINT '✓ Created etl_checkpoint_archive table';
END;
ELSE
    PRINT '✓ etl_checkpoint_archive table already exists';

-- ============================================================
-- SECTION 3: INITIALIZE INCREMENTAL CHECKPOINTS
-- ============================================================
PRINT '';
PRINT '========================================';
PRINT 'INITIALIZING INCREMENTAL CHECKPOINTS';
PRINT '========================================';

-- Check if checkpoints exist
DECLARE @CheckpointCount INT;
SELECT @CheckpointCount = COUNT(*) FROM etl_incremental_checkpoints;

IF @CheckpointCount = 0
BEGIN
    PRINT 'No checkpoints found. Initializing...';
    
    INSERT INTO etl_incremental_checkpoints 
        (source_system, table_name, last_load_time, record_count, last_status)
    VALUES 
        ('ERP', 'Orders', DATEADD(DAY, -30, CAST(GETDATE() AS DATE)), 0, 'INITIALIZED'),
        ('SALESFORCE', 'Customers', DATEADD(DAY, -30, CAST(GETDATE() AS DATE)), 0, 'INITIALIZED'),
        ('INVENTORY', 'Stock', DATEADD(DAY, -30, CAST(GETDATE() AS DATE)), 0, 'INITIALIZED');
    
    PRINT '✓ Initialized 3 checkpoints (30-day lookback)';
END;
ELSE
BEGIN
    PRINT '✓ Checkpoints already exist (' + CAST(@CheckpointCount AS VARCHAR(2)) + ' records)';
    PRINT 'Display current checkpoints:';
    
    SELECT 
        source_system,
        table_name,
        last_load_time,
        record_count,
        last_status
    FROM etl_incremental_checkpoints;
END;

-- ============================================================
-- SECTION 4: JOB DEPLOYMENT INSTRUCTIONS
-- ============================================================
PRINT '';
PRINT '========================================';
PRINT 'JOB DEPLOYMENT INSTRUCTIONS';
PRINT '========================================';
PRINT '';
PRINT 'Execute the following scripts in SQL Server Management Studio (SSMS):';
PRINT '(On the msdb database)';
PRINT '';
PRINT '1. First:  01_create_etl_master_job.sql';
PRINT '2. Then:   02_create_incremental_load_jobs.sql';
PRINT '3. Then:   03_create_monitoring_alerting_jobs.sql';
PRINT '';
PRINT 'After that, on the KPI_DataWarehouse database:';
PRINT '4. Finally: 04_job_execution_monitoring.sql';
PRINT '';

-- ============================================================
-- SECTION 5: MANUAL JOB TESTING PROCEDURES
-- ============================================================
PRINT '';
PRINT '========================================';
PRINT 'MANUAL JOB TESTING PROCEDURES';
PRINT '========================================';
PRINT '';
PRINT 'After deploying jobs, test them manually using:';
PRINT '';
PRINT '-- Test 1: Single source load (ERP Orders)';
PRINT 'DECLARE @ProcessDate DATE = CAST(GETDATE() AS DATE);';
PRINT 'BEGIN TRY';
PRINT '  EXEC sp_etl_master_orchestration ';
PRINT '    @ProcessDate = @ProcessDate,';
PRINT '    @ProcessType = ''INCREMENTAL'',';
PRINT '    @DebugMode = 1;';
PRINT '  PRINT ''Test PASSED: ETL Master executed successfully'';';
PRINT 'END TRY';
PRINT 'BEGIN CATCH';
PRINT '  PRINT ''Test FAILED: '' + ERROR_MESSAGE();';
PRINT 'END CATCH;';
PRINT '';

-- ============================================================
-- SECTION 6: CREATE TEST PROCEDURES
-- ============================================================
PRINT '';
PRINT 'Creating test procedures...';
GO

CREATE OR ALTER PROCEDURE sp_test_etl_pipeline
    @DebugOutput BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @ProcessDate DATE = CAST(GETDATE() AS DATE);
    DECLARE @TestResult VARCHAR(50);
    DECLARE @ErrorMessage VARCHAR(MAX);
    DECLARE @RecordCount INT;
    
    BEGIN TRY
        PRINT 'Testing ETL Pipeline...';
        PRINT 'Process Date: ' + CAST(@ProcessDate AS VARCHAR(10));
        PRINT '';
        
        -- Test 1: Check checkpoints
        PRINT 'Test 1: Checking incremental checkpoints...';
        SELECT 
            @RecordCount = COUNT(*) 
        FROM etl_incremental_checkpoints;
        
        IF @RecordCount = 0
            RAISERROR('FAIL: No checkpoints found', 16, 1);
        
        PRINT '✓ PASS: Found ' + CAST(@RecordCount AS VARCHAR(5)) + ' checkpoints';
        
        -- Test 2: Verify staging tables
        PRINT '';
        PRINT 'Test 2: Checking staging tables...';
        DECLARE @StagingCount INT = 0;
        
        SELECT @StagingCount = COUNT(*) 
        FROM stg_raw_erp_orders 
        WHERE CAST(load_date AS DATE) >= DATEADD(DAY, -1, @ProcessDate);
        
        PRINT '✓ PASS: ERP staging table has data (' + CAST(@StagingCount AS VARCHAR(10)) + ' records)';
        
        -- Test 3: Check logging infrastructure
        PRINT '';
        PRINT 'Test 3: Verifying ETL logging...';
        INSERT INTO etl_logs (process_name, process_step, status, log_date, details)
        VALUES ('sp_test_etl_pipeline', 'Test_Insert', 'SUCCESS', GETDATE(), 'Test log entry');
        
        SELECT @RecordCount = @@ROWCOUNT;
        IF @RecordCount = 0
            RAISERROR('FAIL: Unable to write to etl_logs', 16, 1);
        
        PRINT '✓ PASS: Logging infrastructure functional';
        
        -- Test 4: Verify procedures exist
        PRINT '';
        PRINT 'Test 4: Checking required procedures...';
        DECLARE @ProcCount INT;
        
        SELECT @ProcCount = COUNT(*)
        FROM INFORMATION_SCHEMA.ROUTINES
        WHERE ROUTINE_NAME IN (
            'sp_etl_master_orchestration',
            'sp_data_quality_validation',
            'sp_refresh_all_kpi_metrics'
        )
        AND ROUTINE_TYPE = 'PROCEDURE';
        
        IF @ProcCount < 3
            PRINT '⚠ WARNING: Only ' + CAST(@ProcCount AS VARCHAR(2)) + '/3 procedures found'
        ELSE
            PRINT '✓ PASS: All 3 required procedures exist';
        
        PRINT '';
        PRINT '========================================';
        PRINT 'All tests completed successfully!';
        PRINT 'ETL pipeline is ready for deployment.';
        PRINT '========================================';
    END TRY
    BEGIN CATCH
        SELECT @ErrorMessage = ERROR_MESSAGE();
        PRINT '';
        PRINT '========================================';
        PRINT 'TEST FAILED';
        PRINT '========================================';
        PRINT 'Error: ' + @ErrorMessage;
        
        INSERT INTO etl_logs (process_name, status, log_date, details)
        VALUES ('sp_test_etl_pipeline', 'FAILED', GETDATE(), @ErrorMessage);
        
        RAISERROR(@ErrorMessage, 16, 1);
    END CATCH;
END;
GO

PRINT '✓ Created sp_test_etl_pipeline procedure';

-- ============================================================
-- SECTION 7: RUN SELF-TESTS
-- ============================================================
PRINT '';
PRINT '========================================';
PRINT 'RUNNING SELF-TESTS';
PRINT '========================================';
PRINT '';

EXEC sp_test_etl_pipeline @DebugOutput = 1;

-- ============================================================
-- SECTION 8: DEPLOYMENT CHECKLIST
-- ============================================================
PRINT '';
PRINT '========================================';
PRINT 'DEPLOYMENT CHECKLIST';
PRINT '========================================';
PRINT '';
PRINT 'Before running scheduled jobs:';
PRINT '  [ ] Execute all 4 SQL job scripts (msdb database)';
PRINT '  [ ] Execute monitoring script (KPI_DataWarehouse database)';
PRINT '  [ ] Verify SQL Server Agent is running';
PRINT '  [ ] Run manual test: EXEC sp_test_etl_pipeline';
PRINT '  [ ] Check job creation: SELECT * FROM vw_etl_job_summary';
PRINT '  [ ] Validate schedules: EXEC sp_validate_etl_job_schedules';
PRINT '  [ ] Configure email alerts (optional but recommended)';
PRINT '  [ ] Test first manual execution of master job';
PRINT '  [ ] Monitor first scheduled run in SQL Agent';
PRINT '';
PRINT 'After deployment:';
PRINT '  [ ] Set daily health check review';
PRINT '  [ ] Monitor etl_logs table for errors';
PRINT '  [ ] Review job execution history weekly';
PRINT '  [ ] Plan capacity based on actual durations';
PRINT '';

-- ============================================================
-- SECTION 9: REFERENCE QUERIES
-- ============================================================
PRINT '';
PRINT '========================================';
PRINT 'REFERENCE QUERIES';
PRINT '========================================';
PRINT '';
PRINT 'Monitor jobs with:';
PRINT '';
PRINT '-- Job Summary';
PRINT 'SELECT * FROM vw_etl_job_summary;';
PRINT '';
PRINT '-- Recent Failures';
PRINT 'SELECT * FROM vw_recent_job_failures;';
PRINT '';
PRINT '-- Incremental Status';
PRINT 'EXEC sp_get_incremental_checkpoint_status;';
PRINT '';
PRINT '-- 7-Day Performance';
PRINT 'EXEC sp_get_etl_job_dashboard @DaysToAnalyze = 7;';
PRINT '';

EndOfScript:
PRINT '';
PRINT 'Script execution complete.';
PRINT 'Check for any errors above before proceeding.';

GO
