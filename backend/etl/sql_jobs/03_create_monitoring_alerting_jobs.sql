-- ============================================================
-- SQL SERVER AGENT JOBS: MONITORING & ALERTING
-- ============================================================
-- Purpose: Monitor job health, validate data, and send alerts
-- Schedules: Regular monitoring intervals
-- ============================================================

USE msdb;
GO

-- ============================================================
-- JOB 1: ETL HEALTH CHECK & MONITORING
-- ============================================================
-- Schedule: Every 30 minutes to monitor job execution

DECLARE @ReturnCode INT = 0;
DECLARE @JobName NVARCHAR(128) = 'ETL_Health_Check_Monitor';
DECLARE @JobID UNIQUEIDENTIFIER;

IF EXISTS (SELECT * FROM dbo.sysjobs WHERE name = @JobName)
    EXEC sp_delete_job @job_name = @JobName, @delete_unused_schedule = 1;
GO

DECLARE @ReturnCode INT = 0;
DECLARE @JobName NVARCHAR(128) = 'ETL_Health_Check_Monitor';
DECLARE @JobID UNIQUEIDENTIFIER;

EXEC @ReturnCode = sp_add_job 
    @job_name = @JobName,
    @enabled = 1,
    @start_step_name = 'Check_ETL_Health',
    @description = 'Monitor ETL job execution, log health metrics, and identify failures',
    @category_name = N'[Uncategorized (Local)]',
    @owner_login_name = N'sa',
    @job_id = @JobID OUTPUT;

IF @ReturnCode = 0
BEGIN
    EXEC @ReturnCode = sp_add_jobstep
        @job_id = @JobID,
        @step_name = N'Check_ETL_Health',
        @step_id = 1,
        @cmdexec_success_code = 0,
        @on_success_action = 1,
        @on_fail_action = 2,
        @subsystem = N'TSQL',
        @database_name = N'Enterprise_KPI_DW',
        @command = N'
            DECLARE @HealthCheckTime DATETIME2 = GETDATE();
            DECLARE @FailedJobCount INT;
            DECLARE @FailedStepCount INT;
            DECLARE @AlertThreshold INT = 3;  -- Alert if more than 3 failures in last 24 hours
            
            BEGIN TRY
                -- Check for failed ETL jobs in last 24 hours
                SELECT @FailedJobCount = COUNT(*)
                FROM msdb.dbo.sysjobhistory jh
                INNER JOIN msdb.dbo.sysjobs j ON jh.job_id = j.job_id
                WHERE j.name LIKE ''ETL_%''
                  AND jh.run_date >= CAST(GETDATE() - 1 AS INT)
                  AND jh.run_status = 0;  -- Failed
                
                -- Check for failed steps
                SELECT @FailedStepCount = COUNT(*)
                FROM msdb.dbo.sysjobhistory jh
                INNER JOIN msdb.dbo.sysjobs j ON jh.job_id = j.job_id
                WHERE j.name LIKE ''ETL_%''
                  AND jh.run_date >= CAST(GETDATE() - 1 AS INT)
                  AND jh.run_status = 0
                  AND jh.step_id > 0;
                
                -- Log health metrics
                INSERT INTO etl_logs (process_name, process_step, status, log_date, details)
                VALUES (''ETL_Health_Check_Monitor'', ''Check_ETL_Health'', ''SUCCESS'', @HealthCheckTime,
                        ''Failed Jobs: '' + CAST(@FailedJobCount AS VARCHAR(5)) + 
                        '' | Failed Steps: '' + CAST(@FailedStepCount AS VARCHAR(5)));
                
                -- Alert if threshold exceeded
                IF @FailedJobCount > @AlertThreshold
                BEGIN
                    INSERT INTO etl_alerts (alert_type, severity, alert_time, message)
                    VALUES (''MULTIPLE_JOB_FAILURES'', ''HIGH'', @HealthCheckTime,
                            ''WARNING: '' + CAST(@FailedJobCount AS VARCHAR(5)) + 
                            '' ETL jobs failed in last 24 hours'');
                            
                    -- You can add email notification here using sp_send_dbmail
                END;
            END TRY
            BEGIN CATCH
                INSERT INTO etl_logs (process_name, status, log_date, details)
                VALUES (''ETL_Health_Check_Monitor'', ''FAILED'', @HealthCheckTime, ERROR_MESSAGE());
            END CATCH;
        ';
        
    EXEC sp_add_schedule
        @schedule_name = N'Every_30_Minutes',
        @freq_type = 4,
        @freq_interval = 1,
        @freq_subday_type = 1,  -- Minute
        @freq_subday_interval = 30;
        
    EXEC sp_attach_schedule
        @job_id = @JobID,
        @schedule_name = N'Every_30_Minutes';
        
    EXEC sp_add_jobserver @job_id = @JobID, @server_name = @@SERVERNAME;
    
    PRINT 'Job created: ' + @JobName;
END;
GO

-- ============================================================
-- JOB 2: DATA FRESHNESS VALIDATION
-- ============================================================
-- Schedule: Daily at 3:00 AM (after master orchestration)

DECLARE @ReturnCode INT = 0;
DECLARE @JobName NVARCHAR(128) = 'ETL_Data_Freshness_Validation';
DECLARE @JobID UNIQUEIDENTIFIER;

IF EXISTS (SELECT * FROM dbo.sysjobs WHERE name = @JobName)
    EXEC sp_delete_job @job_name = @JobName, @delete_unused_schedule = 1;
GO

DECLARE @ReturnCode INT = 0;
DECLARE @JobName NVARCHAR(128) = 'ETL_Data_Freshness_Validation';
DECLARE @JobID UNIQUEIDENTIFIER;

EXEC @ReturnCode = sp_add_job 
    @job_name = @JobName,
    @enabled = 1,
    @start_step_name = 'Validate_Data_Freshness',
    @description = 'Validate that data warehouse contains current data',
    @category_name = N'[Uncategorized (Local)]',
    @owner_login_name = N'sa',
    @job_id = @JobID OUTPUT;

IF @ReturnCode = 0
BEGIN
    EXEC @ReturnCode = sp_add_jobstep
        @job_id = @JobID,
        @step_name = N'Validate_Data_Freshness',
        @step_id = 1,
        @cmdexec_success_code = 0,
        @on_success_action = 1,
        @on_fail_action = 2,
        @retry_attempts = 1,
        @subsystem = N'TSQL',
        @database_name = N'Enterprise_KPI_DW',
        @command = N'
            DECLARE @ValidationTime DATETIME2 = GETDATE();
            DECLARE @MaxFactDate DATE;
            DECLARE @MaxDimensionDate DATE;
            DECLARE @ProcessDate DATE = CAST(GETDATE() - 1 AS DATE);
            DECLARE @FreshnessAlert VARCHAR(MAX);
            
            BEGIN TRY
                -- Check fact table currency
                SELECT @MaxFactDate = MAX(CAST(fact_date AS DATE))
                FROM fact_orders;
                
                -- Check dimension table currency
                SELECT @MaxDimensionDate = MAX(CAST(dw_load_date AS DATE))
                FROM dim_customer;
                
                -- Validate freshness (should be same day or previous day)
                IF @MaxFactDate < @ProcessDate
                BEGIN
                    SET @FreshnessAlert = ''STALE_DATA: Fact tables not updated for '' + 
                        CAST(DATEDIFF(DAY, @MaxFactDate, @ProcessDate) AS VARCHAR(3)) + '' days'';
                    
                    INSERT INTO etl_alerts (alert_type, severity, alert_time, message)
                    VALUES (''DATA_STALENESS'', ''HIGH'', @ValidationTime, @FreshnessAlert);
                    
                    INSERT INTO etl_logs (process_name, status, log_date, details)
                    VALUES (''ETL_Data_Freshness_Validation'', ''WARNING'', @ValidationTime, @FreshnessAlert);
                END;
                ELSE
                BEGIN
                    INSERT INTO etl_logs (process_name, status, log_date, details)
                    VALUES (''ETL_Data_Freshness_Validation'', ''SUCCESS'', @ValidationTime,
                            ''Data is current - Fact Date: '' + CAST(@MaxFactDate AS VARCHAR(10)));
                END;
            END TRY
            BEGIN CATCH
                INSERT INTO etl_logs (process_name, status, log_date, details)
                VALUES (''ETL_Data_Freshness_Validation'', ''FAILED'', @ValidationTime, 
                        ERROR_MESSAGE());
                RAISERROR(ERROR_MESSAGE(), 16, 1);
            END CATCH;
        ';
        
    EXEC sp_add_schedule
        @schedule_name = N'Daily_0300AM_Freshness_Check',
        @freq_type = 4,
        @freq_interval = 1,
        @active_start_time = 030000;
        
    EXEC sp_attach_schedule
        @job_id = @JobID,
        @schedule_name = N'Daily_0300AM_Freshness_Check';
        
    EXEC sp_add_jobserver @job_id = @JobID, @server_name = @@SERVERNAME;
    
    PRINT 'Job created: ' + @JobName;
END;
GO

-- ============================================================
-- JOB 3: INCREMENTAL CHECKPOINT CLEANUP & MAINTENANCE
-- ============================================================
-- Schedule: Weekly on Sundays at 4:00 AM

DECLARE @ReturnCode INT = 0;
DECLARE @JobName NVARCHAR(128) = 'ETL_Checkpoint_Maintenance';
DECLARE @JobID UNIQUEIDENTIFIER;

IF EXISTS (SELECT * FROM dbo.sysjobs WHERE name = @JobName)
    EXEC sp_delete_job @job_name = @JobName, @delete_unused_schedule = 1;
GO

DECLARE @ReturnCode INT = 0;
DECLARE @JobName NVARCHAR(128) = 'ETL_Checkpoint_Maintenance';
DECLARE @JobID UNIQUEIDENTIFIER;

EXEC @ReturnCode = sp_add_job 
    @job_name = @JobName,
    @enabled = 1,
    @start_step_name = 'Maintain_Checkpoints',
    @description = 'Archive old checkpoints and optimize incremental load tables',
    @category_name = N'[Uncategorized (Local)]',
    @owner_login_name = N'sa',
    @job_id = @JobID OUTPUT;

IF @ReturnCode = 0
BEGIN
    EXEC @ReturnCode = sp_add_jobstep
        @job_id = @JobID,
        @step_name = N'Maintain_Checkpoints',
        @step_id = 1,
        @cmdexec_success_code = 0,
        @on_success_action = 3,
        @on_fail_action = 2,
        @subsystem = N'TSQL',
        @database_name = N'Enterprise_KPI_DW',
        @command = N'
            DECLARE @MaintenanceTime DATETIME2 = GETDATE();
            DECLARE @ArchiveDate DATE = DATEADD(MONTH, -3, CAST(GETDATE() AS DATE));
            DECLARE @ArchivedRows INT;
            
            BEGIN TRY
                -- Archive old checkpoints (older than 3 months)
                INSERT INTO etl_checkpoint_archive
                SELECT * FROM etl_incremental_checkpoints
                WHERE last_load_time < @ArchiveDate;
                
                SET @ArchivedRows = @@ROWCOUNT;
                
                DELETE FROM etl_incremental_checkpoints
                WHERE last_load_time < @ArchiveDate;
                
                -- Rebuild indexes on checkpoint table
                DBCC DBREINDEX (''etl_incremental_checkpoints'', '', 80);
                
                INSERT INTO etl_logs (process_name, record_count, status, log_date, details)
                VALUES (''ETL_Checkpoint_Maintenance'', @ArchivedRows, ''SUCCESS'', @MaintenanceTime,
                        ''Archived '' + CAST(@ArchivedRows AS VARCHAR(10)) + '' checkpoint records'');
            END TRY
            BEGIN CATCH
                INSERT INTO etl_logs (process_name, status, log_date, details)
                VALUES (''ETL_Checkpoint_Maintenance'', ''FAILED'', @MaintenanceTime, ERROR_MESSAGE());
            END CATCH;
        ';
        
    EXEC @ReturnCode = sp_add_jobstep
        @job_id = @JobID,
        @step_name = N'Optimize_ETL_Tables',
        @step_id = 2,
        @cmdexec_success_code = 0,
        @on_success_action = 1,
        @on_fail_action = 2,
        @subsystem = N'TSQL',
        @database_name = N'Enterprise_KPI_DW',
        @command = N'
            BEGIN TRY
                -- Update statistics on staging tables
                UPDATE STATISTICS stg_raw_erp_orders;
                UPDATE STATISTICS stg_raw_salesforce_customers;
                UPDATE STATISTICS stg_raw_inventory;
                
                INSERT INTO etl_logs (process_name, status, log_date, details)
                VALUES (''ETL_Table_Optimization'', ''SUCCESS'', GETDATE(), 
                        ''Statistics updated on staging tables'');
            END TRY
            BEGIN CATCH
                INSERT INTO etl_logs (process_name, status, log_date, details)
                VALUES (''ETL_Table_Optimization'', ''FAILED'', GETDATE(), ERROR_MESSAGE());
            END CATCH;
        ';
        
    EXEC sp_add_schedule
        @schedule_name = N'Weekly_Sunday_0400AM_Maintenance',
        @freq_type = 8,           -- Weekly
        @freq_interval = 1,       -- Sunday
        @active_start_time = 040000;
        
    EXEC sp_attach_schedule
        @job_id = @JobID,
        @schedule_name = N'Weekly_Sunday_0400AM_Maintenance';
        
    EXEC sp_add_jobserver @job_id = @JobID, @server_name = @@SERVERNAME;
    
    PRINT 'Job created: ' + @JobName;
END;
GO

PRINT 'All monitoring and alerting jobs created successfully!';
