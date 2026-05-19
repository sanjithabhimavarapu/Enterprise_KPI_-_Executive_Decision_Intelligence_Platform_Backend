-- ============================================================
-- ETL IMPLEMENTATION QUICK START GUIDE
-- ============================================================
-- Enterprise KPI Platform - Complete SQL Implementation
-- Version: 1.0
-- Last Updated: 2024-01-15
-- ============================================================

/*

TABLE OF CONTENTS:
===================
1. Architecture Overview
2. File Structure & Organization
3. Staging Transformation Procedures
4. Dimension Loading (SCD Type 2)
5. Fact Table Loading
6. KPI Calculations
7. Data Quality & Validation
8. Master Orchestration
9. Execution Examples
10. Monitoring & Troubleshooting


1. ARCHITECTURE OVERVIEW
========================

The ETL pipeline consists of 4 main stages:

    SOURCE SYSTEMS → STAGING → DIMENSIONS & FACTS → KPI CALCULATIONS
    ├─ SAP/Oracle ERP          ├─ Raw staging       ├─ SCD Type 2    ├─ 32+ KPIs
    ├─ Salesforce CRM          ├─ Transformations   ├─ Fact tables   ├─ Segment views
    ├─ Warehouse/Ops           ├─ Data validation   ├─ Aggregates    ├─ Drill-down
    ├─ Finance                 └─ DQ checks        └─ Reconciliation └─ Alerts
    └─ HR/Production systems

Data Flow:
    Raw Data → Conformed Staging → Dim/Fact Loading → KPI Views → BI/Dashboard


2. FILE STRUCTURE & ORGANIZATION
=================================

backend/database/staging/
├─ 01_stg_erp_orders_transformation.sql
│  ├─ sp_transform_erp_orders
│  ├─ sp_validate_orders_quality
│  └─ stg_orders_conformed table
│
├─ 02_stg_salesforce_transformation.sql
│  ├─ sp_transform_salesforce_customers
│  ├─ sp_transform_salesforce_opportunities
│  ├─ stg_customers_conformed table
│  └─ stg_opportunities_conformed table
│
└─ 03_stg_inventory_hr_production_transformation.sql
   ├─ sp_transform_warehouse_inventory
   ├─ sp_transform_customer_interactions
   ├─ sp_transform_revenue_recognition
   ├─ sp_transform_production_quality
   └─ sp_transform_all_staging (master)

backend/database/stored_procedures/
├─ 01_sp_load_dimensions.sql
│  ├─ sp_load_dim_customer (SCD Type 2)
│  ├─ sp_load_dim_product (SCD Type 2)
│  └─ sp_load_dim_date (reference dimension)
│
├─ 02_sp_load_facts.sql
│  ├─ sp_load_fact_sales (~500K records/day)
│  ├─ sp_load_fact_revenue (daily aggregates)
│  ├─ sp_load_fact_customer_interactions (~2M records/day)
│  └─ sp_load_all_facts (orchestrator)
│
├─ 03_sp_calculate_kpis.sql
│  ├─ vw_kpi_financial_summary (5 KPIs)
│  ├─ vw_kpi_sales_summary (7 KPIs)
│  ├─ vw_kpi_customer_success (6 KPIs)
│  ├─ vw_kpi_operational (6 KPIs)
│  └─ sp_calculate_all_kpis (orchestrator)
│
├─ 04_sp_etl_master_orchestration.sql
│  └─ sp_etl_master_orchestration (complete ETL flow)
│
├─ 05_kpi_reference_specifications.sql
│  └─ KPI definitions, formulas, targets (reference)
│
└─ 06_sp_data_quality_validation.sql
   ├─ sp_validate_staging_completeness
   ├─ sp_reconcile_etl_totals
   ├─ sp_calculate_dq_score
   ├─ sp_check_referential_integrity
   ├─ sp_detect_duplicates
   └─ sp_generate_dq_summary_report


3. STAGING TRANSFORMATION PROCEDURES
=====================================

Each source system has a transformation procedure that:
  1. Reads raw data from stg_raw_* tables
  2. Performs data quality checks
  3. Applies business logic transformations
  4. Populates conformed staging tables (stg_*_conformed)

Files: backend/database/staging/*.sql

PROCEDURES:
-----------

sp_transform_erp_orders
  Input: stg_raw_erp_orders (raw data from SAP/Oracle)
  Output: stg_orders_conformed
  Logic:
    - Calculate net amount (gross - discount)
    - Calculate gross profit (net - COGS)
    - Calculate gross margin %
    - Flag delivery performance
    - Validate data quality
  Run: Daily after ERP data load
  Volume: ~500K records/day
  Duration: ~5-10 minutes

sp_transform_salesforce_customers
  Input: stg_raw_salesforce_customers
  Output: stg_customers_conformed
  Logic:
    - Address normalization
    - Engagement metrics calculation
    - Lifecycle classification
  Run: Daily (15-min batch frequency)
  Volume: ~10GB/day

sp_transform_salesforce_opportunities
  Input: stg_raw_salesforce_opportunities
  Output: stg_opportunities_conformed
  Logic:
    - Sales cycle calculation
    - Expected value calculation (amount * probability)
    - Pipeline stage analysis
  Run: Daily

sp_transform_warehouse_inventory
  Input: stg_raw_warehouse_inventory
  Output: stg_inventory_conformed
  Logic:
    - Inventory turnover calculation
    - Days on hand analysis
    - Obsolescence flagging
  Run: Daily

sp_transform_customer_interactions
  Input: stg_raw_customer_interactions
  Output: stg_customer_interactions_conformed
  Logic:
    - Engagement scoring
    - Sentiment analysis
    - Resolution tracking
  Run: Real-time (as interactions logged)

sp_transform_revenue_recognition
  Input: stg_raw_revenue_contracts
  Output: stg_revenue_recognition_conformed
  Logic:
    - Revenue recognition schedule
    - Deferred revenue tracking
    - ASC 606 compliance
  Run: Daily (post-GL close)

sp_transform_production_quality
  Input: stg_raw_production_quality
  Output: stg_production_quality_conformed
  Logic:
    - Defect rate calculation
    - First pass yield calculation
    - Efficiency metrics
  Run: Real-time (batch processing by shift)

MASTER ORCHESTRATOR:
  sp_transform_all_staging
    - Calls all transformation procedures
    - Runs sequentially
    - Total duration: ~20-30 minutes for full ETL


4. DIMENSION LOADING (SCD Type 2)
==================================

SCD Type 2 (Slowly Changing Dimensions) tracks history of changes:
  - New record: Add as current
  - Changed attribute: Close old record, open new record with history
  - Type 1 (overwrite): Customer name, industry (overwrite without history)

File: backend/database/stored_procedures/01_sp_load_dimensions.sql

PROCEDURES:
-----------

sp_load_dim_customer
  Tracked Attributes (SCD Type 2):
    - customer_segment (A, B, C, D)
    - annual_contract_value
    - subscription_status
  
  Type 1 Attributes (overwrite):
    - customer_name
    - industry
    - is_active_customer
  
  Process:
    1. Identify new customers (not in dim_customer)
    2. Insert new records as current
    3. Identify changed customers (SCD attributes differ)
    4. Close old records (set is_current=0, end_date=yesterday)
    5. Insert new versions as current
    6. Update Type 1 attributes on current records
  
  Duration: ~3-5 minutes per load
  Output: 
    - All current records: is_current=1, end_date='9999-12-31'
    - Historical records: is_current=0, end_date=date of change

sp_load_dim_product
  Similar process, tracks:
    - product_category
    - unit_price
    - supplier_id
    - lead_time_days

sp_load_dim_date
  Pre-populate reference dimension
  Run once: Generates 10 years of dates with all attributes
  Includes: Holidays, business days, fiscal periods, week/quarter/year


5. FACT TABLE LOADING
====================

File: backend/database/stored_procedures/02_sp_load_facts.sql

PROCEDURES:
-----------

sp_load_fact_sales
  Input: stg_orders_conformed (staging)
  Process:
    1. Join with dimension tables to get keys
    2. Handle missing dimensions (set to -1)
    3. Check for duplicates
    4. Insert new fact records
  Volume: ~500K records/day
  Duration: ~5-10 minutes
  
  Grain: One row per line item (order × product)
  Attributes:
    - Quantity, pricing, costs, margins
    - Delivery performance
    - Order status

sp_load_fact_revenue
  Input: fact_sales (aggregates daily data)
  Process:
    1. Group by date, customer, product, warehouse
    2. Sum quantities and amounts
    3. Calculate average margins
    4. Count on-time deliveries
  
  Grain: One row per day × customer × product × warehouse combination
  Frequency: Daily post-fact_sales load

sp_load_fact_customer_interactions
  Input: stg_customer_interactions_conformed
  Process:
    1. Join with customer and employee dimensions
    2. Classify interaction type
    3. Insert interaction facts
  Volume: ~2M records/day
  
  Grain: One row per interaction

sp_load_all_facts (ORCHESTRATOR)
  Calls all fact loading procedures
  Order matters: Must load sales first, then revenue aggregates
  Includes error handling and logging


6. KPI CALCULATIONS
===================

File: backend/database/stored_procedures/03_sp_calculate_kpis.sql

VIEWS (READ-ONLY, REAL-TIME):
------------------------------

vw_kpi_financial_summary
  - Total Revenue
  - Revenue by Segment
  - Gross Profit Margin %
  - Operating Margin %
  - Average Deal Size

vw_kpi_sales_summary
  - Sales Growth Rate (YoY)
  - Win Rate %
  - Sales Cycle Length (Days)
  - Pipeline Value
  - New Customers Acquired
  - Customer Acquisition Cost
  - Sales per Rep

vw_kpi_customer_success
  - Customer Retention Rate %
  - Churn Rate %
  - Net Revenue Retention (NRR) %
  - Customer Satisfaction (CSAT)
  - Support Resolution Time
  - Product Usage Rate

vw_kpi_operational
  - Order Fulfillment Time (Days)
  - On-Time Delivery Rate %
  - Inventory Turnover
  - Operational Efficiency Ratio %
  - Process Compliance %
  - Defect Rate %
  - First Pass Yield %

PROCEDURE:
----------

sp_calculate_all_kpis
  1. Queries all KPI views
  2. Compares to targets
  3. Calculates variance
  4. Assigns status (Green/Yellow/Red)
  5. Inserts into kpi_results table
  
  Status Logic:
    - Green: >= Target
    - Yellow: >= 90% of target
    - Red: < 90% of target
  
  Frequency: Daily (post-fact load)
  Duration: ~2-3 minutes


7. DATA QUALITY & VALIDATION
=============================

File: backend/database/stored_procedures/06_sp_data_quality_validation.sql

PROCEDURES:
-----------

sp_validate_staging_completeness
  Checks:
    - Missing required fields
    - Data type validity
    - Duplicate records
  
  Metrics:
    - Total records
    - Invalid records
    - Valid records
    - Quality score %
  
  Output: dq_validation_logs table

sp_reconcile_etl_totals
  Compares:
    - Source record count vs Staging count
    - Source total amount vs Fact total amount
    - Calculates variance percentages
  
  Thresholds:
    - < 0.01% variance: PASS
    - > 0.01% variance: FAIL (investigate)
  
  Output: etl_reconciliation table

sp_calculate_dq_score
  Weighted components:
    - Completeness (20%): % with all required fields
    - Accuracy (25%): % passing validation checks
    - Consistency (25%): % with no duplicates
    - Timeliness (15%): % loaded within time window
    - Validity (15%): % with valid data ranges
  
  Overall Score: 0-100
  Status:
    - Excellent: >= 90
    - Good: >= 75
    - Fair: >= 60
    - Poor: < 60

sp_check_referential_integrity
  Validates:
    - No orphaned dimension keys
    - All fact references exist in dimensions
  
  Detects:
    - Orphaned customer keys
    - Orphaned product keys
    - Other dimension mismatches

sp_detect_duplicates
  Finds duplicate business keys
  Flags for manual review or reload

sp_generate_dq_summary_report
  Comprehensive report including:
    - Record counts by status
    - Quality scores
    - Validation issues
    - Reconciliation results


8. MASTER ORCHESTRATION
=======================

File: backend/database/stored_procedures/04_sp_etl_master_orchestration.sql

PROCEDURE:
----------

sp_etl_master_orchestration
  Complete end-to-end ETL pipeline

  Parameters:
    @ProcessDate DATE
      - Date to process (cannot be future date)
    @ProcessType VARCHAR(20)
      - INCREMENTAL: Load only new/changed data (default)
      - FULL_REFRESH: Reload all historical data
    @DebugMode BIT
      - 0: Silent mode (production)
      - 1: Verbose output (development)

  Execution Flow:
    1. Validate Date & Prerequisites
       - Verify process date is valid
       - Check staging tables have data
    
    2. Transform Staging Data
       - ERP Orders
       - Salesforce Customers & Opportunities
       - Inventory, Interactions, etc.
       - Validate data quality
    
    3. Load Dimensions (SCD Type 2)
       - Customer dimension
       - Product dimension
       - Date dimension (if needed)
    
    4. Load Facts
       - Sales facts (~500K records/day)
       - Revenue aggregates
       - Customer interaction facts
       - Other fact tables
    
    5. Reconciliation Checks
       - Source vs Staging totals
       - Staging vs Facts totals
       - Variance analysis
    
    6. Calculate KPIs
       - Financial KPIs
       - Sales KPIs
       - Customer Success KPIs
       - Operational KPIs
    
    7. Archive Old Staging Data
       - Move staging data > 30 days to archive
    
    8. Generate Summary & Logs

  Total Duration: ~45 minutes for full load
  Data Volume: 500K+ orders, 2M+ interactions, 1M+ inventory records


9. EXECUTION EXAMPLES
====================

BASIC EXECUTION (Incremental Load):
  EXEC sp_etl_master_orchestration
    @ProcessDate = '2024-01-15',
    @ProcessType = 'INCREMENTAL',
    @DebugMode = 1;

FULL REFRESH (Reload all data):
  EXEC sp_etl_master_orchestration
    @ProcessDate = '2024-01-15',
    @ProcessType = 'FULL_REFRESH',
    @DebugMode = 0;

STAGING ONLY (Transform without loading facts):
  EXEC sp_transform_all_staging @LoadDate = '2024-01-15';

DIMENSIONS ONLY:
  EXEC sp_load_dim_customer @ProcessDate = '2024-01-15';
  EXEC sp_load_dim_product @ProcessDate = '2024-01-15';

FACTS ONLY:
  EXEC sp_load_all_facts @LoadDate = '2024-01-15', @IsIncrementalLoad = 1;

KPI CALCULATION ONLY:
  EXEC sp_calculate_all_kpis @CalculationDate = '2024-01-15';

DATA QUALITY CHECKS:
  EXEC sp_validate_staging_completeness 
    @StagingTable = 'stg_raw_erp_orders', 
    @LoadDate = '2024-01-15';
  
  EXEC sp_reconcile_etl_totals @LoadDate = '2024-01-15';
  
  EXEC sp_calculate_dq_score @LoadDate = '2024-01-15';
  
  EXEC sp_generate_dq_summary_report @LoadDate = '2024-01-15';

QUERIES FOR VALIDATION:
  -- View KPI results
  SELECT * FROM kpi_results 
  WHERE calculation_date = '2024-01-15'
  ORDER BY kpi_category, kpi_name;
  
  -- View fact totals
  SELECT 
    COUNT(*) as record_count,
    SUM(net_amount) as total_revenue,
    AVG(delivery_days) as avg_delivery_days
  FROM fact_sales 
  WHERE load_date = '2024-01-15';
  
  -- View dimension records
  SELECT COUNT(*) as customer_count
  FROM dim_customer 
  WHERE is_current = 1;
  
  -- View data quality scores
  SELECT * FROM dq_scores 
  WHERE load_date = '2024-01-15';


10. MONITORING & TROUBLESHOOTING
================================

MONITORING TABLES:
------------------

etl_logs
  - All procedure executions
  - Success/failure status
  - Execution times
  - Record counts
  
  Query:
    SELECT * FROM etl_logs 
    WHERE process_name = 'sp_etl_master_orchestration'
    ORDER BY log_date DESC, log_timestamp DESC;

dq_validation_logs
  - Data quality metrics
  - Completeness scores
  - Validity checks
  
  Query:
    SELECT * FROM dq_validation_logs 
    WHERE validation_run_time >= DATEADD(DAY, -1, GETDATE())
    ORDER BY validation_run_time DESC;

etl_reconciliation
  - Record counts by stage
  - Amount totals & variance
  - Reconciliation status
  
  Query:
    SELECT * FROM etl_reconciliation 
    WHERE load_date = '2024-01-15'
    ORDER BY reconciliation_type;

data_issues
  - Orphaned keys
  - Referential integrity violations
  - Duplicate detections
  
  Query:
    SELECT * FROM data_issues 
    WHERE issue_date = '2024-01-15'
    AND severity = 'HIGH';

TROUBLESHOOTING CHECKLIST:
--------------------------

If ETL fails:
  1. Check etl_logs for error message
  2. Verify raw staging tables have data
  3. Check data types in staging tables
  4. Run sp_validate_staging_completeness
  5. Verify dimension tables are loaded

If KPIs are missing:
  1. Verify facts were loaded
  2. Check for orphaned dimension keys
  3. Run sp_calculate_all_kpis manually
  4. Check kpi_results table

If reconciliation fails:
  1. Run sp_reconcile_etl_totals
  2. Check record counts in staging vs facts
  3. Look for invalid records marked in staging
  4. Run sp_detect_duplicates

Low data quality score:
  1. Run sp_calculate_dq_score
  2. Check completeness_score
  3. Check for invalid data types
  4. Review specific invalid records


BEST PRACTICES:
---------------

1. Always run incremental loads (faster)
   - Only use FULL_REFRESH for troubleshooting

2. Schedule ETL during off-hours
   - Avoid business hours when possible

3. Monitor execution logs daily
   - Set up alerts for FAILED status

4. Validate KPI results manually
   - Compare to dashboard metrics
   - Spot-check calculations

5. Archive staging data regularly
   - Keeps database lean
   - Master orchestration does this automatically

6. Review data quality scores weekly
   - Target: >= 95% Excellent
   - Investigate drops below 90% Good

7. Reconciliation must PASS
   - < 0.01% variance is acceptable
   - Investigate any FAIL status

*/

PRINT 'ETL Implementation Guide - Complete';
PRINT '';
PRINT 'TO GET STARTED:';
PRINT '==============';
PRINT '';
PRINT 'Step 1: Deploy all SQL files in order:';
PRINT '  1. backend/database/staging/01_*.sql';
PRINT '  2. backend/database/staging/02_*.sql';
PRINT '  3. backend/database/staging/03_*.sql';
PRINT '  4. backend/database/stored_procedures/01_*.sql';
PRINT '  5. backend/database/stored_procedures/02_*.sql';
PRINT '  6. backend/database/stored_procedures/03_*.sql';
PRINT '  7. backend/database/stored_procedures/04_*.sql';
PRINT '  8. backend/database/stored_procedures/05_*.sql';
PRINT '  9. backend/database/stored_procedures/06_*.sql';
PRINT '';
PRINT 'Step 2: Execute for your target date:';
PRINT '  EXEC sp_etl_master_orchestration @ProcessDate = ''2024-01-15'', @DebugMode = 1;';
PRINT '';
PRINT 'Step 3: Validate results:';
PRINT '  SELECT * FROM kpi_results WHERE calculation_date = ''2024-01-15'';';
PRINT '';
GO
