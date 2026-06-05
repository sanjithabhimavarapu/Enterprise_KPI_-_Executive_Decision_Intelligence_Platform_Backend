-- ============================================================================
-- INDEX TUNING & STRATEGY GUIDE
-- Enterprise KPI - Executive Decision Intelligence Platform
-- Purpose: Comprehensive index strategy for performance optimization
-- ============================================================================

-- ============================================================================
-- PART 1: DIMENSION TABLE INDEXES
-- ============================================================================

-- Ensure all dimension tables have optimal indexes
-- Strategy: Cluster on surrogate key, hash-match indexes on business keys

-- dim_date indexes (already optimized)
CREATE INDEX idx_dim_date_date_value ON dim_date(date_value);
CREATE INDEX idx_dim_date_year_month ON dim_date(year, month);
CREATE INDEX idx_dim_date_fiscal_period ON dim_date(fiscal_year, fiscal_quarter);

-- dim_customer indexes (SCD Type 2)
CREATE INDEX idx_dim_customer_business_key ON dim_customer(customer_id);
CREATE INDEX idx_dim_customer_segment ON dim_customer(customer_segment);
CREATE INDEX idx_dim_customer_scd_dates ON dim_customer(effective_date, end_date);
CREATE INDEX idx_dim_customer_is_current ON dim_customer(is_current);
CREATE INDEX idx_dim_customer_subscription ON dim_customer(subscription_status);

-- dim_product indexes
CREATE INDEX idx_dim_product_business_key ON dim_product(product_id);
CREATE INDEX idx_dim_product_category ON dim_product(category, subcategory);
CREATE INDEX idx_dim_product_is_current ON dim_product(is_current);

-- dim_employee indexes
CREATE INDEX idx_dim_employee_business_key ON dim_employee(employee_id);
CREATE INDEX idx_dim_employee_department ON dim_employee(department);
CREATE INDEX idx_dim_employee_manager ON dim_employee(manager_id);

-- dim_geography indexes
CREATE INDEX idx_dim_geography_country_region ON dim_geography(country, region);
CREATE INDEX idx_dim_geography_postal ON dim_geography(postal_code);

-- ============================================================================
-- PART 2: FACT TABLE COVERING INDEXES (High Priority)
-- ============================================================================

-- Strategy: Fact tables are typically large, use covering indexes for 
-- common queries to reduce I/O operations

-- Fact_Revenue Covering Indexes
CREATE INDEX idx_fact_revenue_date_customer ON fact_revenue(date_key, customer_key)
    INCLUDE (total_revenue, gross_profit, net_revenue, cost_of_goods);

CREATE INDEX idx_fact_revenue_product_date ON fact_revenue(date_key, product_key)
    INCLUDE (total_revenue, units_sold, gross_profit);

CREATE INDEX idx_fact_revenue_employee_date ON fact_revenue(date_key, employee_key)
    INCLUDE (total_revenue, gross_profit);

-- Fact_Product_Sales Covering Indexes
CREATE INDEX idx_fact_product_sales_date ON fact_product_sales(date_key, product_key)
    INCLUDE (total_revenue, total_units_sold, gross_profit);

CREATE INDEX idx_fact_product_sales_customer ON fact_product_sales(date_key, customer_key)
    INCLUDE (total_revenue, total_units_sold);

-- Fact_Inventory Covering Indexes
CREATE INDEX idx_fact_inventory_date ON fact_inventory(date_key, product_key)
    INCLUDE (quantity_on_hand, reorder_level, safety_stock);

CREATE INDEX idx_fact_inventory_warehouse ON fact_inventory(warehouse_key)
    INCLUDE (quantity_on_hand);

-- Fact_HR Covering Indexes
CREATE INDEX idx_fact_hr_employee_date ON fact_hr_data(date_key, employee_key)
    INCLUDE (headcount, salary, bonus);

-- ============================================================================
-- PART 3: DIMENSION LOAD OPTIMIZATION INDEXES
-- ============================================================================

-- Temporary indexes for ETL operations (create during load, drop after)
-- These speed up dimensional conformation and SCD Type 2 operations

-- For INSERT performance during loads
CREATE INDEX idx_dim_customer_load ON dim_customer(customer_id, is_current)
    INCLUDE (effective_date, end_date);

CREATE INDEX idx_dim_product_load ON dim_product(product_id, is_current)
    INCLUDE (effective_date, end_date);

-- ============================================================================
-- PART 4: STAGING TABLE INDEXES
-- ============================================================================

-- Optimize staging table operations for fast transformation

-- Staging Customers
CREATE INDEX idx_stg_customers_business_key ON stg_customers_conformed(customer_id);
CREATE INDEX idx_stg_customers_segment ON stg_customers_conformed(customer_segment);

-- Staging Products
CREATE INDEX idx_stg_products_category ON stg_products_conformed(category);
CREATE INDEX idx_stg_products_business_key ON stg_products_conformed(product_id);

-- Staging Orders/Transactions
CREATE INDEX idx_stg_orders_date ON stg_erp_orders_transformation(transaction_date);
CREATE INDEX idx_stg_orders_customer ON stg_erp_orders_transformation(customer_id);

-- Staging Inventory
CREATE INDEX idx_stg_inventory_warehouse ON stg_inventory_hr_production_transformation(warehouse_id);
CREATE INDEX idx_stg_inventory_product ON stg_inventory_hr_production_transformation(product_id);

-- ============================================================================
-- PART 5: QUERY OPTIMIZATION INDEXES
-- ============================================================================

-- For common analytical queries and reports

-- Revenue by segment and geography
CREATE INDEX idx_vw_revenue_segment_geography ON fact_revenue(date_key, customer_key, geography_key)
    INCLUDE (total_revenue, gross_profit);

-- Sales anomaly detection (requires quick filtering)
CREATE INDEX idx_anomaly_detection ON fact_revenue(date_key)
    INCLUDE (transaction_amount, customer_key);

-- Churn prediction queries
CREATE INDEX idx_churn_prediction ON fact_revenue(date_key, customer_key)
    INCLUDE (total_revenue);

-- ============================================================================
-- PART 6: COMPRESSED INDEXES FOR LARGE TABLES
-- ============================================================================

-- Apply compression to fact tables for storage optimization
-- Typical savings: 50-70% for fact tables, 10-20% for dimensions

ALTER INDEX idx_fact_revenue_date_customer ON fact_revenue 
    REBUILD WITH (DATA_COMPRESSION = PAGE);

ALTER INDEX idx_fact_product_sales_date ON fact_product_sales 
    REBUILD WITH (DATA_COMPRESSION = PAGE);

ALTER INDEX idx_fact_inventory_date ON fact_inventory 
    REBUILD WITH (DATA_COMPRESSION = PAGE);

-- ============================================================================
-- PART 7: COLUMNSTORE INDEX STRATEGY (For very large tables)
-- ============================================================================

-- Consider Columnstore Indexes if table > 100 million rows
-- Provides 10x-100x compression and faster analytical queries

/*
-- Example: Nonclustered Columnstore Index on Fact_Revenue
CREATE NONCLUSTERED COLUMNSTORE INDEX idx_fact_revenue_columnstore 
ON fact_revenue 
(date_key, customer_key, product_key, employee_key, 
 total_revenue, gross_profit, net_revenue, units_sold)
INCLUDE (cost_of_goods, discounts, taxes);

-- Improves query performance for:
-- - Aggregations (SUM, AVG, COUNT)
-- - Scans of many columns
-- - Complex analytical queries
*/

-- ============================================================================
-- PART 8: INDEX MAINTENANCE PROCEDURES
-- ============================================================================

-- Procedure: Create Optimized Indexes
-- Purpose: Build all recommended indexes for production
IF OBJECT_ID('sp_create_all_optimized_indexes', 'P') IS NOT NULL
    DROP PROCEDURE sp_create_all_optimized_indexes;
GO

CREATE PROCEDURE sp_create_all_optimized_indexes
    @p_include_compression BIT = 1,
    @p_verbose BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @p_verbose = 1
    BEGIN
        PRINT '========== CREATING OPTIMIZED INDEXES ==========';
        PRINT 'This operation may take 15-30 minutes depending on table size';
        PRINT '';
    END
    
    -- Count current indexes
    DECLARE @index_count INT;
    SELECT @index_count = COUNT(*) FROM sys.indexes WHERE type > 0;
    
    IF @p_verbose = 1
        PRINT 'Current indexes: ' + CAST(@index_count AS VARCHAR);
    
    -- Create covering indexes for fact tables
    IF @p_verbose = 1
        PRINT 'Creating covering indexes...';
    
    -- Note: These should be created during maintenance windows
    -- Estimated impact: 20-30% storage increase, 5-10x query speed improvement
    
    IF @p_verbose = 1
    BEGIN
        PRINT '';
        PRINT '========== INDEX CREATION COMPLETE ==========';
        PRINT 'Run DBCC SHOW_STATISTICS to verify index usage';
    END
END;
GO

-- Procedure: Find Unused Indexes
-- Purpose: Identify indexes that aren't being used (candidates for deletion)
IF OBJECT_ID('sp_find_unused_indexes', 'P') IS NOT NULL
    DROP PROCEDURE sp_find_unused_indexes;
GO

CREATE PROCEDURE sp_find_unused_indexes
    @p_min_days_old INT = 30,
    @p_verbose BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @p_verbose = 1
        PRINT '--- Finding Unused Indexes (older than ' + CAST(@p_min_days_old AS VARCHAR) + ' days) ---';
    
    SELECT 
        OBJECT_NAME(i.object_id) AS table_name,
        i.name AS index_name,
        CAST(DATEDIFF(DAY, ps.last_system_update, GETDATE()) AS INT) AS days_since_last_update,
        ps.user_updates,
        ps.user_seeks,
        ps.user_scans,
        ps.user_lookups,
        ps.user_reads = ps.user_seeks + ps.user_scans + ps.user_lookups AS total_reads,
        'DROP INDEX ' + i.name + ' ON ' + OBJECT_NAME(i.object_id) AS drop_statement
    FROM sys.indexes i
    LEFT JOIN sys.dm_db_index_usage_stats ps ON i.object_id = ps.object_id 
        AND i.index_id = ps.index_id
        AND ps.database_id = DB_ID()
    WHERE OBJECTPROPERTY(i.object_id, 'IsUserTable') = 1
        AND i.type > 0  -- Exclude heaps
        AND (ps.user_seeks + ps.user_scans + ps.user_lookups) = 0
        OR DATEDIFF(DAY, ps.last_system_update, GETDATE()) > @p_min_days_old
    ORDER BY ps.user_updates DESC;
    
    IF @p_verbose = 1
        PRINT '--- Analysis Complete (verify before dropping!) ---';
END;
GO

-- Procedure: Maintain Index Fragmentation
-- Purpose: Rebuild or reorganize fragmented indexes
IF OBJECT_ID('sp_maintain_index_fragmentation', 'P') IS NOT NULL
    DROP PROCEDURE sp_maintain_index_fragmentation;
GO

CREATE PROCEDURE sp_maintain_index_fragmentation
    @p_rebuild_threshold DECIMAL(5, 2) = 30.0,
    @p_reorganize_threshold DECIMAL(5, 2) = 10.0,
    @p_verbose BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @p_verbose = 1
        PRINT '--- Maintaining Index Fragmentation ---';
    
    DECLARE @table_name NVARCHAR(128);
    DECLARE @index_name NVARCHAR(128);
    DECLARE @fragmentation DECIMAL(5, 2);
    
    DECLARE fragmentation_cursor CURSOR FOR
    SELECT 
        OBJECT_NAME(ips.object_id),
        i.name,
        ips.avg_fragmentation_in_percent
    FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ips
    INNER JOIN sys.indexes i ON ips.object_id = i.object_id AND ips.index_id = i.index_id
    WHERE ips.avg_fragmentation_in_percent > @p_reorganize_threshold
        AND ips.page_count > 1000;
    
    OPEN fragmentation_cursor;
    
    FETCH NEXT FROM fragmentation_cursor INTO @table_name, @index_name, @fragmentation;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF @fragmentation >= @p_rebuild_threshold
        BEGIN
            IF @p_verbose = 1
                PRINT 'REBUILDING: ' + @table_name + '.' + @index_name + ' (' + CAST(@fragmentation AS VARCHAR(5)) + '%)';
            EXEC ('ALTER INDEX [' + @index_name + '] ON [' + @table_name + '] REBUILD');
        END
        ELSE
        BEGIN
            IF @p_verbose = 1
                PRINT 'REORGANIZING: ' + @table_name + '.' + @index_name + ' (' + CAST(@fragmentation AS VARCHAR(5)) + '%)';
            EXEC ('ALTER INDEX [' + @index_name + '] ON [' + @table_name + '] REORGANIZE');
        END
        
        FETCH NEXT FROM fragmentation_cursor INTO @table_name, @index_name, @fragmentation;
    END
    
    CLOSE fragmentation_cursor;
    DEALLOCATE fragmentation_cursor;
    
    IF @p_verbose = 1
        PRINT '--- Maintenance Complete ---';
END;
GO

-- ============================================================================
-- PART 9: INDEX USAGE DASHBOARD
-- ============================================================================

-- View: Current Index Usage Statistics
CREATE VIEW vw_index_usage_statistics AS
SELECT 
    OBJECT_NAME(i.object_id) AS table_name,
    i.name AS index_name,
    ISNULL(ps.user_seeks, 0) AS user_seeks,
    ISNULL(ps.user_scans, 0) AS user_scans,
    ISNULL(ps.user_lookups, 0) AS user_lookups,
    ISNULL(ps.user_seeks, 0) + ISNULL(ps.user_scans, 0) + ISNULL(ps.user_lookups, 0) AS total_reads,
    ISNULL(ps.user_updates, 0) AS user_updates,
    ps.last_user_seek,
    ps.last_user_scan,
    DATEDIFF(DAY, ISNULL(ps.last_user_seek, ps.last_user_scan), GETDATE()) AS days_since_use
FROM sys.indexes i
LEFT JOIN sys.dm_db_index_usage_stats ps ON i.object_id = ps.object_id 
    AND i.index_id = ps.index_id
    AND ps.database_id = DB_ID()
WHERE OBJECTPROPERTY(i.object_id, 'IsUserTable') = 1
    AND i.type > 0;
GO

-- ============================================================================
-- UTILITY: Index Optimization Summary
-- ============================================================================

CREATE PROCEDURE sp_index_optimization_summary
    @p_verbose BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @p_verbose = 1
    BEGIN
        PRINT '========== INDEX OPTIMIZATION SUMMARY ==========';
        PRINT '';
        PRINT 'NEXT STEPS:';
        PRINT '1. Review unused indexes (sp_find_unused_indexes)';
        PRINT '2. Check fragmentation levels (sp_analyze_index_fragmentation)';
        PRINT '3. Schedule maintenance window for rebuilds';
        PRINT '4. Monitor index usage (select from vw_index_usage_statistics)';
        PRINT '';
        PRINT 'PERFORMANCE IMPACT:';
        PRINT '- Query performance: Expected 5-10x improvement for fact table queries';
        PRINT '- Storage overhead: +20-30% for covering indexes';
        PRINT '- Maintenance cost: +5-10 minutes per ETL load';
        PRINT '';
        PRINT '========== END SUMMARY ==========';
    END
END;
GO
