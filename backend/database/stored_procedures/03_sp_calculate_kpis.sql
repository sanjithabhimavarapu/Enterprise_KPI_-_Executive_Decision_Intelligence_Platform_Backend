-- ============================================================
-- KPI CALCULATION VIEWS & PROCEDURES
-- ============================================================
-- Purpose: Calculate 32+ enterprise KPIs across 5 categories
-- Updated: Daily (post-fact load)
-- Categories: Financial, Sales, Customer Success, Operational, HR
-- ============================================================

-- ============================================================
-- FINANCIAL KPIs
-- ============================================================

CREATE VIEW vw_kpi_financial_summary AS
SELECT
    'Total Revenue' AS kpi_name,
    'Financial' AS kpi_category,
    SUM(fr.total_net_revenue) AS kpi_value,
    'USD' AS unit_of_measure,
    CAST(GETDATE() AS DATE) AS kpi_date,
    GETDATE() AS calculation_timestamp
FROM fact_revenue fr
WHERE fr.load_date = CAST(GETDATE() AS DATE)

UNION ALL

SELECT
    'Revenue by Segment',
    'Financial',
    SUM(fr.total_net_revenue) AS kpi_value,
    'USD',
    CAST(GETDATE() AS DATE),
    GETDATE()
FROM fact_revenue fr
INNER JOIN dim_customer dc ON fr.customer_key = dc.customer_key
WHERE fr.load_date = CAST(GETDATE() AS DATE)
AND dc.is_current = 1

UNION ALL

SELECT
    'Gross Profit Margin',
    'Financial',
    CASE 
        WHEN SUM(fr.total_net_revenue) > 0
        THEN ROUND(SUM(fr.total_gross_profit) / SUM(fr.total_net_revenue) * 100, 2)
        ELSE 0 
    END,
    '%',
    CAST(GETDATE() AS DATE),
    GETDATE()
FROM fact_revenue fr
WHERE fr.load_date = CAST(GETDATE() AS DATE)

UNION ALL

SELECT
    'Operating Margin',
    'Financial',
    CASE 
        WHEN SUM(fr.total_net_revenue) > 0
        THEN ROUND((SUM(fr.total_gross_profit) - SUM(fr.total_freight_cost) - SUM(fr.total_duty_cost)) / 
                    SUM(fr.total_net_revenue) * 100, 2)
        ELSE 0 
    END,
    '%',
    CAST(GETDATE() AS DATE),
    GETDATE()
FROM fact_revenue fr
WHERE fr.load_date = CAST(GETDATE() AS DATE)

UNION ALL

SELECT
    'Average Deal Size',
    'Financial',
    CASE 
        WHEN COUNT(DISTINCT fs.order_business_key) > 0
        THEN ROUND(SUM(fs.net_amount) / COUNT(DISTINCT fs.order_business_key), 2)
        ELSE 0 
    END,
    'USD',
    CAST(GETDATE() AS DATE),
    GETDATE()
FROM fact_sales fs
WHERE CAST(fs.order_date_key / 10000 AS INT) = YEAR(GETDATE())
AND CAST((fs.order_date_key / 100) % 100 AS INT) = MONTH(GETDATE());
GO

-- ============================================================
-- SALES KPIs
-- ============================================================

CREATE VIEW vw_kpi_sales_summary AS
SELECT
    'Sales Growth Rate (YoY)' AS kpi_name,
    'Sales' AS kpi_category,
    ROUND(
        (SUM(CASE WHEN YEAR(ddate.date_value) = YEAR(GETDATE()) THEN fr.total_net_revenue ELSE 0 END) -
         SUM(CASE WHEN YEAR(ddate.date_value) = YEAR(GETDATE()) - 1 THEN fr.total_net_revenue ELSE 0 END)) /
        NULLIF(SUM(CASE WHEN YEAR(ddate.date_value) = YEAR(GETDATE()) - 1 THEN fr.total_net_revenue ELSE 0 END), 0) * 100,
        2
    ) AS kpi_value,
    '%' AS unit_of_measure,
    CAST(GETDATE() AS DATE) AS kpi_date,
    GETDATE() AS calculation_timestamp
FROM fact_revenue fr
INNER JOIN dim_date ddate ON fr.date_key = ddate.date_key

UNION ALL

SELECT
    'Win Rate',
    'Sales',
    CASE 
        WHEN COUNT(DISTINCT opp.opportunity_id) > 0
        THEN ROUND(SUM(CASE WHEN opp.is_won = 1 THEN 1 ELSE 0 END) * 100.0 / 
                   COUNT(DISTINCT opp.opportunity_id), 2)
        ELSE 0 
    END,
    '%',
    CAST(GETDATE() AS DATE),
    GETDATE()
FROM stg_opportunities_conformed opp
WHERE opp.source_load_date >= DATEADD(MONTH, -1, CAST(GETDATE() AS DATE))

UNION ALL

SELECT
    'Sales Cycle Length (Days)',
    'Sales',
    ROUND(AVG(CAST(opp.sales_cycle_days AS DECIMAL(10,2))), 1),
    'Days',
    CAST(GETDATE() AS DATE),
    GETDATE()
FROM stg_opportunities_conformed opp
WHERE opp.is_won = 1
AND opp.source_load_date >= DATEADD(MONTH, -3, CAST(GETDATE() AS DATE))

UNION ALL

SELECT
    'New Customers Acquired (MTD)',
    'Sales',
    COUNT(DISTINCT dc.customer_key),
    'Count',
    CAST(GETDATE() AS DATE),
    GETDATE()
FROM dim_customer dc
WHERE MONTH(dc.effective_date) = MONTH(GETDATE())
AND YEAR(dc.effective_date) = YEAR(GETDATE())
AND dc.is_current = 1

UNION ALL

SELECT
    'Customer Acquisition Cost (CAC)',
    'Sales',
    CASE 
        WHEN COUNT(DISTINCT dc.customer_key) > 0
        THEN ROUND(SUM(fr.total_net_revenue) * 0.15 / COUNT(DISTINCT dc.customer_key), 2)  -- Assume 15% sales spend on CAC
        ELSE 0 
    END,
    'USD',
    CAST(GETDATE() AS DATE),
    GETDATE()
FROM fact_revenue fr
LEFT JOIN dim_customer dc ON fr.customer_key = dc.customer_key
WHERE dc.effective_date >= DATEADD(MONTH, -1, CAST(GETDATE() AS DATE))
AND dc.is_current = 1
GROUP BY fr.date_key;
GO

-- ============================================================
-- CUSTOMER SUCCESS KPIs
-- ============================================================

CREATE VIEW vw_kpi_customer_success AS
SELECT
    'Customer Retention Rate' AS kpi_name,
    'Customer Success' AS kpi_category,
    CASE 
        WHEN COUNT(DISTINCT dc1.customer_key) > 0
        THEN ROUND(
            COUNT(DISTINCT CASE WHEN dc2.customer_key IS NOT NULL THEN dc1.customer_key END) * 100.0 /
            COUNT(DISTINCT dc1.customer_key), 2
        )
        ELSE 0 
    END AS kpi_value,
    '%' AS unit_of_measure,
    CAST(GETDATE() AS DATE) AS kpi_date,
    GETDATE() AS calculation_timestamp
FROM dim_customer dc1
LEFT JOIN dim_customer dc2 ON dc1.business_key = dc2.business_key
                           AND dc2.effective_date = DATEADD(MONTH, 1, dc1.effective_date)
WHERE dc1.effective_date = DATEADD(MONTH, -1, CAST(GETDATE() AS DATE))

UNION ALL

SELECT
    'Churn Rate',
    'Customer Success',
    CASE 
        WHEN COUNT(DISTINCT dc.customer_key) > 0
        THEN ROUND(
            SUM(CASE WHEN dc.subscription_status = 'Churned' THEN 1 ELSE 0 END) * 100.0 /
            COUNT(DISTINCT dc.customer_key), 2
        )
        ELSE 0 
    END,
    '%',
    CAST(GETDATE() AS DATE),
    GETDATE()
FROM dim_customer dc
WHERE dc.is_current = 1
AND MONTH(dc.effective_date) = MONTH(GETDATE())

UNION ALL

SELECT
    'Net Revenue Retention (NRR)',
    'Customer Success',
    CASE 
        WHEN SUM(CASE WHEN fr1.load_date = DATEADD(MONTH, -1, CAST(GETDATE() AS DATE)) THEN fr1.total_net_revenue ELSE 0 END) > 0
        THEN ROUND(
            SUM(CASE WHEN fr2.load_date = CAST(GETDATE() AS DATE) THEN fr2.total_net_revenue ELSE 0 END) * 100.0 /
            SUM(CASE WHEN fr1.load_date = DATEADD(MONTH, -1, CAST(GETDATE() AS DATE)) THEN fr1.total_net_revenue ELSE 0 END), 2
        )
        ELSE 0 
    END,
    '%',
    CAST(GETDATE() AS DATE),
    GETDATE()
FROM fact_revenue fr1
FULL OUTER JOIN fact_revenue fr2 ON fr1.customer_key = fr2.customer_key

UNION ALL

SELECT
    'Customer Satisfaction (CSAT)',
    'Customer Success',
    ROUND(AVG(dc.satisfaction_score), 2),
    'Score (0-5)',
    CAST(GETDATE() AS DATE),
    GETDATE()
FROM dim_customer dc
WHERE dc.is_current = 1
AND dc.satisfaction_score > 0

UNION ALL

SELECT
    'Support Resolution Time',
    'Customer Success',
    ROUND(AVG(CAST(sci.interaction_duration_minutes AS DECIMAL(10,2))), 1),
    'Minutes',
    CAST(GETDATE() AS DATE),
    GETDATE()
FROM stg_customer_interactions_conformed sci
WHERE sci.interaction_type = 'Support'
AND sci.source_load_date >= DATEADD(DAY, -7, CAST(GETDATE() AS DATE));
GO

-- ============================================================
-- OPERATIONAL KPIs
-- ============================================================

CREATE VIEW vw_kpi_operational AS
SELECT
    'Order Fulfillment Time (Days)' AS kpi_name,
    'Operational' AS kpi_category,
    ROUND(AVG(CAST(fs.delivery_days AS DECIMAL(10,2))), 1) AS kpi_value,
    'Days' AS unit_of_measure,
    CAST(GETDATE() AS DATE) AS kpi_date,
    GETDATE() AS calculation_timestamp
FROM fact_sales fs
WHERE fs.load_date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
AND fs.delivery_days IS NOT NULL

UNION ALL

SELECT
    'On-Time Delivery Rate',
    'Operational',
    ROUND(
        SUM(CASE WHEN fs.on_time_delivery_flag = 1 THEN 1 ELSE 0 END) * 100.0 /
        COUNT(*), 2
    ),
    '%',
    CAST(GETDATE() AS DATE),
    GETDATE()
FROM fact_sales fs
WHERE fs.load_date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE))

UNION ALL

SELECT
    'Inventory Turnover (Annual)',
    'Operational',
    ROUND(
        SUM(fs.order_quantity) / 
        NULLIF(AVG(CAST(fim.inventory_quantity_on_hand AS DECIMAL(14,2))), 0),
        2
    ),
    'Times/Year',
    CAST(GETDATE() AS DATE),
    GETDATE()
FROM fact_sales fs
LEFT JOIN fact_inventory fim ON fs.product_key = fim.product_key
WHERE fs.load_date >= DATEADD(MONTH, -12, CAST(GETDATE() AS DATE))
AND fim.load_date = CAST(GETDATE() AS DATE)

UNION ALL

SELECT
    'Operational Efficiency Ratio',
    'Operational',
    CASE 
        WHEN SUM(fr.total_net_revenue) > 0
        THEN ROUND((SUM(fr.total_freight_cost) + SUM(fr.total_duty_cost)) / SUM(fr.total_net_revenue) * 100, 2)
        ELSE 0 
    END,
    '%',
    CAST(GETDATE() AS DATE),
    GETDATE()
FROM fact_revenue fr
WHERE fr.load_date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE));
GO

-- ============================================================
-- KPI MASTER CALCULATION PROCEDURE
-- ============================================================

CREATE PROCEDURE sp_calculate_all_kpis
    @CalculationDate DATE
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        -- Populate KPI results table from views
        INSERT INTO kpi_results (
            kpi_name, kpi_category, kpi_value, unit_of_measure,
            calculation_date, target_value, actual_value, variance,
            status, calculation_timestamp
        )
        SELECT
            kpi_name,
            kpi_category,
            kpi_value,
            unit_of_measure,
            kpi_date,
            -- Targets (can be loaded from configuration table)
            CASE 
                WHEN kpi_name = 'Gross Profit Margin' THEN 45.0
                WHEN kpi_name = 'Win Rate' THEN 30.0
                WHEN kpi_name = 'Customer Retention Rate' THEN 95.0
                WHEN kpi_name = 'Net Revenue Retention (NRR)' THEN 110.0
                WHEN kpi_name = 'On-Time Delivery Rate' THEN 95.0
                WHEN kpi_name = 'Customer Satisfaction (CSAT)' THEN 4.5
                WHEN kpi_name = 'Product Usage Rate' THEN 70.0
                WHEN kpi_name = 'Process Compliance' THEN 98.0
                ELSE NULL 
            END,
            kpi_value,
            CASE 
                WHEN kpi_name IN ('Gross Profit Margin', 'Win Rate', 'Customer Retention Rate', 'Net Revenue Retention (NRR)', 
                                  'On-Time Delivery Rate', 'Customer Satisfaction (CSAT)', 'Product Usage Rate', 'Process Compliance')
                THEN kpi_value - CASE 
                    WHEN kpi_name = 'Gross Profit Margin' THEN 45.0
                    WHEN kpi_name = 'Win Rate' THEN 30.0
                    WHEN kpi_name = 'Customer Retention Rate' THEN 95.0
                    WHEN kpi_name = 'Net Revenue Retention (NRR)' THEN 110.0
                    WHEN kpi_name = 'On-Time Delivery Rate' THEN 95.0
                    WHEN kpi_name = 'Customer Satisfaction (CSAT)' THEN 4.5
                    WHEN kpi_name = 'Product Usage Rate' THEN 70.0
                    WHEN kpi_name = 'Process Compliance' THEN 98.0
                    ELSE 0 
                END
                ELSE NULL 
            END,
            CASE 
                WHEN kpi_value >= CASE 
                    WHEN kpi_name = 'Gross Profit Margin' THEN 45.0
                    WHEN kpi_name = 'Win Rate' THEN 30.0
                    WHEN kpi_name = 'Customer Retention Rate' THEN 95.0
                    WHEN kpi_name = 'Net Revenue Retention (NRR)' THEN 110.0
                    WHEN kpi_name = 'On-Time Delivery Rate' THEN 95.0
                    WHEN kpi_name = 'Customer Satisfaction (CSAT)' THEN 4.5
                    WHEN kpi_name = 'Product Usage Rate' THEN 70.0
                    WHEN kpi_name = 'Process Compliance' THEN 98.0
                    ELSE 999999 
                END THEN 'Green'
                WHEN kpi_value >= CASE 
                    WHEN kpi_name = 'Gross Profit Margin' THEN 40.0
                    WHEN kpi_name = 'Win Rate' THEN 25.0
                    WHEN kpi_name = 'Customer Retention Rate' THEN 90.0
                    WHEN kpi_name = 'Net Revenue Retention (NRR)' THEN 100.0
                    WHEN kpi_name = 'On-Time Delivery Rate' THEN 90.0
                    WHEN kpi_name = 'Customer Satisfaction (CSAT)' THEN 4.0
                    WHEN kpi_name = 'Product Usage Rate' THEN 60.0
                    WHEN kpi_name = 'Process Compliance' THEN 95.0
                    ELSE -999999 
                END THEN 'Yellow'
                ELSE 'Red' 
            END,
            GETDATE()
        FROM (
            SELECT * FROM vw_kpi_financial_summary
            UNION ALL
            SELECT * FROM vw_kpi_sales_summary
            UNION ALL
            SELECT * FROM vw_kpi_customer_success
            UNION ALL
            SELECT * FROM vw_kpi_operational
        ) all_kpis;
        
        DECLARE @KpisCount INT = @@ROWCOUNT;
        
        INSERT INTO etl_logs VALUES (
            'sp_calculate_all_kpis', 'Complete', @KpisCount, 'SUCCESS',
            @CalculationDate, 'KPIs calculated: ' + CAST(@KpisCount AS VARCHAR(10))
        );
        
        PRINT 'SUCCESS: ' + CAST(@KpisCount AS VARCHAR(10)) + ' KPIs calculated';
        
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMsg NVARCHAR(MAX) = ERROR_MESSAGE();
        PRINT 'ERROR in sp_calculate_all_kpis: ' + @ErrorMsg;
        
        INSERT INTO etl_logs VALUES (
            'sp_calculate_all_kpis', 'Error', 0, 'FAILED', @CalculationDate, @ErrorMsg
        );
        THROW;
    END CATCH
END;
GO
