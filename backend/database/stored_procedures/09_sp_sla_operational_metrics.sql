-- ============================================================================
-- SLA CALCULATIONS & OPERATIONAL METRICS
-- Enterprise KPI - Executive Decision Intelligence Platform
-- Purpose: Calculate Service Level Agreements and operational performance
-- Updated: May 27, 2026
-- ============================================================================

-- ============================================================================
-- SECTION 1: SLA TRACKING TABLES
-- ============================================================================

-- ============================================================================
-- 1.1: SLA Definition Table
-- Purpose: Define SLA targets by service type and customer segment
-- ============================================================================
CREATE TABLE IF NOT EXISTS sla_definitions (
    sla_definition_key      BIGINT PRIMARY KEY AUTO_INCREMENT,
    sla_name                VARCHAR(200) NOT NULL,
    sla_category            VARCHAR(100) NOT NULL, -- Response, Resolution, Availability, Delivery
    service_type            VARCHAR(100), -- Support, Delivery, Incident, Implementation
    customer_segment        VARCHAR(50), -- Enterprise, Mid-Market, SMB, All
    sla_target_value        DECIMAL(10, 4), -- Time in hours or percentage
    sla_unit                VARCHAR(20), -- Hours, Days, %, Minutes
    sla_severity_level      VARCHAR(20), -- Critical, High, Medium, Low
    warning_threshold_pct   DECIMAL(5, 2), -- Alert at 80% of target
    critical_threshold_pct  DECIMAL(5, 2), -- Critical at 95% of target
    is_active               BOOLEAN DEFAULT TRUE,
    effective_date          DATE NOT NULL,
    end_date                DATE,
    created_by              VARCHAR(100),
    created_date            TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_date            TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_sla_active (is_active, effective_date),
    INDEX idx_sla_category (sla_category),
    INDEX idx_service_type (service_type),
    UNIQUE KEY uk_sla_unique (sla_name, effective_date)
);

-- ============================================================================
-- 1.2: SLA Performance Tracking Table
-- Purpose: Track individual SLA instances and compliance
-- Grain: One row per SLA per ticket/order/incident
-- ============================================================================
CREATE TABLE IF NOT EXISTS sla_performance_tracking (
    sla_tracking_key        BIGINT PRIMARY KEY AUTO_INCREMENT,
    sla_definition_key      BIGINT NOT NULL,
    ticket_key              BIGINT, -- Support ticket reference
    order_key               BIGINT, -- Order reference
    incident_key            BIGINT, -- Incident reference
    customer_key            BIGINT NOT NULL,
    employee_key            BIGINT, -- Assigned agent/representative
    -- SLA Timeline
    sla_start_time          DATETIME NOT NULL,
    sla_due_time            DATETIME NOT NULL,
    sla_breach_time         DATETIME,
    sla_resolution_time     DATETIME,
    -- SLA Status
    sla_status              VARCHAR(20), -- Compliant, At Risk, Breached, Waived
    is_compliant            BOOLEAN,
    is_breached             BOOLEAN,
    is_waived               BOOLEAN,
    waive_reason            VARCHAR(500),
    -- Metrics
    elapsed_minutes         DECIMAL(10, 2),
    remaining_minutes       DECIMAL(10, 2),
    sla_utilization_pct     DECIMAL(8, 4),
    -- Severity & Priority
    severity_level          VARCHAR(20),
    priority_level          VARCHAR(20),
    -- Root Cause
    escalation_count        INT DEFAULT 0,
    is_escalated            BOOLEAN DEFAULT FALSE,
    root_cause              VARCHAR(500),
    dw_insert_ts            TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    dw_update_ts            TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_sla_def (sla_definition_key),
    INDEX idx_customer (customer_key),
    INDEX idx_status (sla_status),
    INDEX idx_ticket (ticket_key),
    INDEX idx_is_breached (is_breached),
    INDEX idx_sla_period (sla_start_time, sla_due_time)
);

-- ============================================================================
-- 1.3: SLA Monthly Summary Table
-- Purpose: Aggregate SLA compliance metrics by month
-- Grain: One row per SLA per customer per month
-- ============================================================================
CREATE TABLE IF NOT EXISTS sla_monthly_summary (
    sla_month_key           BIGINT PRIMARY KEY AUTO_INCREMENT,
    year_month              CHAR(7) NOT NULL, -- YYYY-MM
    sla_definition_key      BIGINT NOT NULL,
    customer_key            BIGINT,
    customer_segment        VARCHAR(50),
    service_type            VARCHAR(100),
    -- Compliance Metrics
    total_slas              BIGINT,
    compliant_slas          BIGINT,
    breached_slas           BIGINT,
    waived_slas             BIGINT,
    compliance_rate_pct     DECIMAL(8, 4),
    breach_rate_pct         DECIMAL(8, 4),
    -- Performance Metrics
    avg_utilization_pct     DECIMAL(8, 4),
    max_utilization_pct     DECIMAL(8, 4),
    min_utilization_pct     DECIMAL(8, 4),
    avg_response_minutes    DECIMAL(10, 2),
    avg_resolution_minutes  DECIMAL(10, 2),
    -- Escalation Metrics
    escalation_count        BIGINT,
    escalation_rate_pct     DECIMAL(8, 4),
    -- Trend
    mtd_trend_pct           DECIMAL(8, 4),
    yoy_trend_pct           DECIMAL(8, 4),
    dw_insert_ts            TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    dw_update_ts            TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_year_month (year_month),
    INDEX idx_sla_def (sla_definition_key),
    INDEX idx_customer (customer_key),
    INDEX idx_compliance (compliance_rate_pct)
);

-- ============================================================================
-- SECTION 2: OPERATIONAL METRICS TABLES
-- ============================================================================

-- ============================================================================
-- 2.1: Daily Operational KPI Table
-- Purpose: Track key operational metrics by day
-- Grain: One row per metric per day
-- ============================================================================
CREATE TABLE IF NOT EXISTS operational_daily_kpi (
    operational_kpi_key     BIGINT PRIMARY KEY AUTO_INCREMENT,
    metric_date             DATE NOT NULL,
    warehouse_location      VARCHAR(100),
    department              VARCHAR(100),
    shift_name              VARCHAR(50), -- Day, Night, Swing
    -- Volume Metrics
    items_processed         BIGINT,
    orders_processed        BIGINT,
    shipments_created       BIGINT,
    returns_processed       BIGINT,
    -- Time Metrics
    avg_processing_time_min DECIMAL(10, 2),
    avg_cycle_time_hours    DECIMAL(10, 2),
    peak_hour_throughput    BIGINT,
    -- Quality Metrics
    error_count             BIGINT,
    error_rate_pct          DECIMAL(8, 4),
    rework_count            BIGINT,
    quality_score           DECIMAL(5, 2), -- 0-100
    -- Efficiency Metrics
    labor_productivity      DECIMAL(10, 2), -- Items per labor hour
    equipment_utilization_pct DECIMAL(8, 4),
    facility_utilization_pct DECIMAL(8, 4),
    -- Safety Metrics
    safety_incidents        INT,
    near_miss_count         INT,
    safety_score            DECIMAL(5, 2),
    dw_insert_ts            TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    dw_update_ts            TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_metric_date (metric_date),
    INDEX idx_warehouse (warehouse_location, metric_date),
    INDEX idx_quality_score (quality_score)
);

-- ============================================================================
-- 2.2: Operational Process Metrics Table
-- Purpose: Track process-specific operational KPIs
-- Grain: One row per process per day
-- ============================================================================
CREATE TABLE IF NOT EXISTS operational_process_metrics (
    process_metric_key      BIGINT PRIMARY KEY AUTO_INCREMENT,
    metric_date             DATE NOT NULL,
    process_name            VARCHAR(200) NOT NULL, -- Receiving, Picking, Packing, Shipping
    process_stage           VARCHAR(100), -- Sub-process stage
    warehouse_location      VARCHAR(100),
    -- Process Execution
    total_executions        BIGINT,
    successful_executions   BIGINT,
    failed_executions       BIGINT,
    success_rate_pct        DECIMAL(8, 4),
    -- Time Performance
    avg_duration_minutes    DECIMAL(10, 2),
    min_duration_minutes    DECIMAL(10, 2),
    max_duration_minutes    DECIMAL(10, 2),
    p95_duration_minutes    DECIMAL(10, 2), -- 95th percentile
    sla_adherence_pct       DECIMAL(8, 4),
    -- Quality Metrics
    defect_count            BIGINT,
    defect_rate_pct         DECIMAL(8, 4),
    first_pass_yield_pct    DECIMAL(8, 4),
    rework_required_pct     DECIMAL(8, 4),
    -- Cost Metrics
    process_cost            DECIMAL(15, 2),
    cost_per_execution      DECIMAL(12, 4),
    cost_variance_pct       DECIMAL(8, 4),
    dw_insert_ts            TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    dw_update_ts            TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_process_date (metric_date, process_name),
    INDEX idx_warehouse_date (warehouse_location, metric_date),
    INDEX idx_success_rate (success_rate_pct)
);

-- ============================================================================
-- SECTION 3: SLA CALCULATION PROCEDURES
-- ============================================================================

-- ============================================================================
-- 3.1: Calculate SLA Compliance Procedure
-- Purpose: Calculate SLA metrics for a specific time period
-- ============================================================================
CREATE PROCEDURE sp_calculate_sla_compliance (
    @p_start_date DATETIME = NULL,
    @p_end_date DATETIME = NULL,
    @p_verbose BIT = 0
)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @v_start_date DATETIME = ISNULL(@p_start_date, DATEADD(DAY, -1, CAST(GETDATE() AS DATE)));
    DECLARE @v_end_date DATETIME = ISNULL(@p_end_date, CAST(GETDATE() AS DATE));

    BEGIN TRY
        IF @p_verbose = 1
            PRINT 'Starting SLA Compliance calculation for: ' + CONVERT(VARCHAR, @v_start_date) + ' to ' + CONVERT(VARCHAR, @v_end_date);

        -- Clean previous records for the date range
        DELETE FROM sla_performance_tracking
        WHERE sla_start_time >= @v_start_date AND sla_start_time < DATEADD(DAY, 1, @v_end_date);

        -- Insert SLA records for support tickets (if tickets exist)
        INSERT INTO sla_performance_tracking (
            sla_definition_key, ticket_key, customer_key, employee_key,
            sla_start_time, sla_due_time, sla_status, is_compliant,
            elapsed_minutes, sla_utilization_pct, severity_level, priority_level
        )
        SELECT
            sd.sla_definition_key,
            sci.interaction_key,
            dc.customer_key,
            de.employee_key,
            CAST(sci.interaction_start_time AS DATETIME) AS sla_start_time,
            DATEADD(HOUR, CAST(sd.sla_target_value AS INT), CAST(sci.interaction_start_time AS DATETIME)) AS sla_due_time,
            CASE 
                WHEN sci.interaction_end_time IS NULL THEN 'Open'
                WHEN DATEDIFF(MINUTE, sci.interaction_start_time, sci.interaction_end_time) <= (sd.sla_target_value * 60) 
                    THEN 'Compliant'
                ELSE 'Breached'
            END,
            CASE 
                WHEN DATEDIFF(MINUTE, sci.interaction_start_time, ISNULL(sci.interaction_end_time, GETDATE())) <= (sd.sla_target_value * 60) 
                    THEN 1 ELSE 0
            END,
            DATEDIFF(MINUTE, sci.interaction_start_time, ISNULL(sci.interaction_end_time, GETDATE())),
            ROUND(DATEDIFF(MINUTE, sci.interaction_start_time, ISNULL(sci.interaction_end_time, GETDATE())) / 
                  (sd.sla_target_value * 60) * 100, 2),
            'Support',
            'Standard'
        FROM stg_customer_interactions_conformed sci
        LEFT JOIN sla_definitions sd ON sd.sla_category = 'Response' AND sd.is_active = 1
        LEFT JOIN dim_customer dc ON sci.customer_key = dc.customer_key AND dc.is_current = 1
        LEFT JOIN dim_employee de ON sci.agent_key = de.employee_key AND de.is_current = 1
        WHERE sci.source_load_date >= @v_start_date 
        AND sci.source_load_date <= @v_end_date
        AND sci.interaction_type = 'Support';

        IF @p_verbose = 1
            PRINT 'SLA Compliance calculation completed successfully';

    END TRY
    BEGIN CATCH
        PRINT 'Error in sp_calculate_sla_compliance: ' + ERROR_MESSAGE();
        THROW;
    END CATCH;
END;
GO

-- ============================================================================
-- 3.2: Update SLA Monthly Summary Procedure
-- Purpose: Aggregate daily SLA metrics to monthly summaries
-- ============================================================================
CREATE PROCEDURE sp_update_sla_monthly_summary (
    @p_year_month CHAR(7) = NULL,
    @p_verbose BIT = 0
)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @v_year_month CHAR(7) = ISNULL(@p_year_month, FORMAT(GETDATE(), 'yyyy-MM'));

    BEGIN TRY
        IF @p_verbose = 1
            PRINT 'Updating SLA Monthly Summary for: ' + @v_year_month;

        -- Delete existing summary for the month
        DELETE FROM sla_monthly_summary WHERE year_month = @v_year_month;

        -- Insert aggregated SLA metrics
        INSERT INTO sla_monthly_summary (
            year_month, sla_definition_key, customer_key, customer_segment, 
            service_type, total_slas, compliant_slas, breached_slas, waived_slas,
            compliance_rate_pct, breach_rate_pct, avg_utilization_pct,
            max_utilization_pct, min_utilization_pct, escalation_count
        )
        SELECT
            @v_year_month,
            spt.sla_definition_key,
            spt.customer_key,
            dc.customer_segment,
            sd.service_type,
            COUNT(DISTINCT spt.sla_tracking_key) AS total_slas,
            SUM(CASE WHEN spt.is_compliant = 1 THEN 1 ELSE 0 END),
            SUM(CASE WHEN spt.is_breached = 1 THEN 1 ELSE 0 END),
            SUM(CASE WHEN spt.is_waived = 1 THEN 1 ELSE 0 END),
            ROUND(SUM(CASE WHEN spt.is_compliant = 1 THEN 1 ELSE 0 END) * 100.0 / 
                  COUNT(DISTINCT spt.sla_tracking_key), 2),
            ROUND(SUM(CASE WHEN spt.is_breached = 1 THEN 1 ELSE 0 END) * 100.0 / 
                  COUNT(DISTINCT spt.sla_tracking_key), 2),
            ROUND(AVG(spt.sla_utilization_pct), 2),
            MAX(spt.sla_utilization_pct),
            MIN(spt.sla_utilization_pct),
            SUM(spt.escalation_count)
        FROM sla_performance_tracking spt
        LEFT JOIN sla_definitions sd ON spt.sla_definition_key = sd.sla_definition_key
        LEFT JOIN dim_customer dc ON spt.customer_key = dc.customer_key AND dc.is_current = 1
        WHERE FORMAT(spt.sla_start_time, 'yyyy-MM') = @v_year_month
        GROUP BY spt.sla_definition_key, spt.customer_key, dc.customer_segment, sd.service_type;

        IF @p_verbose = 1
            PRINT 'SLA Monthly Summary updated successfully';

    END TRY
    BEGIN CATCH
        PRINT 'Error in sp_update_sla_monthly_summary: ' + ERROR_MESSAGE();
        THROW;
    END CATCH;
END;
GO

-- ============================================================================
-- SECTION 4: OPERATIONAL METRICS PROCEDURES
-- ============================================================================

-- ============================================================================
-- 4.1: Calculate Daily Operational KPIs
-- Purpose: Calculate operational KPIs for each day
-- ============================================================================
CREATE PROCEDURE sp_calculate_operational_daily_kpi (
    @p_metric_date DATE = NULL,
    @p_verbose BIT = 0
)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @v_metric_date DATE = ISNULL(@p_metric_date, CAST(GETDATE() AS DATE));

    BEGIN TRY
        IF @p_verbose = 1
            PRINT 'Calculating Operational Daily KPIs for: ' + CONVERT(VARCHAR, @v_metric_date);

        DELETE FROM operational_daily_kpi WHERE metric_date = @v_metric_date;

        INSERT INTO operational_daily_kpi (
            metric_date, warehouse_location, department,
            items_processed, orders_processed, shipments_created, returns_processed,
            avg_processing_time_min, error_count, error_rate_pct, quality_score,
            labor_productivity, equipment_utilization_pct
        )
        SELECT
            @v_metric_date,
            fi.warehouse_location,
            'Warehouse',
            SUM(fi.quantity_on_hand),
            COUNT(DISTINCT fs.sales_key),
            SUM(CASE WHEN fs.shipment_date = @v_metric_date THEN 1 ELSE 0 END),
            SUM(CASE WHEN fs.is_return = 1 THEN 1 ELSE 0 END),
            AVG(CAST(fs.processing_time_minutes AS DECIMAL(10, 2))),
            SUM(CASE WHEN fs.quality_flag = 0 THEN 1 ELSE 0 END),
            CASE 
                WHEN COUNT(*) > 0 
                THEN ROUND(SUM(CASE WHEN fs.quality_flag = 0 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2)
                ELSE 0
            END,
            CASE 
                WHEN COUNT(*) > 0 
                THEN ROUND(100 - (SUM(CASE WHEN fs.quality_flag = 0 THEN 1 ELSE 0 END) * 100.0 / COUNT(*)), 2)
                ELSE 100
            END,
            CASE 
                WHEN COUNT(DISTINCT de.employee_key) > 0
                THEN ROUND(COUNT(DISTINCT fs.sales_key) * 1.0 / COUNT(DISTINCT de.employee_key), 2)
                ELSE 0
            END,
            CASE 
                WHEN SUM(fi.quantity_on_hand) > 0
                THEN ROUND(COUNT(DISTINCT fs.sales_key) * 100.0 / SUM(fi.quantity_on_hand), 2)
                ELSE 0
            END
        FROM fact_inventory fi
        LEFT JOIN fact_sales fs ON fi.product_key = fs.product_key 
            AND fi.warehouse_location_key = fs.warehouse_key
            AND CAST(fs.order_date_key / 10000 AS INT) = YEAR(@v_metric_date)
            AND CAST((fs.order_date_key / 100) % 100 AS INT) = MONTH(@v_metric_date)
            AND CAST(fs.order_date_key % 100 AS INT) = DAY(@v_metric_date)
        LEFT JOIN dim_employee de ON fs.employee_key = de.employee_key AND de.is_current = 1
        WHERE fi.inventory_date = @v_metric_date
        GROUP BY fi.warehouse_location;

        IF @p_verbose = 1
            PRINT 'Operational Daily KPIs calculated successfully';

    END TRY
    BEGIN CATCH
        PRINT 'Error in sp_calculate_operational_daily_kpi: ' + ERROR_MESSAGE();
        THROW;
    END CATCH;
END;
GO

-- ============================================================================
-- 4.2: Calculate Operational Process Metrics
-- Purpose: Calculate metrics for specific operational processes
-- ============================================================================
CREATE PROCEDURE sp_calculate_operational_process_metrics (
    @p_metric_date DATE = NULL,
    @p_verbose BIT = 0
)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @v_metric_date DATE = ISNULL(@p_metric_date, CAST(GETDATE() AS DATE));

    BEGIN TRY
        IF @p_verbose = 1
            PRINT 'Calculating Operational Process Metrics for: ' + CONVERT(VARCHAR, @v_metric_date);

        DELETE FROM operational_process_metrics WHERE metric_date = @v_metric_date;

        -- Insert metrics for Picking process
        INSERT INTO operational_process_metrics (
            metric_date, process_name, process_stage, warehouse_location,
            total_executions, successful_executions, failed_executions,
            success_rate_pct, avg_duration_minutes, first_pass_yield_pct, sla_adherence_pct
        )
        SELECT
            @v_metric_date,
            'Picking',
            'Order Processing',
            fi.warehouse_location,
            COUNT(DISTINCT fs.sales_key),
            SUM(CASE WHEN fs.quality_flag = 1 THEN 1 ELSE 0 END),
            SUM(CASE WHEN fs.quality_flag = 0 THEN 1 ELSE 0 END),
            CASE 
                WHEN COUNT(*) > 0 
                THEN ROUND(SUM(CASE WHEN fs.quality_flag = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2)
                ELSE 0
            END,
            AVG(CAST(fs.processing_time_minutes AS DECIMAL(10, 2))),
            CASE 
                WHEN COUNT(*) > 0 
                THEN ROUND(SUM(CASE WHEN fs.quality_flag = 1 AND fs.processing_time_minutes <= 30 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2)
                ELSE 0
            END,
            CASE 
                WHEN COUNT(*) > 0 
                THEN ROUND(SUM(CASE WHEN fs.delivery_days <= 2 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2)
                ELSE 0
            END
        FROM fact_inventory fi
        LEFT JOIN fact_sales fs ON fi.product_key = fs.product_key
        WHERE CAST(fs.order_date_key / 10000 AS INT) = YEAR(@v_metric_date)
        AND CAST((fs.order_date_key / 100) % 100 AS INT) = MONTH(@v_metric_date)
        AND CAST(fs.order_date_key % 100 AS INT) = DAY(@v_metric_date)
        GROUP BY fi.warehouse_location;

        IF @p_verbose = 1
            PRINT 'Operational Process Metrics calculated successfully';

    END TRY
    BEGIN CATCH
        PRINT 'Error in sp_calculate_operational_process_metrics: ' + ERROR_MESSAGE();
        THROW;
    END CATCH;
END;
GO

-- ============================================================================
-- SECTION 5: SLA & OPERATIONAL VIEWS
-- ============================================================================

-- ============================================================================
-- 5.1: SLA Compliance Dashboard View
-- Purpose: Real-time SLA compliance tracking
-- ============================================================================
CREATE OR REPLACE VIEW vw_sla_compliance_dashboard AS
SELECT
    sd.sla_name,
    sd.sla_category,
    sd.service_type,
    COUNT(DISTINCT spt.sla_tracking_key) AS total_slas,
    SUM(CASE WHEN spt.is_compliant = 1 THEN 1 ELSE 0 END) AS compliant_count,
    SUM(CASE WHEN spt.is_breached = 1 THEN 1 ELSE 0 END) AS breached_count,
    ROUND(SUM(CASE WHEN spt.is_compliant = 1 THEN 1 ELSE 0 END) * 100.0 / 
          COUNT(DISTINCT spt.sla_tracking_key), 2) AS compliance_rate_pct,
    MAX(spt.sla_utilization_pct) AS max_utilization_pct,
    ROUND(AVG(spt.sla_utilization_pct), 2) AS avg_utilization_pct,
    SUM(spt.escalation_count) AS escalation_count,
    CAST(GETDATE() AS DATE) AS dashboard_date
FROM sla_definitions sd
LEFT JOIN sla_performance_tracking spt ON sd.sla_definition_key = spt.sla_definition_key
    AND CAST(spt.sla_start_time AS DATE) >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
WHERE sd.is_active = 1
GROUP BY sd.sla_name, sd.sla_category, sd.service_type;

-- ============================================================================
-- 5.2: Operational Efficiency Dashboard View
-- Purpose: Operational KPI overview
-- ============================================================================
CREATE OR REPLACE VIEW vw_operational_efficiency_dashboard AS
SELECT
    ok.metric_date,
    ok.warehouse_location,
    ok.items_processed,
    ok.orders_processed,
    ok.error_rate_pct,
    ok.quality_score,
    ok.labor_productivity,
    ok.equipment_utilization_pct,
    CASE 
        WHEN ok.quality_score >= 95 THEN 'GREEN'
        WHEN ok.quality_score >= 90 THEN 'YELLOW'
        ELSE 'RED'
    END AS quality_status,
    CASE 
        WHEN ok.labor_productivity >= 100 THEN 'GREEN'
        WHEN ok.labor_productivity >= 80 THEN 'YELLOW'
        ELSE 'RED'
    END AS productivity_status
FROM operational_daily_kpi ok
WHERE ok.metric_date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
ORDER BY ok.metric_date DESC;

-- ============================================================================
-- 5.3: Process Performance View
-- Purpose: Track performance of specific operational processes
-- ============================================================================
CREATE OR REPLACE VIEW vw_process_performance AS
SELECT
    opm.metric_date,
    opm.process_name,
    opm.warehouse_location,
    opm.total_executions,
    opm.successful_executions,
    opm.success_rate_pct,
    opm.avg_duration_minutes,
    opm.first_pass_yield_pct,
    opm.sla_adherence_pct,
    CASE 
        WHEN opm.success_rate_pct >= 98 THEN 'GREEN'
        WHEN opm.success_rate_pct >= 95 THEN 'YELLOW'
        ELSE 'RED'
    END AS performance_status
FROM operational_process_metrics opm
WHERE opm.metric_date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
ORDER BY opm.metric_date DESC, opm.warehouse_location;

GO
