-- ============================================================
-- Enterprise KPI Platform - SQL Scalar & Table-Valued Functions
-- Database: KPI_DataWarehouse
-- ============================================================

USE KPI_DataWarehouse;
GO

-- ── 1. Date/Period Helpers ────────────────────────────────────────────────────

-- Returns the first day of the month for a given date
CREATE OR ALTER FUNCTION dbo.fn_first_day_of_month (@date DATE)
RETURNS DATE
AS
BEGIN
    RETURN DATEFROMPARTS(YEAR(@date), MONTH(@date), 1);
END;
GO

-- Returns the last day of the month for a given date
CREATE OR ALTER FUNCTION dbo.fn_last_day_of_month (@date DATE)
RETURNS DATE
AS
BEGIN
    RETURN EOMONTH(@date);
END;
GO

-- Returns the fiscal year (July-June cycle) for a given date
-- Fiscal Year starts in July: FY2026 = Jul 2025 – Jun 2026
CREATE OR ALTER FUNCTION dbo.fn_fiscal_year (@date DATE)
RETURNS INT
AS
BEGIN
    RETURN CASE WHEN MONTH(@date) >= 7 THEN YEAR(@date) + 1 ELSE YEAR(@date) END;
END;
GO

-- Returns fiscal quarter (Q1=Jul-Sep, Q2=Oct-Dec, Q3=Jan-Mar, Q4=Apr-Jun)
CREATE OR ALTER FUNCTION dbo.fn_fiscal_quarter (@date DATE)
RETURNS INT
AS
BEGIN
    RETURN CASE
        WHEN MONTH(@date) IN (7,8,9)   THEN 1
        WHEN MONTH(@date) IN (10,11,12) THEN 2
        WHEN MONTH(@date) IN (1,2,3)   THEN 3
        WHEN MONTH(@date) IN (4,5,6)   THEN 4
    END;
END;
GO

-- Returns number of business days between two dates (Mon-Fri, no holiday check)
CREATE OR ALTER FUNCTION dbo.fn_business_days_between (
    @start_date DATE,
    @end_date   DATE
)
RETURNS INT
AS
BEGIN
    DECLARE @days INT = 0;
    DECLARE @current DATE = @start_date;
    WHILE @current <= @end_date
    BEGIN
        IF DATEPART(WEEKDAY, @current) NOT IN (1, 7)  -- 1=Sunday, 7=Saturday
            SET @days = @days + 1;
        SET @current = DATEADD(DAY, 1, @current);
    END;
    RETURN @days;
END;
GO

-- ── 2. KPI Calculation Helpers ────────────────────────────────────────────────

-- Returns % achievement of actual vs target, capped at 200%
CREATE OR ALTER FUNCTION dbo.fn_kpi_achievement_pct (
    @actual  DECIMAL(18,4),
    @target  DECIMAL(18,4)
)
RETURNS DECIMAL(10,2)
AS
BEGIN
    IF @target IS NULL OR @target = 0 RETURN NULL;
    RETURN ROUND(CASE
        WHEN (@actual / @target) * 100.0 > 200.0 THEN 200.0
        ELSE (@actual / @target) * 100.0
    END, 2);
END;
GO

-- Returns KPI status label based on achievement %
CREATE OR ALTER FUNCTION dbo.fn_kpi_status_label (@achievement_pct DECIMAL(10,2))
RETURNS NVARCHAR(20)
AS
BEGIN
    RETURN CASE
        WHEN @achievement_pct IS NULL    THEN N'NO_DATA'
        WHEN @achievement_pct >= 100.0   THEN N'ON_TARGET'
        WHEN @achievement_pct >= 90.0    THEN N'AT_RISK'
        WHEN @achievement_pct >= 75.0    THEN N'BELOW_TARGET'
        ELSE                                  N'CRITICAL'
    END;
END;
GO

-- Returns gross margin % given revenue and cost
CREATE OR ALTER FUNCTION dbo.fn_gross_margin_pct (
    @revenue DECIMAL(18,4),
    @cost    DECIMAL(18,4)
)
RETURNS DECIMAL(10,2)
AS
BEGIN
    IF @revenue IS NULL OR @revenue = 0 RETURN NULL;
    RETURN ROUND(((@revenue - @cost) / @revenue) * 100.0, 2);
END;
GO

-- ── 3. SLA / Operational Helpers ─────────────────────────────────────────────

-- Returns SLA compliance status based on actual vs SLA minutes
CREATE OR ALTER FUNCTION dbo.fn_sla_compliance_status (
    @actual_minutes  INT,
    @sla_minutes     INT
)
RETURNS NVARCHAR(20)
AS
BEGIN
    IF @sla_minutes IS NULL OR @sla_minutes = 0 RETURN N'NO_SLA';
    RETURN CASE
        WHEN @actual_minutes <= @sla_minutes              THEN N'COMPLIANT'
        WHEN @actual_minutes <= @sla_minutes * 1.10       THEN N'WARNING'
        ELSE                                                   N'BREACHED'
    END;
END;
GO

-- Returns SLA breach severity (NONE / LOW / MEDIUM / HIGH / CRITICAL)
CREATE OR ALTER FUNCTION dbo.fn_sla_breach_severity (
    @actual_minutes  INT,
    @sla_minutes     INT
)
RETURNS NVARCHAR(20)
AS
BEGIN
    IF @sla_minutes IS NULL OR @sla_minutes = 0 RETURN N'UNKNOWN';
    DECLARE @overage_pct DECIMAL(10,2) =
        CAST(@actual_minutes - @sla_minutes AS DECIMAL) / @sla_minutes * 100.0;
    RETURN CASE
        WHEN @overage_pct <= 0    THEN N'NONE'
        WHEN @overage_pct <= 10   THEN N'LOW'
        WHEN @overage_pct <= 25   THEN N'MEDIUM'
        WHEN @overage_pct <= 50   THEN N'HIGH'
        ELSE                           N'CRITICAL'
    END;
END;
GO

-- ── 4. Revenue / Financial Helpers ───────────────────────────────────────────

-- Calculates period-over-period growth % (handles NULL and zero safely)
CREATE OR ALTER FUNCTION dbo.fn_period_growth_pct (
    @current_value  DECIMAL(18,4),
    @prior_value    DECIMAL(18,4)
)
RETURNS DECIMAL(10,2)
AS
BEGIN
    IF @prior_value IS NULL OR @prior_value = 0 RETURN NULL;
    RETURN ROUND(((@current_value - @prior_value) / ABS(@prior_value)) * 100.0, 2);
END;
GO

-- Returns revenue tier label for customer segmentation
CREATE OR ALTER FUNCTION dbo.fn_customer_revenue_tier (@annual_revenue DECIMAL(18,4))
RETURNS NVARCHAR(20)
AS
BEGIN
    RETURN CASE
        WHEN @annual_revenue >= 1000000  THEN N'ENTERPRISE'
        WHEN @annual_revenue >= 250000   THEN N'LARGE'
        WHEN @annual_revenue >= 50000    THEN N'MID_MARKET'
        WHEN @annual_revenue >= 10000    THEN N'SMALL'
        ELSE                                  N'MICRO'
    END;
END;
GO

-- ── 5. Table-Valued Functions ─────────────────────────────────────────────────

-- Returns a calendar table for a given date range (useful for date spine joins)
CREATE OR ALTER FUNCTION dbo.fn_date_spine (
    @start_date DATE,
    @end_date   DATE
)
RETURNS TABLE
AS
RETURN (
    WITH dates AS (
        SELECT @start_date AS dt
        UNION ALL
        SELECT DATEADD(DAY, 1, dt)
        FROM dates
        WHERE dt < @end_date
    )
    SELECT
        dt                                          AS calendar_date,
        YEAR(dt)                                    AS calendar_year,
        MONTH(dt)                                   AS calendar_month,
        DAY(dt)                                     AS calendar_day,
        DATEPART(QUARTER, dt)                       AS calendar_quarter,
        DATEPART(WEEK, dt)                          AS week_of_year,
        DATEPART(WEEKDAY, dt)                       AS day_of_week,
        DATENAME(WEEKDAY, dt)                       AS day_name,
        DATENAME(MONTH, dt)                         AS month_name,
        CASE WHEN DATEPART(WEEKDAY, dt) IN (1,7)
             THEN 1 ELSE 0 END                      AS is_weekend,
        dbo.fn_fiscal_year(dt)                      AS fiscal_year,
        dbo.fn_fiscal_quarter(dt)                   AS fiscal_quarter,
        dbo.fn_first_day_of_month(dt)               AS first_day_of_month,
        dbo.fn_last_day_of_month(dt)                AS last_day_of_month
    FROM dates
    OPTION (MAXRECURSION 3660)  -- ~10 years max
);
GO

-- Returns department KPI summary for a given date range (inline TVF)
CREATE OR ALTER FUNCTION dbo.fn_department_kpi_summary (
    @start_date DATE,
    @end_date   DATE
)
RETURNS TABLE
AS
RETURN (
    SELECT
        d.department_key,
        d.department_name,
        d.department_code,
        COUNT(DISTINCT f.order_key)                                     AS order_count,
        SUM(f.revenue_amount)                                           AS total_revenue,
        SUM(f.cost_amount)                                              AS total_cost,
        SUM(f.revenue_amount) - SUM(f.cost_amount)                     AS gross_profit,
        dbo.fn_gross_margin_pct(
            SUM(f.revenue_amount), SUM(f.cost_amount)
        )                                                               AS margin_pct,
        AVG(CAST(f.on_time_delivery_flag AS DECIMAL(5,4))) * 100.0     AS on_time_pct,
        AVG(f.order_fill_rate) * 100.0                                  AS fill_rate_pct
    FROM dbo.fact_financial_metrics f
    JOIN dbo.dim_department d ON f.department_key = d.department_key
    WHERE f.transaction_date BETWEEN @start_date AND @end_date
    GROUP BY d.department_key, d.department_name, d.department_code
);
GO

-- ── Usage Examples ────────────────────────────────────────────────────────────
/*
-- Date spine for current month
SELECT * FROM dbo.fn_date_spine('2026-06-01', '2026-06-30');

-- KPI achievement for a metric
SELECT dbo.fn_kpi_achievement_pct(850000.00, 1000000.00);  -- Returns 85.00

-- KPI status label
SELECT dbo.fn_kpi_status_label(85.00);  -- Returns 'AT_RISK'

-- Gross margin
SELECT dbo.fn_gross_margin_pct(1000000.00, 650000.00);  -- Returns 35.00

-- Department KPI summary
SELECT * FROM dbo.fn_department_kpi_summary('2026-06-01', '2026-06-30')
ORDER BY total_revenue DESC;

-- Fiscal year and quarter
SELECT dbo.fn_fiscal_year('2025-09-15');   -- Returns 2026 (Jul-Jun FY)
SELECT dbo.fn_fiscal_quarter('2025-09-15'); -- Returns 1

-- SLA compliance
SELECT dbo.fn_sla_compliance_status(55, 60);  -- Returns 'COMPLIANT'
SELECT dbo.fn_sla_breach_severity(90, 60);    -- Returns 'HIGH'

-- Period growth
SELECT dbo.fn_period_growth_pct(1100000, 1000000);  -- Returns 10.00
*/
