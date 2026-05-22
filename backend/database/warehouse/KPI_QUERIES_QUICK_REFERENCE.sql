# KPI Optimization - Quick Reference Guide

## 🚀 Quick Start

### 1. Run Daily KPI Refresh
```sql
-- Execute after ETL completes
EXEC sp_refresh_all_kpi_metrics @p_metric_date = CAST(GETDATE() AS DATE), @p_verbose = 1;
```

**Expected Results**: 
- Completes in 70-115 seconds
- Populates 8 aggregation tables
- Calculates 25+ KPIs
- Updates executive views

---

## 📊 Executive Dashboards

### Executive KPI Dashboard (All KPIs at a Glance)
```sql
SELECT * FROM vw_executive_kpi_dashboard
WHERE dashboard_date = CAST(GETDATE() AS DATE)
ORDER BY dashboard_section, metric_group;
```

**Output Columns**: `dashboard_date`, `dashboard_section`, `metric_group`, `kpi_count`, `primary_metric`, `achievement_pct`, `status`

---

## 💰 Financial KPI Queries

### Daily Revenue Summary
```sql
SELECT 
    kpi_date,
    kpi_value AS total_revenue,
    achievement_pct,
    status_flag
FROM kpi_daily_summary
WHERE kpi_name = 'Total Revenue'
AND kpi_date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
ORDER BY kpi_date DESC;
```

### Financial Performance by Segment
```sql
SELECT 
    metric_date,
    segment_key,
    ROUND(SUM(total_revenue), 2) AS revenue,
    ROUND(AVG(gross_profit_margin_pct), 2) AS gross_margin,
    ROUND(AVG(operating_margin_pct), 2) AS operating_margin
FROM financial_metrics_summary
WHERE metric_date >= DATEADD(DAY, -90, CAST(GETDATE() AS DATE))
GROUP BY metric_date, segment_key
ORDER BY metric_date DESC;
```

### Gross Profit Margin Trend
```sql
SELECT 
    kpi_date,
    kpi_value AS margin_pct,
    target_value,
    CASE 
        WHEN status_flag = 'GREEN' THEN '✓ On Target'
        WHEN status_flag = 'YELLOW' THEN '⚠ At Risk'
        ELSE '✗ Below Target'
    END AS status
FROM kpi_daily_summary
WHERE kpi_name = 'Gross Profit Margin'
AND kpi_date >= DATEADD(DAY, -60, CAST(GETDATE() AS DATE))
ORDER BY kpi_date DESC;
```

### Revenue by Geography
```sql
SELECT 
    fms.metric_date,
    dg.region,
    dg.country,
    ROUND(SUM(fms.total_revenue), 2) AS revenue,
    ROUND(AVG(fms.gross_profit_margin_pct), 2) AS margin
FROM financial_metrics_summary fms
LEFT JOIN dim_geography dg ON fms.geography_key = dg.geography_key AND dg.is_current = 1
WHERE fms.metric_date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
GROUP BY fms.metric_date, dg.region, dg.country
ORDER BY fms.metric_date DESC, revenue DESC;
```

---

## 📈 Sales KPI Queries

### Sales Growth Tracking
```sql
SELECT 
    kpi_date,
    'Sales Growth YoY' AS metric,
    kpi_value AS growth_pct,
    target_value AS target,
    achievement_pct,
    status_flag
FROM kpi_daily_summary
WHERE kpi_name = 'Sales Growth Rate (YoY)'
AND kpi_date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
ORDER BY kpi_date DESC;
```

### Sales Performance Optimized View
```sql
SELECT 
    metric_date,
    department,
    SUM(total_orders) AS orders,
    ROUND(SUM(total_sales_amount), 2) AS revenue,
    ROUND(AVG(average_order_value), 2) AS avg_deal_size,
    ROUND(AVG(win_rate_pct), 2) AS win_rate,
    ROUND(AVG(yoy_growth_pct), 2) AS growth_yoy
FROM vw_sales_performance_optimized
WHERE metric_date >= DATEADD(DAY, -90, CAST(GETDATE() AS DATE))
GROUP BY metric_date, department
ORDER BY metric_date DESC;
```

### Sales Rep Leaderboard (Top 10)
```sql
SELECT TOP 10
    de.employee_name,
    SUM(sps.total_sales_amount) AS revenue,
    SUM(sps.total_orders) AS deals,
    ROUND(AVG(sps.average_order_value), 2) AS avg_deal_size,
    SUM(sps.new_customers_count) AS new_customers,
    ROUND(AVG(sps.win_rate_pct), 2) AS win_rate,
    ROUND(AVG(sps.yoy_growth_pct), 2) AS yoy_growth
FROM sales_performance_summary sps
LEFT JOIN dim_employee de ON sps.employee_key = de.employee_key
WHERE sps.metric_date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
GROUP BY de.employee_name, sps.employee_key
ORDER BY revenue DESC;
```

### Pipeline Value by Segment
```sql
SELECT 
    sps.metric_date,
    dc.customer_segment,
    ROUND(SUM(sps.pipeline_value), 2) AS pipeline_value,
    ROUND(SUM(sps.pipeline_value) / SUM(sps.total_sales_amount * 12), 2) AS pipeline_to_monthly_quota
FROM sales_performance_summary sps
LEFT JOIN dim_customer dc ON sps.segment_key = dc.customer_key
WHERE sps.metric_date = CAST(GETDATE() AS DATE)
GROUP BY sps.metric_date, dc.customer_segment
ORDER BY pipeline_value DESC;
```

---

## 👥 Customer Success KPI Queries

### Customer Health Overview
```sql
SELECT 
    metric_date,
    COUNT(DISTINCT customer_key) AS total_customers,
    ROUND(AVG(customer_health_score), 2) AS avg_health,
    ROUND(AVG(nps_score), 2) AS avg_nps,
    SUM(CASE WHEN churn_flag = 1 THEN 1 ELSE 0 END) AS churned,
    ROUND(AVG(retention_rate_pct), 2) AS retention_rate
FROM vw_customer_health_optimized
WHERE metric_date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
GROUP BY metric_date
ORDER BY metric_date DESC;
```

### Churn Risk Customers
```sql
SELECT 
    css.customer_key,
    dc.customer_name,
    dc.customer_segment,
    css.customer_health_score,
    css.nps_score,
    css.current_arr,
    css.engagement_level,
    css.avg_resolution_time_hours
FROM customer_success_summary css
LEFT JOIN dim_customer dc ON css.customer_key = dc.customer_key AND dc.is_current = 1
WHERE css.metric_date = CAST(GETDATE() AS DATE)
AND css.customer_health_score < 50
AND css.churn_flag = 0
ORDER BY css.customer_health_score ASC;
```

### Retention Rate by Segment
```sql
SELECT 
    css.metric_date,
    dc.customer_segment,
    ROUND(AVG(css.retention_rate_pct), 2) AS retention_rate,
    COUNT(DISTINCT css.customer_key) AS customer_count,
    ROUND(SUM(css.current_arr), 2) AS total_arr,
    ROUND(AVG(css.nps_score), 2) AS avg_nps
FROM customer_success_summary css
LEFT JOIN dim_customer dc ON css.segment_key = dc.customer_key AND dc.is_current = 1
WHERE css.metric_date >= DATEADD(DAY, -90, CAST(GETDATE() AS DATE))
GROUP BY css.metric_date, dc.customer_segment
ORDER BY css.metric_date DESC;
```

### Net Revenue Retention (NRR)
```sql
SELECT 
    css.metric_date,
    ROUND(AVG(css.net_revenue_retention_pct), 2) AS nrr,
    COUNT(DISTINCT css.customer_key) AS customers,
    ROUND(SUM(css.expansion_revenue), 2) AS expansion,
    ROUND(SUM(css.churn_revenue), 2) AS churn
FROM customer_success_summary css
WHERE css.metric_date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
GROUP BY css.metric_date
ORDER BY css.metric_date DESC;
```

---

## 🏭 Operational KPI Queries

### Fulfillment Performance
```sql
SELECT 
    metric_date,
    warehouse_location,
    ROUND(AVG(fulfillment_rate_pct), 2) AS fulfillment_rate,
    ROUND(AVG(ontime_delivery_rate_pct), 2) AS ontime_rate,
    ROUND(AVG(avg_fulfillment_days), 1) AS avg_days,
    SUM(orders_received) AS orders
FROM vw_operational_efficiency_optimized
WHERE metric_date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
GROUP BY metric_date, warehouse_location
ORDER BY metric_date DESC;
```

### Quality Metrics Dashboard
```sql
SELECT 
    metric_date,
    ROUND(AVG(defect_rate_pct), 2) AS defect_rate,
    ROUND(AVG(first_pass_yield_pct), 2) AS fpy,
    SUM(total_units_produced) AS units_produced,
    SUM(defective_units) AS defects,
    ROUND(SUM(rework_cost), 2) AS rework_cost
FROM operational_metrics_summary
WHERE metric_date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
GROUP BY metric_date
ORDER BY metric_date DESC;
```

### Inventory Health
```sql
SELECT 
    metric_date,
    warehouse_location,
    ROUND(inventory_value, 2) AS inventory_value,
    inventory_units,
    ROUND(inventory_turnover_ratio, 2) AS turnover_ratio,
    slow_moving_inventory,
    stockout_incidents
FROM operational_metrics_summary
WHERE metric_date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
GROUP BY metric_date, warehouse_location
ORDER BY metric_date DESC;
```

---

## 👨‍💼 HR KPI Queries

### Department Performance
```sql
SELECT 
    hrps.metric_date,
    hrps.department,
    COUNT(DISTINCT hrps.employee_key) AS headcount,
    ROUND(AVG(hrps.productivity_per_employee), 2) AS avg_productivity,
    ROUND(AVG(hrps.engagement_score), 2) AS engagement,
    SUM(CASE WHEN hrps.is_turnover_risk = 1 THEN 1 ELSE 0 END) AS at_risk_count
FROM vw_hr_performance_optimized hrps
WHERE hrps.metric_date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
GROUP BY hrps.metric_date, hrps.department
ORDER BY hrps.metric_date DESC;
```

### Sales Rep Performance
```sql
SELECT 
    hrps.metric_date,
    de.employee_name,
    hrps.job_title,
    hrps.quota_attainment_pct,
    hrps.productivity_per_employee,
    hrps.engagement_score,
    hrps.training_hours_ytd,
    CASE WHEN hrps.is_turnover_risk = 1 THEN 'At Risk' ELSE 'Stable' END AS status
FROM hr_performance_summary hrps
LEFT JOIN dim_employee de ON hrps.employee_key = de.employee_key
WHERE hrps.metric_date = CAST(GETDATE() AS DATE)
AND hrps.job_title LIKE '%Rep%'
ORDER BY hrps.quota_attainment_pct DESC;
```

### Turnover Risk Analysis
```sql
SELECT 
    hrps.metric_date,
    COUNT(DISTINCT hrps.employee_key) AS at_risk_count,
    hrps.department,
    SUM(CASE WHEN hrps.voluntary_turnover_flag = 1 THEN 1 ELSE 0 END) AS voluntary_departures,
    ROUND(AVG(hrps.tenure_months), 1) AS avg_tenure,
    ROUND(AVG(hrps.engagement_score), 2) AS avg_engagement
FROM hr_performance_summary hrps
WHERE hrps.is_turnover_risk = 1
AND hrps.metric_date = CAST(GETDATE() AS DATE)
GROUP BY hrps.metric_date, hrps.department
ORDER BY at_risk_count DESC;
```

---

## 🎯 KPI Status Monitoring

### All KPIs Status Summary
```sql
SELECT 
    kpi_date,
    kpi_category,
    COUNT(*) AS kpi_count,
    SUM(CASE WHEN status_flag = 'GREEN' THEN 1 ELSE 0 END) AS green_count,
    SUM(CASE WHEN status_flag = 'YELLOW' THEN 1 ELSE 0 END) AS yellow_count,
    SUM(CASE WHEN status_flag = 'RED' THEN 1 ELSE 0 END) AS red_count,
    ROUND(AVG(achievement_pct), 2) AS avg_achievement_pct
FROM kpi_daily_summary
WHERE kpi_date >= DATEADD(DAY, -7, CAST(GETDATE() AS DATE))
GROUP BY kpi_date, kpi_category
ORDER BY kpi_date DESC;
```

### KPIs Below Target
```sql
SELECT 
    kpi_date,
    kpi_category,
    kpi_name,
    kpi_value,
    target_value,
    achievement_pct,
    status_flag
FROM kpi_daily_summary
WHERE kpi_date = CAST(GETDATE() AS DATE)
AND status_flag IN ('RED', 'YELLOW')
ORDER BY achievement_pct ASC;
```

### Year-to-Date Performance
```sql
SELECT 
    kpi_name,
    kpi_category,
    SUM(kpi_value) AS ytd_value,
    SUM(target_value) AS ytd_target,
    ROUND((SUM(kpi_value) / NULLIF(SUM(target_value), 0)) * 100, 2) AS ytd_achievement_pct,
    MAX(status_flag) AS status
FROM kpi_daily_summary
WHERE YEAR(kpi_date) = YEAR(GETDATE())
AND kpi_date <= CAST(GETDATE() AS DATE)
GROUP BY kpi_name, kpi_category
ORDER BY kpi_category, ytd_achievement_pct DESC;
```

---

## 🔧 Maintenance & Administration

### Check Last Refresh Time
```sql
SELECT 
    'kpi_daily_summary' AS table_name,
    MAX(dw_update_ts) AS last_refresh
FROM kpi_daily_summary
UNION ALL
SELECT 'financial_metrics_summary', MAX(dw_update_ts) FROM financial_metrics_summary
UNION ALL
SELECT 'sales_performance_summary', MAX(dw_update_ts) FROM sales_performance_summary
UNION ALL
SELECT 'customer_success_summary', MAX(dw_update_ts) FROM customer_success_summary
UNION ALL
SELECT 'operational_metrics_summary', MAX(dw_update_ts) FROM operational_metrics_summary
UNION ALL
SELECT 'hr_performance_summary', MAX(dw_update_ts) FROM hr_performance_summary
ORDER BY last_refresh DESC;
```

### Table Row Counts
```sql
SELECT 
    'kpi_daily_summary' AS table_name,
    COUNT(*) AS row_count,
    ROUND(CAST(SUM(DATALENGTH(ks)) AS FLOAT) / 1024 / 1024, 2) AS size_mb
FROM kpi_daily_summary ks
UNION ALL
SELECT 'financial_metrics_summary', COUNT(*), ROUND(CAST(SUM(DATALENGTH(fms)) AS FLOAT) / 1024 / 1024, 2)
FROM financial_metrics_summary fms
UNION ALL
SELECT 'sales_performance_summary', COUNT(*), ROUND(CAST(SUM(DATALENGTH(sps)) AS FLOAT) / 1024 / 1024, 2)
FROM sales_performance_summary sps
UNION ALL
SELECT 'customer_success_summary', COUNT(*), ROUND(CAST(SUM(DATALENGTH(css)) AS FLOAT) / 1024 / 1024, 2)
FROM customer_success_summary css
UNION ALL
SELECT 'operational_metrics_summary', COUNT(*), ROUND(CAST(SUM(DATALENGTH(ops)) AS FLOAT) / 1024 / 1024, 2)
FROM operational_metrics_summary ops
UNION ALL
SELECT 'hr_performance_summary', COUNT(*), ROUND(CAST(SUM(DATALENGTH(hrps)) AS FLOAT) / 1024 / 1024, 2)
FROM hr_performance_summary hrps
ORDER BY table_name;
```

### Rebuild Indexes
```sql
-- Rebuild all indexes on KPI tables
ALTER INDEX ALL ON kpi_daily_summary REBUILD;
ALTER INDEX ALL ON financial_metrics_summary REBUILD;
ALTER INDEX ALL ON sales_performance_summary REBUILD;
ALTER INDEX ALL ON customer_success_summary REBUILD;
ALTER INDEX ALL ON operational_metrics_summary REBUILD;
ALTER INDEX ALL ON hr_performance_summary REBUILD;

-- Update statistics
UPDATE STATISTICS kpi_daily_summary;
UPDATE STATISTICS financial_metrics_summary;
UPDATE STATISTICS sales_performance_summary;
UPDATE STATISTICS customer_success_summary;
UPDATE STATISTICS operational_metrics_summary;
UPDATE STATISTICS hr_performance_summary;

PRINT 'Index rebuild and statistics update completed';
```

---

## 📋 Common Reports

### Executive Weekly Summary
```sql
DECLARE @v_week_start DATE = DATEADD(WEEK, -1, CAST(GETDATE() AS DATE));

SELECT 
    ks.kpi_date,
    ks.kpi_category,
    COUNT(DISTINCT ks.kpi_name) AS kpi_count,
    ROUND(AVG(ks.achievement_pct), 2) AS avg_achievement_pct,
    SUM(CASE WHEN ks.status_flag = 'GREEN' THEN 1 ELSE 0 END) AS green_count,
    SUM(CASE WHEN ks.status_flag = 'YELLOW' THEN 1 ELSE 0 END) AS yellow_count,
    SUM(CASE WHEN ks.status_flag = 'RED' THEN 1 ELSE 0 END) AS red_count
FROM kpi_daily_summary ks
WHERE ks.kpi_date >= @v_week_start AND ks.kpi_date <= CAST(GETDATE() AS DATE)
GROUP BY ks.kpi_date, ks.kpi_category
ORDER BY ks.kpi_date DESC;
```

### Customer Segment Performance Comparison
```sql
SELECT 
    css.metric_date,
    dc.customer_segment,
    COUNT(DISTINCT css.customer_key) AS customers,
    ROUND(AVG(css.customer_health_score), 2) AS health_score,
    ROUND(SUM(css.current_arr), 2) AS total_arr,
    ROUND(AVG(css.retention_rate_pct), 2) AS retention_rate,
    ROUND(AVG(css.nps_score), 2) AS nps,
    ROUND(AVG(css.net_revenue_retention_pct), 2) AS nrr_pct
FROM customer_success_summary css
LEFT JOIN dim_customer dc ON css.customer_key = dc.customer_key AND dc.is_current = 1
WHERE css.metric_date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
GROUP BY css.metric_date, dc.customer_segment
ORDER BY css.metric_date DESC, total_arr DESC;
```

---

## 📝 Notes

- All queries use **UTC dates**. Adjust `CAST(GETDATE() AS DATE)` if needed for your timezone.
- Performance typically <200ms for all queries when using recommended date filters.
- For historical analysis >1 year, aggregate using `kpi_monthly_summary` instead of `kpi_daily_summary`.
- Always include date filters to leverage indexes and maintain performance.

---

**Last Updated**: May 22, 2026  
**Quick Reference Version**: 1.0
