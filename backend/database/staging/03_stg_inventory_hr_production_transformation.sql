-- ============================================================
-- STAGING: Inventory & Production Transformations
-- ============================================================
-- Purpose: Transform inventory and production quality data
-- Sources: Warehouse/Operations Systems (real-time)
-- Volume: ~1M records/day
-- ============================================================

IF OBJECT_ID('stg_inventory_conformed', 'U') IS NOT NULL
    DROP TABLE stg_inventory_conformed;
GO

CREATE TABLE stg_inventory_conformed (
    inventory_sk                BIGINT IDENTITY(1,1) PRIMARY KEY CLUSTERED,
    inventory_business_key      VARCHAR(100) NOT NULL,
    warehouse_code              VARCHAR(10),
    product_sku                 VARCHAR(50),
    inventory_date              DATE NOT NULL,
    
    -- Quantity Metrics
    opening_quantity            DECIMAL(12,2),
    receipts_quantity           DECIMAL(12,2),
    issues_quantity             DECIMAL(12,2),
    adjustments_quantity        DECIMAL(12,2),
    closing_quantity            DECIMAL(12,2),
    
    -- Value Metrics
    inventory_value             DECIMAL(14,2),
    obsolete_value              DECIMAL(12,2),
    
    -- Quality & Age
    days_on_hand                INT,
    inventory_turnover          DECIMAL(10,2),
    slow_moving_flag            BIT,
    obsolete_flag               BIT,
    
    -- Source Info
    source_load_date            DATE,
    source_system_code          VARCHAR(20),
    
    INDEX idx_warehouse_product (warehouse_code, product_sku),
    INDEX idx_inventory_date (inventory_date)
);
GO

CREATE PROCEDURE sp_transform_warehouse_inventory
    @LoadDate DATE,
    @FullRefreshFlag BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        IF @FullRefreshFlag = 1
            DELETE FROM stg_inventory_conformed WHERE source_load_date = @LoadDate;
        
        INSERT INTO stg_inventory_conformed (
            inventory_business_key, warehouse_code, product_sku, inventory_date,
            opening_quantity, receipts_quantity, issues_quantity, adjustments_quantity, closing_quantity,
            inventory_value, obsolete_value,
            days_on_hand, inventory_turnover, slow_moving_flag, obsolete_flag,
            source_load_date, source_system_code
        )
        SELECT
            raw.INVENTORY_ID,
            raw.WAREHOUSE_CODE,
            raw.PRODUCT_CODE,
            CAST(raw.INVENTORY_DATE AS DATE),
            CAST(ISNULL(raw.OPENING_QTY, 0) AS DECIMAL(12,2)),
            CAST(ISNULL(raw.RECEIPT_QTY, 0) AS DECIMAL(12,2)),
            CAST(ISNULL(raw.ISSUE_QTY, 0) AS DECIMAL(12,2)),
            CAST(ISNULL(raw.ADJUSTMENT_QTY, 0) AS DECIMAL(12,2)),
            CAST(ISNULL(raw.CLOSING_QTY, 0) AS DECIMAL(12,2)),
            CAST(ISNULL(raw.INVENTORY_VALUE, 0) AS DECIMAL(14,2)),
            CAST(ISNULL(raw.OBSOLETE_VALUE, 0) AS DECIMAL(12,2)),
            CAST(ISNULL(raw.DAYS_ON_HAND, 0) AS INT),
            CAST(ISNULL(raw.TURNOVER_RATE, 0) AS DECIMAL(10,2)),
            CASE WHEN ISNULL(raw.DAYS_ON_HAND, 0) > 90 THEN 1 ELSE 0 END,
            CASE WHEN ISNULL(raw.OBSOLETE_VALUE, 0) > ISNULL(raw.INVENTORY_VALUE, 0) * 0.05 THEN 1 ELSE 0 END,
            @LoadDate,
            'WAREHOUSE_OPS'
        FROM stg_raw_warehouse_inventory raw
        WHERE CAST(raw.LOAD_DATE AS DATE) = @LoadDate;
        
        PRINT 'SUCCESS: Warehouse inventory transformed. Rows: ' + CAST(@@ROWCOUNT AS VARCHAR(10));
        
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMsg NVARCHAR(MAX) = ERROR_MESSAGE();
        PRINT 'ERROR in sp_transform_warehouse_inventory: ' + @ErrorMsg;
        THROW;
    END CATCH
END;
GO

-- ============================================================
-- STAGING: Customer Interactions (Call Center, Email, Meetings)
-- ============================================================

IF OBJECT_ID('stg_customer_interactions_conformed', 'U') IS NOT NULL
    DROP TABLE stg_customer_interactions_conformed;
GO

CREATE TABLE stg_customer_interactions_conformed (
    interaction_sk              BIGINT IDENTITY(1,1) PRIMARY KEY CLUSTERED,
    interaction_id              VARCHAR(100) NOT NULL UNIQUE,
    customer_id                 VARCHAR(100),
    employee_id                 VARCHAR(100),
    interaction_type            VARCHAR(50), -- Call, Email, Chat, Meeting
    interaction_date            DATE,
    interaction_timestamp       DATETIME2,
    
    -- Duration & Time
    interaction_duration_minutes INT,
    wait_time_minutes           INT,
    
    -- Interaction Details
    interaction_topic           VARCHAR(200),
    interaction_outcome         VARCHAR(100),
    is_successful               BIT,
    
    -- Engagement & Sentiment
    engagement_score            DECIMAL(3,1),
    sentiment_score             DECIMAL(3,1),
    satisfaction_rating         DECIMAL(3,1),
    
    -- Follow-up
    requires_followup           BIT,
    followup_date               DATE,
    
    -- Metadata
    source_load_date            DATE,
    source_system_code          VARCHAR(20),
    
    INDEX idx_customer_id (customer_id),
    INDEX idx_interaction_date (interaction_date),
    INDEX idx_interaction_type (interaction_type)
);
GO

CREATE PROCEDURE sp_transform_customer_interactions
    @LoadDate DATE
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        INSERT INTO stg_customer_interactions_conformed (
            interaction_id, customer_id, employee_id, interaction_type,
            interaction_date, interaction_timestamp, interaction_duration_minutes, wait_time_minutes,
            interaction_topic, interaction_outcome, is_successful,
            engagement_score, sentiment_score, satisfaction_rating,
            requires_followup, followup_date, source_load_date, source_system_code
        )
        SELECT
            raw.INTERACTION_ID,
            raw.CUSTOMER_ID,
            raw.AGENT_ID,
            raw.INTERACTION_TYPE,
            CAST(raw.INTERACTION_DATE AS DATE),
            raw.INTERACTION_DATETIME,
            CAST(ISNULL(raw.DURATION_MINUTES, 0) AS INT),
            CAST(ISNULL(raw.WAIT_TIME_MINUTES, 0) AS INT),
            raw.TOPIC,
            raw.OUTCOME,
            CASE WHEN raw.OUTCOME = 'Resolved' THEN 1 ELSE 0 END,
            CAST(ISNULL(raw.ENGAGEMENT_SCORE, 0) AS DECIMAL(3,1)),
            CAST(ISNULL(raw.SENTIMENT_SCORE, 0) AS DECIMAL(3,1)),
            CAST(ISNULL(raw.CSAT_RATING, 0) AS DECIMAL(3,1)),
            CASE WHEN raw.FOLLOWUP_REQUIRED = 1 THEN 1 ELSE 0 END,
            CAST(raw.FOLLOWUP_DATE AS DATE),
            @LoadDate,
            'CONTACT_CENTER'
        FROM stg_raw_customer_interactions raw
        WHERE CAST(raw.LOAD_DATE AS DATE) = @LoadDate;
        
        PRINT 'SUCCESS: Customer interactions transformed. Rows: ' + CAST(@@ROWCOUNT AS VARCHAR(10));
        
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMsg NVARCHAR(MAX) = ERROR_MESSAGE();
        PRINT 'ERROR in sp_transform_customer_interactions: ' + @ErrorMsg;
        THROW;
    END CATCH
END;
GO

-- ============================================================
-- STAGING: HR/Employee Metrics
-- ============================================================

IF OBJECT_ID('stg_employee_metrics_conformed', 'U') IS NOT NULL
    DROP TABLE stg_employee_metrics_conformed;
GO

CREATE TABLE stg_employee_metrics_conformed (
    employee_metric_sk          BIGINT IDENTITY(1,1) PRIMARY KEY CLUSTERED,
    employee_id                 VARCHAR(100),
    metric_date                 DATE,
    
    -- Attendance & Engagement
    is_present                  BIT,
    actual_hours                DECIMAL(5,2),
    tasks_completed             INT,
    productivity_score          DECIMAL(5,2),
    
    -- Performance
    sales_target                DECIMAL(12,2),
    sales_achieved              DECIMAL(12,2),
    achievement_percent         DECIMAL(5,2),
    
    -- Training
    training_hours              DECIMAL(5,2),
    certifications_earned       INT,
    
    -- Metadata
    source_load_date            DATE,
    source_system_code          VARCHAR(20),
    
    INDEX idx_employee_id (employee_id),
    INDEX idx_metric_date (metric_date)
);
GO

-- ============================================================
-- STAGING: Finance/Revenue Recognition
-- ============================================================

IF OBJECT_ID('stg_revenue_recognition_conformed', 'U') IS NOT NULL
    DROP TABLE stg_revenue_recognition_conformed;
GO

CREATE TABLE stg_revenue_recognition_conformed (
    revenue_recognition_sk      BIGINT IDENTITY(1,1) PRIMARY KEY CLUSTERED,
    contract_id                 VARCHAR(100),
    customer_id                 VARCHAR(100),
    
    -- Contract Terms
    contract_amount             DECIMAL(14,2),
    contract_start_date         DATE,
    contract_end_date           DATE,
    
    -- Revenue Recognition
    revenue_period_start        DATE,
    revenue_period_end          DATE,
    recognized_revenue          DECIMAL(14,2),
    deferred_revenue            DECIMAL(14,2),
    
    -- Source Info
    source_load_date            DATE,
    source_system_code          VARCHAR(20),
    
    INDEX idx_contract_id (contract_id),
    INDEX idx_customer_id (customer_id),
    INDEX idx_revenue_period (revenue_period_start, revenue_period_end)
);
GO

CREATE PROCEDURE sp_transform_revenue_recognition
    @LoadDate DATE
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        INSERT INTO stg_revenue_recognition_conformed (
            contract_id, customer_id, contract_amount,
            contract_start_date, contract_end_date,
            revenue_period_start, revenue_period_end,
            recognized_revenue, deferred_revenue,
            source_load_date, source_system_code
        )
        SELECT
            raw.CONTRACT_ID,
            raw.CUSTOMER_ID,
            CAST(raw.CONTRACT_AMOUNT AS DECIMAL(14,2)),
            CAST(raw.CONTRACT_START_DATE AS DATE),
            CAST(raw.CONTRACT_END_DATE AS DATE),
            CAST(raw.PERIOD_START AS DATE),
            CAST(raw.PERIOD_END AS DATE),
            CAST(raw.RECOGNIZED_AMOUNT AS DECIMAL(14,2)),
            CAST(raw.DEFERRED_AMOUNT AS DECIMAL(14,2)),
            @LoadDate,
            'FINANCE'
        FROM stg_raw_revenue_contracts raw
        WHERE CAST(raw.LOAD_DATE AS DATE) = @LoadDate;
        
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMsg NVARCHAR(MAX) = ERROR_MESSAGE();
        PRINT 'ERROR in sp_transform_revenue_recognition: ' + @ErrorMsg;
        THROW;
    END CATCH
END;
GO

-- ============================================================
-- STAGING: Production Quality Metrics
-- ============================================================

IF OBJECT_ID('stg_production_quality_conformed', 'U') IS NOT NULL
    DROP TABLE stg_production_quality_conformed;
GO

CREATE TABLE stg_production_quality_conformed (
    production_metric_sk        BIGINT IDENTITY(1,1) PRIMARY KEY CLUSTERED,
    production_batch_id         VARCHAR(100),
    product_sku                 VARCHAR(50),
    production_date             DATE,
    
    -- Production Volume
    units_produced              INT,
    units_passed_qc             INT,
    units_failed_qc             INT,
    defect_rate_percent         DECIMAL(5,2),
    
    -- Quality Metrics
    first_pass_yield_percent    DECIMAL(5,2),
    rework_percent              DECIMAL(5,2),
    
    -- Efficiency
    production_hours            DECIMAL(8,2),
    units_per_hour              DECIMAL(10,2),
    
    -- Source Info
    source_load_date            DATE,
    source_system_code          VARCHAR(20),
    
    INDEX idx_production_date (production_date),
    INDEX idx_product_sku (product_sku)
);
GO

CREATE PROCEDURE sp_transform_production_quality
    @LoadDate DATE
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        INSERT INTO stg_production_quality_conformed (
            production_batch_id, product_sku, production_date,
            units_produced, units_passed_qc, units_failed_qc, defect_rate_percent,
            first_pass_yield_percent, rework_percent,
            production_hours, units_per_hour,
            source_load_date, source_system_code
        )
        SELECT
            raw.BATCH_ID,
            raw.PRODUCT_CODE,
            CAST(raw.PRODUCTION_DATE AS DATE),
            CAST(raw.UNITS_PRODUCED AS INT),
            CAST(raw.UNITS_PASSED AS INT),
            CAST(raw.UNITS_FAILED AS INT),
            CASE 
                WHEN CAST(raw.UNITS_PRODUCED AS INT) > 0
                THEN CAST(raw.UNITS_FAILED AS INT) * 100.0 / CAST(raw.UNITS_PRODUCED AS INT)
                ELSE 0 
            END,
            CAST(ISNULL(raw.FIRST_PASS_YIELD_PCT, 0) AS DECIMAL(5,2)),
            CAST(ISNULL(raw.REWORK_PCT, 0) AS DECIMAL(5,2)),
            CAST(raw.PRODUCTION_HOURS AS DECIMAL(8,2)),
            CASE 
                WHEN CAST(raw.PRODUCTION_HOURS AS DECIMAL(8,2)) > 0
                THEN CAST(raw.UNITS_PRODUCED AS INT) / CAST(raw.PRODUCTION_HOURS AS DECIMAL(8,2))
                ELSE 0 
            END,
            @LoadDate,
            'PRODUCTION_OPS'
        FROM stg_raw_production_quality raw
        WHERE CAST(raw.LOAD_DATE AS DATE) = @LoadDate;
        
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMsg NVARCHAR(MAX) = ERROR_MESSAGE();
        PRINT 'ERROR in sp_transform_production_quality: ' + @ErrorMsg;
        THROW;
    END CATCH
END;
GO

-- ============================================================
-- MASTER STAGING TRANSFORMATION ORCHESTRATION
-- ============================================================

CREATE PROCEDURE sp_transform_all_staging
    @LoadDate DATE
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        PRINT 'Starting comprehensive staging transformations for ' + CAST(@LoadDate AS VARCHAR(10));
        
        EXEC sp_transform_erp_orders @LoadDate, GETDATE(), 0;
        EXEC sp_transform_salesforce_customers @LoadDate, GETDATE(), 0;
        EXEC sp_transform_salesforce_opportunities @LoadDate, GETDATE(), 0;
        EXEC sp_transform_warehouse_inventory @LoadDate, 0;
        EXEC sp_transform_customer_interactions @LoadDate;
        EXEC sp_transform_revenue_recognition @LoadDate;
        EXEC sp_transform_production_quality @LoadDate;
        
        PRINT 'All staging transformations completed successfully';
        
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMsg NVARCHAR(MAX) = ERROR_MESSAGE();
        PRINT 'ERROR in sp_transform_all_staging: ' + @ErrorMsg;
        THROW;
    END CATCH
END;
GO
