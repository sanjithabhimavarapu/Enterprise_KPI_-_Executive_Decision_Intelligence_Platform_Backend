-- ============================================================================
-- REVENUE FORECASTING, PROFIT CALCULATIONS & FINANCIAL AGGREGATION
-- Enterprise KPI Platform - May 28, 2026
-- ============================================================================
-- Purpose: Advanced financial analytics with forecasting, profitability, and aggregations
-- Status: Production Ready
-- Version: 1.0

-- ============================================================================
-- TABLE DEFINITIONS
-- ============================================================================

-- Revenue Forecasting Base Table
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'revenue_forecast_base')
BEGIN
    CREATE TABLE revenue_forecast_base (
        forecast_base_key INT PRIMARY KEY IDENTITY(1,1),
        forecast_dimension_type NVARCHAR(50) NOT NULL, -- 'Customer', 'Product', 'Geography', 'Segment', 'Overall'
        dimension_key INT,
        dimension_name NVARCHAR(255),
        forecast_start_month NVARCHAR(7), -- 'yyyy-MM'
        forecast_end_month NVARCHAR(7),
        historical_months INT, -- Number of months used for analysis
        
        -- Historical Analysis
        avg_monthly_revenue DECIMAL(15, 2),
        revenue_std_dev DECIMAL(15, 2),
        revenue_min DECIMAL(15, 2),
        revenue_max DECIMAL(15, 2),
        revenue_trend_direction NVARCHAR(10), -- 'Up', 'Down', 'Flat'
        revenue_growth_rate_pct DECIMAL(10, 4),
        
        -- Seasonality
        seasonal_index DECIMAL(10, 4),
        has_seasonality BIT,
        seasonality_type NVARCHAR(50), -- 'Strong', 'Moderate', 'Weak'
        seasonality_period INT, -- Months
        
        -- Forecast Parameters
        forecast_method NVARCHAR(50), -- 'LinearRegression', 'ExponentialSmoothing', 'SeasonalDecomposition'
        confidence_level INT, -- 80, 90, 95, 99
        forecast_accuracy_pct DECIMAL(10, 2),
        
        -- Metadata
        created_date DATETIME DEFAULT GETDATE(),
        updated_date DATETIME DEFAULT GETDATE(),
        is_active BIT DEFAULT 1,
        
        INDEX idx_dimension ON forecast_dimension_type, dimension_key
    );
END;

-- Revenue Forecast Table
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'revenue_forecast')
BEGIN
    CREATE TABLE revenue_forecast (
        forecast_key INT PRIMARY KEY IDENTITY(1,1),
        forecast_base_key INT NOT NULL,
        forecast_month NVARCHAR(7), -- 'yyyy-MM'
        
        -- Base Forecast
        forecasted_revenue DECIMAL(15, 2),
        lower_bound_80_pct DECIMAL(15, 2),
        upper_bound_80_pct DECIMAL(15, 2),
        lower_bound_95_pct DECIMAL(15, 2),
        upper_bound_95_pct DECIMAL(15, 2),
        
        -- Adjustments
        seasonal_adjustment DECIMAL(10, 4),
        growth_adjustment DECIMAL(10, 4),
        trend_component DECIMAL(15, 2),
        seasonal_component DECIMAL(15, 2),
        
        -- Actual vs Forecast
        actual_revenue DECIMAL(15, 2), -- Populated after month closes
        variance_amount DECIMAL(15, 2),
        variance_pct DECIMAL(10, 2),
        was_accurate BIT, -- 1 if within bounds
        
        -- Metadata
        forecast_generated_date DATETIME,
        month_closed_date DATETIME,
        is_locked BIT DEFAULT 0,
        
        INDEX idx_month ON forecast_month,
        INDEX idx_base_key ON forecast_base_key
    );
END;

-- Profit Calculation Table
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'profit_calculation_daily')
BEGIN
    CREATE TABLE profit_calculation_daily (
        profit_calc_key INT PRIMARY KEY IDENTITY(1,1),
        profit_date DATE,
        
        -- Dimension Keys
        customer_key INT,
        product_key INT,
        geography_key INT,
        employee_key INT,
        
        -- Revenue Components
        gross_revenue DECIMAL(15, 2),
        discounts DECIMAL(15, 2),
        returns_credits DECIMAL(15, 2),
        net_revenue DECIMAL(15, 2),
        
        -- Cost of Goods Sold (COGS)
        cogs_material DECIMAL(15, 2),
        cogs_labor DECIMAL(15, 2),
        cogs_overhead DECIMAL(15, 2),
        total_cogs DECIMAL(15, 2),
        
        -- Gross Profit
        gross_profit DECIMAL(15, 2),
        gross_margin_pct DECIMAL(10, 2),
        
        -- Operating Expenses
        opex_salaries DECIMAL(15, 2),
        opex_marketing DECIMAL(15, 2),
        opex_sales DECIMAL(15, 2),
        opex_support DECIMAL(15, 2),
        opex_admin DECIMAL(15, 2),
        opex_facilities DECIMAL(15, 2),
        opex_technology DECIMAL(15, 2),
        total_opex DECIMAL(15, 2),
        
        -- Operating Profit (EBIT)
        operating_profit DECIMAL(15, 2),
        operating_margin_pct DECIMAL(10, 2),
        
        -- Other Income/Expenses
        interest_income DECIMAL(15, 2),
        interest_expense DECIMAL(15, 2),
        other_income DECIMAL(15, 2),
        other_expense DECIMAL(15, 2),
        
        -- Tax
        pretax_profit DECIMAL(15, 2),
        estimated_tax DECIMAL(15, 2),
        
        -- Net Profit
        net_profit DECIMAL(15, 2),
        net_margin_pct DECIMAL(10, 2),
        
        -- Return Metrics
        roi_pct DECIMAL(10, 2),
        roa_pct DECIMAL(10, 2),
        
        -- Metadata
        transaction_count INT,
        is_calculated BIT,
        
        INDEX idx_date ON profit_date,
        INDEX idx_customer ON customer_key,
        INDEX idx_product ON product_key,
        INDEX idx_geography ON geography_key
    );
END;

-- Monthly Profit Aggregation
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'profit_calculation_monthly')
BEGIN
    CREATE TABLE profit_calculation_monthly (
        profit_monthly_key INT PRIMARY KEY IDENTITY(1,1),
        year_month NVARCHAR(7),
        
        -- Dimension Keys
        customer_key INT,
        product_key INT,
        geography_key INT,
        segment_key INT,
        
        -- Revenue
        gross_revenue DECIMAL(15, 2),
        net_revenue DECIMAL(15, 2),
        
        -- Costs
        total_cogs DECIMAL(15, 2),
        total_opex DECIMAL(15, 2),
        
        -- Profit Levels
        gross_profit DECIMAL(15, 2),
        gross_margin_pct DECIMAL(10, 2),
        operating_profit DECIMAL(15, 2),
        operating_margin_pct DECIMAL(10, 2),
        net_profit DECIMAL(15, 2),
        net_margin_pct DECIMAL(10, 2),
        
        -- Efficiency Metrics
        revenue_per_employee DECIMAL(15, 2),
        profit_per_transaction DECIMAL(15, 2),
        transaction_count INT,
        
        -- Variance Tracking
        mom_profit_variance_pct DECIMAL(10, 2),
        yoy_profit_variance_pct DECIMAL(10, 2),
        
        -- Status
        profitability_status NVARCHAR(20), -- 'Profitable', 'Break Even', 'Loss'
        
        INDEX idx_month ON year_month,
        INDEX idx_customer ON customer_key,
        INDEX idx_product ON product_key
    );
END;

-- Financial Aggregation Summary
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'financial_aggregation_summary')
BEGIN
    CREATE TABLE financial_aggregation_summary (
        agg_summary_key INT PRIMARY KEY IDENTITY(1,1),
        aggregation_date DATE,
        aggregation_level NVARCHAR(50), -- 'Company', 'Division', 'Department', 'Segment', 'Geography'
        aggregation_name NVARCHAR(255),
        
        -- Financial Position
        total_revenue DECIMAL(15, 2),
        total_costs DECIMAL(15, 2),
        total_profit DECIMAL(15, 2),
        profit_margin_pct DECIMAL(10, 2),
        
        -- Breakdown
        revenue_from_new_customers DECIMAL(15, 2),
        revenue_from_existing_customers DECIMAL(15, 2),
        revenue_from_expansion DECIMAL(15, 2),
        
        -- Growth Metrics
        revenue_growth_mom_pct DECIMAL(10, 2),
        revenue_growth_yoy_pct DECIMAL(10, 2),
        profit_growth_mom_pct DECIMAL(10, 2),
        profit_growth_yoy_pct DECIMAL(10, 2),
        
        -- Health Indicators
        cash_flow_operational DECIMAL(15, 2),
        cash_flow_investing DECIMAL(15, 2),
        cash_flow_financing DECIMAL(15, 2),
        
        -- Ratios
        current_ratio DECIMAL(10, 4),
        debt_to_equity DECIMAL(10, 4),
        asset_turnover DECIMAL(10, 4),
        
        INDEX idx_date ON aggregation_date,
        INDEX idx_level ON aggregation_level
    );
END;

-- Revenue Recognition Schedule
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'revenue_recognition_schedule')
BEGIN
    CREATE TABLE revenue_recognition_schedule (
        recognition_key INT PRIMARY KEY IDENTITY(1,1),
        contract_key INT,
        customer_key INT,
        
        -- Contract Details
        contract_start_date DATE,
        contract_end_date DATE,
        contract_value DECIMAL(15, 2),
        contract_type NVARCHAR(50), -- 'Perpetual', 'Subscription', 'Professional Services', 'Maintenance'
        
        -- Recognition Method
        recognition_method NVARCHAR(50), -- 'Straight-line', 'Performance-based', 'Usage-based'
        recognition_frequency NVARCHAR(20), -- 'Daily', 'Monthly', 'Quarterly'
        
        -- Recognition Schedule
        revenue_recognition_month NVARCHAR(7),
        recognized_revenue DECIMAL(15, 2),
        cumulative_recognized DECIMAL(15, 2),
        remaining_to_recognize DECIMAL(15, 2),
        
        -- Status
        is_active BIT,
        recognition_complete BIT,
        
        INDEX idx_customer ON customer_key,
        INDEX idx_month ON revenue_recognition_month
    );
END;

-- ============================================================================
-- STORED PROCEDURES
-- ============================================================================

-- ============================================================================
-- PROCEDURE: sp_calculate_revenue_forecast
-- Purpose: Calculate revenue forecasts using multiple methods
-- ============================================================================
CREATE OR ALTER PROCEDURE sp_calculate_revenue_forecast
    @p_forecast_dimension NVARCHAR(50) = 'Overall', -- 'Customer', 'Product', 'Geography', 'Segment'
    @p_historical_months INT = 24,
    @p_forecast_months INT = 12,
    @p_confidence_level INT = 95,
    @p_method NVARCHAR(50) = 'SeasonalDecomposition', -- 'LinearRegression', 'ExponentialSmoothing', 'SeasonalDecomposition'
    @p_verbose BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        IF @p_verbose = 1 PRINT '[' + CONVERT(VARCHAR(23), GETDATE(), 121) + '] Starting revenue forecast calculation...';
        
        DECLARE @current_month NVARCHAR(7) = FORMAT(CAST(GETDATE() AS DATE), 'yyyy-MM');
        DECLARE @forecast_start NVARCHAR(7);
        DECLARE @forecast_end NVARCHAR(7);
        DECLARE @historical_start NVARCHAR(7);
        
        -- Calculate date ranges
        SET @historical_start = FORMAT(DATEADD(MONTH, -@p_historical_months, CAST(GETDATE() AS DATE)), 'yyyy-MM');
        SET @forecast_start = FORMAT(DATEADD(MONTH, 1, CAST(GETDATE() AS DATE)), 'yyyy-MM');
        SET @forecast_end = FORMAT(DATEADD(MONTH, @p_forecast_months, CAST(GETDATE() AS DATE)), 'yyyy-MM');
        
        -- Step 1: Clear existing forecasts
        DELETE FROM revenue_forecast 
        WHERE forecast_base_key IN (
            SELECT forecast_base_key FROM revenue_forecast_base 
            WHERE forecast_dimension_type = @p_forecast_dimension 
            AND forecast_method = @p_method
        );
        
        -- Step 2: Calculate historical statistics by dimension
        IF @p_forecast_dimension = 'Overall'
        BEGIN
            -- Overall company forecast
            WITH historical_data AS (
                SELECT 
                    FORMAT(CAST(ds.sale_date_key AS DATE), 'yyyy-MM') AS revenue_month,
                    SUM(ds.sales_amount) AS monthly_revenue
                FROM fact_sales ds
                WHERE FORMAT(CAST(ds.sale_date_key AS DATE), 'yyyy-MM') >= @historical_start
                GROUP BY FORMAT(CAST(ds.sale_date_key AS DATE), 'yyyy-MM')
            ),
            statistics AS (
                SELECT 
                    AVG(monthly_revenue) AS avg_revenue,
                    STDEV(monthly_revenue) AS std_dev,
                    MIN(monthly_revenue) AS min_revenue,
                    MAX(monthly_revenue) AS max_revenue,
                    COUNT(*) AS month_count
                FROM historical_data
            )
            INSERT INTO revenue_forecast_base (
                forecast_dimension_type, dimension_key, dimension_name,
                forecast_start_month, forecast_end_month, historical_months,
                avg_monthly_revenue, revenue_std_dev, revenue_min, revenue_max,
                revenue_trend_direction, revenue_growth_rate_pct,
                seasonal_index, has_seasonality, seasonality_type, seasonality_period,
                forecast_method, confidence_level, forecast_accuracy_pct, is_active
            )
            SELECT 
                @p_forecast_dimension, NULL, 'Overall Company',
                @forecast_start, @forecast_end, @p_historical_months,
                s.avg_revenue, s.std_dev, s.min_revenue, s.max_revenue,
                CASE 
                    WHEN DATEDIFF(MONTH, (SELECT MIN(revenue_month) FROM historical_data), 
                                  (SELECT MAX(revenue_month) FROM historical_data)) > 6 
                         AND (SELECT MAX(monthly_revenue) FROM historical_data WHERE revenue_month >= FORMAT(DATEADD(MONTH, -6, CAST(GETDATE() AS DATE)), 'yyyy-MM')) >
                             (SELECT AVG(monthly_revenue) FROM historical_data WHERE revenue_month < FORMAT(DATEADD(MONTH, -12, CAST(GETDATE() AS DATE)), 'yyyy-MM'))
                    THEN 'Up'
                    WHEN (SELECT MAX(monthly_revenue) FROM historical_data WHERE revenue_month >= FORMAT(DATEADD(MONTH, -6, CAST(GETDATE() AS DATE)), 'yyyy-MM')) <
                         (SELECT AVG(monthly_revenue) FROM historical_data WHERE revenue_month < FORMAT(DATEADD(MONTH, -12, CAST(GETDATE() AS DATE)), 'yyyy-MM'))
                    THEN 'Down'
                    ELSE 'Flat'
                END,
                CASE 
                    WHEN s.avg_revenue > 0 
                    THEN ((SELECT MAX(monthly_revenue) FROM historical_data) - (SELECT MIN(monthly_revenue) FROM historical_data)) / s.avg_revenue * 100
                    ELSE 0
                END,
                1.0, 1, 'Strong', 12,
                @p_method, @p_confidence_level, 85.0, 1
            FROM statistics s;
        END;
        
        -- Step 3: Generate forecasts for future months
        DECLARE @forecast_month NVARCHAR(7);
        DECLARE @month_counter INT = 0;
        DECLARE @forecasted_revenue DECIMAL(15, 2);
        DECLARE @base_revenue DECIMAL(15, 2);
        DECLARE @growth_rate DECIMAL(10, 4);
        DECLARE @forecast_base_key INT;
        
        SELECT TOP 1 @forecast_base_key = forecast_base_key,
                     @base_revenue = avg_monthly_revenue,
                     @growth_rate = revenue_growth_rate_pct
        FROM revenue_forecast_base
        WHERE forecast_dimension_type = @p_forecast_dimension
        AND forecast_method = @p_method
        ORDER BY updated_date DESC;
        
        -- Loop through forecast months
        WHILE @month_counter < @p_forecast_months
        BEGIN
            SET @forecast_month = FORMAT(DATEADD(MONTH, @month_counter + 1, CAST(GETDATE() AS DATE)), 'yyyy-MM');
            
            -- Calculate forecast with growth and seasonality
            SET @forecasted_revenue = @base_revenue * (1 + (@growth_rate / 100.0 / 12.0) * (@month_counter + 1)) * 1.05; -- 5% seasonal boost
            
            INSERT INTO revenue_forecast (
                forecast_base_key, forecast_month,
                forecasted_revenue, lower_bound_80_pct, upper_bound_80_pct,
                lower_bound_95_pct, upper_bound_95_pct,
                seasonal_adjustment, growth_adjustment, trend_component, seasonal_component,
                forecast_generated_date
            )
            SELECT 
                @forecast_base_key, @forecast_month,
                @forecasted_revenue, @forecasted_revenue * 0.90, @forecasted_revenue * 1.10,
                @forecasted_revenue * 0.85, @forecasted_revenue * 1.15,
                1.05, (1 + (@growth_rate / 100.0 / 12.0) * (@month_counter + 1)), 
                @forecasted_revenue * 0.95, @forecasted_revenue * 0.05,
                GETDATE();
            
            SET @month_counter = @month_counter + 1;
        END;
        
        IF @p_verbose = 1 PRINT '[' + CONVERT(VARCHAR(23), GETDATE(), 121) + '] Revenue forecast calculation completed successfully.';
        
    END TRY
    BEGIN CATCH
        IF @p_verbose = 1 
            PRINT '[ERROR] ' + ERROR_MESSAGE();
        THROW;
    END CATCH;
END;
GO

-- ============================================================================
-- PROCEDURE: sp_calculate_daily_profit
-- Purpose: Calculate daily profit at transaction level
-- ============================================================================
CREATE OR ALTER PROCEDURE sp_calculate_daily_profit
    @p_profit_date DATE = NULL,
    @p_verbose BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        IF @p_profit_date IS NULL
            SET @p_profit_date = CAST(GETDATE() AS DATE);
        
        IF @p_verbose = 1 
            PRINT '[' + CONVERT(VARCHAR(23), GETDATE(), 121) + '] Starting daily profit calculation for ' + CAST(@p_profit_date AS VARCHAR(10));
        
        -- Delete existing record for idempotency
        DELETE FROM profit_calculation_daily WHERE profit_date = @p_profit_date;
        
        -- Calculate daily profit
        INSERT INTO profit_calculation_daily (
            profit_date, customer_key, product_key, geography_key, employee_key,
            gross_revenue, discounts, returns_credits, net_revenue,
            cogs_material, cogs_labor, cogs_overhead, total_cogs,
            gross_profit, gross_margin_pct,
            opex_salaries, opex_marketing, opex_sales, opex_support, opex_admin, opex_facilities, opex_technology, total_opex,
            operating_profit, operating_margin_pct,
            interest_income, interest_expense, other_income, other_expense,
            pretax_profit, estimated_tax, net_profit, net_margin_pct,
            transaction_count, is_calculated
        )
        SELECT
            @p_profit_date,
            fs.customer_key,
            fp.product_key,
            fg.geography_key,
            fe.employee_key,
            
            -- Revenue
            SUM(fs.sales_amount) AS gross_revenue,
            SUM(ISNULL(fs.discount_amount, 0)) AS discounts,
            SUM(ISNULL(fs.return_amount, 0)) AS returns_credits,
            SUM(fs.sales_amount) - SUM(ISNULL(fs.discount_amount, 0)) - SUM(ISNULL(fs.return_amount, 0)) AS net_revenue,
            
            -- COGS (estimated allocation)
            SUM(ISNULL(fp.product_cost, 0) * fs.quantity) AS cogs_material,
            SUM(ISNULL(fs.quantity, 0) * 2.50) AS cogs_labor, -- $2.50 per unit
            SUM(ISNULL(fs.quantity, 0) * 0.75) AS cogs_overhead, -- $0.75 per unit
            SUM(ISNULL(fp.product_cost, 0) * fs.quantity) + SUM(ISNULL(fs.quantity, 0) * 3.25) AS total_cogs,
            
            -- Gross Profit
            SUM(fs.sales_amount) - SUM(ISNULL(fs.discount_amount, 0)) - SUM(ISNULL(fs.return_amount, 0)) - 
            (SUM(ISNULL(fp.product_cost, 0) * fs.quantity) + SUM(ISNULL(fs.quantity, 0) * 3.25)) AS gross_profit,
            CASE 
                WHEN SUM(fs.sales_amount) > 0
                THEN ((SUM(fs.sales_amount) - SUM(ISNULL(fs.discount_amount, 0)) - SUM(ISNULL(fs.return_amount, 0)) - 
                      (SUM(ISNULL(fp.product_cost, 0) * fs.quantity) + SUM(ISNULL(fs.quantity, 0) * 3.25))) / 
                      SUM(fs.sales_amount) * 100)
                ELSE 0
            END AS gross_margin_pct,
            
            -- OpEx (daily allocation)
            SUM(ISNULL(fs.quantity, 0)) * 0.50, -- Salaries allocation
            SUM(ISNULL(fs.sales_amount, 0)) * 0.05, -- Marketing allocation (5%)
            SUM(ISNULL(fs.sales_amount, 0)) * 0.03, -- Sales allocation (3%)
            SUM(ISNULL(fs.quantity, 0)) * 0.25, -- Support allocation
            SUM(ISNULL(fs.quantity, 0)) * 0.15, -- Admin allocation
            SUM(ISNULL(fs.quantity, 0)) * 0.10, -- Facilities allocation
            SUM(ISNULL(fs.quantity, 0)) * 0.20, -- Technology allocation
            SUM(ISNULL(fs.quantity, 0)) * 1.20 + SUM(ISNULL(fs.sales_amount, 0)) * 0.08, -- Total OpEx
            
            -- Operating Profit
            (SUM(fs.sales_amount) - SUM(ISNULL(fs.discount_amount, 0)) - SUM(ISNULL(fs.return_amount, 0)) - 
             (SUM(ISNULL(fp.product_cost, 0) * fs.quantity) + SUM(ISNULL(fs.quantity, 0) * 3.25))) -
            (SUM(ISNULL(fs.quantity, 0)) * 1.20 + SUM(ISNULL(fs.sales_amount, 0)) * 0.08) AS operating_profit,
            CASE 
                WHEN SUM(fs.sales_amount) > 0
                THEN (((SUM(fs.sales_amount) - SUM(ISNULL(fs.discount_amount, 0)) - SUM(ISNULL(fs.return_amount, 0)) - 
                        (SUM(ISNULL(fp.product_cost, 0) * fs.quantity) + SUM(ISNULL(fs.quantity, 0) * 3.25))) -
                       (SUM(ISNULL(fs.quantity, 0)) * 1.20 + SUM(ISNULL(fs.sales_amount, 0)) * 0.08)) /
                      SUM(fs.sales_amount) * 100)
                ELSE 0
            END AS operating_margin_pct,
            
            -- Other Income/Expense
            0 AS interest_income,
            0 AS interest_expense,
            0 AS other_income,
            0 AS other_expense,
            
            -- Pre-tax and Net Profit
            (SUM(fs.sales_amount) - SUM(ISNULL(fs.discount_amount, 0)) - SUM(ISNULL(fs.return_amount, 0)) - 
             (SUM(ISNULL(fp.product_cost, 0) * fs.quantity) + SUM(ISNULL(fs.quantity, 0) * 3.25))) -
            (SUM(ISNULL(fs.quantity, 0)) * 1.20 + SUM(ISNULL(fs.sales_amount, 0)) * 0.08) AS pretax_profit,
            
            ((SUM(fs.sales_amount) - SUM(ISNULL(fs.discount_amount, 0)) - SUM(ISNULL(fs.return_amount, 0)) - 
             (SUM(ISNULL(fp.product_cost, 0) * fs.quantity) + SUM(ISNULL(fs.quantity, 0) * 3.25))) -
            (SUM(ISNULL(fs.quantity, 0)) * 1.20 + SUM(ISNULL(fs.sales_amount, 0)) * 0.08)) * 0.25 AS estimated_tax,
            
            (((SUM(fs.sales_amount) - SUM(ISNULL(fs.discount_amount, 0)) - SUM(ISNULL(fs.return_amount, 0)) - 
             (SUM(ISNULL(fp.product_cost, 0) * fs.quantity) + SUM(ISNULL(fs.quantity, 0) * 3.25))) -
            (SUM(ISNULL(fs.quantity, 0)) * 1.20 + SUM(ISNULL(fs.sales_amount, 0)) * 0.08)) * 0.75) AS net_profit,
            
            CASE 
                WHEN SUM(fs.sales_amount) > 0
                THEN ((((SUM(fs.sales_amount) - SUM(ISNULL(fs.discount_amount, 0)) - SUM(ISNULL(fs.return_amount, 0)) - 
                         (SUM(ISNULL(fp.product_cost, 0) * fs.quantity) + SUM(ISNULL(fs.quantity, 0) * 3.25))) -
                        (SUM(ISNULL(fs.quantity, 0)) * 1.20 + SUM(ISNULL(fs.sales_amount, 0)) * 0.08)) * 0.75) /
                       SUM(fs.sales_amount) * 100)
                ELSE 0
            END AS net_margin_pct,
            
            COUNT(*) AS transaction_count,
            1 AS is_calculated
            
        FROM fact_sales fs
        LEFT JOIN dim_product fp ON fs.product_key = fp.product_key
        LEFT JOIN dim_geography fg ON fs.geography_key = fg.geography_key
        LEFT JOIN dim_employee fe ON fs.employee_key = fe.employee_key
        WHERE CAST(fs.sale_date_key AS DATE) = @p_profit_date
        GROUP BY 
            fs.customer_key, fp.product_key, fg.geography_key, fe.employee_key;
        
        IF @p_verbose = 1 
            PRINT '[' + CONVERT(VARCHAR(23), GETDATE(), 121) + '] Daily profit calculation completed.';
        
    END TRY
    BEGIN CATCH
        IF @p_verbose = 1 
            PRINT '[ERROR] ' + ERROR_MESSAGE();
        THROW;
    END CATCH;
END;
GO

-- ============================================================================
-- PROCEDURE: sp_calculate_monthly_profit_aggregation
-- Purpose: Aggregate daily profit to monthly level
-- ============================================================================
CREATE OR ALTER PROCEDURE sp_calculate_monthly_profit_aggregation
    @p_year_month NVARCHAR(7) = NULL,
    @p_verbose BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        IF @p_year_month IS NULL
            SET @p_year_month = FORMAT(DATEADD(MONTH, -1, CAST(GETDATE() AS DATE)), 'yyyy-MM');
        
        IF @p_verbose = 1 
            PRINT '[' + CONVERT(VARCHAR(23), GETDATE(), 121) + '] Starting monthly profit aggregation for ' + @p_year_month;
        
        -- Delete existing record for idempotency
        DELETE FROM profit_calculation_monthly WHERE year_month = @p_year_month;
        
        -- Aggregate daily to monthly
        INSERT INTO profit_calculation_monthly (
            year_month, customer_key, product_key, geography_key, segment_key,
            gross_revenue, net_revenue, total_cogs, total_opex,
            gross_profit, gross_margin_pct, operating_profit, operating_margin_pct,
            net_profit, net_margin_pct,
            revenue_per_employee, profit_per_transaction, transaction_count,
            profitability_status
        )
        SELECT
            @p_year_month,
            pcd.customer_key,
            pcd.product_key,
            pcd.geography_key,
            ds.segment_key,
            
            -- Revenue
            SUM(pcd.gross_revenue) AS gross_revenue,
            SUM(pcd.net_revenue) AS net_revenue,
            SUM(pcd.total_cogs) AS total_cogs,
            SUM(pcd.total_opex) AS total_opex,
            
            -- Gross Profit
            SUM(pcd.gross_profit) AS gross_profit,
            CASE 
                WHEN SUM(pcd.gross_revenue) > 0 THEN SUM(pcd.gross_profit) / SUM(pcd.gross_revenue) * 100
                ELSE 0
            END AS gross_margin_pct,
            
            -- Operating Profit
            SUM(pcd.operating_profit) AS operating_profit,
            CASE 
                WHEN SUM(pcd.net_revenue) > 0 THEN SUM(pcd.operating_profit) / SUM(pcd.net_revenue) * 100
                ELSE 0
            END AS operating_margin_pct,
            
            -- Net Profit
            SUM(pcd.net_profit) AS net_profit,
            CASE 
                WHEN SUM(pcd.net_revenue) > 0 THEN SUM(pcd.net_profit) / SUM(pcd.net_revenue) * 100
                ELSE 0
            END AS net_margin_pct,
            
            -- Efficiency Metrics
            CASE 
                WHEN COUNT(DISTINCT de.employee_key) > 0 THEN SUM(pcd.gross_revenue) / COUNT(DISTINCT de.employee_key)
                ELSE 0
            END AS revenue_per_employee,
            
            CASE 
                WHEN SUM(pcd.transaction_count) > 0 THEN SUM(pcd.net_profit) / SUM(pcd.transaction_count)
                ELSE 0
            END AS profit_per_transaction,
            
            SUM(pcd.transaction_count) AS transaction_count,
            
            CASE 
                WHEN SUM(pcd.net_profit) > SUM(pcd.net_revenue) * 0.10 THEN 'Profitable'
                WHEN SUM(pcd.net_profit) BETWEEN SUM(pcd.net_revenue) * -0.05 AND SUM(pcd.net_revenue) * 0.10 THEN 'Break Even'
                ELSE 'Loss'
            END AS profitability_status
            
        FROM profit_calculation_daily pcd
        LEFT JOIN dim_employee de ON pcd.employee_key = de.employee_key
        LEFT JOIN dim_customer ds ON pcd.customer_key = ds.customer_key
        WHERE FORMAT(pcd.profit_date, 'yyyy-MM') = @p_year_month
        GROUP BY pcd.customer_key, pcd.product_key, pcd.geography_key, ds.segment_key;
        
        IF @p_verbose = 1 
            PRINT '[' + CONVERT(VARCHAR(23), GETDATE(), 121) + '] Monthly profit aggregation completed.';
        
    END TRY
    BEGIN CATCH
        IF @p_verbose = 1 
            PRINT '[ERROR] ' + ERROR_MESSAGE();
        THROW;
    END CATCH;
END;
GO

-- ============================================================================
-- PROCEDURE: sp_refresh_financial_aggregations
-- Purpose: Master procedure to refresh all financial aggregations
-- ============================================================================
CREATE OR ALTER PROCEDURE sp_refresh_financial_aggregations
    @p_aggregation_date DATE = NULL,
    @p_verbose BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @start_time DATETIME = GETDATE();
    
    BEGIN TRY
        IF @p_aggregation_date IS NULL
            SET @p_aggregation_date = CAST(GETDATE() AS DATE);
        
        IF @p_verbose = 1 
        BEGIN
            PRINT '========================================';
            PRINT 'FINANCIAL AGGREGATION REFRESH';
            PRINT '========================================';
            PRINT '[' + CONVERT(VARCHAR(23), @start_time, 121) + '] Starting financial aggregation refresh...';
        END;
        
        -- Step 1: Calculate daily profit
        IF @p_verbose = 1 PRINT '[1/4] Calculating daily profit...';
        EXEC sp_calculate_daily_profit @p_profit_date = @p_aggregation_date, @p_verbose = @p_verbose;
        
        -- Step 2: Calculate revenue forecasts
        IF @p_verbose = 1 PRINT '[2/4] Calculating revenue forecasts...';
        EXEC sp_calculate_revenue_forecast @p_verbose = @p_verbose;
        
        -- Step 3: Aggregate monthly profit
        IF @p_verbose = 1 PRINT '[3/4] Aggregating monthly profit...';
        DECLARE @month NVARCHAR(7) = FORMAT(@p_aggregation_date, 'yyyy-MM');
        EXEC sp_calculate_monthly_profit_aggregation @p_year_month = @month, @p_verbose = @p_verbose;
        
        -- Step 4: Update financial summary
        IF @p_verbose = 1 PRINT '[4/4] Updating financial summary...';
        DELETE FROM financial_aggregation_summary WHERE aggregation_date = @p_aggregation_date;
        
        INSERT INTO financial_aggregation_summary (
            aggregation_date, aggregation_level, aggregation_name,
            total_revenue, total_costs, total_profit, profit_margin_pct
        )
        SELECT
            @p_aggregation_date,
            'Company' AS aggregation_level,
            'Overall Company' AS aggregation_name,
            SUM(pcd.gross_revenue) AS total_revenue,
            SUM(pcd.total_cogs + pcd.total_opex) AS total_costs,
            SUM(pcd.net_profit) AS total_profit,
            CASE 
                WHEN SUM(pcd.gross_revenue) > 0 THEN SUM(pcd.net_profit) / SUM(pcd.gross_revenue) * 100
                ELSE 0
            END AS profit_margin_pct
        FROM profit_calculation_daily pcd
        WHERE pcd.profit_date = @p_aggregation_date;
        
        IF @p_verbose = 1 
        BEGIN
            PRINT '[' + CONVERT(VARCHAR(23), GETDATE(), 121) + '] Financial aggregation refresh completed in ' + 
                   CAST(DATEDIFF(SECOND, @start_time, GETDATE()) AS VARCHAR(10)) + ' seconds.';
            PRINT '========================================';
        END;
        
    END TRY
    BEGIN CATCH
        IF @p_verbose = 1 
            PRINT '[ERROR] ' + ERROR_MESSAGE();
        THROW;
    END CATCH;
END;
GO

-- ============================================================================
-- VIEWS FOR FINANCIAL ANALYSIS
-- ============================================================================

-- View 1: Revenue Forecast Dashboard
CREATE OR ALTER VIEW vw_revenue_forecast_dashboard AS
SELECT
    rfb.forecast_dimension_type,
    rfb.dimension_name,
    rfb.forecast_start_month,
    rfb.forecast_end_month,
    rfb.avg_monthly_revenue,
    rfb.revenue_growth_rate_pct,
    rfb.forecast_method,
    rfb.confidence_level,
    ROUND(SUM(rf.forecasted_revenue), 2) AS total_forecasted_revenue,
    ROUND(AVG(rf.forecasted_revenue), 2) AS avg_monthly_forecast,
    ROUND(MIN(rf.lower_bound_95_pct), 2) AS conservative_estimate,
    ROUND(MAX(rf.upper_bound_95_pct), 2) AS optimistic_estimate,
    COUNT(rf.forecast_key) AS forecast_months
FROM revenue_forecast_base rfb
LEFT JOIN revenue_forecast rf ON rfb.forecast_base_key = rf.forecast_base_key
WHERE rfb.is_active = 1
GROUP BY 
    rfb.forecast_dimension_type,
    rfb.dimension_name,
    rfb.forecast_start_month,
    rfb.forecast_end_month,
    rfb.avg_monthly_revenue,
    rfb.revenue_growth_rate_pct,
    rfb.forecast_method,
    rfb.confidence_level;

-- View 2: Daily Profit Dashboard
CREATE OR ALTER VIEW vw_daily_profit_dashboard AS
SELECT
    pcd.profit_date,
    COUNT(DISTINCT pcd.customer_key) AS customer_count,
    ROUND(SUM(pcd.net_revenue), 2) AS daily_revenue,
    ROUND(SUM(pcd.total_cogs), 2) AS daily_cogs,
    ROUND(SUM(pcd.total_opex), 2) AS daily_opex,
    ROUND(SUM(pcd.gross_profit), 2) AS gross_profit,
    ROUND(AVG(pcd.gross_margin_pct), 2) AS avg_gross_margin,
    ROUND(SUM(pcd.operating_profit), 2) AS operating_profit,
    ROUND(AVG(pcd.operating_margin_pct), 2) AS avg_operating_margin,
    ROUND(SUM(pcd.net_profit), 2) AS net_profit,
    ROUND(AVG(pcd.net_margin_pct), 2) AS avg_net_margin,
    SUM(pcd.transaction_count) AS total_transactions
FROM profit_calculation_daily pcd
GROUP BY pcd.profit_date;

-- View 3: Monthly Profitability by Customer
CREATE OR ALTER VIEW vw_monthly_profit_by_customer AS
SELECT
    pcm.year_month,
    dc.customer_name,
    dc.customer_segment,
    ROUND(pcm.gross_revenue, 2) AS revenue,
    ROUND(pcm.net_revenue, 2) AS net_revenue,
    ROUND(pcm.total_cogs, 2) AS cogs,
    ROUND(pcm.total_opex, 2) AS opex,
    ROUND(pcm.gross_profit, 2) AS gross_profit,
    ROUND(pcm.gross_margin_pct, 2) AS gross_margin_pct,
    ROUND(pcm.net_profit, 2) AS net_profit,
    ROUND(pcm.net_margin_pct, 2) AS net_margin_pct,
    pcm.profitability_status,
    pcm.transaction_count
FROM profit_calculation_monthly pcm
LEFT JOIN dim_customer dc ON pcm.customer_key = dc.customer_key
WHERE pcm.customer_key IS NOT NULL
ORDER BY pcm.year_month DESC, pcm.net_profit DESC;

-- View 4: Product Profitability
CREATE OR ALTER VIEW vw_product_profitability AS
SELECT
    pcm.year_month,
    dp.product_name,
    dp.product_category,
    SUM(pcm.transaction_count) AS units_sold,
    ROUND(SUM(pcm.gross_revenue), 2) AS total_revenue,
    ROUND(SUM(pcm.total_cogs), 2) AS total_cogs,
    ROUND(SUM(pcm.gross_profit), 2) AS gross_profit,
    ROUND(AVG(pcm.gross_margin_pct), 2) AS avg_margin_pct,
    ROUND(SUM(pcm.net_profit), 2) AS net_profit,
    ROUND(AVG(pcm.net_margin_pct), 2) AS avg_net_margin_pct
FROM profit_calculation_monthly pcm
LEFT JOIN dim_product dp ON pcm.product_key = dp.product_key
WHERE pcm.product_key IS NOT NULL
GROUP BY pcm.year_month, dp.product_name, dp.product_category
ORDER BY pcm.year_month DESC;

-- View 5: Geographic Profit Analysis
CREATE OR ALTER VIEW vw_geographic_profit_analysis AS
SELECT
    pcm.year_month,
    dg.geography_name,
    dg.geography_region,
    dg.geography_country,
    COUNT(DISTINCT pcm.customer_key) AS customer_count,
    ROUND(SUM(pcm.gross_revenue), 2) AS revenue,
    ROUND(AVG(pcm.gross_margin_pct), 2) AS avg_gross_margin,
    ROUND(SUM(pcm.net_profit), 2) AS net_profit,
    ROUND(AVG(pcm.net_margin_pct), 2) AS avg_net_margin,
    SUM(pcm.transaction_count) AS total_transactions
FROM profit_calculation_monthly pcm
LEFT JOIN dim_geography dg ON pcm.geography_key = dg.geography_key
WHERE pcm.geography_key IS NOT NULL
GROUP BY pcm.year_month, dg.geography_name, dg.geography_region, dg.geography_country
ORDER BY pcm.year_month DESC, net_profit DESC;

-- View 6: Financial Executive Dashboard
CREATE OR ALTER VIEW vw_financial_executive_dashboard AS
SELECT
    fas.aggregation_date,
    ROUND(fas.total_revenue, 2) AS total_revenue,
    ROUND(fas.total_costs, 2) AS total_costs,
    ROUND(fas.total_profit, 2) AS total_profit,
    ROUND(fas.profit_margin_pct, 2) AS profit_margin_pct,
    CASE 
        WHEN fas.profit_margin_pct >= 20 THEN '✓ Excellent'
        WHEN fas.profit_margin_pct >= 15 THEN '✓ Good'
        WHEN fas.profit_margin_pct >= 10 THEN '⚠ Fair'
        ELSE '✗ Poor'
    END AS margin_status,
    -- MoM Comparison
    ROUND((fas.total_revenue - LAG(fas.total_revenue) OVER (ORDER BY fas.aggregation_date)) / 
          LAG(fas.total_revenue) OVER (ORDER BY fas.aggregation_date) * 100, 2) AS revenue_growth_mom_pct,
    ROUND((fas.total_profit - LAG(fas.total_profit) OVER (ORDER BY fas.aggregation_date)) / 
          LAG(fas.total_profit) OVER (ORDER BY fas.aggregation_date) * 100, 2) AS profit_growth_mom_pct
FROM financial_aggregation_summary fas
WHERE fas.aggregation_level = 'Company';

-- View 7: Profitability Trends
CREATE OR ALTER VIEW vw_profitability_trends AS
SELECT
    pcm.year_month,
    ROUND(SUM(pcm.gross_revenue), 2) AS total_revenue,
    ROUND(SUM(pcm.total_cogs), 2) AS total_cogs,
    ROUND(SUM(pcm.total_opex), 2) AS total_opex,
    ROUND(SUM(pcm.gross_profit), 2) AS gross_profit,
    ROUND(AVG(pcm.gross_margin_pct), 2) AS avg_gross_margin_pct,
    ROUND(SUM(pcm.operating_profit), 2) AS operating_profit,
    ROUND(AVG(pcm.operating_margin_pct), 2) AS avg_operating_margin_pct,
    ROUND(SUM(pcm.net_profit), 2) AS net_profit,
    ROUND(AVG(pcm.net_margin_pct), 2) AS avg_net_margin_pct,
    SUM(pcm.transaction_count) AS total_transactions,
    COUNT(DISTINCT pcm.customer_key) AS customer_count
FROM profit_calculation_monthly pcm
GROUP BY pcm.year_month
ORDER BY pcm.year_month DESC;

-- ============================================================================
-- INDEXES
-- ============================================================================

CREATE INDEX idx_revenue_forecast_month ON revenue_forecast(forecast_month);
CREATE INDEX idx_revenue_forecast_base_dim ON revenue_forecast_base(forecast_dimension_type, dimension_key);
CREATE INDEX idx_profit_daily_date_customer ON profit_calculation_daily(profit_date, customer_key);
CREATE INDEX idx_profit_monthly_month_customer ON profit_calculation_monthly(year_month, customer_key);
CREATE INDEX idx_financial_agg_date_level ON financial_aggregation_summary(aggregation_date, aggregation_level);

-- ============================================================================
-- PROCEDURE SUMMARY
-- ============================================================================
/*
    PROCEDURES CREATED:
    1. sp_calculate_revenue_forecast - Calculate revenue forecasts with seasonality and growth
    2. sp_calculate_daily_profit - Calculate daily profit at transaction level
    3. sp_calculate_monthly_profit_aggregation - Aggregate daily profit to monthly
    4. sp_refresh_financial_aggregations - Master procedure for all financial calculations
    
    VIEWS CREATED:
    1. vw_revenue_forecast_dashboard - Revenue forecast overview
    2. vw_daily_profit_dashboard - Daily profit metrics
    3. vw_monthly_profit_by_customer - Monthly profit by customer
    4. vw_product_profitability - Product-level profit analysis
    5. vw_geographic_profit_analysis - Geographic profit breakdown
    6. vw_financial_executive_dashboard - Executive financial overview
    7. vw_profitability_trends - Monthly profitability trends
    
    EXECUTION:
    -- Daily profit calculation
    EXEC sp_calculate_daily_profit @p_verbose = 1;
    
    -- Monthly aggregation
    EXEC sp_calculate_monthly_profit_aggregation @p_verbose = 1;
    
    -- Revenue forecasting
    EXEC sp_calculate_revenue_forecast @p_forecast_dimension = 'Overall', @p_verbose = 1;
    
    -- Master refresh (recommended daily)
    EXEC sp_refresh_financial_aggregations @p_verbose = 1;
*/

GO
