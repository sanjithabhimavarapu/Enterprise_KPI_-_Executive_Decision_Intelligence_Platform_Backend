-- ============================================================
-- DIMENSION LOADING PROCEDURES (SCD Type 2 Implementation)
-- ============================================================
-- Purpose: Load dimensions from staging with Slowly Changing Dimension logic
-- Pattern: UPSERT with history tracking
-- Target: Dimension tables (dim_customer, dim_product, dim_employee, etc.)
-- ============================================================

-- ============================================================
-- DIM_CUSTOMER LOADING (SCD Type 2)
-- ============================================================
-- Tracks changes to: customer_segment, annual_contract_value, subscription_status
-- Historical records preserved with valid_from and valid_to dates
-- ============================================================

IF OBJECT_ID('sp_load_dim_customer', 'P') IS NOT NULL
    DROP PROCEDURE sp_load_dim_customer;
GO

CREATE PROCEDURE sp_load_dim_customer
    @LoadDate DATE
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        -- STEP 1: Identify new customers (not in dim_customer)
        CREATE TABLE #new_customers AS
        SELECT DISTINCT
            stg.customer_id,
            stg.customer_name,
            stg.customer_type,
            stg.industry,
            stg.annual_contract_value,
            stg.customer_segment,
            stg.subscription_status,
            stg.is_active_customer,
            @LoadDate AS effective_date
        FROM stg_customers_conformed stg
        WHERE stg.customer_id NOT IN (
            SELECT DISTINCT business_key FROM dim_customer WHERE is_current = 1
        );
        
        -- STEP 2: INSERT new customer records
        INSERT INTO dim_customer (
            business_key, customer_name, customer_type, industry,
            annual_contract_value, customer_segment, subscription_status,
            is_active_customer, effective_date, end_date, is_current, created_date
        )
        SELECT
            nc.customer_id,
            nc.customer_name,
            nc.customer_type,
            nc.industry,
            nc.annual_contract_value,
            nc.customer_segment,
            nc.subscription_status,
            nc.is_active_customer,
            nc.effective_date,
            CAST('9999-12-31' AS DATE) AS end_date,
            1 AS is_current,
            GETDATE() AS created_date
        FROM #new_customers nc;
        
        DECLARE @NewCustomersCount INT = @@ROWCOUNT;
        
        -- STEP 3: Identify changed customers (existing with changed SCD attributes)
        CREATE TABLE #changed_customers AS
        SELECT DISTINCT
            stg.customer_id,
            dc.customer_key,
            stg.customer_name,
            stg.customer_type,
            stg.industry,
            stg.annual_contract_value,
            stg.customer_segment,
            stg.subscription_status,
            stg.is_active_customer,
            dc.annual_contract_value AS old_acv,
            dc.customer_segment AS old_segment,
            dc.subscription_status AS old_status
        FROM stg_customers_conformed stg
        INNER JOIN dim_customer dc ON stg.customer_id = dc.business_key
        WHERE dc.is_current = 1
        AND (
            -- SCD Type 2 tracked attributes changed
            stg.annual_contract_value != ISNULL(dc.annual_contract_value, 0)
            OR stg.customer_segment != ISNULL(dc.customer_segment, '')
            OR stg.subscription_status != ISNULL(dc.subscription_status, '')
        );
        
        -- STEP 4: Close old records for changed customers
        UPDATE dim_customer
        SET is_current = 0,
            end_date = DATEADD(DAY, -1, @LoadDate)
        FROM dim_customer dc
        INNER JOIN #changed_customers cc ON dc.customer_key = cc.customer_key
        WHERE dc.is_current = 1;
        
        DECLARE @OldRecordsCount INT = @@ROWCOUNT;
        
        -- STEP 5: INSERT new versions of changed records
        INSERT INTO dim_customer (
            business_key, customer_name, customer_type, industry,
            annual_contract_value, customer_segment, subscription_status,
            is_active_customer, effective_date, end_date, is_current, created_date
        )
        SELECT
            cc.customer_id,
            cc.customer_name,
            cc.customer_type,
            cc.industry,
            cc.annual_contract_value,
            cc.customer_segment,
            cc.subscription_status,
            cc.is_active_customer,
            @LoadDate,
            CAST('9999-12-31' AS DATE),
            1 AS is_current,
            GETDATE()
        FROM #changed_customers cc;
        
        DECLARE @NewVersionsCount INT = @@ROWCOUNT;
        
        -- STEP 6: Update non-SCD attributes on current records (Type 1)
        UPDATE dim_customer
        SET customer_name = stg.customer_name,
            customer_type = stg.customer_type,
            industry = stg.industry,
            is_active_customer = stg.is_active_customer,
            last_update_date = GETDATE()
        FROM dim_customer dc
        INNER JOIN stg_customers_conformed stg ON dc.business_key = stg.customer_id
        WHERE dc.is_current = 1
        AND (
            dc.customer_name != stg.customer_name
            OR dc.customer_type != stg.customer_type
            OR dc.industry != stg.industry
            OR dc.is_active_customer != stg.is_active_customer
        );
        
        DECLARE @UpdatedCount INT = @@ROWCOUNT;
        
        -- Logging
        INSERT INTO etl_logs (
            process_name, process_step, record_count, status, log_date, details
        )
        VALUES (
            'sp_load_dim_customer',
            'Complete',
            @NewCustomersCount + @NewVersionsCount,
            'SUCCESS',
            @LoadDate,
            'New Records: ' + CAST(@NewCustomersCount AS VARCHAR(10)) +
            ' | Old Records Closed: ' + CAST(@OldRecordsCount AS VARCHAR(10)) +
            ' | New Versions: ' + CAST(@NewVersionsCount AS VARCHAR(10)) +
            ' | Type 1 Updates: ' + CAST(@UpdatedCount AS VARCHAR(10))
        );
        
        PRINT 'SUCCESS: dim_customer loaded. New: ' + CAST(@NewCustomersCount AS VARCHAR(10)) +
              ' | Versions: ' + CAST(@NewVersionsCount AS VARCHAR(10));
        
        DROP TABLE #new_customers;
        DROP TABLE #changed_customers;
        
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMsg NVARCHAR(MAX) = ERROR_MESSAGE();
        PRINT 'ERROR in sp_load_dim_customer: ' + @ErrorMsg;
        
        INSERT INTO etl_logs (
            process_name, process_step, record_count, status, log_date, details
        )
        VALUES (
            'sp_load_dim_customer',
            'Error',
            0,
            'FAILED',
            @LoadDate,
            @ErrorMsg
        );
        
        THROW;
    END CATCH
END;
GO

-- ============================================================
-- DIM_PRODUCT LOADING (SCD Type 2)
-- ============================================================
-- Tracks changes to: product_category, unit_price, supplier, lead_time
-- ============================================================

CREATE PROCEDURE sp_load_dim_product
    @LoadDate DATE
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        -- STEP 1: Load new products
        INSERT INTO dim_product (
            business_key, product_name, product_category, unit_price,
            supplier_id, lead_time_days, is_active, effective_date, end_date, is_current
        )
        SELECT DISTINCT
            stg.product_sku,
            stg.product_name,
            stg.product_category,
            stg.unit_price,
            stg.supplier_id,
            stg.lead_time_days,
            stg.is_active,
            @LoadDate,
            CAST('9999-12-31' AS DATE),
            1
        FROM stg_products_conformed stg
        WHERE stg.product_sku NOT IN (
            SELECT DISTINCT business_key FROM dim_product WHERE is_current = 1
        );
        
        DECLARE @NewProductsCount INT = @@ROWCOUNT;
        
        -- STEP 2: Track SCD Type 2 changes (price, category, supplier, lead time)
        UPDATE dim_product
        SET is_current = 0,
            end_date = DATEADD(DAY, -1, @LoadDate)
        WHERE product_key IN (
            SELECT dp.product_key
            FROM dim_product dp
            INNER JOIN stg_products_conformed stg ON dp.business_key = stg.product_sku
            WHERE dp.is_current = 1
            AND (
                dp.product_category != stg.product_category
                OR dp.unit_price != stg.unit_price
                OR dp.supplier_id != stg.supplier_id
                OR dp.lead_time_days != stg.lead_time_days
            )
        );
        
        DECLARE @OldVersionsCount INT = @@ROWCOUNT;
        
        -- STEP 3: Insert new versions
        INSERT INTO dim_product (
            business_key, product_name, product_category, unit_price,
            supplier_id, lead_time_days, is_active, effective_date, end_date, is_current
        )
        SELECT DISTINCT
            stg.product_sku,
            stg.product_name,
            stg.product_category,
            stg.unit_price,
            stg.supplier_id,
            stg.lead_time_days,
            stg.is_active,
            @LoadDate,
            CAST('9999-12-31' AS DATE),
            1
        FROM stg_products_conformed stg
        WHERE stg.product_sku IN (
            SELECT business_key FROM dim_product WHERE is_current = 0 AND end_date = DATEADD(DAY, -1, @LoadDate)
        );
        
        DECLARE @NewVersionsCount INT = @@ROWCOUNT;
        
        INSERT INTO etl_logs (
            process_name, process_step, record_count, status, log_date, details
        )
        VALUES (
            'sp_load_dim_product',
            'Complete',
            @NewProductsCount + @NewVersionsCount,
            'SUCCESS',
            @LoadDate,
            'New Products: ' + CAST(@NewProductsCount AS VARCHAR(10)) +
            ' | New Versions (SCD): ' + CAST(@NewVersionsCount AS VARCHAR(10)) +
            ' | Old Versions Closed: ' + CAST(@OldVersionsCount AS VARCHAR(10))
        );
        
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMsg NVARCHAR(MAX) = ERROR_MESSAGE();
        INSERT INTO etl_logs VALUES ('sp_load_dim_product', 'Error', 0, 'FAILED', @LoadDate, @ErrorMsg);
        THROW;
    END CATCH
END;
GO

-- ============================================================
-- DIM_DATE (Reference Dimension - Pre-populated)
-- ============================================================
-- Generate dates for 10-year period with all attributes
-- Run once, no updates needed

CREATE PROCEDURE sp_load_dim_date
    @StartDate DATE,
    @EndDate DATE
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @CurrentDate DATE = @StartDate;
    
    WHILE @CurrentDate <= @EndDate
    BEGIN
        INSERT INTO dim_date (
            date_key, date_value, year_number, month_number, day_of_month,
            day_of_week, week_of_year, quarter_number, fiscal_year,
            date_description, is_weekend, is_holiday
        )
        VALUES (
            CAST(FORMAT(@CurrentDate, 'yyyyMMdd') AS INT),
            @CurrentDate,
            YEAR(@CurrentDate),
            MONTH(@CurrentDate),
            DAY(@CurrentDate),
            DATEPART(WEEKDAY, @CurrentDate),
            DATEPART(WEEK, @CurrentDate),
            DATEPART(QUARTER, @CurrentDate),
            CASE WHEN MONTH(@CurrentDate) >= 7
                 THEN YEAR(@CurrentDate) + 1
                 ELSE YEAR(@CurrentDate) END,
            FORMAT(@CurrentDate, 'dddd, MMMM dd, yyyy'),
            CASE WHEN DATEPART(WEEKDAY, @CurrentDate) IN (1, 7) THEN 1 ELSE 0 END,
            CASE WHEN FORMAT(@CurrentDate, 'MM-dd') IN ('01-01', '12-25') THEN 1 ELSE 0 END
        );
        
        SET @CurrentDate = DATEADD(DAY, 1, @CurrentDate);
    END
    
    PRINT 'Dimension dates loaded from ' + CAST(@StartDate AS VARCHAR(10)) + 
          ' to ' + CAST(@EndDate AS VARCHAR(10));
END;
GO
