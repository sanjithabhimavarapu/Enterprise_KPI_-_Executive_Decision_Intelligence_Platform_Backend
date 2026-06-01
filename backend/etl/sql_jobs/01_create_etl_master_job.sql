-- ============================================================
-- SQL SERVER AGENT JOB: ETL MASTER ORCHESTRATION
-- ============================================================
-- Purpose: Master job orchestrating incremental ETL pipeline
-- Schedule: Daily at 2:00 AM
-- Retry Logic: 3 retries with 5-minute intervals
-- ============================================================

-- Step 1: Create Job
USE msdb;
GO

-- Drop job if exists
IF EXISTS (SELECT * FROM dbo.sysjobs WHERE name = 'ETL_Master_Orchestration')
    EXEC sp_delete_job @job_name = 'ETL_Master_Orchestration', @delete_unused_schedule = 1;
GO

-- Create the job
DECLARE @ReturnCode INT = 0;
DECLARE @JobName NVARCHAR(128) = 'ETL_Master_Orchestration';
DECLARE @JobID UNIQUEIDENTIFIER;

EXEC @ReturnCode = sp_add_job 
    @job_name = @JobName,
    @enabled = 1,
    @start_step_name = 'Execute_ETL_Orchestration',
    @description = 'Master orchestration job for incremental ETL pipeline - Staging -> Dimensions -> Facts -> KPIs',
    @category_name = N'[Uncategorized (Local)]',
    @owner_login_name = N'sa',
    @job_id = @JobID OUTPUT;

IF @ReturnCode <> 0 
BEGIN
    RAISERROR('Failed to create job %s', 16, 1, @JobName);
    GOTO QuitWithRollback;
END;

PRINT 'Job created: ' + @JobName;

-- Step 2: Add job step - Main ETL Orchestration
EXEC @ReturnCode = sp_add_jobstep
    @job_id = @JobID,
    @step_name = N'Execute_ETL_Orchestration',
    @step_id = 1,
    @cmdexec_success_code = 0,
    @on_success_action = 3,  -- Go to next step
    @on_fail_action = 2,     -- Quit job with failure
    @retry_attempts = 3,
    @retry_interval = 5,     -- 5 minutes between retries
    @os_run_priority = 0,
    @subsystem = N'TSQL',
    @database_name = N'Enterprise_KPI_DW',
    @command = N'
        DECLARE @ProcessDate DATE = CAST(GETDATE() AS DATE);
        DECLARE @ErrorNumber INT;
        DECLARE @ErrorMessage NVARCHAR(MAX);
        DECLARE @ErrorSeverity INT;
        DECLARE @ErrorState INT;
        
        BEGIN TRY
            -- Execute incremental ETL
            EXEC sp_etl_master_orchestration 
                @ProcessDate = @ProcessDate,
                @ProcessType = ''INCREMENTAL'',
                @DebugMode = 0;
            
            PRINT ''ETL Master Orchestration completed successfully for date: '' + CAST(@ProcessDate AS VARCHAR(10));
        END TRY
        BEGIN CATCH
            SELECT @ErrorNumber = ERROR_NUMBER(),
                   @ErrorMessage = ERROR_MESSAGE(),
                   @ErrorSeverity = ERROR_SEVERITY(),
                   @ErrorState = ERROR_STATE();
            
            -- Log error to etl_logs
            INSERT INTO etl_logs (process_name, process_step, status, log_date, details, error_number)
            VALUES (''sp_etl_master_orchestration'', ''Execute_ETL_Orchestration'', ''FAILED'', GETDATE(), 
                    ''Error: '' + @ErrorMessage, @ErrorNumber);
            
            RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
        END CATCH;
    ';

IF @ReturnCode <> 0 
BEGIN
    RAISERROR('Failed to add step Execute_ETL_Orchestration', 16, 1);
    GOTO QuitWithRollback;
END;

-- Step 3: Add job step - Data Quality Validation
EXEC @ReturnCode = sp_add_jobstep
    @job_id = @JobID,
    @step_name = N'Validate_Data_Quality',
    @step_id = 2,
    @cmdexec_success_code = 0,
    @on_success_action = 3,  -- Go to next step
    @on_fail_action = 2,     -- Quit job with failure
    @retry_attempts = 2,
    @retry_interval = 5,
    @os_run_priority = 0,
    @subsystem = N'TSQL',
    @database_name = N'Enterprise_KPI_DW',
    @command = N'
        DECLARE @ProcessDate DATE = CAST(GETDATE() AS DATE);
        
        BEGIN TRY
            EXEC sp_data_quality_validation
                @p_process_date = @ProcessDate,
                @p_validation_type = ''INCREMENTAL'';
                
            PRINT ''Data Quality Validation completed for date: '' + CAST(@ProcessDate AS VARCHAR(10));
        END TRY
        BEGIN CATCH
            DECLARE @ErrorMessage NVARCHAR(MAX) = ERROR_MESSAGE();
            INSERT INTO etl_logs (process_name, status, log_date, details)
            VALUES (''sp_data_quality_validation'', ''FAILED'', GETDATE(), @ErrorMessage);
            RAISERROR(@ErrorMessage, 16, 1);
        END CATCH;
    ';

IF @ReturnCode <> 0 
BEGIN
    RAISERROR('Failed to add step Validate_Data_Quality', 16, 1);
    GOTO QuitWithRollback;
END;

-- Step 4: Add job step - KPI Refresh
EXEC @ReturnCode = sp_add_jobstep
    @job_id = @JobID,
    @step_name = N'Refresh_KPI_Metrics',
    @step_id = 3,
    @cmdexec_success_code = 0,
    @on_success_action = 1,  -- Quit job with success
    @on_fail_action = 2,     -- Quit job with failure
    @retry_attempts = 2,
    @retry_interval = 5,
    @os_run_priority = 0,
    @subsystem = N'TSQL',
    @database_name = N'Enterprise_KPI_DW',
    @command = N'
        DECLARE @ProcessDate DATE = CAST(GETDATE() AS DATE);
        
        BEGIN TRY
            EXEC sp_refresh_all_kpi_metrics
                @p_metric_date = @ProcessDate,
                @p_verbose = 1;
                
            INSERT INTO etl_logs (process_name, process_step, status, log_date, details)
            VALUES (''ETL_Master_Orchestration'', ''Refresh_KPI_Metrics'', ''SUCCESS'', GETDATE(), 
                    ''KPI refresh completed successfully'');
            
            PRINT ''KPI Refresh completed for date: '' + CAST(@ProcessDate AS VARCHAR(10));
        END TRY
        BEGIN CATCH
            DECLARE @ErrorMessage NVARCHAR(MAX) = ERROR_MESSAGE();
            INSERT INTO etl_logs (process_name, status, log_date, details)
            VALUES (''sp_refresh_all_kpi_metrics'', ''FAILED'', GETDATE(), @ErrorMessage);
            RAISERROR(@ErrorMessage, 16, 1);
        END CATCH;
    ';

IF @ReturnCode <> 0 
BEGIN
    RAISERROR('Failed to add step Refresh_KPI_Metrics', 16, 1);
    GOTO QuitWithRollback;
END;

-- Step 5: Create schedule - Daily at 2:00 AM
DECLARE @ScheduleName NVARCHAR(128) = 'Daily_02AM_Incremental_ETL';

IF NOT EXISTS (SELECT 1 FROM dbo.sysschedules WHERE name = @ScheduleName)
BEGIN
    EXEC sp_add_schedule
        @schedule_name = @ScheduleName,
        @freq_type = 4,           -- Daily
        @freq_interval = 1,       -- Every day
        @active_start_time = 020000,  -- 02:00 AM
        @active_start_date = CAST(CONVERT(VARCHAR(8), GETDATE(), 112) AS INT);
END;

-- Attach schedule to job
EXEC sp_attach_schedule
    @job_id = @JobID,
    @schedule_name = @ScheduleName;

PRINT 'Schedule attached: ' + @ScheduleName;

-- Step 6: Add job server
EXEC sp_add_jobserver
    @job_id = @JobID,
    @server_name = @@SERVERNAME;

PRINT 'Job server added: ' + @@SERVERNAME;

-- Success
GOTO AllDone;

QuitWithRollback:
    PRINT 'Job creation failed!';
    GOTO AllDone;

AllDone:
    PRINT 'ETL Master Orchestration job setup completed!';
GO
