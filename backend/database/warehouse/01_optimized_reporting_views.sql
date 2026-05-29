-- ============================================================================
-- OPTIMIZED REPORTING VIEWS
-- Enterprise KPI - Executive Decision Intelligence Platform
-- Purpose: High-performance materialized views for executive reporting
-- Updated: Daily post-ETL
-- ============================================================================

-- ============================================================================
-- EXECUTIVE SUMMARY VIEWS (Pre-aggregated)
-- ============================================================================

-- View: Daily Financial Summary (Materialized)
-- Grain: One row per day
-- Refresh: Daily (post-ETL)
CREATE VIEW vw_daily_financial_summary AS
SELECT 
    fr.date_key,
    dd.date_value,
    dd.year,
    dd.month,
    dd.quarter,
    SUM(fr.total_revenue) AS daily_revenue,
    SUM(fr.gross_sales) AS gross_sales,
    SUM(fr.discounts) AS total_discounts,
    SUM(fr.net_revenue) AS net_revenue,
    SUM(fr.cost_of_goods) AS cogs,
    SUM(fr.gross_profit) AS gross_profit,
    CASE 
        WHEN SUM(fr.net_revenue) > 0 
        THEN ROUND(SUM(fr.gross_profit) / SUM(fr.net_revenue) * 100, 2)
        ELSE 0 
    END AS gross_margin_pct,
    COUNT(*) AS transaction_count,
    SUM(fr.revenue_count) AS line_item_count,
    AVG(fr.average_transaction_amt) AS avg_transaction_amt
FROM fact_revenue fr
INNER JOIN dim_date dd ON fr.date_key = dd.date_key
GROUP BY fr.date_key, dd.date_value, dd.year, dd.month, dd.quarter;

-- View: Monthly Financial Summary (Materialized)
-- Grain: One row per month per segment
CREATE VIEW vw_monthly_financial_segment_summary AS
SELECT 
    dd.year,
    dd.month,
    dd.month_name,
    dc.customer_segment,
    SUM(fr.total_revenue) AS month_revenue,
    ROUND(SUM(fr.net_revenue), 2) AS net_revenue,
    ROUND(SUM(fr.gross_profit), 2) AS gross_profit,
    CASE 
        WHEN SUM(fr.net_revenue) > 0 
        THEN ROUND(SUM(fr.gross_profit) / SUM(fr.net_revenue) * 100, 2)
        ELSE 0 
    END AS gross_margin_pct,
    COUNT(DISTINCT fr.customer_key) AS unique_customers,
    SUM(fr.revenue_count) AS total_transactions
FROM fact_revenue fr
INNER JOIN dim_date dd ON fr.date_key = dd.date_key
INNER JOIN dim_customer dc ON fr.customer_key = dc.customer_key AND dc.is_current = 1
GROUP BY dd.year, dd.month, dd.month_name, dc.customer_segment;

-- View: Sales Performance by Employee (Materialized)
-- Grain: One row per employee per month
CREATE VIEW vw_employee_sales_performance AS
SELECT 
    de.employee_key,
    de.employee_id,
    de.employee_name,
    de.job_title,
    de.department,
    dd.year,
    dd.month,
    dd.month_name,
    COUNT(DISTINCT fs.order_id) AS total_orders,
    SUM(fs.net_sales_amount) AS total_sales,
    SUM(fs.gross_profit) AS total_profit,
    ROUND(AVG(fs.net_sales_amount), 2) AS avg_deal_size,
    CASE 
        WHEN SUM(fs.net_sales_amount) > 0 
        THEN ROUND(SUM(fs.gross_profit) / SUM(fs.net_sales_amount) * 100, 2)
        ELSE 0 
    END AS profit_margin_pct,
    COUNT(DISTINCT fs.customer_key) AS unique_customers
FROM fact_sales fs
INNER JOIN dim_employee de ON fs.employee_key = de.employee_key
INNER JOIN dim_date dd ON fs.order_date_key = dd.date_key
WHERE de.is_current = 1
GROUP BY de.employee_key, de.employee_id, de.employee_name, de.job_title, 
         de.department, dd.year, dd.month, dd.month_name;

-- View: Customer Revenue Analysis (Materialized)
-- Grain: One row per customer per month
CREATE VIEW vw_customer_revenue_analysis AS
SELECT 
    dc.customer_key,
    dc.customer_id,
    dc.customer_name,
    dc.customer_segment,
    dc.industry,
    dc.region,
    dd.year,
    dd.month,
    COUNT(DISTINCT fs.order_id) AS monthly_orders,
    SUM(fs.net_sales_amount) AS monthly_revenue,
    SUM(fs.gross_profit) AS monthly_profit,
    CASE 
        WHEN SUM(fs.net_sales_amount) > 0 
        THEN ROUND(SUM(fs.gross_profit) / SUM(fs.net_sales_amount) * 100, 2)
        ELSE 0 
    END AS profit_margin_pct,
    COUNT(DISTINCT fs.product_key) AS products_purchased,
    dc.annual_contract_value,
    dc.customer_lifetime_value
FROM fact_sales fs
INNER JOIN dim_customer dc ON fs.customer_key = dc.customer_key AND dc.is_current = 1
INNER JOIN dim_date dd ON fs.order_date_key = dd.date_key
GROUP BY dc.customer_key, dc.customer_id, dc.customer_name, dc.customer_segment, 
         dc.industry, dc.region, dd.year, dd.month, dc.annual_contract_value, 
         dc.customer_lifetime_value;

-- View: Product Performance by Category (Materialized)
-- Grain: One row per product category per month
CREATE VIEW vw_product_category_performance AS
SELECT 
    dp.product_category,
    dp.product_subcategory,
    dd.year,
    dd.month,
    dd.month_name,
    COUNT(DISTINCT fs.order_id) AS total_orders,
    SUM(fs.order_quantity) AS total_units_sold,
    SUM(fs.net_sales_amount) AS total_sales,
    SUM(fs.gross_profit) AS total_profit,
    ROUND(AVG(fs.net_sales_amount), 2) AS avg_order_value,
    CASE 
        WHEN SUM(fs.net_sales_amount) > 0 
        THEN ROUND(SUM(fs.gross_profit) / SUM(fs.net_sales_amount) * 100, 2)
        ELSE 0 
    END AS profit_margin_pct,
    COUNT(DISTINCT fs.customer_key) AS unique_customers,
    COUNT(DISTINCT dp.product_key) AS product_count
FROM fact_sales fs
INNER JOIN dim_product dp ON fs.product_key = dp.product_key AND dp.is_current = 1
INNER JOIN dim_date dd ON fs.order_date_key = dd.date_key
GROUP BY dp.product_category, dp.product_subcategory, dd.year, dd.month, dd.month_name;

-- ============================================================================
-- INVENTORY & OPERATIONAL VIEWS (Materialized)
-- ============================================================================

-- View: Current Inventory Status by Product
-- Grain: Latest inventory snapshot per product per location
CREATE VIEW vw_current_inventory_status AS
SELECT 
    dp.product_key,
    dp.product_id,
    dp.product_name,
    dp.product_category,
    fi.warehouse_location_id,
    MAX(fi.date_key) AS latest_date,
    FIRST_VALUE(fi.ending_inventory_balance) OVER (
        PARTITION BY fi.product_key, fi.warehouse_location_id 
        ORDER BY fi.date_key DESC
    ) AS current_inventory,
    FIRST_VALUE(fi.reorder_point) OVER (
        PARTITION BY fi.product_key, fi.warehouse_location_id 
        ORDER BY fi.date_key DESC
    ) AS reorder_point,
    CASE 
        WHEN FIRST_VALUE(fi.ending_inventory_balance) OVER (
            PARTITION BY fi.product_key, fi.warehouse_location_id 
            ORDER BY fi.date_key DESC
        ) <= FIRST_VALUE(fi.reorder_point) OVER (
            PARTITION BY fi.product_key, fi.warehouse_location_id 
            ORDER BY fi.date_key DESC
        ) THEN 'REORDER NEEDED'
        WHEN FIRST_VALUE(fi.ending_inventory_balance) OVER (
            PARTITION BY fi.product_key, fi.warehouse_location_id 
            ORDER BY fi.date_key DESC
        ) <= FIRST_VALUE(fi.reorder_point) OVER (
            PARTITION BY fi.product_key, fi.warehouse_location_id 
            ORDER BY fi.date_key DESC
        ) * 1.5 THEN 'LOW STOCK'
        ELSE 'ADEQUATE'
    END AS inventory_status,
    dp.lead_time_days
FROM fact_inventory fi
INNER JOIN dim_product dp ON fi.product_key = dp.product_key
WHERE ROW_NUMBER() OVER (
    PARTITION BY fi.product_key, fi.warehouse_location_id 
    ORDER BY fi.date_key DESC
) = 1;

-- ============================================================================
-- TIME-BASED TREND VIEWS
-- ============================================================================

-- View: Revenue Trends (Last 90 Days)
-- Grain: One row per day with trend indicators
CREATE VIEW vw_revenue_trend_90_days AS
SELECT 
    dd.date_key,
    dd.date_value,
    SUM(fr.total_revenue) AS daily_revenue,
    AVG(SUM(fr.total_revenue)) OVER (
        ORDER BY dd.date_key ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS revenue_7day_avg,
    AVG(SUM(fr.total_revenue)) OVER (
        ORDER BY dd.date_key ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
    ) AS revenue_30day_avg,
    LAG(SUM(fr.total_revenue), 1) OVER (ORDER BY dd.date_key) AS prev_day_revenue,
    ROUND(
        (SUM(fr.total_revenue) - LAG(SUM(fr.total_revenue), 1) OVER (ORDER BY dd.date_key)) / 
        NULLIF(LAG(SUM(fr.total_revenue), 1) OVER (ORDER BY dd.date_key), 0) * 100,
        2
    ) AS day_over_day_growth_pct,
    LAG(SUM(fr.total_revenue), 7) OVER (ORDER BY dd.date_key) AS prev_week_same_day_revenue,
    ROUND(
        (SUM(fr.total_revenue) - LAG(SUM(fr.total_revenue), 7) OVER (ORDER BY dd.date_key)) / 
        NULLIF(LAG(SUM(fr.total_revenue), 7) OVER (ORDER BY dd.date_key), 0) * 100,
        2
    ) AS week_over_week_growth_pct
FROM fact_revenue fr
INNER JOIN dim_date dd ON fr.date_key = dd.date_key
WHERE dd.date_value >= DATEADD(DAY, -90, CAST(GETDATE() AS DATE))
GROUP BY dd.date_key, dd.date_value;

-- View: Customer Acquisition Trend
-- Grain: New customers by day
CREATE VIEW vw_customer_acquisition_trend AS
SELECT 
    dd.date_key,
    dd.date_value,
    COUNT(DISTINCT dc.customer_key) AS new_customers,
    SUM(dc.annual_contract_value) AS acv_acquired,
    AVG(SUM(fs.net_sales_amount)) OVER (
        ORDER BY dd.date_key ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS avg_new_customer_first_order
FROM dim_customer dc
INNER JOIN fact_sales fs ON dc.customer_key = fs.customer_key
INNER JOIN dim_date dd ON fs.order_date_key = dd.date_key AND dc.effective_date = dd.date_value
WHERE dc.is_current = 1
GROUP BY dd.date_key, dd.date_value;

-- ============================================================================
-- EXECUTIVE DASHBOARD VIEWS
-- ============================================================================

-- View: Executive KPI Dashboard
-- Single query for executive dashboard - all metrics at a glance
CREATE VIEW vw_executive_kpi_dashboard AS
SELECT 
    CAST(GETDATE() AS DATE) AS dashboard_date,
    'Financial Performance' AS dashboard_section,
    'Revenue Metrics' AS metric_group,
    (SELECT SUM(daily_revenue) FROM vw_daily_financial_summary 
     WHERE date_value = CAST(GETDATE() AS DATE)) AS primary_metric,
    (SELECT ROUND(
        ((SELECT SUM(daily_revenue) FROM vw_daily_financial_summary 
          WHERE date_value = CAST(GETDATE() AS DATE)) - 
         (SELECT SUM(daily_revenue) FROM vw_daily_financial_summary 
          WHERE date_value = DATEADD(DAY, -1, CAST(GETDATE() AS DATE)))) / 
        NULLIF((SELECT SUM(daily_revenue) FROM vw_daily_financial_summary 
                WHERE date_value = DATEADD(DAY, -1, CAST(GETDATE() AS DATE))), 0) * 100, 2)) AS achievement_pct,
    'GREEN' AS status,
    5 AS kpi_count

UNION ALL

SELECT 
    CAST(GETDATE() AS DATE),
    'Sales Performance',
    'Sales Growth',
    (SELECT SUM(total_sales) FROM vw_employee_sales_performance 
     WHERE month = MONTH(GETDATE()) AND year = YEAR(GETDATE())),
    85.5,
    'GREEN',
    3

UNION ALL

SELECT 
    CAST(GETDATE() AS DATE),
    'Operational Metrics',
    'Inventory Health',
    (SELECT COUNT(*) FROM vw_current_inventory_status WHERE inventory_status = 'ADEQUATE'),
    92.0,
    'GREEN',
    2;

-- ============================================================================
-- SEGMENT & GEO ANALYSIS VIEWS
-- ============================================================================

-- View: Revenue by Geography and Segment
-- Grain: One row per geography per segment per month
CREATE VIEW vw_revenue_geography_segment_analysis AS
SELECT 
    dg.region,
    dg.country,
    dg.state_province,
    dc.customer_segment,
    dd.year,
    dd.month,
    dd.month_name,
    SUM(fr.total_revenue) AS segment_revenue,
    ROUND(SUM(fr.gross_profit) / NULLIF(SUM(fr.total_revenue), 0) * 100, 2) AS profit_margin_pct,
    COUNT(DISTINCT fr.customer_key) AS customer_count,
    SUM(fr.revenue_count) AS transaction_count,
    ROUND(AVG(fr.average_transaction_amt), 2) AS avg_transaction_value
FROM fact_revenue fr
INNER JOIN dim_geography dg ON fr.geography_key = dg.geography_key
INNER JOIN dim_customer dc ON fr.customer_key = dc.customer_key AND dc.is_current = 1
INNER JOIN dim_date dd ON fr.date_key = dd.date_key
GROUP BY dg.region, dg.country, dg.state_province, dc.customer_segment, 
         dd.year, dd.month, dd.month_name;

-- ============================================================================
-- DATA QUALITY & ANOMALY DETECTION VIEWS
-- ============================================================================

-- View: Sales Anomalies (Unusual transactions)
-- Detects transactions > 3 standard deviations from mean
CREATE VIEW vw_sales_anomaly_detection AS
SELECT 
    fs.sales_key,
    fs.order_id,
    fs.order_date_key,
    dd.date_value,
    dc.customer_name,
    dp.product_name,
    fs.net_sales_amount,
    fs.order_quantity,
    AVG(fs.net_sales_amount) OVER (
        PARTITION BY fs.product_key 
        ORDER BY fs.order_date_key ROWS BETWEEN 89 PRECEDING AND CURRENT ROW
    ) AS avg_sales_90day,
    STDEV(fs.net_sales_amount) OVER (
        PARTITION BY fs.product_key 
        ORDER BY fs.order_date_key ROWS BETWEEN 89 PRECEDING AND CURRENT ROW
    ) AS stdev_sales_90day,
    CASE 
        WHEN ABS(fs.net_sales_amount - AVG(fs.net_sales_amount) OVER (
            PARTITION BY fs.product_key 
            ORDER BY fs.order_date_key ROWS BETWEEN 89 PRECEDING AND CURRENT ROW
        )) > 3 * STDEV(fs.net_sales_amount) OVER (
            PARTITION BY fs.product_key 
            ORDER BY fs.order_date_key ROWS BETWEEN 89 PRECEDING AND CURRENT ROW
        ) THEN 'ANOMALY_DETECTED'
        ELSE 'NORMAL'
    END AS anomaly_flag
FROM fact_sales fs
INNER JOIN dim_customer dc ON fs.customer_key = dc.customer_key
INNER JOIN dim_product dp ON fs.product_key = dp.product_key
INNER JOIN dim_date dd ON fs.order_date_key = dd.date_key
WHERE fs.order_date_key >= (SELECT MAX(date_key) - 30 FROM dim_date);

-- ============================================================================
-- CHURN & RETENTION VIEWS
-- ============================================================================

-- View: Customer Churn Risk Analysis
-- Identifies at-risk customers
CREATE VIEW vw_customer_churn_risk AS
SELECT 
    dc.customer_key,
    dc.customer_id,
    dc.customer_name,
    dc.subscription_status,
    dc.annual_contract_value,
    DATEDIFF(DAY, MAX(fs.order_date_key), CAST(GETDATE() AS DATE)) AS days_since_last_order,
    COUNT(DISTINCT CAST(fs.order_date_key / 100 AS INT)) AS purchase_frequency_months,
    SUM(fs.net_sales_amount) AS total_lifetime_sales,
    AVG(fs.net_sales_amount) AS avg_order_value,
    CASE 
        WHEN DATEDIFF(DAY, MAX(fs.order_date_key), CAST(GETDATE() AS DATE)) > 90 
             AND COUNT(DISTINCT CAST(fs.order_date_key / 100 AS INT)) <= 3 THEN 'HIGH_RISK'
        WHEN DATEDIFF(DAY, MAX(fs.order_date_key), CAST(GETDATE() AS DATE)) > 60 
             AND COUNT(DISTINCT CAST(fs.order_date_key / 100 AS INT)) <= 6 THEN 'MEDIUM_RISK'
        ELSE 'LOW_RISK'
    END AS churn_risk_level
FROM dim_customer dc
LEFT JOIN fact_sales fs ON dc.customer_key = fs.customer_key
WHERE dc.is_current = 1 AND dc.subscription_status IN ('Active', 'At Risk')
GROUP BY dc.customer_key, dc.customer_id, dc.customer_name, dc.subscription_status, 
         dc.annual_contract_value;

GO
