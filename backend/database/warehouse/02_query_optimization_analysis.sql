-- ============================================================================
-- QUERY OPTIMIZATION ANALYSIS & RECOMMENDATIONS
-- Enterprise KPI - Executive Decision Intelligence Platform
-- Purpose: Optimize slow queries and provide performance tuning strategies
-- ============================================================================

-- ============================================================================
-- PART 1: QUERY PERFORMANCE ANALYSIS
-- ============================================================================

-- Procedure: Find Expensive Queries
-- Purpose: Identify queries consuming most resources
-- Performance: Scans query statistics, sorted by total elapsed time
IF OBJECT_ID('sp_find_expensive_queries', 'P') IS NOT NULL
    DROP PROCEDURE sp_find_expensive_queries;
GO

CREATE PROCEDURE sp_find_expensive_queries
    @p_top_n INT = 20,
    @p_min_execution_time_ms INT = 100,
    @p_verbose BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @p_verbose = 1
        PRINT '--- Finding Top ' + CAST(@p_top_n AS VARCHAR) + ' Expensive Queries ---';
    
    SELECT TOP (@p_top_n)
        qs.sql_handle,
        qs.plan_handle,
        qs.execution_count,
        qs.total_elapsed_time / 1000000.0 AS total_elapsed_sec,
        CAST(qs.total_elapsed_time / CAST(qs.execution_count AS FLOAT) / 1000.0 AS NUMERIC(10, 2)) AS avg_duration_ms,
        qs.total_logical_reads,
        qs.total_physical_reads,
        qs.total_logical_writes,
        CAST(qs.total_logical_reads / CAST(qs.execution_count AS FLOAT) AS NUMERIC(10, 2)) AS avg_logical_reads,
        SUBSTRING(st.text, 1, 100) AS query_text
    FROM sys.dm_exec_query_stats qs
    CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
    WHERE qs.total_elapsed_time / 1000000.0 > @p_min_execution_time_ms
    ORDER BY qs.total_elapsed_time DESC;
    
    IF @p_verbose = 1
        PRINT '--- Analysis Complete ---';
END;
GO

-- Procedure: Analyze Query Execution Plan
-- Purpose: Get detailed query plan for specific query
IF OBJECT_ID('sp_analyze_query_execution_plan', 'P') IS NOT NULL
    DROP PROCEDURE sp_analyze_query_execution_plan;
GO

CREATE PROCEDURE sp_analyze_query_execution_plan
    @p_query NVARCHAR(MAX),
    @p_verbose BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @p_verbose = 1
        PRINT 'Analyzing Query Execution Plan...';
    
    SET STATISTICS IO ON;
    SET STATISTICS TIME ON;
    
    EXEC sp_executesql @p_query;
    
    SET STATISTICS TIME OFF;
    SET STATISTICS IO OFF;
    
    IF @p_verbose = 1
        PRINT 'Analysis Complete - Review Messages Tab for I/O and Time Statistics';
END;
GO

-- ============================================================================
-- PART 2: MISSING INDEX ANALYSIS
-- ============================================================================

-- Procedure: Identify Missing Indexes
-- Purpose: Find columns that would benefit from indexing
IF OBJECT_ID('sp_find_missing_indexes', 'P') IS NOT NULL
    DROP PROCEDURE sp_find_missing_indexes;
GO

CREATE PROCEDURE sp_find_missing_indexes
    @p_min_improvement_pct INT = 10,
    @p_verbose BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @p_verbose = 1
        PRINT '--- Finding Missing Indexes ---';
    
    SELECT TOP 50
        migs.avg_total_user_cost * (migs.avg_user_impact / 100.0) * (migs.user_seeks + migs.user_scans) AS improvement_measure,
        mid.equality_columns,
        mid.inequality_columns,
        mid.included_columns,
        migs.user_seeks,
        migs.user_scans,
        migs.user_lookups,
        migs.avg_user_impact AS avg_impact_pct,
        migs.avg_total_user_cost,
        CONVERT(DECIMAL(18, 2), migs.avg_total_user_cost * migs.avg_user_impact * (migs.user_seeks + migs.user_scans)) AS improvement_potential,
        'CREATE INDEX idx_' + REPLACE(REPLACE(REPLACE(mid.equality_columns, ', ', '_'), '[', ''), ']', '') +
            ' ON ' + mid.statement + ' (' + mid.equality_columns +
            CASE WHEN mid.inequality_columns IS NOT NULL THEN ', ' + mid.inequality_columns ELSE '' END + ')' +
            CASE WHEN mid.included_columns IS NOT NULL THEN ' INCLUDE (' + mid.included_columns + ')' ELSE '' END AS create_index_statement
    FROM sys.dm_db_missing_index_details mid
    INNER JOIN sys.dm_db_missing_index_groups mig ON mid.index_handle = mig.index_handle
    INNER JOIN sys.dm_db_missing_index_groups_stats migs ON mig.index_group_id = migs.index_group_id
    WHERE database_id = DB_ID()
        AND migs.avg_user_impact > @p_min_improvement_pct
    ORDER BY improvement_measure DESC;
    
    IF @p_verbose = 1
        PRINT '--- Analysis Complete ---';
END;
GO

-- ============================================================================
-- PART 3: OPTIMIZED QUERY PATTERNS
-- ============================================================================

-- Pattern 1: Efficient Large Table Scan with Aggregation
-- Best for: Revenue and fact table aggregations
CREATE PROCEDURE sp_get_revenue_summary_optimized
    @p_start_date DATE,
    @p_end_date DATE,
    @p_segment VARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Use covering index on fact_revenue (date_key, customer_key, amount, status)
    -- Filter pushdown for date range
    SELECT 
        dd.date_value,
        dd.year,
        dd.month,
        dc.customer_segment,
        COUNT(*) AS transaction_count,
        SUM(fr.total_revenue) AS total_revenue,
        SUM(fr.gross_profit) AS gross_profit,
        AVG(fr.average_transaction_amt) AS avg_transaction
    FROM fact_revenue fr
    INNER JOIN dim_date dd ON fr.date_key = dd.date_key
    INNER JOIN dim_customer dc ON fr.customer_key = dc.customer_key
    WHERE dd.date_value BETWEEN @p_start_date AND @p_end_date
        AND dc.is_current = 1
        AND (@p_segment IS NULL OR dc.customer_segment = @p_segment)
    GROUP BY dd.date_value, dd.year, dd.month, dc.customer_segment
    ORDER BY dd.date_value DESC, dc.customer_segment;
END;
GO

-- Pattern 2: Efficient Dimension Join with SCD Type 2
-- Best for: Customer and product dimensions
CREATE PROCEDURE sp_get_customer_metrics_optimized
    @p_report_date DATE
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Use effective_date and end_date in WHERE clause for efficient filtering
    SELECT 
        dc.customer_id,
        dc.customer_name,
        dc.customer_segment,
        dc.annual_contract_value,
        COUNT(DISTINCT fr.transaction_id) AS transaction_count,
        SUM(fr.total_revenue) AS lifetime_revenue,
        MAX(fr.transaction_date) AS last_transaction_date
    FROM dim_customer dc
    LEFT JOIN fact_revenue fr ON dc.customer_key = fr.customer_key
        AND fr.transaction_date >= dc.effective_date
        AND fr.transaction_date < ISNULL(dc.end_date, '9999-12-31')
    WHERE dc.is_current = 1
    GROUP BY 
        dc.customer_id,
        dc.customer_name,
        dc.customer_segment,
        dc.annual_contract_value
    HAVING COUNT(DISTINCT fr.transaction_id) > 0;
END;
GO

-- Pattern 3: Window Functions for Ranking (Efficient Alternative to Subqueries)
-- Best for: Top N queries without temporary tables
CREATE PROCEDURE sp_get_top_products_by_revenue_optimized
    @p_limit INT = 50,
    @p_month INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    WITH ranked_products AS (
        SELECT 
            dp.product_id,
            dp.product_name,
            dp.category,
            SUM(fp.total_units_sold) AS total_units,
            SUM(fp.total_revenue) AS total_revenue,
            SUM(fp.gross_profit) AS gross_profit,
            ROW_NUMBER() OVER (ORDER BY SUM(fp.total_revenue) DESC) AS rnk
        FROM fact_product_sales fp
        INNER JOIN dim_product dp ON fp.product_key = dp.product_key
        INNER JOIN dim_date dd ON fp.date_key = dd.date_key
        WHERE dp.is_current = 1
            AND (@p_month IS NULL OR dd.month = @p_month)
        GROUP BY 
            dp.product_id,
            dp.product_name,
            dp.category
    )
    SELECT 
        ranked_products.*
    FROM ranked_products
    WHERE rnk <= @p_limit
    ORDER BY rnk;
END;
GO

-- ============================================================================
-- PART 4: INDEX FRAGMENTATION ANALYSIS
-- ============================================================================

-- Procedure: Analyze Index Fragmentation
-- Purpose: Identify indexes that need maintenance
IF OBJECT_ID('sp_analyze_index_fragmentation', 'P') IS NOT NULL
    DROP PROCEDURE sp_analyze_index_fragmentation;
GO

CREATE PROCEDURE sp_analyze_index_fragmentation
    @p_min_fragmentation_pct DECIMAL(5, 2) = 10.0,
    @p_verbose BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @p_verbose = 1
        PRINT '--- Analyzing Index Fragmentation ---';
    
    SELECT 
        OBJECT_NAME(ips.object_id) AS table_name,
        i.name AS index_name,
        ips.index_type_desc,
        ips.avg_fragmentation_in_percent,
        ips.page_count,
        CASE 
            WHEN ips.avg_fragmentation_in_percent < 10 THEN 'REBUILD'
            WHEN ips.avg_fragmentation_in_percent < 30 THEN 'REORGANIZE'
            ELSE 'MONITOR'
        END AS recommended_action
    FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ips
    INNER JOIN sys.indexes i ON ips.object_id = i.object_id AND ips.index_id = i.index_id
    WHERE database_id = DB_ID()
        AND ips.avg_fragmentation_in_percent > @p_min_fragmentation_pct
        AND ips.page_count > 1000
        AND OBJECTPROPERTY(ips.object_id, 'IsUserTable') = 1
    ORDER BY ips.avg_fragmentation_in_percent DESC;
    
    IF @p_verbose = 1
        PRINT '--- Analysis Complete ---';
END;
GO

-- ============================================================================
-- PART 5: QUERY TUNING RECOMMENDATIONS
-- ============================================================================

/*
OPTIMIZATION RECOMMENDATIONS:

1. COVERING INDEXES:
   - Create covering indexes for frequently used queries
   - Include columns used in SELECT and WHERE clauses
   - Example: CREATE INDEX idx_fact_revenue_covering 
     ON fact_revenue (date_key, customer_key) 
     INCLUDE (total_revenue, gross_profit)

2. PARTITION STRATEGY (for large tables):
   - Partition fact_revenue by date_key (monthly)
   - Benefits: Faster queries, easier maintenance, parallel processing
   - Implementation: Use partition function and scheme

3. STATISTICS MAINTENANCE:
   - Update statistics on dimension tables monthly
   - Update statistics on fact tables weekly
   - Use AUTO_CREATE_STATISTICS = ON

4. EXECUTION PLAN OPTIMIZATION:
   - Use OPTION (RECOMPILE) for one-off queries with parameters
   - Monitor parameter sniffing issues
   - Consider query hints only as last resort

5. FACT TABLE OPTIMIZATION:
   - Fact tables should be clustered on date_key + primary business key
   - Use columnstore indexes for analytical queries on large tables
   - Implement compression on partitioned tables

6. DIMENSION TABLE OPTIMIZATION:
   - Cluster on primary key (surrogate key)
   - Create indexes on business keys and common filter columns
   - Keep dimensions small (< 50MB typical)

7. VIEW OPTIMIZATION:
   - Use indexed views for pre-aggregated results
   - Refresh indexed views after major ETL operations
   - Avoid complex joins in views

8. QUERY PATTERNS TO AVOID:
   - Correlated subqueries (use joins instead)
   - NOT IN with NULL values (use NOT EXISTS)
   - Implicit conversions (ensure column types match)
   - Functions on WHERE clause columns (breaks index usage)

*/

-- ============================================================================
-- UTILITY: Run All Optimization Analyses
-- ============================================================================

CREATE PROCEDURE sp_run_query_optimization_analysis
    @p_verbose BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @p_verbose = 1
    BEGIN
        PRINT '========== QUERY OPTIMIZATION ANALYSIS START ==========';
        PRINT '';
    END
    
    IF @p_verbose = 1
        PRINT '1. Analyzing Expensive Queries...';
    EXEC sp_find_expensive_queries @p_top_n = 20, @p_verbose = @p_verbose;
    
    IF @p_verbose = 1
    BEGIN
        PRINT '';
        PRINT '2. Analyzing Missing Indexes...';
    END
    EXEC sp_find_missing_indexes @p_min_improvement_pct = 10, @p_verbose = @p_verbose;
    
    IF @p_verbose = 1
    BEGIN
        PRINT '';
        PRINT '3. Analyzing Index Fragmentation...';
    END
    EXEC sp_analyze_index_fragmentation @p_min_fragmentation_pct = 10.0, @p_verbose = @p_verbose;
    
    IF @p_verbose = 1
    BEGIN
        PRINT '';
        PRINT '========== QUERY OPTIMIZATION ANALYSIS COMPLETE ==========';
    END
END;
GO
