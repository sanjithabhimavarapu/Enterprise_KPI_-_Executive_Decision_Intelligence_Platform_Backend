-- ============================================================
-- FACT TABLE LOADING PROCEDURES
-- ============================================================
-- Purpose: Load transactional and aggregate facts from staging
-- Pattern: Incremental loads with dimension key lookups
-- Handles: Reconciliation, CDC tracking, data quality checks
-- ============================================================

-- ============================================================
-- FACT_SALES LOADING (Transactional - ~500K records/day)
-- ============================================================

CREATE PROCEDURE sp_load_fact_sales
    @LoadDate DATE,
    @IsIncrementalLoad BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        -- STEP 1: Get dimension keys from staging
        CREATE TABLE #fact_sales_staging AS
        SELECT
            stg.order_id AS order_business_key,
            stg.order_date,
            stg.order_timestamp,
            ISNULL(dc.customer_key, -1) AS customer_key,
            ISNULL(dp.product_key, -1) AS product_key,
            ISNULL(dw.warehouse_key, -1) AS warehouse_key,
            ISNULL(ddate.date_key, -1) AS date_key,
            
            -- Order metrics
            stg.order_quantity,
            stg.unit_price,
            stg.gross_amount,
            stg.discount_percent,
            stg.discount_amount,
            stg.net_amount,
            
            -- Cost & margin
            stg.product_cost,
            stg.freight_cost,
            stg.duty_cost,
            stg.gross_profit,
            stg.gross_margin_percent,
            
            -- Fulfillment
            stg.delivery_days,
            stg.on_time_delivery_flag,
            
            -- Status
            stg.order_status_code,
            stg.is_cancelled,
            stg.is_returned,
            
            -- Metadata
            stg.source_load_date,
            stg.source_system_code,
            GETDATE() AS etl_load_timestamp
            
        FROM stg_orders_conformed stg
        LEFT JOIN dim_customer dc ON stg.customer_business_key = dc.business_key 
                                    AND dc.is_current = 1
        LEFT JOIN dim_product dp ON stg.product_sku = dp.business_key 
                                   AND dp.is_current = 1
        LEFT JOIN dim_warehouse dw ON stg.warehouse_code = dw.business_key
        LEFT JOIN dim_date ddate ON stg.order_date = ddate.date_value
        WHERE stg.dq_validation_status = 'VALID'
        AND (
            @IsIncrementalLoad = 0  -- Full reload flag
            OR stg.record_load_timestamp >= DATEADD(DAY, -1, GETDATE())  -- Last 24 hours for incremental
        );
        
        -- STEP 2: Insert new facts
        INSERT INTO fact_sales (
            order_business_key, order_date_key, order_timestamp,
            customer_key, product_key, warehouse_key,
            order_quantity, unit_price,
            gross_amount, discount_percent, discount_amount, net_amount,
            product_cost, freight_cost, duty_cost,
            gross_profit, gross_margin_percent,
            delivery_days, on_time_delivery_flag,
            order_status, is_cancelled, is_returned,
            load_date, etl_load_timestamp
        )
        SELECT
            fss.order_business_key,
            fss.date_key,
            fss.order_timestamp,
            fss.customer_key,
            fss.product_key,
            fss.warehouse_key,
            fss.order_quantity,
            fss.unit_price,
            fss.gross_amount,
            fss.discount_percent,
            fss.discount_amount,
            fss.net_amount,
            fss.product_cost,
            fss.freight_cost,
            fss.duty_cost,
            fss.gross_profit,
            fss.gross_margin_percent,
            fss.delivery_days,
            fss.on_time_delivery_flag,
            fss.order_status_code,
            fss.is_cancelled,
            fss.is_returned,
            @LoadDate,
            fss.etl_load_timestamp
        FROM #fact_sales_staging fss
        WHERE NOT EXISTS (
            SELECT 1 FROM fact_sales fs
            WHERE fs.order_business_key = fss.order_business_key
        );
        
        DECLARE @NewFactsCount INT = @@ROWCOUNT;
        
        -- STEP 3: Log metrics
        INSERT INTO etl_logs (
            process_name, process_step, record_count, status, log_date, details
        )
        VALUES (
            'sp_load_fact_sales',
            'Complete',
            @NewFactsCount,
            'SUCCESS',
            @LoadDate,
            'Fact Sales loaded: ' + CAST(@NewFactsCount AS VARCHAR(10)) +
            ' | Incremental: ' + CAST(@IsIncrementalLoad AS VARCHAR(1))
        );
        
        PRINT 'SUCCESS: fact_sales loaded. Records: ' + CAST(@NewFactsCount AS VARCHAR(10));
        
        DROP TABLE #fact_sales_staging;
        
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMsg NVARCHAR(MAX) = ERROR_MESSAGE();
        PRINT 'ERROR in sp_load_fact_sales: ' + @ErrorMsg;
        
        INSERT INTO etl_logs VALUES (
            'sp_load_fact_sales', 'Error', 0, 'FAILED', @LoadDate, @ErrorMsg
        );
        THROW;
    END CATCH
END;
GO

-- ============================================================
-- FACT_REVENUE LOADING (Daily Aggregate)
-- ============================================================

CREATE PROCEDURE sp_load_fact_revenue
    @LoadDate DATE
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        -- Aggregate sales by customer/product/date
        INSERT INTO fact_revenue (
            date_key, customer_key, product_key, warehouse_key,
            total_orders, total_quantity, total_gross_amount,
            total_discount_amount, total_net_revenue,
            total_product_cost, total_freight_cost, total_duty_cost,
            total_gross_profit, avg_margin_percent,
            avg_delivery_days, on_time_count, late_count,
            load_date, etl_load_timestamp
        )
        SELECT
            ddate.date_key,
            fs.customer_key,
            fs.product_key,
            fs.warehouse_key,
            
            -- Aggregate metrics
            COUNT(DISTINCT fs.order_business_key) AS total_orders,
            SUM(fs.order_quantity) AS total_quantity,
            SUM(fs.gross_amount) AS total_gross_amount,
            SUM(fs.discount_amount) AS total_discount_amount,
            SUM(fs.net_amount) AS total_net_revenue,
            
            -- Cost aggregates
            SUM(fs.product_cost) AS total_product_cost,
            SUM(fs.freight_cost) AS total_freight_cost,
            SUM(fs.duty_cost) AS total_duty_cost,
            SUM(fs.gross_profit) AS total_gross_profit,
            AVG(fs.gross_margin_percent) AS avg_margin_percent,
            
            -- Fulfillment metrics
            AVG(fs.delivery_days) AS avg_delivery_days,
            SUM(CASE WHEN fs.on_time_delivery_flag = 1 THEN 1 ELSE 0 END) AS on_time_count,
            SUM(CASE WHEN fs.on_time_delivery_flag = 0 THEN 1 ELSE 0 END) AS late_count,
            
            @LoadDate,
            GETDATE()
        
        FROM fact_sales fs
        INNER JOIN dim_date ddate ON fs.order_date_key = ddate.date_key
        WHERE fs.load_date = @LoadDate
        AND fs.customer_key != -1
        AND fs.product_key != -1
        GROUP BY
            ddate.date_key, fs.customer_key, fs.product_key, fs.warehouse_key;
        
        DECLARE @RevenueFactsCount INT = @@ROWCOUNT;
        
        INSERT INTO etl_logs VALUES (
            'sp_load_fact_revenue', 'Complete', @RevenueFactsCount, 'SUCCESS',
            @LoadDate, 'Revenue facts aggregated: ' + CAST(@RevenueFactsCount AS VARCHAR(10))
        );
        
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMsg NVARCHAR(MAX) = ERROR_MESSAGE();
        INSERT INTO etl_logs VALUES ('sp_load_fact_revenue', 'Error', 0, 'FAILED', @LoadDate, @ErrorMsg);
        THROW;
    END CATCH
END;
GO

-- ============================================================
-- FACT_CUSTOMER_INTERACTIONS LOADING (~2M records/day)
-- ============================================================

CREATE PROCEDURE sp_load_fact_customer_interactions
    @LoadDate DATE
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        INSERT INTO fact_customer_interactions (
            interaction_business_key, interaction_date_key, interaction_type,
            customer_key, employee_key, interaction_timestamp,
            interaction_duration_minutes, interaction_outcome,
            engagement_score, is_successful, created_date, etl_load_timestamp
        )
        SELECT
            sci.interaction_id,
            ddate.date_key,
            sci.interaction_type,
            ISNULL(dc.customer_key, -1),
            ISNULL(de.employee_key, -1),
            sci.interaction_timestamp,
            sci.interaction_duration_minutes,
            sci.outcome,
            sci.engagement_score,
            sci.is_successful,
            @LoadDate,
            GETDATE()
        
        FROM stg_customer_interactions_conformed sci
        INNER JOIN dim_date ddate ON sci.interaction_date = ddate.date_value
        LEFT JOIN dim_customer dc ON sci.customer_id = dc.business_key AND dc.is_current = 1
        LEFT JOIN dim_employee de ON sci.employee_id = de.business_key AND de.is_current = 1
        WHERE sci.source_load_date = @LoadDate;
        
        DECLARE @InteractionCount INT = @@ROWCOUNT;
        PRINT 'SUCCESS: fact_customer_interactions loaded. Records: ' + CAST(@InteractionCount AS VARCHAR(10));
        
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMsg NVARCHAR(MAX) = ERROR_MESSAGE();
        PRINT 'ERROR in sp_load_fact_customer_interactions: ' + @ErrorMsg;
        THROW;
    END CATCH
END;
GO

-- ============================================================
-- MASTER FACT LOADING ORCHESTRATION
-- ============================================================

CREATE PROCEDURE sp_load_all_facts
    @LoadDate DATE,
    @IsIncrementalLoad BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime DATETIME2 = GETDATE();
    DECLARE @ProcessStep VARCHAR(100);
    
    BEGIN TRY
        SET @ProcessStep = 'Loading Sales Facts';
        PRINT @ProcessStep;
        EXEC sp_load_fact_sales @LoadDate, @IsIncrementalLoad;
        
        SET @ProcessStep = 'Loading Revenue Aggregates';
        PRINT @ProcessStep;
        EXEC sp_load_fact_revenue @LoadDate;
        
        SET @ProcessStep = 'Loading Customer Interactions';
        PRINT @ProcessStep;
        EXEC sp_load_fact_customer_interactions @LoadDate;
        
        -- Additional fact loading procedures would go here
        
        DECLARE @EndTime DATETIME2 = GETDATE();
        DECLARE @DurationSeconds INT = DATEDIFF(SECOND, @StartTime, @EndTime);
        
        INSERT INTO etl_logs VALUES (
            'sp_load_all_facts', 'Complete', 0, 'SUCCESS', @LoadDate,
            'All facts loaded in ' + CAST(@DurationSeconds AS VARCHAR(10)) + ' seconds'
        );
        
        PRINT 'SUCCESS: All facts loaded in ' + CAST(@DurationSeconds AS VARCHAR(10)) + ' seconds';
        
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMsg NVARCHAR(MAX) = ERROR_MESSAGE();
        PRINT 'ERROR in ' + @ProcessStep + ': ' + @ErrorMsg;
        
        INSERT INTO etl_logs VALUES (
            'sp_load_all_facts', @ProcessStep, 0, 'FAILED', @LoadDate, @ErrorMsg
        );
        THROW;
    END CATCH
END;
GO
