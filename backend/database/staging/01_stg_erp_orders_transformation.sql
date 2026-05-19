-- ============================================================
-- STAGING: ERP Orders Transformation (SAP/Oracle)
-- ============================================================
-- Purpose: Transform raw ERP order data from stg_raw_erp_orders
--          into conformed staging table with business logic
-- Source: SAP/Oracle ERP system (real-time & batch)
-- Volume: ~500K records/day
-- Frequency: Incremental load (CDC-based)
-- ============================================================

IF OBJECT_ID('stg_orders_conformed', 'U') IS NOT NULL
    DROP TABLE stg_orders_conformed;
GO

CREATE TABLE stg_orders_conformed (
    order_sk                    BIGINT IDENTITY(1,1) PRIMARY KEY CLUSTERED,
    order_id                    VARCHAR(50) NOT NULL UNIQUE,
    order_source_id             VARCHAR(50),
    order_date                  DATE NOT NULL,
    order_timestamp             DATETIME2 NOT NULL,
    customer_business_key       VARCHAR(100) NOT NULL,
    product_sku                 VARCHAR(50) NOT NULL,
    warehouse_code              VARCHAR(10),
    
    -- Order Details
    order_quantity              DECIMAL(12,2) NOT NULL,
    unit_price                  DECIMAL(12,4) NOT NULL,
    gross_amount                DECIMAL(14,2),
    discount_percent            DECIMAL(5,2),
    discount_amount             DECIMAL(12,2),
    net_amount                  DECIMAL(14,2),
    
    -- Cost & Margin Calculations
    product_cost                DECIMAL(12,4),
    freight_cost                DECIMAL(10,2),
    duty_cost                   DECIMAL(10,2),
    gross_profit                DECIMAL(14,2),
    gross_margin_percent        DECIMAL(5,2),
    
    -- Delivery Details
    requested_delivery_date     DATE,
    actual_delivery_date        DATE,
    delivery_days               INT,
    on_time_delivery_flag       BIT,
    
    -- Operational Flags
    order_status_code           VARCHAR(20),
    is_cancelled                BIT DEFAULT 0,
    is_returned                 BIT DEFAULT 0,
    return_reason_code          VARCHAR(50),
    
    -- Data Quality
    record_load_timestamp       DATETIME2 DEFAULT GETDATE(),
    source_load_date            DATE,
    source_system_code          VARCHAR(20),
    dq_validation_status        VARCHAR(20),
    dq_validation_message       NVARCHAR(MAX),
    
    INDEX idx_order_id (order_id),
    INDEX idx_customer_key (customer_business_key),
    INDEX idx_order_date (order_date),
    INDEX idx_product_sku (product_sku)
);
GO

-- ============================================================
-- TRANSFORMATION LOGIC FOR ERP ORDERS
-- ============================================================

CREATE PROCEDURE sp_transform_erp_orders
    @LoadStartDateTime DATETIME2,
    @LoadEndDateTime DATETIME2,
    @FullRefreshFlag BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        -- Delete target if full refresh
        IF @FullRefreshFlag = 1
            DELETE FROM stg_orders_conformed
            WHERE source_system_code = 'ERP';
        
        -- STEP 1: Load new/changed orders with business logic transformations
        INSERT INTO stg_orders_conformed (
            order_id, order_source_id, order_date, order_timestamp,
            customer_business_key, product_sku, warehouse_code,
            order_quantity, unit_price, gross_amount,
            discount_percent, discount_amount, net_amount,
            product_cost, freight_cost, duty_cost,
            gross_profit, gross_margin_percent,
            requested_delivery_date, actual_delivery_date,
            delivery_days, on_time_delivery_flag,
            order_status_code, is_cancelled, is_returned,
            return_reason_code, source_load_date, source_system_code,
            dq_validation_status, dq_validation_message
        )
        SELECT
            -- Primary Keys & IDs
            raw.ORDER_NUMBER AS order_id,
            raw.ORDER_ID AS order_source_id,
            CAST(raw.ORDER_DATE AS DATE) AS order_date,
            raw.ORDER_DATETIME AS order_timestamp,
            -- Customer Business Key (join to find it)
            ISNULL(raw.CUSTOMER_CODE, 'UNKNOWN') AS customer_business_key,
            raw.PRODUCT_CODE AS product_sku,
            raw.WAREHOUSE_CODE,
            
            -- Order Quantities & Pricing
            CAST(raw.ORDER_QTY AS DECIMAL(12,2)) AS order_quantity,
            CAST(raw.UNIT_PRICE AS DECIMAL(12,4)) AS unit_price,
            CAST(raw.GROSS_AMOUNT AS DECIMAL(14,2)) AS gross_amount,
            
            -- Discount Calculations
            CAST(ISNULL(raw.DISCOUNT_PERCENT, 0) AS DECIMAL(5,2)) AS discount_percent,
            CASE 
                WHEN ISNULL(raw.DISCOUNT_PERCENT, 0) > 0 
                THEN ROUND(CAST(raw.GROSS_AMOUNT AS DECIMAL(14,2)) * 
                           CAST(raw.DISCOUNT_PERCENT AS DECIMAL(5,2)) / 100, 2)
                ELSE 0 
            END AS discount_amount,
            -- Net Amount (Gross - Discount)
            ROUND(CAST(raw.GROSS_AMOUNT AS DECIMAL(14,2)) - 
                  CASE WHEN ISNULL(raw.DISCOUNT_PERCENT, 0) > 0 
                       THEN ROUND(CAST(raw.GROSS_AMOUNT AS DECIMAL(14,2)) * 
                                  CAST(raw.DISCOUNT_PERCENT AS DECIMAL(5,2)) / 100, 2)
                       ELSE 0 END, 2) AS net_amount,
            
            -- Cost & Margin
            CAST(ISNULL(raw.PRODUCT_COST, 0) AS DECIMAL(12,4)) AS product_cost,
            CAST(ISNULL(raw.FREIGHT_COST, 0) AS DECIMAL(10,2)) AS freight_cost,
            CAST(ISNULL(raw.DUTY_COST, 0) AS DECIMAL(10,2)) AS duty_cost,
            -- Gross Profit = Net Amount - (Product Cost + Freight + Duty)
            ROUND(
                CAST(raw.GROSS_AMOUNT AS DECIMAL(14,2)) - 
                CASE WHEN ISNULL(raw.DISCOUNT_PERCENT, 0) > 0 
                     THEN ROUND(CAST(raw.GROSS_AMOUNT AS DECIMAL(14,2)) * 
                                CAST(raw.DISCOUNT_PERCENT AS DECIMAL(5,2)) / 100, 2)
                     ELSE 0 END -
                (CAST(ISNULL(raw.PRODUCT_COST, 0) AS DECIMAL(12,4)) +
                 CAST(ISNULL(raw.FREIGHT_COST, 0) AS DECIMAL(10,2)) +
                 CAST(ISNULL(raw.DUTY_COST, 0) AS DECIMAL(10,2)))
            , 2) AS gross_profit,
            -- Gross Margin % = (Gross Profit / Net Amount) * 100
            CASE 
                WHEN CAST(raw.GROSS_AMOUNT AS DECIMAL(14,2)) > 0
                THEN ROUND(
                    (ROUND(
                        CAST(raw.GROSS_AMOUNT AS DECIMAL(14,2)) - 
                        CASE WHEN ISNULL(raw.DISCOUNT_PERCENT, 0) > 0 
                             THEN ROUND(CAST(raw.GROSS_AMOUNT AS DECIMAL(14,2)) * 
                                        CAST(raw.DISCOUNT_PERCENT AS DECIMAL(5,2)) / 100, 2)
                             ELSE 0 END -
                        (CAST(ISNULL(raw.PRODUCT_COST, 0) AS DECIMAL(12,4)) +
                         CAST(ISNULL(raw.FREIGHT_COST, 0) AS DECIMAL(10,2)) +
                         CAST(ISNULL(raw.DUTY_COST, 0) AS DECIMAL(10,2)))
                    , 2) / 
                    (CAST(raw.GROSS_AMOUNT AS DECIMAL(14,2)) - 
                     CASE WHEN ISNULL(raw.DISCOUNT_PERCENT, 0) > 0 
                          THEN ROUND(CAST(raw.GROSS_AMOUNT AS DECIMAL(14,2)) * 
                                     CAST(raw.DISCOUNT_PERCENT AS DECIMAL(5,2)) / 100, 2)
                          ELSE 0 END)) * 100
                , 2)
                ELSE 0 
            END AS gross_margin_percent,
            
            -- Delivery Dates & Metrics
            CAST(raw.REQUESTED_DELIVERY_DATE AS DATE) AS requested_delivery_date,
            CAST(raw.ACTUAL_DELIVERY_DATE AS DATE) AS actual_delivery_date,
            -- Delivery Days = ACTUAL - REQUESTED
            DATEDIFF(DAY, CAST(raw.REQUESTED_DELIVERY_DATE AS DATE), 
                          CAST(raw.ACTUAL_DELIVERY_DATE AS DATE)) AS delivery_days,
            -- On-Time Flag = 1 if Actual <= Requested
            CASE WHEN CAST(raw.ACTUAL_DELIVERY_DATE AS DATE) <= CAST(raw.REQUESTED_DELIVERY_DATE AS DATE)
                 THEN 1 ELSE 0 END AS on_time_delivery_flag,
            
            -- Status Flags
            raw.ORDER_STATUS AS order_status_code,
            CASE WHEN raw.ORDER_STATUS = 'CANCELLED' THEN 1 ELSE 0 END AS is_cancelled,
            CASE WHEN raw.ORDER_STATUS = 'RETURNED' THEN 1 ELSE 0 END AS is_returned,
            raw.RETURN_REASON AS return_reason_code,
            
            -- Metadata
            CAST(raw.LOAD_DATE AS DATE) AS source_load_date,
            'ERP' AS source_system_code,
            'VALID' AS dq_validation_status,
            NULL AS dq_validation_message
        
        FROM stg_raw_erp_orders raw
        WHERE (
            -- Incremental: Only new/changed records
            (@FullRefreshFlag = 0 AND raw.CHANGE_TIMESTAMP BETWEEN @LoadStartDateTime AND @LoadEndDateTime)
            -- Full Refresh: All records
            OR @FullRefreshFlag = 1
        )
        AND raw.ORDER_NUMBER IS NOT NULL
        AND CAST(raw.ORDER_DATE AS DATE) >= DATEADD(YEAR, -3, CAST(GETDATE() AS DATE));
        
        PRINT 'SUCCESS: ERP Orders transformation completed. Rows inserted: ' + 
              CAST(@@ROWCOUNT AS NVARCHAR(20));
        
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMsg NVARCHAR(MAX) = ERROR_MESSAGE();
        PRINT 'ERROR in sp_transform_erp_orders: ' + @ErrorMsg;
        THROW;
    END CATCH
END;
GO

-- ============================================================
-- DATA QUALITY VALIDATION FOR ORDERS
-- ============================================================

CREATE PROCEDURE sp_validate_orders_quality
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Mark invalid records
    UPDATE stg_orders_conformed
    SET dq_validation_status = 'INVALID',
        dq_validation_message = 
            CASE 
                WHEN order_id IS NULL THEN 'Null order_id'
                WHEN customer_business_key = 'UNKNOWN' THEN 'Unknown customer'
                WHEN order_quantity <= 0 THEN 'Invalid quantity'
                WHEN net_amount <= 0 THEN 'Invalid net amount'
                WHEN order_date > CAST(GETDATE() AS DATE) THEN 'Future order date'
                WHEN actual_delivery_date IS NOT NULL 
                     AND actual_delivery_date < requested_delivery_date 
                     AND DATEDIFF(DAY, requested_delivery_date, actual_delivery_date) < -30 
                THEN 'Suspicious early delivery (>30 days early)'
                ELSE dq_validation_message
            END
    WHERE dq_validation_status != 'INVALID'
    AND (
        order_id IS NULL
        OR customer_business_key = 'UNKNOWN'
        OR order_quantity <= 0
        OR net_amount <= 0
        OR order_date > CAST(GETDATE() AS DATE)
        OR (actual_delivery_date IS NOT NULL 
            AND actual_delivery_date < requested_delivery_date 
            AND DATEDIFF(DAY, requested_delivery_date, actual_delivery_date) < -30)
    );
    
    -- Log data quality metrics
    INSERT INTO dq_validation_logs (
        table_name, validation_run_time, total_records, invalid_records, 
        valid_records, quality_score
    )
    SELECT
        'stg_orders_conformed',
        GETDATE(),
        COUNT(*),
        SUM(CASE WHEN dq_validation_status = 'INVALID' THEN 1 ELSE 0 END),
        SUM(CASE WHEN dq_validation_status = 'VALID' THEN 1 ELSE 0 END),
        ROUND(
            CAST(SUM(CASE WHEN dq_validation_status = 'VALID' THEN 1 ELSE 0 END) AS DECIMAL(10,2)) /
            CAST(COUNT(*) AS DECIMAL(10,2)) * 100, 2
        )
    FROM stg_orders_conformed;
    
END;
GO
