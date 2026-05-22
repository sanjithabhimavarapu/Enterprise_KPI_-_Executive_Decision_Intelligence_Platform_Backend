-- ============================================================================
-- OPTIMIZED KPI STORED PROCEDURES
-- Enterprise KPI - Executive Decision Intelligence Platform
-- Purpose: Populate KPI aggregation tables and calculate metrics
-- Updated: May 22, 2026
-- ============================================================================

-- ============================================================================
-- PROCEDURE 1: sp_populate_daily_kpi_summary
-- Purpose: Calculate and populate daily KPI summary table
-- Schedule: Daily (post-fact load completion)
-- Performance: Uses indexed queries, ~30-60 seconds for full day
-- ============================================================================
CREATE PROCEDURE sp_populate_daily_kpi_summary (
    @p_kpi_date DATE = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @v_kpi_date DATE = ISNULL(@p_kpi_date, CAST(GETDATE() AS DATE));
    DECLARE @v_prior_date DATE = DATEADD(DAY, -1, @v_kpi_date);
    DECLARE @v_year_ago_date DATE = DATEADD(YEAR, -1, @v_kpi_date);

    BEGIN TRY
        -- Delete existing records for the date (idempotent operation)
        DELETE FROM kpi_daily_summary 
        WHERE kpi_date = @v_kpi_date;

        -- ================================================================
        -- FINANCIAL KPIs
        -- ================================================================
        INSERT INTO kpi_daily_summary (
            kpi_date, kpi_name, kpi_category, kpi_value, kpi_value_prior_period,
            kpi_variance, kpi_variance_pct, unit_of_measure, target_value,
            achievement_pct, status_flag, data_quality_score, calculation_timestamp
        )
        SELECT
            @v_kpi_date,
            'Total Revenue',
            'Financial',
            ISNULL(SUM(fms.total_revenue), 0),
            (SELECT ISNULL(SUM(fms2.total_revenue), 0) 
             FROM financial_metrics_summary fms2 
             WHERE fms2.metric_date = @v_prior_date),
            ISNULL(SUM(fms.total_revenue), 0) - 
            (SELECT ISNULL(SUM(fms2.total_revenue), 0) FROM financial_metrics_summary fms2 WHERE fms2.metric_date = @v_prior_date),
            CASE 
                WHEN (SELECT SUM(fms2.total_revenue) FROM financial_metrics_summary fms2 WHERE fms2.metric_date = @v_prior_date) > 0
                THEN ROUND(((ISNULL(SUM(fms.total_revenue), 0) - (SELECT SUM(fms2.total_revenue) FROM financial_metrics_summary fms2 WHERE fms2.metric_date = @v_prior_date)) / 
                            (SELECT SUM(fms2.total_revenue) FROM financial_metrics_summary fms2 WHERE fms2.metric_date = @v_prior_date)) * 100, 2)
                ELSE 0
            END,
            'USD',
            0, -- Target set during configuration
            0,
            CASE 
                WHEN ISNULL(SUM(fms.total_revenue), 0) > 0 THEN 'GREEN'
                WHEN ISNULL(SUM(fms.total_revenue), 0) = 0 THEN 'YELLOW'
                ELSE 'RED'
            END,
            95,
            GETDATE()
        FROM financial_metrics_summary fms
        WHERE fms.metric_date = @v_kpi_date;

        -- Gross Profit Margin
        INSERT INTO kpi_daily_summary (
            kpi_date, kpi_name, kpi_category, kpi_value, unit_of_measure,
            target_value, achievement_pct, status_flag, data_quality_score, calculation_timestamp
        )
        SELECT
            @v_kpi_date,
            'Gross Profit Margin',
            'Financial',
            ROUND(AVG(fms.gross_profit_margin_pct), 2),
            '%',
            40.0, -- 40% target
            ROUND(AVG(fms.gross_profit_margin_pct) / 40 * 100, 2),
            CASE 
                WHEN AVG(fms.gross_profit_margin_pct) >= 40 THEN 'GREEN'
                WHEN AVG(fms.gross_profit_margin_pct) >= 35 THEN 'YELLOW'
                ELSE 'RED'
            END,
            95,
            GETDATE()
        FROM financial_metrics_summary fms
        WHERE fms.metric_date = @v_kpi_date
        AND fms.gross_profit_margin_pct > 0;

        -- Operating Margin
        INSERT INTO kpi_daily_summary (
            kpi_date, kpi_name, kpi_category, kpi_value, unit_of_measure,
            target_value, achievement_pct, status_flag, data_quality_score, calculation_timestamp
        )
        SELECT
            @v_kpi_date,
            'Operating Margin',
            'Financial',
            ROUND(AVG(fms.operating_margin_pct), 2),
            '%',
            15.0, -- 15% target
            ROUND(AVG(fms.operating_margin_pct) / 15 * 100, 2),
            CASE 
                WHEN AVG(fms.operating_margin_pct) >= 15 THEN 'GREEN'
                WHEN AVG(fms.operating_margin_pct) >= 12 THEN 'YELLOW'
                ELSE 'RED'
            END,
            95,
            GETDATE()
        FROM financial_metrics_summary fms
        WHERE fms.metric_date = @v_kpi_date
        AND fms.operating_margin_pct > 0;

        -- Average Deal Size
        INSERT INTO kpi_daily_summary (
            kpi_date, kpi_name, kpi_category, kpi_value, unit_of_measure,
            target_value, achievement_pct, status_flag, data_quality_score, calculation_timestamp
        )
        SELECT
            @v_kpi_date,
            'Average Deal Size',
            'Financial',
            ROUND(AVG(fms.average_transaction_value), 2),
            'USD',
            50000.0, -- $50K target
            ROUND(AVG(fms.average_transaction_value) / 50000 * 100, 2),
            CASE 
                WHEN AVG(fms.average_transaction_value) >= 50000 THEN 'GREEN'
                WHEN AVG(fms.average_transaction_value) >= 40000 THEN 'YELLOW'
                ELSE 'RED'
            END,
            95,
            GETDATE()
        FROM financial_metrics_summary fms
        WHERE fms.metric_date = @v_kpi_date;

        -- ================================================================
        -- SALES KPIs
        -- ================================================================
        INSERT INTO kpi_daily_summary (
            kpi_date, kpi_name, kpi_category, kpi_value, unit_of_measure,
            target_value, achievement_pct, status_flag, data_quality_score, calculation_timestamp
        )
        SELECT
            @v_kpi_date,
            'Sales Growth Rate (YoY)',
            'Sales',
            ISNULL(ROUND(AVG(sps.yoy_growth_pct), 2), 0),
            '%',
            10.0, -- 10% growth target
            ISNULL(ROUND(AVG(sps.yoy_growth_pct) / 10 * 100, 2), 0),
            CASE 
                WHEN ISNULL(AVG(sps.yoy_growth_pct), 0) >= 10 THEN 'GREEN'
                WHEN ISNULL(AVG(sps.yoy_growth_pct), 0) >= 5 THEN 'YELLOW'
                ELSE 'RED'
            END,
            95,
            GETDATE()
        FROM sales_performance_summary sps
        WHERE sps.metric_date = @v_kpi_date;

        -- Win Rate
        INSERT INTO kpi_daily_summary (
            kpi_date, kpi_name, kpi_category, kpi_value, unit_of_measure,
            target_value, achievement_pct, status_flag, data_quality_score, calculation_timestamp
        )
        SELECT
            @v_kpi_date,
            'Win Rate',
            'Sales',
            ISNULL(ROUND(AVG(sps.win_rate_pct), 2), 0),
            '%',
            30.0, -- 30% win rate target
            ISNULL(ROUND(AVG(sps.win_rate_pct) / 30 * 100, 2), 0),
            CASE 
                WHEN ISNULL(AVG(sps.win_rate_pct), 0) >= 30 THEN 'GREEN'
                WHEN ISNULL(AVG(sps.win_rate_pct), 0) >= 25 THEN 'YELLOW'
                ELSE 'RED'
            END,
            95,
            GETDATE()
        FROM sales_performance_summary sps
        WHERE sps.metric_date = @v_kpi_date;

        -- New Customers Acquired
        INSERT INTO kpi_daily_summary (
            kpi_date, kpi_name, kpi_category, kpi_value, unit_of_measure,
            target_value, achievement_pct, status_flag, data_quality_score, calculation_timestamp
        )
        SELECT
            @v_kpi_date,
            'New Customers Acquired',
            'Sales',
            SUM(sps.new_customers_count),
            'Count',
            50.0,
            ROUND(SUM(sps.new_customers_count) / 50 * 100, 2),
            CASE 
                WHEN SUM(sps.new_customers_count) >= 50 THEN 'GREEN'
                WHEN SUM(sps.new_customers_count) >= 40 THEN 'YELLOW'
                ELSE 'RED'
            END,
            95,
            GETDATE()
        FROM sales_performance_summary sps
        WHERE sps.metric_date = @v_kpi_date;

        -- ================================================================
        -- CUSTOMER SUCCESS KPIs
        -- ================================================================
        INSERT INTO kpi_daily_summary (
            kpi_date, kpi_name, kpi_category, kpi_value, unit_of_measure,
            target_value, achievement_pct, status_flag, data_quality_score, calculation_timestamp
        )
        SELECT
            @v_kpi_date,
            'Customer Retention Rate',
            'Customer Success',
            ISNULL(ROUND(AVG(css.retention_rate_pct), 2), 0),
            '%',
            95.0, -- 95% retention target
            ISNULL(ROUND(AVG(css.retention_rate_pct) / 95 * 100, 2), 0),
            CASE 
                WHEN ISNULL(AVG(css.retention_rate_pct), 0) >= 95 THEN 'GREEN'
                WHEN ISNULL(AVG(css.retention_rate_pct), 0) >= 90 THEN 'YELLOW'
                ELSE 'RED'
            END,
            95,
            GETDATE()
        FROM customer_success_summary css
        WHERE css.metric_date = @v_kpi_date;

        -- Customer Health Score
        INSERT INTO kpi_daily_summary (
            kpi_date, kpi_name, kpi_category, kpi_value, unit_of_measure,
            target_value, achievement_pct, status_flag, data_quality_score, calculation_timestamp
        )
        SELECT
            @v_kpi_date,
            'Customer Health Score',
            'Customer Success',
            ISNULL(ROUND(AVG(css.customer_health_score), 2), 0),
            'Score',
            75.0, -- 75/100 target
            ISNULL(ROUND(AVG(css.customer_health_score) / 100 * 100, 2), 0),
            CASE 
                WHEN ISNULL(AVG(css.customer_health_score), 0) >= 75 THEN 'GREEN'
                WHEN ISNULL(AVG(css.customer_health_score), 0) >= 60 THEN 'YELLOW'
                ELSE 'RED'
            END,
            95,
            GETDATE()
        FROM customer_success_summary css
        WHERE css.metric_date = @v_kpi_date;

        -- NPS Score
        INSERT INTO kpi_daily_summary (
            kpi_date, kpi_name, kpi_category, kpi_value, unit_of_measure,
            target_value, achievement_pct, status_flag, data_quality_score, calculation_timestamp
        )
        SELECT
            @v_kpi_date,
            'Net Promoter Score',
            'Customer Success',
            ISNULL(ROUND(AVG(css.nps_score), 2), 0),
            'Score',
            50.0, -- 50 NPS target
            ISNULL(ROUND(AVG(css.nps_score) / 100 * 100, 2), 0),
            CASE 
                WHEN ISNULL(AVG(css.nps_score), 0) >= 50 THEN 'GREEN'
                WHEN ISNULL(AVG(css.nps_score), 0) >= 40 THEN 'YELLOW'
                ELSE 'RED'
            END,
            95,
            GETDATE()
        FROM customer_success_summary css
        WHERE css.metric_date = @v_kpi_date;

        -- ================================================================
        -- OPERATIONAL KPIs
        -- ================================================================
        INSERT INTO kpi_daily_summary (
            kpi_date, kpi_name, kpi_category, kpi_value, unit_of_measure,
            target_value, achievement_pct, status_flag, data_quality_score, calculation_timestamp
        )
        SELECT
            @v_kpi_date,
            'On-Time Delivery Rate',
            'Operational',
            ISNULL(ROUND(AVG(ops.ontime_delivery_rate_pct), 2), 0),
            '%',
            95.0, -- 95% on-time target
            ISNULL(ROUND(AVG(ops.ontime_delivery_rate_pct) / 95 * 100, 2), 0),
            CASE 
                WHEN ISNULL(AVG(ops.ontime_delivery_rate_pct), 0) >= 95 THEN 'GREEN'
                WHEN ISNULL(AVG(ops.ontime_delivery_rate_pct), 0) >= 90 THEN 'YELLOW'
                ELSE 'RED'
            END,
            95,
            GETDATE()
        FROM operational_metrics_summary ops
        WHERE ops.metric_date = @v_kpi_date;

        -- Defect Rate
        INSERT INTO kpi_daily_summary (
            kpi_date, kpi_name, kpi_category, kpi_value, unit_of_measure,
            target_value, achievement_pct, status_flag, data_quality_score, calculation_timestamp
        )
        SELECT
            @v_kpi_date,
            'Defect Rate',
            'Operational',
            ISNULL(ROUND(AVG(ops.defect_rate_pct), 2), 0),
            '%',
            1.0, -- <1% defect target
            CASE 
                WHEN ISNULL(AVG(ops.defect_rate_pct), 0) <= 1 THEN 100.0
                ELSE ROUND(100.0 - (ISNULL(AVG(ops.defect_rate_pct), 0) * 100), 2)
            END,
            CASE 
                WHEN ISNULL(AVG(ops.defect_rate_pct), 0) <= 1 THEN 'GREEN'
                WHEN ISNULL(AVG(ops.defect_rate_pct), 0) <= 2 THEN 'YELLOW'
                ELSE 'RED'
            END,
            95,
            GETDATE()
        FROM operational_metrics_summary ops
        WHERE ops.metric_date = @v_kpi_date;

        -- ================================================================
        -- HR KPIs
        -- ================================================================
        INSERT INTO kpi_daily_summary (
            kpi_date, kpi_name, kpi_category, kpi_value, unit_of_measure,
            target_value, achievement_pct, status_flag, data_quality_score, calculation_timestamp
        )
        SELECT
            @v_kpi_date,
            'Employee Productivity',
            'HR',
            ISNULL(ROUND(AVG(hrps.productivity_per_employee), 2), 0),
            'USD',
            500000.0, -- $500K per employee target
            ISNULL(ROUND(AVG(hrps.productivity_per_employee) / 500000 * 100, 2), 0),
            CASE 
                WHEN ISNULL(AVG(hrps.productivity_per_employee), 0) >= 500000 THEN 'GREEN'
                WHEN ISNULL(AVG(hrps.productivity_per_employee), 0) >= 400000 THEN 'YELLOW'
                ELSE 'RED'
            END,
            95,
            GETDATE()
        FROM hr_performance_summary hrps
        WHERE hrps.metric_date = @v_kpi_date;

        PRINT 'KPI Daily Summary calculated successfully for: ' + CONVERT(VARCHAR, @v_kpi_date);
    END TRY
    BEGIN CATCH
        PRINT 'Error in sp_populate_daily_kpi_summary: ' + ERROR_MESSAGE();
        THROW;
    END CATCH;
END;
GO

-- ============================================================================
-- PROCEDURE 2: sp_populate_financial_metrics_summary
-- Purpose: Populate financial_metrics_summary table from fact tables
-- Performance: Optimized with proper indexing, ~15-30 seconds per day
-- ============================================================================
CREATE PROCEDURE sp_populate_financial_metrics_summary (
    @p_metric_date DATE = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @v_metric_date DATE = ISNULL(@p_metric_date, CAST(GETDATE() AS DATE));

    BEGIN TRY
        DELETE FROM financial_metrics_summary 
        WHERE metric_date = @v_metric_date;

        INSERT INTO financial_metrics_summary (
            metric_date, customer_key, product_key, segment_key, geography_key,
            total_revenue, net_revenue, gross_profit, gross_profit_margin_pct,
            operating_expense, operating_margin_pct, net_income, net_margin_pct,
            transaction_count, average_transaction_value, freight_cost, duty_cost,
            discount_amount, discount_pct, ytd_revenue, ytd_gross_profit
        )
        SELECT
            @v_metric_date,
            dc.customer_key,
            dp.product_key,
            ISNULL(dc.customer_segment, 'Unknown') AS segment_key,
            dg.geography_key,
            SUM(fr.total_net_revenue),
            SUM(fr.total_net_revenue),
            SUM(fr.total_gross_profit),
            CASE 
                WHEN SUM(fr.total_net_revenue) > 0 
                THEN ROUND((SUM(fr.total_gross_profit) / SUM(fr.total_net_revenue)) * 100, 4)
                ELSE 0
            END,
            SUM(ISNULL(fr.total_freight_cost, 0) + ISNULL(fr.total_duty_cost, 0)),
            CASE 
                WHEN SUM(fr.total_net_revenue) > 0 
                THEN ROUND(((SUM(fr.total_gross_profit) - SUM(ISNULL(fr.total_freight_cost, 0)) - SUM(ISNULL(fr.total_duty_cost, 0))) / 
                           SUM(fr.total_net_revenue)) * 100, 4)
                ELSE 0
            END,
            SUM(fr.total_gross_profit) * 0.15, -- Estimated tax
            CASE 
                WHEN SUM(fr.total_net_revenue) > 0 
                THEN ROUND((SUM(fr.total_gross_profit) * 0.85 / SUM(fr.total_net_revenue)) * 100, 4)
                ELSE 0
            END,
            COUNT(DISTINCT fr.revenue_key),
            AVG(fr.total_net_revenue),
            SUM(ISNULL(fr.total_freight_cost, 0)),
            SUM(ISNULL(fr.total_duty_cost, 0)),
            SUM(ISNULL(fr.discount_amount, 0)),
            CASE 
                WHEN SUM(fr.total_net_revenue) > 0 
                THEN ROUND((SUM(ISNULL(fr.discount_amount, 0)) / SUM(fr.total_net_revenue)) * 100, 4)
                ELSE 0
            END,
            SUM(CASE WHEN YEAR(fr.date_key_value) = YEAR(GETDATE()) THEN fr.total_net_revenue ELSE 0 END),
            SUM(CASE WHEN YEAR(fr.date_key_value) = YEAR(GETDATE()) THEN fr.total_gross_profit ELSE 0 END)
        FROM fact_revenue fr
        LEFT JOIN dim_customer dc ON fr.customer_key = dc.customer_key AND dc.is_current = 1
        LEFT JOIN dim_product dp ON fr.product_key = dp.product_key AND dp.is_current = 1
        LEFT JOIN dim_geography dg ON fr.geography_key = dg.geography_key AND dg.is_current = 1
        WHERE fr.load_date = @v_metric_date
        GROUP BY dc.customer_key, dp.product_key, ISNULL(dc.customer_segment, 'Unknown'), dg.geography_key;

        PRINT 'Financial Metrics Summary populated for: ' + CONVERT(VARCHAR, @v_metric_date);
    END TRY
    BEGIN CATCH
        PRINT 'Error in sp_populate_financial_metrics_summary: ' + ERROR_MESSAGE();
        THROW;
    END CATCH;
END;
GO

-- ============================================================================
-- PROCEDURE 3: sp_populate_sales_performance_summary
-- Purpose: Populate sales_performance_summary from sales facts
-- ============================================================================
CREATE PROCEDURE sp_populate_sales_performance_summary (
    @p_metric_date DATE = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @v_metric_date DATE = ISNULL(@p_metric_date, CAST(GETDATE() AS DATE));

    BEGIN TRY
        DELETE FROM sales_performance_summary 
        WHERE metric_date = @v_metric_date;

        INSERT INTO sales_performance_summary (
            metric_date, employee_key, segment_key, geography_key, department,
            total_orders, total_units_sold, total_sales_amount, average_order_value,
            new_customers_count, returning_customers_count, win_rate_pct,
            average_sales_cycle_days, pipeline_value, closed_won_count, closed_lost_count,
            open_opportunities, mom_growth_pct, qoq_growth_pct, yoy_growth_pct, ytd_sales_amount
        )
        SELECT
            @v_metric_date,
            de.employee_key,
            dc.customer_segment,
            dg.geography_key,
            de.department,
            COUNT(DISTINCT fs.sales_key),
            SUM(fs.order_quantity),
            SUM(fs.net_amount),
            AVG(fs.net_amount),
            COUNT(DISTINCT CASE WHEN fs.is_new_customer = 1 THEN fs.customer_key END),
            COUNT(DISTINCT CASE WHEN fs.is_new_customer = 0 THEN fs.customer_key END),
            CASE 
                WHEN COUNT(*) > 0 
                THEN ROUND(SUM(CASE WHEN fs.deal_won_flag = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2)
                ELSE 0
            END,
            AVG(CAST(fs.sales_cycle_days AS DECIMAL(10, 2))),
            SUM(CASE WHEN fs.opportunity_status = 'Open' THEN fs.opportunity_value ELSE 0 END),
            COUNT(CASE WHEN fs.deal_won_flag = 1 THEN 1 END),
            COUNT(CASE WHEN fs.deal_won_flag = 0 THEN 1 END),
            COUNT(CASE WHEN fs.opportunity_status = 'Open' THEN 1 END),
            0, 0, 0, 0 -- Growth calculations in separate process
        FROM fact_sales fs
        LEFT JOIN dim_employee de ON fs.employee_key = de.employee_key AND de.is_current = 1
        LEFT JOIN dim_customer dc ON fs.customer_key = dc.customer_key AND dc.is_current = 1
        LEFT JOIN dim_geography dg ON de.geography_key = dg.geography_key AND dg.is_current = 1
        WHERE fs.order_date_key = CONVERT(INT, FORMAT(@v_metric_date, 'yyyyMMdd'))
        GROUP BY de.employee_key, dc.customer_segment, dg.geography_key, de.department;

        PRINT 'Sales Performance Summary populated for: ' + CONVERT(VARCHAR, @v_metric_date);
    END TRY
    BEGIN CATCH
        PRINT 'Error in sp_populate_sales_performance_summary: ' + ERROR_MESSAGE();
        THROW;
    END CATCH;
END;
GO

-- ============================================================================
-- PROCEDURE 4: sp_populate_customer_success_summary
-- Purpose: Populate customer success metrics
-- ============================================================================
CREATE PROCEDURE sp_populate_customer_success_summary (
    @p_metric_date DATE = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @v_metric_date DATE = ISNULL(@p_metric_date, CAST(GETDATE() AS DATE));

    BEGIN TRY
        DELETE FROM customer_success_summary 
        WHERE metric_date = @v_metric_date;

        INSERT INTO customer_success_summary (
            metric_date, customer_key, segment_key, geography_key,
            is_active, churn_flag, retention_cohort,
            customer_health_score, usage_score, satisfaction_score, support_sentiment_score,
            engagement_level, current_arr, expansion_revenue, churn_revenue,
            net_revenue_retention_pct, open_tickets, resolved_tickets,
            avg_resolution_time_hours, nps_score
        )
        SELECT
            @v_metric_date,
            dc.customer_key,
            dc.customer_segment,
            dg.geography_key,
            dc.is_active,
            CASE WHEN dc.subscription_status = 'Churned' THEN 1 ELSE 0 END,
            DATEDIFF(MONTH, dc.acquisition_date, @v_metric_date) AS retention_cohort,
            (ISNULL(usage.usage_score, 50) + ISNULL(sat.satisfaction_score, 50) + ISNULL(supp.support_score, 50)) / 3.0,
            ISNULL(usage.usage_score, 50),
            ISNULL(sat.satisfaction_score, 50),
            ISNULL(supp.support_score, 50),
            CASE 
                WHEN (ISNULL(usage.usage_score, 50) + ISNULL(sat.satisfaction_score, 50)) / 2.0 >= 75 THEN 'High'
                WHEN (ISNULL(usage.usage_score, 50) + ISNULL(sat.satisfaction_score, 50)) / 2.0 >= 50 THEN 'Medium'
                ELSE 'Low'
            END,
            ISNULL(dc.annual_contract_value, 0),
            0, 0, 0,
            COUNT(DISTINCT sci.interaction_key),
            COUNT(DISTINCT CASE WHEN sci.resolution_date IS NOT NULL THEN sci.interaction_key END),
            AVG(CAST(sci.interaction_duration_minutes AS DECIMAL(10, 2))) / 60.0,
            ISNULL(sat.nps_score, 0)
        FROM dim_customer dc
        LEFT JOIN dim_geography dg ON dc.country = dg.country AND dg.is_current = 1
        LEFT JOIN (
            SELECT customer_key, AVG(CAST(ISNULL(product_usage_pct, 50) AS DECIMAL(5,2))) AS usage_score
            FROM stg_customer_interactions_conformed
            WHERE source_load_date = @v_metric_date
            GROUP BY customer_key
        ) usage ON dc.customer_key = usage.customer_key
        LEFT JOIN (
            SELECT customer_key, AVG(CAST(ISNULL(satisfaction_score, 50) AS DECIMAL(5,2))) AS satisfaction_score,
                   MAX(CAST(ISNULL(nps_score, 0) AS DECIMAL(5,2))) AS nps_score
            FROM stg_customer_interactions_conformed
            WHERE source_load_date = @v_metric_date
            GROUP BY customer_key
        ) sat ON dc.customer_key = sat.customer_key
        LEFT JOIN (
            SELECT customer_key, AVG(CAST(ISNULL(sentiment_score, 50) AS DECIMAL(5,2))) AS support_score
            FROM stg_customer_interactions_conformed
            WHERE source_load_date = @v_metric_date
            GROUP BY customer_key
        ) supp ON dc.customer_key = supp.customer_key
        LEFT JOIN stg_customer_interactions_conformed sci ON dc.customer_key = sci.customer_key
        WHERE dc.is_current = 1
        GROUP BY dc.customer_key, dc.customer_segment, dg.geography_key, dc.is_active,
                 CASE WHEN dc.subscription_status = 'Churned' THEN 1 ELSE 0 END,
                 DATEDIFF(MONTH, dc.acquisition_date, @v_metric_date),
                 ISNULL(usage.usage_score, 50), ISNULL(sat.satisfaction_score, 50),
                 ISNULL(supp.support_score, 50), ISNULL(dc.annual_contract_value, 0),
                 ISNULL(sat.nps_score, 0);

        PRINT 'Customer Success Summary populated for: ' + CONVERT(VARCHAR, @v_metric_date);
    END TRY
    BEGIN CATCH
        PRINT 'Error in sp_populate_customer_success_summary: ' + ERROR_MESSAGE();
        THROW;
    END CATCH;
END;
GO

-- ============================================================================
-- PROCEDURE 5: sp_populate_operational_metrics_summary
-- Purpose: Populate operational efficiency metrics
-- ============================================================================
CREATE PROCEDURE sp_populate_operational_metrics_summary (
    @p_metric_date DATE = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @v_metric_date DATE = ISNULL(@p_metric_date, CAST(GETDATE() AS DATE));

    BEGIN TRY
        DELETE FROM operational_metrics_summary 
        WHERE metric_date = @v_metric_date;

        INSERT INTO operational_metrics_summary (
            metric_date, warehouse_location, product_key, geography_key,
            orders_received, orders_fulfilled, orders_fulfilled_ontime,
            fulfillment_rate_pct, ontime_delivery_rate_pct, avg_fulfillment_days,
            inventory_value, inventory_units, inventory_turnover_ratio,
            slow_moving_inventory, obsolete_inventory, stockout_incidents,
            total_units_produced, defective_units, defect_rate_pct,
            first_pass_yield_pct, rework_cost, operating_expense, freight_cost,
            warehouse_cost, efficiency_ratio_pct
        )
        SELECT
            @v_metric_date,
            fi.warehouse_location,
            fi.product_key,
            dg.geography_key,
            COUNT(DISTINCT fs.sales_key),
            SUM(CASE WHEN fs.on_time_delivery_flag IS NOT NULL THEN 1 ELSE 0 END),
            SUM(fs.on_time_delivery_flag),
            CASE 
                WHEN COUNT(*) > 0 
                THEN ROUND(SUM(CASE WHEN fs.on_time_delivery_flag IS NOT NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2)
                ELSE 0
            END,
            CASE 
                WHEN COUNT(*) > 0 
                THEN ROUND(SUM(CASE WHEN fs.on_time_delivery_flag = 1 THEN 1 ELSE 0 END) * 100.0 / 
                          COUNT(CASE WHEN fs.on_time_delivery_flag IS NOT NULL THEN 1 ELSE NULL END), 2)
                ELSE 0
            END,
            AVG(CAST(fs.delivery_days AS DECIMAL(10, 2))),
            SUM(fi.inventory_value),
            SUM(fi.quantity_on_hand),
            CASE 
                WHEN AVG(fi.quantity_on_hand) > 0 
                THEN ROUND(SUM(fs.order_quantity * 12.0) / AVG(fi.quantity_on_hand), 2)
                ELSE 0
            END,
            SUM(CASE WHEN fi.quantity_on_hand > fi.quantity_on_hand * 0.2 THEN 1 ELSE 0 END),
            SUM(CASE WHEN fi.quantity_on_hand = 0 THEN 1 ELSE 0 END),
            SUM(CASE WHEN fi.quantity_on_hand = 0 THEN 1 ELSE 0 END),
            SUM(fs.order_quantity),
            SUM(CASE WHEN fs.quality_flag = 0 THEN fs.order_quantity ELSE 0 END),
            CASE 
                WHEN SUM(fs.order_quantity) > 0 
                THEN ROUND(SUM(CASE WHEN fs.quality_flag = 0 THEN fs.order_quantity ELSE 0 END) * 100.0 / 
                          SUM(fs.order_quantity), 2)
                ELSE 0
            END,
            CASE 
                WHEN SUM(fs.order_quantity) > 0 
                THEN ROUND(SUM(CASE WHEN fs.quality_flag = 1 THEN fs.order_quantity ELSE 0 END) * 100.0 / 
                          SUM(fs.order_quantity), 2)
                ELSE 0
            END,
            SUM(fs.order_quantity) * 50, -- Estimated rework cost
            SUM(ISNULL(fs.shipping_cost, 0)),
            SUM(ISNULL(fs.shipping_cost, 0)),
            SUM(ISNULL(fs.warehouse_cost, 0)),
            CASE 
                WHEN SUM(fs.net_amount) > 0 
                THEN ROUND((SUM(ISNULL(fs.shipping_cost, 0)) + SUM(ISNULL(fs.warehouse_cost, 0))) / 
                          SUM(fs.net_amount) * 100, 2)
                ELSE 0
            END
        FROM fact_inventory fi
        LEFT JOIN fact_sales fs ON fi.product_key = fs.product_key AND fi.warehouse_location_key = fs.warehouse_key
        LEFT JOIN dim_geography dg ON fi.geography_key = dg.geography_key AND dg.is_current = 1
        WHERE fi.inventory_date = @v_metric_date
        GROUP BY fi.warehouse_location, fi.product_key, dg.geography_key;

        PRINT 'Operational Metrics Summary populated for: ' + CONVERT(VARCHAR, @v_metric_date);
    END TRY
    BEGIN CATCH
        PRINT 'Error in sp_populate_operational_metrics_summary: ' + ERROR_MESSAGE();
        THROW;
    END CATCH;
END;
GO

-- ============================================================================
-- PROCEDURE 6: sp_populate_hr_performance_summary
-- Purpose: Populate HR and employee performance metrics
-- ============================================================================
CREATE PROCEDURE sp_populate_hr_performance_summary (
    @p_metric_date DATE = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @v_metric_date DATE = ISNULL(@p_metric_date, CAST(GETDATE() AS DATE));

    BEGIN TRY
        DELETE FROM hr_performance_summary 
        WHERE metric_date = @v_metric_date;

        INSERT INTO hr_performance_summary (
            metric_date, employee_key, department, geography_key, job_title,
            is_active_employee, tenure_months,
            productivity_score, productivity_per_employee, sales_per_rep,
            quota_attainment_pct, engagement_score, performance_rating,
            training_hours_ytd, certifications_count, promotion_eligible,
            is_turnover_risk, voluntary_turnover_flag, salary_grade, bonus_target_pct
        )
        SELECT
            @v_metric_date,
            de.employee_key,
            de.department,
            dg.geography_key,
            de.job_title,
            de.is_active,
            DATEDIFF(MONTH, de.hire_date, @v_metric_date),
            ISNULL(sps.yoy_growth_pct, 50),
            ISNULL(sps.total_sales_amount / NULLIF(COUNT(DISTINCT sps.employee_key), 0), 0),
            ISNULL(AVG(sps.total_sales_amount), 0),
            CASE 
                WHEN ISNULL(AVG(sps.total_sales_amount), 0) > 0 THEN 100.0
                ELSE 50.0
            END,
            ISNULL(fhm.engagement_score, 50),
            CASE 
                WHEN ISNULL(ISNULL(sps.yoy_growth_pct, 0), 0) >= 90 THEN 'Exceeds'
                WHEN ISNULL(ISNULL(sps.yoy_growth_pct, 0), 0) >= 80 THEN 'Meets'
                ELSE 'Below'
            END,
            ISNULL(fhm.training_hours_ytd, 0),
            ISNULL(fhm.certifications_count, 0),
            CASE WHEN DATEDIFF(YEAR, de.hire_date, @v_metric_date) >= 2 THEN 1 ELSE 0 END,
            CASE WHEN de.is_active = 0 THEN 1 ELSE 0 END,
            0,
            de.salary_grade,
            0.15
        FROM dim_employee de
        LEFT JOIN dim_geography dg ON de.region = dg.region AND dg.is_current = 1
        LEFT JOIN sales_performance_summary sps ON de.employee_key = sps.employee_key AND sps.metric_date = @v_metric_date
        LEFT JOIN fact_hr_metrics fhm ON de.employee_key = fhm.employee_key AND fhm.metric_date = @v_metric_date
        WHERE de.is_current = 1
        GROUP BY de.employee_key, de.department, dg.geography_key, de.job_title, de.is_active,
                 DATEDIFF(MONTH, de.hire_date, @v_metric_date),
                 ISNULL(sps.yoy_growth_pct, 50), ISNULL(sps.total_sales_amount, 0),
                 ISNULL(fhm.engagement_score, 50), ISNULL(fhm.training_hours_ytd, 0),
                 ISNULL(fhm.certifications_count, 0), de.salary_grade;

        PRINT 'HR Performance Summary populated for: ' + CONVERT(VARCHAR, @v_metric_date);
    END TRY
    BEGIN CATCH
        PRINT 'Error in sp_populate_hr_performance_summary: ' + ERROR_MESSAGE();
        THROW;
    END CATCH;
END;
GO

-- ============================================================================
-- PROCEDURE 7: sp_refresh_all_kpi_metrics
-- Purpose: Master procedure to refresh all KPI aggregations for a specific date
-- Schedule: Daily (after fact load completion)
-- ============================================================================
CREATE PROCEDURE sp_refresh_all_kpi_metrics (
    @p_metric_date DATE = NULL,
    @p_verbose BIT = 0
)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @v_metric_date DATE = ISNULL(@p_metric_date, CAST(GETDATE() AS DATE));
    DECLARE @v_start_time DATETIME = GETDATE();

    BEGIN TRY
        IF @p_verbose = 1
            PRINT '=== Starting KPI Refresh for: ' + CONVERT(VARCHAR, @v_metric_date) + ' ===';

        -- Step 1: Populate base metrics
        EXEC sp_populate_financial_metrics_summary @v_metric_date;
        EXEC sp_populate_sales_performance_summary @v_metric_date;
        EXEC sp_populate_customer_success_summary @v_metric_date;
        EXEC sp_populate_operational_metrics_summary @v_metric_date;
        EXEC sp_populate_hr_performance_summary @v_metric_date;

        -- Step 2: Populate KPI summary
        EXEC sp_populate_daily_kpi_summary @v_metric_date;

        IF @p_verbose = 1
        BEGIN
            DECLARE @v_duration INT = DATEDIFF(SECOND, @v_start_time, GETDATE());
            PRINT '=== KPI Refresh Completed in ' + CONVERT(VARCHAR, @v_duration) + ' seconds ===';
        END;

    END TRY
    BEGIN CATCH
        PRINT 'Error in sp_refresh_all_kpi_metrics: ' + ERROR_MESSAGE();
        THROW;
    END CATCH;
END;
GO
