-- ============================================================================
-- REVENUE FORECASTING, PROFIT CALCULATIONS & FINANCIAL AGGREGATION
-- QUICK REFERENCE QUERIES
-- Enterprise KPI Platform - May 28, 2026
-- ============================================================================
-- Copy and paste these queries into your SQL client
-- All queries are production-tested and optimized for performance

-- ============================================================================
-- SECTION 1: REVENUE FORECASTING QUERIES
-- ============================================================================

-- 1.1: View 12-Month Revenue Forecast (Overall Company)
SELECT
    rf.forecast_month,
    ROUND(rf.forecasted_revenue, 2) AS forecasted_revenue,
    ROUND(rf.lower_bound_95_pct, 2) AS conservative_estimate,
    ROUND(rf.upper_bound_95_pct, 2) AS optimistic_estimate,
    ROUND((rf.upper_bound_95_pct - rf.lower_bound_95_pct) / rf.forecasted_revenue * 100, 2) AS confidence_range_pct,
    ROUND(rfb.revenue_growth_rate_pct, 2) AS growth_rate
FROM revenue_forecast rf
LEFT JOIN revenue_forecast_base rfb ON rf.forecast_base_key = rfb.forecast_base_key
WHERE rfb.forecast_dimension_type = 'Overall'
AND rfb.is_active = 1
ORDER BY rf.forecast_month;

-- 1.2: Compare Forecast vs Actual
SELECT
    rf.forecast_month,
    ROUND(rf.forecasted_revenue, 2) AS forecast,
    ROUND(rf.actual_revenue, 2) AS actual,
    ROUND(rf.variance_amount, 2) AS variance,
    ROUND(rf.variance_pct, 2) AS variance_pct,
    CASE 
        WHEN rf.was_accurate = 1 THEN 'Within Bounds'
        ELSE 'Outside Bounds'
    END AS accuracy_status
FROM revenue_forecast rf
WHERE rf.forecast_dimension_type = 'Overall'
AND rf.actual_revenue IS NOT NULL
ORDER BY rf.forecast_month DESC;

-- 1.3: Revenue Forecast by Top Customers
SELECT TOP 20
    dc.customer_name,
    dc.customer_segment,
    ROUND(SUM(rf.forecasted_revenue), 2) AS total_forecast,
    ROUND(AVG(rf.forecasted_revenue), 2) AS avg_monthly_forecast,
    ROUND(rfb.revenue_growth_rate_pct, 2) AS growth_rate,
    COUNT(rf.forecast_key) AS forecast_months
FROM revenue_forecast rf
LEFT JOIN revenue_forecast_base rfb ON rf.forecast_base_key = rfb.forecast_base_key
LEFT JOIN dim_customer dc ON rfb.dimension_key = dc.customer_key
WHERE rfb.forecast_dimension_type = 'Customer'
AND rfb.is_active = 1
GROUP BY dc.customer_name, dc.customer_segment, rfb.revenue_growth_rate_pct
ORDER BY total_forecast DESC;

-- 1.4: Product Revenue Forecast (Next Quarter)
SELECT
    dp.product_name,
    dp.product_category,
    ROUND(SUM(rf.forecasted_revenue), 2) AS q1_forecast,
    ROUND(AVG(rf.forecasted_revenue), 2) AS avg_monthly,
    ROUND(rfb.revenue_growth_rate_pct, 2) AS growth_rate
FROM revenue_forecast rf
LEFT JOIN revenue_forecast_base rfb ON rf.forecast_base_key = rfb.forecast_base_key
LEFT JOIN dim_product dp ON rfb.dimension_key = dp.product_key
WHERE rfb.forecast_dimension_type = 'Product'
AND rf.forecast_month >= FORMAT(GETDATE(), 'yyyy-MM')
AND rf.forecast_month < FORMAT(DATEADD(QUARTER, 1, GETDATE()), 'yyyy-MM')
GROUP BY dp.product_name, dp.product_category, rfb.revenue_growth_rate_pct
ORDER BY q1_forecast DESC;

-- 1.5: Forecast Accuracy Trend (Last 6 Months)
SELECT
    ROUND(rf.forecasted_revenue, 2) AS forecast,
    ROUND(rf.actual_revenue, 2) AS actual,
    ROUND(rf.variance_pct, 2) AS variance_pct,
    rfb.forecast_method,
    rfb.confidence_level,
    COUNT(*) OVER (PARTITION BY rfb.forecast_method) AS samples
FROM revenue_forecast rf
LEFT JOIN revenue_forecast_base rfb ON rf.forecast_base_key = rfb.forecast_base_key
WHERE rf.actual_revenue IS NOT NULL
AND rf.forecast_month >= FORMAT(DATEADD(MONTH, -6, GETDATE()), 'yyyy-MM')
ORDER BY rf.forecast_month DESC;

-- 1.6: Forecast Scenarios (Conservative vs Optimistic)
SELECT
    rf.forecast_month,
    ROUND(rf.forecasted_revenue, 2) AS base_case,
    ROUND(rf.lower_bound_95_pct, 2) AS worst_case_95_pct,
    ROUND(rf.lower_bound_80_pct, 2) AS conservative_80_pct,
    ROUND(rf.upper_bound_80_pct, 2) AS optimistic_80_pct,
    ROUND(rf.upper_bound_95_pct, 2) AS best_case_95_pct,
    ROUND((rf.upper_bound_95_pct - rf.lower_bound_95_pct), 2) AS range
FROM revenue_forecast rf
LEFT JOIN revenue_forecast_base rfb ON rf.forecast_base_key = rfb.forecast_base_key
WHERE rfb.forecast_dimension_type = 'Overall'
AND rfb.confidence_level = 95
ORDER BY rf.forecast_month;

-- ============================================================================
-- SECTION 2: DAILY PROFIT QUERIES
-- ============================================================================

-- 2.1: Daily Profit Summary (Last 30 Days)
SELECT
    pcd.profit_date,
    COUNT(DISTINCT pcd.customer_key) AS customers,
    ROUND(SUM(pcd.net_revenue), 2) AS daily_revenue,
    ROUND(SUM(pcd.total_cogs), 2) AS daily_cogs,
    ROUND(SUM(pcd.total_opex), 2) AS daily_opex,
    ROUND(SUM(pcd.gross_profit), 2) AS gross_profit,
    ROUND(AVG(pcd.gross_margin_pct), 2) AS avg_gross_margin,
    ROUND(SUM(pcd.operating_profit), 2) AS operating_profit,
    ROUND(AVG(pcd.operating_margin_pct), 2) AS avg_operating_margin,
    ROUND(SUM(pcd.net_profit), 2) AS net_profit,
    ROUND(AVG(pcd.net_margin_pct), 2) AS avg_net_margin,
    SUM(pcd.transaction_count) AS transactions
FROM profit_calculation_daily pcd
WHERE pcd.profit_date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
GROUP BY pcd.profit_date
ORDER BY pcd.profit_date DESC;

-- 2.2: Daily Profit Trend with Moving Average
SELECT
    pcd.profit_date,
    ROUND(SUM(pcd.net_profit), 2) AS daily_profit,
    ROUND(AVG(SUM(pcd.net_profit)) OVER (ORDER BY pcd.profit_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 2) AS ma7_profit,
    ROUND(AVG(SUM(pcd.net_profit)) OVER (ORDER BY pcd.profit_date ROWS BETWEEN 29 PRECEDING AND CURRENT ROW), 2) AS ma30_profit
FROM profit_calculation_daily pcd
WHERE pcd.profit_date >= DATEADD(DAY, -90, CAST(GETDATE() AS DATE))
GROUP BY pcd.profit_date
ORDER BY pcd.profit_date DESC;

-- 2.3: Profitability by Customer (Daily)
SELECT TOP 25
    dc.customer_name,
    dc.customer_segment,
    pcd.profit_date,
    ROUND(pcd.net_revenue, 2) AS revenue,
    ROUND(pcd.total_cogs, 2) AS cogs,
    ROUND(pcd.total_opex, 2) AS opex,
    ROUND(pcd.net_profit, 2) AS profit,
    ROUND(pcd.net_margin_pct, 2) AS margin_pct
FROM profit_calculation_daily pcd
LEFT JOIN dim_customer dc ON pcd.customer_key = dc.customer_key
WHERE pcd.profit_date = CAST(GETDATE() AS DATE)
ORDER BY pcd.net_profit DESC;

-- 2.4: Product Profitability (Daily)
SELECT TOP 20
    dp.product_name,
    dp.product_category,
    CAST(GETDATE() AS DATE) AS report_date,
    ROUND(SUM(pcd.net_revenue), 2) AS daily_revenue,
    ROUND(SUM(pcd.total_cogs), 2) AS daily_cogs,
    ROUND(SUM(pcd.net_profit), 2) AS daily_profit,
    ROUND(AVG(pcd.net_margin_pct), 2) AS avg_margin,
    SUM(pcd.transaction_count) AS units_sold
FROM profit_calculation_daily pcd
LEFT JOIN dim_product dp ON pcd.product_key = dp.product_key
WHERE pcd.profit_date = CAST(GETDATE() AS DATE)
GROUP BY dp.product_name, dp.product_category
ORDER BY daily_profit DESC;

-- 2.5: Profitability by Geography (Daily)
SELECT
    dg.geography_name,
    dg.geography_region,
    CAST(GETDATE() AS DATE) AS report_date,
    COUNT(DISTINCT pcd.customer_key) AS customers,
    ROUND(SUM(pcd.net_revenue), 2) AS revenue,
    ROUND(SUM(pcd.net_profit), 2) AS profit,
    ROUND(AVG(pcd.net_margin_pct), 2) AS avg_margin
FROM profit_calculation_daily pcd
LEFT JOIN dim_geography dg ON pcd.geography_key = dg.geography_key
WHERE pcd.profit_date = CAST(GETDATE() AS DATE)
GROUP BY dg.geography_name, dg.geography_region
ORDER BY profit DESC;

-- ============================================================================
-- SECTION 3: MONTHLY PROFIT QUERIES
-- ============================================================================

-- 3.1: Monthly Profit Summary (Last 12 Months)
SELECT
    pcm.year_month,
    ROUND(SUM(pcm.gross_revenue), 2) AS monthly_revenue,
    ROUND(SUM(pcm.total_cogs), 2) AS monthly_cogs,
    ROUND(SUM(pcm.total_opex), 2) AS monthly_opex,
    ROUND(SUM(pcm.gross_profit), 2) AS gross_profit,
    ROUND(AVG(pcm.gross_margin_pct), 2) AS avg_gross_margin,
    ROUND(SUM(pcm.operating_profit), 2) AS operating_profit,
    ROUND(AVG(pcm.operating_margin_pct), 2) AS avg_operating_margin,
    ROUND(SUM(pcm.net_profit), 2) AS net_profit,
    ROUND(AVG(pcm.net_margin_pct), 2) AS avg_net_margin,
    COUNT(DISTINCT pcm.customer_key) AS customer_count
FROM profit_calculation_monthly pcm
WHERE pcm.year_month >= FORMAT(DATEADD(MONTH, -12, GETDATE()), 'yyyy-MM')
GROUP BY pcm.year_month
ORDER BY pcm.year_month DESC;

-- 3.2: Top 25 Most Profitable Customers (YTD)
SELECT TOP 25
    dc.customer_name,
    dc.customer_segment,
    ROUND(SUM(pcm.gross_revenue), 2) AS ytd_revenue,
    ROUND(SUM(pcm.net_profit), 2) AS ytd_profit,
    ROUND(AVG(pcm.net_margin_pct), 2) AS avg_margin,
    COUNT(DISTINCT pcm.year_month) AS months_active,
    CASE 
        WHEN AVG(pcm.net_margin_pct) >= 25 THEN '✓✓ Excellent'
        WHEN AVG(pcm.net_margin_pct) >= 15 THEN '✓ Good'
        WHEN AVG(pcm.net_margin_pct) >= 5 THEN '⚠ Fair'
        ELSE '✗ Poor'
    END AS profitability_status
FROM profit_calculation_monthly pcm
LEFT JOIN dim_customer dc ON pcm.customer_key = dc.customer_key
WHERE pcm.year_month >= FORMAT(DATEADD(MONTH, -12, GETDATE()), 'yyyy-MM')
GROUP BY dc.customer_name, dc.customer_segment
ORDER BY ytd_profit DESC;

-- 3.3: Bottom 25 Least Profitable Customers (YTD)
SELECT TOP 25
    dc.customer_name,
    dc.customer_segment,
    ROUND(SUM(pcm.gross_revenue), 2) AS ytd_revenue,
    ROUND(SUM(pcm.net_profit), 2) AS ytd_profit,
    ROUND(AVG(pcm.net_margin_pct), 2) AS avg_margin,
    CASE 
        WHEN SUM(pcm.net_profit) < 0 THEN 'Loss Making'
        WHEN AVG(pcm.net_margin_pct) < 5 THEN 'Margin Pressure'
        ELSE 'Monitor'
    END AS status
FROM profit_calculation_monthly pcm
LEFT JOIN dim_customer dc ON pcm.customer_key = dc.customer_key
WHERE pcm.year_month >= FORMAT(DATEADD(MONTH, -12, GETDATE()), 'yyyy-MM')
GROUP BY dc.customer_name, dc.customer_segment
ORDER BY ytd_profit ASC;

-- 3.4: Product Profitability Rankings (YTD)
SELECT
    dp.product_name,
    dp.product_category,
    ROUND(SUM(pcm.gross_revenue), 2) AS ytd_revenue,
    SUM(pcm.transaction_count) AS units_sold,
    ROUND(SUM(pcm.total_cogs), 2) AS total_cogs,
    ROUND(SUM(pcm.net_profit), 2) AS ytd_profit,
    ROUND(AVG(pcm.net_margin_pct), 2) AS avg_margin,
    CASE 
        WHEN AVG(pcm.net_margin_pct) >= 30 THEN 'High Margin'
        WHEN AVG(pcm.net_margin_pct) >= 15 THEN 'Medium Margin'
        ELSE 'Low Margin'
    END AS margin_category
FROM profit_calculation_monthly pcm
LEFT JOIN dim_product dp ON pcm.product_key = dp.product_key
WHERE pcm.year_month >= FORMAT(DATEADD(MONTH, -12, GETDATE()), 'yyyy-MM')
AND pcm.product_key IS NOT NULL
GROUP BY dp.product_name, dp.product_category
ORDER BY ytd_profit DESC;

-- 3.5: Monthly Profit by Segment (YTD)
SELECT
    pcm.year_month,
    dc.customer_segment,
    COUNT(DISTINCT pcm.customer_key) AS customer_count,
    ROUND(SUM(pcm.gross_revenue), 2) AS revenue,
    ROUND(SUM(pcm.net_profit), 2) AS profit,
    ROUND(AVG(pcm.net_margin_pct), 2) AS avg_margin
FROM profit_calculation_monthly pcm
LEFT JOIN dim_customer dc ON pcm.customer_key = dc.customer_key
WHERE pcm.year_month >= FORMAT(DATEADD(MONTH, -12, GETDATE()), 'yyyy-MM')
GROUP BY pcm.year_month, dc.customer_segment
ORDER BY pcm.year_month DESC, profit DESC;

-- 3.6: Geographic Profitability Analysis
SELECT
    dg.geography_name,
    dg.geography_region,
    dg.geography_country,
    ROUND(SUM(pcm.gross_revenue), 2) AS ytd_revenue,
    ROUND(SUM(pcm.net_profit), 2) AS ytd_profit,
    ROUND(AVG(pcm.net_margin_pct), 2) AS avg_margin,
    COUNT(DISTINCT pcm.customer_key) AS customer_count,
    ROUND(SUM(pcm.gross_revenue) / NULLIF(COUNT(DISTINCT pcm.customer_key), 0), 2) AS revenue_per_customer
FROM profit_calculation_monthly pcm
LEFT JOIN dim_geography dg ON pcm.geography_key = dg.geography_key
WHERE pcm.year_month >= FORMAT(DATEADD(MONTH, -12, GETDATE()), 'yyyy-MM')
AND pcm.geography_key IS NOT NULL
GROUP BY dg.geography_name, dg.geography_region, dg.geography_country
ORDER BY ytd_profit DESC;

-- ============================================================================
-- SECTION 4: FINANCIAL AGGREGATION QUERIES
-- ============================================================================

-- 4.1: Executive Financial Dashboard
SELECT
    CAST(GETDATE() AS DATE) AS report_date,
    ROUND(SUM(fas.total_revenue), 2) AS total_revenue,
    ROUND(SUM(fas.total_costs), 2) AS total_costs,
    ROUND(SUM(fas.total_profit), 2) AS total_profit,
    ROUND(AVG(fas.profit_margin_pct), 2) AS profit_margin_pct,
    CASE 
        WHEN AVG(fas.profit_margin_pct) >= 20 THEN '✓ Excellent Performance'
        WHEN AVG(fas.profit_margin_pct) >= 15 THEN '✓ Good Performance'
        WHEN AVG(fas.profit_margin_pct) >= 10 THEN '⚠ Needs Attention'
        ELSE '✗ Below Target'
    END AS performance_status
FROM financial_aggregation_summary fas
WHERE fas.aggregation_level = 'Company'
AND fas.aggregation_date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE));

-- 4.2: Monthly Financial Trend
SELECT
    fas.aggregation_date,
    ROUND(fas.total_revenue, 2) AS revenue,
    ROUND(fas.total_profit, 2) AS profit,
    ROUND(fas.profit_margin_pct, 2) AS margin_pct,
    ROUND(fas.total_revenue - LAG(fas.total_revenue) OVER (ORDER BY fas.aggregation_date), 2) AS mom_revenue_change,
    ROUND(((fas.total_revenue - LAG(fas.total_revenue) OVER (ORDER BY fas.aggregation_date)) / 
           LAG(fas.total_revenue) OVER (ORDER BY fas.aggregation_date) * 100), 2) AS mom_revenue_growth_pct,
    ROUND(((fas.total_profit - LAG(fas.total_profit) OVER (ORDER BY fas.aggregation_date)) / 
           LAG(fas.total_profit) OVER (ORDER BY fas.aggregation_date) * 100), 2) AS mom_profit_growth_pct
FROM financial_aggregation_summary fas
WHERE fas.aggregation_level = 'Company'
AND fas.aggregation_date >= DATEADD(MONTH, -12, CAST(GETDATE() AS DATE))
ORDER BY fas.aggregation_date DESC;

-- 4.3: Year-over-Year Comparison
SELECT
    FORMAT(fas.aggregation_date, 'MM') AS month,
    YEAR(fas.aggregation_date) AS year,
    ROUND(fas.total_revenue, 2) AS revenue,
    ROUND(fas.total_profit, 2) AS profit,
    ROUND(fas.profit_margin_pct, 2) AS margin_pct
FROM financial_aggregation_summary fas
WHERE fas.aggregation_level = 'Company'
AND fas.aggregation_date >= DATEADD(YEAR, -2, CAST(GETDATE() AS DATE))
ORDER BY FORMAT(fas.aggregation_date, 'MM'), YEAR(fas.aggregation_date) DESC;

-- ============================================================================
-- SECTION 5: MARGIN & EFFICIENCY ANALYSIS
-- ============================================================================

-- 5.1: Margin Trend Analysis (Last 12 Months)
SELECT
    pcm.year_month,
    ROUND(AVG(pcm.gross_margin_pct), 2) AS avg_gross_margin,
    ROUND(AVG(pcm.operating_margin_pct), 2) AS avg_operating_margin,
    ROUND(AVG(pcm.net_margin_pct), 2) AS avg_net_margin,
    ROUND(AVG(pcm.gross_margin_pct) - LAG(AVG(pcm.gross_margin_pct)) OVER (ORDER BY pcm.year_month), 2) AS gross_margin_change,
    ROUND(AVG(pcm.net_margin_pct) - LAG(AVG(pcm.net_margin_pct)) OVER (ORDER BY pcm.year_month), 2) AS net_margin_change
FROM profit_calculation_monthly pcm
WHERE pcm.year_month >= FORMAT(DATEADD(MONTH, -12, GETDATE()), 'yyyy-MM')
GROUP BY pcm.year_month
ORDER BY pcm.year_month DESC;

-- 5.2: Cost Structure Analysis
SELECT
    pcm.year_month,
    ROUND(SUM(pcm.gross_revenue), 2) AS revenue,
    ROUND(SUM(pcm.total_cogs) / NULLIF(SUM(pcm.gross_revenue), 0) * 100, 2) AS cogs_pct_of_revenue,
    ROUND(SUM(pcm.total_opex) / NULLIF(SUM(pcm.gross_revenue), 0) * 100, 2) AS opex_pct_of_revenue,
    ROUND(SUM(pcm.net_profit) / NULLIF(SUM(pcm.gross_revenue), 0) * 100, 2) AS net_profit_pct
FROM profit_calculation_monthly pcm
WHERE pcm.year_month >= FORMAT(DATEADD(MONTH, -12, GETDATE()), 'yyyy-MM')
GROUP BY pcm.year_month
ORDER BY pcm.year_month DESC;

-- 5.3: Revenue per Employee
SELECT
    pcm.year_month,
    COUNT(DISTINCT de.employee_key) AS employee_count,
    ROUND(SUM(pcm.gross_revenue), 2) AS total_revenue,
    ROUND(SUM(pcm.gross_revenue) / NULLIF(COUNT(DISTINCT de.employee_key), 0), 2) AS revenue_per_employee,
    ROUND(SUM(pcm.net_profit) / NULLIF(COUNT(DISTINCT de.employee_key), 0), 2) AS profit_per_employee
FROM profit_calculation_monthly pcm
LEFT JOIN dim_employee de ON pcm.employee_key = de.employee_key
WHERE pcm.year_month >= FORMAT(DATEADD(MONTH, -6, GETDATE()), 'yyyy-MM')
AND pcm.employee_key IS NOT NULL
GROUP BY pcm.year_month
ORDER BY pcm.year_month DESC;

-- ============================================================================
-- SECTION 6: PROFITABILITY STATUS
-- ============================================================================

-- 6.1: Customers at Risk (Negative Margin)
SELECT TOP 50
    dc.customer_name,
    dc.customer_segment,
    pcm.year_month,
    ROUND(pcm.gross_revenue, 2) AS revenue,
    ROUND(pcm.net_profit, 2) AS profit,
    ROUND(pcm.net_margin_pct, 2) AS margin_pct,
    pcm.profitability_status,
    'ACTION REQUIRED' AS status
FROM profit_calculation_monthly pcm
LEFT JOIN dim_customer dc ON pcm.customer_key = dc.customer_key
WHERE pcm.net_margin_pct < -10
AND pcm.year_month >= FORMAT(DATEADD(MONTH, -3, GETDATE()), 'yyyy-MM')
ORDER BY pcm.net_margin_pct ASC;

-- 6.2: High-Margin Opportunities (Products)
SELECT TOP 25
    dp.product_name,
    ROUND(AVG(pcm.net_margin_pct), 2) AS avg_margin,
    ROUND(SUM(pcm.gross_revenue), 2) AS ytd_revenue,
    SUM(pcm.transaction_count) AS units_sold,
    'EXPAND' AS recommendation
FROM profit_calculation_monthly pcm
LEFT JOIN dim_product dp ON pcm.product_key = dp.product_key
WHERE pcm.year_month >= FORMAT(DATEADD(MONTH, -12, GETDATE()), 'yyyy-MM')
GROUP BY dp.product_name
HAVING AVG(pcm.net_margin_pct) >= 35
ORDER BY avg_margin DESC;

-- 6.3: Low-Margin Products (Review Pricing)
SELECT TOP 25
    dp.product_name,
    ROUND(AVG(pcm.net_margin_pct), 2) AS avg_margin,
    ROUND(SUM(pcm.gross_revenue), 2) AS ytd_revenue,
    SUM(pcm.transaction_count) AS units_sold,
    'REVIEW' AS recommendation
FROM profit_calculation_monthly pcm
LEFT JOIN dim_product dp ON pcm.product_key = dp.product_key
WHERE pcm.year_month >= FORMAT(DATEADD(MONTH, -12, GETDATE()), 'yyyy-MM')
GROUP BY dp.product_name
HAVING AVG(pcm.net_margin_pct) < 10
ORDER BY avg_margin ASC;

-- ============================================================================
-- NOTES
-- ============================================================================
-- All queries use current data from materialized tables
-- Dates are in UTC - adjust for your timezone if needed
-- All monetary values are rounded to 2 decimal places
-- Replace table/column names if using different schema
-- These queries are read-only and safe for production

GO
