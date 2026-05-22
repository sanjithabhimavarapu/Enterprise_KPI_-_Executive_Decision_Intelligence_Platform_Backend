-- ============================================================================
-- KPI OPTIMIZATION & MATERIALIZED AGGREGATIONS
-- Enterprise KPI - Executive Decision Intelligence Platform
-- Purpose: Create optimized KPI queries with pre-aggregated data structures
-- Updated: May 22, 2026
-- ============================================================================

-- ============================================================================
-- SECTION 1: MATERIALIZED KPI AGGREGATION TABLES
-- These tables cache KPI calculations at multiple granularities
-- ============================================================================

-- ============================================================================
-- 1.1: Daily KPI Summary Table (Base Aggregation)
-- Grain: One row per KPI per day
-- Refresh: Daily (post-ETL)
-- ============================================================================
CREATE TABLE IF NOT EXISTS kpi_daily_summary (
    kpi_summary_key         BIGINT PRIMARY KEY AUTO_INCREMENT,
    kpi_date                DATE NOT NULL,
    kpi_name                VARCHAR(200) NOT NULL,
    kpi_category            VARCHAR(100) NOT NULL,
    kpi_value               DECIMAL(18, 4),
    kpi_value_prior_period  DECIMAL(18, 4),
    kpi_variance            DECIMAL(18, 4),
    kpi_variance_pct        DECIMAL(10, 4),
    unit_of_measure         VARCHAR(50),
    target_value            DECIMAL(18, 4),
    achievement_pct         DECIMAL(10, 4),
    status_flag             VARCHAR(20), -- GREEN, YELLOW, RED
    segment_key             BIGINT, -- Customer segment or department
    geography_key           BIGINT, -- Geography dimension
    employee_key            BIGINT, -- For employee-related KPIs
    data_quality_score      DECIMAL(5, 2), -- 0-100
    calculation_timestamp   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    dw_insert_ts            TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    dw_update_ts            TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_kpi_date (kpi_date),
    INDEX idx_kpi_name_date (kpi_name, kpi_date),
    INDEX idx_kpi_category (kpi_category),
    INDEX idx_segment_date (segment_key, kpi_date),
    INDEX idx_geography_date (geography_key, kpi_date),
    INDEX idx_status_flag (status_flag)
);

-- ============================================================================
-- 1.2: Weekly KPI Aggregation Table
-- Grain: One row per KPI per week
-- Refresh: Weekly (aggregated from daily)
-- ============================================================================
CREATE TABLE IF NOT EXISTS kpi_weekly_summary (
    kpi_summary_key         BIGINT PRIMARY KEY AUTO_INCREMENT,
    week_start_date         DATE NOT NULL,
    week_end_date           DATE NOT NULL,
    kpi_name                VARCHAR(200) NOT NULL,
    kpi_category            VARCHAR(100) NOT NULL,
    kpi_value               DECIMAL(18, 4),
    kpi_value_prior_week    DECIMAL(18, 4),
    kpi_trend_direction     VARCHAR(10), -- UP, DOWN, FLAT
    unit_of_measure         VARCHAR(50),
    target_value            DECIMAL(18, 4),
    achievement_pct         DECIMAL(10, 4),
    segment_key             BIGINT,
    geography_key           BIGINT,
    record_count            BIGINT,
    dw_insert_ts            TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    dw_update_ts            TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_week_date (week_start_date),
    INDEX idx_kpi_category_week (kpi_category, week_start_date)
);

-- ============================================================================
-- 1.3: Monthly KPI Aggregation Table
-- Grain: One row per KPI per month
-- Refresh: Monthly (aggregated from daily)
-- ============================================================================
CREATE TABLE IF NOT EXISTS kpi_monthly_summary (
    kpi_summary_key         BIGINT PRIMARY KEY AUTO_INCREMENT,
    year_month              CHAR(7) NOT NULL, -- YYYY-MM format
    kpi_name                VARCHAR(200) NOT NULL,
    kpi_category            VARCHAR(100) NOT NULL,
    kpi_value               DECIMAL(18, 4),
    kpi_value_prior_month   DECIMAL(18, 4),
    kpi_value_year_ago      DECIMAL(18, 4),
    kpi_variance_mom        DECIMAL(18, 4),
    kpi_variance_yoy        DECIMAL(18, 4),
    unit_of_measure         VARCHAR(50),
    target_value            DECIMAL(18, 4),
    achievement_pct         DECIMAL(10, 4),
    segment_key             BIGINT,
    geography_key           BIGINT,
    record_count            BIGINT,
    dw_insert_ts            TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    dw_update_ts            TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_year_month (year_month),
    INDEX idx_kpi_category_month (kpi_category, year_month),
    INDEX idx_segment_month (segment_key, year_month)
);

-- ============================================================================
-- 1.4: Financial Metrics Summary Table
-- Grain: One row per metric per date
-- Purpose: Pre-calculated financial KPIs for dashboard rendering
-- ============================================================================
CREATE TABLE IF NOT EXISTS financial_metrics_summary (
    financial_metric_key    BIGINT PRIMARY KEY AUTO_INCREMENT,
    metric_date             DATE NOT NULL,
    customer_key            BIGINT,
    product_key             BIGINT,
    segment_key             BIGINT,
    geography_key           BIGINT,
    -- Revenue Metrics
    total_revenue           DECIMAL(18, 2),
    net_revenue             DECIMAL(18, 2),
    gross_profit            DECIMAL(18, 2),
    gross_profit_margin_pct DECIMAL(8, 4),
    operating_expense       DECIMAL(18, 2),
    operating_margin_pct    DECIMAL(8, 4),
    net_income              DECIMAL(18, 2),
    net_margin_pct          DECIMAL(8, 4),
    -- Additional Metrics
    transaction_count       BIGINT,
    average_transaction_value DECIMAL(18, 4),
    freight_cost            DECIMAL(18, 2),
    duty_cost               DECIMAL(18, 2),
    discount_amount         DECIMAL(18, 2),
    discount_pct            DECIMAL(8, 4),
    ytd_revenue             DECIMAL(18, 2),
    ytd_gross_profit        DECIMAL(18, 2),
    dw_insert_ts            TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    dw_update_ts            TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_metric_date (metric_date),
    INDEX idx_customer_date (customer_key, metric_date),
    INDEX idx_segment_date (segment_key, metric_date),
    INDEX idx_geography_date (geography_key, metric_date)
);

-- ============================================================================
-- 1.5: Sales Performance Summary Table
-- Grain: One row per sales metric per date per segment
-- Purpose: Fast queries for sales dashboards
-- ============================================================================
CREATE TABLE IF NOT EXISTS sales_performance_summary (
    sales_metric_key        BIGINT PRIMARY KEY AUTO_INCREMENT,
    metric_date             DATE NOT NULL,
    employee_key            BIGINT,
    segment_key             BIGINT,
    geography_key           BIGINT,
    department              VARCHAR(100),
    -- Sales Metrics
    total_orders            BIGINT,
    total_units_sold        BIGINT,
    total_sales_amount      DECIMAL(18, 2),
    average_order_value     DECIMAL(18, 4),
    new_customers_count     BIGINT,
    returning_customers_count BIGINT,
    win_rate_pct            DECIMAL(8, 4),
    average_sales_cycle_days DECIMAL(10, 2),
    pipeline_value          DECIMAL(18, 2),
    closed_won_count        BIGINT,
    closed_lost_count       BIGINT,
    open_opportunities      BIGINT,
    -- Trend Metrics
    mom_growth_pct          DECIMAL(10, 4),
    qoq_growth_pct          DECIMAL(10, 4),
    yoy_growth_pct          DECIMAL(10, 4),
    ytd_sales_amount        DECIMAL(18, 2),
    dw_insert_ts            TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    dw_update_ts            TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_sales_date (metric_date),
    INDEX idx_employee_date (employee_key, metric_date),
    INDEX idx_segment_date (segment_key, metric_date),
    INDEX idx_geography_date (geography_key, metric_date),
    INDEX idx_department (department)
);

-- ============================================================================
-- 1.6: Customer Success Metrics Summary Table
-- Grain: One row per customer success metric per date
-- Purpose: Health score and retention tracking
-- ============================================================================
CREATE TABLE IF NOT EXISTS customer_success_summary (
    cs_metric_key           BIGINT PRIMARY KEY AUTO_INCREMENT,
    metric_date             DATE NOT NULL,
    customer_key            BIGINT,
    segment_key             BIGINT,
    geography_key           BIGINT,
    -- Retention & Churn
    is_active               BOOLEAN,
    churn_flag              BOOLEAN,
    retention_cohort        VARCHAR(20), -- 1m, 3m, 6m, 12m
    -- Health Metrics
    customer_health_score   DECIMAL(5, 2), -- 0-100
    usage_score             DECIMAL(5, 2),
    satisfaction_score      DECIMAL(5, 2),
    support_sentiment_score DECIMAL(5, 2),
    engagement_level        VARCHAR(20), -- High, Medium, Low
    -- Revenue Metrics
    current_arr             DECIMAL(18, 2), -- Annual Recurring Revenue
    expansion_revenue       DECIMAL(18, 2),
    churn_revenue           DECIMAL(18, 2),
    net_revenue_retention_pct DECIMAL(8, 4),
    -- Support Metrics
    open_tickets            BIGINT,
    resolved_tickets        BIGINT,
    avg_resolution_time_hours DECIMAL(10, 2),
    nps_score               DECIMAL(5, 2),
    dw_insert_ts            TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    dw_update_ts            TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_cs_date (metric_date),
    INDEX idx_customer_date (customer_key, metric_date),
    INDEX idx_health_score (customer_health_score),
    INDEX idx_churn_flag (churn_flag)
);

-- ============================================================================
-- 1.7: Operational Metrics Summary Table
-- Grain: One row per operational metric per date
-- Purpose: Supply chain, fulfillment, and quality tracking
-- ============================================================================
CREATE TABLE IF NOT EXISTS operational_metrics_summary (
    ops_metric_key          BIGINT PRIMARY KEY AUTO_INCREMENT,
    metric_date             DATE NOT NULL,
    warehouse_location      VARCHAR(100),
    product_key             BIGINT,
    geography_key           BIGINT,
    -- Fulfillment Metrics
    orders_received         BIGINT,
    orders_fulfilled        BIGINT,
    orders_fulfilled_ontime BIGINT,
    fulfillment_rate_pct    DECIMAL(8, 4),
    ontime_delivery_rate_pct DECIMAL(8, 4),
    avg_fulfillment_days    DECIMAL(10, 2),
    -- Inventory Metrics
    inventory_value         DECIMAL(18, 2),
    inventory_units         BIGINT,
    inventory_turnover_ratio DECIMAL(10, 4),
    slow_moving_inventory   BIGINT,
    obsolete_inventory      BIGINT,
    stockout_incidents      BIGINT,
    -- Quality Metrics
    total_units_produced    BIGINT,
    defective_units         BIGINT,
    defect_rate_pct         DECIMAL(8, 4),
    first_pass_yield_pct    DECIMAL(8, 4),
    rework_cost             DECIMAL(18, 2),
    -- Cost Metrics
    operating_expense       DECIMAL(18, 2),
    freight_cost            DECIMAL(18, 2),
    warehouse_cost          DECIMAL(18, 2),
    efficiency_ratio_pct    DECIMAL(8, 4),
    dw_insert_ts            TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    dw_update_ts            TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_ops_date (metric_date),
    INDEX idx_warehouse_date (warehouse_location, metric_date),
    INDEX idx_product_date (product_key, metric_date),
    INDEX idx_fulfillment_rate (fulfillment_rate_pct)
);

-- ============================================================================
-- 1.8: HR & Employee Performance Summary Table
-- Grain: One row per employee per date
-- Purpose: Workforce analytics and performance tracking
-- ============================================================================
CREATE TABLE IF NOT EXISTS hr_performance_summary (
    hr_metric_key           BIGINT PRIMARY KEY AUTO_INCREMENT,
    metric_date             DATE NOT NULL,
    employee_key            BIGINT,
    department              VARCHAR(100),
    geography_key           BIGINT,
    job_title               VARCHAR(100),
    -- Headcount Metrics
    is_active_employee      BOOLEAN,
    tenure_months           INT,
    -- Performance Metrics
    productivity_score      DECIMAL(8, 4),
    productivity_per_employee DECIMAL(18, 2), -- Revenue/output per employee
    sales_per_rep           DECIMAL(18, 2),
    quota_attainment_pct    DECIMAL(8, 4),
    engagement_score        DECIMAL(5, 2),
    performance_rating      VARCHAR(20), -- Exceeds, Meets, Below
    -- Development Metrics
    training_hours_ytd      DECIMAL(10, 2),
    certifications_count    INT,
    promotion_eligible      BOOLEAN,
    -- Turnover Metrics
    is_turnover_risk        BOOLEAN,
    voluntary_turnover_flag BOOLEAN,
    -- Compensation
    salary_grade            VARCHAR(20),
    bonus_target_pct        DECIMAL(8, 4),
    dw_insert_ts            TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    dw_update_ts            TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_hr_date (metric_date),
    INDEX idx_employee_date (employee_key, metric_date),
    INDEX idx_department (department),
    INDEX idx_is_active (is_active_employee)
);

-- ============================================================================
-- SECTION 2: OPTIMIZED KPI VIEW QUERIES
-- ============================================================================

-- ============================================================================
-- 2.1: Executive KPI Dashboard View
-- Purpose: High-level KPIs for executive reporting
-- Performance: < 100ms (uses materialized tables)
-- ============================================================================
CREATE OR REPLACE VIEW vw_executive_kpi_dashboard AS
SELECT
    CAST(GETDATE() AS DATE) AS dashboard_date,
    'Revenue' AS kpi_category,
    'Total Revenue' AS kpi_name,
    SUM(fms.total_revenue) AS kpi_value,
    'USD' AS unit,
    SUM(fms.total_revenue - fms.gross_profit) AS cogs_value,
    ROUND(SUM(fms.gross_profit_margin_pct) / COUNT(*), 2) AS gross_margin,
    'Active' AS status
FROM financial_metrics_summary fms
WHERE fms.metric_date = CAST(GETDATE() AS DATE)

UNION ALL

SELECT
    CAST(GETDATE() AS DATE),
    'Sales',
    'Total Orders',
    SUM(sps.total_orders),
    'Count',
    SUM(sps.new_customers_count),
    ROUND(AVG(sps.yoy_growth_pct), 2),
    'Active'
FROM sales_performance_summary sps
WHERE sps.metric_date = CAST(GETDATE() AS DATE)

UNION ALL

SELECT
    CAST(GETDATE() AS DATE),
    'Customer Success',
    'Customer Health Score',
    ROUND(AVG(css.customer_health_score), 2),
    'Score',
    COUNT(CASE WHEN css.churn_flag = 1 THEN 1 END),
    ROUND(AVG(css.nps_score), 2),
    'Active'
FROM customer_success_summary css
WHERE css.metric_date = CAST(GETDATE() AS DATE);

-- ============================================================================
-- 2.2: Financial KPI Optimized View
-- Purpose: Complete financial metrics for FP&A teams
-- ============================================================================
CREATE OR REPLACE VIEW vw_financial_kpi_optimized AS
SELECT
    fms.metric_date,
    fms.segment_key,
    fms.geography_key,
    ROUND(SUM(fms.total_revenue), 2) AS total_revenue,
    ROUND(SUM(fms.net_revenue), 2) AS net_revenue,
    ROUND(SUM(fms.gross_profit), 2) AS gross_profit,
    ROUND(AVG(fms.gross_profit_margin_pct), 2) AS gross_margin_pct,
    ROUND(SUM(fms.operating_expense), 2) AS operating_expense,
    ROUND(AVG(fms.operating_margin_pct), 2) AS operating_margin_pct,
    ROUND(SUM(fms.net_income), 2) AS net_income,
    ROUND(AVG(fms.net_margin_pct), 2) AS net_margin_pct,
    ROUND(SUM(fms.discount_amount), 2) AS total_discount,
    ROUND(AVG(fms.discount_pct), 2) AS avg_discount_pct,
    ROUND(SUM(fms.ytd_revenue), 2) AS ytd_revenue,
    COUNT(*) AS record_count
FROM financial_metrics_summary fms
WHERE fms.metric_date >= DATEADD(DAY, -90, CAST(GETDATE() AS DATE))
GROUP BY fms.metric_date, fms.segment_key, fms.geography_key;

-- ============================================================================
-- 2.3: Sales Performance Optimized View (by Segment & Geography)
-- Purpose: Segmented sales analysis for sales leadership
-- ============================================================================
CREATE OR REPLACE VIEW vw_sales_performance_optimized AS
SELECT
    sps.metric_date,
    sps.segment_key,
    sps.geography_key,
    sps.department,
    COUNT(DISTINCT sps.employee_key) AS rep_count,
    SUM(sps.total_orders) AS total_orders,
    SUM(sps.total_units_sold) AS total_units,
    ROUND(SUM(sps.total_sales_amount), 2) AS total_sales,
    ROUND(AVG(sps.average_order_value), 2) AS avg_order_value,
    SUM(sps.new_customers_count) AS new_customers,
    ROUND(AVG(sps.win_rate_pct), 2) AS win_rate_pct,
    ROUND(AVG(sps.average_sales_cycle_days), 1) AS avg_sales_cycle_days,
    ROUND(SUM(sps.pipeline_value), 2) AS pipeline_value,
    SUM(sps.closed_won_count) AS won_deals,
    SUM(sps.closed_lost_count) AS lost_deals,
    ROUND(AVG(sps.yoy_growth_pct), 2) AS yoy_growth_pct,
    ROUND(SUM(sps.ytd_sales_amount), 2) AS ytd_sales
FROM sales_performance_summary sps
WHERE sps.metric_date >= DATEADD(DAY, -90, CAST(GETDATE() AS DATE))
GROUP BY sps.metric_date, sps.segment_key, sps.geography_key, sps.department;

-- ============================================================================
-- 2.4: Customer Success Health View
-- Purpose: Track customer health and churn risk
-- ============================================================================
CREATE OR REPLACE VIEW vw_customer_health_optimized AS
SELECT
    css.metric_date,
    css.segment_key,
    css.geography_key,
    COUNT(DISTINCT css.customer_key) AS total_customers,
    SUM(CASE WHEN css.is_active = 1 THEN 1 ELSE 0 END) AS active_customers,
    SUM(CASE WHEN css.churn_flag = 1 THEN 1 ELSE 0 END) AS churned_customers,
    ROUND(ROUND(SUM(CASE WHEN css.is_active = 1 THEN 1 ELSE 0 END), 0) * 100.0 / 
          COUNT(DISTINCT css.customer_key), 2) AS retention_rate_pct,
    ROUND(AVG(css.customer_health_score), 2) AS avg_health_score,
    ROUND(AVG(css.usage_score), 2) AS avg_usage_score,
    ROUND(AVG(css.satisfaction_score), 2) AS avg_satisfaction,
    ROUND(AVG(css.nps_score), 2) AS avg_nps,
    ROUND(SUM(css.current_arr), 2) AS current_arr,
    ROUND(SUM(css.expansion_revenue), 2) AS expansion_revenue,
    ROUND(SUM(css.churn_revenue), 2) AS churn_revenue,
    ROUND(AVG(css.net_revenue_retention_pct), 2) AS net_revenue_retention_pct,
    SUM(css.open_tickets) AS open_support_tickets,
    ROUND(AVG(css.avg_resolution_time_hours), 1) AS avg_resolution_hours
FROM customer_success_summary css
WHERE css.metric_date >= DATEADD(DAY, -90, CAST(GETDATE() AS DATE))
GROUP BY css.metric_date, css.segment_key, css.geography_key;

-- ============================================================================
-- 2.5: Operational Efficiency View
-- Purpose: Track fulfillment, quality, and operational metrics
-- ============================================================================
CREATE OR REPLACE VIEW vw_operational_efficiency_optimized AS
SELECT
    ops.metric_date,
    ops.warehouse_location,
    ops.product_key,
    ops.geography_key,
    SUM(ops.orders_received) AS orders_received,
    SUM(ops.orders_fulfilled) AS orders_fulfilled,
    SUM(ops.orders_fulfilled_ontime) AS ontime_fulfilled,
    ROUND(AVG(ops.fulfillment_rate_pct), 2) AS fulfillment_rate_pct,
    ROUND(AVG(ops.ontime_delivery_rate_pct), 2) AS ontime_delivery_rate_pct,
    ROUND(AVG(ops.avg_fulfillment_days), 1) AS avg_fulfillment_days,
    SUM(ops.inventory_units) AS inventory_units,
    ROUND(SUM(ops.inventory_value), 2) AS inventory_value,
    ROUND(AVG(ops.inventory_turnover_ratio), 2) AS inventory_turnover_ratio,
    SUM(ops.stockout_incidents) AS stockout_incidents,
    SUM(ops.total_units_produced) AS units_produced,
    SUM(ops.defective_units) AS defective_units,
    ROUND(AVG(ops.defect_rate_pct), 2) AS defect_rate_pct,
    ROUND(AVG(ops.first_pass_yield_pct), 2) AS first_pass_yield_pct,
    ROUND(SUM(ops.rework_cost), 2) AS rework_cost,
    ROUND(AVG(ops.efficiency_ratio_pct), 2) AS efficiency_ratio_pct,
    ROUND(SUM(ops.warehouse_cost), 2) AS warehouse_cost
FROM operational_metrics_summary ops
WHERE ops.metric_date >= DATEADD(DAY, -90, CAST(GETDATE() AS DATE))
GROUP BY ops.metric_date, ops.warehouse_location, ops.product_key, ops.geography_key;

-- ============================================================================
-- 2.6: HR Performance Dashboard View
-- Purpose: Workforce analytics and performance metrics
-- ============================================================================
CREATE OR REPLACE VIEW vw_hr_performance_optimized AS
SELECT
    hrps.metric_date,
    hrps.department,
    hrps.geography_key,
    COUNT(DISTINCT hrps.employee_key) AS headcount,
    SUM(CASE WHEN hrps.is_active_employee = 1 THEN 1 ELSE 0 END) AS active_employees,
    ROUND(AVG(CASE WHEN hrps.productivity_per_employee > 0 THEN hrps.productivity_per_employee ELSE NULL END), 2) AS avg_productivity,
    ROUND(AVG(CASE WHEN hrps.sales_per_rep > 0 THEN hrps.sales_per_rep ELSE NULL END), 2) AS avg_sales_per_rep,
    ROUND(AVG(hrps.quota_attainment_pct), 2) AS avg_quota_attainment_pct,
    ROUND(AVG(hrps.engagement_score), 2) AS avg_engagement_score,
    ROUND(AVG(hrps.training_hours_ytd), 1) AS avg_training_hours,
    SUM(CASE WHEN hrps.is_turnover_risk = 1 THEN 1 ELSE 0 END) AS at_risk_employees,
    SUM(CASE WHEN hrps.voluntary_turnover_flag = 1 THEN 1 ELSE 0 END) AS voluntary_separations
FROM hr_performance_summary hrps
WHERE hrps.metric_date >= DATEADD(DAY, -90, CAST(GETDATE() AS DATE))
GROUP BY hrps.metric_date, hrps.department, hrps.geography_key;

-- ============================================================================
-- SECTION 3: EXECUTIVE AGGREGATION VIEWS
-- ============================================================================

-- ============================================================================
-- 3.1: Executive Summary Dashboard - All KPIs at a Glance
-- Grain: One row per business day
-- Purpose: High-level KPI tracking for C-suite
-- ============================================================================
CREATE OR REPLACE VIEW vw_executive_summary_dashboard AS
SELECT
    ks.kpi_date,
    'Financial Performance' AS dashboard_section,
    'Revenue' AS metric_group,
    COUNT(CASE WHEN ks.kpi_category = 'Financial' AND ks.kpi_name LIKE '%Revenue%' THEN 1 END) AS kpi_count,
    ROUND(AVG(CASE WHEN ks.kpi_name = 'Total Revenue' THEN ks.kpi_value ELSE NULL END), 2) AS primary_metric,
    ROUND(AVG(CASE WHEN ks.kpi_name = 'Total Revenue' THEN ks.achievement_pct ELSE NULL END), 2) AS achievement_pct,
    MAX(CASE WHEN ks.kpi_name = 'Total Revenue' THEN ks.status_flag ELSE NULL END) AS status
FROM kpi_daily_summary ks
WHERE ks.kpi_date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
GROUP BY ks.kpi_date

UNION ALL

SELECT
    ks.kpi_date,
    'Sales Performance',
    'Growth',
    COUNT(CASE WHEN ks.kpi_category = 'Sales' THEN 1 END),
    ROUND(AVG(CASE WHEN ks.kpi_name = 'Sales Growth Rate (YoY)' THEN ks.kpi_value ELSE NULL END), 2),
    ROUND(AVG(CASE WHEN ks.kpi_name = 'Sales Growth Rate (YoY)' THEN ks.achievement_pct ELSE NULL END), 2),
    MAX(CASE WHEN ks.kpi_name = 'Sales Growth Rate (YoY)' THEN ks.status_flag ELSE NULL END)
FROM kpi_daily_summary ks
WHERE ks.kpi_date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
GROUP BY ks.kpi_date

UNION ALL

SELECT
    ks.kpi_date,
    'Customer Success',
    'Health',
    COUNT(CASE WHEN ks.kpi_category = 'Customer Success' THEN 1 END),
    ROUND(AVG(CASE WHEN ks.kpi_name = 'Customer Retention Rate' THEN ks.kpi_value ELSE NULL END), 2),
    ROUND(AVG(CASE WHEN ks.kpi_name = 'Customer Retention Rate' THEN ks.achievement_pct ELSE NULL END), 2),
    MAX(CASE WHEN ks.kpi_name = 'Customer Retention Rate' THEN ks.status_flag ELSE NULL END)
FROM kpi_daily_summary ks
WHERE ks.kpi_date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
GROUP BY ks.kpi_date;

-- ============================================================================
-- 3.2: Segment-Level Executive View
-- Purpose: Compare performance across customer segments
-- ============================================================================
CREATE OR REPLACE VIEW vw_executive_segment_comparison AS
SELECT
    ks.kpi_date,
    'Enterprise' AS segment,
    ROUND(SUM(CASE WHEN ks.kpi_name = 'Total Revenue' THEN ks.kpi_value ELSE 0 END), 2) AS revenue,
    ROUND(AVG(CASE WHEN ks.kpi_name = 'Gross Profit Margin' THEN ks.kpi_value ELSE NULL END), 2) AS margin_pct,
    ROUND(AVG(CASE WHEN ks.kpi_name = 'Win Rate' THEN ks.kpi_value ELSE NULL END), 2) AS win_rate_pct,
    COUNT(DISTINCT ks.segment_key) AS segment_count
FROM kpi_daily_summary ks
WHERE ks.kpi_date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
  AND ks.segment_key IS NOT NULL
GROUP BY ks.kpi_date

UNION ALL

SELECT
    ks.kpi_date,
    'Mid-Market',
    ROUND(SUM(CASE WHEN ks.kpi_name = 'Total Revenue' THEN ks.kpi_value ELSE 0 END), 2),
    ROUND(AVG(CASE WHEN ks.kpi_name = 'Gross Profit Margin' THEN ks.kpi_value ELSE NULL END), 2),
    ROUND(AVG(CASE WHEN ks.kpi_name = 'Win Rate' THEN ks.kpi_value ELSE NULL END), 2),
    COUNT(DISTINCT ks.segment_key)
FROM kpi_daily_summary ks
WHERE ks.kpi_date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
  AND ks.segment_key IS NOT NULL
GROUP BY ks.kpi_date

UNION ALL

SELECT
    ks.kpi_date,
    'SMB',
    ROUND(SUM(CASE WHEN ks.kpi_name = 'Total Revenue' THEN ks.kpi_value ELSE 0 END), 2),
    ROUND(AVG(CASE WHEN ks.kpi_name = 'Gross Profit Margin' THEN ks.kpi_value ELSE NULL END), 2),
    ROUND(AVG(CASE WHEN ks.kpi_name = 'Win Rate' THEN ks.kpi_value ELSE NULL END), 2),
    COUNT(DISTINCT ks.segment_key)
FROM kpi_daily_summary ks
WHERE ks.kpi_date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
  AND ks.segment_key IS NOT NULL
GROUP BY ks.kpi_date;

-- ============================================================================
-- 3.3: Geographic Performance View
-- Purpose: Compare performance across regions
-- ============================================================================
CREATE OR REPLACE VIEW vw_executive_geography_performance AS
SELECT
    ks.kpi_date,
    dg.region,
    dg.country,
    ROUND(SUM(CASE WHEN ks.kpi_name = 'Total Revenue' THEN ks.kpi_value ELSE 0 END), 2) AS revenue,
    COUNT(DISTINCT CASE WHEN ks.achievement_pct >= 90 THEN ks.kpi_name END) AS kpis_on_target,
    COUNT(DISTINCT ks.kpi_name) AS total_kpis,
    ROUND(AVG(CASE WHEN ks.achievement_pct >= 0 THEN ks.achievement_pct ELSE NULL END), 2) AS avg_achievement_pct
FROM kpi_daily_summary ks
LEFT JOIN dim_geography dg ON ks.geography_key = dg.geography_key
WHERE ks.kpi_date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
  AND dg.is_current = 1
GROUP BY ks.kpi_date, dg.region, dg.country;

-- ============================================================================
-- 3.4: Year-to-Date Performance Trend View
-- Purpose: Track YTD progress vs targets
-- ============================================================================
CREATE OR REPLACE VIEW vw_ytd_performance_trend AS
SELECT
    ks.kpi_date,
    ks.kpi_name,
    ks.kpi_category,
    ROUND(SUM(ks.kpi_value), 2) AS ytd_value,
    ROUND(SUM(ks.target_value), 2) AS ytd_target,
    ROUND((SUM(ks.kpi_value) / NULLIF(SUM(ks.target_value), 0)) * 100, 2) AS ytd_achievement_pct,
    ROUND(AVG(ks.achievement_pct), 2) AS avg_daily_achievement_pct,
    MAX(ks.status_flag) AS overall_status
FROM kpi_daily_summary ks
WHERE YEAR(ks.kpi_date) = YEAR(GETDATE())
  AND ks.kpi_date <= CAST(GETDATE() AS DATE)
GROUP BY ks.kpi_date, ks.kpi_name, ks.kpi_category;

GO
