-- ============================================================================
-- EXECUTIVE REPORTING PROCEDURES
-- Enterprise KPI - Executive Decision Intelligence Platform
-- Purpose: Pre-built reporting procedures for C-level dashboards
-- ============================================================================

-- ============================================================================
-- FINANCIAL REPORTING PROCEDURES
-- ============================================================================

-- Procedure: Get Daily Financial Performance Report
-- Purpose: Executive summary of daily financial metrics
-- Usage: EXEC sp_get_daily_financial_report @p_report_date = '2026-05-29', @p_include_comparison = 1
CREATE PROCEDURE sp_get_daily_financial_report
    @p_report_date DATE,
    @p_include_comparison BIT = 1,
    @p_verbose BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        IF @p_verbose = 1
            PRINT 'Starting Daily Financial Report for ' + CAST(@p_report_date AS VARCHAR(10));
        
        SELECT 
            'Daily Financial Report' AS report_title,
            @p_report_date AS report_date,
            GETDATE() AS report_generated_ts,
            'Executive Finance' AS report_category
        
        UNION ALL
        
        -- Current Day Metrics
        SELECT 
            'CURRENT DAY METRICS' AS report_title,
            @p_report_date,
            NULL,
            NULL
        
        UNION ALL
        
        SELECT 
            CONCAT('Total Revenue: $', FORMAT(dfs.daily_revenue, 'N2')) AS report_title,
            @p_report_date,
            NULL,
            'Revenue'
        FROM vw_daily_financial_summary dfs
        WHERE dfs.date_value = @p_report_date
        
        UNION ALL
        
        SELECT 
            CONCAT('Gross Profit: $', FORMAT(dfs.gross_profit, 'N2')) AS report_title,
            @p_report_date,
            NULL,
            'Profitability'
        FROM vw_daily_financial_summary dfs
        WHERE dfs.date_value = @p_report_date
        
        UNION ALL
        
        SELECT 
            CONCAT('Gross Margin: ', FORMAT(dfs.gross_margin_pct, 'N2'), '%') AS report_title,
            @p_report_date,
            NULL,
            'Profitability'
        FROM vw_daily_financial_summary dfs
        WHERE dfs.date_value = @p_report_date;
        
        IF @p_include_comparison = 1
        BEGIN
            SELECT 
                'COMPARISON METRICS' AS metric_category,
                'Prior Day' AS comparison_period,
                (SELECT daily_revenue FROM vw_daily_financial_summary 
                 WHERE date_value = DATEADD(DAY, -1, @p_report_date)) AS revenue_prior_day,
                (SELECT daily_revenue FROM vw_daily_financial_summary 
                 WHERE date_value = @p_report_date) AS revenue_current_day,
                ROUND(
                    ((SELECT daily_revenue FROM vw_daily_financial_summary 
                      WHERE date_value = @p_report_date) - 
                     (SELECT daily_revenue FROM vw_daily_financial_summary 
                      WHERE date_value = DATEADD(DAY, -1, @p_report_date))) /
                    NULLIF((SELECT daily_revenue FROM vw_daily_financial_summary 
                            WHERE date_value = DATEADD(DAY, -1, @p_report_date)), 0) * 100, 2) AS growth_pct;
        END;
        
        IF @p_verbose = 1
            PRINT 'Daily Financial Report completed successfully';
            
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        PRINT 'ERROR: ' + @ErrorMessage;
        THROW;
    END CATCH;
END;
GO

-- Procedure: Get Monthly Financial Performance Report
-- Purpose: Detailed monthly financial analysis by segment and geography
-- Usage: EXEC sp_get_monthly_financial_report @p_year = 2026, @p_month = 5
CREATE PROCEDURE sp_get_monthly_financial_report
    @p_year INT,
    @p_month INT,
    @p_verbose BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        IF @p_verbose = 1
            PRINT 'Generating Monthly Financial Report for ' + CAST(@p_year AS VARCHAR(4)) + '-' + CAST(@p_month AS VARCHAR(2));
        
        -- Overall Monthly Metrics
        SELECT 
            'Monthly Financial Performance' AS report_section,
            'OVERALL SUMMARY' AS metric_category,
            CAST(NULL AS VARCHAR(50)) AS segment,
            CAST(NULL AS VARCHAR(50)) AS geography,
            CAST(NULL AS VARCHAR(50)) AS sub_dimension,
            SUM(month_revenue) AS total_revenue,
            SUM(net_revenue) AS net_revenue,
            SUM(gross_profit) AS gross_profit,
            ROUND(AVG(gross_margin_pct), 2) AS avg_gross_margin_pct,
            SUM(unique_customers) AS total_customers,
            SUM(total_transactions) AS total_transactions
        FROM vw_monthly_financial_segment_summary
        WHERE year = @p_year AND month = @p_month
        GROUP BY year, month
        
        UNION ALL
        
        -- By Segment
        SELECT 
            'By Customer Segment',
            'SEGMENT ANALYSIS',
            customer_segment,
            NULL,
            NULL,
            month_revenue,
            net_revenue,
            gross_profit,
            gross_margin_pct,
            unique_customers,
            total_transactions
        FROM vw_monthly_financial_segment_summary
        WHERE year = @p_year AND month = @p_month
        ORDER BY month_revenue DESC;
        
        -- By Geography
        SELECT 
            'By Geography' AS report_section,
            'GEOGRAPHIC ANALYSIS' AS metric_category,
            NULL AS segment,
            rgs.country,
            rgs.state_province,
            rgs.segment_revenue AS total_revenue,
            NULL AS net_revenue,
            NULL AS gross_profit,
            rgs.profit_margin_pct AS avg_gross_margin_pct,
            rgs.customer_count AS total_customers,
            rgs.transaction_count AS total_transactions
        FROM vw_revenue_geography_segment_analysis rgs
        WHERE rgs.year = @p_year AND rgs.month = @p_month
        ORDER BY rgs.segment_revenue DESC;
        
        IF @p_verbose = 1
            PRINT 'Monthly Financial Report completed successfully';
            
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        PRINT 'ERROR: ' + @ErrorMessage;
        THROW;
    END CATCH;
END;
GO

-- ============================================================================
-- SALES ANALYTICS PROCEDURES
-- ============================================================================

-- Procedure: Get Top Performers Report
-- Purpose: Sales performance rankings and trends
-- Usage: EXEC sp_get_top_performers_report @p_metric = 'Sales', @p_limit = 10
CREATE PROCEDURE sp_get_top_performers_report
    @p_metric VARCHAR(50) = 'Sales', -- 'Sales', 'Profit', 'Orders'
    @p_limit INT = 10,
    @p_year INT = NULL,
    @p_month INT = NULL,
    @p_verbose BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        IF @p_year IS NULL SET @p_year = YEAR(GETDATE());
        IF @p_month IS NULL SET @p_month = MONTH(GETDATE());
        
        IF @p_verbose = 1
            PRINT 'Generating Top Performers Report for ' + @p_metric;
        
        IF @p_metric = 'Sales'
        BEGIN
            SELECT TOP (@p_limit)
                employee_name,
                job_title,
                department,
                year,
                month,
                total_orders,
                total_sales,
                total_profit,
                avg_deal_size,
                profit_margin_pct,
                unique_customers,
                ROW_NUMBER() OVER (ORDER BY total_sales DESC) AS sales_rank
            FROM vw_employee_sales_performance
            WHERE year = @p_year AND month = @p_month
            ORDER BY total_sales DESC;
        END
        ELSE IF @p_metric = 'Profit'
        BEGIN
            SELECT TOP (@p_limit)
                employee_name,
                job_title,
                department,
                year,
                month,
                total_orders,
                total_sales,
                total_profit,
                avg_deal_size,
                profit_margin_pct,
                unique_customers,
                ROW_NUMBER() OVER (ORDER BY total_profit DESC) AS profit_rank
            FROM vw_employee_sales_performance
            WHERE year = @p_year AND month = @p_month
            ORDER BY total_profit DESC;
        END
        ELSE IF @p_metric = 'Orders'
        BEGIN
            SELECT TOP (@p_limit)
                employee_name,
                job_title,
                department,
                year,
                month,
                total_orders,
                total_sales,
                total_profit,
                avg_deal_size,
                profit_margin_pct,
                unique_customers,
                ROW_NUMBER() OVER (ORDER BY total_orders DESC) AS order_rank
            FROM vw_employee_sales_performance
            WHERE year = @p_year AND month = @p_month
            ORDER BY total_orders DESC;
        END;
        
        IF @p_verbose = 1
            PRINT 'Top Performers Report completed successfully';
            
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        PRINT 'ERROR: ' + @ErrorMessage;
        THROW;
    END CATCH;
END;
GO

-- ============================================================================
-- CUSTOMER INTELLIGENCE PROCEDURES
-- ============================================================================

-- Procedure: Get Customer Insights Report
-- Purpose: Revenue analysis and churn risk assessment
-- Usage: EXEC sp_get_customer_insights_report @p_segment = 'Enterprise', @p_limit = 20
CREATE PROCEDURE sp_get_customer_insights_report
    @p_segment VARCHAR(50) = NULL, -- Filter by segment: Enterprise, Mid-Market, SMB, Startup
    @p_limit INT = 20,
    @p_include_churn_risk BIT = 1,
    @p_verbose BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        IF @p_verbose = 1
            PRINT 'Generating Customer Insights Report';
        
        -- Top Revenue Customers
        SELECT 
            'Top Revenue Customers' AS report_section,
            customer_name,
            customer_segment,
            industry,
            region,
            monthly_revenue,
            monthly_profit,
            profit_margin_pct,
            monthly_orders,
            products_purchased,
            annual_contract_value,
            customer_lifetime_value,
            ROW_NUMBER() OVER (ORDER BY monthly_revenue DESC) AS customer_rank
        FROM vw_customer_revenue_analysis
        WHERE (@p_segment IS NULL OR customer_segment = @p_segment)
        AND YEAR(GETDATE()) = year
        AND MONTH(GETDATE()) = month
        ORDER BY monthly_revenue DESC
        OFFSET 0 ROWS FETCH NEXT @p_limit ROWS ONLY;
        
        IF @p_include_churn_risk = 1
        BEGIN
            -- Customer Churn Risk
            SELECT 
                'Customer Churn Risk' AS report_section,
                customer_name,
                churn_risk_level,
                subscription_status,
                days_since_last_order,
                purchase_frequency_months,
                total_lifetime_sales,
                avg_order_value,
                annual_contract_value
            FROM vw_customer_churn_risk
            WHERE subscription_status IN ('Active', 'At Risk')
            AND (@p_segment IS NULL OR customer_name IN 
                (SELECT customer_name FROM vw_customer_revenue_analysis 
                 WHERE customer_segment = @p_segment))
            ORDER BY churn_risk_level DESC, days_since_last_order DESC
            OFFSET 0 ROWS FETCH NEXT @p_limit ROWS ONLY;
        END;
        
        IF @p_verbose = 1
            PRINT 'Customer Insights Report completed successfully';
            
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        PRINT 'ERROR: ' + @ErrorMessage;
        THROW;
    END CATCH;
END;
GO

-- ============================================================================
-- OPERATIONAL METRICS PROCEDURES
-- ============================================================================

-- Procedure: Get Inventory Health Report
-- Purpose: Current inventory status and reorder requirements
-- Usage: EXEC sp_get_inventory_health_report @p_include_forecast = 1
CREATE PROCEDURE sp_get_inventory_health_report
    @p_include_low_stock BIT = 1,
    @p_include_overstock BIT = 1,
    @p_verbose BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        IF @p_verbose = 1
            PRINT 'Generating Inventory Health Report';
        
        -- Overall Inventory Status
        SELECT 
            'Inventory Health Summary' AS report_section,
            COUNT(*) AS total_products,
            SUM(CASE WHEN inventory_status = 'ADEQUATE' THEN 1 ELSE 0 END) AS adequate_stock,
            SUM(CASE WHEN inventory_status = 'LOW_STOCK' THEN 1 ELSE 0 END) AS low_stock_products,
            SUM(CASE WHEN inventory_status = 'REORDER NEEDED' THEN 1 ELSE 0 END) AS reorder_needed,
            ROUND(
                SUM(CASE WHEN inventory_status = 'ADEQUATE' THEN 1 ELSE 0 END) * 100.0 / 
                NULLIF(COUNT(*), 0), 2) AS health_percentage
        FROM vw_current_inventory_status;
        
        IF @p_include_low_stock = 1
        BEGIN
            -- Low Stock Items
            SELECT 
                'Low Stock Products' AS report_section,
                product_name,
                product_category,
                warehouse_location_id,
                current_inventory,
                reorder_point,
                inventory_status,
                lead_time_days,
                CASE 
                    WHEN current_inventory = 0 THEN 'URGENT'
                    WHEN current_inventory < reorder_point THEN 'IMMEDIATE'
                    ELSE 'SOON'
                END AS action_required
            FROM vw_current_inventory_status
            WHERE inventory_status IN ('LOW_STOCK', 'REORDER NEEDED')
            ORDER BY current_inventory ASC;
        END;
        
        IF @p_verbose = 1
            PRINT 'Inventory Health Report completed successfully';
            
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        PRINT 'ERROR: ' + @ErrorMessage;
        THROW;
    END CATCH;
END;
GO

-- ============================================================================
-- PRODUCT ANALYTICS PROCEDURES
-- ============================================================================

-- Procedure: Get Product Performance Report
-- Purpose: Detailed product category and SKU analysis
-- Usage: EXEC sp_get_product_performance_report @p_year = 2026, @p_month = 5
CREATE PROCEDURE sp_get_product_performance_report
    @p_year INT = NULL,
    @p_month INT = NULL,
    @p_order_by VARCHAR(50) = 'SALES', -- SALES, PROFIT, UNITS, MARGIN
    @p_verbose BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        IF @p_year IS NULL SET @p_year = YEAR(GETDATE());
        IF @p_month IS NULL SET @p_month = MONTH(GETDATE());
        
        IF @p_verbose = 1
            PRINT 'Generating Product Performance Report';
        
        -- Product Category Performance
        SELECT 
            'Product Category Performance' AS report_section,
            product_category,
            product_subcategory,
            total_orders,
            total_units_sold,
            total_sales,
            total_profit,
            avg_order_value,
            profit_margin_pct,
            unique_customers,
            product_count,
            ROW_NUMBER() OVER (
                ORDER BY 
                    CASE WHEN @p_order_by = 'SALES' THEN total_sales
                         WHEN @p_order_by = 'PROFIT' THEN total_profit
                         WHEN @p_order_by = 'UNITS' THEN total_units_sold
                         WHEN @p_order_by = 'MARGIN' THEN profit_margin_pct
                         ELSE total_sales END DESC
            ) AS product_rank
        FROM vw_product_category_performance
        WHERE year = @p_year AND month = @p_month
        ORDER BY 
            CASE WHEN @p_order_by = 'SALES' THEN total_sales
                 WHEN @p_order_by = 'PROFIT' THEN total_profit
                 WHEN @p_order_by = 'UNITS' THEN total_units_sold
                 WHEN @p_order_by = 'MARGIN' THEN profit_margin_pct
                 ELSE total_sales END DESC;
        
        IF @p_verbose = 1
            PRINT 'Product Performance Report completed successfully';
            
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        PRINT 'ERROR: ' + @ErrorMessage;
        THROW;
    END CATCH;
END;
GO

-- ============================================================================
-- DATA QUALITY & MONITORING PROCEDURES
-- ============================================================================

-- Procedure: Get Sales Anomalies Report
-- Purpose: Detect unusual transactions for investigation
-- Usage: EXEC sp_get_sales_anomalies_report @p_severity = 'HIGH'
CREATE PROCEDURE sp_get_sales_anomalies_report
    @p_severity VARCHAR(20) = 'ALL', -- HIGH, MEDIUM, ALL
    @p_limit INT = 100,
    @p_verbose BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        IF @p_verbose = 1
            PRINT 'Generating Sales Anomalies Report';
        
        SELECT 
            'Sales Anomalies Detected' AS report_section,
            sales_key,
            order_id,
            date_value,
            customer_name,
            product_name,
            net_sales_amount,
            order_quantity,
            avg_sales_90day,
            stdev_sales_90day,
            anomaly_flag,
            ROUND(
                ABS(net_sales_amount - avg_sales_90day) / NULLIF(stdev_sales_90day, 0), 2
            ) AS z_score,
            CASE 
                WHEN ROUND(ABS(net_sales_amount - avg_sales_90day) / NULLIF(stdev_sales_90day, 0), 2) > 3 
                THEN 'HIGH'
                WHEN ROUND(ABS(net_sales_amount - avg_sales_90day) / NULLIF(stdev_sales_90day, 0), 2) > 2
                THEN 'MEDIUM'
                ELSE 'LOW'
            END AS severity_level
        FROM vw_sales_anomaly_detection
        WHERE anomaly_flag = 'ANOMALY_DETECTED'
        AND (@p_severity = 'ALL' OR 
             (@p_severity = 'HIGH' AND ROUND(ABS(net_sales_amount - avg_sales_90day) / NULLIF(stdev_sales_90day, 0), 2) > 3) OR
             (@p_severity = 'MEDIUM' AND ROUND(ABS(net_sales_amount - avg_sales_90day) / NULLIF(stdev_sales_90day, 0), 2) > 2))
        ORDER BY z_score DESC
        OFFSET 0 ROWS FETCH NEXT @p_limit ROWS ONLY;
        
        IF @p_verbose = 1
            PRINT 'Sales Anomalies Report completed successfully';
            
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        PRINT 'ERROR: ' + @ErrorMessage;
        THROW;
    END CATCH;
END;
GO

GO
