-- ============================================================
-- DATA QUALITY, VALIDATION & RECONCILIATION PROCEDURES
-- ============================================================
-- Purpose: Ensure data integrity throughout ETL pipeline
-- Includes: Pre-load validation, post-load reconciliation, DQ scoring
-- ============================================================

-- ============================================================
-- PRE-LOAD VALIDATION (Source Data Quality Checks)
-- ============================================================

CREATE PROCEDURE sp_validate_staging_completeness
    @StagingTable VARCHAR(100),
    @LoadDate DATE
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @MissingCount INT;
    DECLARE @InvalidCount INT;
    DECLARE @DuplicateCount INT;
    DECLARE @ValidationMessage NVARCHAR(MAX);
    
    BEGIN TRY
        -- Check 1: Missing required fields
        IF @StagingTable = 'stg_raw_erp_orders'
        BEGIN
            SELECT @MissingCount = COUNT(*)
            FROM stg_raw_erp_orders
            WHERE CAST(LOAD_DATE AS DATE) = @LoadDate
            AND (ORDER_NUMBER IS NULL 
                 OR CUSTOMER_CODE IS NULL 
                 OR PRODUCT_CODE IS NULL 
                 OR ORDER_DATE IS NULL);
            
            SET @ValidationMessage = 'Missing required fields in ERP Orders: ' + CAST(@MissingCount AS VARCHAR(10));
        END;
        
        -- Check 2: Duplicate records
        IF @StagingTable = 'stg_raw_erp_orders'
        BEGIN
            SELECT @DuplicateCount = COUNT(*) - COUNT(DISTINCT ORDER_NUMBER)
            FROM stg_raw_erp_orders
            WHERE CAST(LOAD_DATE AS DATE) = @LoadDate;
            
            SET @ValidationMessage = @ValidationMessage + ' | Duplicates: ' + CAST(@DuplicateCount AS VARCHAR(10));
        END;
        
        -- Check 3: Data type validity
        IF @StagingTable = 'stg_raw_erp_orders'
        BEGIN
            SELECT @InvalidCount = COUNT(*)
            FROM stg_raw_erp_orders
            WHERE CAST(LOAD_DATE AS DATE) = @LoadDate
            AND (
                TRY_CAST(ORDER_QTY AS DECIMAL(12,2)) IS NULL
                OR TRY_CAST(UNIT_PRICE AS DECIMAL(12,4)) IS NULL
                OR TRY_CAST(ORDER_DATE AS DATE) IS NULL
            );
            
            SET @ValidationMessage = @ValidationMessage + ' | Invalid types: ' + CAST(@InvalidCount AS VARCHAR(10));
        END;
        
        INSERT INTO dq_validation_logs (
            table_name, validation_run_time, total_records, invalid_records, 
            valid_records, quality_score, validation_detail
        )
        SELECT
            @StagingTable,
            GETDATE(),
            COUNT(*),
            @MissingCount + @InvalidCount,
            COUNT(*) - (@MissingCount + @InvalidCount),
            CASE 
                WHEN COUNT(*) > 0 
                THEN ROUND(((COUNT(*) - (@MissingCount + @InvalidCount)) * 100.0 / COUNT(*)), 2)
                ELSE 0 
            END,
            @ValidationMessage
        FROM (
            SELECT * FROM stg_raw_erp_orders
            WHERE CAST(LOAD_DATE AS DATE) = @LoadDate
            UNION ALL
            SELECT * FROM stg_raw_salesforce_customers
            WHERE CAST(LOAD_DATE AS DATE) = @LoadDate
        ) stg;
        
        PRINT 'Data Quality Check Complete: ' + @ValidationMessage;
        
    END TRY
    BEGIN CATCH
        PRINT 'ERROR in sp_validate_staging_completeness: ' + ERROR_MESSAGE();
        THROW;
    END CATCH
END;
GO

-- ============================================================
-- RECONCILIATION: Source vs Staging vs Facts
-- ============================================================

CREATE PROCEDURE sp_reconcile_etl_totals
    @LoadDate DATE
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        -- Create reconciliation summary
        INSERT INTO etl_reconciliation (
            load_date, reconciliation_type, source_name,
            source_record_count, source_total_amount,
            staging_record_count, staging_total_amount,
            fact_record_count, fact_total_amount,
            record_variance, amount_variance_percent,
            reconciliation_status, reconciliation_notes
        )
        
        -- ERP ORDERS RECONCILIATION
        SELECT
            @LoadDate,
            'Orders',
            'ERP',
            (SELECT COUNT(*) FROM stg_raw_erp_orders WHERE CAST(LOAD_DATE AS DATE) = @LoadDate),
            (SELECT SUM(CAST(GROSS_AMOUNT AS DECIMAL(14,2))) FROM stg_raw_erp_orders WHERE CAST(LOAD_DATE AS DATE) = @LoadDate),
            (SELECT COUNT(*) FROM stg_orders_conformed WHERE source_load_date = @LoadDate),
            (SELECT SUM(gross_amount) FROM stg_orders_conformed WHERE source_load_date = @LoadDate),
            (SELECT COUNT(*) FROM fact_sales WHERE load_date = @LoadDate),
            (SELECT SUM(gross_amount) FROM fact_sales WHERE load_date = @LoadDate),
            (SELECT COUNT(*) FROM stg_raw_erp_orders WHERE CAST(LOAD_DATE AS DATE) = @LoadDate) -
            (SELECT COUNT(*) FROM stg_orders_conformed WHERE source_load_date = @LoadDate),
            CASE 
                WHEN (SELECT SUM(CAST(GROSS_AMOUNT AS DECIMAL(14,2))) FROM stg_raw_erp_orders WHERE CAST(LOAD_DATE AS DATE) = @LoadDate) > 0
                THEN ROUND(
                    ABS((SELECT SUM(CAST(GROSS_AMOUNT AS DECIMAL(14,2))) FROM stg_raw_erp_orders WHERE CAST(LOAD_DATE AS DATE) = @LoadDate) -
                        (SELECT SUM(gross_amount) FROM fact_sales WHERE load_date = @LoadDate)) /
                    (SELECT SUM(CAST(GROSS_AMOUNT AS DECIMAL(14,2))) FROM stg_raw_erp_orders WHERE CAST(LOAD_DATE AS DATE) = @LoadDate) * 100, 2
                )
                ELSE 0 
            END,
            CASE 
                WHEN ROUND(
                    ABS((SELECT SUM(CAST(GROSS_AMOUNT AS DECIMAL(14,2))) FROM stg_raw_erp_orders WHERE CAST(LOAD_DATE AS DATE) = @LoadDate) -
                        (SELECT SUM(gross_amount) FROM fact_sales WHERE load_date = @LoadDate)) /
                    NULLIF(SELECT SUM(CAST(GROSS_AMOUNT AS DECIMAL(14,2))) FROM stg_raw_erp_orders WHERE CAST(LOAD_DATE AS DATE) = @LoadDate, 0) * 100, 2) < 0.01
                THEN 'PASS'
                ELSE 'FAIL' 
            END,
            'Order amount reconciliation completed'
        
        UNION ALL
        
        -- CUSTOMER RECONCILIATION
        SELECT
            @LoadDate,
            'Customers',
            'SALESFORCE',
            (SELECT COUNT(*) FROM stg_raw_salesforce_customers WHERE CAST(LOAD_DATE AS DATE) = @LoadDate),
            NULL, -- Customers don't have amounts
            (SELECT COUNT(*) FROM stg_customers_conformed WHERE source_load_date = @LoadDate),
            NULL,
            (SELECT COUNT(*) FROM dim_customer WHERE effective_date = @LoadDate),
            NULL,
            (SELECT COUNT(*) FROM stg_raw_salesforce_customers WHERE CAST(LOAD_DATE AS DATE) = @LoadDate) -
            (SELECT COUNT(*) FROM stg_customers_conformed WHERE source_load_date = @LoadDate),
            NULL,
            CASE 
                WHEN (SELECT COUNT(*) FROM stg_raw_salesforce_customers WHERE CAST(LOAD_DATE AS DATE) = @LoadDate) =
                     (SELECT COUNT(*) FROM stg_customers_conformed WHERE source_load_date = @LoadDate)
                THEN 'PASS'
                ELSE 'FAIL' 
            END,
            'Customer record count reconciliation';
        
        INSERT INTO etl_logs VALUES (
            'sp_reconcile_etl_totals', 'Complete', 0, 'SUCCESS', @LoadDate,
            'Reconciliation checks completed'
        );
        
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMsg NVARCHAR(MAX) = ERROR_MESSAGE();
        INSERT INTO etl_logs VALUES ('sp_reconcile_etl_totals', 'Error', 0, 'FAILED', @LoadDate, @ErrorMsg);
        PRINT 'ERROR in sp_reconcile_etl_totals: ' + @ErrorMsg;
        THROW;
    END CATCH
END;
GO

-- ============================================================
-- DATA QUALITY SCORING
-- ============================================================

CREATE PROCEDURE sp_calculate_dq_score
    @LoadDate DATE
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        -- Overall DQ Score = Weighted combination of multiple factors
        INSERT INTO dq_scores (
            load_date, calculation_timestamp,
            completeness_score, accuracy_score, consistency_score,
            timeliness_score, validity_score,
            overall_dq_score, dq_status
        )
        SELECT
            @LoadDate,
            GETDATE(),
            
            -- Completeness (% of records with all required fields populated)
            ROUND(
                COUNT(CASE WHEN ORDER_NUMBER IS NOT NULL 
                           AND CUSTOMER_CODE IS NOT NULL 
                           AND PRODUCT_CODE IS NOT NULL 
                           THEN 1 END) * 100.0 / NULLIF(COUNT(*), 0), 2
            ),
            
            -- Accuracy (% of records passing validation checks)
            ROUND(
                COUNT(CASE WHEN TRY_CAST(ORDER_QTY AS DECIMAL) IS NOT NULL 
                           AND TRY_CAST(UNIT_PRICE AS DECIMAL) IS NOT NULL 
                           THEN 1 END) * 100.0 / NULLIF(COUNT(*), 0), 2
            ),
            
            -- Consistency (% of records with no duplicate keys)
            ROUND(
                (COUNT(*) - COUNT(DISTINCT ORDER_NUMBER)) * 100.0 / NULLIF(COUNT(*), 0), 2
            ),
            
            -- Timeliness (% of data loaded within expected time window)
            ROUND(
                COUNT(CASE WHEN DATEDIFF(HOUR, CAST(LOAD_DATE AS DATETIME2), GETDATE()) <= 24 
                           THEN 1 END) * 100.0 / NULLIF(COUNT(*), 0), 2
            ),
            
            -- Validity (% of records with valid data types and ranges)
            ROUND(
                COUNT(CASE WHEN CAST(ORDER_QTY AS DECIMAL) > 0 
                           AND CAST(UNIT_PRICE AS DECIMAL) > 0 
                           THEN 1 END) * 100.0 / NULLIF(COUNT(*), 0), 2
            ),
            
            -- Overall Score (weighted average)
            ROUND(
                (COUNT(CASE WHEN ORDER_NUMBER IS NOT NULL THEN 1 END) * 100.0 / NULLIF(COUNT(*), 0) * 0.20 +  -- Completeness 20%
                 COUNT(CASE WHEN TRY_CAST(ORDER_QTY AS DECIMAL) IS NOT NULL THEN 1 END) * 100.0 / NULLIF(COUNT(*), 0) * 0.25 +  -- Accuracy 25%
                 (100 - (COUNT(*) - COUNT(DISTINCT ORDER_NUMBER)) * 100.0 / NULLIF(COUNT(*), 0)) * 0.25 +  -- Consistency 25%
                 COUNT(CASE WHEN DATEDIFF(HOUR, CAST(LOAD_DATE AS DATETIME2), GETDATE()) <= 24 THEN 1 END) * 100.0 / NULLIF(COUNT(*), 0) * 0.15 +  -- Timeliness 15%
                 COUNT(CASE WHEN CAST(ORDER_QTY AS DECIMAL) > 0 THEN 1 END) * 100.0 / NULLIF(COUNT(*), 0) * 0.15),  -- Validity 15%
                2
            ),
            
            -- DQ Status
            CASE 
                WHEN (COUNT(CASE WHEN ORDER_NUMBER IS NOT NULL THEN 1 END) * 100.0 / NULLIF(COUNT(*), 0) * 0.20 +
                      COUNT(CASE WHEN TRY_CAST(ORDER_QTY AS DECIMAL) IS NOT NULL THEN 1 END) * 100.0 / NULLIF(COUNT(*), 0) * 0.25 +
                      (100 - (COUNT(*) - COUNT(DISTINCT ORDER_NUMBER)) * 100.0 / NULLIF(COUNT(*), 0)) * 0.25 +
                      COUNT(CASE WHEN DATEDIFF(HOUR, CAST(LOAD_DATE AS DATETIME2), GETDATE()) <= 24 THEN 1 END) * 100.0 / NULLIF(COUNT(*), 0) * 0.15 +
                      COUNT(CASE WHEN CAST(ORDER_QTY AS DECIMAL) > 0 THEN 1 END) * 100.0 / NULLIF(COUNT(*), 0) * 0.15) >= 90
                THEN 'Excellent'
                WHEN (COUNT(CASE WHEN ORDER_NUMBER IS NOT NULL THEN 1 END) * 100.0 / NULLIF(COUNT(*), 0) * 0.20 +
                      COUNT(CASE WHEN TRY_CAST(ORDER_QTY AS DECIMAL) IS NOT NULL THEN 1 END) * 100.0 / NULLIF(COUNT(*), 0) * 0.25 +
                      (100 - (COUNT(*) - COUNT(DISTINCT ORDER_NUMBER)) * 100.0 / NULLIF(COUNT(*), 0)) * 0.25 +
                      COUNT(CASE WHEN DATEDIFF(HOUR, CAST(LOAD_DATE AS DATETIME2), GETDATE()) <= 24 THEN 1 END) * 100.0 / NULLIF(COUNT(*), 0) * 0.15 +
                      COUNT(CASE WHEN CAST(ORDER_QTY AS DECIMAL) > 0 THEN 1 END) * 100.0 / NULLIF(COUNT(*), 0) * 0.15) >= 75
                THEN 'Good'
                WHEN (COUNT(CASE WHEN ORDER_NUMBER IS NOT NULL THEN 1 END) * 100.0 / NULLIF(COUNT(*), 0) * 0.20 +
                      COUNT(CASE WHEN TRY_CAST(ORDER_QTY AS DECIMAL) IS NOT NULL THEN 1 END) * 100.0 / NULLIF(COUNT(*), 0) * 0.25 +
                      (100 - (COUNT(*) - COUNT(DISTINCT ORDER_NUMBER)) * 100.0 / NULLIF(COUNT(*), 0)) * 0.25 +
                      COUNT(CASE WHEN DATEDIFF(HOUR, CAST(LOAD_DATE AS DATETIME2), GETDATE()) <= 24 THEN 1 END) * 100.0 / NULLIF(COUNT(*), 0) * 0.15 +
                      COUNT(CASE WHEN CAST(ORDER_QTY AS DECIMAL) > 0 THEN 1 END) * 100.0 / NULLIF(COUNT(*), 0) * 0.15) >= 60
                THEN 'Fair'
                ELSE 'Poor'
            END
        
        FROM stg_raw_erp_orders
        WHERE CAST(LOAD_DATE AS DATE) = @LoadDate;
        
        PRINT 'DQ Score calculation completed for ' + CAST(@LoadDate AS VARCHAR(10));
        
    END TRY
    BEGIN CATCH
        PRINT 'ERROR in sp_calculate_dq_score: ' + ERROR_MESSAGE();
        THROW;
    END CATCH
END;
GO

-- ============================================================
-- REFERENTIAL INTEGRITY CHECKS
-- ============================================================

CREATE PROCEDURE sp_check_referential_integrity
    @LoadDate DATE
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        -- Find orphaned records (fact references non-existent dimensions)
        
        -- Orphaned customer references
        INSERT INTO data_issues (
            issue_date, issue_type, source_table, target_table,
            issue_count, issue_description, severity
        )
        SELECT
            @LoadDate,
            'Orphaned Key Reference',
            'fact_sales',
            'dim_customer',
            COUNT(*),
            'fact_sales records with customer_key not in dim_customer',
            'HIGH'
        FROM fact_sales fs
        WHERE fs.load_date = @LoadDate
        AND fs.customer_key != -1
        AND NOT EXISTS (
            SELECT 1 FROM dim_customer dc WHERE dc.customer_key = fs.customer_key
        );
        
        -- Orphaned product references
        INSERT INTO data_issues (
            issue_date, issue_type, source_table, target_table,
            issue_count, issue_description, severity
        )
        SELECT
            @LoadDate,
            'Orphaned Key Reference',
            'fact_sales',
            'dim_product',
            COUNT(*),
            'fact_sales records with product_key not in dim_product',
            'HIGH'
        FROM fact_sales fs
        WHERE fs.load_date = @LoadDate
        AND fs.product_key != -1
        AND NOT EXISTS (
            SELECT 1 FROM dim_product dp WHERE dp.product_key = fs.product_key
        );
        
        PRINT 'Referential integrity checks completed';
        
    END TRY
    BEGIN CATCH
        PRINT 'ERROR in sp_check_referential_integrity: ' + ERROR_MESSAGE();
        THROW;
    END CATCH
END;
GO

-- ============================================================
-- DUPLICATE DETECTION & HANDLING
-- ============================================================

CREATE PROCEDURE sp_detect_duplicates
    @TableName VARCHAR(100),
    @BusinessKeyColumns VARCHAR(500),
    @LoadDate DATE
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        PRINT 'Detecting duplicates in ' + @TableName + ' using key: ' + @BusinessKeyColumns;
        
        -- Generic approach: Flag duplicates based on business key
        IF @TableName = 'stg_orders_conformed'
        BEGIN
            INSERT INTO data_quality_issues (
                table_name, business_key, duplicate_count, first_occurrence_date,
                issue_severity, recommended_action
            )
            SELECT
                @TableName,
                order_id,
                COUNT(*),
                MIN(record_load_timestamp),
                'MEDIUM',
                'Review for ETL reload'
            FROM stg_orders_conformed
            WHERE source_load_date = @LoadDate
            GROUP BY order_id
            HAVING COUNT(*) > 1;
            
            PRINT 'Duplicate orders detected and logged';
        END;
        
    END TRY
    BEGIN CATCH
        PRINT 'ERROR in sp_detect_duplicates: ' + ERROR_MESSAGE();
        THROW;
    END CATCH
END;
GO

-- ============================================================
-- FINAL DATA QUALITY SUMMARY REPORT
-- ============================================================

CREATE PROCEDURE sp_generate_dq_summary_report
    @LoadDate DATE
AS
BEGIN
    SET NOCOUNT ON;
    
    PRINT '============================================================';
    PRINT 'DATA QUALITY SUMMARY REPORT';
    PRINT '============================================================';
    PRINT 'Report Date: ' + CAST(GETDATE() AS VARCHAR(20));
    PRINT 'Load Date: ' + CAST(@LoadDate AS VARCHAR(10));
    PRINT '============================================================';
    PRINT '';
    
    -- Summary statistics
    SELECT
        'Orders Processed' AS metric,
        CAST((SELECT COUNT(*) FROM stg_orders_conformed WHERE source_load_date = @LoadDate) AS VARCHAR(20)) AS value
    UNION ALL
    SELECT
        'Orders Valid',
        CAST((SELECT COUNT(*) FROM stg_orders_conformed WHERE source_load_date = @LoadDate AND dq_validation_status = 'VALID') AS VARCHAR(20))
    UNION ALL
    SELECT
        'Orders Invalid',
        CAST((SELECT COUNT(*) FROM stg_orders_conformed WHERE source_load_date = @LoadDate AND dq_validation_status = 'INVALID') AS VARCHAR(20))
    UNION ALL
    SELECT
        'Facts Loaded',
        CAST((SELECT COUNT(*) FROM fact_sales WHERE load_date = @LoadDate) AS VARCHAR(20))
    UNION ALL
    SELECT
        'Customers Processed',
        CAST((SELECT COUNT(*) FROM stg_customers_conformed WHERE source_load_date = @LoadDate) AS VARCHAR(20))
    UNION ALL
    SELECT
        'Data Quality Score',
        CAST((SELECT ROUND(AVG(overall_dq_score), 2) FROM dq_scores WHERE load_date = @LoadDate) AS VARCHAR(20)) + '%'
    UNION ALL
    SELECT
        'Reconciliation Status',
        (SELECT MAX(reconciliation_status) FROM etl_reconciliation WHERE load_date = @LoadDate);
    
    PRINT '';
    PRINT 'VALIDATION ISSUES:';
    SELECT * FROM data_quality_issues WHERE issue_date = @LoadDate;
    
    PRINT '';
    PRINT '============================================================';
    PRINT 'END OF REPORT';
    PRINT '============================================================';
    
END;
GO

-- Quick execution example
PRINT 'Data Quality Procedures Loaded Successfully';
PRINT 'To run quality checks, execute:';
PRINT '  EXEC sp_validate_staging_completeness @StagingTable = ''stg_raw_erp_orders'', @LoadDate = ''2024-01-15'';';
PRINT '  EXEC sp_reconcile_etl_totals @LoadDate = ''2024-01-15'';';
PRINT '  EXEC sp_calculate_dq_score @LoadDate = ''2024-01-15'';';
PRINT '  EXEC sp_generate_dq_summary_report @LoadDate = ''2024-01-15'';';
GO
