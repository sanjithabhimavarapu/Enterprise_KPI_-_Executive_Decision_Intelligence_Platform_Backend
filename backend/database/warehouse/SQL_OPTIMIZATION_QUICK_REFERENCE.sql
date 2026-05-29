-- ============================================================================
-- SQL OPTIMIZATION QUICK REFERENCE GUIDE
-- Enterprise KPI - Executive Decision Intelligence Platform
-- ============================================================================

/*
CONTENTS:
1. OPTIMIZED VIEWS - High-performance materialized views
2. EXECUTIVE REPORTING PROCEDURES - Pre-built dashboards
3. PERFORMANCE TUNING PROCEDURES - Maintenance & optimization
4. USAGE EXAMPLES - Quick start commands
5. BEST PRACTICES - Performance guidelines
*/

-- ============================================================================
-- 1. OPTIMIZED VIEWS SUMMARY
-- ============================================================================

/*
📊 FINANCIAL VIEWS:
  • vw_daily_financial_summary          - Daily revenue, profit, margins
  • vw_monthly_financial_segment_summary - Monthly breakdown by segment
  • vw_revenue_geography_segment_analysis - Revenue by location & segment

💼 SALES VIEWS:
  • vw_employee_sales_performance       - Sales rep metrics & rankings
  • vw_customer_revenue_analysis        - Customer-level revenue analysis
  • vw_product_category_performance     - Product sales & profitability

📦 OPERATIONAL VIEWS:
  • vw_current_inventory_status         - Real-time inventory health
  • vw_sales_anomaly_detection          - Unusual transaction detection

📈 TREND VIEWS:
  • vw_revenue_trend_90_days            - Revenue trends with moving averages
  • vw_customer_acquisition_trend       - New customer acquisition metrics

⚠️ RISK VIEWS:
  • vw_customer_churn_risk              - At-risk customer identification

🎯 DASHBOARD VIEWS:
  • vw_executive_kpi_dashboard          - All KPIs at a glance
*/

-- ============================================================================
-- 2. EXECUTIVE REPORTING PROCEDURES
-- ============================================================================

/*
📊 FINANCIAL REPORTS:
  • sp_get_daily_financial_report       - Daily financial metrics
  • sp_get_monthly_financial_report     - Monthly detailed analysis

💼 SALES REPORTS:
  • sp_get_top_performers_report        - Sales rankings (by sales/profit/orders)

👥 CUSTOMER REPORTS:
  • sp_get_customer_insights_report     - Revenue & churn risk analysis

📦 OPERATIONAL REPORTS:
  • sp_get_inventory_health_report      - Inventory status & reorder needs
  • sp_get_product_performance_report   - Product category analysis

⚠️ QUALITY REPORTS:
  • sp_get_sales_anomalies_report       - Unusual transactions (fraud detection)
*/

-- ============================================================================
-- 3. PERFORMANCE TUNING PROCEDURES
-- ============================================================================

/*
🔧 INDEX MANAGEMENT:
  • sp_create_optimized_indexes         - Build recommended index strategy
  • sp_find_unused_indexes              - Identify underutilized indexes
  • sp_maintain_index_fragmentation     - Rebuild/reorganize fragmented indexes

📊 STATISTICS & QUERY OPTIMIZATION:
  • sp_update_statistics                - Update table statistics
  • sp_get_expensive_queries            - Top resource-consuming queries
  • sp_analyze_query_plan               - Analyze query execution plans

🔄 MAINTENANCE:
  • sp_refresh_reporting_views          - Refresh materialized views
  • sp_execute_full_maintenance         - Complete maintenance cycle
*/

-- ============================================================================
-- 4. QUICK START EXAMPLES
-- ============================================================================

-- ⚡ QUICK MAINTENANCE (5-10 minutes)
EXEC sp_execute_full_maintenance @p_mode = 'QUICK', @p_verbose = 1;

-- 🔧 STANDARD MAINTENANCE (30-45 minutes)
EXEC sp_execute_full_maintenance @p_mode = 'STANDARD', @p_verbose = 1;

-- 🏗️ COMPREHENSIVE MAINTENANCE (1-2 hours)
EXEC sp_execute_full_maintenance @p_mode = 'COMPREHENSIVE', @p_verbose = 1;

-- ============================================================================
-- FINANCIAL REPORTS
-- ============================================================================

-- Daily Financial Snapshot
EXEC sp_get_daily_financial_report 
    @p_report_date = CAST(GETDATE() AS DATE),
    @p_include_comparison = 1,
    @p_verbose = 1;

-- Monthly Financial Analysis
EXEC sp_get_monthly_financial_report 
    @p_year = 2026,
    @p_month = 5,
    @p_verbose = 1;

-- Monthly Revenue by Segment
SELECT 
    customer_segment,
    month_name,
    ROUND(SUM(month_revenue), 2) AS total_revenue,
    ROUND(AVG(gross_margin_pct), 2) AS avg_margin,
    SUM(unique_customers) AS total_customers
FROM vw_monthly_financial_segment_summary
WHERE year = 2026 AND month = 5
GROUP BY customer_segment, month_name
ORDER BY total_revenue DESC;

-- ============================================================================
-- SALES ANALYTICS
-- ============================================================================

-- Top 10 Sales Performers (Current Month)
EXEC sp_get_top_performers_report 
    @p_metric = 'Sales',
    @p_limit = 10,
    @p_year = 2026,
    @p_month = 5;

-- Top 10 by Profit
EXEC sp_get_top_performers_report 
    @p_metric = 'Profit',
    @p_limit = 10;

-- Sales Performance by Category
SELECT TOP 20
    product_category,
    product_subcategory,
    total_orders,
    total_units_sold,
    ROUND(total_sales, 2) AS total_sales,
    ROUND(total_profit, 2) AS total_profit,
    ROUND(profit_margin_pct, 2) AS margin_pct
FROM vw_product_category_performance
WHERE year = 2026 AND month = 5
ORDER BY total_sales DESC;

-- Sales Trends (Last 30 Days)
SELECT 
    date_value,
    ROUND(daily_revenue, 2) AS daily_revenue,
    ROUND(revenue_7day_avg, 2) AS avg_7day,
    ROUND(day_over_day_growth_pct, 2) AS dod_growth_pct,
    ROUND(week_over_week_growth_pct, 2) AS wow_growth_pct
FROM vw_revenue_trend_90_days
WHERE date_value >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
ORDER BY date_value DESC;

-- ============================================================================
-- CUSTOMER INTELLIGENCE
-- ============================================================================

-- Customer Insights Report
EXEC sp_get_customer_insights_report 
    @p_segment = 'Enterprise',
    @p_limit = 20,
    @p_include_churn_risk = 1;

-- Top Revenue Customers
SELECT TOP 20
    customer_name,
    customer_segment,
    region,
    ROUND(monthly_revenue, 2) AS monthly_revenue,
    ROUND(monthly_profit, 2) AS monthly_profit,
    ROUND(profit_margin_pct, 2) AS margin_pct,
    monthly_orders,
    annual_contract_value,
    customer_lifetime_value
FROM vw_customer_revenue_analysis
WHERE YEAR(GETDATE()) = year AND MONTH(GETDATE()) = month
ORDER BY monthly_revenue DESC;

-- Churn Risk Assessment
SELECT 
    customer_name,
    churn_risk_level,
    days_since_last_order,
    purchase_frequency_months,
    ROUND(total_lifetime_sales, 2) AS lifetime_value,
    ROUND(avg_order_value, 2) AS avg_order_value
FROM vw_customer_churn_risk
WHERE subscription_status IN ('Active', 'At Risk')
    AND churn_risk_level IN ('HIGH_RISK', 'MEDIUM_RISK')
ORDER BY days_since_last_order DESC;

-- ============================================================================
-- OPERATIONAL METRICS
-- ============================================================================

-- Inventory Health Report
EXEC sp_get_inventory_health_report 
    @p_include_low_stock = 1,
    @p_include_overstock = 1;

-- Products Needing Reorder
SELECT 
    product_name,
    warehouse_location_id,
    current_inventory,
    reorder_point,
    lead_time_days,
    action_required
FROM vw_current_inventory_status
WHERE inventory_status IN ('LOW_STOCK', 'REORDER NEEDED')
ORDER BY current_inventory ASC;

-- ============================================================================
-- DATA QUALITY & ANOMALIES
-- ============================================================================

-- Sales Anomalies Report
EXEC sp_get_sales_anomalies_report 
    @p_severity = 'HIGH',
    @p_limit = 100;

-- Detect Unusual Transactions
SELECT 
    order_id,
    date_value,
    customer_name,
    product_name,
    ROUND(net_sales_amount, 2) AS transaction_amount,
    ROUND(avg_sales_90day, 2) AS avg_amount,
    ROUND(z_score, 2) AS z_score,
    severity_level
FROM vw_sales_anomaly_detection
WHERE anomaly_flag = 'ANOMALY_DETECTED'
    AND z_score > 2
ORDER BY z_score DESC;

-- ============================================================================
-- PERFORMANCE OPTIMIZATION
-- ============================================================================

-- Find Expensive Queries
EXEC sp_get_expensive_queries @p_top_n = 20;

-- Find Unused Indexes (Candidates for Removal)
EXEC sp_find_unused_indexes;

-- Update Statistics
EXEC sp_update_statistics @p_table_name = NULL, @p_resample = 0, @p_verbose = 1;

-- Rebuild Fragmented Indexes
EXEC sp_maintain_index_fragmentation @p_fragmentation_threshold = 20, @p_verbose = 1;

-- Create Optimized Indexes
EXEC sp_create_optimized_indexes @p_verbose = 1;

-- ============================================================================
-- 5. BEST PRACTICES & PERFORMANCE GUIDELINES
-- ============================================================================

/*
✅ PERFORMANCE BEST PRACTICES:

1. SCHEDULED MAINTENANCE
   - Run QUICK maintenance daily (after ETL completion)
   - Run STANDARD maintenance weekly (e.g., Sunday nights)
   - Run COMPREHENSIVE maintenance monthly

2. INDEX STRATEGY
   - Use composite indexes on FK + date + status columns
   - Include frequently accessed measures in index INCLUDE clauses
   - Set FILLFACTOR=90 for frequently updated tables
   - Set FILLFACTOR=95 for dimension tables (rarely updated)

3. STATISTICS MAINTENANCE
   - Update statistics after major data loads (sp_update_statistics)
   - Use RESAMPLE for comprehensive updates (monthly)
   - Use default update (FULLSCAN) for regular maintenance (daily)

4. VIEW USAGE
   - Use materialized view approach for frequently accessed reports
   - Aggregate views by date, segment, geography to reduce scans
   - Use window functions (AVG OVER, LAG) for trend calculations

5. QUERY OPTIMIZATION
   - Always filter by date_key early in WHERE clause
   - Use SUM with CASE instead of multiple UNION queries
   - Leverage indexed views for complex aggregations
   - Use JOIN hints only when query plans are suboptimal

6. MONITORING
   - Monitor expensive queries (sp_get_expensive_queries) weekly
   - Check index fragmentation (sp_find_unused_indexes) monthly
   - Track query execution time after schema changes

7. DATA QUALITY
   - Run anomaly detection reports (sp_get_sales_anomalies_report) daily
   - Investigate transactions with z_score > 3
   - Archive false positives for ML model training

8. REFRESH SCHEDULE
   Daily (Post-ETL):
     - sp_update_statistics (quick mode)
     - sp_refresh_reporting_views

   Weekly (Sunday night):
     - sp_execute_full_maintenance (STANDARD mode)
     - sp_find_unused_indexes

   Monthly (1st of month):
     - sp_execute_full_maintenance (COMPREHENSIVE mode)
     - Review sp_get_expensive_queries

EXPECTED PERFORMANCE METRICS:
   • vw_daily_financial_summary: < 1 second
   • vw_monthly_financial_segment_summary: < 2 seconds
   • sp_get_monthly_financial_report: < 5 seconds
   • sp_get_customer_insights_report: < 10 seconds
   • sp_execute_full_maintenance (QUICK): 5-10 minutes
   • sp_execute_full_maintenance (STANDARD): 30-45 minutes
   • sp_execute_full_maintenance (COMPREHENSIVE): 1-2 hours
*/

-- ============================================================================
-- SCHEDULING RECOMMENDATIONS
-- ============================================================================

/*
MAINTENANCE JOBS TO SCHEDULE:

1. DAILY (After ETL Completion - e.g., 6 AM)
   EXEC sp_update_statistics @p_table_name = NULL, @p_resample = 0, @p_verbose = 1;
   EXEC sp_refresh_reporting_views @p_verbose = 1;

2. WEEKLY (Sunday 10 PM - Low activity window)
   EXEC sp_execute_full_maintenance @p_mode = 'STANDARD', @p_verbose = 1;

3. MONTHLY (1st of month, 1 AM)
   EXEC sp_execute_full_maintenance @p_mode = 'COMPREHENSIVE', @p_verbose = 1;
   EXEC sp_find_unused_indexes;

4. QUARTERLY (Review expensive queries)
   EXEC sp_get_expensive_queries @p_top_n = 30;
   -- Review and optimize top 10 queries
*/

-- ============================================================================
-- TROUBLESHOOTING QUERIES
-- ============================================================================

-- Check Current Running Queries
SELECT 
    session_id,
    login_name,
    host_name,
    program_name,
    cpu_time,
    memory_usage,
    status
FROM sys.dm_exec_sessions
WHERE session_id > 50
ORDER BY cpu_time DESC;

-- Check Current Blocking
SELECT 
    blocking_session_id,
    session_id,
    wait_duration_ms,
    wait_type,
    last_wait_type
FROM sys.dm_exec_requests
WHERE blocking_session_id > 0;

-- Check Table Sizes
SELECT 
    OBJECT_NAME(i.object_id) AS table_name,
    ROUND(SUM(s.used_page_count) * 8.0 / 1024, 2) AS used_mb,
    ROUND(SUM(s.total_page_count) * 8.0 / 1024, 2) AS total_mb
FROM sys.dm_db_partition_stats s
INNER JOIN sys.indexes i ON s.object_id = i.object_id AND s.index_id = i.index_id
WHERE database_id = DB_ID()
GROUP BY i.object_id
ORDER BY SUM(s.used_page_count) DESC;

-- Check Last Index Statistics Update
SELECT 
    OBJECT_NAME(object_id) AS table_name,
    name AS index_name,
    STATS_DATE(object_id, index_id) AS last_update
FROM sys.indexes
WHERE database_id = DB_ID()
ORDER BY STATS_DATE(object_id, index_id);
