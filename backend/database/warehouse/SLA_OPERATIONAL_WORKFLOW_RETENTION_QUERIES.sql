-- ============================================================================
-- SLA, OPERATIONAL METRICS & CUSTOMER RETENTION - QUICK REFERENCE QUERIES
-- Enterprise KPI Platform - May 27, 2026
-- ============================================================================
-- Copy and paste these queries into your SQL client for common analysis
-- All timestamps are in UTC - adjust for your timezone if needed

-- ============================================================================
-- SECTION 1: SLA COMPLIANCE QUERIES
-- ============================================================================

-- 1.1: Daily SLA Compliance Summary
SELECT
    CAST(GETDATE() AS DATE) AS report_date,
    sd.sla_name,
    sd.sla_category,
    COUNT(*) AS total_slas,
    SUM(CASE WHEN spt.is_compliant = 1 THEN 1 ELSE 0 END) AS compliant,
    SUM(CASE WHEN spt.is_breached = 1 THEN 1 ELSE 0 END) AS breached,
    ROUND(SUM(CASE WHEN spt.is_compliant = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS compliance_pct,
    MAX(spt.sla_utilization_pct) AS max_utilization,
    ROUND(AVG(spt.sla_utilization_pct), 2) AS avg_utilization
FROM sla_definitions sd
LEFT JOIN sla_performance_tracking spt ON sd.sla_definition_key = spt.sla_definition_key
    AND CAST(spt.sla_start_time AS DATE) = CAST(GETDATE() AS DATE)
WHERE sd.is_active = 1
GROUP BY sd.sla_name, sd.sla_category
ORDER BY compliance_pct ASC;

-- 1.2: Breached SLAs Needing Attention
SELECT TOP 20
    spt.sla_tracking_key,
    sd.sla_name,
    dc.customer_name,
    spt.sla_status,
    spt.sla_utilization_pct,
    DATEDIFF(MINUTE, spt.sla_due_time, GETDATE()) AS minutes_overdue,
    spt.escalation_count,
    spt.severity_level
FROM sla_performance_tracking spt
LEFT JOIN sla_definitions sd ON spt.sla_definition_key = sd.sla_definition_key
LEFT JOIN dim_customer dc ON spt.customer_key = dc.customer_key
WHERE spt.is_breached = 1
AND spt.sla_breach_time >= DATEADD(DAY, -7, CAST(GETDATE() AS DATE))
ORDER BY DATEDIFF(MINUTE, spt.sla_due_time, GETDATE()) DESC;

-- 1.3: SLA Compliance by Customer Segment (Last 30 Days)
SELECT
    sd.customer_segment,
    COUNT(*) AS total_slas,
    SUM(CASE WHEN spt.is_compliant = 1 THEN 1 ELSE 0 END) AS compliant,
    ROUND(SUM(CASE WHEN spt.is_compliant = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS compliance_pct,
    SUM(spt.escalation_count) AS total_escalations,
    ROUND(AVG(spt.sla_utilization_pct), 2) AS avg_utilization
FROM sla_definitions sd
LEFT JOIN sla_performance_tracking spt ON sd.sla_definition_key = spt.sla_definition_key
WHERE spt.sla_start_time >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
GROUP BY sd.customer_segment
ORDER BY compliance_pct ASC;

-- 1.4: Monthly SLA Summary
SELECT
    sms.year_month,
    sms.sla_name,
    sms.total_slas,
    sms.compliant_slas,
    sms.breached_slas,
    ROUND(sms.compliance_rate_pct, 2) AS compliance_pct,
    ROUND(sms.avg_utilization_pct, 2) AS avg_utilization,
    sms.escalation_count
FROM sla_monthly_summary sms
WHERE sms.year_month >= FORMAT(DATEADD(MONTH, -3, GETDATE()), 'yyyy-MM')
ORDER BY sms.year_month DESC;

-- ============================================================================
-- SECTION 2: OPERATIONAL METRICS QUERIES
-- ============================================================================

-- 2.1: Daily Operational KPI Summary
SELECT
    ok.metric_date,
    ok.warehouse_location,
    ok.items_processed,
    ok.orders_processed,
    ok.shipments_created,
    ok.returns_processed,
    ROUND(ok.avg_processing_time_min, 2) AS avg_processing_min,
    ROUND(ok.error_rate_pct, 2) AS error_rate_pct,
    ROUND(ok.quality_score, 2) AS quality_score,
    ROUND(ok.labor_productivity, 2) AS items_per_hour,
    ROUND(ok.equipment_utilization_pct, 2) AS equipment_util_pct,
    CASE 
        WHEN ok.quality_score >= 95 THEN '✓ GREEN'
        WHEN ok.quality_score >= 90 THEN '⚠ YELLOW'
        ELSE '✗ RED'
    END AS quality_status
FROM operational_daily_kpi ok
WHERE ok.metric_date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
ORDER BY ok.metric_date DESC;

-- 2.2: Process Performance by Warehouse (Last 30 Days)
SELECT
    opm.warehouse_location,
    opm.process_name,
    COUNT(DISTINCT opm.metric_date) AS days_tracked,
    SUM(opm.total_executions) AS total_executions,
    ROUND(AVG(opm.success_rate_pct), 2) AS avg_success_rate,
    ROUND(AVG(opm.avg_duration_minutes), 2) AS avg_duration_min,
    ROUND(AVG(opm.first_pass_yield_pct), 2) AS avg_fpy,
    ROUND(AVG(opm.sla_adherence_pct), 2) AS avg_sla_adherence
FROM operational_process_metrics opm
WHERE opm.metric_date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
GROUP BY opm.warehouse_location, opm.process_name
ORDER BY opm.warehouse_location, opm.process_name;

-- 2.3: Quality Trends (Process-Specific)
SELECT
    opm.metric_date,
    opm.process_name,
    opm.defect_count,
    ROUND(opm.defect_rate_pct, 2) AS defect_rate,
    opm.first_pass_yield_pct,
    opm.rework_required_pct,
    ROUND(opm.process_cost, 2) AS daily_cost
FROM operational_process_metrics opm
WHERE opm.process_name = 'Picking'
AND opm.metric_date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
ORDER BY opm.metric_date DESC;

-- 2.4: Warehouse Performance Scorecard
SELECT
    ok.warehouse_location,
    ROUND(AVG(ok.quality_score), 2) AS avg_quality,
    ROUND(AVG(ok.labor_productivity), 2) AS avg_productivity,
    ROUND(AVG(ok.equipment_utilization_pct), 2) AS avg_utilization,
    COUNT(*) AS days_measured,
    MAX(ok.items_processed) AS max_daily_throughput,
    ROUND(AVG(ok.error_rate_pct), 2) AS avg_error_rate
FROM operational_daily_kpi ok
WHERE ok.metric_date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
GROUP BY ok.warehouse_location
ORDER BY avg_quality DESC;

-- ============================================================================
-- SECTION 3: WORKFLOW TRACKING QUERIES
-- ============================================================================

-- 3.1: Active Workflows Status
SELECT
    wd.workflow_name,
    COUNT(*) AS active_count,
    SUM(CASE WHEN wit.is_escalated = 1 THEN 1 ELSE 0 END) AS escalated,
    ROUND(AVG(DATEDIFF(MINUTE, wit.current_state_entered_time, GETDATE()) / 60.0), 1) AS avg_hours_in_state,
    MAX(DATEDIFF(MINUTE, wit.current_state_entered_time, GETDATE()) / 60.0) AS max_hours_in_state
FROM workflow_definition wd
LEFT JOIN workflow_instance_tracking wit ON wd.workflow_key = wit.workflow_key
WHERE wit.workflow_status = 'Active'
AND wd.is_active = 1
GROUP BY wd.workflow_name
ORDER BY active_count DESC;

-- 3.2: Workflow Completion Performance
SELECT
    wd.workflow_name,
    COUNT(*) AS total_workflows,
    SUM(CASE WHEN wit.is_completed = 1 THEN 1 ELSE 0 END) AS completed,
    SUM(CASE WHEN wit.is_failed = 1 THEN 1 ELSE 0 END) AS failed,
    ROUND(SUM(CASE WHEN wit.is_completed = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS completion_rate,
    ROUND(AVG(wit.total_duration_minutes), 2) AS avg_duration_min,
    ROUND(AVG(wit.state_transition_count), 2) AS avg_transitions,
    SUM(wit.escalation_count) AS total_escalations
FROM workflow_definition wd
LEFT JOIN workflow_instance_tracking wit ON wd.workflow_key = wit.workflow_key
    AND wit.workflow_started_time >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
WHERE wd.is_active = 1
GROUP BY wd.workflow_name
ORDER BY completion_rate DESC;

-- 3.3: Stalled Workflows (>8 hours in current state)
SELECT TOP 25
    wd.workflow_name,
    wit.workflow_instance_key,
    wit.entity_type,
    wit.entity_key,
    dc.customer_name,
    wit.current_state_entered_time,
    DATEDIFF(HOUR, wit.current_state_entered_time, GETDATE()) AS hours_stalled,
    wit.state_transition_count,
    wit.is_escalated
FROM workflow_instance_tracking wit
LEFT JOIN workflow_definition wd ON wit.workflow_key = wd.workflow_key
LEFT JOIN dim_customer dc ON wit.customer_key = dc.customer_key
WHERE wit.workflow_status = 'Active'
AND DATEDIFF(HOUR, wit.current_state_entered_time, GETDATE()) > 8
ORDER BY DATEDIFF(HOUR, wit.current_state_entered_time, GETDATE()) DESC;

-- 3.4: Workflow State Distribution (Current)
SELECT
    wd.workflow_name,
    wsd.state_name,
    COUNT(*) AS active_in_state,
    ROUND(AVG(DATEDIFF(MINUTE, wit.current_state_entered_time, GETDATE())), 0) AS avg_state_duration_min
FROM workflow_instance_tracking wit
LEFT JOIN workflow_definition wd ON wit.workflow_key = wd.workflow_key
LEFT JOIN workflow_state_definition wsd ON wit.current_state_key = wsd.state_key
WHERE wit.workflow_status = 'Active'
GROUP BY wd.workflow_name, wsd.state_name
ORDER BY wd.workflow_name, wsd.state_sequence;

-- ============================================================================
-- SECTION 4: CUSTOMER HEALTH & ENGAGEMENT QUERIES
-- ============================================================================

-- 4.1: Customer Health Dashboard
SELECT
    dc.customer_name,
    dc.customer_segment,
    crs.retention_risk_score,
    crs.risk_category,
    cem.health_status,
    cem.engagement_level,
    cfm.monthly_arr,
    ROUND(cfm.mom_growth_pct, 2) AS growth_pct,
    crs.days_since_last_activity,
    crs.predicted_churn_date,
    CASE 
        WHEN crs.retention_risk_score >= 80 THEN 'CRITICAL'
        WHEN crs.retention_risk_score >= 60 THEN 'HIGH'
        WHEN crs.retention_risk_score >= 40 THEN 'MEDIUM'
        ELSE 'LOW'
    END AS action_priority
FROM dim_customer dc
LEFT JOIN customer_retention_status crs ON dc.customer_key = crs.customer_key
LEFT JOIN customer_engagement_metrics cem ON dc.customer_key = cem.customer_key 
    AND cem.metric_date = CAST(GETDATE() AS DATE)
LEFT JOIN customer_financial_metrics cfm ON dc.customer_key = cfm.customer_key 
    AND cfm.year_month = FORMAT(CAST(GETDATE() AS DATE), 'yyyy-MM')
WHERE dc.is_current = 1
ORDER BY crs.retention_risk_score DESC;

-- 4.2: Top Customers by ARR
SELECT TOP 25
    dc.customer_name,
    dc.customer_segment,
    cfm.monthly_arr,
    ROUND(cfm.monthly_arr * 12, 2) AS annual_arr,
    cfm.transaction_count,
    ROUND(cfm.mom_growth_pct, 2) AS growth_pct,
    crs.retention_risk_score,
    cem.health_status
FROM dim_customer dc
LEFT JOIN customer_financial_metrics cfm ON dc.customer_key = cfm.customer_key 
    AND cfm.year_month = FORMAT(CAST(GETDATE() AS DATE), 'yyyy-MM')
LEFT JOIN customer_retention_status crs ON dc.customer_key = crs.customer_key
LEFT JOIN customer_engagement_metrics cem ON dc.customer_key = cem.customer_key 
    AND cem.metric_date = CAST(GETDATE() AS DATE)
WHERE dc.is_current = 1
ORDER BY cfm.monthly_arr DESC;

-- 4.3: Customer Engagement by Segment
SELECT
    dc.customer_segment,
    COUNT(DISTINCT dc.customer_key) AS customer_count,
    ROUND(AVG(cem.login_count), 1) AS avg_logins,
    ROUND(AVG(cem.features_used), 1) AS avg_features,
    SUM(CASE WHEN cem.engagement_level = 'High' THEN 1 ELSE 0 END) AS highly_engaged,
    SUM(CASE WHEN cem.health_status = 'Healthy' THEN 1 ELSE 0 END) AS healthy_customers,
    ROUND(AVG(cem.nps_response), 1) AS avg_nps
FROM dim_customer dc
LEFT JOIN customer_engagement_metrics cem ON dc.customer_key = cem.customer_key 
    AND cem.metric_date = CAST(GETDATE() AS DATE)
WHERE dc.is_current = 1
GROUP BY dc.customer_segment
ORDER BY highly_engaged DESC;

-- 4.4: Customers by Lifecycle Stage
SELECT
    cls.lifecycle_stage,
    COUNT(DISTINCT cls.customer_key) AS customer_count,
    ROUND(AVG(cls.engagement_score), 2) AS avg_engagement,
    ROUND(AVG(cls.monthly_spending), 2) AS avg_monthly_spend,
    ROUND(AVG(cls.expansion_potential_pct), 2) AS avg_expansion_potential,
    MIN(cls.stage_entered_date) AS earliest_stage_entry,
    MAX(cls.stage_entered_date) AS latest_stage_entry
FROM customer_lifecycle_stage cls
WHERE cls.stage_exit_date IS NULL
GROUP BY cls.lifecycle_stage
ORDER BY customer_count DESC;

-- ============================================================================
-- SECTION 5: RETENTION & CHURN QUERIES
-- ============================================================================

-- 5.1: Monthly Retention Rate by Cohort
SELECT
    acquisition_cohort,
    retention_month,
    months_since_acquisition,
    cohort_size_start,
    cohort_size_retained,
    ROUND(retention_rate_pct, 2) AS retention_pct,
    ROUND(net_revenue_retention_pct, 2) AS nrr_pct,
    expanded_customers
FROM customer_retention_cohort
WHERE months_since_acquisition IN (0, 1, 3, 6, 12, 24)
AND acquisition_cohort >= FORMAT(DATEADD(MONTH, -36, GETDATE()), 'yyyy-MM')
ORDER BY acquisition_cohort DESC, months_since_acquisition;

-- 5.2: 12-Month Retention Cohort Table (Pivot View)
SELECT
    acquisition_cohort,
    MAX(CASE WHEN months_since_acquisition = 0 THEN ROUND(retention_rate_pct, 1) END) AS m0,
    MAX(CASE WHEN months_since_acquisition = 1 THEN ROUND(retention_rate_pct, 1) END) AS m1,
    MAX(CASE WHEN months_since_acquisition = 3 THEN ROUND(retention_rate_pct, 1) END) AS m3,
    MAX(CASE WHEN months_since_acquisition = 6 THEN ROUND(retention_rate_pct, 1) END) AS m6,
    MAX(CASE WHEN months_since_acquisition = 12 THEN ROUND(retention_rate_pct, 1) END) AS m12
FROM customer_retention_cohort
WHERE months_since_acquisition <= 12
GROUP BY acquisition_cohort
ORDER BY acquisition_cohort DESC;

-- 5.3: At-Risk Customers for Intervention
SELECT TOP 50
    dc.customer_name,
    dc.customer_segment,
    crs.retention_risk_score,
    crs.churn_probability_pct,
    crs.predicted_churn_date,
    cfm.monthly_arr,
    DATEDIFF(DAY, dc.first_sale_date, CAST(GETDATE() AS DATE)) AS customer_age_days,
    crs.risk_reason,
    CASE 
        WHEN crs.churn_probability_pct >= 80 THEN 'Executive Outreach'
        WHEN crs.churn_probability_pct >= 60 THEN 'CS Intervention'
        WHEN crs.churn_probability_pct >= 40 THEN 'Product Enablement'
        ELSE 'Account Management'
    END AS recommended_action
FROM dim_customer dc
LEFT JOIN customer_retention_status crs ON dc.customer_key = crs.customer_key
LEFT JOIN customer_financial_metrics cfm ON dc.customer_key = cfm.customer_key 
    AND cfm.year_month = FORMAT(CAST(GETDATE() AS DATE), 'yyyy-MM')
WHERE dc.is_current = 1 
AND crs.retention_risk_flag = 1
ORDER BY crs.churn_probability_pct DESC;

-- 5.4: Recent Churn Analysis (Last 90 Days)
SELECT
    cce.churn_date,
    dc.customer_name,
    dc.customer_segment,
    cce.churn_type,
    cce.primary_churn_reason,
    cce.churn_category,
    cce.arr_lost,
    cce.tenure_days,
    cce.was_predicted_churn,
    cce.prediction_accuracy
FROM customer_churn_events cce
LEFT JOIN dim_customer dc ON cce.customer_key = dc.customer_key
WHERE cce.churn_date >= DATEADD(DAY, -90, CAST(GETDATE() AS DATE))
ORDER BY cce.churn_date DESC;

-- 5.5: Monthly Churn Summary
SELECT
    year_month,
    customers_churned,
    ROUND(gross_churn_rate_pct, 2) AS churn_rate_pct,
    ROUND(arr_lost, 2) AS arr_lost_value,
    price_related_count,
    competition_count,
    product_count,
    support_count,
    consolidation_count,
    ROUND(avg_tenure_days, 1) AS avg_tenure_days,
    ROUND(intervention_success_rate_pct, 2) AS intervention_success_pct
FROM monthly_churn_summary
WHERE year_month >= FORMAT(DATEADD(MONTH, -12, GETDATE()), 'yyyy-MM')
ORDER BY year_month DESC;

-- 5.6: Churn Reasons Analysis
SELECT
    cce.churn_category,
    cce.primary_churn_reason,
    COUNT(*) AS count,
    ROUND(SUM(cce.arr_lost), 2) AS total_arr_lost,
    ROUND(AVG(cce.arr_lost), 2) AS avg_arr_lost,
    ROUND(AVG(cce.tenure_days), 0) AS avg_tenure_days,
    SUM(CASE WHEN cce.was_predicted_churn = 1 THEN 1 ELSE 0 END) AS predicted_count
FROM customer_churn_events cce
WHERE cce.churn_date >= DATEADD(MONTH, -12, CAST(GETDATE() AS DATE))
GROUP BY cce.churn_category, cce.primary_churn_reason
ORDER BY count DESC;

-- 5.7: Churn Prediction Accuracy
SELECT
    ROUND(cce.prediction_accuracy) AS accuracy_bucket,
    COUNT(*) AS churn_count,
    ROUND(SUM(cce.arr_lost), 2) AS arr_lost,
    ROUND(AVG(cce.prediction_accuracy), 2) AS avg_accuracy
FROM customer_churn_events cce
WHERE cce.was_predicted_churn = 1
GROUP BY ROUND(cce.prediction_accuracy)
ORDER BY accuracy_bucket DESC;

-- ============================================================================
-- SECTION 6: EXECUTIVE DASHBOARDS
-- ============================================================================

-- 6.1: Customer Success Scorecard
SELECT
    CAST(GETDATE() AS DATE) AS report_date,
    COUNT(DISTINCT dc.customer_key) AS total_customers,
    SUM(CASE WHEN crs.retention_risk_flag = 1 THEN 1 ELSE 0 END) AS at_risk_count,
    ROUND(SUM(CASE WHEN crs.retention_risk_flag = 1 THEN 1 ELSE 0 END) * 100.0 / 
          COUNT(DISTINCT dc.customer_key), 2) AS at_risk_pct,
    (SELECT COUNT(*) FROM customer_churn_events 
     WHERE churn_date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE))) AS monthly_churned,
    (SELECT ROUND(SUM(arr_lost), 2) FROM customer_churn_events 
     WHERE churn_date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE))) AS monthly_arr_lost,
    ROUND(AVG(CAST(ISNULL(cfm.monthly_arr, 0) AS DECIMAL(15, 2))), 2) AS avg_customer_arr
FROM dim_customer dc
LEFT JOIN customer_retention_status crs ON dc.customer_key = crs.customer_key
LEFT JOIN customer_financial_metrics cfm ON dc.customer_key = cfm.customer_key 
    AND cfm.year_month = FORMAT(CAST(GETDATE() AS DATE), 'yyyy-MM')
WHERE dc.is_current = 1;

-- 6.2: Operational Excellence Scorecard
SELECT
    CAST(GETDATE() AS DATE) AS report_date,
    (SELECT ROUND(AVG(quality_score), 2) FROM operational_daily_kpi 
     WHERE metric_date = CAST(GETDATE() AS DATE)) AS avg_quality_score,
    (SELECT ROUND(AVG(compliance_rate_pct), 2) FROM vw_sla_compliance_dashboard) AS avg_sla_compliance,
    (SELECT COUNT(*) FROM workflow_instance_tracking 
     WHERE workflow_status = 'Active' AND is_escalated = 1) AS escalated_workflows,
    (SELECT ROUND(AVG(avg_utilization_pct), 2) FROM vw_sla_compliance_dashboard) AS avg_sla_utilization;

-- ============================================================================
-- NOTES
-- ============================================================================
-- All dates use CAST(GETDATE() AS DATE) for UTC
-- Adjust DATEADD functions for your timezone if needed
-- Replace database names if using non-default schema
-- These queries are read-only and safe for production

GO
