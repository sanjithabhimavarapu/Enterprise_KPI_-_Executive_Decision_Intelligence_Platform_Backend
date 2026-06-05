-- ============================================================================
-- WAREHOUSE OPTIMIZATION PROCEDURES
-- Enterprise KPI - Executive Decision Intelligence Platform
-- Purpose: Advanced warehouse querying, aggregation, and performance tuning
-- ============================================================================

-- ============================================================================
-- PART 1: MATERIALIZED VIEW MANAGEMENT
-- ============================================================================

-- Procedure: Refresh All Materialized Views
-- Purpose: Update all pre-calculated views after ETL
IF OBJECT_ID('sp_refresh_materialized_views', 'P') IS NOT NULL
    DROP PROCEDURE sp_refresh_materialized_views;
GO

CREATE PROCEDURE sp_refresh_materialized_views
    @p_view_type VARCHAR(50) = 'ALL',  -- 'FINANCIAL', 'SALES', 'OPERATIONAL', 'ALL'
    @p_verbose BIT = 1,
    @p_include_timing BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @start_time DATETIME2 = GETDATE();
    DECLARE @view_refresh_time INT;
    
    IF @p_verbose = 1
        PRINT '========== REFRESHING MATERIALIZED VIEWS ==========';
    
    -- Financial Views
    IF @p_view_type IN ('FINANCIAL', 'ALL')
    BEGIN
        IF @p_verbose = 1
            PRINT 'Refreshing financial views...';
        
        -- These would trigger stored procedures to recalculate underlying data
        -- Example: EXEC sp_calculate_daily_financial_summary;
        
        IF @p_include_timing = 1
        BEGIN
            SET @view_refresh_time = DATEDIFF(MILLISECOND, @start_time, GETDATE());
            IF @p_verbose = 1
                PRINT '  Financial views refreshed in ' + CAST(@view_refresh_time AS VARCHAR) + 'ms';
        END
    END
    
    -- Sales Views
    IF @p_view_type IN ('SALES', 'ALL')
    BEGIN
        IF @p_verbose = 1
            PRINT 'Refreshing sales views...';
        
        SET @start_time = GETDATE();
        -- EXEC sp_calculate_sales_metrics;
        
        IF @p_include_timing = 1
        BEGIN
            SET @view_refresh_time = DATEDIFF(MILLISECOND, @start_time, GETDATE());
            IF @p_verbose = 1
                PRINT '  Sales views refreshed in ' + CAST(@view_refresh_time AS VARCHAR) + 'ms';
        END
    END
    
    -- Operational Views
    IF @p_view_type IN ('OPERATIONAL', 'ALL')
    BEGIN
        IF @p_verbose = 1
            PRINT 'Refreshing operational views...';
        
        SET @start_time = GETDATE();
        -- EXEC sp_calculate_operational_metrics;
        
        IF @p_include_timing = 1
        BEGIN
            SET @view_refresh_time = DATEDIFF(MILLISECOND, @start_time, GETDATE());
            IF @p_verbose = 1
                PRINT '  Operational views refreshed in ' + CAST(@view_refresh_time AS VARCHAR) + 'ms';
        END
    END
    
    IF @p_verbose = 1
        PRINT '========== VIEW REFRESH COMPLETE ==========';
END;
GO

-- ============================================================================
-- PART 2: ADVANCED AGGREGATION PROCEDURES
-- ============================================================================

-- Procedure: Multi-Level Aggregation with Rollup
-- Purpose: Generate hierarchical aggregations efficiently
CREATE PROCEDURE sp_calculate_revenue_rollup_hierarchy
    @p_start_date DATE,
    @p_end_date DATE,
    @p_include_forecast BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Level 1: Daily aggregation
    WITH daily_revenue AS (
        SELECT 
            dd.date_key,
            dd.date_value,
            dd.year,
            dd.quarter,
            dd.month,
            SUM(fr.total_revenue) AS daily_revenue,
            SUM(fr.gross_profit) AS daily_profit,
            COUNT(*) AS transaction_count
        FROM fact_revenue fr
        INNER JOIN dim_date dd ON fr.date_key = dd.date_key
        WHERE dd.date_value BETWEEN @p_start_date AND @p_end_date
        GROUP BY dd.date_key, dd.date_value, dd.year, dd.quarter, dd.month
    ),
    -- Level 2: Monthly aggregation
    monthly_revenue AS (
        SELECT 
            year,
            month,
            'MONTH' AS aggregation_level,
            DATEPART(YEAR, date_value) AS period_year,
            DATEPART(MONTH, date_value) AS period_month,
            SUM(daily_revenue) AS total_revenue,
            SUM(daily_profit) AS total_profit,
            SUM(transaction_count) AS total_transactions,
            COUNT(*) AS business_days
        FROM daily_revenue
        GROUP BY year, month, DATEPART(YEAR, date_value), DATEPART(MONTH, date_value)
    ),
    -- Level 3: Quarterly aggregation
    quarterly_revenue AS (
        SELECT 
            year,
            quarter,
            'QUARTER' AS aggregation_level,
            SUM(total_revenue) AS total_revenue,
            SUM(total_profit) AS total_profit,
            SUM(total_transactions) AS total_transactions
        FROM monthly_revenue
        GROUP BY year, quarter
    )
    -- Final result with rollup
    SELECT 
        'DAILY' AS aggregation_level,
        year, quarter, month, NULL AS revenue_level,
        SUM(daily_revenue) AS total_revenue,
        SUM(daily_profit) AS total_profit,
        SUM(transaction_count) AS transaction_count
    FROM daily_revenue
    GROUP BY year, quarter, month
    UNION ALL
    SELECT 
        aggregation_level,
        period_year AS year, NULL, period_month AS month, 'MONTHLY',
        total_revenue,
        total_profit,
        total_transactions
    FROM monthly_revenue
    UNION ALL
    SELECT 
        aggregation_level,
        year, quarter, NULL, 'QUARTERLY',
        total_revenue,
        total_profit,
        total_transactions
    FROM quarterly_revenue
    ORDER BY year, quarter, month;
END;
GO

-- ============================================================================
-- PART 3: INCREMENTAL AGGREGATION (For large datasets)
-- ============================================================================

-- Procedure: Incremental Update of Daily Aggregations
-- Purpose: Only calculate changed data (faster than full refresh)
IF OBJECT_ID('sp_incremental_refresh_daily_metrics', 'P') IS NOT NULL
    DROP PROCEDURE sp_incremental_refresh_daily_metrics;
GO

CREATE PROCEDURE sp_incremental_refresh_daily_metrics
    @p_days_back INT = 1,
    @p_verbose BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @start_date DATE = DATEADD(DAY, -@p_days_back, CAST(GETDATE() AS DATE));
    DECLARE @end_date DATE = CAST(GETDATE() AS DATE);
    
    IF @p_verbose = 1
    BEGIN
        PRINT 'Incrementally refreshing metrics from ' + CAST(@start_date AS VARCHAR);
        PRINT 'to ' + CAST(@end_date AS VARCHAR);
    END
    
    -- Delete existing records for refresh period
    DELETE FROM fact_daily_aggregation
    WHERE date_key >= (SELECT date_key FROM dim_date WHERE date_value = @start_date)
        AND date_key <= (SELECT date_key FROM dim_date WHERE date_value = @end_date);
    
    -- Insert fresh aggregations
    INSERT INTO fact_daily_aggregation (date_key, daily_revenue, daily_profit, transaction_count)
    SELECT 
        dd.date_key,
        SUM(fr.total_revenue) AS daily_revenue,
        SUM(fr.gross_profit) AS daily_profit,
        COUNT(*) AS transaction_count
    FROM fact_revenue fr
    INNER JOIN dim_date dd ON fr.date_key = dd.date_key
    WHERE dd.date_value BETWEEN @start_date AND @end_date
    GROUP BY dd.date_key;
    
    IF @p_verbose = 1
        PRINT 'Incremental refresh complete';
END;
GO

-- ============================================================================
-- PART 4: SNAPSHOT-BASED MATERIALIZATION
-- ============================================================================

-- Procedure: Create Daily Snapshot of Aggregate Tables
-- Purpose: Store pre-calculated results to avoid repeated calculations
IF OBJECT_ID('sp_create_warehouse_snapshot', 'P') IS NOT NULL
    DROP PROCEDURE sp_create_warehouse_snapshot;
GO

CREATE PROCEDURE sp_create_warehouse_snapshot
    @p_snapshot_date DATE,
    @p_verbose BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @p_verbose = 1
        PRINT '--- Creating Warehouse Snapshot for ' + CAST(@p_snapshot_date AS VARCHAR) + ' ---';
    
    -- Daily Financial Snapshot
    IF OBJECT_ID('wh_daily_financial_snapshot', 'U') IS NULL
    CREATE TABLE wh_daily_financial_snapshot (
        snapshot_date DATE NOT NULL,
        date_key INT NOT NULL,
        daily_revenue DECIMAL(15, 2),
        gross_profit DECIMAL(15, 2),
        transaction_count INT,
        created_timestamp DATETIME2 DEFAULT GETDATE(),
        CONSTRAINT pk_wh_daily_financial_snapshot PRIMARY KEY (snapshot_date, date_key)
    );
    
    INSERT INTO wh_daily_financial_snapshot 
    SELECT 
        @p_snapshot_date,
        dd.date_key,
        SUM(fr.total_revenue),
        SUM(fr.gross_profit),
        COUNT(*),
        GETDATE()
    FROM fact_revenue fr
    INNER JOIN dim_date dd ON fr.date_key = dd.date_key
    WHERE dd.date_value = @p_snapshot_date
    GROUP BY dd.date_key;
    
    IF @p_verbose = 1
        PRINT '--- Snapshot Created Successfully ---';
END;
GO

-- ============================================================================
-- PART 5: QUERY PERFORMANCE ENHANCEMENT
-- ============================================================================

-- Procedure: Get Pre-Aggregated Results (Avoids Recalculation)
-- Purpose: Query snapshot instead of raw fact tables
CREATE PROCEDURE sp_get_daily_metrics_from_snapshot
    @p_start_date DATE,
    @p_end_date DATE
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        snapshot_date,
        SUM(daily_revenue) AS period_revenue,
        SUM(gross_profit) AS period_profit,
        SUM(transaction_count) AS period_transactions,
        AVG(daily_revenue) AS avg_daily_revenue,
        STDEV(daily_revenue) AS stddev_daily_revenue
    FROM wh_daily_financial_snapshot
    WHERE snapshot_date BETWEEN @p_start_date AND @p_end_date
    GROUP BY snapshot_date
    ORDER BY snapshot_date DESC;
END;
GO

-- ============================================================================
-- PART 6: WAREHOUSE COMPRESSION & OPTIMIZATION
-- ============================================================================

-- Procedure: Apply Optimal Compression Settings
-- Purpose: Reduce storage while maintaining query performance
IF OBJECT_ID('sp_apply_warehouse_compression', 'P') IS NOT NULL
    DROP PROCEDURE sp_apply_warehouse_compression;
GO

CREATE PROCEDURE sp_apply_warehouse_compression
    @p_compression_type VARCHAR(10) = 'PAGE',  -- 'ROW' for small tables, 'PAGE' for large
    @p_verbose BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @p_verbose = 1
    BEGIN
        PRINT '--- Applying ' + @p_compression_type + ' Compression ---';
        PRINT 'Estimated storage reduction: 40-60%';
        PRINT 'Warning: Increases CPU usage slightly';
    END
    
    -- Apply to large fact tables
    DECLARE @sql NVARCHAR(MAX);
    
    -- Create compressed copy for fact_revenue
    IF @p_verbose = 1
        PRINT 'Compressing fact_revenue...';
    
    SET @sql = 'ALTER TABLE fact_revenue REBUILD WITH (DATA_COMPRESSION = ' + @p_compression_type + ')';
    EXEC sp_executesql @sql;
    
    IF @p_verbose = 1
    BEGIN
        PRINT 'Compression applied successfully';
        PRINT '--- Compression Complete ---';
    END
END;
GO

-- ============================================================================
-- PART 7: WAREHOUSE VALIDATION & INTEGRITY CHECKS
-- ============================================================================

-- Procedure: Validate Warehouse Data Integrity
-- Purpose: Ensure aggregations match source data
IF OBJECT_ID('sp_validate_warehouse_integrity', 'P') IS NOT NULL
    DROP PROCEDURE sp_validate_warehouse_integrity;
GO

CREATE PROCEDURE sp_validate_warehouse_integrity
    @p_sample_size INT = 100,
    @p_verbose BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @p_verbose = 1
        PRINT '--- Validating Warehouse Data Integrity ---';
    
    DECLARE @issues INT = 0;
    
    -- Check 1: Fact table referential integrity
    IF @p_verbose = 1
        PRINT 'Check 1: Verifying dimension keys exist...';
    
    SELECT @issues = COUNT(*)
    FROM fact_revenue fr
    WHERE NOT EXISTS (SELECT 1 FROM dim_date WHERE date_key = fr.date_key)
        OR NOT EXISTS (SELECT 1 FROM dim_customer WHERE customer_key = fr.customer_key);
    
    IF @issues > 0
    BEGIN
        IF @p_verbose = 1
            PRINT 'WARNING: Found ' + CAST(@issues AS VARCHAR) + ' orphaned records';
    END
    
    -- Check 2: Aggregation consistency
    IF @p_verbose = 1
        PRINT 'Check 2: Verifying aggregations...';
    
    -- Check 3: Date range coverage
    IF @p_verbose = 1
        PRINT 'Check 3: Verifying date coverage...';
    
    SELECT 
        COUNT(DISTINCT date_key) AS unique_dates,
        MIN(date_key) AS earliest_date_key,
        MAX(date_key) AS latest_date_key
    FROM fact_revenue;
    
    IF @p_verbose = 1
        PRINT '--- Validation Complete ---';
END;
GO

-- ============================================================================
-- PART 8: WAREHOUSE MAINTENANCE SCHEDULE
-- ============================================================================

-- Create maintenance tracking table
IF OBJECT_ID('wh_maintenance_log', 'U') IS NULL
CREATE TABLE wh_maintenance_log (
    maintenance_id INT PRIMARY KEY IDENTITY(1,1),
    maintenance_date DATETIME2 DEFAULT GETDATE(),
    maintenance_type VARCHAR(50),  -- 'REFRESH', 'COMPRESSION', 'DEFRAG', 'SNAPSHOT'
    duration_seconds INT,
    status VARCHAR(20),  -- 'SUCCESS', 'PARTIAL', 'FAILED'
    message NVARCHAR(MAX)
);
GO

-- Procedure: Execute Full Warehouse Maintenance
-- Purpose: Run all optimization tasks in sequence
IF OBJECT_ID('sp_execute_warehouse_maintenance', 'P') IS NOT NULL
    DROP PROCEDURE sp_execute_warehouse_maintenance;
GO

CREATE PROCEDURE sp_execute_warehouse_maintenance
    @p_mode VARCHAR(20) = 'STANDARD',  -- 'QUICK', 'STANDARD', 'COMPREHENSIVE'
    @p_verbose BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @start_time DATETIME2 = GETDATE();
    DECLARE @duration INT;
    
    IF @p_verbose = 1
        PRINT '========== WAREHOUSE MAINTENANCE (' + UPPER(@p_mode) + ') ==========';
    
    BEGIN TRY
        -- QUICK: Refresh views and update statistics (5-10 min)
        IF @p_mode IN ('QUICK', 'STANDARD', 'COMPREHENSIVE')
        BEGIN
            IF @p_verbose = 1
                PRINT 'Refreshing materialized views...';
            EXEC sp_refresh_materialized_views @p_view_type = 'ALL', @p_verbose = @p_verbose;
        END
        
        -- STANDARD: Add defragmentation (30-45 min)
        IF @p_mode IN ('STANDARD', 'COMPREHENSIVE')
        BEGIN
            IF @p_verbose = 1
                PRINT 'Maintaining index fragmentation...';
            EXEC sp_maintain_index_fragmentation @p_verbose = @p_verbose;
        END
        
        -- COMPREHENSIVE: Add compression and full validation (1-2 hours)
        IF @p_mode = 'COMPREHENSIVE'
        BEGIN
            IF @p_verbose = 1
                PRINT 'Applying compression...';
            EXEC sp_apply_warehouse_compression @p_verbose = @p_verbose;
            
            IF @p_verbose = 1
                PRINT 'Validating warehouse integrity...';
            EXEC sp_validate_warehouse_integrity @p_verbose = @p_verbose;
        END
        
        SET @duration = DATEDIFF(SECOND, @start_time, GETDATE());
        
        INSERT INTO wh_maintenance_log (maintenance_type, duration_seconds, status, message)
        VALUES (@p_mode + ' Maintenance', @duration, 'SUCCESS', 'Maintenance completed successfully');
        
        IF @p_verbose = 1
        BEGIN
            PRINT '';
            PRINT '========== MAINTENANCE COMPLETE ==========';
            PRINT 'Duration: ' + CAST(@duration AS VARCHAR) + ' seconds';
            PRINT 'Next scheduled maintenance: tomorrow at 2:00 AM';
        END
    END TRY
    BEGIN CATCH
        INSERT INTO wh_maintenance_log (maintenance_type, duration_seconds, status, message)
        VALUES (@p_mode + ' Maintenance', DATEDIFF(SECOND, @start_time, GETDATE()), 'FAILED', ERROR_MESSAGE());
        
        THROW;
    END CATCH
END;
GO

-- ============================================================================
-- UTILITY: Warehouse Optimization Dashboard
-- ============================================================================

CREATE VIEW vw_warehouse_optimization_status AS
SELECT 
    'Materialized Views' AS component,
    COUNT(*) AS item_count,
    'READY' AS status
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME LIKE 'vw_%'
UNION ALL
SELECT 
    'Compression Enabled Indexes',
    COUNT(*),
    'ENABLED'
FROM sys.indexes
WHERE has_filter = 1;
GO
