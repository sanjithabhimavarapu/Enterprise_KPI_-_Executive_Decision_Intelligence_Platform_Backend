-- ============================================================
-- STAGING: Salesforce CRM Customer & Opportunities
-- ============================================================
-- Purpose: Transform raw Salesforce data into conformed staging
-- Source: Salesforce CRM (real-time via APIs, 15-min batches)
-- Volume: ~10GB/day (customers + opportunities + activities)
-- ============================================================

IF OBJECT_ID('stg_customers_conformed', 'U') IS NOT NULL
    DROP TABLE stg_customers_conformed;
GO

CREATE TABLE stg_customers_conformed (
    customer_sk                 BIGINT IDENTITY(1,1) PRIMARY KEY CLUSTERED,
    customer_id                 VARCHAR(100) NOT NULL UNIQUE,
    customer_source_id          VARCHAR(100),
    customer_name               VARCHAR(200) NOT NULL,
    customer_type               VARCHAR(50), -- Enterprise, Mid-market, SMB, etc.
    
    -- Contact Information
    primary_contact_name        VARCHAR(200),
    primary_contact_email       VARCHAR(100),
    primary_contact_phone       VARCHAR(20),
    billing_address             VARCHAR(500),
    billing_city                VARCHAR(100),
    billing_state               VARCHAR(50),
    billing_country             VARCHAR(100),
    billing_postal_code         VARCHAR(20),
    
    -- Customer Profile
    industry                    VARCHAR(100),
    annual_revenue              DECIMAL(14,2),
    employee_count              INT,
    annual_contract_value       DECIMAL(14,2),
    lifetime_value              DECIMAL(14,2),
    customer_segment            VARCHAR(50), -- A, B, C, D
    customer_sub_segment        VARCHAR(100),
    
    -- Engagement Metrics
    accounts_created_date       DATE,
    first_purchase_date         DATE,
    last_purchase_date          DATE,
    total_purchases             INT,
    days_since_last_purchase    INT,
    
    -- Support & Satisfaction
    support_tier                VARCHAR(50),
    satisfaction_score          DECIMAL(3,1),
    nps_score                   INT,
    open_support_tickets        INT,
    
    -- Subscription Status
    is_active_customer          BIT,
    subscription_status         VARCHAR(50), -- Active, Trial, Churned, Paused
    subscription_end_date       DATE,
    
    -- Metadata
    record_load_timestamp       DATETIME2 DEFAULT GETDATE(),
    source_load_date            DATE,
    source_system_code          VARCHAR(20),
    
    INDEX idx_customer_id (customer_id),
    INDEX idx_customer_segment (customer_segment),
    INDEX idx_subscription_status (subscription_status)
);
GO

IF OBJECT_ID('stg_opportunities_conformed', 'U') IS NOT NULL
    DROP TABLE stg_opportunities_conformed;
GO

CREATE TABLE stg_opportunities_conformed (
    opportunity_sk              BIGINT IDENTITY(1,1) PRIMARY KEY CLUSTERED,
    opportunity_id              VARCHAR(100) NOT NULL UNIQUE,
    opportunity_source_id       VARCHAR(100),
    customer_id                 VARCHAR(100) NOT NULL,
    
    -- Opportunity Details
    opportunity_name            VARCHAR(500),
    opportunity_stage           VARCHAR(100), -- Prospecting, Negotiation, Won, Lost
    close_date                  DATE,
    close_month                 VARCHAR(7), -- YYYY-MM
    
    -- Financial Metrics
    opportunity_amount          DECIMAL(14,2),
    weighted_forecast           DECIMAL(14,2),
    probability_percent         DECIMAL(5,2),
    expected_value              DECIMAL(14,2), -- Amount * Probability
    
    -- Deal Characteristics
    deal_type                   VARCHAR(50),
    competition_level           VARCHAR(50),
    
    -- Dates & Timing
    opportunity_created_date    DATE,
    opportunity_created_timestamp DATETIME2,
    last_activity_date          DATE,
    sales_cycle_days            INT,
    
    -- Sales Information
    account_owner_id            VARCHAR(100),
    account_owner_name          VARCHAR(200),
    sales_region                VARCHAR(100),
    
    -- Outcomes
    is_won                      BIT,
    is_lost                     BIT,
    loss_reason                 VARCHAR(500),
    
    -- Metadata
    record_load_timestamp       DATETIME2 DEFAULT GETDATE(),
    source_load_date            DATE,
    source_system_code          VARCHAR(20),
    
    INDEX idx_opportunity_id (opportunity_id),
    INDEX idx_customer_id (customer_id),
    INDEX idx_opportunity_stage (opportunity_stage),
    INDEX idx_close_date (close_date)
);
GO

-- ============================================================
-- TRANSFORMATION LOGIC FOR SALESFORCE CUSTOMERS
-- ============================================================

CREATE PROCEDURE sp_transform_salesforce_customers
    @LoadStartDateTime DATETIME2,
    @LoadEndDateTime DATETIME2,
    @FullRefreshFlag BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        IF @FullRefreshFlag = 1
            DELETE FROM stg_customers_conformed
            WHERE source_system_code = 'SALESFORCE';
        
        -- MERGE customers with lifecycle calculations
        INSERT INTO stg_customers_conformed (
            customer_id, customer_source_id, customer_name, customer_type,
            primary_contact_name, primary_contact_email, primary_contact_phone,
            billing_address, billing_city, billing_state, billing_country, billing_postal_code,
            industry, annual_revenue, employee_count, annual_contract_value,
            accounts_created_date, first_purchase_date, last_purchase_date,
            total_purchases, days_since_last_purchase,
            support_tier, satisfaction_score, nps_score,
            is_active_customer, subscription_status, subscription_end_date,
            source_load_date, source_system_code
        )
        SELECT
            raw.ACCOUNT_ID AS customer_id,
            raw.SFDC_ID AS customer_source_id,
            raw.ACCOUNT_NAME AS customer_name,
            raw.ACCOUNT_TYPE AS customer_type,
            raw.PRIMARY_CONTACT_NAME,
            raw.PRIMARY_CONTACT_EMAIL,
            raw.PRIMARY_CONTACT_PHONE,
            raw.BILLING_STREET + ' ' + ISNULL(raw.BILLING_SUITE, '') AS billing_address,
            raw.BILLING_CITY,
            raw.BILLING_STATE,
            raw.BILLING_COUNTRY,
            raw.BILLING_POSTAL_CODE,
            raw.INDUSTRY,
            CAST(ISNULL(raw.ANNUAL_REVENUE, 0) AS DECIMAL(14,2)) AS annual_revenue,
            CAST(ISNULL(raw.NUMBER_OF_EMPLOYEES, 0) AS INT) AS employee_count,
            CAST(ISNULL(raw.ACV, 0) AS DECIMAL(14,2)) AS annual_contract_value,
            CAST(raw.CREATED_DATE AS DATE) AS accounts_created_date,
            CAST(raw.FIRST_ORDER_DATE AS DATE) AS first_purchase_date,
            CAST(raw.LAST_ORDER_DATE AS DATE) AS last_purchase_date,
            CAST(ISNULL(raw.TOTAL_ORDERS, 0) AS INT) AS total_purchases,
            DATEDIFF(DAY, CAST(raw.LAST_ORDER_DATE AS DATE), CAST(GETDATE() AS DATE)) AS days_since_last_purchase,
            raw.SUPPORT_TIER,
            CAST(ISNULL(raw.CSAT_SCORE, 0) AS DECIMAL(3,1)) AS satisfaction_score,
            CAST(ISNULL(raw.NPS_SCORE, 0) AS INT) AS nps_score,
            -- Active if subscription status not churned
            CASE WHEN raw.SUBSCRIPTION_STATUS NOT IN ('Churned', 'Cancelled')
                 THEN 1 ELSE 0 END AS is_active_customer,
            raw.SUBSCRIPTION_STATUS,
            CAST(raw.SUBSCRIPTION_END_DATE AS DATE) AS subscription_end_date,
            CAST(raw.LOAD_DATE AS DATE) AS source_load_date,
            'SALESFORCE' AS source_system_code
        
        FROM stg_raw_salesforce_customers raw
        WHERE (
            (@FullRefreshFlag = 0 AND raw.LAST_MODIFIED >= @LoadStartDateTime)
            OR @FullRefreshFlag = 1
        )
        AND raw.ACCOUNT_ID IS NOT NULL;
        
        PRINT 'SUCCESS: Salesforce Customers transformation completed. Rows: ' + 
              CAST(@@ROWCOUNT AS NVARCHAR(20));
        
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMsg NVARCHAR(MAX) = ERROR_MESSAGE();
        PRINT 'ERROR in sp_transform_salesforce_customers: ' + @ErrorMsg;
        THROW;
    END CATCH
END;
GO

-- ============================================================
-- TRANSFORMATION LOGIC FOR SALESFORCE OPPORTUNITIES
-- ============================================================

CREATE PROCEDURE sp_transform_salesforce_opportunities
    @LoadStartDateTime DATETIME2,
    @LoadEndDateTime DATETIME2,
    @FullRefreshFlag BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        IF @FullRefreshFlag = 1
            DELETE FROM stg_opportunities_conformed
            WHERE source_system_code = 'SALESFORCE';
        
        INSERT INTO stg_opportunities_conformed (
            opportunity_id, opportunity_source_id, customer_id,
            opportunity_name, opportunity_stage, close_date, close_month,
            opportunity_amount, weighted_forecast, probability_percent, expected_value,
            deal_type, competition_level,
            opportunity_created_date, opportunity_created_timestamp, last_activity_date,
            sales_cycle_days,
            account_owner_id, account_owner_name, sales_region,
            is_won, is_lost, loss_reason,
            source_load_date, source_system_code
        )
        SELECT
            raw.OPPORTUNITY_ID,
            raw.SFDC_OPP_ID,
            raw.ACCOUNT_ID,
            raw.OPPORTUNITY_NAME,
            raw.STAGE_NAME,
            CAST(raw.CLOSE_DATE AS DATE),
            FORMAT(CAST(raw.CLOSE_DATE AS DATE), 'yyyy-MM') AS close_month,
            CAST(raw.AMOUNT AS DECIMAL(14,2)),
            CAST(raw.WEIGHTED_AMOUNT AS DECIMAL(14,2)),
            CAST(raw.PROBABILITY AS DECIMAL(5,2)),
            -- Expected Value = Amount * (Probability / 100)
            ROUND(CAST(raw.AMOUNT AS DECIMAL(14,2)) * 
                  CAST(raw.PROBABILITY AS DECIMAL(5,2)) / 100, 2),
            raw.DEAL_TYPE,
            raw.COMPETITION_LEVEL,
            CAST(raw.CREATED_DATE AS DATE),
            raw.CREATED_DATETIME,
            CAST(raw.LAST_ACTIVITY_DATE AS DATE),
            -- Sales Cycle = Close Date - Created Date
            DATEDIFF(DAY, CAST(raw.CREATED_DATE AS DATE), CAST(raw.CLOSE_DATE AS DATE)),
            raw.OWNER_ID,
            raw.OWNER_NAME,
            raw.REGION,
            CASE WHEN raw.IS_WON = 1 THEN 1 ELSE 0 END,
            CASE WHEN raw.IS_LOST = 1 THEN 1 ELSE 0 END,
            raw.LOSS_REASON,
            CAST(raw.LOAD_DATE AS DATE),
            'SALESFORCE'
        
        FROM stg_raw_salesforce_opportunities raw
        WHERE (
            (@FullRefreshFlag = 0 AND raw.LAST_MODIFIED >= @LoadStartDateTime)
            OR @FullRefreshFlag = 1
        )
        AND raw.OPPORTUNITY_ID IS NOT NULL;
        
        PRINT 'SUCCESS: Salesforce Opportunities transformation completed. Rows: ' + 
              CAST(@@ROWCOUNT AS NVARCHAR(20));
        
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMsg NVARCHAR(MAX) = ERROR_MESSAGE();
        PRINT 'ERROR in sp_transform_salesforce_opportunities: ' + @ErrorMsg;
        THROW;
    END CATCH
END;
GO
