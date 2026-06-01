-- ============================================================
-- SQL SERVER AGENT JOB MONITORING & REPORTING QUERIES
-- ============================================================
-- Purpose: Monitor job execution, track failures, and report metrics
-- ============================================================

USE msdb;
GO

-- ============================================================
-- VIEW 1: Job Execution Summary
-- ============================================================
-- Shows status of all ETL jobs
CREATE OR ALTER VIEW vw_etl_job_summary AS
SELECT 
    j.name AS JobName,
    j.enabled AS IsEnabled,
    CASE 
        WHEN jh.last_run_status = 0 THEN 'Failed'
        WHEN jh.last_run_status = 1 THEN 'Succeeded'
        WHEN jh.last_run_status = 2 THEN 'Retry'
        WHEN jh.last_run_status = 3 THEN 'Cancelled'
        ELSE 'Unknown'
    END AS LastStatus,
    CAST(CAST(jh.last_run_date AS CHAR(8)) + ' ' + 
         RIGHT('00' + CAST(jh.last_run_time / 10000 AS VARCHAR(2)), 2) + ':' +
         RIGHT('00' + CAST((jh.last_run_time % 10000) / 100 AS VARCHAR(2)), 2) + ':' +
         RIGHT('00' + CAST(jh.last_run_time % 100 AS VARCHAR(2)), 2) AS DATETIME) AS LastRunTime,
    jh.run_duration AS LastRunDurationSeconds,
    sjs.next_run_date,
    sjs.next_run_time,
    CAST(CAST(sjs.next_run_date AS CHAR(8)) + ' ' + 
         RIGHT('00' + CAST(sjs.next_run_time / 10000 AS VARCHAR(2)), 2) + ':' +
         RIGHT('00' + CAST((sjs.next_run_time % 10000) / 100 AS VARCHAR(2)), 2) AS DATETIME) AS NextScheduledTime
FROM sysjobs j
LEFT JOIN (
    SELECT job_id, last_run_status, last_run_date, last_run_time, run_duration,
           ROW_NUMBER() OVER (PARTITION BY job_id ORDER BY instance_id DESC) AS rn
    FROM sysjobhistory
    WHERE step_id = 0  -- Job level
) jh ON j.job_id = jh.job_id AND jh.rn = 1
LEFT JOIN sysjobschedules sjs ON j.job_id = sjs.job_id
WHERE j.name LIKE 'ETL_%'
ORDER BY j.name;
GO

-- ============================================================
-- VIEW 2: Recent Job Failures
-- ============================================================
-- Shows recent failed job steps for troubleshooting
CREATE OR ALTER VIEW vw_recent_job_failures AS
SELECT TOP 50
    j.name AS JobName,
    js.step_name AS StepName,
    CAST(CAST(jh.run_date AS CHAR(8)) + ' ' + 
         RIGHT('00' + CAST(jh.run_time / 10000 AS VARCHAR(2)), 2) + ':' +
         RIGHT('00' + CAST((jh.run_time % 10000) / 100 AS VARCHAR(2)), 2) AS DATETIME) AS FailureTime,
    DATEDIFF(HOUR, CAST(CAST(jh.run_date AS CHAR(8)) + ' ' + 
                        RIGHT('00' + CAST(jh.run_time / 10000 AS VARCHAR(2)), 2) + ':' +
                        RIGHT('00' + CAST((jh.run_time % 10000) / 100 AS VARCHAR(2)), 2) AS DATETIME), 
                        GETDATE()) AS HoursSinceFailure,
    jh.run_duration AS DurationSeconds,
    jh.message AS ErrorMessage,
    jh.retries_attempted AS RetriesAttempted
FROM sysjobhistory jh
INNER JOIN sysjobs j ON jh.job_id = j.job_id
INNER JOIN sysjobsteps js ON jh.job_id = js.job_id AND jh.step_id = js.step_id
WHERE j.name LIKE 'ETL_%'
  AND jh.run_status = 0  -- Failed
  AND CAST(jh.run_date AS DATE) >= DATEADD(DAY, -7, CAST(GETDATE() AS DATE))
ORDER BY jh.run_date DESC, jh.run_time DESC;
GO

-- ============================================================
-- QUERY 1: ETL Job Performance Dashboard
-- ============================================================
-- Comprehensive job performance metrics
CREATE OR ALTER PROCEDURE sp_get_etl_job_dashboard
    @DaysToAnalyze INT = 7
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        j.name AS JobName,
        COUNT(*) AS TotalExecutions,
        SUM(CASE WHEN jh.run_status = 1 THEN 1 ELSE 0 END) AS SuccessfulExecutions,
        SUM(CASE WHEN jh.run_status = 0 THEN 1 ELSE 0 END) AS FailedExecutions,
        CAST(
            SUM(CASE WHEN jh.run_status = 1 THEN 1 ELSE 0 END) * 100.0 / 
            COUNT(*)
        AS DECIMAL(5, 2)) AS SuccessPercentage,
        AVG(jh.run_duration) AS AvgDurationSeconds,
        MIN(jh.run_duration) AS MinDurationSeconds,
        MAX(jh.run_duration) AS MaxDurationSeconds,
        MAX(CAST(CAST(jh.run_date AS CHAR(8)) + ' ' + 
                 RIGHT('00' + CAST(jh.run_time / 10000 AS VARCHAR(2)), 2) + ':' +
                 RIGHT('00' + CAST((jh.run_time % 10000) / 100 AS VARCHAR(2)), 2) AS DATETIME)) AS LastExecutionTime
    FROM sysjobs j
    INNER JOIN sysjobhistory jh ON j.job_id = jh.job_id
    WHERE j.name LIKE 'ETL_%'
      AND jh.step_id = 0  -- Job level
      AND CAST(jh.run_date AS DATE) >= DATEADD(DAY, -@DaysToAnalyze, CAST(GETDATE() AS DATE))
    GROUP BY j.name
    ORDER BY SuccessPercentage ASC, FailedExecutions DESC;
END;
GO

-- ============================================================
-- QUERY 2: Incremental Load Checkpoint Status
-- ============================================================
-- Monitor incremental load progress
CREATE OR ALTER PROCEDURE sp_get_incremental_checkpoint_status
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        source_system,
        table_name,
        last_load_time,
        DATEDIFF(HOUR, last_load_time, GETDATE()) AS HoursSinceLastLoad,
        record_count AS RecordsProcessedInLastLoad,
        CASE 
            WHEN last_status = 'SUCCESS' THEN 'OK'
            WHEN last_status = 'FAILED' THEN 'ERROR'
            WHEN last_status = 'INCOMPLETE' THEN 'WARNING'
            ELSE last_status
        END AS Status,
        CASE
            WHEN DATEDIFF(HOUR, last_load_time, GETDATE()) > 24 THEN 'CRITICAL - No load in 24+ hours'
            WHEN DATEDIFF(HOUR, last_load_time, GETDATE()) > 12 THEN 'WARNING - No load in 12+ hours'
            WHEN last_status = 'FAILED' THEN 'ERROR - Last load failed'
            ELSE 'OK - Data current'
        END AS HealthStatus,
        last_error_message
    FROM etl_incremental_checkpoints
    ORDER BY source_system, table_name;
END;
GO

-- ============================================================
-- QUERY 3: ETL Job Schedule Validation
-- ============================================================
-- Verify job schedules are properly configured
CREATE OR ALTER PROCEDURE sp_validate_etl_job_schedules
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        j.name AS JobName,
        j.enabled AS JobEnabled,
        s.name AS ScheduleName,
        s.enabled AS ScheduleEnabled,
        CASE s.freq_type
            WHEN 1 THEN 'One time'
            WHEN 4 THEN 'Daily'
            WHEN 8 THEN 'Weekly'
            WHEN 16 THEN 'Monthly'
            WHEN 32 THEN 'Monthly relative'
            WHEN 64 THEN 'When SQL Agent starts'
            ELSE 'Other'
        END AS FrequencyType,
        CASE s.freq_subday_type
            WHEN 1 THEN 'Once'
            WHEN 2 THEN 'Second'
            WHEN 4 THEN 'Minute'
            WHEN 8 THEN 'Hour'
            ELSE 'N/A'
        END AS SubdayType,
        RIGHT('0' + CAST(s.active_start_time / 10000 AS VARCHAR(2)), 2) + ':' +
        RIGHT('0' + CAST((s.active_start_time % 10000) / 100 AS VARCHAR(2)), 2) AS StartTime,
        CASE 
            WHEN j.enabled = 0 THEN 'ERROR: Job disabled'
            WHEN s.enabled = 0 THEN 'ERROR: Schedule disabled'
            ELSE 'OK'
        END AS ConfigurationStatus
    FROM sysjobs j
    LEFT JOIN sysjobschedules sjs ON j.job_id = sjs.job_id
    LEFT JOIN sysschedules s ON sjs.schedule_id = s.schedule_id
    WHERE j.name LIKE 'ETL_%'
    ORDER BY j.name;
END;
GO

-- ============================================================
-- QUERY 4: List All ETL Jobs with Details
-- ============================================================
-- Complete inventory of all ETL jobs
CREATE OR ALTER PROCEDURE sp_list_all_etl_jobs
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        j.name AS JobName,
        j.description AS JobDescription,
        CASE j.enabled WHEN 0 THEN 'Disabled' ELSE 'Enabled' END AS Status,
        COUNT(js.step_id) AS StepCount,
        STRING_AGG(js.step_name, ', ') WITHIN GROUP (ORDER BY js.step_id) AS StepNames
    FROM sysjobs j
    LEFT JOIN sysjobsteps js ON j.job_id = js.job_id
    WHERE j.name LIKE 'ETL_%'
    GROUP BY j.job_id, j.name, j.description, j.enabled
    ORDER BY j.name;
END;
GO

-- ============================================================
-- EXECUTION EXAMPLES
-- ============================================================

/*

-- 1. View job summary (daily at a glance)
SELECT * FROM vw_etl_job_summary;

-- 2. View recent failures
SELECT * FROM vw_recent_job_failures;

-- 3. Get 7-day performance dashboard
EXEC sp_get_etl_job_dashboard @DaysToAnalyze = 7;

-- 4. Check incremental load status
EXEC sp_get_incremental_checkpoint_status;

-- 5. Validate all job schedules
EXEC sp_validate_etl_job_schedules;

-- 6. List all ETL jobs
EXEC sp_list_all_etl_jobs;

*/

PRINT 'Job monitoring views and procedures created successfully!';
