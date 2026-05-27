-- ============================================================================
-- WORKFLOW TRACKING, CUSTOMER METRICS, RETENTION & CHURN LOGIC
-- Enterprise KPI - Executive Decision Intelligence Platform
-- Purpose: Track workflows, customer lifecycle metrics, retention and churn
-- Updated: May 27, 2026
-- ============================================================================

-- ============================================================================
-- SECTION 1: WORKFLOW TRACKING TABLES
-- ============================================================================

-- ============================================================================
-- 1.1: Workflow Definition Table
-- Purpose: Define workflow states and transitions
-- ============================================================================
CREATE TABLE IF NOT EXISTS workflow_definition (
    workflow_key            BIGINT PRIMARY KEY AUTO_INCREMENT,
    workflow_name           VARCHAR(200) NOT NULL,
    workflow_type           VARCHAR(100), -- Order Processing, Support Ticket, Onboarding, Implementation
    workflow_description    VARCHAR(500),
    is_active               BOOLEAN DEFAULT TRUE,
    created_date            TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_date            TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_workflow_name (workflow_name)
);

-- ============================================================================
-- 1.2: Workflow State Definition Table
-- Purpose: Define possible states in workflows
-- ============================================================================
CREATE TABLE IF NOT EXISTS workflow_state_definition (
    state_key               BIGINT PRIMARY KEY AUTO_INCREMENT,
    workflow_key            BIGINT NOT NULL,
    state_name              VARCHAR(100) NOT NULL,
    state_sequence          INT NOT NULL,
    state_category          VARCHAR(50), -- Initial, InProgress, Pending, Completed, Failed
    is_terminal_state       BOOLEAN DEFAULT FALSE,
    description             VARCHAR(500),
    created_date            TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (workflow_key) REFERENCES workflow_definition(workflow_key),
    INDEX idx_workflow (workflow_key),
    UNIQUE KEY uk_state_sequence (workflow_key, state_sequence)
);

-- ============================================================================
-- 1.3: Workflow Instance Tracking Table
-- Purpose: Track individual workflow instances and state transitions
-- Grain: One row per workflow instance state change
-- ============================================================================
CREATE TABLE IF NOT EXISTS workflow_instance_tracking (
    workflow_instance_key   BIGINT PRIMARY KEY AUTO_INCREMENT,
    workflow_key            BIGINT NOT NULL,
    entity_type             VARCHAR(100), -- Order, Ticket, Customer, Implementation
    entity_key              BIGINT, -- Reference to order_key, ticket_key, etc.
    customer_key            BIGINT,
    current_state_key       BIGINT,
    previous_state_key      BIGINT,
    -- Timeline
    workflow_started_time   DATETIME NOT NULL,
    current_state_entered_time DATETIME NOT NULL,
    workflow_completed_time DATETIME,
    total_duration_minutes  DECIMAL(10, 2),
    current_state_duration_minutes DECIMAL(10, 2),
    -- Status
    workflow_status         VARCHAR(20), -- Active, Completed, Failed, On Hold
    is_completed            BOOLEAN DEFAULT FALSE,
    is_failed               BOOLEAN DEFAULT FALSE,
    failure_reason          VARCHAR(500),
    -- Performance
    state_transition_count  INT DEFAULT 1,
    escalation_count        INT DEFAULT 0,
    is_escalated            BOOLEAN DEFAULT FALSE,
    assigned_to_employee_key BIGINT,
    dw_insert_ts            TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    dw_update_ts            TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (workflow_key) REFERENCES workflow_definition(workflow_key),
    INDEX idx_entity (entity_type, entity_key),
    INDEX idx_customer (customer_key),
    INDEX idx_status (workflow_status),
    INDEX idx_current_state (current_state_key),
    INDEX idx_workflow_started (workflow_started_time)
);

-- ============================================================================
-- 1.4: Workflow State History Table
-- Purpose: Complete audit trail of state transitions
-- Grain: One row per state change
-- ============================================================================
CREATE TABLE IF NOT EXISTS workflow_state_history (
    state_history_key       BIGINT PRIMARY KEY AUTO_INCREMENT,
    workflow_instance_key   BIGINT NOT NULL,
    from_state_key          BIGINT,
    to_state_key            BIGINT NOT NULL,
    state_change_time       DATETIME NOT NULL,
    transition_duration_minutes DECIMAL(10, 2),
    transition_reason       VARCHAR(500),
    transition_notes        VARCHAR(1000),
    changed_by_employee_key BIGINT,
    is_manual_transition    BOOLEAN DEFAULT FALSE,
    dw_insert_ts            TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (workflow_instance_key) REFERENCES workflow_instance_tracking(workflow_instance_key),
    INDEX idx_workflow_instance (workflow_instance_key),
    INDEX idx_state_change_time (state_change_time),
    INDEX idx_to_state (to_state_key)
);

-- ============================================================================
-- SECTION 2: CUSTOMER METRICS TABLES
-- ============================================================================

-- ============================================================================
-- 2.1: Customer Lifecycle Stage Table
-- Purpose: Track customer journey through different lifecycle stages
-- ============================================================================
CREATE TABLE IF NOT EXISTS customer_lifecycle_stage (
    lifecycle_key           BIGINT PRIMARY KEY AUTO_INCREMENT,
    customer_key            BIGINT NOT NULL,
    lifecycle_stage         VARCHAR(100), -- Prospect, New Customer, Growth, Mature, At Risk, Churned
    stage_entered_date      DATE NOT NULL,
    stage_exit_date         DATE,
    stage_duration_days     INT,
    -- Engagement Metrics
    engagement_score        DECIMAL(5, 2),
    interaction_frequency   INT, -- Interactions per month
    response_time_hours     DECIMAL(10, 2),
    product_adoption_score  DECIMAL(5, 2),
    feature_usage_count     INT,
    -- Health
    health_score            DECIMAL(5, 2),
    satisfaction_score      DECIMAL(5, 2),
    nps_score               DECIMAL(5, 2),
    -- Financial
    monthly_spending        DECIMAL(15, 2),
    spending_trend_pct      DECIMAL(8, 4),
    expansion_potential_pct DECIMAL(8, 4),
    dw_insert_ts            TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    dw_update_ts            TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_key) REFERENCES dim_customer(customer_key),
    INDEX idx_customer (customer_key),
    INDEX idx_lifecycle_stage (lifecycle_stage),
    INDEX idx_entered_date (stage_entered_date)
);

-- ============================================================================
-- 2.2: Customer Engagement Metrics Table
-- Purpose: Daily customer engagement tracking
-- Grain: One row per customer per day
-- ============================================================================
CREATE TABLE IF NOT EXISTS customer_engagement_metrics (
    engagement_metric_key   BIGINT PRIMARY KEY AUTO_INCREMENT,
    metric_date             DATE NOT NULL,
    customer_key            BIGINT NOT NULL,
    -- Activity Metrics
    login_count             INT,
    page_views              BIGINT,
    features_used           INT,
    support_tickets_created INT,
    support_tickets_resolved INT,
    -- Interaction Metrics
    email_opens             INT,
    email_clicks            INT,
    webinar_attendance      BOOLEAN,
    training_session_count  INT,
    -- Product Usage
    active_users_count      INT,
    average_session_duration_minutes DECIMAL(10, 2),
    feature_adoption_rate_pct DECIMAL(8, 4),
    high_value_feature_usage_pct DECIMAL(8, 4),
    -- Sentiment & Health
    sentiment_score         DECIMAL(5, 2), -- -1 to 1 (negative to positive)
    nps_response           INT,
    csat_score             DECIMAL(5, 2),
    engagement_level       VARCHAR(20), -- High, Medium, Low
    health_status          VARCHAR(20), -- Healthy, At Risk, Critical
    dw_insert_ts           TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    dw_update_ts           TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_key) REFERENCES dim_customer(customer_key),
    INDEX idx_metric_date (metric_date),
    INDEX idx_customer_date (customer_key, metric_date),
    INDEX idx_engagement_level (engagement_level),
    INDEX idx_health_status (health_status)
);

-- ============================================================================
-- 2.3: Customer Financial Metrics Table
-- Purpose: Customer financial value and trend analysis
-- Grain: One row per customer per month
-- ============================================================================
CREATE TABLE IF NOT EXISTS customer_financial_metrics (
    financial_metric_key    BIGINT PRIMARY KEY AUTO_INCREMENT,
    year_month              CHAR(7), -- YYYY-MM
    customer_key            BIGINT NOT NULL,
    -- Revenue Metrics
    monthly_revenue         DECIMAL(15, 2),
    monthly_arr             DECIMAL(15, 2), -- Annual Recurring Revenue
    monthly_expansion_revenue DECIMAL(15, 2),
    monthly_churn_revenue   DECIMAL(15, 2),
    -- Customer Value
    lifetime_value          DECIMAL(15, 2),
    customer_acquisition_cost DECIMAL(15, 2),
    customer_payback_months DECIMAL(5, 2),
    -- Spending Patterns
    average_transaction_value DECIMAL(15, 4),
    transaction_count       BIGINT,
    high_value_transactions INT,
    -- Growth Metrics
    mom_growth_pct          DECIMAL(8, 4),
    qoq_growth_pct          DECIMAL(8, 4),
    yoy_growth_pct          DECIMAL(8, 4),
    expansion_rate_pct      DECIMAL(8, 4),
    -- Profitability
    gross_margin_pct        DECIMAL(8, 4),
    operating_cost_pct      DECIMAL(8, 4),
    profit_margin_pct       DECIMAL(8, 4),
    dw_insert_ts            TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    dw_update_ts            TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_key) REFERENCES dim_customer(customer_key),
    INDEX idx_year_month (year_month),
    INDEX idx_customer (customer_key),
    INDEX idx_arr (monthly_arr)
);

-- ============================================================================
-- SECTION 3: RETENTION CALCULATION TABLES
-- ============================================================================

-- ============================================================================
-- 3.1: Customer Retention Cohort Analysis Table
-- Purpose: Track customer retention by cohort (acquisition month)
-- Grain: One row per customer per retention period
-- ============================================================================
CREATE TABLE IF NOT EXISTS customer_retention_cohort (
    retention_cohort_key    BIGINT PRIMARY KEY AUTO_INCREMENT,
    acquisition_cohort      CHAR(7), -- YYYY-MM, month customer acquired
    retention_month         CHAR(7), -- YYYY-MM, measurement month
    months_since_acquisition INT, -- 0, 1, 2, 3, ..., 36, etc.
    -- Cohort Size
    cohort_size_start       BIGINT, -- Number of customers in cohort at start
    cohort_size_retained    BIGINT, -- Still active in measurement month
    -- Retention Metrics
    retention_rate_pct      DECIMAL(8, 4), -- Percentage retained
    -- Revenue Metrics
    cohort_revenue_start    DECIMAL(15, 2),
    cohort_revenue_current  DECIMAL(15, 2),
    cohort_arr_current      DECIMAL(15, 2),
    revenue_retention_rate_pct DECIMAL(8, 4),
    net_revenue_retention_pct DECIMAL(8, 4), -- Including expansion
    -- Health
    avg_health_score        DECIMAL(5, 2),
    avg_engagement_score    DECIMAL(5, 2),
    avg_nps_score           DECIMAL(5, 2),
    -- Expansion
    expanded_customers      BIGINT,
    expansion_rate_pct      DECIMAL(8, 4),
    dw_insert_ts            TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    dw_update_ts            TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_acquisition_cohort (acquisition_cohort),
    INDEX idx_retention_month (retention_month),
    INDEX idx_months_since (months_since_acquisition)
);

-- ============================================================================
-- 3.2: Customer Retention Status Table
-- Purpose: Current retention status for each customer
-- Grain: One row per customer
-- ============================================================================
CREATE TABLE IF NOT EXISTS customer_retention_status (
    retention_status_key    BIGINT PRIMARY KEY AUTO_INCREMENT,
    customer_key            BIGINT NOT NULL UNIQUE,
    is_active               BOOLEAN NOT NULL,
    -- Retention Timeline
    acquisition_date        DATE,
    first_purchase_date     DATE,
    last_purchase_date      DATE,
    days_since_last_activity INT,
    -- Retention Risk
    retention_risk_flag     BOOLEAN DEFAULT FALSE,
    retention_risk_score    DECIMAL(5, 2), -- 0-100, higher = more risk
    churn_probability_pct   DECIMAL(8, 4),
    risk_category           VARCHAR(20), -- Low, Medium, High, Critical
    risk_reason             VARCHAR(500),
    -- Intervention
    intervention_flag       BOOLEAN DEFAULT FALSE,
    intervention_type       VARCHAR(100),
    intervention_date       DATE,
    intervention_effective  BOOLEAN,
    -- Prediction
    predicted_churn_date    DATE,
    confidence_score_pct    DECIMAL(8, 4),
    dw_insert_ts            TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    dw_update_ts            TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_key) REFERENCES dim_customer(customer_key),
    INDEX idx_is_active (is_active),
    INDEX idx_risk_flag (retention_risk_flag),
    INDEX idx_risk_score (retention_risk_score)
);

-- ============================================================================
-- SECTION 4: CHURN ANALYSIS TABLES
-- ============================================================================

-- ============================================================================
-- 4.1: Customer Churn Events Table
-- Purpose: Track churn events with causes and context
-- Grain: One row per churn event
-- ============================================================================
CREATE TABLE IF NOT EXISTS customer_churn_events (
    churn_event_key         BIGINT PRIMARY KEY AUTO_INCREMENT,
    customer_key            BIGINT NOT NULL,
    -- Churn Details
    churn_date              DATE NOT NULL,
    churn_type              VARCHAR(50), -- Voluntary, Involuntary, Forced
    primary_churn_reason    VARCHAR(200),
    secondary_churn_reason  VARCHAR(200),
    churn_category          VARCHAR(100), -- Price, Competition, Product, Support, Consolidation
    -- Customer State at Churn
    tenure_days             INT,
    months_as_customer      INT,
    customer_lifetime_value DECIMAL(15, 2),
    arr_lost                DECIMAL(15, 2),
    -- Leading Indicators
    days_since_last_activity INT,
    engagement_decline_pct  DECIMAL(8, 4),
    support_tickets_increase_flag BOOLEAN,
    -- Financial Context
    last_monthly_spend      DECIMAL(15, 2),
    spending_decline_pct    DECIMAL(8, 4),
    was_expansion_customer  BOOLEAN,
    expansion_streak_broken BOOLEAN,
    -- Intervention History
    previous_interventions  INT,
    days_since_last_intervention INT,
    last_intervention_effective BOOLEAN,
    -- Prediction
    was_predicted_churn     BOOLEAN,
    prediction_accuracy     DECIMAL(5, 2),
    dw_insert_ts            TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_key) REFERENCES dim_customer(customer_key),
    INDEX idx_churn_date (churn_date),
    INDEX idx_churn_reason (primary_churn_reason),
    INDEX idx_churn_category (churn_category)
);

-- ============================================================================
-- 4.2: Monthly Churn Analysis Summary Table
-- Purpose: Aggregated churn metrics by month
-- Grain: One row per month
-- ============================================================================
CREATE TABLE IF NOT EXISTS monthly_churn_summary (
    churn_summary_key       BIGINT PRIMARY KEY AUTO_INCREMENT,
    year_month              CHAR(7), -- YYYY-MM
    -- Churn Volume
    customers_churned       BIGINT,
    arr_lost                DECIMAL(15, 2),
    mrr_lost                DECIMAL(15, 2),
    -- Churn Rate
    gross_churn_rate_pct    DECIMAL(8, 4),
    net_churn_rate_pct      DECIMAL(8, 4), -- After expansion
    cohort_churn_rate_pct   DECIMAL(8, 4),
    -- By Reason
    price_related_count     BIGINT,
    competition_count       BIGINT,
    product_count           BIGINT,
    support_count           BIGINT,
    consolidation_count     BIGINT,
    other_count             BIGINT,
    -- By Segment
    enterprise_churn_count  BIGINT,
    midmarket_churn_count   BIGINT,
    smb_churn_count         BIGINT,
    -- Metrics
    avg_tenure_days         DECIMAL(10, 2),
    avg_ltv_lost            DECIMAL(15, 2),
    involuntary_churn_pct   DECIMAL(8, 4),
    -- Performance
    successful_interventions BIGINT,
    intervention_success_rate_pct DECIMAL(8, 4),
    -- Trends
    mom_churn_change_pct    DECIMAL(8, 4),
    yoy_churn_change_pct    DECIMAL(8, 4),
    dw_insert_ts            TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    dw_update_ts            TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_year_month (year_month),
    INDEX idx_churn_rate (gross_churn_rate_pct)
);

-- ============================================================================
-- SECTION 5: RETENTION & CHURN CALCULATION PROCEDURES
-- ============================================================================

-- ============================================================================
-- 5.1: Calculate Customer Retention Status
-- Purpose: Determine current retention status for all customers
-- ============================================================================
CREATE PROCEDURE sp_calculate_customer_retention_status (
    @p_as_of_date DATE = NULL,
    @p_verbose BIT = 0
)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @v_as_of_date DATE = ISNULL(@p_as_of_date, CAST(GETDATE() AS DATE));
    DECLARE @v_critical_days INT = 90; -- Days without activity = critical

    BEGIN TRY
        IF @p_verbose = 1
            PRINT 'Calculating Customer Retention Status as of: ' + CONVERT(VARCHAR, @v_as_of_date);

        TRUNCATE TABLE customer_retention_status;

        INSERT INTO customer_retention_status (
            customer_key, is_active, acquisition_date, first_purchase_date, last_purchase_date,
            days_since_last_activity, retention_risk_flag, retention_risk_score,
            churn_probability_pct, risk_category
        )
        SELECT
            dc.customer_key,
            dc.is_active,
            dc.acquisition_date,
            dc.first_sale_date,
            MAX(fs.order_date) AS last_purchase_date,
            DATEDIFF(DAY, MAX(fs.order_date), @v_as_of_date) AS days_since_activity,
            CASE 
                WHEN DATEDIFF(DAY, MAX(fs.order_date), @v_as_of_date) > @v_critical_days THEN 1
                WHEN DATEDIFF(DAY, MAX(fs.order_date), @v_as_of_date) > 60 THEN 1
                ELSE 0
            END,
            CASE 
                WHEN DATEDIFF(DAY, MAX(fs.order_date), @v_as_of_date) > @v_critical_days THEN 95
                WHEN DATEDIFF(DAY, MAX(fs.order_date), @v_as_of_date) > 60 THEN 65
                WHEN DATEDIFF(DAY, MAX(fs.order_date), @v_as_of_date) > 30 THEN 35
                ELSE 10
            END,
            CASE 
                WHEN DATEDIFF(DAY, MAX(fs.order_date), @v_as_of_date) > @v_critical_days THEN 95
                WHEN DATEDIFF(DAY, MAX(fs.order_date), @v_as_of_date) > 60 THEN 65
                WHEN DATEDIFF(DAY, MAX(fs.order_date), @v_as_of_date) > 30 THEN 35
                ELSE 10
            END,
            CASE 
                WHEN DATEDIFF(DAY, MAX(fs.order_date), @v_as_of_date) > @v_critical_days THEN 'Critical'
                WHEN DATEDIFF(DAY, MAX(fs.order_date), @v_as_of_date) > 60 THEN 'High'
                WHEN DATEDIFF(DAY, MAX(fs.order_date), @v_as_of_date) > 30 THEN 'Medium'
                ELSE 'Low'
            END
        FROM dim_customer dc
        LEFT JOIN fact_sales fs ON dc.customer_key = fs.customer_key
        WHERE dc.is_current = 1
        GROUP BY dc.customer_key, dc.is_active, dc.acquisition_date, dc.first_sale_date;

        IF @p_verbose = 1
            PRINT 'Customer Retention Status calculated successfully';

    END TRY
    BEGIN CATCH
        PRINT 'Error in sp_calculate_customer_retention_status: ' + ERROR_MESSAGE();
        THROW;
    END CATCH;
END;
GO

-- ============================================================================
-- 5.2: Calculate Monthly Churn Summary
-- Purpose: Aggregate churn metrics by month
-- ============================================================================
CREATE PROCEDURE sp_calculate_monthly_churn_summary (
    @p_year_month CHAR(7) = NULL,
    @p_verbose BIT = 0
)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @v_year_month CHAR(7) = ISNULL(@p_year_month, FORMAT(GETDATE(), 'yyyy-MM'));

    BEGIN TRY
        IF @p_verbose = 1
            PRINT 'Calculating Monthly Churn Summary for: ' + @v_year_month;

        DELETE FROM monthly_churn_summary WHERE year_month = @v_year_month;

        INSERT INTO monthly_churn_summary (
            year_month, customers_churned, arr_lost, gross_churn_rate_pct,
            net_churn_rate_pct, price_related_count, competition_count,
            product_count, support_count, avg_tenure_days
        )
        SELECT
            @v_year_month,
            COUNT(DISTINCT cce.customer_key),
            SUM(cce.arr_lost),
            ROUND(COUNT(DISTINCT cce.customer_key) * 100.0 / 
                  (SELECT COUNT(DISTINCT customer_key) FROM dim_customer WHERE is_current = 1), 2),
            ROUND((COUNT(DISTINCT cce.customer_key) - 
                   (SELECT COUNT(DISTINCT customer_key) FROM customer_lifecycle_stage 
                    WHERE lifecycle_stage = 'Growth' AND stage_entered_date >= @v_year_month + '-01')) * 100.0 / 
                  (SELECT COUNT(DISTINCT customer_key) FROM dim_customer WHERE is_current = 1), 2),
            SUM(CASE WHEN cce.churn_category = 'Price' THEN 1 ELSE 0 END),
            SUM(CASE WHEN cce.churn_category = 'Competition' THEN 1 ELSE 0 END),
            SUM(CASE WHEN cce.churn_category = 'Product' THEN 1 ELSE 0 END),
            SUM(CASE WHEN cce.churn_category = 'Support' THEN 1 ELSE 0 END),
            ROUND(AVG(cce.tenure_days), 0)
        FROM customer_churn_events cce
        WHERE FORMAT(cce.churn_date, 'yyyy-MM') = @v_year_month
        GROUP BY FORMAT(cce.churn_date, 'yyyy-MM');

        IF @p_verbose = 1
            PRINT 'Monthly Churn Summary calculated successfully';

    END TRY
    BEGIN CATCH
        PRINT 'Error in sp_calculate_monthly_churn_summary: ' + ERROR_MESSAGE();
        THROW;
    END CATCH;
END;
GO

-- ============================================================================
-- SECTION 6: WORKFLOW & CUSTOMER TRACKING VIEWS
-- ============================================================================

-- ============================================================================
-- 6.1: Workflow Performance View
-- Purpose: Track workflow efficiency and metrics
-- ============================================================================
CREATE OR REPLACE VIEW vw_workflow_performance AS
SELECT
    wd.workflow_name,
    COUNT(DISTINCT wit.workflow_instance_key) AS total_workflows,
    SUM(CASE WHEN wit.is_completed = 1 THEN 1 ELSE 0 END) AS completed_count,
    SUM(CASE WHEN wit.is_failed = 1 THEN 1 ELSE 0 END) AS failed_count,
    ROUND(SUM(CASE WHEN wit.is_completed = 1 THEN 1 ELSE 0 END) * 100.0 / 
          COUNT(DISTINCT wit.workflow_instance_key), 2) AS completion_rate_pct,
    ROUND(AVG(wit.total_duration_minutes), 2) AS avg_duration_minutes,
    MAX(wit.total_duration_minutes) AS max_duration_minutes,
    MIN(wit.total_duration_minutes) AS min_duration_minutes,
    SUM(wit.state_transition_count) AS total_transitions,
    SUM(wit.escalation_count) AS escalation_count,
    CAST(GETDATE() AS DATE) AS report_date
FROM workflow_definition wd
LEFT JOIN workflow_instance_tracking wit ON wd.workflow_key = wit.workflow_key
    AND wit.workflow_started_time >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
WHERE wd.is_active = 1
GROUP BY wd.workflow_name;

-- ============================================================================
-- 6.2: Customer Health & Retention View
-- Purpose: Real-time customer health status
-- ============================================================================
CREATE OR REPLACE VIEW vw_customer_health_retention AS
SELECT
    dc.customer_key,
    dc.customer_name,
    dc.customer_segment,
    crs.risk_category,
    crs.retention_risk_score,
    ISNULL(cfm.monthly_arr, 0) AS current_arr,
    ISNULL(cfm.mom_growth_pct, 0) AS growth_rate,
    ISNULL(cem.health_status, 'Healthy') AS health_status,
    ISNULL(cem.engagement_level, 'Medium') AS engagement_level,
    ISNULL(cem.nps_response, 0) AS nps_score,
    crs.days_since_last_activity,
    CASE 
        WHEN crs.retention_risk_score >= 80 THEN 'Critical - Immediate Action'
        WHEN crs.retention_risk_score >= 60 THEN 'High - Proactive Engagement'
        WHEN crs.retention_risk_score >= 40 THEN 'Medium - Monitor Closely'
        ELSE 'Low - Normal Tracking'
    END AS recommended_action
FROM dim_customer dc
LEFT JOIN customer_retention_status crs ON dc.customer_key = crs.customer_key
LEFT JOIN customer_financial_metrics cfm ON dc.customer_key = cfm.customer_key 
    AND cfm.year_month = FORMAT(CAST(GETDATE() AS DATE), 'yyyy-MM')
LEFT JOIN customer_engagement_metrics cem ON dc.customer_key = cem.customer_key 
    AND cem.metric_date = CAST(GETDATE() AS DATE)
WHERE dc.is_current = 1
ORDER BY crs.retention_risk_score DESC;

-- ============================================================================
-- 6.3: Churn Risk & Intervention View
-- Purpose: Identify at-risk customers for intervention
-- ============================================================================
CREATE OR REPLACE VIEW vw_churn_risk_intervention AS
SELECT
    dc.customer_key,
    dc.customer_name,
    dc.customer_segment,
    crs.retention_risk_score,
    crs.churn_probability_pct,
    crs.predicted_churn_date,
    cfm.monthly_arr,
    cfm.mom_growth_pct,
    DATEDIFF(DAY, dc.first_sale_date, CAST(GETDATE() AS DATE)) AS customer_age_days,
    cem.health_status,
    cem.engagement_level,
    crs.risk_reason,
    CASE 
        WHEN crs.churn_probability_pct >= 80 THEN 'Executive Outreach'
        WHEN crs.churn_probability_pct >= 60 THEN 'Customer Success Intervention'
        WHEN crs.churn_probability_pct >= 40 THEN 'Product/Feature Enablement'
        ELSE 'Standard Account Management'
    END AS intervention_strategy
FROM dim_customer dc
LEFT JOIN customer_retention_status crs ON dc.customer_key = crs.customer_key
LEFT JOIN customer_financial_metrics cfm ON dc.customer_key = cfm.customer_key 
    AND cfm.year_month = FORMAT(CAST(GETDATE() AS DATE), 'yyyy-MM')
LEFT JOIN customer_engagement_metrics cem ON dc.customer_key = cem.customer_key 
    AND cem.metric_date = CAST(GETDATE() AS DATE)
WHERE dc.is_current = 1 AND crs.retention_risk_flag = 1
ORDER BY crs.churn_probability_pct DESC;

GO
