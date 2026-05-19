-- ============================================================
-- MASTER ETL ORCHESTRATION PROCEDURE
-- ============================================================
-- Purpose: Orchestrate entire ETL pipeline
-- Flow: Staging -> Dimensions -> Facts -> KPIs
-- Includes: Error handling, logging, validation, reconciliation
-- ============================================================

CREATE PROCEDURE sp_etl_master_orchestration
    @ProcessDate DATE,
    @ProcessType VARCHAR(20) = 'INCREMENTAL',  -- INCREMENTAL or FULL_REFRESH
    @DebugMode BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartDateTime DATETIME2 = GETDATE();
    DECLARE @CurrentStep VARCHAR(200);
    DECLARE @StepStartTime DATETIME2;
    DECLARE @RecordsProcessed INT = 0;
    DECLARE @IsFullRefresh BIT = CASE WHEN @ProcessType = 'FULL_REFRESH' THEN 1 ELSE 0 END;
    
    BEGIN TRY
        -- ==================================================
        -- STEP 1: VALIDATE PROCESS DATE & PREREQUISITES
        -- ==================================================
        SET @CurrentStep = 'Validate Process Date and Prerequisites';
        SET @StepStartTime = GETDATE();
        
        IF @DebugMode = 1 PRINT 'Starting: ' + @CurrentStep;
        
        IF @ProcessDate > CAST(GETDATE() AS DATE)
        BEGIN
            RAISERROR('Process date cannot be in the future', 16, 1);
        END;
        
        -- Verify staging tables have data
        DECLARE @RawOrdersCount INT = (SELECT COUNT(*) FROM stg_raw_erp_orders WHERE CAST(LOAD_DATE AS DATE) = @ProcessDate);
        DECLARE @RawCustomersCount INT = (SELECT COUNT(*) FROM stg_raw_salesforce_customers WHERE CAST(LOAD_DATE AS DATE) = @ProcessDate);
        
        IF @RawOrdersCount = 0 AND @RawCustomersCount = 0
        BEGIN
            RAISERROR('No data found in staging tables for process date', 16, 1);
        END;
        
        INSERT INTO etl_logs (process_name, process_step, record_count, status, log_date, details)
        VALUES ('sp_etl_master_orchestration', @CurrentStep, 0, 'SUCCESS', @ProcessDate,
                'Validation complete. Orders: ' + CAST(@RawOrdersCount AS VARCHAR(10)) + 
                ' | Customers: ' + CAST(@RawCustomersCount AS VARCHAR(10)));
        
        -- ==================================================
        -- STEP 2: TRANSFORM STAGING DATA
        -- ==================================================
        SET @CurrentStep = 'Transform ERP Orders';
        SET @StepStartTime = GETDATE();
        
        IF @DebugMode = 1 PRINT 'Starting: ' + @CurrentStep;
        
        EXEC sp_transform_erp_orders
            @LoadStartDateTime = CAST(@ProcessDate AS DATETIME2),
            @LoadEndDateTime = DATEADD(DAY, 1, CAST(@ProcessDate AS DATETIME2)),
            @FullRefreshFlag = @IsFullRefresh;
        
        SET @RecordsProcessed = (SELECT COUNT(*) FROM stg_orders_conformed WHERE source_load_date = @ProcessDate);
        
        INSERT INTO etl_logs VALUES ('sp_etl_master_orchestration', @CurrentStep, @RecordsProcessed, 'SUCCESS', @ProcessDate,
                                    'Completed in ' + CAST(DATEDIFF(SECOND, @StepStartTime, GETDATE()) AS VARCHAR(10)) + ' seconds');
        
        -- --
        SET @CurrentStep = 'Validate Order Quality';
        SET @StepStartTime = GETDATE();
        
        IF @DebugMode = 1 PRINT 'Starting: ' + @CurrentStep;
        
        EXEC sp_validate_orders_quality;
        
        INSERT INTO etl_logs VALUES ('sp_etl_master_orchestration', @CurrentStep, 0, 'SUCCESS', @ProcessDate, 'Data quality validation completed');
        
        -- --
        SET @CurrentStep = 'Transform Salesforce Customers';
        SET @StepStartTime = GETDATE();
        
        IF @DebugMode = 1 PRINT 'Starting: ' + @CurrentStep;
        
        EXEC sp_transform_salesforce_customers
            @LoadStartDateTime = CAST(@ProcessDate AS DATETIME2),
            @LoadEndDateTime = DATEADD(DAY, 1, CAST(@ProcessDate AS DATETIME2)),
            @FullRefreshFlag = @IsFullRefresh;
        
        INSERT INTO etl_logs VALUES ('sp_etl_master_orchestration', @CurrentStep, 0, 'SUCCESS', @ProcessDate, 'Completed');
        
        -- --
        SET @CurrentStep = 'Transform Salesforce Opportunities';
        SET @StepStartTime = GETDATE();
        
        EXEC sp_transform_salesforce_opportunities
            @LoadStartDateTime = CAST(@ProcessDate AS DATETIME2),
            @LoadEndDateTime = DATEADD(DAY, 1, CAST(@ProcessDate AS DATETIME2)),
            @FullRefreshFlag = @IsFullRefresh;
        
        INSERT INTO etl_logs VALUES ('sp_etl_master_orchestration', @CurrentStep, 0, 'SUCCESS', @ProcessDate, 'Completed');
        
        -- ==================================================
        -- STEP 3: LOAD DIMENSIONS (SCD Type 2)
        -- ==================================================
        SET @CurrentStep = 'Load Dimension Customer';
        SET @StepStartTime = GETDATE();
        
        IF @DebugMode = 1 PRINT 'Starting: ' + @CurrentStep;
        
        EXEC sp_load_dim_customer @ProcessDate;
        
        INSERT INTO etl_logs VALUES ('sp_etl_master_orchestration', @CurrentStep, 0, 'SUCCESS', @ProcessDate,
                                    'Duration: ' + CAST(DATEDIFF(SECOND, @StepStartTime, GETDATE()) AS VARCHAR(10)) + 's');
        
        -- --
        SET @CurrentStep = 'Load Dimension Product';
        SET @StepStartTime = GETDATE();
        
        IF @DebugMode = 1 PRINT 'Starting: ' + @CurrentStep;
        
        EXEC sp_load_dim_product @ProcessDate;
        
        INSERT INTO etl_logs VALUES ('sp_etl_master_orchestration', @CurrentStep, 0, 'SUCCESS', @ProcessDate,
                                    'Duration: ' + CAST(DATEDIFF(SECOND, @StepStartTime, GETDATE()) AS VARCHAR(10)) + 's');
        
        -- ==================================================
        -- STEP 4: LOAD FACTS (Transactional & Aggregates)
        -- ==================================================
        SET @CurrentStep = 'Load All Fact Tables';
        SET @StepStartTime = GETDATE();
        
        IF @DebugMode = 1 PRINT 'Starting: ' + @CurrentStep;
        
        EXEC sp_load_all_facts @ProcessDate, @IsFullRefresh;
        
        INSERT INTO etl_logs VALUES ('sp_etl_master_orchestration', @CurrentStep, 0, 'SUCCESS', @ProcessDate,
                                    'Duration: ' + CAST(DATEDIFF(SECOND, @StepStartTime, GETDATE()) AS VARCHAR(10)) + 's');
        
        -- ==================================================
        -- STEP 5: DATA RECONCILIATION
        -- ==================================================
        SET @CurrentStep = 'Reconciliation Check';
        SET @StepStartTime = GETDATE();
        
        IF @DebugMode = 1 PRINT 'Starting: ' + @CurrentStep;
        
        DECLARE @StagingTotal DECIMAL(14,2) = (SELECT SUM(net_amount) FROM stg_orders_conformed WHERE source_load_date = @ProcessDate);
        DECLARE @FactsTotal DECIMAL(14,2) = (SELECT SUM(net_amount) FROM fact_sales WHERE load_date = @ProcessDate);
        DECLARE @ReconciliationVariance DECIMAL(14,2) = ABS(@StagingTotal - @FactsTotal);
        DECLARE @ReconciliationPercent DECIMAL(5,2) = 
            CASE WHEN @StagingTotal > 0 THEN (@ReconciliationVariance / @StagingTotal * 100) ELSE 0 END;
        
        IF @ReconciliationPercent > 0.01  -- Allow 0.01% variance
        BEGIN
            INSERT INTO etl_logs VALUES ('sp_etl_master_orchestration', @CurrentStep, 0, 'WARNING', @ProcessDate,
                                        'Variance: ' + CAST(@ReconciliationVariance AS VARCHAR(20)) + 
                                        ' (' + CAST(@ReconciliationPercent AS VARCHAR(10)) + '%)');
        END
        ELSE
        BEGIN
            INSERT INTO etl_logs VALUES ('sp_etl_master_orchestration', @CurrentStep, 0, 'SUCCESS', @ProcessDate,
                                        'Variance: ' + CAST(@ReconciliationVariance AS VARCHAR(20)) + 
                                        ' (' + CAST(@ReconciliationPercent AS VARCHAR(10)) + '%)');
        END;
        
        -- ==================================================
        -- STEP 6: CALCULATE KPIs
        -- ==================================================
        SET @CurrentStep = 'Calculate KPIs';
        SET @StepStartTime = GETDATE();
        
        IF @DebugMode = 1 PRINT 'Starting: ' + @CurrentStep;
        
        EXEC sp_calculate_all_kpis @ProcessDate;
        
        INSERT INTO etl_logs VALUES ('sp_etl_master_orchestration', @CurrentStep, 0, 'SUCCESS', @ProcessDate,
                                    'Duration: ' + CAST(DATEDIFF(SECOND, @StepStartTime, GETDATE()) AS VARCHAR(10)) + 's');
        
        -- ==================================================
        -- STEP 7: ARCHIVE STAGING DATA (Optional retention)
        -- ==================================================
        SET @CurrentStep = 'Archive Staging Data';
        SET @StepStartTime = GETDATE();
        
        IF @DebugMode = 1 PRINT 'Starting: ' + @CurrentStep;
        
        -- Move old staging data (>30 days) to archive
        INSERT INTO stg_archive_orders
        SELECT * FROM stg_orders_conformed
        WHERE source_load_date < DATEADD(DAY, -30, @ProcessDate);
        
        DELETE FROM stg_orders_conformed
        WHERE source_load_date < DATEADD(DAY, -30, @ProcessDate);
        
        INSERT INTO etl_logs VALUES ('sp_etl_master_orchestration', @CurrentStep, 0, 'SUCCESS', @ProcessDate, 'Archived old staging data');
        
        -- ==================================================
        -- STEP 8: FINAL SUMMARY & LOGGING
        -- ==================================================
        DECLARE @EndDateTime DATETIME2 = GETDATE();
        DECLARE @TotalDurationSeconds INT = DATEDIFF(SECOND, @StartDateTime, @EndDateTime);
        DECLARE @TotalFactsLoaded INT = (SELECT COUNT(*) FROM fact_sales WHERE load_date = @ProcessDate);
        
        PRINT '';
        PRINT '====================================================';
        PRINT 'ETL ORCHESTRATION COMPLETED SUCCESSFULLY';
        PRINT '====================================================';
        PRINT 'Process Date: ' + CAST(@ProcessDate AS VARCHAR(10));
        PRINT 'Process Type: ' + @ProcessType;
        PRINT 'Total Duration: ' + CAST(@TotalDurationSeconds AS VARCHAR(10)) + ' seconds';
        PRINT 'Total Facts Loaded: ' + CAST(@TotalFactsLoaded AS VARCHAR(20));
        PRINT 'KPIs Calculated: ' + CAST((SELECT COUNT(*) FROM kpi_results WHERE calculation_date = @ProcessDate) AS VARCHAR(10));
        PRINT '====================================================';
        
        INSERT INTO etl_logs (process_name, process_step, record_count, status, log_date, details)
        VALUES ('sp_etl_master_orchestration', 'COMPLETE', @TotalFactsLoaded, 'SUCCESS', @ProcessDate,
                'Total Duration: ' + CAST(@TotalDurationSeconds AS VARCHAR(10)) + ' seconds | ' +
                'Process Type: ' + @ProcessType);
        
    END TRY
    BEGIN CATCH
        DECLARE @ErrorNumber INT = ERROR_NUMBER();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorLine INT = ERROR_LINE();
        DECLARE @ErrorMsg NVARCHAR(MAX) = ERROR_MESSAGE();
        
        DECLARE @FullErrorMsg NVARCHAR(MAX) = 
            'Error in step: ' + @CurrentStep + ' | Error: ' + @ErrorMsg +
            ' | Line: ' + CAST(@ErrorLine AS VARCHAR(10));
        
        PRINT '';
        PRINT '====================================================';
        PRINT 'ETL ORCHESTRATION FAILED';
        PRINT '====================================================';
        PRINT @FullErrorMsg;
        PRINT 'Process Date: ' + CAST(@ProcessDate AS VARCHAR(10));
        PRINT '====================================================';
        
        INSERT INTO etl_logs (process_name, process_step, record_count, status, log_date, details)
        VALUES ('sp_etl_master_orchestration', @CurrentStep, 0, 'FAILED', @ProcessDate, @FullErrorMsg);
        
        -- Re-throw for alerting systems
        THROW @ErrorNumber, @FullErrorMsg, @ErrorSeverity;
        
    END CATCH
END;
GO

-- ============================================================
-- QUICK START SCRIPT
-- ============================================================
-- Execute the entire ETL pipeline for a specific date

PRINT 'ETL Master Orchestration Setup Complete';
PRINT '';
PRINT 'To run the complete ETL pipeline, execute:';
PRINT '  EXEC sp_etl_master_orchestration @ProcessDate = ''2024-01-15'', @ProcessType = ''INCREMENTAL'', @DebugMode = 1;';
PRINT '';
PRINT 'Or for a full refresh:';
PRINT '  EXEC sp_etl_master_orchestration @ProcessDate = ''2024-01-15'', @ProcessType = ''FULL_REFRESH'', @DebugMode = 1;';
GO
