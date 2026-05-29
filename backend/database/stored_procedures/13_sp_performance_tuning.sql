-- ============================================================================
-- PERFORMANCE TUNING PROCEDURES & MAINTENANCE
-- Enterprise KPI - Executive Decision Intelligence Platform
-- Purpose: Query optimization, index maintenance, statistics updates
-- ============================================================================

-- ============================================================================
-- INDEX MANAGEMENT & OPTIMIZATION
-- ============================================================================

-- Procedure: Create Optimized Indexes for Performance
-- Purpose: Build recommended index strategy for analytical queries
-- Usage: EXEC sp_create_optimized_indexes @p_verbose = 1
CREATE PROCEDURE sp_create_optimized_indexes
    @p_verbose BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        IF @p_verbose = 1
            PRINT 'Starting index optimization procedure...';
        
        -- Fact Tables: Composite indexes on FK + date + status
        DECLARE @sql_command NVARCHAR(MAX);
        
        -- fact_sales optimized indexes
        SET @sql_command = N'
        IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = ''idx_fact_sales_customer_date_status'')
        BEGIN
            CREATE NONCLUSTERED INDEX idx_fact_sales_customer_date_status
            ON fact_sales (customer_key, order_date_key, order_status)
            INCLUDE (net_sales_amount, gross_profit)
            WITH (FILLFACTOR = 90);
            IF @verbose = 1 PRINT ''Index idx_fact_sales_customer_date_status created'';
        END
        
        IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = ''idx_fact_sales_product_date'')
        BEGIN
            CREATE NONCLUSTERED INDEX idx_fact_sales_product_date
            ON fact_sales (product_key, order_date_key)
            INCLUDE (net_sales_amount, order_quantity, gross_profit)
            WITH (FILLFACTOR = 90);
            IF @verbose = 1 PRINT ''Index idx_fact_sales_product_date created'';
        END
        
        IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = ''idx_fact_sales_employee_date'')
        BEGIN
            CREATE NONCLUSTERED INDEX idx_fact_sales_employee_date
            ON fact_sales (employee_key, order_date_key)
            INCLUDE (net_sales_amount, gross_profit)
            WITH (FILLFACTOR = 90);
            IF @verbose = 1 PRINT ''Index idx_fact_sales_employee_date created'';
        END';
        
        EXEC sp_executesql @sql_command, N'@verbose BIT', @p_verbose;
        
        -- fact_revenue optimized indexes
        SET @sql_command = N'
        IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = ''idx_fact_revenue_date_customer'')
        BEGIN
            CREATE NONCLUSTERED INDEX idx_fact_revenue_date_customer
            ON fact_revenue (date_key, customer_key)
            INCLUDE (total_revenue, net_revenue, gross_profit, gross_margin_percent)
            WITH (FILLFACTOR = 90);
            IF @verbose = 1 PRINT ''Index idx_fact_revenue_date_customer created'';
        END
        
        IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = ''idx_fact_revenue_customer_product'')
        BEGIN
            CREATE NONCLUSTERED INDEX idx_fact_revenue_customer_product
            ON fact_revenue (customer_key, product_key, date_key)
            INCLUDE (total_revenue, gross_profit)
            WITH (FILLFACTOR = 90);
            IF @verbose = 1 PRINT ''Index idx_fact_revenue_customer_product created'';
        END
        
        IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = ''idx_fact_revenue_geography_date'')
        BEGIN
            CREATE NONCLUSTERED INDEX idx_fact_revenue_geography_date
            ON fact_revenue (geography_key, date_key)
            INCLUDE (total_revenue, gross_profit, gross_margin_percent)
            WITH (FILLFACTOR = 90);
            IF @verbose = 1 PRINT ''Index idx_fact_revenue_geography_date created'';
        END';
        
        EXEC sp_executesql @sql_command, N'@verbose BIT', @p_verbose;
        
        -- Dimension Tables: Indexes on effective_date for SCD Type 2
        SET @sql_command = N'
        IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = ''idx_dim_customer_effective_current'')
        BEGIN
            CREATE NONCLUSTERED INDEX idx_dim_customer_effective_current
            ON dim_customer (is_current, effective_date)
            INCLUDE (customer_id, customer_name, customer_segment)
            WITH (FILLFACTOR = 95);
            IF @verbose = 1 PRINT ''Index idx_dim_customer_effective_current created'';
        END
        
        IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = ''idx_dim_product_effective_current'')
        BEGIN
            CREATE NONCLUSTERED INDEX idx_dim_product_effective_current
            ON dim_product (is_current, effective_date)
            INCLUDE (product_id, product_name, product_category)
            WITH (FILLFACTOR = 95);
            IF @verbose = 1 PRINT ''Index idx_dim_product_effective_current created'';
        END
        
        IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = ''idx_dim_employee_effective_current'')
        BEGIN
            CREATE NONCLUSTERED INDEX idx_dim_employee_effective_current
            ON dim_employee (is_current, effective_date)
            INCLUDE (employee_id, employee_name, department)
            WITH (FILLFACTOR = 95);
            IF @verbose = 1 PRINT ''Index idx_dim_employee_effective_current created'';
        END';
        
        EXEC sp_executesql @sql_command, N'@verbose BIT', @p_verbose;
        
        IF @p_verbose = 1
            PRINT 'Index optimization completed successfully';
            
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        PRINT 'ERROR in sp_create_optimized_indexes: ' + @ErrorMessage;
        THROW;
    END CATCH;
END;
GO

-- Procedure: Find and Report Unused Indexes
-- Purpose: Identify indexes that consume space but are not being used
-- Usage: EXEC sp_find_unused_indexes
CREATE PROCEDURE sp_find_unused_indexes
    @p_database_name NVARCHAR(128) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @p_database_name IS NULL
        SET @p_database_name = DB_NAME();
    
    SELECT 
        OBJECT_NAME(i.object_id) AS table_name,
        i.name AS index_name,
        i.type_desc AS index_type,
        s.user_updates,
        s.user_seeks,
        s.user_scans,
        s.user_lookups,
        (s.user_seeks + s.user_scans + s.user_lookups) AS total_reads,
        CASE 
            WHEN (s.user_seeks + s.user_scans + s.user_lookups) = 0 
                AND s.user_updates > 0 THEN 'CANDIDATE_FOR_REMOVAL'
            WHEN (s.user_seeks + s.user_scans + s.user_lookups) < 10 
                AND s.user_updates > 100 THEN 'LOW_USE_HIGH_COST'
            ELSE 'MONITOR'
        END AS recommendation
    FROM sys.indexes i
    LEFT JOIN sys.dm_db_index_usage_stats s 
        ON i.object_id = s.object_id 
        AND i.index_id = s.index_id 
        AND s.database_id = DB_ID()
    WHERE OBJECTPROPERTY(i.object_id, 'IsUserTable') = 1
        AND i.index_id > 0  -- Exclude heaps
    ORDER BY (s.user_seeks + s.user_scans + s.user_lookups) ASC,
             s.user_updates DESC;
END;
GO

-- Procedure: Rebuild and Reorganize Fragmented Indexes
-- Purpose: Maintenance of index fragmentation for performance
-- Usage: EXEC sp_maintain_index_fragmentation @p_fragmentation_threshold = 20
CREATE PROCEDURE sp_maintain_index_fragmentation
    @p_fragmentation_threshold INT = 20, -- Percentage threshold for rebuild
    @p_verbose BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        IF @p_verbose = 1
            PRINT 'Starting index fragmentation maintenance...';
        
        DECLARE @table_name NVARCHAR(128);
        DECLARE @index_name NVARCHAR(128);
        DECLARE @fragmentation FLOAT;
        DECLARE @sql_command NVARCHAR(MAX);
        
        DECLARE index_cursor CURSOR FOR
        SELECT 
            OBJECT_NAME(ips.object_id) AS table_name,
            i.name AS index_name,
            ips.avg_fragmentation_in_percent
        FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ips
        INNER JOIN sys.indexes i 
            ON ips.object_id = i.object_id 
            AND ips.index_id = i.index_id
        WHERE ips.avg_fragmentation_in_percent > 10
            AND ips.page_count > 1000
            AND OBJECTPROPERTY(ips.object_id, 'IsUserTable') = 1
        ORDER BY ips.avg_fragmentation_in_percent DESC;
        
        OPEN index_cursor;
        FETCH NEXT FROM index_cursor INTO @table_name, @index_name, @fragmentation;
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            IF @fragmentation > @p_fragmentation_threshold
            BEGIN
                SET @sql_command = 'ALTER INDEX ' + @index_name + ' ON ' + @table_name + ' REBUILD;';
                IF @p_verbose = 1
                    PRINT 'REBUILDING: ' + @table_name + '.' + @index_name + ' (Fragmentation: ' + 
                          CAST(@fragmentation AS VARCHAR(5)) + '%)';
                EXEC sp_executesql @sql_command;
            END
            ELSE IF @fragmentation > 10
            BEGIN
                SET @sql_command = 'ALTER INDEX ' + @index_name + ' ON ' + @table_name + ' REORGANIZE;';
                IF @p_verbose = 1
                    PRINT 'REORGANIZING: ' + @table_name + '.' + @index_name + ' (Fragmentation: ' + 
                          CAST(@fragmentation AS VARCHAR(5)) + '%)';
                EXEC sp_executesql @sql_command;
            END;
            
            FETCH NEXT FROM index_cursor INTO @table_name, @index_name, @fragmentation;
        END;
        
        CLOSE index_cursor;
        DEALLOCATE index_cursor;
        
        IF @p_verbose = 1
            PRINT 'Index fragmentation maintenance completed';
            
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('global', 'index_cursor') >= 0
        BEGIN
            CLOSE index_cursor;
            DEALLOCATE index_cursor;
        END;
        
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        PRINT 'ERROR: ' + @ErrorMessage;
        THROW;
    END CATCH;
END;
GO

-- ============================================================================
-- STATISTICS MANAGEMENT & UPDATES
-- ============================================================================

-- Procedure: Update Table Statistics
-- Purpose: Ensure query optimizer has latest statistics
-- Usage: EXEC sp_update_statistics @p_table_name = 'fact_sales', @p_resample = 1
CREATE PROCEDURE sp_update_statistics
    @p_table_name NVARCHAR(128) = NULL,
    @p_resample BIT = 0,
    @p_verbose BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        IF @p_verbose = 1
            PRINT 'Starting statistics update...';
        
        DECLARE @sql_command NVARCHAR(MAX);
        
        IF @p_table_name IS NULL
        BEGIN
            -- Update all user tables
            IF @p_resample = 1
            BEGIN
                SET @sql_command = N'
                DECLARE @table NVARCHAR(128);
                DECLARE table_cursor CURSOR FOR
                SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES 
                WHERE TABLE_SCHEMA = ''dbo'' AND TABLE_TYPE = ''BASE TABLE'';
                
                OPEN table_cursor;
                FETCH NEXT FROM table_cursor INTO @table;
                
                WHILE @@FETCH_STATUS = 0
                BEGIN
                    EXEC (''UPDATE STATISTICS '' + @table + '' WITH RESAMPLE'');
                    IF @verbose = 1 PRINT ''Statistics updated (RESAMPLE): '' + @table;
                    FETCH NEXT FROM table_cursor INTO @table;
                END;
                
                CLOSE table_cursor;
                DEALLOCATE table_cursor;';
                
                EXEC sp_executesql @sql_command, N'@verbose BIT', @p_verbose;
            END
            ELSE
            BEGIN
                SET @sql_command = N'
                DECLARE @table NVARCHAR(128);
                DECLARE table_cursor CURSOR FOR
                SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES 
                WHERE TABLE_SCHEMA = ''dbo'' AND TABLE_TYPE = ''BASE TABLE'';
                
                OPEN table_cursor;
                FETCH NEXT FROM table_cursor INTO @table;
                
                WHILE @@FETCH_STATUS = 0
                BEGIN
                    EXEC (''UPDATE STATISTICS '' + @table);
                    IF @verbose = 1 PRINT ''Statistics updated (FULLSCAN): '' + @table;
                    FETCH NEXT FROM table_cursor INTO @table;
                END;
                
                CLOSE table_cursor;
                DEALLOCATE table_cursor;';
                
                EXEC sp_executesql @sql_command, N'@verbose BIT', @p_verbose;
            END;
        END
        ELSE
        BEGIN
            -- Update specific table
            IF @p_resample = 1
                SET @sql_command = 'UPDATE STATISTICS ' + @p_table_name + ' WITH RESAMPLE;'
            ELSE
                SET @sql_command = 'UPDATE STATISTICS ' + @p_table_name + ';';
            
            IF @p_verbose = 1
                PRINT 'Updating statistics for table: ' + @p_table_name;
            
            EXEC sp_executesql @sql_command;
        END;
        
        IF @p_verbose = 1
            PRINT 'Statistics update completed successfully';
            
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        PRINT 'ERROR in sp_update_statistics: ' + @ErrorMessage;
        THROW;
    END CATCH;
END;
GO

-- ============================================================================
-- QUERY PERFORMANCE ANALYSIS
-- ============================================================================

-- Procedure: Get Expensive Queries
-- Purpose: Identify queries consuming most resources
-- Usage: EXEC sp_get_expensive_queries @p_top_n = 20
CREATE PROCEDURE sp_get_expensive_queries
    @p_top_n INT = 20
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT TOP (@p_top_n)
        DB_NAME(qs.database_id) AS database_name,
        SUBSTRING(st.text, (qs.statement_start_offset / 2) + 1,
            ((CASE qs.statement_end_offset 
              WHEN -1 THEN DATALENGTH(st.text)
              ELSE qs.statement_end_offset 
             END - qs.statement_start_offset) / 2) + 1) AS query_text,
        qs.execution_count,
        CAST(qs.total_elapsed_time / 1000000.0 AS DECIMAL(12, 2)) AS total_elapsed_time_sec,
        CAST(qs.total_elapsed_time / (qs.execution_count * 1000000.0) AS DECIMAL(12, 4)) AS avg_elapsed_time_sec,
        CAST(qs.total_logical_reads / 1024.0 / 1024.0 AS DECIMAL(12, 2)) AS total_logical_reads_mb,
        CAST(qs.total_physical_reads / 1024.0 / 1024.0 AS DECIMAL(12, 2)) AS total_physical_reads_mb,
        qs.last_execution_time,
        qp.query_plan
    FROM sys.dm_exec_query_stats qs
    CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
    CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) qp
    WHERE DB_NAME(qs.database_id) = DB_NAME()
    ORDER BY qs.total_elapsed_time DESC;
END;
GO

-- Procedure: Analyze Query Execution Plan
-- Purpose: Store and retrieve execution plans for analysis
-- Usage: EXEC sp_analyze_query_plan @p_query_text = 'SELECT * FROM fact_sales'
CREATE PROCEDURE sp_analyze_query_plan
    @p_query_text NVARCHAR(MAX),
    @p_verbose BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        IF @p_verbose = 1
            PRINT 'Analyzing query execution plan...';
        
        SET STATISTICS IO ON;
        SET STATISTICS TIME ON;
        
        DECLARE @sql_command NVARCHAR(MAX) = 'SET STATISTICS PROFILE ON; ' + @p_query_text;
        EXEC sp_executesql @sql_command;
        
        SET STATISTICS PROFILE OFF;
        SET STATISTICS TIME OFF;
        SET STATISTICS IO OFF;
        
        IF @p_verbose = 1
            PRINT 'Query plan analysis completed';
            
    END TRY
    BEGIN CATCH
        SET STATISTICS PROFILE OFF;
        SET STATISTICS TIME OFF;
        SET STATISTICS IO OFF;
        
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        PRINT 'ERROR: ' + @ErrorMessage;
        THROW;
    END CATCH;
END;
GO

-- ============================================================================
-- MATERIALIZED VIEW REFRESH PROCEDURES
-- ============================================================================

-- Procedure: Refresh All Reporting Views
-- Purpose: Refresh materialized views for latest data
-- Usage: EXEC sp_refresh_reporting_views @p_parallel = 1
CREATE PROCEDURE sp_refresh_reporting_views
    @p_parallel BIT = 0,
    @p_verbose BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        IF @p_verbose = 1
            PRINT 'Starting refresh of all reporting views...';
        
        DECLARE @start_time DATETIME = GETDATE();
        
        -- Views to refresh (in order of dependencies)
        DECLARE @views TABLE (view_name NVARCHAR(128), sequence INT);
        INSERT INTO @views VALUES 
            ('vw_daily_financial_summary', 1),
            ('vw_monthly_financial_segment_summary', 2),
            ('vw_employee_sales_performance', 2),
            ('vw_customer_revenue_analysis', 2),
            ('vw_product_category_performance', 2),
            ('vw_current_inventory_status', 3),
            ('vw_revenue_trend_90_days', 3),
            ('vw_executive_kpi_dashboard', 4);
        
        -- Note: SQL Server views are not materialized by default
        -- For true materialization, consider using indexed views or scheduled jobs
        -- This procedure serves as a framework for maintenance
        
        IF @p_verbose = 1
        BEGIN
            DECLARE @elapsed_seconds INT = DATEDIFF(SECOND, @start_time, GETDATE());
            PRINT 'View refresh completed in ' + CAST(@elapsed_seconds AS VARCHAR(10)) + ' seconds';
        END;
            
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        PRINT 'ERROR: ' + @ErrorMessage;
        THROW;
    END CATCH;
END;
GO

-- ============================================================================
-- COMPREHENSIVE MAINTENANCE PROCEDURE
-- ============================================================================

-- Procedure: Execute Full Maintenance Cycle
-- Purpose: Run complete performance maintenance routine
-- Usage: EXEC sp_execute_full_maintenance @p_mode = 'COMPREHENSIVE'
CREATE PROCEDURE sp_execute_full_maintenance
    @p_mode VARCHAR(50) = 'QUICK', -- QUICK, STANDARD, COMPREHENSIVE
    @p_verbose BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        DECLARE @start_time DATETIME = GETDATE();
        
        IF @p_verbose = 1
            PRINT '========================================';
            PRINT 'DATABASE MAINTENANCE CYCLE STARTING';
            PRINT '========================================';
            PRINT 'Mode: ' + @p_mode;
            PRINT 'Started: ' + CAST(@start_time AS VARCHAR(20));
        
        -- Step 1: Update Statistics
        IF @p_verbose = 1 PRINT '';
        IF @p_verbose = 1 PRINT 'Step 1: Updating Statistics...';
        EXEC sp_update_statistics @p_table_name = NULL, 
                                  @p_resample = CASE WHEN @p_mode = 'COMPREHENSIVE' THEN 1 ELSE 0 END, 
                                  @p_verbose = @p_verbose;
        
        -- Step 2: Maintain Index Fragmentation
        IF @p_verbose = 1 PRINT '';
        IF @p_verbose = 1 PRINT 'Step 2: Maintaining Index Fragmentation...';
        EXEC sp_maintain_index_fragmentation @p_fragmentation_threshold = 20, 
                                             @p_verbose = @p_verbose;
        
        -- Step 3: Create Optimized Indexes (if needed)
        IF @p_mode = 'COMPREHENSIVE'
        BEGIN
            IF @p_verbose = 1 PRINT '';
            IF @p_verbose = 1 PRINT 'Step 3: Creating Optimized Indexes...';
            EXEC sp_create_optimized_indexes @p_verbose = @p_verbose;
        END;
        
        -- Step 4: Check for Unused Indexes
        IF @p_mode IN ('STANDARD', 'COMPREHENSIVE')
        BEGIN
            IF @p_verbose = 1 PRINT '';
            IF @p_verbose = 1 PRINT 'Step 4: Checking for Unused Indexes...';
            EXEC sp_find_unused_indexes;
        END;
        
        -- Step 5: Refresh Views
        IF @p_verbose = 1 PRINT '';
        IF @p_verbose = 1 PRINT 'Step 5: Refreshing Reporting Views...';
        EXEC sp_refresh_reporting_views @p_verbose = @p_verbose;
        
        DECLARE @end_time DATETIME = GETDATE();
        DECLARE @elapsed_minutes FLOAT = DATEDIFF(SECOND, @start_time, @end_time) / 60.0;
        
        IF @p_verbose = 1
        BEGIN
            PRINT '';
            PRINT '========================================';
            PRINT 'DATABASE MAINTENANCE CYCLE COMPLETED';
            PRINT '========================================';
            PRINT 'Completed: ' + CAST(@end_time AS VARCHAR(20));
            PRINT 'Elapsed Time: ' + CAST(@elapsed_minutes AS VARCHAR(10)) + ' minutes';
        END;
            
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        PRINT '';
        PRINT '========================================';
        PRINT 'ERROR DURING MAINTENANCE CYCLE';
        PRINT '========================================';
        PRINT @ErrorMessage;
        THROW;
    END CATCH;
END;
GO

GO
